namespace Portal.Domain.Encomendas;

public sealed class EncomendaLinha
{
    public required string BiStamp { get; init; }
    public required string BoStamp { get; init; }
    public string Ref { get; init; } = string.Empty;
    public string Design { get; init; } = string.Empty;
    public string Cor { get; init; } = string.Empty;
    public string Unidade { get; init; } = string.Empty;
    public decimal QuantidadeAtual { get; init; }
    public decimal QuantidadeFornecida { get; init; }
    public decimal QuantidadeOriginalCampo { get; init; }
    public decimal QuantidadeOriginalConsiderada { get; init; }
    public decimal QuantidadePorSatisfazer { get; init; }
    public decimal PrecoUnitario { get; init; }
    public decimal PrecoOriginalCampo { get; init; }
    public decimal QuantidadeAutorizada { get; init; }
    public string QuantidadeAutorizadaPor { get; init; } = string.Empty;
    public DateTime? QuantidadeAutorizadaEm { get; init; }
    public decimal StockDisponivel { get; init; }
    /// <summary>STOBS.u_dispPort — true = artigo no universo Portal.</summary>
    public bool DisponivelNoPortal { get; init; } = true;
    public string Usrinis { get; init; } = string.Empty;
    public DateTime? Usrdata { get; init; }
    public string Usrhora { get; init; } = string.Empty;
}
