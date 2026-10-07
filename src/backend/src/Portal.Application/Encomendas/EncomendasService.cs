using System.Globalization;
using Microsoft.Extensions.Options;
using Portal.Domain.Encomendas;

namespace Portal.Application.Encomendas;

public sealed class EncomendasService
{
    private readonly IEncomendasQuery _query;
    private readonly IEncomendasCommands _commands;
    private readonly IPickingDossiersQuery _pickingDossiers;
    private readonly PlaneamentoSettings _planeamento;
    private readonly int _serieNdos;
    private readonly int _seriePickingNdos;

    public EncomendasService(
        IEncomendasQuery query,
        IEncomendasCommands commands,
        IPickingDossiersQuery pickingDossiers,
        IOptions<PlaneamentoSettings> planeamento,
        IOptions<SerieEncomendasSettings> serie)
    {
        _query = query;
        _commands = commands;
        _pickingDossiers = pickingDossiers;
        _planeamento = planeamento.Value;
        _serieNdos = serie.Value.SerieEncomendasNdos;
        _seriePickingNdos = serie.Value.SeriePickingNdos;
    }

    public async Task<EncomendaListaResponseDto> ListarAbertasAsync(
        EncomendasFiltro filtro,
        CancellationToken cancellationToken = default)
    {
        var page = Math.Max(1, filtro.Page);
        var pageSize = Math.Clamp(filtro.PageSize, 1, 200);

        // Carregar conjunto filtrado (sem paginação SQL): ordenação DP→AC + nº encomenda é calculada em memória.
        var queryFiltro = new EncomendasFiltro
        {
            DataDe = filtro.DataDe,
            DataAte = filtro.DataAte,
            HoraDe = filtro.HoraDe,
            HoraAte = filtro.HoraAte,
            ClienteNo = filtro.ClienteNo,
            ClienteNoContem = filtro.ClienteNoContem,
            ArtigoRef = filtro.ArtigoRef,
            ArtigoCor = filtro.ArtigoCor,
            ProntaPicking = filtro.ProntaPicking ?? false,
            PickStatus = filtro.PickStatus,
            Page = 1,
            PageSize = 5000
        };

        var (items, _) = await _query.ListarAbertasAsync(queryFiltro, _serieNdos, cancellationToken);

        var mapped = items
            .Select(MapListaItem)
            .Where(i => PlaneamentoCalculator.CoincideFiltro(i.EstadoPlaneamentoCodigo, filtro.EstadoPlaneamento))
            .Where(i => MetodoExpedicaoFiltro.Coincide(i.MetodoExpedicao, filtro.MetodoExpedicao))
            .OrderByDescending(i => i.Urgente)
            .ThenBy(i => i.EstadoPlaneamentoCodigo == "DP" ? 0 : 1)
            .ThenBy(i => i.NumeroEncomenda)
            .ToList();

        var total = mapped.Count;
        mapped = mapped
            .Skip((page - 1) * pageSize)
            .Take(pageSize)
            .ToList();

        return new EncomendaListaResponseDto(page, pageSize, total, mapped);
    }

    public async Task<EncomendaDetalheDto?> ObterDetalheAsync(
        string boStamp,
        CancellationToken cancellationToken = default)
    {
        if (string.IsNullOrWhiteSpace(boStamp))
            return null;

        var (cab, linhas) = await _query.ObterDetalheAsync(boStamp.Trim(), _serieNdos, cancellationToken);
        if (cab is null)
            return null;

        var (etiqueta, codigo) = PlaneamentoCalculator.Classificar(
            cab.DataObra,
            cab.Hora,
            _planeamento.DiaCorte,
            _planeamento.HoraCorte,
            _planeamento.Fuso);

        return new EncomendaDetalheDto(
            cab.BoStamp,
            cab.NumeroEncomenda,
            cab.Ndos,
            cab.NomeSerie,
            cab.ClienteNo,
            cab.ClienteEstab,
            cab.ClienteNome,
            string.IsNullOrWhiteSpace(cab.ClienteNome2) ? null : cab.ClienteNome2,
            cab.DataObra.ToString("yyyy-MM-dd"),
            NormalizarHora(cab.Hora),
            etiqueta,
            codigo,
            cab.ProntaPicking,
            string.IsNullOrWhiteSpace(cab.ProntaPickingPor) ? null : cab.ProntaPickingPor,
            cab.ProntaPickingEm,
            cab.PickStatus,
            cab.Urgente,
            cab.DataEntrega,
            string.IsNullOrWhiteSpace(cab.MetodoExpedicao) ? null : cab.MetodoExpedicao,
            string.IsNullOrWhiteSpace(cab.MoradaEntrega) ? null : cab.MoradaEntrega,
            linhas.Select(MapLinha).ToList(),
            cab.TemQtt66);
    }

