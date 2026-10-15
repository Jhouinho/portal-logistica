using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using Portal.Api.Cliente;
using Portal.Application.Cliente;

namespace Portal.Api.Controllers;

[ApiController]
[Route("api/v1/cliente/auth")]
public sealed class ClienteAuthController : ControllerBase
{
    private const string MsgBalcao =
        "Não encontramos os seus dados nos nossos registos. Dirija-se por favor ao balcão para atualização dos dados de cliente.";

    private readonly IClienteAuthService _auth;

    public ClienteAuthController(IClienteAuthService auth) => _auth = auth;

    public sealed record NifRequest(string Nif);
    public sealed record TelemovelRequest(string ChallengeToken, string Telemovel);
    public sealed record PasswordRequest(string PasswordToken, string Password);
    public sealed record LoginRequest(string Nif, string Password);

    [HttpPost("primeiro-acesso/iniciar")]
    [AllowAnonymous]
    public async Task<IActionResult> PrimeiroAcessoIniciar([FromBody] NifRequest body, CancellationToken ct)
    {
        var (status, ficha) = await _auth.ResolverPorNifAsync(body.Nif ?? "", ct);
        return ElegibilidadeResponse(status, ficha, "primeiro-acesso");
    }

    [HttpPost("primeiro-acesso/validar-telemovel")]
    [AllowAnonymous]
    public async Task<IActionResult> PrimeiroAcessoValidarTelemovel(
        [FromBody] TelemovelRequest body,
        CancellationToken ct)
    {
        if (!_auth.TryReadChallengeToken(body.ChallengeToken ?? "", "primeiro-acesso", out var no, out var estab))
            return BadRequest(Err("Token inválido ou expirado."));

        var ficha = await _auth.GetFichaAsync(no, estab, ct);
        if (ficha is null)
            return BadRequest(Err("Sessão de activação inválida."));

        var (ok, code) = await _auth.ValidarTelemovelAsync(
            no, estab, body.Telemovel ?? "", ficha.Tlmvl, ficha.Telefone, ct);
        if (!ok)
            return StatusCode(StatusCodes.Status401Unauthorized, Err(MsgTelemovel(code), 401));

        var passwordToken = _auth.CreateChallengeToken(no, estab, "definir-password", TimeSpan.FromMinutes(15));
        return Ok(new { passwordToken });
    }

    [HttpPost("primeiro-acesso/definir-password")]
    [AllowAnonymous]
    public async Task<IActionResult> PrimeiroAcessoDefinirPassword(
        [FromBody] PasswordRequest body,
        CancellationToken ct)
    {
        if (!_auth.TryReadChallengeToken(body.PasswordToken ?? "", "definir-password", out var no, out var estab))
            return BadRequest(Err("Token inválido ou expirado."));

        if (string.IsNullOrWhiteSpace(body.Password) || body.Password.Length < 8)
            return BadRequest(Err("A palavra-passe deve ter pelo menos 8 caracteres."));

        var ficha = await _auth.GetFichaAsync(no, estab, ct);
        if (ficha is null)
            return BadRequest(Err("Sessão de activação inválida."));

        await _auth.DefinirPasswordAsync(no, estab, body.Password, ct);
        await ClienteSession.SignInAsync(HttpContext, ficha);
        return Ok(new { utilizador = MeDto(ficha) });
    }

    [HttpPost("login")]
    [AllowAnonymous]
    public async Task<IActionResult> Login([FromBody] LoginRequest body, CancellationToken ct)
    {
        var (ok, code, ficha) = await _auth.ValidarLoginAsync(body.Nif ?? "", body.Password ?? "", ct);
        if (!ok || ficha is null)
        {
            var detail = code switch
            {
                "bloqueado" => "Conta temporariamente bloqueada. Tente mais tarde.",
                "consumidor_final" or "balcao" => MsgBalcao,
                _ => "Credenciais inválidas."
            };
            return Unauthorized(Err(detail, 401));
        }

        await ClienteSession.SignInAsync(HttpContext, ficha);
        return Ok(new { utilizador = MeDto(ficha) });
    }

    [HttpPost("recuperar/iniciar")]
    [AllowAnonymous]
    public async Task<IActionResult> RecuperarIniciar([FromBody] NifRequest body, CancellationToken ct)
    {
        var (status, ficha) = await _auth.ResolverPorNifAsync(body.Nif ?? "", ct);
        return ElegibilidadeResponse(status, ficha, "recuperar");
    }

