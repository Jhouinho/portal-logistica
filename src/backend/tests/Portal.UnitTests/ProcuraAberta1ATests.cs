using Microsoft.Extensions.Options;
using Portal.Application.Encomendas;
using Portal.Domain.Encomendas;

namespace Portal.UnitTests;

/// <summary>
/// Paridade / paginação / stock da arquitectura 1A (Prev* só chaves da página).
/// </summary>
public sealed class ProcuraAberta1ATests
{
    private const string Dia = "Monday";
    private const string Hora = "12:00";
    private const string Fuso = "Europe/Lisbon";

    // Segunda 2026-08-10: antes das 12 → DP; às 12+ → AC (PlaneamentoCalculatorTests).
    private static readonly DateTime DataSegunda = new(2026, 8, 10);

    [Fact]
    public async Task Sem_pageSize_devolve_todos_os_grupos_com_stock()
    {
        var linhas = new[]
        {
            Linha("bi1", "bo1", 1, "1368", "", "Desc 1368", 10, 0, 10, urgente: false, hora: "11:00:00"),
            Linha("bi2", "bo2", 2, "1053", "", "Desc 1053", 5, 0, 5, urgente: true, hora: "13:00:00"),
        };
        var stockCalls = new List<IReadOnlyList<ArtigoRefCorChave>>();
        var sut = CreateSut(linhas, stockCalls, stock: new Dictionary<string, decimal>
        {
            [Key("1368", "")] = 20m,
            [Key("1053", "")] = 7m,
        });

        var result = await sut.ListarProcuraAbertaAsync(pageSize: null);

        Assert.Equal(2, result.TotalItems);
        Assert.Equal(2, result.Items.Count);
        Assert.Equal(1, result.Page);
        Assert.Equal(2, result.PageSize);
        Assert.Equal(20m, result.Items.Single(i => i.Ref == "1368").QuantidadeDisponivel);
        Assert.Equal(7m, result.Items.Single(i => i.Ref == "1053").QuantidadeDisponivel);
        Assert.Single(stockCalls);
        Assert.Equal(2, stockCalls[0].Count);
    }

    [Fact]
    public async Task PageSize_maior_ou_igual_total_equivale_a_lista_completa()
    {
        var linhas = BuildUniversoMisto();
        var stock = new Dictionary<string, decimal>
        {
            [Key("A", "")] = 11m,
            [Key("B", "X")] = 22m,
            [Key("C", "")] = 33m,
        };

        var sutAll = CreateSut(linhas, [], stock);
        var completo = await sutAll.ListarProcuraAbertaAsync(pageSize: null);

        var stockCalls = new List<IReadOnlyList<ArtigoRefCorChave>>();
        var sutPage = CreateSut(linhas, stockCalls, stock);
        var paged = await sutPage.ListarProcuraAbertaAsync(page: 1, pageSize: 200);

        Assert.Equal(completo.TotalItems, paged.TotalItems);
        Assert.Equal(completo.Items.Count, paged.Items.Count);
        AssertEqualItems(completo.Items, paged.Items);
        Assert.True(stockCalls[0].Count <= completo.Items.Count);
    }

