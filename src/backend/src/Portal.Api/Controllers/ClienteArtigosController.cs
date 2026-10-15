using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using Portal.Api.Cliente;
using Portal.Application.Cliente;

namespace Portal.Api.Controllers;

[ApiController]
[Authorize(AuthenticationSchemes = ClienteAuthConstants.CookieScheme, Policy = ClienteAuthConstants.PolicyName)]
[Route("api/v1/cliente/artigos")]
public sealed class ClienteArtigosController : ControllerBase
{
    private readonly IClienteCatalogoQuery _catalogo;

    public ClienteArtigosController(IClienteCatalogoQuery catalogo) => _catalogo = catalogo;

    [HttpGet("{referencia}")]
    public async Task<IActionResult> Get(string referencia, CancellationToken ct)
    {
        if (!ClienteSession.TryGetCliente(User, out var no, out var estab))
            return Unauthorized();

        var artigo = await _catalogo.GetArtigoAsync(no, estab, referencia, ct);
        if (artigo is null)
        {
            return NotFound(new ProblemDetails
            {
                Title = "Não encontrado",
                Detail = "Artigo não encontrado ou inactivo.",
                Status = StatusCodes.Status404NotFound
            });
        }

        return Ok(artigo);
    }

    [HttpGet("~/api/v1/cliente/cores")]
    public async Task<IActionResult> Cores(CancellationToken ct)
    {
        var cores = await _catalogo.ListarCoresAsync(ct);
        return Ok(cores);
    }
}