    [HttpPost("recuperar/validar-telemovel")]
    [AllowAnonymous]
    public async Task<IActionResult> RecuperarValidarTelemovel(
        [FromBody] TelemovelRequest body,
        CancellationToken ct)
    {
        if (!_auth.TryReadChallengeToken(body.ChallengeToken ?? "", "recuperar", out var no, out var estab))
            return BadRequest(Err("Token inválido ou expirado."));

        var ficha = await _auth.GetFichaAsync(no, estab, ct);
        if (ficha is null)
            return BadRequest(Err("Sessão de recuperação inválida."));

        var (ok, code) = await _auth.ValidarTelemovelAsync(
            no, estab, body.Telemovel ?? "", ficha.Tlmvl, ficha.Telefone, ct);
        if (!ok)
            return StatusCode(StatusCodes.Status401Unauthorized, Err(MsgTelemovel(code), 401));

        var passwordToken = _auth.CreateChallengeToken(no, estab, "recuperar-password", TimeSpan.FromMinutes(15));
        return Ok(new { passwordToken });
    }

    [HttpPost("recuperar/definir-password")]
    [AllowAnonymous]
    public async Task<IActionResult> RecuperarDefinirPassword(
        [FromBody] PasswordRequest body,
        CancellationToken ct)
    {
        if (!_auth.TryReadChallengeToken(body.PasswordToken ?? "", "recuperar-password", out var no, out var estab))
            return BadRequest(Err("Token inválido ou expirado."));

        if (string.IsNullOrWhiteSpace(body.Password) || body.Password.Length < 8)
            return BadRequest(Err("A palavra-passe deve ter pelo menos 8 caracteres."));

        var ficha = await _auth.GetFichaAsync(no, estab, ct);
        if (ficha is null)
            return BadRequest(Err("Sessão de recuperação inválida."));

        await _auth.DefinirPasswordAsync(no, estab, body.Password, ct);
        await ClienteSession.SignInAsync(HttpContext, ficha);
        return Ok(new { utilizador = MeDto(ficha) });
    }

    [HttpPost("logout")]
    [Authorize(AuthenticationSchemes = ClienteAuthConstants.CookieScheme, Policy = ClienteAuthConstants.PolicyName)]
    public async Task<IActionResult> Logout()
    {
        await ClienteSession.SignOutAsync(HttpContext);
        return NoContent();
    }

    [HttpGet("me")]
    [Authorize(AuthenticationSchemes = ClienteAuthConstants.CookieScheme, Policy = ClienteAuthConstants.PolicyName)]
    public IActionResult Me()
    {
        if (!ClienteSession.TryGetCliente(User, out var no, out var estab))
            return Unauthorized();

        return Ok(new
        {
            no,
            estab,
            nome = User.FindFirst(ClienteAuthConstants.ClaimNome)?.Value ?? "",
            ncont = User.FindFirst(ClienteAuthConstants.ClaimNcont)?.Value ?? ""
        });
    }

    private IActionResult ElegibilidadeResponse(
        ClienteElegibilidade status,
        ClienteFicha? ficha,
        string purpose)
    {
        if (status is ClienteElegibilidade.ConsumidorFinal
            or ClienteElegibilidade.SemFicha
            or ClienteElegibilidade.VariasFichas
            || ficha is null)
        {
            return BadRequest(Err(MsgBalcao));
        }

        var challengeToken = _auth.CreateChallengeToken(
            ficha.No, ficha.Estab, purpose, TimeSpan.FromMinutes(15));
        return Ok(new { challengeToken, nome = ficha.Nome });
    }

    private static object MeDto(ClienteFicha f) => new
    {
        no = f.No,
        estab = f.Estab,
        nome = f.Nome,
        ncont = f.Ncont
    };

    private static string MsgTelemovel(string? code) => code switch
    {
        "bloqueado" => "Demasiadas tentativas. Tente novamente dentro de 15 minutos.",
        _ => MsgBalcao
    };

    private static ProblemDetails Err(string detail, int status = StatusCodes.Status400BadRequest) => new()
    {
        Title = status >= 500 ? "Erro" : "Pedido inválido",
        Detail = detail,
        Status = status
    };
}
