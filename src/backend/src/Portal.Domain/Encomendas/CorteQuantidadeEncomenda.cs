namespace Portal.Domain.Encomendas;

public sealed class CorteQuantidadeEncomenda
{
    public string BoStamp { get; init; } = string.Empty;
    public int NumeroEncomenda { get; init; }
    public DateTime DataObra { get; init; }
    public string Hora { get; init; } = string.Empty;
    public int ClienteNo { get; init; }
    public string ClienteNome { get; init; } = string.Empty;
    public int TotalLinhas { get; init; }
    public decimal QuantidadeOriginalTotal { get; init; }
    public decimal QuantidadeAutorizadaTotal { get; init; }
    public decimal QuantidadeNaoAutorizadaTotal { get; init; }
    public bool ProntaPicking { get; init; }
    public bool Fechada { get; init; }
    public bool Urgente { get; init; }
}
