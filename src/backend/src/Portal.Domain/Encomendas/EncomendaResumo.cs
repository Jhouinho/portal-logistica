namespace Portal.Domain.Encomendas;

public sealed class EncomendaResumo
{
    public required string BoStamp { get; init; }
    public int NumeroEncomenda { get; init; }
    /// <summary>Nº do dossier (série 66/65), quando aplicável.</summary>
    public int? NumeroDossier { get; init; }
    /// <summary>Nº do dossier de picking (ndos=66), quando resolvido.</summary>
    public int? NumeroPicking { get; init; }
    /// <summary>Nº do dossier de separação/expedição (ndos=65), quando resolvido.</summary>
    public int? NumeroSeparacao { get; init; }
    public int Ndos { get; init; }
    public string NomeSerie { get; init; } = string.Empty;
    public DateTime DataObra { get; init; }
    public string Hora { get; init; } = string.Empty;
    public int ClienteNo { get; init; }
    public int ClienteEstab { get; init; }
    public string ClienteNome { get; init; } = string.Empty;
    /// <summary>BO.nome2 — nome principal na apresentação (PR5).</summary>
    public string ClienteNome2 { get; init; } = string.Empty;
    public int TotalLinhas { get; init; }
    public decimal QuantidadeOriginalTotal { get; init; }
    public decimal QuantidadeAtualTotal { get; init; }
    public decimal QuantidadePorSatisfazer { get; init; }
    public decimal QuantidadeAutorizadaTotal { get; init; }
    /// <summary>SUM(BI.qtt) — quantidade do documento (ndos=66 Separado).</summary>
    public decimal QuantidadeDocumento { get; init; }
    /// <summary>SUM(BI.qtt2) — quantidade já expedida (ndos=66 Separado).</summary>
    public decimal QuantidadeExpedida { get; init; }
    /// <summary>SUM(BI.qtt − BI.qtt2) — pendente de entrega (ndos=66 Separado).</summary>
    public decimal QuantidadePendenteEntrega { get; init; }
    public bool ProntaPicking { get; init; }
    public string ProntaPickingPor { get; init; } = string.Empty;
    public DateTime? ProntaPickingEm { get; init; }
    public int PickStatus { get; init; }
    public bool Urgente { get; init; }
    /// <summary>BO3.TAXPOINTDT — data de entrega (leitura). Null se ausente/inválida.</summary>
    public DateTime? DataEntrega { get; init; }
    /// <summary>BO3.u_modExp — método de expedição (leitura PHC).</summary>
    public string MetodoExpedicao { get; init; } = string.Empty;
    /// <summary>BO2.u_mEntrega — morada de entrega (texto corrido; leitura).</summary>
    public string MoradaEntrega { get; init; } = string.Empty;
    /// <summary>Check-in (BO3.u_chkin) — tipicamente dossiers ndos=66.</summary>
    public bool CheckIn { get; init; }
    public string CheckInPor { get; init; } = string.Empty;
    public DateTime? CheckInEm { get; init; }
    /// <summary>REGRA B: existe linha com SUM(66.BI.qtt) &gt; 0 via obistamp.</summary>
    public bool TemQtt66 { get; init; }
}
