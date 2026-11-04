using System.Security.Claims;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Identity;
using Microsoft.Extensions.Logging.Abstractions;
using Microsoft.Extensions.Options;
using Portal.Api.Cliente;
using Portal.Api.Controllers;
using Portal.Application.Cliente;
using Portal.Infrastructure.Cliente;
using Portal.Infrastructure.Options;

namespace Portal.UnitTests;

public class ClientePedidoIsolamentoTests
{
    [Fact]
    public async Task Obter_pedido_de_outro_cliente_devolve_null()
    {
        var store = new FakePmStore();
        store.ById[(999, 0, 21)] = MakePedido(21, clNo: 999, clEstab: 0);
        var svc = CreateService(store);

        var d = await svc.ObterAsync(6065, 0, "21", CancellationToken.None);

        Assert.Null(d);
        Assert.Contains((6065m, 0m, 21L), store.ObterPorIdCalls);
    }

    [Fact]
    public async Task Obter_pedido_do_proprio_cliente_devolve_detalhe()
    {
        var store = new FakePmStore();
        store.ById[(6065, 0, 21)] = MakePedido(21, clNo: 6065, clEstab: 0);
        var svc = CreateService(store);

        var d = await svc.ObterAsync(6065, 0, "21", CancellationToken.None);

        Assert.NotNull(d);
        Assert.Equal(21, d!.PedidoId);
        Assert.Equal("PM-2026-000021", d.NumeroInterno);
    }

    [Fact]
    public async Task Obter_por_numero_interno_respeita_clNo_estab()
    {
        var store = new FakePmStore();
        store.ByNumero[("PM-2026-000021", 999, 0)] = MakePedido(21, clNo: 999, clEstab: 0);
        var svc = CreateService(store);

        Assert.Null(await svc.ObterAsync(6065, 0, "PM-2026-000021", CancellationToken.None));
        Assert.Contains(("PM-2026-000021", 6065m, 0m), store.ObterPorNumeroCalls);
    }

    [Fact]
    public async Task Obter_PM_inexistente_devolve_null_sem_cair_em_legado()
    {
        var store = new FakePmStore();
        var svc = CreateService(store);
        Assert.Null(await svc.ObterAsync(6065, 0, "PM-2026-000999", CancellationToken.None));
        Assert.Contains(("PM-2026-000999", 6065m, 0m), store.ObterPorNumeroCalls);
        Assert.Empty(store.ObterPorIdCalls);
    }

    [Fact]
    public async Task Obter_id_vazio_ou_malformado_nao_consulta_store_interno()
    {
        var store = new FakePmStore();
        var svc = CreateService(store);
        Assert.Null(await svc.ObterAsync(6065, 0, "  ", CancellationToken.None));
        Assert.Null(await svc.ObterAsync(6065, 0, "PM-XX", CancellationToken.None));
        Assert.Empty(store.ObterPorIdCalls);
        Assert.Empty(store.ObterPorNumeroCalls);
    }

    [Fact]
    public async Task Cancelar_interno_inexistente_ou_outro_cliente_nao_tenta_legado()
    {
        var store = new FakePmStore();
        store.ById[(999, 0, 21)] = MakePedido(21, clNo: 999, clEstab: 0);
        var svc = CreateService(store);

        var (okOutro, errOutro) = await svc.CancelarAsync(6065, 0, "21", CancellationToken.None);
        Assert.False(okOutro);
        Assert.Equal("nao_encontrado", errOutro);

        var (okPm, errPm) = await svc.CancelarAsync(6065, 0, "PM-2026-000021", CancellationToken.None);
        Assert.False(okPm);
        Assert.Equal("nao_encontrado", errPm);
    }

    [Fact]
    public async Task Cancelar_interno_proprio_continua_proibido()
    {
        var store = new FakePmStore();
        store.ById[(6065, 0, 21)] = MakePedido(21, clNo: 6065, clEstab: 0);
        var svc = CreateService(store);

        var (ok, err) = await svc.CancelarAsync(6065, 0, "21", CancellationToken.None);
        Assert.False(ok);
        Assert.Equal("interno_proibido", err);
    }

    [Fact]
    public async Task Listar_passa_clNo_estab_do_caller_ao_store()
    {
        var store = new FakePmStore();
        store.ListResult = [MakePedido(20, clNo: 6065, clEstab: 0)];
        var svc = CreateService(store);

        try
        {
            await svc.ListarAsync(6065, 0, 10, CancellationToken.None);
        }
        catch
        {
            // ListarLegado requer SQL; o store já deve ter sido chamado com o caller.
        }

        Assert.Contains((6065m, 0m, 10), store.ListarCalls);
    }

