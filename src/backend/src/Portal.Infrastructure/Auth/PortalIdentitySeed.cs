using Microsoft.AspNetCore.Identity;
using Microsoft.Extensions.DependencyInjection;
using Microsoft.Extensions.Hosting;
using Microsoft.Extensions.Logging;
using Portal.Application.Auth;
using Portal.Infrastructure.Identity;

namespace Portal.Infrastructure.Auth;

public static class PortalIdentitySeed
{
    /// <summary>
    /// Garante role Admin e atribui-a ao Identity ligado ao US.usercode = sa (piloto).
    /// Equivalente SQL versionado: sql/033_seed_role_Admin.sql
    /// </summary>
    public static async Task EnsureAdminAsync(IServiceProvider services, CancellationToken cancellationToken = default)
    {
        using var scope = services.CreateScope();
        var sp = scope.ServiceProvider;
        var logger = sp.GetRequiredService<ILoggerFactory>().CreateLogger("PortalIdentitySeed");
        var roles = sp.GetRequiredService<RoleManager<IdentityRole>>();
        var users = sp.GetRequiredService<UserManager<PortalUserIdentity>>();
        var phc = sp.GetRequiredService<IPhcAdminUsers>();

        if (!await roles.RoleExistsAsync(PortalRoles.Admin))
        {
            var created = await roles.CreateAsync(new IdentityRole(PortalRoles.Admin));
            if (!created.Succeeded)
            {
                logger.LogError(
                    "Falha ao criar role Admin: {Errors}",
                    string.Join("; ", created.Errors.Select(e => e.Description)));
                return;
            }

            logger.LogInformation("Role Admin criada.");
        }

        var activos = await phc.ListarActivosAsync(cancellationToken);
        var sa = activos.FirstOrDefault(u =>
            string.Equals(u.Login, "sa", StringComparison.OrdinalIgnoreCase) && u.UsaPort);

        if (sa is null)
        {
            logger.LogDebug("Seed Admin: utilizador PHC sa com u_usaPort não encontrado.");
            return;
        }

        var identity = await users.FindByEmailAsync(sa.Email);
        if (identity is null)
        {
            logger.LogDebug("Seed Admin: Identity para {Email} ainda não existe.", sa.Email);
            return;
        }

        if (await users.IsInRoleAsync(identity, PortalRoles.Admin))
            return;

        var add = await users.AddToRoleAsync(identity, PortalRoles.Admin);
        if (add.Succeeded)
            logger.LogInformation("Role Admin atribuída a {Email} (usercode sa).", sa.Email);
        else
            logger.LogWarning(
                "Não foi possível atribuir Admin a {Email}: {Errors}",
                sa.Email,
                string.Join("; ", add.Errors.Select(e => e.Description)));
    }
}
