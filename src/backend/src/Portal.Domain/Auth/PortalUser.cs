namespace Portal.Domain.Auth;

public sealed class PortalUser
{
    public required string UserStamp { get; init; }
    public required string Login { get; init; }
    public required string Nome { get; init; }
    public required string Usrinis { get; init; }
    /// <summary>US.email — usado para localizar a conta Identity.</summary>
    public string Email { get; init; } = string.Empty;
    /// <summary>Legado (u_portalph); password do portal está no Identity.</summary>
    public string PortalHash { get; init; } = string.Empty;
}
