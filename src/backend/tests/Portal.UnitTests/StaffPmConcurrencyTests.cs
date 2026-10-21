using Microsoft.Extensions.Logging.Abstractions;
using Microsoft.Extensions.Options;
using Portal.Application.Cliente;
using Portal.Application.Encomendas;
using Portal.Infrastructure.Cliente;
using Portal.Infrastructure.Options;

namespace Portal.UnitTests;

public class StaffPmConcurrencyTests
{
    [Fact]
    public async Task Aprovar_e_rejeitar_simultaneos_apenas_um_vence()
    {
        var store = new ConcurrentFakeStore(MakePedido("recebido"));
        var gate = new CountingBo67Gateway();
        var svc = CreateService(store, gate);

        var aprovar = svc.AprovarAsync(1, "ADM", "admin", CancellationToken.None);
        var rejeitar = svc.RejeitarAsync(1, "stock", "admin", CancellationToken.None);
        await Task.WhenAll(
            IgnoreBusiness(aprovar),
            IgnoreBusiness(rejeitar));

        var final = store.Pedido!;
        var integrado = StaffPmPedidoRules.IsIntegradoCompleto(final.EstadoInterno, final.Bostamp);
        var rejeitado = StaffPmPedidoRules.NormalizeEstado(final.EstadoInterno) == "rejeitado";

        Assert.True(integrado ^ rejeitado, "Exactamente um de integrado ou rejeitado.");
        if (integrado)
        {
            Assert.Equal(1, gate.CreateCalls);
            Assert.NotEqual("rejeitado", final.EstadoInterno);
            Assert.False(string.IsNullOrWhiteSpace(final.Bostamp));
        }
        else
        {
            Assert.Equal(0, gate.CreateCalls);
            Assert.Null(final.Bostamp);
        }
    }

    [Fact]
    public async Task Precos_bloqueados_apos_claim_de_aprovacao()
    {
        var store = new ConcurrentFakeStore(MakePedido("recebido"));
        store.BlockBo67UntilReleased = new TaskCompletionSource();
        var gate = new CountingBo67Gateway { DelayUntil = store.BlockBo67UntilReleased.Task };
        var svc = CreateService(store, gate);

        var aprovarTask = svc.AprovarAsync(1, "ADM", "admin", CancellationToken.None);
        await store.ClaimStarted.Task.WaitAsync(TimeSpan.FromSeconds(5));

        Assert.Equal("em_aprovacao", store.Pedido!.EstadoInterno);
        Assert.False(StaffPmPrecoRules.CanEditPrecos(store.Pedido.EstadoInterno, store.Pedido.Bostamp));

        var ex = await Assert.ThrowsAsync<PortalBusinessException>(() =>
            svc.GuardarPrecosAsync(1, [new StaffPmPrecoLinhaRequest(1, 99m)], CancellationToken.None));
        Assert.Equal(409, ex.StatusCode);
        Assert.Equal(0, store.AtualizarPrecosCalls);

        store.BlockBo67UntilReleased.SetResult();
        var r = await aprovarTask;
        Assert.Equal("integrado", r.EstadoInterno);
    }

    [Fact]
    public async Task Duas_aprovacoes_simultaneas_um_so_dossier()
    {
        var store = new ConcurrentFakeStore(MakePedido("recebido"));
        var gate = new CountingBo67Gateway();
        var svc = CreateService(store, gate);

        var t1 = svc.AprovarAsync(1, "ADM", "a1", CancellationToken.None);
        var t2 = svc.AprovarAsync(1, "ADM", "a2", CancellationToken.None);
        var results = await Task.WhenAll(t1, t2);

        Assert.All(results, r => Assert.Equal("STAMP-1", r.Bostamp));
        // Ambos podem chamar a SP; a 2.ª é idempotente (AlreadyExists). Um só claim.
        Assert.InRange(gate.CreateCalls, 1, 2);
        Assert.Equal(1, store.ClaimSuccessCount);
        Assert.Equal("integrado", store.Pedido!.EstadoInterno);
    }

    [Fact]
    public async Task Repetir_aprovacao_apos_timeout_reconcilia_sem_segundo_dossier()
    {
        // Simula: claim + BO criados, mark falhou (timeout) → em_aprovacao sem Bostamp no pedido,
        // mas gateway devolve alreadyExists.
        var store = new ConcurrentFakeStore(
            MakePedido("em_aprovacao", bostamp: null));
        var gate = new CountingBo67Gateway { AlreadyExistsOnNext = true };
        var svc = CreateService(store, gate);

        var r = await svc.AprovarAsync(1, "ADM", "admin", CancellationToken.None);

        Assert.True(r.AlreadyExistsBo);
        Assert.Equal("STAMP-1", r.Bostamp);
        Assert.Equal("integrado", r.EstadoInterno);
        Assert.Equal(1, gate.CreateCalls);
        Assert.Equal(0, store.ClaimSuccessCount); // já estava em_aprovacao
    }

