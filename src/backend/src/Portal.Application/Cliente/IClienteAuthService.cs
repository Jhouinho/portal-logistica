namespace Portal.Application.Cliente;

public interface IClienteAuthService
{
    Task<(ClienteElegibilidade Status, ClienteFicha? Ficha)> ResolverPorNifAsync(
        string nif,
        CancellationToken cancellationToken);

    Task<ClienteFicha?> GetFichaAsync(decimal no, decimal estab, CancellationToken cancellationToken);

    Task EnsureAuthRowAsync(decimal no, decimal estab, CancellationToken cancellationToken);

    Task<ClienteAuthRow?> GetAuthAsync(decimal no, decimal estab, CancellationToken cancellationToken);

    Task<(bool Ok, string? ErrorCode)> ValidarTelemovelAsync(
        decimal no,
        decimal estab,
        string telemovel,
        string? tlmvl,
        string? telefone,
        CancellationToken cancellationToken);

    Task DefinirPasswordAsync(decimal no, decimal estab, string password, CancellationToken cancellationToken);

    Task<(bool Ok, string? ErrorCode, ClienteFicha? Ficha)> ValidarLoginAsync(
        string nif,
        string password,
        CancellationToken cancellationToken);

    string CreateChallengeToken(decimal no, decimal estab, string purpose, TimeSpan lifetime);

    bool TryReadChallengeToken(string token, string expectedPurpose, out decimal no, out decimal estab);
}