    [Fact]
    public async Task Paginacao_parcial_preserva_ordem_e_limita_Prev_as_chaves_da_pagina()
    {
        var linhas = BuildUniversoMisto();
        var stock = new Dictionary<string, decimal>
        {
            [Key("A", "")] = 11m,
            [Key("B", "X")] = 22m,
            [Key("C", "")] = 33m,
        };

        var completo = await CreateSut(linhas, [], stock).ListarProcuraAbertaAsync(pageSize: null);
        Assert.True(completo.Items.Count >= 3);

        var stockCalls = new List<IReadOnlyList<ArtigoRefCorChave>>();
        var page1 = await CreateSut(linhas, stockCalls, stock)
            .ListarProcuraAbertaAsync(page: 1, pageSize: 2);

        Assert.Equal(completo.TotalItems, page1.TotalItems);
        Assert.Equal(2, page1.Items.Count);
        Assert.Equal(completo.Items[0].Ref, page1.Items[0].Ref);
        Assert.Equal(completo.Items[0].Cor, page1.Items[0].Cor);
        Assert.Equal(completo.Items[0].EstadoPlaneamentoCodigo, page1.Items[0].EstadoPlaneamentoCodigo);
        Assert.Equal(completo.Items[1].Ref, page1.Items[1].Ref);

        var chavesPedidas = stockCalls.Single()
            .Select(c => Key(c.Ref, c.Cor))
            .OrderBy(x => x, StringComparer.Ordinal)
            .ToList();
        var chavesEsperadas = page1.Items
            .Select(i => Key(i.Ref, i.Cor))
            .Distinct(StringComparer.Ordinal)
            .OrderBy(x => x, StringComparer.Ordinal)
            .ToList();
        Assert.Equal(chavesEsperadas, chavesPedidas);

        stockCalls.Clear();
        var page2 = await CreateSut(linhas, stockCalls, stock)
            .ListarProcuraAbertaAsync(page: 2, pageSize: 2);
        Assert.Equal(completo.Items.Skip(2).Take(2).Select(i => (i.Ref, i.Cor, i.EstadoPlaneamentoCodigo)).ToList(),
            page2.Items.Select(i => (i.Ref, i.Cor, i.EstadoPlaneamentoCodigo)).ToList());
    }

    [Fact]
    public async Task Mesmo_RefCor_em_DP_e_AC_gera_dois_grupos_e_um_calculo_de_stock()
    {
        var linhas = new[]
        {
            Linha("bi1", "bo1", 1, "X", "Y", "Mesmo", 3, 0, 3, hora: "11:00:00"), // DP
            Linha("bi2", "bo2", 2, "X", "Y", "Mesmo", 4, 0, 4, hora: "13:00:00"), // AC
        };
        var stockCalls = new List<IReadOnlyList<ArtigoRefCorChave>>();
        var sut = CreateSut(linhas, stockCalls, new Dictionary<string, decimal>
        {
            [Key("X", "Y")] = 99m,
        });

        var result = await sut.ListarProcuraAbertaAsync(pageSize: null);

        Assert.Equal(2, result.TotalItems);
        Assert.Equal(2, result.Items.Count);
        Assert.Contains(result.Items, i => i.EstadoPlaneamentoCodigo == "DP");
        Assert.Contains(result.Items, i => i.EstadoPlaneamentoCodigo == "AC");
        Assert.All(result.Items, i => Assert.Equal(99m, i.QuantidadeDisponivel));
        Assert.Single(stockCalls);
        Assert.Single(stockCalls[0]);
        Assert.Equal("X", stockCalls[0][0].Ref);
        Assert.Equal("Y", stockCalls[0][0].Cor);
    }

    [Fact]
    public async Task Filtro_q_e_estadoPlaneamento_DP()
    {
        var linhas = new[]
        {
            Linha("bi1", "bo1", 1, "1368", "", "A", 10, 0, 10, hora: "11:00:00"),
            Linha("bi2", "bo2", 2, "1368", "", "A", 2, 0, 2, hora: "14:00:00"),
            Linha("bi3", "bo3", 3, "9999", "", "B", 1, 0, 1, hora: "11:00:00"),
        };
        // Fake aplica filtro q no serviço via filtro SQL — simulamos já filtrado.
        var filtradas = linhas.Where(l => l.Ref.Contains("1368", StringComparison.Ordinal)).ToList();
        var sut = CreateSut(filtradas, [], new Dictionary<string, decimal> { [Key("1368", "")] = 5m });

        var result = await sut.ListarProcuraAbertaAsync(estadoPlaneamento: "DP", pageSize: null);

        Assert.Equal(1, result.TotalItems);
        Assert.Equal("DP", result.Items[0].EstadoPlaneamentoCodigo);
        Assert.Equal(10m, result.Items[0].QuantidadeEncomendada);
    }

