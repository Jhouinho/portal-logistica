using Microsoft.Extensions.Logging.Abstractions;
using Microsoft.Extensions.Options;
using Portal.Application.Cliente;
using Portal.Application.Encomendas;
using Portal.Infrastructure.Cliente;
using Portal.Infrastructure.Options;

namespace Portal.UnitTests;

public class StaffPmPrecosTests
{
    [Fact]
    public void PrecoSubmissao_preservado_na_semantica_de_linha()
    {
        var linha = new ClientePmLinhaPersistida(
            1, "1051", "Art", "", 2m, PrecoUnitario: 9.5m, TotalLinha: 19m, PrecoSubmissao: 1.5m);

        Assert.Equal(1.5m, linha.PrecoSubmissao);
        Assert.Equal(9.5m, linha.PrecoUnitario);
        Assert.Equal(19m, linha.TotalLinha);
    }

    [Fact]
    public void TotalLinha_reflete_qtt_vezes_preco_operador()
    {
        Assert.Equal(19m, StaffPmPrecoRules.CalcTotalLinha(2m, 9.5m));
        Assert.Equal(37.037037m, StaffPmPrecoRules.CalcTotalLinha(3m, 12.345679m));
    }

    [Theory]
    [InlineData(-1)]
    [InlineData(-0.01)]
    public void Validate_rejeita_preco_negativo(decimal preco)
    {
        var linhas = new[] { new ClientePmLinhaPersistida(1, "A", "d", "", 1m, 1m, 1m, 1m) };
        var err = StaffPmPrecoRules.ValidatePrecosOperador(linhas, [(1, preco)]);
        Assert.NotNull(err);
        Assert.Contains("negativ", err, StringComparison.OrdinalIgnoreCase);
    }

    [Fact]
    public void Validate_rejeita_preco_acima_do_maximo()
    {
        var linhas = new[] { new ClientePmLinhaPersistida(1, "A", "d", "", 1m, 1m, 1m, 1m) };
        var err = StaffPmPrecoRules.ValidatePrecosOperador(
            linhas, [(1, StaffPmPrecoRules.PrecoMaximo + 1)]);
        Assert.NotNull(err);
    }

    [Fact]
    public void CanEditPrecos_apenas_pendente()
    {
        Assert.True(StaffPmPrecoRules.CanEditPrecos("recebido", null));
        Assert.True(StaffPmPrecoRules.CanEditPrecos("em_analise", null));
        Assert.False(StaffPmPrecoRules.CanEditPrecos("rejeitado", null));
        Assert.False(StaffPmPrecoRules.CanEditPrecos("integrado", "STAMP"));
        Assert.False(StaffPmPrecoRules.CanEditPrecos("recebido", "STAMP"));
    }

    [Fact]
    public async Task GuardarPrecos_rejeitado_falha_409()
    {
        var store = new FakeStaffPrecoStore
        {
            Pedido = MakePedido("rejeitado", bostamp: null, precoOp: 1.5m, precoSub: 1.5m)
        };
        var svc = CreateService(store);
        var ex = await Assert.ThrowsAsync<PortalBusinessException>(() =>
            svc.GuardarPrecosAsync(1, [new StaffPmPrecoLinhaRequest(1, 2m)], CancellationToken.None));
        Assert.Equal(409, ex.StatusCode);
        Assert.Equal(0, store.AtualizarPrecosCalls);
    }

    [Fact]
    public async Task GuardarPrecos_integrado_falha_409()
    {
        var store = new FakeStaffPrecoStore
        {
            Pedido = MakePedido("integrado", bostamp: "X", precoOp: 1.5m, precoSub: 1.5m)
        };
        var svc = CreateService(store);
        var ex = await Assert.ThrowsAsync<PortalBusinessException>(() =>
            svc.GuardarPrecosAsync(1, [new StaffPmPrecoLinhaRequest(1, 2m)], CancellationToken.None));
        Assert.Equal(409, ex.StatusCode);
    }

    [Fact]
    public async Task GuardarPrecos_pendente_actualiza_e_preserva_submissao()
    {
        var store = new FakeStaffPrecoStore
        {
            Pedido = MakePedido("recebido", bostamp: null, precoOp: 1.5m, precoSub: 1.5m)
        };
        var svc = CreateService(store);
        var r = await svc.GuardarPrecosAsync(
            1, [new StaffPmPrecoLinhaRequest(1, 9.5m)], CancellationToken.None);

        Assert.Equal(1, store.AtualizarPrecosCalls);
        Assert.Single(r.Linhas);
        Assert.Equal(1.5m, r.Linhas[0].PrecoSubmissao);
        Assert.Equal(9.5m, r.Linhas[0].PrecoUnitario);
        Assert.Equal(19m, r.Linhas[0].TotalLinha);
        Assert.Equal(19m, r.Etotaldeb);
        Assert.True(r.PodeEditarPrecos);
    }

