namespace Portal.Application.Cliente;

public static class ClienteElegibilidadeRules
{
    public static string NormalizeNif(string? nif)
    {
        if (string.IsNullOrWhiteSpace(nif))
            return string.Empty;
        return nif.Trim();
    }

    public static bool IsConsumidorFinal(string nif) =>
        string.Equals(NormalizeNif(nif), ClienteAuthConstants.ConsumidorFinalNif, StringComparison.Ordinal);

    /// <summary>
    /// fichas: já filtradas a activas (inactivo=0) e NIF correspondente.
    /// </summary>
    public static ClienteElegibilidade Classify(string nif, IReadOnlyList<ClienteFicha> fichasActivas)
    {
        if (IsConsumidorFinal(nif))
            return ClienteElegibilidade.ConsumidorFinal;

        if (fichasActivas.Count == 0)
            return ClienteElegibilidade.SemFicha;

        if (fichasActivas.Count > 1)
            return ClienteElegibilidade.VariasFichas;

        return ClienteElegibilidade.Ok;
    }
}
