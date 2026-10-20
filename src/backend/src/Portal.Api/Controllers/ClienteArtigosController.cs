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

    /// <summary>Imagem do artigo (IFL.bdados ou ficheiro ST.imagem). Cookie cliente obrigatório.</summary>
    [HttpGet("{referencia}/imagem")]
    [ResponseCache(Duration = 300, Location = ResponseCacheLocation.Client, NoStore = false)]
    public async Task<IActionResult> GetImagem(string referencia, CancellationToken ct)
    {
        if (!ClienteSession.TryGetCliente(User, out var no, out var estab))
            return Unauthorized();

        var img = await _catalogo.GetArtigoImagemAsync(no, estab, referencia, ct);
        if (img is null)
        {
            return NotFound(new ProblemDetails
            {
                Title = "Não encontrado",
                Detail = "Imagem do artigo indisponível.",
                Status = StatusCodes.Status404NotFound
            });
        }

        if (!string.IsNullOrWhiteSpace(img.FileName))
            Response.Headers.ContentDisposition = $"inline; filename=\"{img.FileName}\"";

        return File(img.Conteudo, img.ContentType);
    }
}