    public Task<IReadOnlyList<ArtigoSugestaoDto>> SugerirArtigosAsync(
        string termo,
        int limit = 20,
        CancellationToken cancellationToken = default)
        => _query.SugerirArtigosAsync(termo, _serieNdos, limit, cancellationToken);

    public Task<IReadOnlyList<string>> SugerirCoresAsync(
        string termo,
        int limit = 20,
        CancellationToken cancellationToken = default)
        => _query.SugerirCoresAsync(termo, _serieNdos, limit, cancellationToken);

    public async Task<ArtigoProcuraResponseDto> ListarProcuraAbertaAsync(
        string? estadoPlaneamento = null,
        string? q = null,
        string? cor = null,
        DateTime? dataDe = null,
        DateTime? dataAte = null,
        string? horaDe = null,
        string? horaAte = null,
        string? clienteNoContem = null,
        string? metodoExpedicao = null,
        int page = 1,
        int? pageSize = null,
        CancellationToken cancellationToken = default)
    {
        var dataDeN = DateQuery.Normalize(dataDe);
        var dataAteN = DateQuery.Normalize(dataAte);
        var horaDeTs = TimeQuery.ParseHoraDe(horaDe);
        var horaAteTs = TimeQuery.ParseHoraAte(horaAte);

        var pageN = Math.Max(1, page);
        // pageSize omitido → devolver todos os grupos (compat. FE até passar page/pageSize).
        // Quando indicado → clamp 1..200 (convenção das outras listas).
        var pageSizeN = pageSize is null ? (int?)null : Math.Clamp(pageSize.Value, 1, 200);

        var sw = System.Diagnostics.Stopwatch.StartNew();
        var linhas = await _query.ListarLinhasAbertasProcuraAsync(
            _serieNdos,
            new ArtigoProcuraLinhasFiltro
            {
                RefOuDesignContem = q,
                CorContem = cor,
                DataDe = dataDeN,
                DataAte = dataAteN,
                HoraDe = horaDeTs,
                HoraAte = horaAteTs,
                ClienteNoContem = clienteNoContem,
                MetodoExpedicao = metodoExpedicao,
            },
            cancellationToken);
        var msFase1 = sw.ElapsedMilliseconds;

        var items = linhas
            .Select(l =>
            {
                var (etiqueta, codigo) = PlaneamentoCalculator.Classificar(
                    l.DataObra,
                    l.Hora,
                    _planeamento.DiaCorte,
                    _planeamento.HoraCorte,
                    _planeamento.Fuso);
                return (Linha: l, Etiqueta: etiqueta, Codigo: codigo);
            })
            .Where(x => PlaneamentoCalculator.CoincideFiltro(x.Codigo, estadoPlaneamento))
            .GroupBy(x => (
                x.Codigo,
                RefKey: x.Linha.Ref.ToUpperInvariant(),
                CorKey: x.Linha.Cor.ToUpperInvariant()))
            .Select(g =>
            {
                var first = g.First();
                return new ArtigoProcuraItemDto(
                    first.Linha.Ref,
                    g.Select(x => x.Linha.Design).FirstOrDefault(d => !string.IsNullOrWhiteSpace(d))
                        ?? first.Linha.Design,
                    first.Linha.Cor,
                    g.Sum(x => x.Linha.QuantidadePedida),
                    g.Sum(x => x.Linha.QuantidadeFornecida),
                    g.Sum(x => x.Linha.QuantidadePorSatisfazer),
                    0m, // QuantidadeDisponivel — Fase 2 (Prev* só chaves da página)
                    g.Sum(x => x.Linha.QuantidadeAutorizada),
                    g.Count(),
                    g.Select(x => x.Linha.BoStamp).Distinct(StringComparer.OrdinalIgnoreCase).Count(),
                    first.Etiqueta,
                    first.Codigo,
                    g.Any(x => x.Linha.Urgente));
            })
            .OrderByDescending(i => i.Urgente)
            .ThenBy(i => i.EstadoPlaneamentoCodigo == "DP" ? 0 : 1)
            .ThenBy(i => i.Ref, StringComparer.OrdinalIgnoreCase)
            .ThenBy(i => i.Cor, StringComparer.OrdinalIgnoreCase)
            .ToList();

        var totalItems = items.Count;

        var effectivePageSize = pageSizeN ?? Math.Max(totalItems, 1);
        var pageItems = items
            .Skip((pageN - 1) * effectivePageSize)
            .Take(effectivePageSize)
            .ToList();

        // Fase 2: Prev* só para DISTINCT Ref+Cor da página (DP+AC mesma Ref+Cor → 1 chave).
        var chavesPagina = pageItems
            .Select(i => new ArtigoRefCorChave(i.Ref, i.Cor))
            .GroupBy(c => (c.Ref.ToUpperInvariant(), c.Cor.ToUpperInvariant()))
            .Select(g => g.First())
            .ToList();

        sw.Restart();
        IReadOnlyList<ArtigoStockPrevDto> stockRows = Array.Empty<ArtigoStockPrevDto>();
        if (chavesPagina.Count > 0)
        {
            stockRows = await _query.ObterStockDisponivelPrevPorChavesAsync(
                chavesPagina,
                cancellationToken);
        }
        var msFase2 = sw.ElapsedMilliseconds;

        var stockLookup = new Dictionary<string, decimal>(StringComparer.Ordinal);
        foreach (var s in stockRows)
        {
            stockLookup[StockLookupKey(s.Ref, s.Cor)] = s.StockDisponivel;
        }

        var withStock = pageItems
            .Select(i => i with
            {
                QuantidadeDisponivel = stockLookup.TryGetValue(StockLookupKey(i.Ref, i.Cor), out var stock)
                    ? stock
                    : 0m
            })
            .ToList();

        // Logging leve (sem infra nova): útil em UAT para comparar fase1 vs fase2.
        System.Diagnostics.Trace.WriteLine(
            $"[procura-aberta 1A] linhas={linhas.Count} grupos={totalItems} page={pageN} " +
            $"pageSize={(pageSizeN?.ToString() ?? "all")} chavesStock={chavesPagina.Count} " +
            $"msFase1={msFase1} msFase2={msFase2}");

        return new ArtigoProcuraResponseDto(
            withStock,
            pageN,
            pageSizeN ?? totalItems,
            totalItems);
    }

