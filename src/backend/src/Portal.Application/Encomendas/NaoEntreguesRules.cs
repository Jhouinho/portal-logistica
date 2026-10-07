namespace Portal.Application.Encomendas;

/// <summary>
/// Critério de listagem «Quantidades não entregues»: dossiers ndos=66
/// fechados com quantidade pendente de entrega (BI.qtt − BI.qtt2) &gt; 0.
/// </summary>
public static class NaoEntreguesRules
{
    /// <summary>
    /// Indica se o dossier deve aparecer na área /nao-entregues.
    /// Assume já filtrado a ndos=66; aplica apenas fechada + pendente.
    /// </summary>
    public static bool DeveAparecerNaLista(bool fechada, decimal quantidadePendenteEntrega) =>
        fechada && quantidadePendenteEntrega > 0m;

    public static decimal QuantidadePendente(decimal quantidadeDocumento, decimal quantidadeExpedida) =>
        EntregaParcialRules.QuantidadePendente(quantidadeDocumento, quantidadeExpedida);
}
