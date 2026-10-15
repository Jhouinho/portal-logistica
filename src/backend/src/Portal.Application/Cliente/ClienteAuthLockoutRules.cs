namespace Portal.Application.Cliente;

/// <summary>
/// Interpretação do resultado de um UPDATE atómico de falhas (telefone / login).
/// </summary>
public static class ClienteAuthLockoutRules
{
    /// <summary>
    /// Após OUTPUT do UPDATE: se PhoneLockoutEnd/LoginLockoutEnd ficou no futuro → bloqueado.
    /// </summary>
    public static string FailureErrorCode(DateTime? lockoutEndUtc, DateTime utcNow, string invalidCode, string lockedCode = "bloqueado")
    {
        if (lockoutEndUtc is { } until && until > utcNow)
            return lockedCode;
        return invalidCode;
    }

    /// <summary>
    /// True quando o contador atinge o máximo (o UPDATE SQL zera o contador e define lockout).
    /// </summary>
    public static bool ShouldLockAfterFailure(int previousFailures, int maxFailures) =>
        previousFailures + 1 >= maxFailures;
}