    private static string StockLookupKey(string? referencia, string? cor) =>
        $"{(referencia ?? string.Empty).Trim().ToUpperInvariant()}\u001f{(cor ?? string.Empty).Trim().ToUpperInvariant()}";

    public async Task<ArtigoEncomendasAbertasResponseDto?> ObterEncomendasAbertasPorArtigoAsync(
        string artigoRef,
        string? cor = null,
        string? estadoPlaneamento = null,
        CancellationToken cancellationToken = default)
    {
        if (string.IsNullOrWhiteSpace(artigoRef))
            return null;

        var refTrim = artigoRef.Trim();
        // cor null = não filtrar; cor "" = só sem cor. Query param explícito vazio vem como "".
        string? corFilter = cor;
        if (cor is null)
            corFilter = null;

        var linhas = await _query.ListarLinhasAbertasProcuraAsync(
            _serieNdos,
            new ArtigoProcuraLinhasFiltro
            {
                RefExact = refTrim,
                CorExact = corFilter,
            },
            cancellationToken);

        if (linhas.Count == 0)
        {
            return new ArtigoEncomendasAbertasResponseDto(
                refTrim,
                cor,
                string.Empty,
                0,
                Array.Empty<ArtigoEncomendaAbertaItemDto>());
        }

        var chaves = linhas
            .Select(l => new ArtigoRefCorChave(l.Ref, l.Cor))
            .GroupBy(c => (c.Ref.ToUpperInvariant(), c.Cor.ToUpperInvariant()))
            .Select(g => g.First())
            .ToList();

        var stockRows = await _query.ObterStockDisponivelPrevPorChavesAsync(chaves, cancellationToken);
        var stockLookup = new Dictionary<string, decimal>(StringComparer.Ordinal);
        foreach (var s in stockRows)
            stockLookup[StockLookupKey(s.Ref, s.Cor)] = s.StockDisponivel;

        decimal StockOf(ArtigoLinhaAberta l) =>
            stockLookup.TryGetValue(StockLookupKey(l.Ref, l.Cor), out var v) ? v : 0m;

        var mapped = linhas
            .Select(l =>
            {
                var (etiqueta, codigo) = PlaneamentoCalculator.Classificar(
                    l.DataObra,
                    l.Hora,
                    _planeamento.DiaCorte,
                    _planeamento.HoraCorte,
                    _planeamento.Fuso);
                return new ArtigoEncomendaAbertaItemDto(
                    l.BoStamp,
                    l.BiStamp,
                    l.NumeroEncomenda,
                    l.ClienteNo,
                    l.ClienteNome,
                    string.IsNullOrWhiteSpace(l.ClienteNome2) ? null : l.ClienteNome2,
                    l.DataObra.ToString("yyyy-MM-dd"),
                    NormalizarHora(l.Hora),
                    etiqueta,
                    codigo,
                    l.Ref,
                    l.Design,
                    l.Cor,
                    l.Unidade,
                    l.QuantidadeAtual,
                    l.QuantidadeOriginalConsiderada,
                    l.QuantidadeAtual,
                    l.QuantidadeFornecida,
                    l.QuantidadePorSatisfazer,
                    l.PrecoUnitario,
                    l.PrecoOriginalCampo,
                    l.QuantidadeAutorizada,
                    string.IsNullOrWhiteSpace(l.QuantidadeAutorizadaPor) ? null : l.QuantidadeAutorizadaPor,
                    l.QuantidadeAutorizadaEm,
                    StockOf(l),
                    string.IsNullOrWhiteSpace(l.Usrinis) ? null : l.Usrinis,
                    l.Usrdata?.ToString("yyyy-MM-dd"),
                    string.IsNullOrWhiteSpace(l.Usrhora) ? null : NormalizarHora(l.Usrhora),
                    l.Urgente,
                    l.DataEntrega,
                    string.IsNullOrWhiteSpace(l.MetodoExpedicao) ? null : l.MetodoExpedicao);
            })
            .Where(i => PlaneamentoCalculator.CoincideFiltro(i.EstadoPlaneamentoCodigo, estadoPlaneamento))
            .OrderByDescending(i => i.Urgente)
            .ThenBy(i => i.NumeroEncomenda)
            .ThenBy(i => i.BiStamp, StringComparer.OrdinalIgnoreCase)
            .ToList();

        return new ArtigoEncomendasAbertasResponseDto(
            refTrim,
            cor,
            linhas.Select(l => l.Design).FirstOrDefault(d => !string.IsNullOrWhiteSpace(d)) ?? string.Empty,
            linhas.Count == 0 ? 0 : linhas.Max(StockOf),
            mapped);
    }