    [Fact]
    public async Task GuardarPrecos_valor_invalido_nao_chama_store()
    {
        var store = new FakeStaffPrecoStore
        {
            Pedido = MakePedido("recebido", bostamp: null, precoOp: 1.5m, precoSub: 1.5m)
        };
        var svc = CreateService(store);
        var ex = await Assert.ThrowsAsync<PortalBusinessException>(() =>
            svc.GuardarPrecosAsync(1, [new StaffPmPrecoLinhaRequest(1, -3m)], CancellationToken.None));
        Assert.Contains("negativ", ex.Message, StringComparison.OrdinalIgnoreCase);
        Assert.Equal(0, store.AtualizarPrecosCalls);
    }

    [Fact]
    public void Tvp_staff_envia_preco_operador_persistido()
    {
        var linhas = new[]
        {
            new ClientePmLinhaPersistida(1, "1051", "A", "azul", 2m, 9.5m, 19m, 1.5m)
        };
        var tvp = PedidoMobileLinhaTvp.BuildStaffComPrecoOperador(linhas);
        Assert.Equal(5, tvp.Columns.Count);
        Assert.True(tvp.Columns.Contains("edebito"));
        Assert.Equal(9.5m, (decimal)tvp.Rows[0]["edebito"]);
        Assert.NotEqual(1.5m, (decimal)tvp.Rows[0]["edebito"]);
    }

    [Fact]
    public void Tvp_legado_envia_edebito_null()
    {
        var tvp = PedidoMobileLinhaTvp.BuildLegado([(1, "1051", 1m, "")]);
        Assert.True(tvp.Columns.Contains("edebito"));
        Assert.Equal(DBNull.Value, tvp.Rows[0]["edebito"]);
    }

    [Fact]
    public async Task Aprovar_rejeitado_nao_cria_dossier()
    {
        var store = new FakeStaffPrecoStore
        {
            Pedido = MakePedido("rejeitado", bostamp: null, precoOp: 9.5m, precoSub: 1.5m)
        };
        var svc = CreateService(store);
        var ex = await Assert.ThrowsAsync<PortalBusinessException>(() =>
            svc.AprovarAsync(1, "ADM", "admin", CancellationToken.None));
        Assert.Equal(409, ex.StatusCode);
        Assert.Equal(0, store.MarcarIntegradoCalls);
    }

    [Fact]
    public async Task Segunda_aprovacao_integrado_nao_marca_nem_recria()
    {
        var store = new FakeStaffPrecoStore
        {
            Pedido = MakePedido("integrado", bostamp: "STAMP1", precoOp: 9.5m, precoSub: 1.5m,
                obrano: 10, boano: 2026, ndos: 67)
        };
        var svc = CreateService(store);
        var r = await svc.AprovarAsync(1, "ADM", "admin", CancellationToken.None);
        Assert.True(r.AlreadyIntegrated);
        Assert.Equal("STAMP1", r.Bostamp);
        Assert.Equal(0, store.MarcarIntegradoCalls);
    }

    [Fact]
    public async Task Recover_apos_falha_reconcile_nao_chama_sp_nem_altera_precos()
    {
        var store = new FakeStaffPrecoStore
        {
            Pedido = MakePedido("recebido", bostamp: "RECON", precoOp: 9.5m, precoSub: 1.5m,
                obrano: 5, boano: 2026, ndos: 67)
        };
        store.OnMarcarIntegrado = () =>
        {
            store.Pedido = MakePedido("integrado", bostamp: "RECON", precoOp: 9.5m, precoSub: 1.5m,
                obrano: 5, boano: 2026, ndos: 67);
            return new ClientePmIntegracaoResult(true, store.Pedido);
        };
        var svc = CreateService(store);
        var r = await svc.AprovarAsync(1, "ADM", "admin", CancellationToken.None);
        Assert.Equal("RECON", r.Bostamp);
        Assert.True(r.AlreadyExistsBo);
        Assert.Equal(0, store.AtualizarPrecosCalls);
        Assert.Equal(9.5m, store.Pedido!.Linhas![0].PrecoUnitario);
        Assert.Equal(1.5m, store.Pedido.Linhas[0].PrecoSubmissao);
    }