    [Fact]
    public async Task Filtro_estadoPlaneamento_AC()
    {
        var linhas = new[]
        {
            Linha("bi1", "bo1", 1, "1368", "", "A", 10, 0, 10, hora: "11:00:00"),
            Linha("bi2", "bo2", 2, "1368", "", "A", 2, 0, 2, hora: "14:00:00"),
        };
        var sut = CreateSut(linhas, [], new Dictionary<string, decimal> { [Key("1368", "")] = 5m });

        var result = await sut.ListarProcuraAbertaAsync(estadoPlaneamento: "AC", pageSize: null);

        Assert.Equal(1, result.TotalItems);
        Assert.Equal("AC", result.Items[0].EstadoPlaneamentoCodigo);
        Assert.Equal(2m, result.Items[0].QuantidadeEncomendada);
    }

    [Fact]
    public async Task Varias_linhas_mesmo_RefCor_somam_e_contam_encomendas()
    {
        var linhas = new[]
        {
            Linha("bi1", "bo1", 1, "A", "", "D", 10, 1, 9, hora: "11:00:00"),
            Linha("bi2", "bo1", 1, "A", "", "D", 5, 0, 5, hora: "11:30:00"),
            Linha("bi3", "bo2", 2, "A", "", "Outro design", 3, 0, 3, hora: "11:45:00"),
        };
        var sut = CreateSut(linhas, [], new Dictionary<string, decimal> { [Key("A", "")] = 8m });

        var result = await sut.ListarProcuraAbertaAsync(pageSize: null);
        var g = Assert.Single(result.Items);
        Assert.Equal(18m, g.QuantidadeEncomendada);
        Assert.Equal(1m, g.QuantidadeFornecida);
        Assert.Equal(17m, g.QuantidadePorSatisfazer);
        Assert.Equal(3, g.TotalLinhas);
        Assert.Equal(2, g.TotalEncomendas);
        Assert.Equal("D", g.Descricao);
        Assert.Equal(8m, g.QuantidadeDisponivel);
    }

    [Fact]
    public async Task Urgente_ordena_primeiro()
    {
        var linhas = new[]
        {
            Linha("bi1", "bo1", 1, "Z", "", "z", 1, 0, 1, urgente: false, hora: "11:00:00"),
            Linha("bi2", "bo2", 2, "A", "", "a", 1, 0, 1, urgente: true, hora: "11:00:00"),
        };
        var sut = CreateSut(linhas, [], new Dictionary<string, decimal>
        {
            [Key("Z", "")] = 0m,
            [Key("A", "")] = 0m,
        });

        var result = await sut.ListarProcuraAbertaAsync(pageSize: null);
        Assert.Equal("A", result.Items[0].Ref);
        Assert.True(result.Items[0].Urgente);
    }

    [Fact]
    public async Task Pagina_alem_do_fim_devolve_vazio_sem_chamar_stock()
    {
        var linhas = new[]
        {
            Linha("bi1", "bo1", 1, "A", "", "a", 1, 0, 1, hora: "11:00:00"),
        };
        var stockCalls = new List<IReadOnlyList<ArtigoRefCorChave>>();
        var sut = CreateSut(linhas, stockCalls, new Dictionary<string, decimal> { [Key("A", "")] = 1m });

        var result = await sut.ListarProcuraAbertaAsync(page: 99, pageSize: 10);

        Assert.Equal(1, result.TotalItems);
        Assert.Empty(result.Items);
        Assert.Empty(stockCalls);
    }

    [Fact]
    public async Task Page_invalido_e_pageSize_sao_normalizados()
    {
        var linhas = Enumerable.Range(1, 5)
            .Select(i => Linha($"bi{i}", $"bo{i}", i, $"R{i}", "", $"d{i}", 1, 0, 1, hora: "11:00:00"))
            .ToList();
        var stock = linhas.ToDictionary(l => Key(l.Ref, l.Cor), _ => 1m);

        var r0 = await CreateSut(linhas, [], stock).ListarProcuraAbertaAsync(page: 0, pageSize: 2);
        Assert.Equal(1, r0.Page);
        Assert.Equal(2, r0.Items.Count);

        var rHuge = await CreateSut(linhas, [], stock).ListarProcuraAbertaAsync(page: 1, pageSize: 9999);
        Assert.Equal(5, rHuge.Items.Count); // clamp 200, mas só há 5
        Assert.Equal(200, rHuge.PageSize);
    }