    public async Task<QuantidadeAutorizadaAtualizadaDto> AtualizarQuantidadeAutorizadaAsync(
        string biStamp,
        AtualizarQuantidadeAutorizadaRequest request,
        string usrLogin,
        string? usrinis = null,
        CancellationToken cancellationToken = default)
    {
        if (string.IsNullOrWhiteSpace(biStamp))
            throw new PortalBusinessException("bistamp obrigatório.", 400);
        if (string.IsNullOrWhiteSpace(usrLogin))
            throw new PortalBusinessException("Utilizador não autenticado.", 401);
        if (request.QuantidadeAutorizada < 0)
            throw new PortalBusinessException("quantidadeAutorizada inválida.", 400);

        return await _commands.AtualizarQuantidadeAutorizadaAsync(
            biStamp.Trim(),
            request.QuantidadeAutorizada,
            usrLogin.Trim(),
            request.ValorAnteriorEsperado,
            request.PermitirAcimaStock,
            usrinis,
            cancellationToken);
    }

    public async Task<LinhaAtualizadaDto> AtualizarLinhaAsync(
        string biStamp,
        AtualizarLinhaRequest request,
        string usrinis,
        CancellationToken cancellationToken = default)
    {
        if (string.IsNullOrWhiteSpace(biStamp))
            throw new PortalBusinessException("bistamp obrigatório.", 400);
        if (string.IsNullOrWhiteSpace(usrinis))
            throw new PortalBusinessException("usrinis em falta no utilizador.", 400);
        if (request.Quantidade is null && request.PrecoUnitario is null)
            throw new PortalBusinessException("Indicar quantidade e/ou preço.", 400);
        if (request.Quantidade is < 0)
            throw new PortalBusinessException("quantidade inválida.", 400);
        if (request.PrecoUnitario is < 0)
            throw new PortalBusinessException("preço inválido.", 400);

        return await _commands.AtualizarLinhaQttPrecoAsync(
            biStamp.Trim(),
            request.Quantidade,
            request.PrecoUnitario,
            usrinis.Trim(),
            request.QuantidadeAnteriorEsperada,
            request.PrecoAnteriorEsperado,
            cancellationToken);
    }

