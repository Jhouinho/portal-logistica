using Microsoft.Extensions.Options;
using Portal.Application.Encomendas;

namespace Portal.Application.Painel;

public sealed class PainelService
{
    private readonly IPainelQuery _query;
    private readonly PlaneamentoSettings _planeamento;
    private readonly int _serieNdos;
    private readonly int _seriePickingNdos;
    private readonly int _serieSeparacaoNdos;

    public PainelService(
        IPainelQuery query,
        IOptions<PlaneamentoSettings> planeamento,
        IOptions<SerieEncomendasSettings> serie)
    {
        _query = query;
        _planeamento = planeamento.Value;
        _serieNdos = serie.Value.SerieEncomendasNdos;
        _seriePickingNdos = serie.Value.SeriePickingNdos;
        _serieSeparacaoNdos = serie.Value.SerieSeparacaoNdos;
    }

    public async Task<PainelKpisDto> ObterKpisAsync(CancellationToken cancellationToken = default)
    {
        var rows = await _query.ListarAbertasParaKpisAsync(_serieNdos, cancellationToken);
        var aposCorte = 0;
        decimal qtdPorSatisfazer = 0;
        decimal qtdAutorizada = 0;
        var clientes = new HashSet<int>();

        foreach (var r in rows)
        {
            var (_, codigo) = PlaneamentoCalculator.Classificar(
                r.DataObra,
                r.Hora,
                _planeamento.DiaCorte,
                _planeamento.HoraCorte,
                _planeamento.Fuso);

            if (codigo == "AC")
                aposCorte++;

            qtdPorSatisfazer += r.QuantidadePorSatisfazer;
            qtdAutorizada += r.QuantidadeAutorizada;
            clientes.Add(r.ClienteNo);
        }

        var rutura = await _query.ContarArtigosEmRuturaAsync(cancellationToken);

        return new PainelKpisDto(
            rows.Count,
            aposCorte,
            rutura,
            qtdPorSatisfazer,
            qtdAutorizada,
            clientes.Count);
    }

    public async Task<CentroEstadosKpisDto> ObterCentroEstadosAsync(
        CancellationToken cancellationToken = default)
    {
        var rowTask = _query.ContarEstadosCentroAsync(
            _serieNdos,
            _seriePickingNdos,
            _serieSeparacaoNdos,
            cancellationToken);
        var distTask = _query.ContarDistribuicaoLogicaAsync(
            _serieNdos,
            _seriePickingNdos,
            _serieSeparacaoNdos,
            cancellationToken);
        await Task.WhenAll(rowTask, distTask);

        var row = await rowTask;
        var dist = await distTask;
        var total = row.EmAberto + row.EmPicking + row.Expedicao + row.Concluidas;
        return new CentroEstadosKpisDto(
            row.EmAberto,
            row.EmPicking,
            row.Expedicao,
            row.Separado,
            row.EmEntrega,
            row.Expedido,
            row.Concluidas,
            total,
            DistribuicaoLogicaCalculator.FromContagens(dist));
    }

    /// <summary>Resumo Kapps para Vista TV — 1 roundtrip em vez de N+1 detalhe.</summary>
    public async Task<TvKappsResumoDto> ObterTvKappsResumoAsync(
        CancellationToken cancellationToken = default)
    {
        var rows = await _query.ListarTvKappsResumoAsync(
            _serieNdos,
            _seriePickingNdos,
            cancellationToken);
        var items = rows.Select(TvKappsResumoCalculator.ToItem).ToList();
        return new TvKappsResumoDto(items);
    }
}
