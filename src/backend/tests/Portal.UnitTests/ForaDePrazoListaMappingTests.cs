using Microsoft.Extensions.Options;
using Portal.Application.Encomendas;
using Portal.Domain.Encomendas;

namespace Portal.UnitTests;

/// <summary>
/// Mapeamento API: <c>ForaDePrazo</c> usa só
/// <see cref="EncomendaResumo.Ousrdata"/> / <see cref="EncomendaResumo.Ousrhora"/>
/// (origem ndos=1), independente de DP/AC (<see cref="EncomendaResumo.DataObra"/> / <see cref="EncomendaResumo.Hora"/>).
/// </summary>
public sealed class ForaDePrazoListaMappingTests
{
    private const string Fuso = "Europe/Lisbon";

    /// <summary>Quarta 2026-08-12 12:00 Lisboa — semana do corte segunda 12:30.</summary>
    private static readonly DateTime AgoraUtc = UtcFromLisbon(2026, 8, 12, 12, 0, 0);

    private static readonly TimeProvider Relogio = new FixedUtcTimeProvider(AgoraUtc);

    private static DateTime UtcFromLisbon(int y, int m, int d, int h, int mi, int s = 0)
    {
        var tz = ResolveTz();
        var local = new DateTime(y, m, d, h, mi, s, DateTimeKind.Unspecified);
        return TimeZoneInfo.ConvertTimeToUtc(local, tz);
    }

    private static TimeZoneInfo ResolveTz()
    {
        try
        {
            return TimeZoneInfo.FindSystemTimeZoneById(Fuso);
        }
        catch (TimeZoneNotFoundException)
        {
            return TimeZoneInfo.FindSystemTimeZoneById("GMT Standard Time");
        }
        catch (InvalidTimeZoneException)
        {
            return TimeZoneInfo.FindSystemTimeZoneById("GMT Standard Time");
        }
    }

    private static EncomendaResumo Resumo(
        DateTime? ousrdata,
        string ousrhora,
        DateTime? dataObra = null,
        string? horaDossier = null) =>
        new()
        {
            BoStamp = "bo-1",
            NumeroEncomenda = 10,
            NumeroDossier = 20,
            Ndos = 1,
            NomeSerie = "ENC",
            DataObra = dataObra ?? new DateTime(2000, 1, 1),
            Ousrdata = ousrdata,
            Ousrhora = ousrhora,
            Hora = horaDossier ?? "00:00:00",
            ClienteNo = 1,
            ClienteNome = "Cliente",
            TotalLinhas = 1,
            QuantidadeOriginalTotal = 1,
            QuantidadePorSatisfazer = 1,
        };

    [Fact]
    public async Task Semana_actual_apos_1230_fora_de_prazo_mesmo_se_dp_por_dataobra()
    {
        // Origem: segunda 12:30:01 → fora; DataObra/Hora do dossier seriam DP (antes das 12:00).
        var item = Resumo(
            new DateTime(2026, 8, 10),
            "12:30:01",
            dataObra: new DateTime(2026, 8, 10),
            horaDossier: "11:00:00");

        var row = Assert.Single(
            (await CreateEncomendas(item).ListarAbertasAsync(new EncomendasFiltro())).Items);
        Assert.Equal("DP", row.EstadoPlaneamentoCodigo);
        Assert.True(row.ForaDePrazo);
    }

    [Fact]
    public async Task Semana_anterior_ac_mas_fora_de_prazo_false()
    {
        // Caso n.º 19: 02/10 AC na semana da encomenda; «agora» = 15/10 → semana anterior.
        var relogio = new FixedUtcTimeProvider(UtcFromLisbon(2026, 10, 15, 10, 0, 0));
        var item = Resumo(
            new DateTime(2026, 10, 2),
            "15:56:37",
            dataObra: new DateTime(2026, 10, 2),
            horaDossier: "15:56:37");
        item = CloneStamp(item, "ADM26100257328,079000002");

        var sut = CreateEncomendas(item, relogio);
        var row = Assert.Single((await sut.ListarAbertasAsync(new EncomendasFiltro())).Items);
        Assert.Equal("AC", row.EstadoPlaneamentoCodigo);
        Assert.False(row.ForaDePrazo);

        var detalhe = await sut.ObterDetalheAsync("ADM26100257328,079000002");
        Assert.NotNull(detalhe);
        Assert.Equal("AC", detalhe!.EstadoPlaneamentoCodigo);
        Assert.False(detalhe.ForaDePrazo);
    }

