using Microsoft.Extensions.Options;

namespace Portal.Application.Encomendas;

public sealed class PendentesPicagemService
{
    private readonly IPendentesPicagemQuery _query;
    private readonly int _serieEncomendas;
    private readonly int _seriePicking;

    public PendentesPicagemService(
        IPendentesPicagemQuery query,
        IOptions<SerieEncomendasSettings> serie)
    {
        _query = query;
        _serieEncomendas = serie.Value.SerieEncomendasNdos;
        _seriePicking = serie.Value.SeriePickingNdos;
    }

    public async Task<PendentesPicagemEncomendaListaDto> ListarPorEncomendaAsync(
        PendentesPicagemFiltro filtro,
        CancellationToken cancellationToken = default)
    {
        var linhas = await _query.ListarLinhasPendentesAsync(
            filtro,
            _serieEncomendas,
            _seriePicking,
            cancellationToken);

        var grupos = linhas
            .GroupBy(l => l.BoStamp, StringComparer.OrdinalIgnoreCase)
            .Select(g =>
            {
                var ordered = g.OrderBy(l => l.Ref, StringComparer.OrdinalIgnoreCase)
                    .ThenBy(l => l.BiStamp, StringComparer.OrdinalIgnoreCase)
                    .ToList();
                var head = ordered[0];
                return new PendentesPicagemEncomendaItemDto(
                    head.BoStamp,
                    head.NumeroEncomenda,
                    head.ClienteNo,
                    head.ClienteNome,
                    head.ClienteNome2,
                    head.DataEntrega,
                    head.MetodoExpedicao,
                    PendentesPicagemRules.SomarPendentesEncomenda(ordered.Select(l => l.Pending)),
                    ordered.Count,
                    ordered);
            })
            .OrderByDescending(e => e.NumeroEncomenda)
            .ThenBy(e => e.BoStamp, StringComparer.OrdinalIgnoreCase)
            .ToList();

        return Paginar(grupos, filtro.Page, filtro.PageSize);
    }

    public async Task<PendentesPicagemReferenciaListaDto> ListarPorReferenciaAsync(
        PendentesPicagemFiltro filtro,
        CancellationToken cancellationToken = default)
    {
        var linhas = await _query.ListarLinhasPendentesAsync(
            filtro,
            _serieEncomendas,
            _seriePicking,
            cancellationToken);

        var grupos = linhas
            .GroupBy(l => l.Ref.Trim(), StringComparer.OrdinalIgnoreCase)
            .Select(g =>
            {
                var ordered = g.OrderByDescending(l => l.NumeroEncomenda)
                    .ThenBy(l => l.BoStamp, StringComparer.OrdinalIgnoreCase)
                    .ToList();
                var docs = ordered
                    .GroupBy(l => l.BoStamp, StringComparer.OrdinalIgnoreCase)
                    .Select(dg =>
                    {
                        var h = dg.First();
                        return new PendentesPicagemDocumentoRefDto(
                            h.BoStamp,
                            h.NumeroEncomenda,
                            h.ClienteNo,
                            h.ClienteNome,
                            h.ClienteNome2,
                            PendentesPicagemRules.SomarPendentesEncomenda(dg.Select(x => x.Pending)));
                    })
                    .OrderByDescending(d => d.NumeroEncomenda)
                    .ToList();

                var head = ordered[0];
                return new PendentesPicagemReferenciaItemDto(
                    head.Ref.Trim(),
                    head.Designacao,
                    PendentesPicagemRules.SomarPendentesEncomenda(ordered.Select(l => l.Pending)),
                    ordered.Count,
                    docs.Count,
                    docs);
            })
            .OrderBy(r => r.Ref, StringComparer.OrdinalIgnoreCase)
            .ToList();

        return PaginarRef(grupos, filtro.Page, filtro.PageSize);
    }

    public async Task<IReadOnlyList<PendentesPicagemLinhaDto>> ListarLinhasEncomendaAsync(
        string boStamp,
        CancellationToken cancellationToken = default)
    {
        if (string.IsNullOrWhiteSpace(boStamp))
            return Array.Empty<PendentesPicagemLinhaDto>();

        var linhas = await _query.ListarLinhasPendentesAsync(
            new PendentesPicagemFiltro(),
            _serieEncomendas,
            _seriePicking,
            cancellationToken);

        return linhas
            .Where(l => string.Equals(l.BoStamp, boStamp.Trim(), StringComparison.OrdinalIgnoreCase))
            .OrderBy(l => l.Ref, StringComparer.OrdinalIgnoreCase)
            .ThenBy(l => l.BiStamp, StringComparer.OrdinalIgnoreCase)
            .ToList();
    }

    private static PendentesPicagemEncomendaListaDto Paginar(
        IReadOnlyList<PendentesPicagemEncomendaItemDto> all,
        int page,
        int? pageSize)
    {
        var total = all.Count;
        if (pageSize is null || pageSize <= 0)
        {
            return new PendentesPicagemEncomendaListaDto(
                1,
                Math.Max(total, 1),
                total,
                all);
        }

        var p = Math.Max(1, page);
        var size = Math.Clamp(pageSize.Value, 1, 200);
        var slice = all.Skip((p - 1) * size).Take(size).ToList();
        return new PendentesPicagemEncomendaListaDto(p, size, total, slice);
    }

    private static PendentesPicagemReferenciaListaDto PaginarRef(
        IReadOnlyList<PendentesPicagemReferenciaItemDto> all,
        int page,
        int? pageSize)
    {
        var total = all.Count;
        if (pageSize is null || pageSize <= 0)
        {
            return new PendentesPicagemReferenciaListaDto(
                1,
                Math.Max(total, 1),
                total,
                all);
        }

        var p = Math.Max(1, page);
        var size = Math.Clamp(pageSize.Value, 1, 200);
        var slice = all.Skip((p - 1) * size).Take(size).ToList();
        return new PendentesPicagemReferenciaListaDto(p, size, total, slice);
    }
}
