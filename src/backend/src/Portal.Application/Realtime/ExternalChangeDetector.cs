using Microsoft.Extensions.Options;
using Portal.Application.Encomendas;

namespace Portal.Application.Realtime;

/// <summary>
/// Detector isolado de alterações externas (Etapa 1).
/// Não conhece SignalR, HostedService, React nem intervalos de polling.
/// </summary>
public sealed class ExternalChangeDetector
{
    private readonly IExternalChangeCursorQuery _query;
    private readonly int _ndos1;
    private readonly int _ndos66;
    private readonly int _ndos65;

    public ExternalChangeDetector(
        IExternalChangeCursorQuery query,
        IOptions<SerieEncomendasSettings> serie)
    {
        _query = query;
        _ndos1 = serie.Value.SerieEncomendasNdos;
        _ndos66 = serie.Value.SeriePickingNdos;
        _ndos65 = serie.Value.SerieSeparacaoNdos;
    }

    /// <summary>
    /// Compara watermarks conhecidos com o estado actual da BD.
    /// <paramref name="known"/> null ou não inicializado = cold start (sem alteração).
    /// </summary>
    public async Task<ExternalChangeDetectionResult> DetectAsync(
        ExternalChangeWatermarks? known,
        CancellationToken cancellationToken = default)
    {
        var snapshot = await ReadSnapshotAsync(cancellationToken);
        return DetectFromSnapshot(known, snapshot);
    }

    /// <summary>Aplica comparação pura (útil em testes sem BD).</summary>
    public static ExternalChangeDetectionResult DetectFromSnapshot(
        ExternalChangeWatermarks? known,
        ExternalChangeSnapshot snapshot)
    {
        if (known is null || !known.IsInitialized)
        {
            return new ExternalChangeDetectionResult
            {
                WasColdStart = true,
                Bo1Advanced = false,
                Bi1Advanced = false,
                Bo66Advanced = false,
                Bi66Advanced = false,
                Bo65Advanced = false,
                Bi65Advanced = false,
                KappsAdvanced = false,
                Bo1Regressed = false,
                Bi1Regressed = false,
                Bo66Regressed = false,
                Bi66Regressed = false,
                Bo65Regressed = false,
                Bi65Regressed = false,
                KappsRegressed = false,
                NextWatermarks = ExternalChangeWatermarks.FromSnapshot(snapshot),
            };
        }

        var bo1 = CursorComparison.Compare(known.Bo1, snapshot.Bo1);
        var bi1 = CursorComparison.Compare(known.Bi1, snapshot.Bi1);
        var bo66 = CursorComparison.Compare(known.Bo66, snapshot.Bo66);
        var bi66 = CursorComparison.Compare(known.Bi66, snapshot.Bi66);
        var bo65 = CursorComparison.Compare(known.Bo65, snapshot.Bo65);
        var bi65 = CursorComparison.Compare(known.Bi65, snapshot.Bi65);
        var kapps = CursorComparison.Compare(known.Kapps, snapshot.Kapps);

        return new ExternalChangeDetectionResult
        {
            WasColdStart = false,
            Bo1Advanced = bo1 == CursorChangeKind.Advanced,
            Bi1Advanced = bi1 == CursorChangeKind.Advanced,
            Bo66Advanced = bo66 == CursorChangeKind.Advanced,
            Bi66Advanced = bi66 == CursorChangeKind.Advanced,
            Bo65Advanced = bo65 == CursorChangeKind.Advanced,
            Bi65Advanced = bi65 == CursorChangeKind.Advanced,
            KappsAdvanced = kapps == CursorChangeKind.Advanced,
            Bo1Regressed = bo1 == CursorChangeKind.Regressed,
            Bi1Regressed = bi1 == CursorChangeKind.Regressed,
            Bo66Regressed = bo66 == CursorChangeKind.Regressed,
            Bi66Regressed = bi66 == CursorChangeKind.Regressed,
            Bo65Regressed = bo65 == CursorChangeKind.Regressed,
            Bi65Regressed = bi65 == CursorChangeKind.Regressed,
            KappsRegressed = kapps == CursorChangeKind.Regressed,
            NextWatermarks = new ExternalChangeWatermarks
            {
                IsInitialized = true,
                Bo1 = NextBoBi(known.Bo1, snapshot.Bo1, bo1),
                Bi1 = NextBoBi(known.Bi1, snapshot.Bi1, bi1),
                Bo66 = NextBoBi(known.Bo66, snapshot.Bo66, bo66),
                Bi66 = NextBoBi(known.Bi66, snapshot.Bi66, bi66),
                Bo65 = NextBoBi(known.Bo65, snapshot.Bo65, bo65),
                Bi65 = NextBoBi(known.Bi65, snapshot.Bi65, bi65),
                Kapps = NextKapps(known.Kapps, snapshot.Kapps, kapps),
            },
        };
    }

    private async Task<ExternalChangeSnapshot> ReadSnapshotAsync(CancellationToken cancellationToken)
    {
        var bo1 = await _query.GetMaxBoCursorAsync(_ndos1, cancellationToken);
        var bi1 = await _query.GetMaxBiCursorAsync(_ndos1, cancellationToken);
        var bo66 = await _query.GetMaxBoCursorAsync(_ndos66, cancellationToken);
        var bi66 = await _query.GetMaxBiCursorAsync(_ndos66, cancellationToken);
        var bo65 = await _query.GetMaxBoCursorAsync(_ndos65, cancellationToken);
        var bi65 = await _query.GetMaxBiCursorAsync(_ndos65, cancellationToken);
        var kapps = await _query.GetMaxKappsCursorAsync(cancellationToken);

        return new ExternalChangeSnapshot
        {
            Bo1 = bo1,
            Bi1 = bi1,
            Bo66 = bo66,
            Bi66 = bi66,
            Bo65 = bo65,
            Bi65 = bi65,
            Kapps = kapps,
        };
    }

    private static BoBiCursor? NextBoBi(BoBiCursor? known, BoBiCursor? observed, CursorChangeKind kind) =>
        kind switch
        {
            CursorChangeKind.Advanced => observed,
            CursorChangeKind.Regressed => known,
            _ => known ?? observed,
        };

    private static KappsCursor? NextKapps(KappsCursor? known, KappsCursor? observed, CursorChangeKind kind) =>
        kind switch
        {
            CursorChangeKind.Advanced => observed,
            CursorChangeKind.Regressed => known,
            _ => known ?? observed,
        };
}