    [Fact]
    public async Task Picking_usa_ousrdata_origem_nao_hora_do_66()
    {
        var item = Resumo(
            new DateTime(2026, 8, 10),
            "12:30:01",
            dataObra: new DateTime(2026, 8, 10),
            horaDossier: "09:00:00");
        item = CloneComNdos(item, 66);

        var row = Assert.Single(
            (await CreatePicking(item).ListarAsync(new EncomendasFiltro(), fechada: false)).Items);
        Assert.True(row.ForaDePrazo);
    }

    [Fact]
    public async Task Separacao_65_origem_semana_anterior_fora_false()
    {
        var relogio = new FixedUtcTimeProvider(UtcFromLisbon(2026, 10, 15, 10, 0, 0));
        var item = Resumo(
            new DateTime(2026, 10, 2),
            "15:56:37",
            dataObra: new DateTime(2026, 10, 6),
            horaDossier: "15:00:00");
        item = CloneComNdos(item, 65);

        var row = Assert.Single(
            (await CreateSeparacao(item, relogio).ListarAsync(new EncomendasFiltro(), false)).Items);
        Assert.Equal("AC", row.EstadoPlaneamentoCodigo);
        Assert.False(row.ForaDePrazo);
    }

    [Fact]
    public async Task Sem_origem_temporal_fora_de_prazo_false()
    {
        var item = Resumo(null, "", dataObra: new DateTime(2026, 8, 10), horaDossier: "15:00:00");

        Assert.False((await CreateEncomendas(item).ListarAbertasAsync(new EncomendasFiltro()))
            .Items[0].ForaDePrazo);
        Assert.False((await CreatePicking(CloneComNdos(item, 66)).ListarAsync(new EncomendasFiltro(), false))
            .Items[0].ForaDePrazo);
        Assert.False((await CreateSeparacao(CloneComNdos(item, 65)).ListarAsync(new EncomendasFiltro(), false))
            .Items[0].ForaDePrazo);
    }

    [Fact]
    public async Task Antes_do_corte_nao_e_fora_de_prazo()
    {
        var item = Resumo(new DateTime(2026, 8, 10), "12:30:00");
        Assert.False((await CreateEncomendas(item).ListarAbertasAsync(new EncomendasFiltro()))
            .Items[0].ForaDePrazo);
    }

    private static EncomendaResumo CloneStamp(EncomendaResumo e, string stamp)
    {
        var c = CloneComNdos(e, e.Ndos);
        return new()
        {
            BoStamp = stamp,
            NumeroEncomenda = c.NumeroEncomenda,
            NumeroDossier = c.NumeroDossier,
            NumeroPicking = c.NumeroPicking,
            NumeroSeparacao = c.NumeroSeparacao,
            Ndos = c.Ndos,
            NomeSerie = c.NomeSerie,
            DataObra = c.DataObra,
            Ousrdata = c.Ousrdata,
            Ousrhora = c.Ousrhora,
            Hora = c.Hora,
            ClienteNo = c.ClienteNo,
            ClienteEstab = c.ClienteEstab,
            ClienteNome = c.ClienteNome,
            ClienteNome2 = c.ClienteNome2,
            TotalLinhas = c.TotalLinhas,
            QuantidadeOriginalTotal = c.QuantidadeOriginalTotal,
            QuantidadeAtualTotal = c.QuantidadeAtualTotal,
            QuantidadePorSatisfazer = c.QuantidadePorSatisfazer,
            QuantidadeAutorizadaTotal = c.QuantidadeAutorizadaTotal,
            QuantidadeDocumento = c.QuantidadeDocumento,
            QuantidadeExpedida = c.QuantidadeExpedida,
            QuantidadePendenteEntrega = c.QuantidadePendenteEntrega,
            ProntaPicking = c.ProntaPicking,
            ProntaPickingPor = c.ProntaPickingPor,
            ProntaPickingEm = c.ProntaPickingEm,
            PickStatus = c.PickStatus,
            Urgente = c.Urgente,
            DataEntrega = c.DataEntrega,
            MetodoExpedicao = c.MetodoExpedicao,
            MoradaEntrega = c.MoradaEntrega,
            CheckIn = c.CheckIn,
            CheckInPor = c.CheckInPor,
            CheckInEm = c.CheckInEm,
            TemQtt66 = c.TemQtt66,
        };
    }

