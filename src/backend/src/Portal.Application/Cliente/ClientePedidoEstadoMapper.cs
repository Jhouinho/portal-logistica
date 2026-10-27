namespace Portal.Application.Cliente;

/// <summary>
/// Mapeamento estado interno / legado → apresentação ao cliente.
/// Após dossier PHC ligado: <c>integrado</c> (legado) e <c>em_separacao</c> apresentam-se
/// como «Em separação»; progresso seguinte: pronto_levantamento → concluido.
/// </summary>
public static class ClientePedidoEstadoMapper
{
    public const string OrigemInterno = "interno";
    public const string OrigemLegado = "legado";

    /// <summary>Fluxo legado (BO ndos=67): mantém códigos históricos.</summary>
    public static (string Codigo, string Etiqueta, bool PodeCancelar) Map(bool cancelado)
    {
        if (cancelado)
            return ("cancelado", "Cancelado", false);
        return ("submetido", "Pedido submetido", true);
    }

    /// <summary>Pedido interno (tabelas u_HcaPm*). Cliente não cancela após submissão.</summary>
    public static (string Codigo, string Etiqueta, bool PodeCancelar) MapInterno(string estadoInterno)
    {
        return (estadoInterno ?? "").Trim().ToLowerInvariant() switch
        {
            "cancelado" => ("cancelado", "Cancelado", false),
            "rejeitado" => ("rejeitado", "Rejeitado", false),
            "em_analise" => ("em_analise", "Em análise", false),
            "em_aprovacao" => ("em_aprovacao", "Em aprovação", false),
            "integrado" => ("em_separacao", "Em separação", false),
            "em_separacao" => ("em_separacao", "Em separação", false),
            "pronto_levantamento" => ("pronto_levantamento", "Pronto para levantamento", false),
            "concluido" => ("concluido", "Concluído", false),
            _ => ("recebido", "Recebido", false)
        };
    }
}