    [Fact]
    public async Task Filtro_cor_e_metodo_sao_delegados_ao_SQL_fake()
    {
        // Garante que o serviço passa CorContem / MetodoExpedicao ao filtro da query.
        ArtigoProcuraLinhasFiltro? visto = null;
        var query = new FakeQuery(
            (_, f, _) =>
            {
                visto = f;
                return Task.FromResult<IReadOnlyList<ArtigoLinhaAberta>>(Array.Empty<ArtigoLinhaAberta>());
            },
            (_, _) => Task.FromResult<IReadOnlyList<ArtigoStockPrevDto>>(Array.Empty<ArtigoStockPrevDto>()));

        var sut = CreateSut(query);
        await sut.ListarProcuraAbertaAsync(cor: "AZUL", metodoExpedicao: "nao_definido", pageSize: 25);

        Assert.NotNull(visto);
        Assert.Equal("AZUL", visto!.CorContem);
        Assert.Equal("nao_definido", visto.MetodoExpedicao);
    }

    // --- helpers ---

    private static IReadOnlyList<ArtigoLinhaAberta> BuildUniversoMisto() =>
    [
        Linha("bi1", "bo1", 1, "C", "", "c", 1, 0, 1, urgente: false, hora: "11:00:00"),
        Linha("bi2", "bo2", 2, "A", "", "a-dp", 2, 0, 2, urgente: true, hora: "11:00:00"),
        Linha("bi3", "bo3", 3, "A", "", "a-ac", 3, 0, 3, urgente: true, hora: "14:00:00"),
        Linha("bi4", "bo4", 4, "B", "X", "b", 4, 0, 4, urgente: false, hora: "11:00:00"),
    ];

    private static ArtigoLinhaAberta Linha(
        string bi,
        string bo,
        int obrano,
        string referencia,
        string cor,
        string design,
        decimal pedida,
        decimal fornecida,
        decimal porSatisfazer,
        bool urgente = false,
        string hora = "11:00:00",
        DateTime? data = null) => new()
    {
        BiStamp = bi,
        BoStamp = bo,
        NumeroEncomenda = obrano,
        DataObra = data ?? DataSegunda,
        Hora = hora,
        Ref = referencia,
        Cor = cor,
        Design = design,
        QuantidadeOriginalConsiderada = pedida,
        QuantidadeFornecida = fornecida,
        QuantidadePorSatisfazer = porSatisfazer,
        QuantidadeAtual = pedida,
        StockDisponivel = 0,
        Urgente = urgente,
    };

    private static string Key(string r, string c) =>
        $"{r.Trim().ToUpperInvariant()}\u001f{c.Trim().ToUpperInvariant()}";

    private static void AssertEqualItems(
        IReadOnlyList<ArtigoProcuraItemDto> a,
        IReadOnlyList<ArtigoProcuraItemDto> b)
    {
        Assert.Equal(a.Count, b.Count);
        for (var i = 0; i < a.Count; i++)
        {
            Assert.Equal(a[i].Ref, b[i].Ref);
            Assert.Equal(a[i].Cor, b[i].Cor);
            Assert.Equal(a[i].Descricao, b[i].Descricao);
            Assert.Equal(a[i].QuantidadeEncomendada, b[i].QuantidadeEncomendada);
            Assert.Equal(a[i].QuantidadeFornecida, b[i].QuantidadeFornecida);
            Assert.Equal(a[i].QuantidadePorSatisfazer, b[i].QuantidadePorSatisfazer);
            Assert.Equal(a[i].QuantidadeDisponivel, b[i].QuantidadeDisponivel);
            Assert.Equal(a[i].QuantidadeAutorizadaTotal, b[i].QuantidadeAutorizadaTotal);
            Assert.Equal(a[i].TotalLinhas, b[i].TotalLinhas);
            Assert.Equal(a[i].TotalEncomendas, b[i].TotalEncomendas);
            Assert.Equal(a[i].EstadoPlaneamento, b[i].EstadoPlaneamento);
            Assert.Equal(a[i].EstadoPlaneamentoCodigo, b[i].EstadoPlaneamentoCodigo);
            Assert.Equal(a[i].Urgente, b[i].Urgente);
        }
    }

