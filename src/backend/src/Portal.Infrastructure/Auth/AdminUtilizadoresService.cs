using Microsoft.AspNetCore.Identity;
using Microsoft.AspNetCore.WebUtilities;
using Microsoft.Extensions.Options;
using Portal.Application.Auth;
using Portal.Infrastructure.Identity;
using Portal.Infrastructure.Options;
using System.Text;

namespace Portal.Infrastructure.Auth;

public sealed class AdminUtilizadoresService
{
    private readonly IPhcAdminUsers _phc;
    private readonly UserManager<PortalUserIdentity> _users;
    private readonly RoleManager<IdentityRole> _roles;
    private readonly PortalAppOptions _portal;

    public AdminUtilizadoresService(
        IPhcAdminUsers phc,
        UserManager<PortalUserIdentity> users,
        RoleManager<IdentityRole> roles,
        IOptions<PortalAppOptions> portal)
    {
        _phc = phc;
        _users = users;
        _roles = roles;
        _portal = portal.Value;
    }

    public async Task<IReadOnlyList<AdminUtilizadorDto>> ListarAsync(CancellationToken cancellationToken)
    {
        var phcUsers = await _phc.ListarActivosAsync(cancellationToken);
        var result = new List<AdminUtilizadorDto>(phcUsers.Count);

        foreach (var u in phcUsers)
        {
            var identity = await _users.FindByEmailAsync(u.Email);
            var temConta = identity is not null;
            var temPassword = identity?.PasswordHash is { Length: > 0 };
            var isAdmin = identity is not null && await _users.IsInRoleAsync(identity, PortalRoles.Admin);

            result.Add(new AdminUtilizadorDto(
                u.Userstamp,
                u.Login,
                u.Nome,
                u.Usrinis,
                u.Email,
                u.UsaPort,
                temConta,
                temPassword,
                isAdmin));
        }

        return result;
    }

    public async Task<(ActivarAcessoResponse? Ok, string? Error)> ActivarAcessoAsync(
        string email,
        CancellationToken cancellationToken)
    {
        email = email.Trim();
        var phc = await _phc.ActualizarUsaPortAsync(email, true, cancellationToken);
        if (phc is null)
            return (null, "Utilizador US activo com esse email não encontrado.");

        var identity = await EnsureIdentityUserAsync(phc);
        if (identity is null)
            return (null, "Não foi possível criar a conta Identity.");

        var (url, token) = await BuildInviteAsync(identity, phc.Email);
        return (new ActivarAcessoResponse(phc.Email, phc.Login, url, token), null);
    }

    public async Task<(bool Ok, string? Error)> RevogarAcessoAsync(
        string email,
        CancellationToken cancellationToken)
    {
        email = email.Trim();
        var phc = await _phc.ActualizarUsaPortAsync(email, false, cancellationToken);
        if (phc is null)
            return (false, "Utilizador US activo com esse email não encontrado.");

        var identity = await _users.FindByEmailAsync(email);
        if (identity is not null)
        {
            await _users.SetLockoutEnabledAsync(identity, true);
            await _users.SetLockoutEndDateAsync(identity, DateTimeOffset.UtcNow.AddYears(100));
        }

        return (true, null);
    }

    public async Task<(ActivarAcessoResponse? Ok, string? Error)> ReenviarConviteAsync(
        string email,
        CancellationToken cancellationToken)
        => await ResetPasswordAsync(email, cancellationToken);

