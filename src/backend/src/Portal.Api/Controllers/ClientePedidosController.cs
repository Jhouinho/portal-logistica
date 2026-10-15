using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using Portal.Api.Cliente;
using Portal.Application.Cliente;

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

    [HttpGet("{bostamp}")]
    public async Task<IActionResult> Detalhe(string bostamp, CancellationToken ct)
    {
        if (!ClienteSession.TryGetCliente(User, out var no, out var estab))
            return Unauthorized();

        var d = await _pedidos.ObterAsync(no, estab, bostamp, ct);
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

        if (body.Linhas is null || body.Linhas.Count == 0)
        {
            return BadRequest(new ProblemDetails
            {
                Title = "Dados inválidos",
                Detail = "É obrigatória pelo menos uma linha.",
                Status = 400
            });
        }

        foreach (var l in body.Linhas)
        {
            if (l.Qtt != Math.Floor(l.Qtt) || l.Qtt <= 0)
            {
                return BadRequest(new ProblemDetails
                {
                    Title = "Dados inválidos",
                    Detail = "As quantidades devem ser números inteiros positivos.",
                    Status = 400
                });
            }
        }

        try
        {
            var linhas = body.Linhas
                .Select(l => new ClientePedidoLinhaInput(
                    l.LinhaOrd,
                    l.Ref,
                    l.Qtt,
                    ClienteCorLimits.Normalize(l.Cor)))
                .ToList();
            var result = await _pedidos.CriarAsync(no, estab, key.Trim(), linhas, ct);
            return Ok(result);
        }
        catch (Exception ex)
        {
            return BadRequest(new ProblemDetails
            {
                Title = "Falha na submissão",
                Detail = ex.Message,
                Status = 400
            });
        }
    }

    [HttpPost("{bostamp}/cancelar")]
    public async Task<IActionResult> Cancelar(string bostamp, CancellationToken ct)
    {
        if (!ClienteSession.TryGetCliente(User, out var no, out var estab))
            return Unauthorized();

        var (ok, error) = await _pedidos.CancelarAsync(no, estab, bostamp, ct);
        if (!ok)
        {
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