    public async Task<AlocarArtigoResponseDto> AlocarArtigoAsync(
        string artigoRef,
        AlocarArtigoRequest request,
        string usrLogin,
        bool simular,
        CancellationToken cancellationToken = default)
    {
        if (string.IsNullOrWhiteSpace(artigoRef))
            throw new PortalBusinessException("ref obrigatória.", 400);
        if (!simular && string.IsNullOrWhiteSpace(usrLogin))
            throw new PortalBusinessException("Utilizador não autenticado.", 401);
        if (string.IsNullOrWhiteSpace(request.Modo))
            request = request with { Modo = "Proporcional" };
        if (!string.Equals(request.Modo, "Proporcional", StringComparison.OrdinalIgnoreCase))
            throw new PortalBusinessException("modo inválido (apenas Proporcional).", 400);
        if (request.QuantidadeDisponivel is < 0)
            throw new PortalBusinessException("quantidadeDisponivel inválida.", 400);

        // cor no request (incl. "") → filtrar; null → todas as cores do ref
        var filtrarCor = request.Cor is not null;
        var cor = filtrarCor ? (request.Cor ?? string.Empty).Trim() : null;

        return await _commands.AlocarProporcionalAsync(
            artigoRef.Trim(),
            usrLogin.Trim(),
            simular,
            request.QuantidadeDisponivel,
            cor,
            filtrarCor,
            cancellationToken);
    }

    public async Task<ProntaPickingAtualizadaDto> MarcarProntaPickingAsync(
        string boStamp,
        MarcarProntaPickingRequest request,
        string usrLogin,
        string? usrinis = null,
        CancellationToken cancellationToken = default)
    {
        if (string.IsNullOrWhiteSpace(boStamp))
            throw new PortalBusinessException("bostamp obrigatório.", 400);
        if (string.IsNullOrWhiteSpace(usrLogin))
            throw new PortalBusinessException("Utilizador não autenticado.", 401);
        if (!request.Pronta && string.IsNullOrWhiteSpace(request.Motivo))
            throw new PortalBusinessException("Motivo de cancelamento obrigatório.", 400);

        var motivo = string.IsNullOrWhiteSpace(request.Motivo)
            ? null
            : request.Motivo.Trim();
        if (motivo is { Length: > 254 })
            motivo = motivo[..254];

        return await _commands.MarcarProntaPickingAsync(
            boStamp.Trim(),
            request.Pronta,
            usrLogin.Trim(),
            usrinis,
            request.ConfirmarLinhasSemAutorizacao,
            motivo,
            cancellationToken);
    }

