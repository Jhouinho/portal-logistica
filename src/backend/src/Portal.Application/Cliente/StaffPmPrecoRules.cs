namespace Portal.Application.Cliente;

/// <summary>Validação e regras de preços do operador (Pedidos Mobile staff).</summary>
public static class StaffPmPrecoRules
{
    public const decimal PrecoMaximo = 999_999.999999m;

    public static bool CanEditPrecos(string? estadoInterno, string? bostamp) =>
        StaffPmPedidoRules.IsPendente(estadoInterno, bostamp);

    public static decimal RoundPreco(decimal preco) =>
        Math.Round(preco, 6, MidpointRounding.AwayFromZero);

    public static decimal CalcTotalLinha(decimal qtt, decimal precoUnitario) =>
        Math.Round(qtt * RoundPreco(precoUnitario), 6, MidpointRounding.AwayFromZero);

    /// <summary>
    /// Valida o conjunto de preços do operador contra as linhas persistidas.
    /// Devolve mensagem de erro ou null se OK.
    /// </summary>
    public static string? ValidatePrecosOperador(
        IReadOnlyList<ClientePmLinhaPersistida> linhasExistentes,
        IReadOnlyList<(int LinhaOrd, decimal PrecoUnitario)> pedidos)
    {
        if (linhasExistentes.Count == 0)
            return "Pedido sem linhas.";

        if (pedidos.Count == 0)
            return "É obrigatório indicar pelo menos um preço.";

        if (pedidos.Count != linhasExistentes.Count)
            return "O conjunto de linhas de preço não corresponde ao pedido.";

        var byOrd = new Dictionary<int, decimal>();
        foreach (var (ord, preco) in pedidos)
        {
            if (ord <= 0)
                return "LinhaOrd inválido.";
            if (!byOrd.TryAdd(ord, preco))
                return $"LinhaOrd {ord} duplicado.";
        }

        foreach (var l in linhasExistentes)
        {
            if (!byOrd.TryGetValue(l.LinhaOrd, out var preco))
                return $"Falta preço para a linha {l.LinhaOrd}.";

            if (preco < 0)
                return $"Preço negativo na linha {l.LinhaOrd}.";

            if (preco > PrecoMaximo)
                return $"Preço demasiado elevado na linha {l.LinhaOrd}.";
        }

        return null;
    }

    public static string? ValidatePrecosParaAprovacao(IReadOnlyList<ClientePmLinhaPersistida> linhas)
    {
        if (linhas.Count == 0)
            return "Pedido sem linhas — não é possível criar o dossier PHC.";

        foreach (var l in linhas)
        {
            if (l.PrecoUnitario < 0)
                return $"Preço inválido na linha {l.LinhaOrd}.";
            if (l.PrecoUnitario > PrecoMaximo)
                return $"Preço demasiado elevado na linha {l.LinhaOrd}.";
        }

        return null;
    }
}