    [Fact]
    public async Task Rejeitar_pedido_integrado_falha()
    {
        var store = new ConcurrentFakeStore(
            MakePedido("integrado", bostamp: "X", obrano: 1, boano: 2026, ndos: 67));
        var svc = CreateService(store, new CountingBo67Gateway());

        var ex = await Assert.ThrowsAsync<PortalBusinessException>(() =>
            svc.RejeitarAsync(1, "x", "admin", CancellationToken.None));
        Assert.Equal(409, ex.StatusCode);
        Assert.Equal(0, store.RejeitarCalls);
    }

    [Fact]
    public async Task Precos_impossiveis_apos_rejeitado()
    {
        var store = new ConcurrentFakeStore(MakePedido("rejeitado"));
        var svc = CreateService(store, new CountingBo67Gateway());

        var ex = await Assert.ThrowsAsync<PortalBusinessException>(() =>
            svc.GuardarPrecosAsync(1, [new StaffPmPrecoLinhaRequest(1, 2m)], CancellationToken.None));
        Assert.Equal(409, ex.StatusCode);
        Assert.Equal(0, store.AtualizarPrecosCalls);
    }

    [Fact]
    public async Task Rejeitar_durante_em_aprovacao_falha_sem_alterar_estado()
    {
        var store = new ConcurrentFakeStore(MakePedido("em_aprovacao"));
        var svc = CreateService(store, new CountingBo67Gateway());

        var ex = await Assert.ThrowsAsync<PortalBusinessException>(() =>
            svc.RejeitarAsync(1, "x", "admin", CancellationToken.None));
        Assert.Equal(409, ex.StatusCode);
        Assert.Contains("Aprovação em curso", ex.Message, StringComparison.OrdinalIgnoreCase);
        Assert.Equal("em_aprovacao", store.Pedido!.EstadoInterno);
        Assert.Equal(0, store.RejeitarCalls);
    }

    private static async Task IgnoreBusiness(Task task)
    {
        try { await task; }
        catch (PortalBusinessException) { /* esperado num dos lados */ }
    }

    private static StaffPmPedidosService CreateService(
        ConcurrentFakeStore store,
        IStaffPmBo67Gateway gate) =>
        new(
            store,
            gate,
            Options.Create(new PortalClienteOptions { PedidoMobileNdos = 67 }),
            NullLogger<StaffPmPedidosService>.Instance);

    private static ClientePmPedidoPersistido MakePedido(
        string estado,
        string? bostamp = null,
        decimal? obrano = null,
        decimal? boano = null,
        decimal? ndos = null)
    {
        var now = new DateTime(2026, 10, 21, 10, 0, 0, DateTimeKind.Utc);
        var linhas = new List<ClientePmLinhaPersistida>
        {
            new(1, "1051", "Art", "", 2m, 1.5m, 3m, 1.5m)
        };
        return new ClientePmPedidoPersistido(
            1, "PM-2026-000001", 100, 0, estado, now, now, 3m, "hash", linhas,
            bostamp, obrano, boano, ndos, null, null, null, "Cliente");
    }

    private sealed class CountingBo67Gateway : IStaffPmBo67Gateway
    {
        public int CreateCalls { get; private set; }
        public bool AlreadyExistsOnNext { get; set; }
        public Task? DelayUntil { get; set; }

        public async Task<StaffPmBo67CreateResult> CriarAsync(
            ClientePmPedidoPersistido pedido,
            string usrinis,
            CancellationToken cancellationToken)
        {
            if (DelayUntil is not null)
                await DelayUntil.WaitAsync(cancellationToken);

            CreateCalls++;
            var already = AlreadyExistsOnNext || CreateCalls > 1;
            AlreadyExistsOnNext = false;
            return new StaffPmBo67CreateResult(already, "STAMP-1", 10, 2026, 67);
        }
    }

    /// <summary>Simula UPDATE atómico de claim/rejeição/mark como na BD.</summary>
    private sealed class ConcurrentFakeStore : IClientePmPedidoStore
    {
        private readonly object _gate = new();
        public ClientePmPedidoPersistido Pedido { get; private set; }
        public int ClaimSuccessCount { get; private set; }
        public int RejeitarCalls { get; private set; }
        public int AtualizarPrecosCalls { get; private set; }
        public TaskCompletionSource ClaimStarted { get; } = new();
        public TaskCompletionSource? BlockBo67UntilReleased { get; set; }

        public ConcurrentFakeStore(ClientePmPedidoPersistido pedido) => Pedido = pedido;

        public Task<ClientePmCreateOutcome> CriarAsync(
            decimal clNo, decimal clEstab, string idempotencyKey, string payloadHash,
            IReadOnlyList<ClientePmLinhaPersistida> linhas, CancellationToken cancellationToken) =>
            throw new NotSupportedException();