    [Fact]
    public void Circuito_armazem_ndos_distinto_de_67()
    {
        var opt = new PortalClienteOptions();
        Assert.Equal(67, opt.PedidoMobileNdos);
        Assert.DoesNotContain(opt.PedidoMobileNdos, new decimal[] { 1, 66, 65 });
    }

    private static StaffPmPedidosService CreateService(FakeStaffPrecoStore store) =>
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
        decimal precoOp,
        decimal precoSub,
        decimal? obrano = null,
        decimal? boano = null,
        decimal? ndos = null)
    {
        var now = new DateTime(2026, 10, 21, 10, 0, 0, DateTimeKind.Utc);
        var total = StaffPmPrecoRules.CalcTotalLinha(2m, precoOp);
        var linhas = new List<ClientePmLinhaPersistida>
        {
            new(1, "1051", "Art", "", 2m, precoOp, total, precoSub)
        };
        return new ClientePmPedidoPersistido(
            1,
            "PM-2026-000001",
            100,
            0,
            estado,
            now,
            now,
            total,
            "hash",
            linhas,
            bostamp,
            obrano,
            boano,
            ndos,
            null,
            null,
            null,
            "Cliente Teste");
    }

    private sealed class FakeStaffPrecoStore : IClientePmPedidoStore
    {
        public ClientePmPedidoPersistido? Pedido { get; set; }
        public int MarcarIntegradoCalls { get; private set; }
        public int AtualizarPrecosCalls { get; private set; }
        public Func<ClientePmIntegracaoResult>? OnMarcarIntegrado { get; set; }

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


        public Task<ClientePmIntegracaoResult> TryAvancarEstadoOperacionalAsync(
            long pedidoId, string estadoDestino, string? decididoPor, CancellationToken cancellationToken) =>
            Task.FromResult(new ClientePmIntegracaoResult(false, Pedido));

        public Task<ClientePmIntegracaoResult> TryRejeitarAsync(
            long pedidoId, string? motivo, string? decididoPor, CancellationToken cancellationToken) =>
            Task.FromResult(new ClientePmIntegracaoResult(false, Pedido));

        public Task<ClientePmIntegracaoResult> TryAtualizarPrecosOperadorAsync(
            long pedidoId,
            IReadOnlyList<(int LinhaOrd, decimal PrecoUnitario)> precos,
            CancellationToken cancellationToken)
        {
            AtualizarPrecosCalls++;
            if (Pedido is null || !StaffPmPrecoRules.CanEditPrecos(Pedido.EstadoInterno, Pedido.Bostamp))
                return Task.FromResult(new ClientePmIntegracaoResult(false, Pedido));

            var linhas = Pedido.Linhas!.Select(l =>
            {
                var p = precos.First(x => x.LinhaOrd == l.LinhaOrd).PrecoUnitario;
                var total = StaffPmPrecoRules.CalcTotalLinha(l.Qtt, p);
                return l with
                {
                    PrecoUnitario = StaffPmPrecoRules.RoundPreco(p),
                    TotalLinha = total,
                    PrecoSubmissao = l.PrecoSubmissao
                };
            }).ToList();

            Pedido = Pedido with
            {
                Linhas = linhas,
                Etotaldeb = linhas.Sum(x => x.TotalLinha)
            };
            return Task.FromResult(new ClientePmIntegracaoResult(true, Pedido));
        }

        public Task<ClientePmIntegracaoResult> TrySubstituirLinhasOperadorAsync(
            long pedidoId,
            IReadOnlyList<StaffPmLinhaEditRequest> linhas,
            CancellationToken cancellationToken)
        {
            if (Pedido is null || !StaffPmPrecoRules.CanEditPrecos(Pedido.EstadoInterno, Pedido.Bostamp))
                return Task.FromResult(new ClientePmIntegracaoResult(false, Pedido));

            var built = StaffPmPrecoRules.BuildLinhasSubstituicao(
                Pedido.Linhas ?? Array.Empty<ClientePmLinhaPersistida>(), linhas);
            Pedido = Pedido with
            {
                Linhas = built.ToList(),
                Etotaldeb = built.Sum(x => x.TotalLinha)
            };
            return Task.FromResult(new ClientePmIntegracaoResult(true, Pedido));
        }

        public Task<ClientePmIntegracaoResult> TryClaimAprovacaoAsync(
            long pedidoId, CancellationToken cancellationToken) =>
            Task.FromResult(new ClientePmIntegracaoResult(false, Pedido));
    }
}
