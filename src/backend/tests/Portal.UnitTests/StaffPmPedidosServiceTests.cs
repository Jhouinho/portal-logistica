using Microsoft.Extensions.Logging.Abstractions;
using Microsoft.Extensions.Options;
using Portal.Application.Cliente;
using Portal.Application.Encomendas;
using Portal.Infrastructure.Cliente;
using Portal.Infrastructure.Options;

namespace Portal.UnitTests;

public class StaffPmPedidosServiceTests
{
    [Fact]
    public async Task Aprovar_pedido_rejeitado_falha_409()
    {
        var store = new FakeStaffStore
        {
            Pedido = MakePedido(estado: "rejeitado", bostamp: null)
        };
        var svc = CreateService(store);
        var ex = await Assert.ThrowsAsync<PortalBusinessException>(() =>
            svc.AprovarAsync(1, "ADM", "admin", CancellationToken.None));
        Assert.Equal(409, ex.StatusCode);
        Assert.Equal(0, store.MarcarIntegradoCalls);
    }

    [Fact]
    public async Task Aprovar_ja_integrado_e_idempotente()
    {
        var store = new FakeStaffStore
        {
            Pedido = MakePedido(estado: "integrado", bostamp: "STAMP1", obrano: 10, boano: 2026, ndos: 67)
        };
        var svc = CreateService(store);
        var r = await svc.AprovarAsync(1, "ADM", "admin", CancellationToken.None);
        Assert.True(r.AlreadyIntegrated);
        Assert.Equal("STAMP1", r.Bostamp);
        Assert.Equal(0, store.MarcarIntegradoCalls);
    }

    [Fact]
    public async Task Rejeitar_pedido_pendente_ok()
    {
        var store = new FakeStaffStore
        {
            Pedido = MakePedido(estado: "recebido", bostamp: null)
        };
        store.OnRejeitar = () =>
        {
            store.Pedido = MakePedido(estado: "rejeitado", bostamp: null, motivo: "stock");
            return new ClientePmIntegracaoResult(true, store.Pedido);
        };
        var svc = CreateService(store);
        var r = await svc.RejeitarAsync(1, "stock", "admin", CancellationToken.None);
        Assert.Equal("rejeitado", r.EstadoCodigo);
        Assert.Equal("stock", r.MotivoRejeicao);
    }

    [Fact]
    public async Task Rejeitar_apos_integrado_falha()
    {
        var store = new FakeStaffStore
        {
            Pedido = MakePedido(estado: "integrado", bostamp: "X")
        };
        var svc = CreateService(store);
        var ex = await Assert.ThrowsAsync<PortalBusinessException>(() =>
            svc.RejeitarAsync(1, "x", "admin", CancellationToken.None));
        Assert.Equal(409, ex.StatusCode);
    }

    [Fact]
    public async Task Reconcile_bostamp_sem_criar_sp()
    {
        var store = new FakeStaffStore
        {
            Pedido = MakePedido(estado: "recebido", bostamp: "RECON", obrano: 5, boano: 2026, ndos: 67)
        };
        store.OnMarcarIntegrado = () =>
        {
            store.Pedido = MakePedido(estado: "integrado", bostamp: "RECON", obrano: 5, boano: 2026, ndos: 67);
            return new ClientePmIntegracaoResult(true, store.Pedido);
        };
        var svc = CreateService(store);
        var r = await svc.AprovarAsync(1, "ADM", "admin", CancellationToken.None);
        Assert.Equal("RECON", r.Bostamp);
        Assert.True(r.AlreadyExistsBo);
        Assert.Equal(1, store.MarcarIntegradoCalls);
    }

    private static StaffPmPedidosService CreateService(FakeStaffStore store) =>
        new(
            store,
            new ThrowingBo67Gateway(),
            Options.Create(new PortalClienteOptions { PedidoMobileNdos = 67 }),
            NullLogger<StaffPmPedidosService>.Instance);

    private sealed class ThrowingBo67Gateway : IStaffPmBo67Gateway
    {
        public Task<StaffPmBo67CreateResult> CriarAsync(
            ClientePmPedidoPersistido pedido,
            string usrinis,
            CancellationToken cancellationToken) =>
            throw new InvalidOperationException("SP não deve ser chamada neste teste.");
    }

