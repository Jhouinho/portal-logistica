using Microsoft.Extensions.Options;
using Portal.Domain.Encomendas;

namespace Portal.Application.Encomendas;

public sealed class PickingDossiersService
{
    private readonly IPickingDossiersQuery _query;
    private readonly IPickingDossiersCommands _commands;
    private readonly PlaneamentoSettings _planeamento;
    private readonly int _seriePickingNdos;

    public PickingDossiersService(
        IPickingDossiersQuery query,
        IPickingDossiersCommands commands,
        IOptions<PlaneamentoSettings> planeamento,
        IOptions<SerieEncomendasSettings> serie)
    {
        _query = query;
        _commands = commands;
        _planeamento = planeamento.Value;
        _seriePickingNdos = serie.Value.SeriePickingNdos;
    }

    public async Task<EncomendaListaResponseDto> ListarAsync(
        EncomendasFiltro filtro,
        bool fechada,
        CancellationToken cancellationToken = default)
    {
        var page = Math.Max(1, filtro.Page);
        var pageSize = Math.Clamp(filtro.PageSize, 1, 200);

        var queryFiltro = new EncomendasFiltro
        {
            DataDe = filtro.DataDe,
            DataAte = filtro.DataAte,
            HoraDe = filtro.HoraDe,
            HoraAte = filtro.HoraAte,
            ClienteNo = filtro.ClienteNo,
            ClienteNoContem = filtro.ClienteNoContem,
            ClienteNomeContem = filtro.ClienteNomeContem,
            ArtigoRef = filtro.ArtigoRef,
            ArtigoCor = filtro.ArtigoCor,
            PickStatus = filtro.PickStatus,
            CheckIn = filtro.CheckIn,
            Page = 1,
            PageSize = 5000
        };

        var (items, _) = await _query.ListarAsync(
            queryFiltro,
            _seriePickingNdos,
            fechada,
            cancellationToken);

        var mapped = items
            .Select(MapListaItem)
            .Where(i => PlaneamentoCalculator.CoincideFiltro(i.EstadoPlaneamentoCodigo, filtro.EstadoPlaneamento))
            .Where(i => MetodoExpedicaoFiltro.Coincide(i.MetodoExpedicao, filtro.MetodoExpedicao))
            .Where(i => filtro.PickStatus is null || i.PickStatus == filtro.PickStatus.Value)
            .Where(i => filtro.CheckIn is null || i.CheckIn == filtro.CheckIn.Value)
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

    public async Task<IReadOnlyList<EncomendaLinhaDto>> ListarLinhasAsync(
        string boStamp,
        CancellationToken cancellationToken = default)
    {
        if (string.IsNullOrWhiteSpace(boStamp))
            return Array.Empty<EncomendaLinhaDto>();

        var linhas = await _query.ListarLinhasAsync(
            boStamp.Trim(),
            _seriePickingNdos,
            cancellationToken);

        return linhas.Select(MapLinha).ToList();
    }

    public Task<FechoPickingAtualizadaDto> MarcarFechoAsync(
        string boStamp,
        MarcarFechoPickingRequest request,
        string? usrLogin,
        CancellationToken cancellationToken = default)
    {
        if (string.IsNullOrWhiteSpace(boStamp))
            throw new PortalBusinessException("bostamp obrigatório.", 400);

        return _commands.MarcarFechoAsync(
            boStamp.Trim(),
            request.Fechada,
            _seriePickingNdos,
            usrLogin,
            cancellationToken);
    }

    public async Task<CheckInLoteResponseDto> MarcarCheckInLoteAsync(
        MarcarCheckInRequest request,
        string usrLogin,
        string? usrinis,
        CancellationToken cancellationToken = default)
    {
        if (string.IsNullOrWhiteSpace(usrLogin))
            throw new PortalBusinessException("Utilizador obrigatório.", 401);

        var stamps = (request.BoStamps ?? Array.Empty<string>())
            .Select(s => s?.Trim() ?? string.Empty)
            .Where(s => !string.IsNullOrWhiteSpace(s))
            .Distinct(StringComparer.OrdinalIgnoreCase)
            .ToList();

        if (stamps.Count == 0)
            throw new PortalBusinessException("Seleccione pelo menos um dossier.", 400);

        var resultados = new List<CheckInLoteItemDto>(stamps.Count);
        foreach (var stamp in stamps)
        {
            try
            {
                var result = await _commands.MarcarCheckInAsync(
                    stamp,
                    checkIn: true,
                    _seriePickingNdos,
                    usrLogin.Trim(),
                    usrinis,
                    cancellationToken);
                resultados.Add(new CheckInLoteItemDto(stamp, true, null, result));
            }
            catch (PortalBusinessException ex)
            {
                resultados.Add(new CheckInLoteItemDto(stamp, false, ex.Message, null));
            }
        }

        var sucesso = resultados.Count(r => r.Ok);
        return new CheckInLoteResponseDto(
            resultados.Count,
            sucesso,
            resultados.Count - sucesso,
            resultados);
    }

    public Task<CheckInAtualizadaDto> ReverterCheckInAsync(
        string boStamp,
        string usrLogin,
        string? usrinis,
        CancellationToken cancellationToken = default)
    {
        if (string.IsNullOrWhiteSpace(boStamp))
            throw new PortalBusinessException("bostamp obrigatório.", 400);
        if (string.IsNullOrWhiteSpace(usrLogin))
            throw new PortalBusinessException("Utilizador obrigatório.", 401);

        return _commands.ReverterCheckInAsync(
            boStamp.Trim(),
            _seriePickingNdos,
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
            string.IsNullOrWhiteSpace(e.NomeSerie) ? null : e.NomeSerie.Trim(),
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
            e.CheckIn,
            string.IsNullOrWhiteSpace(e.CheckInPor) ? null : e.CheckInPor,
            e.CheckInEm,
            MetodoExpedicao: string.IsNullOrWhiteSpace(e.MetodoExpedicao) ? null : e.MetodoExpedicao,
            NumeroPicking: e.NumeroPicking,
            NumeroSeparacao: e.NumeroSeparacao,
            QuantidadeDocumento: e.QuantidadeDocumento,
            QuantidadeExpedida: e.QuantidadeExpedida,
            QuantidadePendenteEntrega: e.QuantidadePendenteEntrega,
            MoradaEntrega: string.IsNullOrWhiteSpace(e.MoradaEntrega) ? null : e.MoradaEntrega);
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
            string.IsNullOrWhiteSpace(l.Usrhora) ? null : NormalizarHora(l.Usrhora));

    private static string NormalizarHora(string hora)
    {
        if (TimeSpan.TryParse(hora?.Trim(), out var ts))
            return ts.ToString(@"hh\:mm\:ss");
        return hora?.Trim() ?? string.Empty;
    }
}
