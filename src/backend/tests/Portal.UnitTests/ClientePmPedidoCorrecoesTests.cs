using Microsoft.Extensions.Logging.Abstractions;
using Microsoft.Extensions.Options;
using Portal.Application.Cliente;
using Portal.Infrastructure.Cliente;
using Portal.Infrastructure.Options;

namespace Portal.UnitTests;

/// <summary>Correções P1–P7 (unitários; sem SQL Server real).</summary>
public class ClientePmPedidoCorrecoesTests
{
    [Fact]
    public void P1_P2_Classify_outro_cliente_nao_devolve_same_hash()
    {
        var kind = ClientePmIdempotencyResolve.Classify(
            callerClNo: 1,
            callerClEstab: 0,
            existingClNo: 99,
            existingClEstab: 0,
            existingNumeroInterno: "PM-2026-000001",
            existingHash: "abc",
            requestHash: "abc");
        Assert.Equal(ClientePmIdempotencyResolve.OutcomeKind.OtherClientOrEstab, kind);
    }

    [Fact]
    public void P2_Classify_mesmo_cliente_hash_diferente_e_409_semantico()
    {
        var kind = ClientePmIdempotencyResolve.Classify(
            10, 0, 10, 0, "PM-2026-000002", "hash-a", "hash-b");
        Assert.Equal(ClientePmIdempotencyResolve.OutcomeKind.SameClientDifferentHash, kind);
    }

    [Fact]
    public void P2_Classify_mesmo_cliente_mesmo_hash()
    {
        var kind = ClientePmIdempotencyResolve.Classify(
            10, 1, 10, 1, "PM-2026-000003", "deadbeef", "DEADBEEF");
        Assert.Equal(ClientePmIdempotencyResolve.OutcomeKind.SameClientSameHash, kind);
    }

    [Fact]
    public void P2_Classify_estab_diferente_e_outro_cliente()
    {
        var kind = ClientePmIdempotencyResolve.Classify(
            10, 0, 10, 1, "PM-2026-000004", "h", "h");
        Assert.Equal(ClientePmIdempotencyResolve.OutcomeKind.OtherClientOrEstab, kind);
    }

    [Fact]
    public void P3_LinhaOrd_duplicado_rejeitado_antes_persistencia()
    {
        var err = ClientePedidoSubmitRules.ValidateLinhasOrError(
        [
            new ClientePedidoLinhaInput(1, "A", 1m, ""),
            new ClientePedidoLinhaInput(1, "B", 2m, "")
        ]);
        Assert.NotNull(err);
        Assert.Contains("duplicado", err, StringComparison.OrdinalIgnoreCase);
    }

    [Fact]
    public void P3_Linhas_validas_ok()
    {
        Assert.Null(ClientePedidoSubmitRules.ValidateLinhasOrError(
        [
            new ClientePedidoLinhaInput(1, "A", 1m, ""),
            new ClientePedidoLinhaInput(2, "B", 2m, "x")
        ]));
    }

    [Fact]
    public void P5_Unique_idempotency_detectada_pelo_nome_da_constraint()
    {
        Assert.True(ClientePmSqlErrorRules.IsIdempotencyKeyUniqueViolation(
            2627,
            "Violation of UNIQUE KEY constraint 'UQ_u_HcaPmPedido_IdemKey'."));
        Assert.False(ClientePmSqlErrorRules.IsIdempotencyKeyUniqueViolation(
            2627,
            "Violation of UNIQUE KEY constraint 'UQ_u_HcaPmPedido_NumeroInterno'."));
        Assert.False(ClientePmSqlErrorRules.IsIdempotencyKeyUniqueViolation(547, "FK fail"));
    }