    private static ClientePmPedidoPersistido MakePedido(
        string estado,
        string? bostamp,
        decimal? obrano = null,
        decimal? boano = null,
        decimal? ndos = null,
        string? motivo = null)
    {
        var now = new DateTime(2026, 10, 21, 10, 0, 0, DateTimeKind.Utc);
        var linhas = new List<ClientePmLinhaPersistida>
        {
            new(1, "1051", "Art", "", 2m, 1.5m, 3m)
        };
        return new ClientePmPedidoPersistido(
            1,
            "PM-2026-000001",
            100,
            0,
            estado,
            now,
            now,
            3m,
            "hash",
            linhas,
            bostamp,
            obrano,
            boano,
            ndos,
            motivo,
            null,
            null,
            "Cliente Teste");
    }

    private sealed class FakeStaffStore : IClientePmPedidoStore
    {
        public ClientePmPedidoPersistido? Pedido { get; set; }
        public int MarcarIntegradoCalls { get; private set; }
        public Func<ClientePmIntegracaoResult>? OnMarcarIntegrado { get; set; }
        public Func<ClientePmIntegracaoResult>? OnRejeitar { get; set; }

        public Task<ClientePmCreateOutcome> CriarAsync(
            decimal clNo, decimal clEstab, string idempotencyKey, string payloadHash,
            IReadOnlyList<ClientePmLinhaPersistida> linhas, CancellationToken cancellationToken) =>
            throw new NotSupportedException();

        public Task<IReadOnlyList<ClientePmPedidoPersistido>> ListarAsync(
            decimal clNo, decimal clEstab, int top, CancellationToken cancellationToken) =>
            Task.FromResult<IReadOnlyList<ClientePmPedidoPersistido>>([]);

        public Task<ClientePmPedidoPersistido?> ObterPorIdAsync(
            decimal clNo, decimal clEstab, long pedidoId, CancellationToken cancellationToken) =>
            Task.FromResult(Pedido);

        public Task<ClientePmPedidoPersistido?> ObterPorNumeroAsync(
            decimal clNo, decimal clEstab, string numeroInterno, CancellationToken cancellationToken) =>
            Task.FromResult(Pedido);

        public Task<IReadOnlyList<ClientePmPedidoPersistido>> ListarStaffAsync(
            string? filtroEstado, int top, CancellationToken cancellationToken) =>
            Task.FromResult<IReadOnlyList<ClientePmPedidoPersistido>>(
                Pedido is null ? [] : [Pedido]);

        public Task<ClientePmPedidoPersistido?> ObterPorIdStaffAsync(
            long pedidoId, bool incluirLinhas, CancellationToken cancellationToken) =>
            Task.FromResult(Pedido);

        public Task<ClientePmIntegracaoResult> TryMarcarIntegradoAsync(
            long pedidoId, string bostamp, decimal obrano, decimal boano, decimal ndos,
            string? decididoPor, CancellationToken cancellationToken)
        {
            MarcarIntegradoCalls++;
            return Task.FromResult(
                OnMarcarIntegrado?.Invoke() ?? new ClientePmIntegracaoResult(false, Pedido));
        }

        public Task<ClientePmIntegracaoResult> TryRejeitarAsync(
            long pedidoId, string? motivo, string? decididoPor, CancellationToken cancellationToken) =>
            Task.FromResult(OnRejeitar?.Invoke() ?? new ClientePmIntegracaoResult(false, Pedido));

        public Task<ClientePmIntegracaoResult> TryAtualizarPrecosOperadorAsync(
            long pedidoId,
            IReadOnlyList<(int LinhaOrd, decimal PrecoUnitario)> precos,
            CancellationToken cancellationToken) =>
            Task.FromResult(new ClientePmIntegracaoResult(false, Pedido));

        public Task<ClientePmIntegracaoResult> TryClaimAprovacaoAsync(
            long pedidoId, CancellationToken cancellationToken) =>
            Task.FromResult(new ClientePmIntegracaoResult(false, Pedido));
    }
}