    private static EncomendasService CreateSut(
        IReadOnlyList<ArtigoLinhaAberta> linhas,
        List<IReadOnlyList<ArtigoRefCorChave>> stockCalls,
        IReadOnlyDictionary<string, decimal> stock)
    {
        var query = new FakeQuery(
            (_, _, _) => Task.FromResult(linhas),
            (chaves, _) =>
            {
                stockCalls.Add(chaves);
                var rows = chaves
                    .Select(c =>
                    {
                        stock.TryGetValue(Key(c.Ref, c.Cor), out var v);
                        return new ArtigoStockPrevDto(c.Ref, c.Cor, v);
                    })
                    .ToList();
                return Task.FromResult<IReadOnlyList<ArtigoStockPrevDto>>(rows);
            });
        return CreateSut(query);
    }

    private static EncomendasService CreateSut(IEncomendasQuery query) =>
        new(
            query,
            new FakeCommands(),
            new FakePickingQuery(),
            Options.Create(new PlaneamentoSettings
            {
                DiaCorte = Dia,
                HoraCorte = Hora,
                Fuso = Fuso,
            }),
            Options.Create(new SerieEncomendasSettings { SerieEncomendasNdos = 1 }));

    private sealed class FakeQuery : IEncomendasQuery
    {
        private readonly Func<int, ArtigoProcuraLinhasFiltro?, CancellationToken, Task<IReadOnlyList<ArtigoLinhaAberta>>> _linhas;
        private readonly Func<IReadOnlyList<ArtigoRefCorChave>, CancellationToken, Task<IReadOnlyList<ArtigoStockPrevDto>>> _stock;

        public FakeQuery(
            Func<int, ArtigoProcuraLinhasFiltro?, CancellationToken, Task<IReadOnlyList<ArtigoLinhaAberta>>> linhas,
            Func<IReadOnlyList<ArtigoRefCorChave>, CancellationToken, Task<IReadOnlyList<ArtigoStockPrevDto>>> stock)
        {
            _linhas = linhas;
            _stock = stock;
        }

        public Task<IReadOnlyList<ArtigoLinhaAberta>> ListarLinhasAbertasProcuraAsync(
            int serieNdos,
            ArtigoProcuraLinhasFiltro? filtro = null,
            CancellationToken cancellationToken = default) =>
            _linhas(serieNdos, filtro, cancellationToken);

        public Task<IReadOnlyList<ArtigoStockPrevDto>> ObterStockDisponivelPrevPorChavesAsync(
            IReadOnlyList<ArtigoRefCorChave> chaves,
            CancellationToken cancellationToken = default) =>
            _stock(chaves, cancellationToken);

        public Task<(IReadOnlyList<EncomendaResumo> Items, int Total)> ListarAbertasAsync(
            EncomendasFiltro filtro, int serieNdos, CancellationToken cancellationToken = default) =>
            throw new NotImplementedException();

        public Task<(EncomendaResumo? Cabecalho, IReadOnlyList<EncomendaLinha> Linhas)> ObterDetalheAsync(
            string boStamp, int serieNdos, CancellationToken cancellationToken = default) =>
            throw new NotImplementedException();

        public Task<IReadOnlyList<ArtigoSugestaoDto>> SugerirArtigosAsync(
            string termo, int serieNdos, int limit = 20, CancellationToken cancellationToken = default) =>
            throw new NotImplementedException();

        public Task<IReadOnlyList<string>> SugerirCoresAsync(
            string termo, int serieNdos, int limit = 20, CancellationToken cancellationToken = default) =>
            throw new NotImplementedException();

