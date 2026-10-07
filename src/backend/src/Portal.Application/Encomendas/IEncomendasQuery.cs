using Portal.Domain.Encomendas;

namespace Portal.Application.Encomendas;

public sealed record ArtigoSugestaoDto(string Ref, string Design, string Cor);

/// <summary>Chave Ref+Cor para cálculo Prev* (Fase 2 da procura aberta).</summary>
public sealed record ArtigoRefCorChave(string Ref, string Cor);

/// <summary>Stock previsão (Previsto − Alocado) por Ref+Cor.</summary>
public sealed record ArtigoStockPrevDto(string Ref, string Cor, decimal StockDisponivel);

/// <summary>Filtros SQL da procura aberta por linha (antes do agrupamento / planeamento).</summary>
public sealed class ArtigoProcuraLinhasFiltro
{
    /// <summary>Match exacto de referência (detalhe por artigo).</summary>
    public string? RefExact { get; init; }

    /// <summary>
    /// Match exacto de cor: <c>null</c> = todas; <c>""</c> = só sem cor.
    /// </summary>
    public string? CorExact { get; init; }

    public string? RefOuDesignContem { get; init; }
    public string? CorContem { get; init; }
    public DateTime? DataDe { get; init; }
    public DateTime? DataAte { get; init; }
    public TimeSpan? HoraDe { get; init; }
    public TimeSpan? HoraAte { get; init; }
    public string? ClienteNoContem { get; init; }
    public string? MetodoExpedicao { get; init; }
}

public interface IEncomendasQuery
{
    Task<(IReadOnlyList<EncomendaResumo> Items, int Total)> ListarAbertasAsync(
        EncomendasFiltro filtro,
        int serieNdos,
        CancellationToken cancellationToken = default);

    Task<(EncomendaResumo? Cabecalho, IReadOnlyList<EncomendaLinha> Linhas)> ObterDetalheAsync(
        string boStamp,
        int serieNdos,
        CancellationToken cancellationToken = default);

    Task<IReadOnlyList<ArtigoSugestaoDto>> SugerirArtigosAsync(
        string termo,
        int serieNdos,
        int limit = 20,
        CancellationToken cancellationToken = default);

    Task<IReadOnlyList<string>> SugerirCoresAsync(
        string termo,
        int serieNdos,
        int limit = 20,
        CancellationToken cancellationToken = default);

    /// <summary>
    /// Linhas abertas (restante &gt; 0) para resumo / distribuição por artigo.
    /// Não calcula Prev*/stock — usar <see cref="ObterStockDisponivelPrevPorChavesAsync"/>.
    /// </summary>
    Task<IReadOnlyList<ArtigoLinhaAberta>> ListarLinhasAbertasProcuraAsync(
        int serieNdos,
        ArtigoProcuraLinhasFiltro? filtro = null,
        CancellationToken cancellationToken = default);

    /// <summary>
    /// Stock previsão (B2: Previsto − Alocado) só para as chaves Ref+Cor pedidas.
    /// Sem filtros ndos/fecho/pronta_picking no alocado.
    /// </summary>
    Task<IReadOnlyList<ArtigoStockPrevDto>> ObterStockDisponivelPrevPorChavesAsync(
        IReadOnlyList<ArtigoRefCorChave> chaves,
        CancellationToken cancellationToken = default);

    /// <summary>Encomendas com pelo menos uma linha de corte (agregado por documento).</summary>
    Task<(IReadOnlyList<CorteQuantidadeEncomenda> Items, int Total)> ListarCortesEncomendasAsync(
        CortesQuantidadeFiltro filtro,
        int serieNdos,
        CancellationToken cancellationToken = default);

    /// <summary>Linhas de corte de uma encomenda.</summary>
    Task<IReadOnlyList<CorteQuantidadeLinha>> ListarCortesLinhasPorEncomendaAsync(
        string boStamp,
        int serieNdos,
        string? artigoRef = null,
        string? artigoCor = null,
        CancellationToken cancellationToken = default);
}
