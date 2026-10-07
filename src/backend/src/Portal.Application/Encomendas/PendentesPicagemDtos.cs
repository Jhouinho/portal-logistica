namespace Portal.Application.Encomendas;

public sealed class PendentesPicagemFiltro
{
    public DateTime? DataDe { get; init; }
    public DateTime? DataAte { get; init; }
    public int? Obrano { get; init; }
    public string? ArtigoRef { get; init; }
    public string? ArtigoCor { get; init; }
    public string? ClienteNomeContem { get; init; }
    public int Page { get; init; } = 1;
    /// <summary>Null = devolver todos (compatível com padrão 1A).</summary>
    public int? PageSize { get; init; }
}

/// <summary>Linha BI elegível com pending já calculado (fonte Kapps ou SUM66).</summary>
public sealed record PendentesPicagemLinhaDto(
    string BoStamp,
    string BiStamp,
    int NumeroEncomenda,
    int ClienteNo,
    string ClienteNome,
    string? ClienteNome2,
    string Ref,
    string Designacao,
    string Cor,
    decimal Qtt,
    decimal Qtt2,
    decimal Sum66,
    decimal Picked,
    decimal Pending,
    string Fonte,
    DateTime? DataEntrega,
    string? MetodoExpedicao);

public sealed record PendentesPicagemEncomendaItemDto(
    string BoStamp,
    int NumeroEncomenda,
    int ClienteNo,
    string ClienteNome,
    string? ClienteNome2,
    DateTime? DataEntrega,
    string? MetodoExpedicao,
    decimal QuantidadePendenteTotal,
    int TotalLinhasPendentes,
    IReadOnlyList<PendentesPicagemLinhaDto> Linhas);

public sealed record PendentesPicagemEncomendaListaDto(
    int Page,
    int PageSize,
    int TotalItems,
    IReadOnlyList<PendentesPicagemEncomendaItemDto> Items);

public sealed record PendentesPicagemDocumentoRefDto(
    string BoStamp,
    int NumeroEncomenda,
    int ClienteNo,
    string ClienteNome,
    string? ClienteNome2,
    decimal QuantidadePendente);

public sealed record PendentesPicagemReferenciaItemDto(
    string Ref,
    string Designacao,
    decimal QuantidadePendenteTotal,
    int TotalLinhasPendentes,
    int TotalDocumentos,
    IReadOnlyList<PendentesPicagemDocumentoRefDto> Documentos);

public sealed record PendentesPicagemReferenciaListaDto(
    int Page,
    int PageSize,
    int TotalItems,
    IReadOnlyList<PendentesPicagemReferenciaItemDto> Items);