    [Fact]
    public void TryGetCliente_sem_claims_falha()
    {
        Assert.False(ClienteSession.TryGetCliente(new ClaimsPrincipal(), out _, out _));
    }

    [Fact]
    public void TryGetCliente_le_claims_cl_no_estab()
    {
        var user = new ClaimsPrincipal(new ClaimsIdentity(
        [
            new Claim(ClienteAuthConstants.ClaimNo, "6065"),
            new Claim(ClienteAuthConstants.ClaimEstab, "0"),
        ], ClienteAuthConstants.CookieScheme));

        Assert.True(ClienteSession.TryGetCliente(user, out var no, out var estab));
        Assert.Equal(6065m, no);
        Assert.Equal(0m, estab);
    }

    [Fact]
    public void Controllers_cliente_exigem_scheme_cliente_staff_nao()
    {
        var cliente = typeof(ClientePedidosController)
            .GetCustomAttributes(typeof(AuthorizeAttribute), true)
            .Cast<AuthorizeAttribute>()
            .First();
        Assert.Equal(ClienteAuthConstants.CookieScheme, cliente.AuthenticationSchemes);
        Assert.Equal(ClienteAuthConstants.PolicyName, cliente.Policy);

        var artigos = typeof(ClienteArtigosController)
            .GetCustomAttributes(typeof(AuthorizeAttribute), true)
            .Cast<AuthorizeAttribute>()
            .First();
        Assert.Equal(ClienteAuthConstants.CookieScheme, artigos.AuthenticationSchemes);

        var staff = typeof(StaffPmPedidosController)
            .GetCustomAttributes(typeof(AuthorizeAttribute), true)
            .Cast<AuthorizeAttribute>()
            .First();
        Assert.NotEqual(ClienteAuthConstants.CookieScheme, staff.AuthenticationSchemes ?? "");
        Assert.True(string.IsNullOrEmpty(staff.AuthenticationSchemes)
                    || staff.AuthenticationSchemes == IdentityConstants.ApplicationScheme);
    }

    [Fact]
    public void Idempotency_outro_cliente_classificado_sem_expor_dados()
    {
        var kind = ClientePmIdempotencyResolve.Classify(
            1, 0, 2, 0, "PM-2026-000099", "h", "h");
        Assert.Equal(ClientePmIdempotencyResolve.OutcomeKind.OtherClientOrEstab, kind);
    }

    private static ClientePedidosService CreateService(FakePmStore store)
    {
        var phc = Options.Create(new PhcOptions { ConnectionString = "Server=(localdb)\\none;Database=none;" });
        var cliente = Options.Create(new PortalClienteOptions
        {
            PedidosInternosEnabled = true,
            PedidoMobileNdos = 67
        });
        return new ClientePedidosService(
            phc,
            cliente,
            store,
            new FakeCatalogo(),
            NullLogger<ClientePedidosService>.Instance);
    }

    private static ClientePmPedidoPersistido MakePedido(long id, decimal clNo, decimal clEstab)
    {
        var now = new DateTime(2026, 10, 28, 12, 0, 0, DateTimeKind.Utc);
        return new ClientePmPedidoPersistido(
            PedidoId: id,
            NumeroInterno: $"PM-2026-{id:D6}",
            ClNo: clNo,
            ClEstab: clEstab,
            EstadoInterno: "recebido",
            DataSubmissao: now,
            DataAlteracao: now,
            Etotaldeb: 13m,
            SubmissaoPayloadHash: "hash",
            Linhas:
            [
                new ClientePmLinhaPersistida(1, "1051", "X", "", 2m, 6.5m, 13m, 6.5m)
            ]);
    }

    private sealed class FakeCatalogo : IClienteCatalogoQuery
    {
        public Task<ClienteArtigoDto?> GetArtigoAsync(
            decimal clNo, decimal clEstab, string referencia, CancellationToken cancellationToken) =>
            Task.FromResult<ClienteArtigoDto?>(null);

        public Task<ClienteArtigoImagemDto?> GetArtigoImagemAsync(
            decimal clNo, decimal clEstab, string referencia, CancellationToken cancellationToken) =>
            Task.FromResult<ClienteArtigoImagemDto?>(null);
    }