        public Task<IReadOnlyList<ClientePmPedidoPersistido>> ListarAsync(
            decimal clNo, decimal clEstab, int top, CancellationToken cancellationToken) =>
            Task.FromResult<IReadOnlyList<ClientePmPedidoPersistido>>([]);

        public Task<ClientePmPedidoPersistido?> ObterPorIdAsync(
            decimal clNo, decimal clEstab, long pedidoId, CancellationToken cancellationToken) =>
            Task.FromResult<ClientePmPedidoPersistido?>(Pedido);

        public Task<ClientePmPedidoPersistido?> ObterPorNumeroAsync(
            decimal clNo, decimal clEstab, string numeroInterno, CancellationToken cancellationToken) =>
            Task.FromResult<ClientePmPedidoPersistido?>(Pedido);

        public Task<IReadOnlyList<ClientePmPedidoPersistido>> ListarStaffAsync(
            string? filtroEstado, int top, CancellationToken cancellationToken) =>
            Task.FromResult<IReadOnlyList<ClientePmPedidoPersistido>>([Pedido]);

        public Task<ClientePmPedidoPersistido?> ObterPorIdStaffAsync(
            long pedidoId, bool incluirLinhas, CancellationToken cancellationToken)
        {
            lock (_gate) return Task.FromResult<ClientePmPedidoPersistido?>(Pedido);
        }

        public Task<ClientePmIntegracaoResult> TryClaimAprovacaoAsync(
            long pedidoId, CancellationToken cancellationToken)
        {
            lock (_gate)
            {
                if (StaffPmPedidoRules.IsPendente(Pedido.EstadoInterno, Pedido.Bostamp))
                {
                    Pedido = Pedido with { EstadoInterno = "em_aprovacao" };
                    ClaimSuccessCount++;
                    ClaimStarted.TrySetResult();
                    return Task.FromResult(new ClientePmIntegracaoResult(true, Pedido));
                }

                ClaimStarted.TrySetResult();
                return Task.FromResult(new ClientePmIntegracaoResult(false, Pedido));
            }
        }

        public Task<ClientePmIntegracaoResult> TryMarcarIntegradoAsync(
            long pedidoId, string bostamp, decimal obrano, decimal boano, decimal ndos,
            string? decididoPor, CancellationToken cancellationToken)
        {
            lock (_gate)
            {
                var e = StaffPmPedidoRules.NormalizeEstado(Pedido.EstadoInterno);
                var ok = e is "recebido" or "em_analise" or "em_aprovacao"
                    && (string.IsNullOrWhiteSpace(Pedido.Bostamp) || Pedido.Bostamp == bostamp);
                if (!ok)
                    return Task.FromResult(new ClientePmIntegracaoResult(false, Pedido));

                Pedido = Pedido with
                {
                    EstadoInterno = "integrado",
                    Bostamp = bostamp,
                    Obrano = obrano,
                    Boano = boano,
                    Ndos = ndos
                };
                return Task.FromResult(new ClientePmIntegracaoResult(true, Pedido));
            }
        }

        public Task<ClientePmIntegracaoResult> TryRejeitarAsync(
            long pedidoId, string? motivo, string? decididoPor, CancellationToken cancellationToken)
        {
            lock (_gate)
            {
                RejeitarCalls++;
                if (!StaffPmPedidoRules.CanReject(Pedido.EstadoInterno, Pedido.Bostamp))
                    return Task.FromResult(new ClientePmIntegracaoResult(false, Pedido));

                Pedido = Pedido with { EstadoInterno = "rejeitado", MotivoRejeicao = motivo };
                return Task.FromResult(new ClientePmIntegracaoResult(true, Pedido));
            }
        }

        public Task<ClientePmIntegracaoResult> TryAtualizarPrecosOperadorAsync(
            long pedidoId,
            IReadOnlyList<(int LinhaOrd, decimal PrecoUnitario)> precos,
            CancellationToken cancellationToken)
        {
            lock (_gate)
            {
                AtualizarPrecosCalls++;
                if (!StaffPmPrecoRules.CanEditPrecos(Pedido.EstadoInterno, Pedido.Bostamp))
                    return Task.FromResult(new ClientePmIntegracaoResult(false, Pedido));

                var linhas = Pedido.Linhas!.Select(l =>
                {
                    var p = precos.First(x => x.LinhaOrd == l.LinhaOrd).PrecoUnitario;
                    return l with
                    {
                        PrecoUnitario = p,
                        TotalLinha = StaffPmPrecoRules.CalcTotalLinha(l.Qtt, p)
                    };
                }).ToList();
                Pedido = Pedido with { Linhas = linhas, Etotaldeb = linhas.Sum(x => x.TotalLinha) };
                return Task.FromResult(new ClientePmIntegracaoResult(true, Pedido));
            }
        }
    }
}
