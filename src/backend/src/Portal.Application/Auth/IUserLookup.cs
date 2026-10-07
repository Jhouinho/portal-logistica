namespace Portal.Application.Auth;

public interface IUserLookup
{
    /// <summary>Lookup PHC por US.usercode (activo + u_usaPort).</summary>
    Task<Domain.Auth.PortalUser?> FindByLoginAsync(string login, CancellationToken cancellationToken = default);

    /// <summary>Lookup PHC por US.email (activo + u_usaPort).</summary>
    Task<Domain.Auth.PortalUser?> FindByEmailAsync(string email, CancellationToken cancellationToken = default);
}