    [Fact]
    public void P4_Missing_table_208_u_HcaPmPedido_e_seguro_omitir()
    {
        Assert.True(ClientePmSqlErrorRules.IsMissingPmPedidoObject(
            208, "Invalid object name 'dbo.u_HcaPmPedido'."));
        Assert.False(ClientePmSqlErrorRules.IsMissingPmPedidoObject(
            4060, "Cannot open database"));
        Assert.False(ClientePmSqlErrorRules.IsMissingPmPedidoObject(
            -2, "Timeout expired"));
    }

    [Fact]
    public void P7_Idempotency_key_max_64()
    {
        Assert.Equal(64, ClientePedidoSubmitRules.IdempotencyKeyMaxLength);
        Assert.True(ClientePedidoSubmitRules.IsIdempotencyKeyLengthValid(new string('a', 64)));
        Assert.False(ClientePedidoSubmitRules.IsIdempotencyKeyLengthValid(new string('a', 65)));
        Assert.False(ClientePedidoSubmitRules.IsIdempotencyKeyLengthValid("  "));
    }

    [Fact]
    public async Task Flag_ON_cria_interno_sem_chamar_legado_SP()
    {
        var store = new FakePmStore();
        var catalogo = new FakeCatalogo();
        var svc = new ClientePedidosService(
            Options.Create(new PhcOptions { ConnectionString = "Server=(invalid);Database=none;Connection Timeout=1" }),
            Options.Create(new PortalClienteOptions { PedidosInternosEnabled = true }),
            store,
            catalogo,
            NullLogger<ClientePedidosService>.Instance);

        var result = await svc.CriarAsync(
            1911, 0, "key-flag-on-test",
            [new ClientePedidoLinhaInput(1, "1310", 2m, "")],
            CancellationToken.None);

        Assert.Equal(ClientePedidoEstadoMapper.OrigemInterno, result.Origem);
        Assert.Equal(1, store.CriarCalls);
        Assert.Equal("PM-2026-000001", result.NumeroInterno);
        Assert.Equal("recebido", result.EstadoCodigo);
        Assert.Null(result.Bostamp);
    }

    [Fact]
    public async Task Flag_OFF_nao_chama_store_interno()
    {
        var store = new FakePmStore();
        var catalogo = new FakeCatalogo();
        var svc = new ClientePedidosService(
            Options.Create(new PhcOptions
            {
                ConnectionString =
                    "Server=127.0.0.1,1;Database=none;User Id=x;Password=y;Encrypt=False;Connection Timeout=1"
            }),
            Options.Create(new PortalClienteOptions { PedidosInternosEnabled = false }),
            store,
            catalogo,
            NullLogger<ClientePedidosService>.Instance);

        await Assert.ThrowsAnyAsync<Exception>(() =>
            svc.CriarAsync(
                1911, 0, "key-flag-off",
                [new ClientePedidoLinhaInput(1, "1310", 1m, "")],
                CancellationToken.None));

        Assert.Equal(0, store.CriarCalls);
    }

    [Fact]
    public async Task P3_Servico_rejeita_LinhaOrd_duplicado_com_PortalBusinessException()
    {
        var svc = new ClientePedidosService(
            Options.Create(new PhcOptions { ConnectionString = "Server=(invalid)" }),
            Options.Create(new PortalClienteOptions { PedidosInternosEnabled = true }),
            new FakePmStore(),
            new FakeCatalogo(),
            NullLogger<ClientePedidosService>.Instance);

        var ex = await Assert.ThrowsAsync<Portal.Application.Encomendas.PortalBusinessException>(() =>
            svc.CriarAsync(
                1, 0, "k",
                [
                    new ClientePedidoLinhaInput(1, "A", 1m, ""),
                    new ClientePedidoLinhaInput(1, "B", 1m, "")
                ],
                CancellationToken.None));

        Assert.Equal(400, ex.StatusCode);
        Assert.Contains("duplicado", ex.Message, StringComparison.OrdinalIgnoreCase);
    }

    private sealed class FakePmStore : IClientePmPedidoStore
    {
        public int CriarCalls { get; private set; }