    public async Task<UrgenteAtualizadaDto> MarcarUrgenteAsync(
        string boStamp,
        MarcarUrgenteRequest request,
        string usrLogin,
        string? usrinis = null,
        CancellationToken cancellationToken = default)
    {
        if (string.IsNullOrWhiteSpace(boStamp))
            throw new PortalBusinessException("bostamp obrigatório.", 400);
        if (string.IsNullOrWhiteSpace(usrLogin))
            throw new PortalBusinessException("Utilizador não autenticado.", 401);

        return await _commands.MarcarUrgenteAsync(
            boStamp.Trim(),
            request.Urgente,
            usrLogin.Trim(),
            usrinis,
            cancellationToken);
    }

    public async Task<CancelarEncomendaAtualizadaDto> CancelarEncomendaAsync(
        string boStamp,
        CancelarEncomendaRequest request,
        string usrLogin,
        string? usrinis = null,
        CancellationToken cancellationToken = default)
    {
        if (string.IsNullOrWhiteSpace(boStamp))
            throw new PortalBusinessException("bostamp obrigatório.", 400);
        if (string.IsNullOrWhiteSpace(usrLogin))
            throw new PortalBusinessException("Utilizador não autenticado.", 401);
        if (string.IsNullOrWhiteSpace(request.Motivo))
            throw new PortalBusinessException("Motivo de cancelamento obrigatório.", 400);

        var motivo = request.Motivo.Trim();
        if (motivo.Length > 254)
            motivo = motivo[..254];

        return await _commands.CancelarEncomendaAsync(
            boStamp.Trim(),
            motivo,
            usrLogin.Trim(),
            usrinis,
            cancellationToken);
    }

    private EncomendaListaItemDto MapListaItem(EncomendaResumo e)
    {
        var (etiqueta, codigo) = PlaneamentoCalculator.Classificar(
            e.DataObra,
            e.Hora,
            _planeamento.DiaCorte,
            _planeamento.HoraCorte,
            _planeamento.Fuso);

        return new EncomendaListaItemDto(
            e.BoStamp,
            e.NumeroEncomenda,
            e.NumeroDossier,
            null,
            e.ClienteNo,
            e.ClienteNome,
            string.IsNullOrWhiteSpace(e.ClienteNome2) ? null : e.ClienteNome2,
            e.DataObra.ToString("yyyy-MM-dd"),
            NormalizarHora(e.Hora),
            e.TotalLinhas,
            e.QuantidadeOriginalTotal,
            e.QuantidadePorSatisfazer,
            "Aberto",
            etiqueta,
            codigo,
            e.ProntaPicking,
            string.IsNullOrWhiteSpace(e.ProntaPickingPor) ? null : e.ProntaPickingPor,
            e.ProntaPickingEm,
            e.PickStatus,
            e.Urgente,
            DataEntrega: e.DataEntrega,
            MetodoExpedicao: string.IsNullOrWhiteSpace(e.MetodoExpedicao) ? null : e.MetodoExpedicao,
            MoradaEntrega: string.IsNullOrWhiteSpace(e.MoradaEntrega) ? null : e.MoradaEntrega,
            TemQtt66: e.TemQtt66);
    }

    private static EncomendaLinhaDto MapLinha(EncomendaLinha l) =>
        new(
            l.BiStamp,
            l.Ref,
            l.Design,
            l.Cor,
            l.Unidade,
            l.QuantidadeAtual,
            l.QuantidadeOriginalConsiderada,
            l.QuantidadeAtual,
            l.QuantidadeFornecida,
            l.QuantidadePorSatisfazer,
            l.PrecoUnitario,
            l.PrecoOriginalCampo,
            l.QuantidadeAutorizada,
            string.IsNullOrWhiteSpace(l.QuantidadeAutorizadaPor) ? null : l.QuantidadeAutorizadaPor,
            l.QuantidadeAutorizadaEm,
            l.StockDisponivel,
            string.IsNullOrWhiteSpace(l.Usrinis) ? null : l.Usrinis,
            l.Usrdata?.ToString("yyyy-MM-dd"),
            string.IsNullOrWhiteSpace(l.Usrhora) ? null : NormalizarHora(l.Usrhora),
            l.DisponivelNoPortal);

