namespace Portal.Application.Encomendas;

/// <summary>
/// Regras de apresentação de expedição parcial em dossiers ndos=66 (Separado).
/// Usa exclusivamente BI.qtt / BI.qtt2 do próprio documento.
/// </summary>
public static class EntregaParcialRules
{
    public static decimal QuantidadePendente(decimal quantidadeDocumento, decimal quantidadeExpedida) =>
        quantidadeDocumento - quantidadeExpedida;

    /// <summary>
    /// Entrega parcial: já houve expedição e ainda há quantidade pendente no mesmo dossier.
    /// </summary>
    public static bool IsEntregaParcial(decimal quantidadeExpedida, decimal quantidadePendenteEntrega) =>
        quantidadeExpedida > 0m && quantidadePendenteEntrega > 0m;

    public static bool IsEntregaParcialFromLinha(decimal qtt, decimal qtt2) =>
        IsEntregaParcial(qtt2, QuantidadePendente(qtt, qtt2));
}
