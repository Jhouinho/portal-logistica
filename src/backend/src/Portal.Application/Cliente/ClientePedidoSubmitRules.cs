namespace Portal.Application.Cliente;

/// <summary>Regras de validação da submissão (Fase 1) — testáveis sem SQL.</summary>
public static class ClientePedidoSubmitRules
{
    /// <summary>Limite de <c>u_HcaPmPedido.SubmissaoIdempotencyKey</c> (varchar(64)).</summary>
    public const int IdempotencyKeyMaxLength = 64;

    public static bool IsIdempotencyKeyLengthValid(string? key) =>
        !string.IsNullOrWhiteSpace(key) && key.Trim().Length <= IdempotencyKeyMaxLength;

    /// <summary>Devolve mensagem de erro se <paramref name="linhas"/> for inválido; senão null.</summary>
    public static string? ValidateLinhasOrError(IReadOnlyList<ClientePedidoLinhaInput> linhas)
    {
        if (linhas is null || linhas.Count == 0)
            return "É obrigatória pelo menos uma linha.";

        var seen = new HashSet<int>();
        foreach (var l in linhas)
        {
            if (l.LinhaOrd <= 0)
                return "As ordens de linha devem ser números inteiros positivos.";
            if (!seen.Add(l.LinhaOrd))
                return "Existem linhas com a mesma ordem (LinhaOrd duplicado).";
            if (l.Qtt != Math.Floor(l.Qtt) || l.Qtt <= 0)
                return "As quantidades devem ser números inteiros positivos.";
        }

        return null;
    }
}

/// <summary>Classificação de erros SQL relevantes aos pedidos internos.</summary>
public static class ClientePmSqlErrorRules
{
    public const string IdempotencyUniqueConstraint = "UQ_u_HcaPmPedido_IdemKey";

    public static bool IsIdempotencyKeyUniqueViolation(int number, string? message)
    {
        if (number is not (2627 or 2601))
            return false;
        if (string.IsNullOrEmpty(message))
            return false;
        return message.Contains(IdempotencyUniqueConstraint, StringComparison.OrdinalIgnoreCase)
               || message.Contains("SubmissaoIdempotencyKey", StringComparison.OrdinalIgnoreCase);
    }

    /// <summary>Tabela/objecto inexistente (ex.: scripts 096 ainda não aplicados).</summary>
    public static bool IsMissingPmPedidoObject(int number, string? message)
    {
        if (number != 208)
            return false;
        if (string.IsNullOrEmpty(message))
            return true;
        return message.Contains("u_HcaPmPedido", StringComparison.OrdinalIgnoreCase);
    }
}

/// <summary>Resolução de conflito de idempotência sem expor dados de outros clientes.</summary>
public static class ClientePmIdempotencyResolve
{
    public enum OutcomeKind
    {
        SameClientSameHash,
        SameClientDifferentHash,
        OtherClientOrEstab,
        IncompleteOrMissing
    }

    public static OutcomeKind Classify(
        decimal callerClNo,
        decimal callerClEstab,
        decimal? existingClNo,
        decimal? existingClEstab,
        string? existingNumeroInterno,
        string? existingHash,
        string requestHash)
    {
        if (existingClNo is null || existingClEstab is null
            || string.IsNullOrWhiteSpace(existingNumeroInterno))
            return OutcomeKind.IncompleteOrMissing;

        if (existingClNo.Value != callerClNo || existingClEstab.Value != callerClEstab)
            return OutcomeKind.OtherClientOrEstab;

        if (!string.Equals(existingHash, requestHash, StringComparison.OrdinalIgnoreCase))
            return OutcomeKind.SameClientDifferentHash;

        return OutcomeKind.SameClientSameHash;
    }
}