    private static EncomendaResumo CloneComNdos(EncomendaResumo e, int ndos) =>
        new()
        {
            BoStamp = e.BoStamp,
            NumeroEncomenda = e.NumeroEncomenda,
            NumeroDossier = e.NumeroDossier,
            NumeroPicking = e.NumeroPicking,
            NumeroSeparacao = e.NumeroSeparacao,
            Ndos = ndos,
            NomeSerie = e.NomeSerie,
            DataObra = e.DataObra,
            Ousrdata = e.Ousrdata,
            Ousrhora = e.Ousrhora,
            Hora = e.Hora,
            ClienteNo = e.ClienteNo,
            ClienteEstab = e.ClienteEstab,
            ClienteNome = e.ClienteNome,
            ClienteNome2 = e.ClienteNome2,
            TotalLinhas = e.TotalLinhas,
            QuantidadeOriginalTotal = e.QuantidadeOriginalTotal,
            QuantidadeAtualTotal = e.QuantidadeAtualTotal,
            QuantidadePorSatisfazer = e.QuantidadePorSatisfazer,
            QuantidadeAutorizadaTotal = e.QuantidadeAutorizadaTotal,
            QuantidadeDocumento = e.QuantidadeDocumento,
            QuantidadeExpedida = e.QuantidadeExpedida,
            QuantidadePendenteEntrega = e.QuantidadePendenteEntrega,
            ProntaPicking = e.ProntaPicking,
            ProntaPickingPor = e.ProntaPickingPor,
            ProntaPickingEm = e.ProntaPickingEm,
            PickStatus = e.PickStatus,
            Urgente = e.Urgente,
            DataEntrega = e.DataEntrega,
            MetodoExpedicao = e.MetodoExpedicao,
            MoradaEntrega = e.MoradaEntrega,
            CheckIn = e.CheckIn,
            CheckInPor = e.CheckInPor,
            CheckInEm = e.CheckInEm,
            TemQtt66 = e.TemQtt66,
        };

    private static PlaneamentoSettings Planeamento() => new()
    {
        DiaCorte = "Monday",
        HoraCorte = "12:00",
        Fuso = Fuso,
    };

    private static EncomendasService CreateEncomendas(EncomendaResumo item, TimeProvider? time = null) =>
        new(
            new FakeEncomendasQuery(
                listar: (_, _, _) => Task.FromResult<(IReadOnlyList<EncomendaResumo>, int)>(
                    (new[] { item }, 1)),
                detalhe: (_, _, _) => Task.FromResult<(EncomendaResumo?, IReadOnlyList<EncomendaLinha>)>(
                    (item, Array.Empty<EncomendaLinha>()))),
            new ThrowingEncomendasCommands(),
            new ThrowingPickingQuery(),
            Options.Create(Planeamento()),
            Options.Create(new SerieEncomendasSettings { SerieEncomendasNdos = 1 }),
            time ?? Relogio);

    private static PickingDossiersService CreatePicking(EncomendaResumo item, TimeProvider? time = null) =>
        new(
            new FakePickingQuery(item),
            new ThrowingPickingCommands(),
            Options.Create(Planeamento()),
            Options.Create(new SerieEncomendasSettings { SeriePickingNdos = 66 }),
            time ?? Relogio);

    private static SeparacaoDossiersService CreateSeparacao(EncomendaResumo item, TimeProvider? time = null) =>
        new(
            new FakePickingQuery(item),
            new ThrowingPickingCommands(),
            Options.Create(Planeamento()),
            Options.Create(new SerieEncomendasSettings { SerieSeparacaoNdos = 65 }),
            time ?? Relogio);

    private sealed class FixedUtcTimeProvider(DateTime utc) : TimeProvider
    {
        private readonly DateTimeOffset _utc = new(DateTime.SpecifyKind(utc, DateTimeKind.Utc));
        public override DateTimeOffset GetUtcNow() => _utc;
    }

    private sealed class FakeEncomendasQuery : IEncomendasQuery
    {
        private readonly Func<EncomendasFiltro, int, CancellationToken, Task<(IReadOnlyList<EncomendaResumo>, int)>>? _listar;
        private readonly Func<string, int, CancellationToken, Task<(EncomendaResumo?, IReadOnlyList<EncomendaLinha>)>>? _detalhe;

        public FakeEncomendasQuery(
            Func<EncomendasFiltro, int, CancellationToken, Task<(IReadOnlyList<EncomendaResumo>, int)>>? listar,
            Func<string, int, CancellationToken, Task<(EncomendaResumo?, IReadOnlyList<EncomendaLinha>)>>? detalhe)
        {
            _listar = listar;
            _detalhe = detalhe;
        }

        public Task<(IReadOnlyList<EncomendaResumo> Items, int Total)> ListarAbertasAsync(
            EncomendasFiltro filtro, int serieNdos, CancellationToken cancellationToken = default) =>
            _listar?.Invoke(filtro, serieNdos, cancellationToken)
            ?? throw new NotImplementedException();

