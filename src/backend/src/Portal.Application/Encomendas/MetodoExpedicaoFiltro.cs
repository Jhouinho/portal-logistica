namespace Portal.Application.Encomendas;

/// <summary>
/// Match do filtro UI «Modo de Expedição» contra BO3.u_modExp (valor PHC tal qual).
/// </summary>
public static class MetodoExpedicaoFiltro
{
    public const string NaoDefinido = "nao_definido";

    /// <summary>
    /// <paramref name="filtro"/> vazio / null / «Todos» → sem filtro.
    /// <c>nao_definido</c> → método vazio após trim.
    /// Caso contrário → igualdade exacta com o valor PHC (após trim).
    /// </summary>
    public static bool Coincide(string? metodoExpedicao, string? filtro)
    {
        if (string.IsNullOrWhiteSpace(filtro) ||
            filtro.Equals("Todos", StringComparison.OrdinalIgnoreCase) ||
            filtro.Equals("todos", StringComparison.OrdinalIgnoreCase))
            return true;

        var v = (metodoExpedicao ?? string.Empty).Trim();
        if (filtro.Equals(NaoDefinido, StringComparison.OrdinalIgnoreCase))
            return v.Length == 0;

        return v.Equals(filtro.Trim(), StringComparison.Ordinal);
    }
}
