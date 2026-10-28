using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using Portal.Application.Auth;
using Portal.Application.Cliente;
using Portal.Application.Encomendas;

namespace Portal.Api.Controllers;

/// <summary>
/// Área staff — Pedidos Mobile internos (u_HcaPmPedido). Autenticação Identity staff, não cookie cliente.
/// </summary>
[ApiController]
[Authorize]
[Route("api/v1/staff/pedidos-mobile")]
public sealed class StaffPmPedidosController : ControllerBase
{
    private readonly IStaffPmPedidosService _service;
    private readonly IUserLookup _phcUsers;

    public StaffPmPedidosController(IStaffPmPedidosService service, IUserLookup phcUsers)
    {
        _service = service;
        _phcUsers = phcUsers;
    }

    /// <summary>
    /// filtro: pendentes (default) | em_separacao | pronto_levantamento | concluidos | rejeitados | todos
    /// (integrados = alias de em_separacao, inclui legado «integrado»).
    /// </summary>
    [HttpGet]
    public async Task<ActionResult<IReadOnlyList<StaffPmPedidoListaItemDto>>> Listar(
        [FromQuery] string? filtro = "pendentes",
        [FromQuery] int top = 100,
        CancellationToken cancellationToken = default)
    {
        var items = await _service.ListarAsync(filtro, top, cancellationToken);
        return Ok(items);
    }

    [HttpGet("{pedidoId:long}")]
    public async Task<ActionResult<StaffPmPedidoDetalheDto>> Obter(
        long pedidoId,
        CancellationToken cancellationToken = default)
    {
        var item = await _service.ObterAsync(pedidoId, cancellationToken);
        return item is null ? NotFound() : Ok(item);
    }

    [HttpPost("{pedidoId:long}/aprovar")]
    public async Task<ActionResult<StaffPmAprovarResultDto>> Aprovar(
        long pedidoId,
        CancellationToken cancellationToken = default)
    {
        var login = User.Identity?.Name;
        if (string.IsNullOrWhiteSpace(login))
            return Unauthorized();

        try
        {
            var usrinis = await ResolveIniciaisAsync(cancellationToken) ?? "PRT";
            var result = await _service.AprovarAsync(pedidoId, usrinis, login, cancellationToken);
            return Ok(result);
        }
        catch (PortalBusinessException ex)
        {
            return StatusCode(ex.StatusCode, new ProblemDetails
            {
                Title = "Pedido Mobile",
                Detail = ex.Message,
                Status = ex.StatusCode
            });
        }
    }

    [HttpPost("{pedidoId:long}/rejeitar")]
    public async Task<ActionResult<StaffPmRejeitarResultDto>> Rejeitar(
        long pedidoId,
        [FromBody] StaffPmRejeitarRequest? body,
        CancellationToken cancellationToken = default)
    {
        var login = User.Identity?.Name;
        if (string.IsNullOrWhiteSpace(login))
            return Unauthorized();

        try
        {
            var result = await _service.RejeitarAsync(
                pedidoId, body?.Motivo, login, cancellationToken);
            return Ok(result);
        }
        catch (PortalBusinessException ex)
        {
            return StatusCode(ex.StatusCode, new ProblemDetails
            {
                Title = "Pedido Mobile",
                Detail = ex.Message,
                Status = ex.StatusCode
            });
        }
    }

    /// <summary>Guarda preços do operador (PrecoUnitario). Não usa autenticação cliente.</summary>
    [HttpPut("{pedidoId:long}/precos")]
    public async Task<ActionResult<StaffPmPedidoDetalheDto>> GuardarPrecos(
        long pedidoId,
        [FromBody] StaffPmGuardarPrecosRequest? body,
        CancellationToken cancellationToken = default)
    {
        if (string.IsNullOrWhiteSpace(User.Identity?.Name))
            return Unauthorized();

        try
        {
            var result = await _service.GuardarPrecosAsync(
                pedidoId,
                body?.Linhas ?? Array.Empty<StaffPmPrecoLinhaRequest>(),
                cancellationToken);
            return Ok(result);
        }
        catch (PortalBusinessException ex)
        {
            return StatusCode(ex.StatusCode, new ProblemDetails
            {
                Title = "Pedido Mobile",
                Detail = ex.Message,
                Status = ex.StatusCode
            });
        }
    }

    /// <summary>
    /// Substitui linhas do pedido (quantidade, preço, adicionar, eliminar) enquanto pendente.
    /// </summary>
    [HttpPut("{pedidoId:long}/linhas")]
    public async Task<ActionResult<StaffPmPedidoDetalheDto>> GuardarLinhas(
        long pedidoId,
        [FromBody] StaffPmGuardarLinhasRequest? body,
        CancellationToken cancellationToken = default)
    {
        if (string.IsNullOrWhiteSpace(User.Identity?.Name))
            return Unauthorized();

        try
        {
            var result = await _service.GuardarLinhasAsync(
                pedidoId,
                body?.Linhas ?? Array.Empty<StaffPmLinhaEditRequest>(),
                cancellationToken);
            return Ok(result);
        }
        catch (PortalBusinessException ex)
        {
            return StatusCode(ex.StatusCode, new ProblemDetails
            {
                Title = "Pedido Mobile",
                Detail = ex.Message,
                Status = ex.StatusCode
            });
        }
    }

    /// <summary>Avanço operacional: body.acao = pronto_levantamento | concluir.</summary>
    [HttpPost("{pedidoId:long}/operacao")]
    public async Task<ActionResult<StaffPmOperacaoResultDto>> Operacao(
        long pedidoId,
        [FromBody] StaffPmOperacaoRequest? body,
        CancellationToken cancellationToken = default)
    {
        var login = User.Identity?.Name;
        if (string.IsNullOrWhiteSpace(login))
            return Unauthorized();

        try
        {
            var result = await _service.AvancarOperacaoAsync(
                pedidoId, body?.Acao, login, cancellationToken);
            return Ok(result);
        }
        catch (PortalBusinessException ex)
        {
            return StatusCode(ex.StatusCode, new ProblemDetails
            {
                Title = "Pedido Mobile",
                Detail = ex.Message,
                Status = ex.StatusCode
            });
        }
    }

    private async Task<string?> ResolveIniciaisAsync(CancellationToken cancellationToken)
    {
        var fromClaim = User.FindFirst("iniciais")?.Value?.Trim();
        if (!string.IsNullOrWhiteSpace(fromClaim))
            return fromClaim.Length <= 3 ? fromClaim : fromClaim[..3];

        var usercodeClaim = User.FindFirst("usercode")?.Value?.Trim();
        var identityName = User.Identity?.Name?.Trim();
        var key = !string.IsNullOrWhiteSpace(usercodeClaim) && !usercodeClaim.Contains('@')
            ? usercodeClaim
            : identityName;
        if (string.IsNullOrWhiteSpace(key))
            return null;

        var phc = key.Contains('@')
            ? await _phcUsers.FindByEmailAsync(key, cancellationToken)
            : await _phcUsers.FindByLoginAsync(key, cancellationToken);
        var iniciais = phc?.Usrinis?.Trim();
        if (string.IsNullOrWhiteSpace(iniciais))
            return null;
        return iniciais.Length <= 3 ? iniciais : iniciais[..3];
    }
}