        public Task<(EncomendaResumo? Cabecalho, IReadOnlyList<EncomendaLinha> Linhas)> ObterDetalheAsync(
            string boStamp, int serieNdos, CancellationToken cancellationToken = default) =>
            _detalhe?.Invoke(boStamp, serieNdos, cancellationToken)
            ?? throw new NotImplementedException();

        public Task<IReadOnlyList<ArtigoSugestaoDto>> SugerirArtigosAsync(
            string termo, int serieNdos, int limit = 20, CancellationToken cancellationToken = default) =>
            throw new NotImplementedException();

        public Task<IReadOnlyList<string>> SugerirCoresAsync(
            string termo, int serieNdos, int limit = 20, CancellationToken cancellationToken = default) =>
            throw new NotImplementedException();

        public Task<IReadOnlyList<ArtigoLinhaAberta>> ListarLinhasAbertasProcuraAsync(
            int serieNdos, ArtigoProcuraLinhasFiltro? filtro = null, CancellationToken cancellationToken = default) =>
            throw new NotImplementedException();

        public Task<IReadOnlyList<ArtigoStockPrevDto>> ObterStockDisponivelPrevPorChavesAsync(
            IReadOnlyList<ArtigoRefCorChave> chaves, CancellationToken cancellationToken = default) =>
            throw new NotImplementedException();

        public Task<(IReadOnlyList<CorteQuantidadeEncomenda> Items, int Total)> ListarCortesEncomendasAsync(
            CortesQuantidadeFiltro filtro, int serieNdos, CancellationToken cancellationToken = default) =>
            throw new NotImplementedException();

        public Task<IReadOnlyList<CorteQuantidadeLinha>> ListarCortesLinhasPorEncomendaAsync(
            string boStamp, int serieNdos, string? artigoRef = null, string? artigoCor = null,
            CancellationToken cancellationToken = default) =>
            throw new NotImplementedException();
    }

    private sealed class FakePickingQuery(EncomendaResumo item) : IPickingDossiersQuery
    {
        public Task<(IReadOnlyList<EncomendaResumo> Items, int Total)> ListarAsync(
            EncomendasFiltro filtro, int seriePickingNdos, bool fechada,
            CancellationToken cancellationToken = default) =>
            Task.FromResult<(IReadOnlyList<EncomendaResumo>, int)>((new[] { item }, 1));

        public Task<IReadOnlyList<EncomendaLinha>> ListarLinhasAsync(
            string boStamp, int seriePickingNdos, CancellationToken cancellationToken = default) =>
            throw new NotImplementedException();
    }

    private sealed class ThrowingPickingQuery : IPickingDossiersQuery
    {
        public Task<(IReadOnlyList<EncomendaResumo> Items, int Total)> ListarAsync(
            EncomendasFiltro filtro, int seriePickingNdos, bool fechada,
            CancellationToken cancellationToken = default) =>
            throw new NotImplementedException();

        public Task<IReadOnlyList<EncomendaLinha>> ListarLinhasAsync(
            string boStamp, int seriePickingNdos, CancellationToken cancellationToken = default) =>
            throw new NotImplementedException();
    }

    private sealed class ThrowingEncomendasCommands : IEncomendasCommands
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

    private sealed class ThrowingPickingCommands : IPickingDossiersCommands
    {
        public Task<FechoPickingAtualizadaDto> MarcarFechoAsync(
            string boStamp, bool fechada, int seriePickingNdos, string? usrLogin,
            CancellationToken cancellationToken = default) =>
            throw new NotImplementedException();

        public Task<FechoPickingAtualizadaDto> FecharExpedicaoAsync(
            string boStamp, int serieSeparacaoNdos, string? usrLogin,
            CancellationToken cancellationToken = default) =>
            throw new NotImplementedException();

        public Task<FechoPickingAtualizadaDto> ReabrirExpedicaoAsync(
            string boStamp, int serieSeparacaoNdos, string? usrLogin,
            CancellationToken cancellationToken = default) =>
            throw new NotImplementedException();

        public Task<CheckInAtualizadaDto> MarcarCheckInAsync(
            string boStamp, bool checkIn, int seriePickingNdos, string usrLogin, string? usrinis,
            CancellationToken cancellationToken = default) =>
            throw new NotImplementedException();

        public Task<CheckInAtualizadaDto> ReverterCheckInAsync(
            string boStamp, int seriePickingNdos, string usrLogin, string? usrinis,
            CancellationToken cancellationToken = default) =>
            throw new NotImplementedException();
    }
}
