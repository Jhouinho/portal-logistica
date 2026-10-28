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

    public const int MaxLinhasOperador = 200;
    public const decimal QttMaxima = 999_999m;

    /// <summary>
    /// Valida o conjunto completo de linhas do operador (qtt/preço/ref) antes de substituir.
    /// </summary>
    public static string? ValidateLinhasOperador(IReadOnlyList<StaffPmLinhaEditRequest> linhas)
    {
        if (linhas is null || linhas.Count == 0)
            return "É obrigatória pelo menos uma linha.";

        if (linhas.Count > MaxLinhasOperador)
            return $"O pedido não pode ter mais de {MaxLinhasOperador} linhas.";

        for (var i = 0; i < linhas.Count; i++)
        {
            var l = linhas[i];
            var refTrim = (l.Ref ?? "").Trim();
            if (refTrim.Length == 0)
                return $"Linha {i + 1}: referência obrigatória.";
            if (refTrim.Length > 18)
                return $"Linha {i + 1}: referência demasiado longa.";

            if (l.Qtt != Math.Floor(l.Qtt) || l.Qtt <= 0)
                return $"Linha {i + 1}: a quantidade deve ser um inteiro positivo.";
            if (l.Qtt > QttMaxima)
                return $"Linha {i + 1}: quantidade demasiado elevada.";

            if (l.PrecoUnitario < 0)
                return $"Linha {i + 1}: preço negativo.";
            if (l.PrecoUnitario > PrecoMaximo)
                return $"Linha {i + 1}: preço demasiado elevado.";
        }

        return null;
    }

    /// <summary>
    /// Constrói linhas persistidas a partir do pedido do operador, preservando PrecoSubmissao
    /// quando a linha original (LinhaOrd) ainda existe.
    /// </summary>
    public static IReadOnlyList<ClientePmLinhaPersistida> BuildLinhasSubstituicao(
        IReadOnlyList<ClientePmLinhaPersistida> existentes,
        IReadOnlyList<StaffPmLinhaEditRequest> pedidos)
    {
        var byOrd = existentes.ToDictionary(l => l.LinhaOrd);
        var result = new List<ClientePmLinhaPersistida>(pedidos.Count);
        var ord = 1;
        foreach (var p in pedidos)
        {
            var preco = RoundPreco(p.PrecoUnitario);
            var qtt = p.Qtt;
            var total = CalcTotalLinha(qtt, preco);
            decimal? precoSub = null;
            if (p.LinhaOrd is int origem && byOrd.TryGetValue(origem, out var old))
                precoSub = old.PrecoSubmissao ?? old.PrecoUnitario;
            else
                precoSub = preco;

            result.Add(new ClientePmLinhaPersistida(
                ord,
                (p.Ref ?? "").Trim(),
                (p.Design ?? "").Trim(),
                (p.Cor ?? "").Trim(),
                qtt,
                preco,
                total,
                precoSub));
            ord++;
        }

        return result;
    }
}
