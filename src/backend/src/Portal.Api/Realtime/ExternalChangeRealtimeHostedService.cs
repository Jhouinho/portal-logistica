using Microsoft.AspNetCore.SignalR;
using Portal.Api.Hubs;
using Portal.Application.Realtime;

namespace Portal.Api.Realtime;

/// <summary>
/// Ciclo periódico: ExternalChangeDetector → SignalR (Portal + TV) → avançar watermarks.
/// Estado em memória (uma instância por processo). Sem persistência / distributed lock (v1).
/// Limitação: múltiplas instâncias podem publicar eventos duplicados (aceitável — invalidação).
/// </summary>
public sealed class ExternalChangeRealtimeHostedService : BackgroundService
{
    private static readonly TimeSpan Interval = TimeSpan.FromSeconds(5);

    private readonly IServiceScopeFactory _scopeFactory;
    private readonly IHubContext<OperacoesHub> _operacoesHub;
    private readonly IHubContext<TvHub> _tvHub;
    private readonly ILogger<ExternalChangeRealtimeHostedService> _logger;
    private readonly SemaphoreSlim _cycleGate = new(1, 1);

    private ExternalChangeWatermarks _watermarks = ExternalChangeWatermarks.Uninitialized;

    public ExternalChangeRealtimeHostedService(
        IServiceScopeFactory scopeFactory,
        IHubContext<OperacoesHub> operacoesHub,
        IHubContext<TvHub> tvHub,
        ILogger<ExternalChangeRealtimeHostedService> logger)
    {
        _scopeFactory = scopeFactory;
        _operacoesHub = operacoesHub;
        _tvHub = tvHub;
        _logger = logger;
    }

    protected override async Task ExecuteAsync(CancellationToken stoppingToken)
    {
        _logger.LogInformation(
            "Realtime externo: HostedService activo (intervalo {IntervalSeconds}s).",
            Interval.TotalSeconds);

        await RunCycleAsync(stoppingToken);

        using var timer = new PeriodicTimer(Interval);
        try
        {
            while (await timer.WaitForNextTickAsync(stoppingToken))
                await RunCycleAsync(stoppingToken);
        }
        catch (OperationCanceledException) when (stoppingToken.IsCancellationRequested)
        {
            // shutdown normal
        }
    }

    internal async Task RunCycleAsync(CancellationToken cancellationToken)
    {
        if (!await _cycleGate.WaitAsync(0, cancellationToken))
            return;

        try
        {
            await ExecuteCycleCoreAsync(cancellationToken);
        }
        catch (OperationCanceledException) when (cancellationToken.IsCancellationRequested)
        {
            throw;
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Ciclo realtime externo falhou.");
        }
        finally
        {
            _cycleGate.Release();
        }
    }

    private async Task ExecuteCycleCoreAsync(CancellationToken cancellationToken)
    {
        using var scope = _scopeFactory.CreateScope();
        var detector = scope.ServiceProvider.GetRequiredService<ExternalChangeDetector>();

        var detection = await detector.DetectAsync(_watermarks, cancellationToken);

        if (detection.WasColdStart)
        {
            _watermarks = detection.NextWatermarks;
            _logger.LogInformation("Realtime externo inicializado; watermarks estabelecidos.");
            return;
        }

        if (detection.AnyRegressed)
        {
            _logger.LogWarning(
                "Regressão de cursor realtime (não recua): Bo1={Bo1} Bi1={Bi1} Bo66={Bo66} Bi66={Bi66} Bo65={Bo65} Bi65={Bi65} Kapps={Kapps}",
                detection.Bo1Regressed,
                detection.Bi1Regressed,
                detection.Bo66Regressed,
                detection.Bi66Regressed,
                detection.Bo65Regressed,
                detection.Bi65Regressed,
                detection.KappsRegressed);
        }

        var plan = ExternalChangeCycleLogic.PlanPublishes(detection);
        if (plan.Count == 0)
        {
            _watermarks = ExternalChangeCycleLogic.MergeAfterPublish(
                _watermarks,
                detection,
                publishedOk: new HashSet<ExternalRealtimeUniverse>());
            return;
        }

        var publishedOk = new HashSet<ExternalRealtimeUniverse>();
        foreach (var universe in plan)
        {
            cancellationToken.ThrowIfCancellationRequested();
            try
            {
                // Portal autenticado é a fonte de verdade para avanço do watermark.
                // TV é best-effort independente: falha na TV não impede avanço se Portal OK.
                var portalOk = await TryPublishOperacoesAsync(universe, cancellationToken);
                await TryPublishTvAsync(universe, cancellationToken);

                if (portalOk)
                {
                    publishedOk.Add(universe);
                    _logger.LogInformation(
                        "Alteração externa detectada: {Universe}",
                        ExternalChangeCycleLogic.DescribeUniverse(universe));
                }
            }
            catch (OperationCanceledException) when (cancellationToken.IsCancellationRequested)
            {
                throw;
            }
            catch (Exception ex)
            {
                _logger.LogError(
                    ex,
                    "Falha SignalR ao publicar invalidação {Universe}; watermark desse universo não avança.",
                    ExternalChangeCycleLogic.DescribeUniverse(universe));
            }
        }

        _watermarks = ExternalChangeCycleLogic.MergeAfterPublish(_watermarks, detection, publishedOk);
    }

    private async Task<bool> TryPublishOperacoesAsync(
        ExternalRealtimeUniverse universe,
        CancellationToken cancellationToken)
    {
        var eventName = EventName(universe);
        try
        {
            await _operacoesHub.Clients.Group("operacoes").SendCoreAsync(
                eventName,
                Array.Empty<object>(),
                cancellationToken);
            return true;
        }
        catch (OperationCanceledException) when (cancellationToken.IsCancellationRequested)
        {
            throw;
        }
        catch (Exception ex)
        {
            _logger.LogError(
                ex,
                "Falha SignalR OperacoesHub ao publicar {Universe}.",
                ExternalChangeCycleLogic.DescribeUniverse(universe));
            return false;
        }
    }

    private async Task TryPublishTvAsync(
        ExternalRealtimeUniverse universe,
        CancellationToken cancellationToken)
    {
        var eventName = EventName(universe);
        try
        {
            await _tvHub.Clients.Group(TvHub.GroupName).SendCoreAsync(
                eventName,
                Array.Empty<object>(),
                cancellationToken);
        }
        catch (OperationCanceledException) when (cancellationToken.IsCancellationRequested)
        {
            throw;
        }
        catch (Exception ex)
        {
            _logger.LogWarning(
                ex,
                "Falha SignalR TvHub ao publicar {Universe} (Portal não afectado).",
                ExternalChangeCycleLogic.DescribeUniverse(universe));
        }
    }

    private static string EventName(ExternalRealtimeUniverse universe) =>
        universe switch
        {
            ExternalRealtimeUniverse.Encomenda => OperacoesHubEvents.EncomendaAlterada,
            ExternalRealtimeUniverse.Dossier66 => OperacoesHubEvents.Dossier66Alterado,
            ExternalRealtimeUniverse.Dossier65 => OperacoesHubEvents.Dossier65Alterado,
            ExternalRealtimeUniverse.Kapps => OperacoesHubEvents.KappsAlterado,
            _ => throw new ArgumentOutOfRangeException(nameof(universe), universe, null),
        };

    public override void Dispose()
    {
        _cycleGate.Dispose();
        base.Dispose();
    }
}
