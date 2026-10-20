using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using Portal.Api.Cliente;
using Portal.Application.Cliente;
using Portal.Application.Encomendas;

namespace Portal.Api.Controllers;

[ApiController]
[Authorize(AuthenticationSchemes = ClienteAuthConstants.CookieScheme, Policy = ClienteAuthConstants.PolicyName)]
[Route("api/v1/cliente/pedidos")]
public sealed class ClientePedidosController : ControllerBase
{
    private readonly IClientePedidosService _pedidos;

    public ClientePedidosController(IClientePedidosService pedidos) => _pedidos = pedidos;

    public sealed record LinhaDto(int LinhaOrd, string Ref, decimal Qtt, string? Cor);
    public sealed record CriarPedidoDto(IReadOnlyList<LinhaDto> Linhas);

    [HttpGet]
    public async Task<IActionResult> Listar([FromQuery] int top = 10, CancellationToken ct = default)
    {
        if (!ClienteSession.TryGetCliente(User, out var no, out var estab))
            return Unauthorized();

        var items = await _pedidos.ListarAsync(no, estab, top, ct);
        return Ok(items);
    }

    /// <summary>
    /// Detalhe: <c>pedidoId</c> (só dígitos), <c>NumeroInterno</c> (<c>PM-AAAA-######</c>) ou <c>bostamp</c> legado.
    /// </summary>
    [HttpGet("{id}")]
    public async Task<IActionResult> Detalhe(string id, CancellationToken ct)
    {
        if (!ClienteSession.TryGetCliente(User, out var no, out var estab))
            return Unauthorized();

        var d = await _pedidos.ObterAsync(no, estab, id, ct);
        if (d is null)
            return NotFound(new ProblemDetails { Title = "Não encontrado", Status = 404 });
        return Ok(d);
    }

    [HttpPost]
    public async Task<IActionResult> Criar([FromBody] CriarPedidoDto body, CancellationToken ct)
    {
        if (!ClienteSession.TryGetCliente(User, out var no, out var estab))
            return Unauthorized();

        var key = Request.Headers["Idempotency-Key"].FirstOrDefault()
                  ?? Request.Headers["IdempotencyKey"].FirstOrDefault();
        if (string.IsNullOrWhiteSpace(key))
        {
            return BadRequest(new ProblemDetails
            {
                Title = "Dados inválidos",
                Detail = "Header Idempotency-Key é obrigatório.",
                Status = 400
            });
        }

        key = key.Trim();
        if (!ClientePedidoSubmitRules.IsIdempotencyKeyLengthValid(key))
        {
            return BadRequest(new ProblemDetails
            {
                Title = "Dados inválidos",
                Detail =
                    $"Idempotency-Key não pode exceder {ClientePedidoSubmitRules.IdempotencyKeyMaxLength} caracteres.",
                Status = 400
            });
        }

        if (body.Linhas is null || body.Linhas.Count == 0)
        {
            return BadRequest(new ProblemDetails
            {
                Title = "Dados inválidos",
                Detail = "É obrigatória pelo menos uma linha.",
                Status = 400
            });
        }

        var linhas = body.Linhas
            .Select(l => new ClientePedidoLinhaInput(
                l.LinhaOrd,
                l.Ref,
                l.Qtt,
                ClienteCorLimits.Normalize(l.Cor)))
            .ToList();

        var linhasErro = ClientePedidoSubmitRules.ValidateLinhasOrError(linhas);
        if (linhasErro is not null)
        {
            return BadRequest(new ProblemDetails
            {
                Title = "Dados inválidos",
                Detail = linhasErro,
                Status = 400
            });
        }

        try
        {
            var result = await _pedidos.CriarAsync(no, estab, key, linhas, ct);
            return Ok(result);
        }
        catch (PortalBusinessException ex) when (ex.StatusCode == StatusCodes.Status409Conflict)
        {
            return Conflict(new ProblemDetails
            {
                Title = "Conflito",
                Detail = ex.Message,
                Status = StatusCodes.Status409Conflict
            });
        }
        catch (PortalBusinessException ex) when (ex.StatusCode is >= 400 and < 500)
        {
            return StatusCode(ex.StatusCode, new ProblemDetails
            {
                Title = "Dados inválidos",
                Detail = ex.Message,
                Status = ex.StatusCode
            });
        }
    }

    [HttpPost("{id}/cancelar")]
    public async Task<IActionResult> Cancelar(string id, CancellationToken ct)
    {
        if (!ClienteSession.TryGetCliente(User, out var no, out var estab))
            return Unauthorized();

        var (ok, error) = await _pedidos.CancelarAsync(no, estab, id, ct);
        if (!ok)
        {
            if (error == "interno_proibido")
            {
                return StatusCode(StatusCodes.Status403Forbidden, new ProblemDetails
                {
                    Title = "Acesso negado",
                    Detail = "Não é possível cancelar este pedido após a submissão.",
                    Status = StatusCodes.Status403Forbidden
                });
            }

            return BadRequest(new ProblemDetails
            {
                Title = "Cancelamento não efectuado",
                Detail = error switch
                {
                    "estado_invalido" => "Só é possível cancelar pedidos no estado «Pedido submetido».",
                    "ja_cancelado" => "O pedido já estava cancelado.",
                    _ => "Pedido não encontrado."
                },
                Status = 400
            });
        }

        return Ok(new { mensagem = "Pedido cancelado com sucesso" });
    }
}
