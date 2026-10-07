namespace Portal.Domain.Encomendas;

public sealed class CorteQuantidadeLinha
{
    public string BiStamp { get; init; } = string.Empty;
    public string BoStamp { get; init; } = string.Empty;
    public int NumeroEncomenda { get; init; }
    public DateTime DataObra { get; init; }
    public int ClienteNo { get; init; }
    public string ClienteNome { get; init; } = string.Empty;
    public string Ref { get; init; } = string.Empty;
    public string Design { get; init; } = string.Empty;
    public string Cor { get; init; } = string.Empty;
    public string Unidade { get; init; } = string.Empty;
    public decimal QuantidadeOriginal { get; init; }
    public decimal QuantidadeAutorizada { get; init; }
    public decimal QuantidadeNaoAutorizada { get; init; }
    public decimal QuantidadeFornecida { get; init; }
    public bool ProntaPicking { get; init; }
    public bool Fechada { get; init; }
}
