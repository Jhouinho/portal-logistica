namespace Portal.Application.Encomendas;

/// <summary>
/// Leitura set-based das linhas ndos=1 com pending híbrido Kapps / SUM66.
/// Não altera regras de Em Picking / REGRA B.
/// </summary>
public interface IPendentesPicagemQuery
{
    /// <summary>
    /// Universo completo de linhas com <c>Pending &gt; 0</c> (sem paginação).
    /// Filtros opcionais aplicados nas linhas base.
    /// </summary>
    Task<IReadOnlyList<PendentesPicagemLinhaDto>> ListarLinhasPendentesAsync(
        PendentesPicagemFiltro filtro,
        int serieEncomendasNdos,
        int seriePickingNdos,
        CancellationToken cancellationToken = default);
}