    private static string NormalizarHora(string hora)
    {
        if (TimeSpan.TryParse(hora?.Trim(), out var ts))
            return ts.ToString(@"hh\:mm\:ss");
        return hora?.Trim() ?? string.Empty;
    }

    public async Task<PickWorkflowAtualizadaDto> PickingStartAsync(
        string boStamp,
        string usrLogin,
        string? usrinis = null,
        CancellationToken cancellationToken = default)
        => await ExecutarPickingWorkflowAsync(
            (s, u, i, ct) => _commands.PickingStartAsync(s, u, i, ct),
            boStamp,
            usrLogin,
            usrinis,
            cancellationToken);

    public async Task<PickWorkflowAtualizadaDto> PickingCompleteAsync(
        string boStamp,
        string usrLogin,
        string? usrinis = null,
        CancellationToken cancellationToken = default)
        => await ExecutarPickingWorkflowAsync(
            (s, u, i, ct) => _commands.PickingCompleteAsync(s, u, i, ct),
            boStamp,
            usrLogin,
            usrinis,
            cancellationToken);

    public async Task<PickWorkflowAtualizadaDto> PickingCancelAsync(
        string boStamp,
        string usrLogin,
        string? usrinis = null,
        string? motivo = null,
        CancellationToken cancellationToken = default)
    {
        if (string.IsNullOrWhiteSpace(boStamp))
            throw new PortalBusinessException("bostamp obrigatório.", 400);
        if (string.IsNullOrWhiteSpace(usrLogin))
            throw new PortalBusinessException("Utilizador não autenticado.", 401);
        if (string.IsNullOrWhiteSpace(motivo))
            throw new PortalBusinessException("Motivo de cancelamento obrigatório.", 400);

        var motivoN = motivo.Trim();
        if (motivoN.Length > 254)
            motivoN = motivoN[..254];

        return await _commands.PickingCancelAsync(
            boStamp.Trim(),
            usrLogin.Trim(),
            usrinis,
            motivoN,
            cancellationToken);
    }

    public async Task<PickWorkflowAtualizadaDto> PickingBackToReadyAsync(
        string boStamp,
        string usrLogin,
        string? usrinis = null,
        CancellationToken cancellationToken = default)
        => await ExecutarPickingWorkflowAsync(
            (s, u, i, ct) => _commands.PickingBackToReadyAsync(s, u, i, ct),
            boStamp,
            usrLogin,
            usrinis,
            cancellationToken);

    public async Task<PickWorkflowAtualizadaDto> PickingReopenAsync(
        string boStamp,
        string usrLogin,
        string? usrinis = null,
        CancellationToken cancellationToken = default)
        => await ExecutarPickingWorkflowAsync(
            (s, u, i, ct) => _commands.PickingReopenAsync(s, u, i, ct),
            boStamp,
            usrLogin,
            usrinis,
            cancellationToken);

    private async Task<PickWorkflowAtualizadaDto> ExecutarPickingWorkflowAsync(
        Func<string, string, string?, CancellationToken, Task<PickWorkflowAtualizadaDto>> action,
        string boStamp,
        string usrLogin,
        string? usrinis,
        CancellationToken cancellationToken)
    {
        if (string.IsNullOrWhiteSpace(boStamp))
            throw new PortalBusinessException("bostamp obrigatório.", 400);
        if (string.IsNullOrWhiteSpace(usrLogin))
            throw new PortalBusinessException("Utilizador não autenticado.", 401);

        return await action(boStamp.Trim(), usrLogin.Trim(), usrinis, cancellationToken);
    }

