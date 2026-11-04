namespace Portal.Application.Cliente;

/// <summary>
/// Merge + ordenação da homepage do cliente (internos + legado).
/// Critério: DataObra DESC, PedidoId DESC, Obrano DESC; respeita <paramref name="top"/>.
/// </summary>
public static class ClientePedidoListaOrdenacao
{
    public const int TopMin = 1;
    public const int TopMax = 50;

    public static int ClampTop(int top) => Math.Clamp(top, TopMin, TopMax);

    public static IReadOnlyList<ClientePedidoListaItem> MergeTop(
        IEnumerable<ClientePedidoListaItem> internos,
        IEnumerable<ClientePedidoListaItem> legado,
        int top)
    {
        top = ClampTop(top);
        var internosList = internos as IList<ClientePedidoListaItem> ?? internos.ToList();
        var linkedBostamps = new HashSet<string>(StringComparer.OrdinalIgnoreCase);
        foreach (var i in internosList)
        {
            var b = i.Bostamp?.Trim();
            if (!string.IsNullOrEmpty(b))
                linkedBostamps.Add(b);
        }

        // Após aprovação, o mesmo dossier não deve aparecer também como legado.
        var legadoFiltrado = legado.Where(l =>
        {
            var b = l.Bostamp?.Trim();
            return string.IsNullOrEmpty(b) || !linkedBostamps.Contains(b);
        });

        return internosList
            .Concat(legadoFiltrado)
            .OrderByDescending(x => x.DataObra)
            .ThenByDescending(x => x.PedidoId ?? 0)
            .ThenByDescending(x => x.Obrano ?? 0)
            .Take(top)
            .ToList();
    }
}