        public Task<ClientePmCreateOutcome> CriarAsync(
            decimal clNo,
            decimal clEstab,
            string idempotencyKey,
            string payloadHash,
            IReadOnlyList<ClientePmLinhaPersistida> linhas,
            CancellationToken cancellationToken)
        {
            CriarCalls++;
            var now = new DateTime(2026, 10, 20, 12, 0, 0, DateTimeKind.Utc);
            var pedido = new ClientePmPedidoPersistido(
                1,
                "PM-2026-000001",
                clNo,
                clEstab,
                "recebido",
                now,
                now,
                linhas.Sum(l => l.TotalLinha),
                payloadHash,
                linhas);
            return Task.FromResult(new ClientePmCreateOutcome(false, pedido));
        }

        public Task<IReadOnlyList<ClientePmPedidoPersistido>> ListarAsync(
            decimal clNo, decimal clEstab, int top, CancellationToken cancellationToken) =>
            Task.FromResult<IReadOnlyList<ClientePmPedidoPersistido>>([]);

        public Task<ClientePmPedidoPersistido?> ObterPorIdAsync(
            decimal clNo, decimal clEstab, long pedidoId, CancellationToken cancellationToken) =>
            Task.FromResult<ClientePmPedidoPersistido?>(null);

        public Task<ClientePmPedidoPersistido?> ObterPorNumeroAsync(
            decimal clNo, decimal clEstab, string numeroInterno, CancellationToken cancellationToken) =>
            Task.FromResult<ClientePmPedidoPersistido?>(null);

        public Task<IReadOnlyList<ClientePmPedidoPersistido>> ListarStaffAsync(
            string? filtroEstado, int top, CancellationToken cancellationToken) =>
            Task.FromResult<IReadOnlyList<ClientePmPedidoPersistido>>([]);

        public Task<ClientePmPedidoPersistido?> ObterPorIdStaffAsync(
            long pedidoId, bool incluirLinhas, CancellationToken cancellationToken) =>
            Task.FromResult<ClientePmPedidoPersistido?>(null);

        public Task<ClientePmIntegracaoResult> TryMarcarIntegradoAsync(
            long pedidoId,
            string bostamp,
            decimal obrano,
            decimal boano,
            decimal ndos,
            string? decididoPor,
            CancellationToken cancellationToken) =>
            Task.FromResult(new ClientePmIntegracaoResult(false, null));

        public Task<ClientePmIntegracaoResult> TryRejeitarAsync(
            long pedidoId,
            string? motivo,
            string? decididoPor,
            CancellationToken cancellationToken) =>
            Task.FromResult(new ClientePmIntegracaoResult(false, null));

        public Task<ClientePmIntegracaoResult> TryAtualizarPrecosOperadorAsync(
            long pedidoId,
            IReadOnlyList<(int LinhaOrd, decimal PrecoUnitario)> precos,
            CancellationToken cancellationToken) =>
            Task.FromResult(new ClientePmIntegracaoResult(false, null));

        public Task<ClientePmIntegracaoResult> TryClaimAprovacaoAsync(
            long pedidoId, CancellationToken cancellationToken) =>
            Task.FromResult(new ClientePmIntegracaoResult(false, null));
    }

    private sealed class FakeCatalogo : IClienteCatalogoQuery
    {
        public Task<ClienteArtigoDto?> GetArtigoAsync(
            decimal clNo, decimal clEstab, string referencia, CancellationToken cancellationToken) =>
            Task.FromResult<ClienteArtigoDto?>(
                new ClienteArtigoDto(referencia.Trim(), "Design", 10.5m, false, false));

        public Task<ClienteArtigoImagemDto?> GetArtigoImagemAsync(
            decimal clNo, decimal clEstab, string referencia, CancellationToken cancellationToken) =>
            Task.FromResult<ClienteArtigoImagemDto?>(null);
    }
}
