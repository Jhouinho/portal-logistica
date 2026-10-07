using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using Portal.Application.Auth;
using Portal.Infrastructure.Auth;

namespace Portal.Api.Controllers;

[ApiController]
[Authorize(Roles = PortalRoles.Admin)]
[Route("api/v1/admin/utilizadores")]
public sealed class AdminUtilizadoresController : ControllerBase
{
    private readonly AdminUtilizadoresService _service;

    public AdminUtilizadoresController(AdminUtilizadoresService service)
    {
        _service = service;
    }

    [HttpGet]
    public async Task<ActionResult<IReadOnlyList<AdminUtilizadorDto>>> Listar(
        CancellationToken cancellationToken)
    {
        var items = await _service.ListarAsync(cancellationToken);
        return Ok(items);
    }

    [HttpPost("acesso")]
    public async Task<IActionResult> ActivarAcesso(
        [FromBody] EmailBodyRequest request,
        CancellationToken cancellationToken)
    {
        if (string.IsNullOrWhiteSpace(request.Email))
            return BadRequest(Problem("Email obrigatório."));

        var (ok, error) = await _service.ActivarAcessoAsync(request.Email, cancellationToken);
        if (ok is null)
            return BadRequest(Problem(error ?? "Falha ao activar acesso."));

        return Ok(ok);
    }

    [HttpPost("revogar")]
    public async Task<IActionResult> Revogar(
        [FromBody] EmailBodyRequest request,
        CancellationToken cancellationToken)
    {
        if (string.IsNullOrWhiteSpace(request.Email))
            return BadRequest(Problem("Email obrigatório."));

        var (ok, error) = await _service.RevogarAcessoAsync(request.Email, cancellationToken);
        if (!ok)
            return BadRequest(Problem(error ?? "Falha ao revogar acesso."));

        return NoContent();
    }

    [HttpPost("reenviar-convite")]
    public async Task<IActionResult> ReenviarConvite(
        [FromBody] EmailBodyRequest request,
        CancellationToken cancellationToken)
        => await ResetPassword(request, cancellationToken);

    /// <summary>
    /// Invalida a password actual e devolve link para o utilizador definir uma nova.
    /// </summary>
    [HttpPost("reset-password")]
    public async Task<IActionResult> ResetPassword(
        [FromBody] EmailBodyRequest request,
        CancellationToken cancellationToken)
    {
        if (string.IsNullOrWhiteSpace(request.Email))
            return BadRequest(Problem("Email obrigatório."));

        var (ok, error) = await _service.ResetPasswordAsync(request.Email, cancellationToken);
        if (ok is null)
            return BadRequest(Problem(error ?? "Falha ao resetar palavra-passe."));

        return Ok(ok);
    }

    [HttpPost("admin")]
    public async Task<IActionResult> AtribuirAdmin([FromBody] EmailBodyRequest request)
    {
        if (string.IsNullOrWhiteSpace(request.Email))
            return BadRequest(Problem("Email obrigatório."));

        var (ok, error) = await _service.AtribuirAdminAsync(request.Email);
        if (!ok)
            return BadRequest(Problem(error ?? "Falha ao atribuir Admin."));

        return NoContent();
    }

    [HttpDelete("admin")]
    public async Task<IActionResult> RemoverAdmin([FromBody] EmailBodyRequest request)
    {
        if (string.IsNullOrWhiteSpace(request.Email))
            return BadRequest(Problem("Email obrigatório."));

        var (ok, error) = await _service.RemoverAdminAsync(request.Email);
        if (!ok)
            return BadRequest(Problem(error ?? "Falha ao remover Admin."));

        return NoContent();
    }

    private static ProblemDetails Problem(string detail) => new()
    {
        Title = "Pedido inválido",
        Detail = detail,
        Status = StatusCodes.Status400BadRequest
    };
}
