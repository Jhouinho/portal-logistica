using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using Portal.Application.Auth;
using Portal.Application.Encomendas;
using Portal.Application.PrevisoesEntrada;

namespace Portal.Api.Controllers;

[ApiController]
[Authorize(Roles = PortalRoles.Admin)]
[Route("api/v1/previsoes-entrada")]
public sealed class PrevisoesEntradaController : ControllerBase
{
    private readonly PrevisoesEntradaService _service;

    public PrevisoesEntradaController(PrevisoesEntradaService service)
    {
        _service = service;
    }

    [HttpGet]
    public async Task<ActionResult<IReadOnlyList<PrevisaoEntradaListaItemDto>>> Listar(
        CancellationToken cancellationToken)
    {
        return Ok(await _service.ListarAsync(cancellationToken));
    }

    [HttpGet("artigos/sugestoes")]
    public async Task<ActionResult<IReadOnlyList<PrevisaoArtigoSugestaoDto>>> Sugestoes(
        [FromQuery] string? q,
        [FromQuery] int limit = 20,
        CancellationToken cancellationToken = default)
    {
        if (string.IsNullOrWhiteSpace(q))
            return Ok(Array.Empty<PrevisaoArtigoSugestaoDto>());

        var items = await _service.SugerirArtigosAsync(q.Trim(), limit, cancellationToken);
        return Ok(items);
    }

    [HttpGet("cores/sugestoes")]
    public async Task<ActionResult<IReadOnlyList<PrevisaoCorSugestaoDto>>> SugestoesCores(
        [FromQuery] string? artigoRef,
        [FromQuery] string? q,
        [FromQuery] int limit = 30,
        CancellationToken cancellationToken = default)
    {
        if (string.IsNullOrWhiteSpace(artigoRef))
            return Ok(Array.Empty<PrevisaoCorSugestaoDto>());

        var items = await _service.SugerirCoresAsync(artigoRef.Trim(), q, limit, cancellationToken);
        return Ok(items);
    }

    [HttpGet("{id:guid}")]
    public async Task<ActionResult<PrevisaoEntradaDetalheDto>> Obter(
        Guid id,
        CancellationToken cancellationToken)
    {
        var item = await _service.ObterAsync(id, cancellationToken);
        return item is null ? NotFound() : Ok(item);
    }

    [HttpPost]
    public async Task<ActionResult<PrevisaoEntradaDetalheDto>> Criar(
        [FromBody] CriarPrevisaoEntradaRequest request,
        CancellationToken cancellationToken)
    {
        try
        {
            var login = User.Identity?.Name ?? string.Empty;
            var created = await _service.CriarAsync(request, login, cancellationToken);
            return CreatedAtAction(nameof(Obter), new { id = created.Id }, created);
        }
        catch (PortalBusinessException ex)
        {
            return StatusCode(ex.StatusCode, Problem(ex));
        }
    }

    [HttpPut("{id:guid}")]
    public async Task<ActionResult<PrevisaoEntradaDetalheDto>> Guardar(
        Guid id,
        [FromBody] GuardarPrevisaoEntradaRequest request,
        CancellationToken cancellationToken)
    {
        try
        {
            var login = User.Identity?.Name ?? string.Empty;
            var saved = await _service.GuardarAsync(id, request, login, cancellationToken);
            return Ok(saved);
        }
        catch (PortalBusinessException ex)
        {
            return StatusCode(ex.StatusCode, Problem(ex));
        }
    }

    [HttpPost("{id:guid}/fechar")]
    public async Task<ActionResult<PrevisaoEntradaDetalheDto>> Fechar(
        Guid id,
        CancellationToken cancellationToken)
    {
        try
        {
            var login = User.Identity?.Name ?? string.Empty;
            var closed = await _service.FecharAsync(id, login, cancellationToken);
            return Ok(closed);
        }
        catch (PortalBusinessException ex)
        {
            return StatusCode(ex.StatusCode, Problem(ex));
        }
    }

    public sealed record AtualizarLinhasResponse(
        PrevisaoEntradaDetalheDto Detalhe,
        int LinhasAdicionadas);

    [HttpPost("{id:guid}/atualizar-linhas")]
    public async Task<ActionResult<AtualizarLinhasResponse>> AtualizarLinhas(
        Guid id,
        CancellationToken cancellationToken)
    {
        try
        {
            var login = User.Identity?.Name ?? string.Empty;
            var (detalhe, n) = await _service.AtualizarLinhasAsync(id, login, cancellationToken);
            return Ok(new AtualizarLinhasResponse(detalhe, n));
        }
        catch (PortalBusinessException ex)
        {
            return StatusCode(ex.StatusCode, Problem(ex));
        }
    }

    private static ProblemDetails Problem(PortalBusinessException ex) => new()
    {
        Title = ex.StatusCode switch
        {
            404 => "Não encontrado",
            409 => "Conflito",
            _ => "Pedido inválido"
        },
        Detail = ex.Message,
        Status = ex.StatusCode
    };
}
