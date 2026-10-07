namespace Portal.Application.Auth;

public sealed class PhcAdminUserRow
{
    public string Userstamp { get; init; } = string.Empty;
    public string Login { get; init; } = string.Empty;
    public string Nome { get; init; } = string.Empty;
    public string Usrinis { get; init; } = string.Empty;
    public string Email { get; init; } = string.Empty;
    public bool UsaPort { get; init; }
}

public interface IPhcAdminUsers
{
    Task<IReadOnlyList<PhcAdminUserRow>> ListarActivosAsync(CancellationToken cancellationToken = default);

    Task<PhcAdminUserRow?> ActualizarUsaPortAsync(
        string email,
        bool usaPort,
        CancellationToken cancellationToken = default);

    Task<PhcAdminUserRow?> FindByEmailAsync(string email, CancellationToken cancellationToken = default);
}
