namespace Portal.Application.Cliente;

public static class ClienteAuthConstants
{
    public const string CookieScheme = "ClienteCookie";
    public const string CookieName = "ls_cliente_auth";
    public const string PolicyName = "ClienteAutenticado";
    public const string ClaimNo = "cl_no";
    public const string ClaimEstab = "cl_estab";
    public const string ClaimNcont = "cl_ncont";
    public const string ClaimNome = "cl_nome";
    public const string ConsumidorFinalNif = "999999990";
    public const int PhoneMaxFailures = 5;
    public const int PhoneLockoutMinutes = 15;
    public const int LoginMaxFailures = 5;
    public const int LoginLockoutMinutes = 15;
    public const int SessionMinutes = 30;
}

public enum ClienteElegibilidade
{
    Ok,
    ConsumidorFinal,
    SemFicha,
    VariasFichas,
}

public sealed record ClienteFicha(
    decimal No,
    decimal Estab,
    string Nome,
    string Ncont,
    string? Tlmvl,
    string? Telefone);

public sealed record ClienteAuthRow(
    decimal ClNo,
    decimal ClEstab,
    string? PasswordHash,
    int FailedPhoneAttempts,
    DateTime? PhoneLockoutEnd,
    int FailedLoginAttempts,
    DateTime? LoginLockoutEnd,
    DateTime? PasswordSetAt);

public sealed class ClientePasswordUser;