    /// <summary>
    /// Quantidades não entregues: dossiers ndos=66 fechados com SUM(qtt−qtt2) &gt; 0.
    /// Reutiliza PickingDossiersQuery (não a vista de corte de autorização).
    /// </summary>
    public async Task<CortesQuantidadeResponseDto> ListarCortesQuantidadeAsync(
        CortesQuantidadeFiltro filtro,
        CancellationToken cancellationToken = default)
    {
        var page = Math.Max(1, filtro.Page);
        var pageSize = Math.Clamp(filtro.PageSize, 1, 200);
        var queryFiltro = new EncomendasFiltro
        {
            DataDe = filtro.DataDe,
            DataAte = filtro.DataAte,
            Obrano = filtro.Obrano,
            ArtigoRef = filtro.ArtigoRef,
            ArtigoCor = filtro.ArtigoCor,
            ApenasComPendenteEntrega = true,
            Page = page,
            PageSize = pageSize
        };

        var (items, total) = await _pickingDossiers.ListarAsync(
            queryFiltro,
            _seriePickingNdos,
            fechada: true,
            cancellationToken);

        var mapped = items.Select(e => new CorteEncomendaItemDto(
            e.BoStamp,
            e.NumeroEncomenda,
            e.NumeroDossier,
            string.IsNullOrWhiteSpace(e.NomeSerie) ? null : e.NomeSerie.Trim(),
            e.DataObra.ToString("yyyy-MM-dd"),
            NormalizarHora(e.Hora),
            e.ClienteNo,
            e.ClienteNome,
            string.IsNullOrWhiteSpace(e.ClienteNome2) ? null : e.ClienteNome2,
            e.TotalLinhas,
            e.QuantidadeDocumento,
            e.QuantidadeExpedida,
            e.QuantidadePendenteEntrega,
            true,
            e.Urgente,
            "Fechada")).ToList();

        return new CortesQuantidadeResponseDto(page, pageSize, total, mapped);
    }

    public async Task<IReadOnlyList<CorteQuantidadeLinhaDto>> ListarCortesLinhasAsync(
        string boStamp,
        string? artigoRef = null,
        string? artigoCor = null,
        CancellationToken cancellationToken = default)
    {
        if (string.IsNullOrWhiteSpace(boStamp))
            return Array.Empty<CorteQuantidadeLinhaDto>();

        var linhas = await _pickingDossiers.ListarLinhasAsync(
            boStamp.Trim(),
            _seriePickingNdos,
            cancellationToken);

        IEnumerable<EncomendaLinha> seq = linhas;
        if (!string.IsNullOrWhiteSpace(artigoRef))
        {
            var padrao = artigoRef.Trim();
            seq = seq.Where(l =>
                l.Ref.Contains(padrao, StringComparison.OrdinalIgnoreCase) ||
                l.Design.Contains(padrao, StringComparison.OrdinalIgnoreCase));
        }

        if (!string.IsNullOrWhiteSpace(artigoCor))
        {
            var cor = artigoCor.Trim();
            seq = seq.Where(l =>
                l.Cor.Contains(cor, StringComparison.OrdinalIgnoreCase));
        }

        return seq.Select(l => new CorteQuantidadeLinhaDto(
            l.BiStamp,
            l.BoStamp,
            l.Ref,
            l.Design,
            l.Cor,
            l.Unidade,
            l.QuantidadeAtual,
            l.QuantidadeFornecida,
            EntregaParcialRules.QuantidadePendente(l.QuantidadeAtual, l.QuantidadeFornecida))).ToList();
    }
}

/// <summary>Espelho de Planeamento em Application para não acoplar a Infrastructure.</summary>
public sealed class PlaneamentoSettings
{
    public const string SectionName = "Planeamento";
    public string DiaCorte { get; set; } = "Monday";
    public string HoraCorte { get; set; } = "12:00";
    public string Fuso { get; set; } = "Europe/Lisbon";
}

public sealed class SerieEncomendasSettings
{
    public const string SectionName = "Phc";
    public int SerieEncomendasNdos { get; set; } = 1;
    /// <summary>Série de dossiers de picking (expedição) — ndos = 66.</summary>
    public int SeriePickingNdos { get; set; } = 66;
    /// <summary>Série de dossiers de separação após integração PHC — ndos = 65.</summary>
    public int SerieSeparacaoNdos { get; set; } = 65;
}
