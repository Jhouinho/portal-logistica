namespace Portal.Application.Auth;

public sealed record LoginRequest(string Login, string Password);

public sealed record DefinirPasswordRequest(
    string Email,
    string Token,
    string Password,
    string ConfirmPassword);

public sealed record UtilizadorDto(string Login, string Nome, bool IsAdmin);

public sealed record LoginResponse(UtilizadorDto Utilizador);

public sealed record MeResponse(string Login, string Nome, bool IsAdmin);

public sealed record AdminUtilizadorDto(
    string Userstamp,
    string Login,
    string Nome,
    string Usrinis,
    string Email,
    bool UsaPort,
    bool TemContaIdentity,
    bool TemPassword,
    bool IsAdmin);

public sealed record EmailBodyRequest(string Email);

public sealed record ActivarAcessoResponse(
    string Email,
    string Login,
    string DefinirPasswordUrl,
    string Token);
