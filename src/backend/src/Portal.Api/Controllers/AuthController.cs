using System.Security.Claims;
using System.Text;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Identity;
using Microsoft.AspNetCore.Mvc;
using Microsoft.AspNetCore.WebUtilities;
using Portal.Application.Auth;
using Portal.Infrastructure.Identity;

namespace Portal.Api.Controllers;

[ApiController]
[Route("api/v1/auth")]
public sealed class AuthController : ControllerBase
{
    private readonly UserManager<PortalUserIdentity> _users;
    private readonly SignInManager<PortalUserIdentity> _signIn;
    private readonly IUserLookup _phcUsers;
    private readonly ILogger<AuthController> _logger;

    public AuthController(
        UserManager<PortalUserIdentity> users,
        SignInManager<PortalUserIdentity> signIn,
        IUserLookup phcUsers,
        ILogger<AuthController> logger)
    {
        _users = users;
        _signIn = signIn;
        _phcUsers = phcUsers;
        _logger = logger;
    }

    [HttpPost("login")]
    [AllowAnonymous]
    public async Task<IActionResult> Login([FromBody] LoginRequest request, CancellationToken cancellationToken)
    {
        if (string.IsNullOrWhiteSpace(request.Login) || string.IsNullOrWhiteSpace(request.Password))
        {
            return BadRequest(new ProblemDetails
            {
                Title = "Dados inválidos",
                Detail = "Utilizador (usercode) e palavra-passe são obrigatórios.",
                Status = StatusCodes.Status400BadRequest
            });
        }

        var login = request.Login.Trim();
        var phc = await _phcUsers.FindByLoginAsync(login, cancellationToken);
        if (phc is null || string.IsNullOrWhiteSpace(phc.Email))
        {
            return Unauthorized(InvalidCredentials());
        }

        var identityUser = await _users.FindByEmailAsync(phc.Email);
        if (identityUser is null)
        {
            return Unauthorized(InvalidCredentials());
        }

        var check = await _signIn.CheckPasswordSignInAsync(identityUser, request.Password, lockoutOnFailure: true);
        if (!check.Succeeded)
        {
            if (check.IsLockedOut)
            {
                return Unauthorized(new ProblemDetails
                {
                    Title = "Não autenticado",
                    Detail = "Conta temporariamente bloqueada. Tente mais tarde.",
                    Status = StatusCodes.Status401Unauthorized
                });
            }

            return Unauthorized(InvalidCredentials());
        }

        identityUser.UsStamp = phc.UserStamp;
        identityUser.Usercode = phc.Login;
        await _users.UpdateAsync(identityUser);

        var isAdmin = await _users.IsInRoleAsync(identityUser, PortalRoles.Admin);
        // Claim "iniciais" = US.iniciais (não é o campo BI/BO.usrinis do dossier).
        var iniciais = (phc.Usrinis ?? string.Empty).Trim();
        if (iniciais.Length > 3)
            iniciais = iniciais[..3];

        var existingClaims = await _users.GetClaimsAsync(identityUser);
        foreach (var c in existingClaims.Where(c => c.Type is "iniciais" or "usrinis" or "nome" or "usercode"))
            await _users.RemoveClaimAsync(identityUser, c);
        if (!string.IsNullOrWhiteSpace(iniciais))
            await _users.AddClaimAsync(identityUser, new Claim("iniciais", iniciais));
        await _users.AddClaimAsync(identityUser, new Claim("nome", phc.Nome));
        await _users.AddClaimAsync(identityUser, new Claim("usercode", phc.Login));

        var claims = new List<Claim>
        {
            new(ClaimTypes.NameIdentifier, phc.UserStamp),
            new(ClaimTypes.Name, phc.Login),
            new("usercode", phc.Login),
            new("nome", phc.Nome)
        };
        if (!string.IsNullOrWhiteSpace(iniciais))
            claims.Add(new Claim("iniciais", iniciais));

        if (isAdmin)
            claims.Add(new Claim(ClaimTypes.Role, PortalRoles.Admin));

        await _signIn.SignInWithClaimsAsync(identityUser, isPersistent: true, claims);

        return Ok(new LoginResponse(new UtilizadorDto(phc.Login, phc.Nome, isAdmin)));
    }

    [HttpPost("definir-password")]
    [AllowAnonymous]
    public async Task<IActionResult> DefinirPassword([FromBody] DefinirPasswordRequest request)
    {
        if (string.IsNullOrWhiteSpace(request.Email)
            || string.IsNullOrWhiteSpace(request.Token)
            || string.IsNullOrWhiteSpace(request.Password))
        {
            return BadRequest(new ProblemDetails
            {
                Title = "Dados inválidos",
                Detail = "Email, token e palavra-passe são obrigatórios.",
                Status = StatusCodes.Status400BadRequest
            });
        }

        if (!string.Equals(request.Password, request.ConfirmPassword, StringComparison.Ordinal))
        {
            return BadRequest(new ProblemDetails
            {
                Title = "Dados inválidos",
                Detail = "A confirmação da palavra-passe não coincide.",
                Status = StatusCodes.Status400BadRequest
            });
        }

        var email = request.Email.Trim();
        var user = await _users.FindByEmailAsync(email);
        if (user is null)
        {
            return BadRequest(new ProblemDetails
            {
                Title = "Pedido inválido",
                Detail = "Token ou email inválidos.",
                Status = StatusCodes.Status400BadRequest
            });
        }

        string rawToken;
        try
        {
            rawToken = Encoding.UTF8.GetString(WebEncoders.Base64UrlDecode(request.Token.Trim()));
        }
        catch (FormatException)
        {
            rawToken = request.Token.Trim();
        }

        var result = await _users.ResetPasswordAsync(user, rawToken, request.Password);
        if (!result.Succeeded)
        {
            return BadRequest(new ProblemDetails
            {
                Title = "Pedido inválido",
                Detail = string.Join(" ", result.Errors.Select(e => e.Description)),
                Status = StatusCodes.Status400BadRequest
            });
        }

        if (user.LockoutEnd is not null && user.LockoutEnd > DateTimeOffset.UtcNow)
            await _users.SetLockoutEndDateAsync(user, null);

        return NoContent();
    }

    [HttpPost("logout")]
    [Authorize]
    public async Task<IActionResult> Logout()
    {
        await _signIn.SignOutAsync();
        return NoContent();
    }

    [HttpGet("me")]
    [Authorize]
    public IActionResult Me()
    {
        var login = User.Identity?.Name ?? string.Empty;
        var nome = User.FindFirstValue("nome") ?? login;
        var isAdmin = User.IsInRole(PortalRoles.Admin);
        return Ok(new MeResponse(login, nome, isAdmin));
    }

    private static ProblemDetails InvalidCredentials() => new()
    {
        Title = "Não autenticado",
        Detail = "Utilizador ou palavra-passe incorrectos.",
        Status = StatusCodes.Status401Unauthorized
    };
}