        public Task<(IReadOnlyList<CorteQuantidadeEncomenda> Items, int Total)> ListarCortesEncomendasAsync(
            CortesQuantidadeFiltro filtro, int serieNdos, CancellationToken cancellationToken = default) =>
            throw new NotImplementedException();

        public Task<IReadOnlyList<CorteQuantidadeLinha>> ListarCortesLinhasPorEncomendaAsync(
            string boStamp, int serieNdos, string? artigoRef = null, string? artigoCor = null,
            CancellationToken cancellationToken = default) =>
            throw new NotImplementedException();
    }

    private sealed class FakeCommands : IEncomendasCommands
    {
        public Task<QuantidadeAutorizadaAtualizadaDto> AtualizarQuantidadeAutorizadaAsync(
            string biStamp, decimal quantidadeAutorizada, string usrLogin, decimal? valorAnteriorEsperado,
            bool permitirAcimaStock = false, string? usrinis = null, CancellationToken cancellationToken = default) =>
            throw new NotImplementedException();

        public Task<LinhaAtualizadaDto> AtualizarLinhaQttPrecoAsync(
            string biStamp, decimal? quantidade, decimal? precoUnitario, string usrinis,
            decimal? quantidadeAnteriorEsperada, decimal? precoAnteriorEsperado,
            CancellationToken cancellationToken = default) =>
            throw new NotImplementedException();

        public Task<AlocarArtigoResponseDto> AlocarProporcionalAsync(
            string artigoRef, string usrLogin, bool simular, decimal? quantidadeDisponivel,
            string? cor, bool filtrarCor, CancellationToken cancellationToken = default) =>
            throw new NotImplementedException();

        public Task<ProntaPickingAtualizadaDto> MarcarProntaPickingAsync(
            string boStamp, bool pronta, string usrLogin, string? usrinis = null,
            bool confirmarLinhasSemAutorizacao = false, string? motivo = null,
            CancellationToken cancellationToken = default) =>
            throw new NotImplementedException();

        public Task<PickWorkflowAtualizadaDto> PickingStartAsync(
            string boStamp, string usrLogin, string? usrinis = null, CancellationToken cancellationToken = default) =>
            throw new NotImplementedException();

        public Task<PickWorkflowAtualizadaDto> PickingCompleteAsync(
            string boStamp, string usrLogin, string? usrinis = null, CancellationToken cancellationToken = default) =>
            throw new NotImplementedException();

        public Task<PickWorkflowAtualizadaDto> PickingCancelAsync(
            string boStamp, string usrLogin, string? usrinis = null, string? motivo = null,
            CancellationToken cancellationToken = default) =>
            throw new NotImplementedException();

        public Task<PickWorkflowAtualizadaDto> PickingBackToReadyAsync(
            string boStamp, string usrLogin, string? usrinis = null, CancellationToken cancellationToken = default) =>
            throw new NotImplementedException();

        public Task<PickWorkflowAtualizadaDto> PickingReopenAsync(
            string boStamp, string usrLogin, string? usrinis = null, CancellationToken cancellationToken = default) =>
            throw new NotImplementedException();

        public Task<UrgenteAtualizadaDto> MarcarUrgenteAsync(
            string boStamp, bool urgente, string usrLogin, string? usrinis = null,
            CancellationToken cancellationToken = default) =>
            throw new NotImplementedException();

        public Task<CancelarEncomendaAtualizadaDto> CancelarEncomendaAsync(
            string boStamp, string motivo, string usrLogin, string? usrinis = null,
            CancellationToken cancellationToken = default) =>
            throw new NotImplementedException();
    }

    private sealed class FakePickingQuery : IPickingDossiersQuery
    {
        public Task<(IReadOnlyList<EncomendaResumo> Items, int Total)> ListarAsync(
            EncomendasFiltro filtro, int seriePickingNdos, bool fechada,
            CancellationToken cancellationToken = default) =>
            throw new NotImplementedException();

        public Task<IReadOnlyList<EncomendaLinha>> ListarLinhasAsync(
            string boStamp, int seriePickingNdos, CancellationToken cancellationToken = default) =>
            throw new NotImplementedException();
    }
}
