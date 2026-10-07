namespace Portal.Domain.Encomendas;

/// <summary>Linha BI aberta (restante &gt; 0) para agregação / distribuição por artigo.</summary>
public sealed class ArtigoLinhaAberta
{
    public required string BiStamp { get; init; }
    public required string BoStamp { get; init; }
    public int NumeroEncomenda { get; init; }
    public DateTime DataObra { get; init; }
    public string Hora { get; init; } = string.Empty;
    public int ClienteNo { get; init; }
    public string ClienteNome { get; init; } = string.Empty;
    /// <summary>BO.nome2 — nome principal na apresentação (PR5).</summary>
    public string ClienteNome2 { get; init; } = string.Empty;
    public string Ref { get; init; } = string.Empty;
    public string Design { get; init; } = string.Empty;
    public string Cor { get; init; } = string.Empty;
    public string Unidade { get; init; } = string.Empty;
    public decimal QuantidadeAtual { get; init; }
    public decimal QuantidadeFornecida { get; init; }
    public decimal QuantidadeOriginalConsiderada { get; init; }
    public decimal QuantidadePorSatisfazer { get; init; }
    public decimal PrecoUnitario { get; init; }
    public decimal PrecoOriginalCampo { get; init; }
    public decimal QuantidadeAutorizada { get; init; }
    public string QuantidadeAutorizadaPor { get; init; } = string.Empty;
    public DateTime? QuantidadeAutorizadaEm { get; init; }
    public decimal StockDisponivel { get; init; }
    public bool Urgente { get; init; }
    /// <summary>BO3.TAXPOINTDT — data de entrega (leitura).</summary>
    public DateTime? DataEntrega { get; init; }
    /// <summary>BO3.u_modExp — método de expedição (leitura PHC).</summary>
    public string MetodoExpedicao { get; init; } = string.Empty;
    public string Usrinis { get; init; } = string.Empty;
    public DateTime? Usrdata { get; init; }
    public string Usrhora { get; init; } = string.Empty;

    /// <summary>Alias legado: quantidade pedida = original considerada.</summary>
    public decimal QuantidadePedida => QuantidadeOriginalConsiderada;
}