    private sealed class FakePmStore : IClientePmPedidoStore
    {
        public Dictionary<(decimal ClNo, decimal ClEstab, long Id), ClientePmPedidoPersistido> ById { get; } = new();
        public Dictionary<(string Numero, decimal ClNo, decimal ClEstab), ClientePmPedidoPersistido> ByNumero { get; } = new();
        public List<ClientePmPedidoPersistido> ListResult { get; set; } = [];
        public List<(decimal, decimal, long)> ObterPorIdCalls { get; } = [];
        public List<(string, decimal, decimal)> ObterPorNumeroCalls { get; } = [];
        public List<(decimal, decimal, int)> ListarCalls { get; } = [];

        public Task<ClientePmCreateOutcome> CriarAsync(
            decimal clNo, decimal clEstab, string idempotencyKey, string payloadHash,
            IReadOnlyList<ClientePmLinhaPersistida> linhas, CancellationToken cancellationToken) =>
            throw new NotImplementedException();

        public Task<IReadOnlyList<ClientePmPedidoPersistido>> ListarAsync(
            decimal clNo, decimal clEstab, int top, CancellationToken cancellationToken)
        {
            ListarCalls.Add((clNo, clEstab, top));
            return Task.FromResult<IReadOnlyList<ClientePmPedidoPersistido>>(
                ListResult.Where(p => p.ClNo == clNo && p.ClEstab == clEstab).Take(top).ToList());
        }

        public Task<ClientePmPedidoPersistido?> ObterPorIdAsync(
            decimal clNo, decimal clEstab, long pedidoId, CancellationToken cancellationToken)
        {
            ObterPorIdCalls.Add((clNo, clEstab, pedidoId));
            ById.TryGetValue((clNo, clEstab, pedidoId), out var p);
            return Task.FromResult(p);
        }

        public Task<ClientePmPedidoPersistido?> ObterPorNumeroAsync(
            decimal clNo, decimal clEstab, string numeroInterno, CancellationToken cancellationToken)
        {
            var key = numeroInterno.ToUpperInvariant();
            ObterPorNumeroCalls.Add((key, clNo, clEstab));
            ByNumero.TryGetValue((key, clNo, clEstab), out var p);
            return Task.FromResult(p);
        }

        public Task<IReadOnlyList<ClientePmPedidoPersistido>> ListarStaffAsync(
            string? filtroEstado, int top, CancellationToken cancellationToken) =>
            Task.FromResult<IReadOnlyList<ClientePmPedidoPersistido>>([]);

        public Task<ClientePmPedidoPersistido?> ObterPorIdStaffAsync(
            long pedidoId, bool incluirLinhas, CancellationToken cancellationToken) =>
            Task.FromResult<ClientePmPedidoPersistido?>(null);

        public Task<ClientePmIntegracaoResult> TryClaimAprovacaoAsync(
            long pedidoId, CancellationToken cancellationToken) =>
            Task.FromResult(new ClientePmIntegracaoResult(false, null));

        public Task<ClientePmIntegracaoResult> TryMarcarIntegradoAsync(
            long pedidoId, string bostamp, decimal obrano, decimal boano, decimal ndos,
            string? decididoPor, CancellationToken cancellationToken) =>
            Task.FromResult(new ClientePmIntegracaoResult(false, null));

        public Task<ClientePmIntegracaoResult> TryAvancarEstadoOperacionalAsync(
            long pedidoId, string estadoDestino, string? decididoPor, CancellationToken cancellationToken) =>
            Task.FromResult(new ClientePmIntegracaoResult(false, null));

        public Task<ClientePmIntegracaoResult> TryRejeitarAsync(
            long pedidoId, string? motivo, string? decididoPor, CancellationToken cancellationToken) =>
            Task.FromResult(new ClientePmIntegracaoResult(false, null));

        public Task<ClientePmIntegracaoResult> TryAtualizarPrecosOperadorAsync(
            long pedidoId, IReadOnlyList<(int LinhaOrd, decimal PrecoUnitario)> precos,
            CancellationToken cancellationToken) =>
            Task.FromResult(new ClientePmIntegracaoResult(false, null));

        public Task<ClientePmIntegracaoResult> TrySubstituirLinhasOperadorAsync(
            long pedidoId, IReadOnlyList<StaffPmLinhaEditRequest> linhas,
            CancellationToken cancellationToken) =>
            Task.FromResult(new ClientePmIntegracaoResult(false, null));
    }
}
