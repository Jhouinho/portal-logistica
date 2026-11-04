namespace Portal.Application.Cliente;

/// <summary>
/// Mapeamento estado interno / legado → apresentação.
/// Circuito balcão (1B+2C): após dossier PHC ligado, <c>integrado</c> / <c>em_separacao</c>
/// (e estados operacionais legados) apresentam-se como «Validado»; faturação no PHC.
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
            "integrado" => ("validado", "Validado", false),
            "em_separacao" => ("validado", "Validado", false),
            "pronto_levantamento" => ("validado", "Validado", false),
            "concluido" => ("validado", "Validado", false),
            _ => ("recebido", "Recebido", false)
        };
    }
}