    /// <summary>
    /// Remove a password actual (se existir) e devolve link para o utilizador definir uma nova
    /// em /definir-password. Até lá o login com a password antiga falha.
    /// </summary>
    public async Task<(ActivarAcessoResponse? Ok, string? Error)> ResetPasswordAsync(
        string email,
        CancellationToken cancellationToken)
    {
        email = email.Trim();
        var phc = await _phc.FindByEmailAsync(email, cancellationToken);
        if (phc is null)
            return (null, "Utilizador US activo com esse email não encontrado.");
        if (!phc.UsaPort)
            return (null, "O utilizador não tem acesso ao portal (u_usaPort=0). Active o acesso primeiro.");

        var identity = await EnsureIdentityUserAsync(phc);
        if (identity is null)
            return (null, "Não foi possível criar a conta Identity.");

        if (await _users.HasPasswordAsync(identity))
        {
            var removed = await _users.RemovePasswordAsync(identity);
            if (!removed.Succeeded)
                return (null, string.Join("; ", removed.Errors.Select(e => e.Description)));
        }

        if (identity.LockoutEnd is not null && identity.LockoutEnd > DateTimeOffset.UtcNow)
            await _users.SetLockoutEndDateAsync(identity, null);

        var (url, token) = await BuildInviteAsync(identity, phc.Email);
        return (new ActivarAcessoResponse(phc.Email, phc.Login, url, token), null);
    }

    public async Task<(bool Ok, string? Error)> AtribuirAdminAsync(string email)
    {
        email = email.Trim();
        await EnsureAdminRoleAsync();
        var identity = await _users.FindByEmailAsync(email);
        if (identity is null)
            return (false, "Conta Identity inexistente. Active o acesso ao portal primeiro.");

        if (await _users.IsInRoleAsync(identity, PortalRoles.Admin))
            return (true, null);

        var result = await _users.AddToRoleAsync(identity, PortalRoles.Admin);
        if (!result.Succeeded)
            return (false, string.Join("; ", result.Errors.Select(e => e.Description)));

        return (true, null);
    }

    public async Task<(bool Ok, string? Error)> RemoverAdminAsync(string email)
    {
        email = email.Trim();
        var identity = await _users.FindByEmailAsync(email);
        if (identity is null)
            return (false, "Conta Identity inexistente.");

        if (!await _users.IsInRoleAsync(identity, PortalRoles.Admin))
            return (true, null);

        var admins = await _users.GetUsersInRoleAsync(PortalRoles.Admin);
        if (admins.Count <= 1)
            return (false, "Não é possível remover o último administrador.");

        var result = await _users.RemoveFromRoleAsync(identity, PortalRoles.Admin);
        if (!result.Succeeded)
            return (false, string.Join("; ", result.Errors.Select(e => e.Description)));

        return (true, null);
    }

    private async Task EnsureAdminRoleAsync()
    {
        if (!await _roles.RoleExistsAsync(PortalRoles.Admin))
            await _roles.CreateAsync(new IdentityRole(PortalRoles.Admin));
    }

    private async Task<PortalUserIdentity?> EnsureIdentityUserAsync(PhcAdminUserRow phc)
    {
        var existing = await _users.FindByEmailAsync(phc.Email);
        if (existing is not null)
        {
            existing.UsStamp = phc.Userstamp;
            existing.Usercode = phc.Login;
            if (existing.LockoutEnd is not null && existing.LockoutEnd > DateTimeOffset.UtcNow)
            {
                await _users.SetLockoutEndDateAsync(existing, null);
            }

            await _users.UpdateAsync(existing);
            return existing;
        }

        var user = new PortalUserIdentity
        {
            UserName = phc.Email,
            Email = phc.Email,
            EmailConfirmed = true,
            UsStamp = phc.Userstamp,
            Usercode = phc.Login
        };

        var create = await _users.CreateAsync(user);
        return create.Succeeded ? user : null;
    }

    private async Task<(string Url, string Token)> BuildInviteAsync(PortalUserIdentity user, string email)
    {
        var rawToken = await _users.GeneratePasswordResetTokenAsync(user);
        var token = WebEncoders.Base64UrlEncode(Encoding.UTF8.GetBytes(rawToken));
        var baseUrl = (_portal.SpaBaseUrl ?? "http://localhost:5173").TrimEnd('/');
        var url =
            $"{baseUrl}/definir-password?email={Uri.EscapeDataString(email)}&token={Uri.EscapeDataString(token)}";
        return (url, token);
    }
}
