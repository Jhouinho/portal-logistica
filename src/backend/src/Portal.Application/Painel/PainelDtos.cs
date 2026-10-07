namespace Portal.Application.Painel;

public sealed record PainelKpisDto(
    int EncomendasEmAberto,
    int EncomendasAposCorte,
    int ArtigosEmRutura,
    decimal QuantidadePorSatisfazer,
    decimal QuantidadeAutorizada,
    int ClientesAfetados);

/// <summary>
/// Contagens do Centro / menu: abertas, picking, expedição (66 abertos),
/// separado (66 sem check-in), a preparar entrega (66 com check-in),
/// expedido (65 abertos), concluídas (65 fechados).
/// </summary>
public sealed record CentroEstadosKpisDto(
    int EmAberto,
    int EmPicking,
    int Expedicao,
    int Separado,
    int EmEntrega,
    int Expedido,
    int Concluidas,
    int Total,
    DistribuicaoLogicaDto DistribuicaoLogica);

/// <summary>
/// Distribuição de encomendas lógicas (bostamp ndos=1) pelos 5 estados do circuito.
/// Quantidades podem ser fraccionadas (ex.: 0,5 Separado + 0,5 Em Expedição).
/// Independente dos COUNTs de documentos em <see cref="CentroEstadosKpisDto"/>.
/// </summary>
public sealed record DistribuicaoLogicaDto(
    int TotalEncomendasLogicas,
    EstadoDistribuicaoLogicaDto EmAberto,
    EstadoDistribuicaoLogicaDto EmPicking,
    EstadoDistribuicaoLogicaDto Separado,
    EstadoDistribuicaoLogicaDto EmEntrega,
    EstadoDistribuicaoLogicaDto EmExpedicao,
    int NaoClassificadas);

public sealed record EstadoDistribuicaoLogicaDto(decimal Quantidade, decimal Percentagem);

/// <summary>Resumo Kapps magro para Vista TV (1 HTTP em vez de N+1 detalhe).</summary>
public sealed record TvKappsResumoDto(IReadOnlyList<TvKappsResumoItemDto> Items);

public sealed record TvKappsResumoItemDto(
    string BoStamp,
    string Origem,
    decimal Qty,
    decimal Picked,
    decimal Pending,
    string Kind,
    int Pct,
    int? ActiveTerminalId,
    string? ActiveTerminalLabel,
    string? ActiveUserId);

/// <summary>Linha crua da query TV (antes de kind/pct).</summary>
public sealed class TvKappsResumoRow
{
    public string BoStamp { get; init; } = string.Empty;
    public string Origem { get; init; } = string.Empty;
    public decimal Qty { get; init; }
    public decimal Picked { get; init; }
    public decimal Pending { get; init; }
    public int? ActiveTerminalId { get; init; }
    public string? ActiveTerminalLabel { get; init; }
    public string? ActiveUserId { get; init; }
}

public sealed class PainelEncomendaAggRow
{
    public DateTime DataObra { get; init; }
    public string Hora { get; init; } = string.Empty;
    public int ClienteNo { get; init; }
    public decimal QuantidadePorSatisfazer { get; init; }
    public decimal QuantidadeAutorizada { get; init; }
}

public sealed class CentroEstadosContagemRow
{
    public int EmAberto { get; init; }
    public int EmPicking { get; init; }
    public int Expedicao { get; init; }
    public int Separado { get; init; }
    public int EmEntrega { get; init; }
    public int Expedido { get; init; }
    public int Concluidas { get; init; }
}

/// <summary>
/// Contagens fraccionadas de encomendas lógicas (soma das unidades ≈ TotalEncomendasLogicas).
/// </summary>
public sealed class DistribuicaoLogicaContagemRow
{
    public decimal EmAberto { get; init; }
    public decimal EmPicking { get; init; }
    public decimal Separado { get; init; }
    public decimal EmEntrega { get; init; }
    public decimal EmExpedicao { get; init; }
    public decimal NaoClassificadas { get; init; }
    /// <summary>Número de encomendas lógicas no universo (denominador das %).</summary>
    public int TotalEncomendasLogicas { get; init; }
}

/// <summary>Factos por encomenda lógica antes de aplicar <see cref="DistribuicaoLogicaCalculator.Contribuir"/>.</summary>
public sealed class DistribuicaoLogicaFactoRow
{
    public int N66Separado { get; init; }
    public int N66EmEntrega { get; init; }
    public bool Tem65 { get; init; }
    public bool? ProntaPicking { get; init; }
    /// <summary>Pronto a picking e ainda com linhas ndos=1 não totalmente cobertas por SUM(66).</summary>
    public bool AindaEmPicking { get; init; }
}

public interface IPainelQuery
{
    Task<IReadOnlyList<PainelEncomendaAggRow>> ListarAbertasParaKpisAsync(
        int serieNdos,
        CancellationToken cancellationToken = default);

    Task<int> ContarArtigosEmRuturaAsync(CancellationToken cancellationToken = default);

    Task<CentroEstadosContagemRow> ContarEstadosCentroAsync(
        int serieNdos,
        int seriePickingNdos,
        int serieSeparacaoNdos,
        CancellationToken cancellationToken = default);

    /// <summary>
    /// Factos por encomenda lógica (ndos=1); pesos fraccionados via
    /// <see cref="DistribuicaoLogicaCalculator.Contribuir"/>.
    /// </summary>
    Task<DistribuicaoLogicaContagemRow> ContarDistribuicaoLogicaAsync(
        int serieNdos,
        int seriePickingNdos,
        int serieSeparacaoNdos,
        CancellationToken cancellationToken = default);

    /// <summary>
    /// Resumo Kapps para TV: encomendas pronta_picking + dossiers 66 abertos sem check-in.
    /// </summary>
    Task<IReadOnlyList<TvKappsResumoRow>> ListarTvKappsResumoAsync(
        int serieEncomendasNdos,
        int seriePickingNdos,
        CancellationToken cancellationToken = default);
}
