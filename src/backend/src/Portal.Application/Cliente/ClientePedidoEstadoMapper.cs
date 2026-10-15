namespace Portal.Application.Cliente;

/// <summary>
/// Mapeamento de estado do pedido Mobile com a informação PHC actualmente confirmada.
/// Estados «em preparação» / «processado» exigem campos de associação Cópia de Dossier (B06–B08) — ainda não inventados.
/// </summary>
public static class ClientePedidoEstadoMapper
{
    public static (string Codigo, string Etiqueta, bool PodeCancelar) Map(bool cancelado)
    {
        if (cancelado)
            return ("cancelado", "Cancelado", false);
        return ("submetido", "Pedido submetido", true);
    }
}
