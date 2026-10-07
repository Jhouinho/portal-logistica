using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using Portal.Application.Encomendas;

namespace Portal.Api.Controllers;

[ApiController]
[Authorize]
[Route("api/v1/separacao-dossiers")]
public sealed class SeparacaoDossiersController : ControllerBase
{
    private readonly SeparacaoDossiersService _service;

    public SeparacaoDossiersController(SeparacaoDossiersService service)
    {
        _service = service;
    }

    [HttpGet]
    public async Task<ActionResult<EncomendaListaResponseDto>> Listar(
        [FromQuery] bool fechada = false,
        [FromQuery] string? dataDe = null,
        [FromQuery] string? dataAte = null,
        [FromQuery] string? horaDe = null,
        [FromQuery] string? horaAte = null,
        [FromQuery] int? clienteNo = null,
        [FromQuery] string? clienteNoContem = null,
        [FromQuery] string? artigoRef = null,
        [FromQuery] string? artigoCor = null,
        [FromQuery] string? estadoPlaneamento = null,
        [FromQuery] string? metodoExpedicao = null,
        [FromQuery] int page = 1,
        [FromQuery] int pageSize = 50,
        CancellationToken cancellationToken = default)
    {
        var filtro = new EncomendasFiltro
        {
            DataDe = DateQuery.ParseDateOnly(dataDe),
            DataAte = DateQuery.ParseDateOnly(dataAte),
            HoraDe = horaDe,
            HoraAte = horaAte,
            ClienteNo = clienteNo,
            ClienteNoContem = clienteNoContem,
            ArtigoRef = artigoRef,
            ArtigoCor = artigoCor,
            EstadoPlaneamento = estadoPlaneamento,
            MetodoExpedicao = metodoExpedicao,
            Page = page,
            PageSize = pageSize
        };

        var result = await _service.ListarAsync(filtro, fechada, cancellationToken);
        return Ok(result);
    }

    [HttpGet("{boStamp}/linhas")]
    public async Task<ActionResult<IReadOnlyList<EncomendaLinhaDto>>> Linhas(
        string boStamp,
        CancellationToken cancellationToken = default)
    {
        var linhas = await _service.ListarLinhasAsync(boStamp, cancellationToken);
        return Ok(linhas);
    }

    [HttpPatch("{boStamp}/fechada")]
    public async Task<ActionResult<FechoPickingAtualizadaDto>> MarcarFecho(
        string boStamp,
        [FromBody] MarcarFechoPickingRequest request,
        CancellationToken cancellationToken = default)
    {
        var login = User.Identity?.Name;
        if (string.IsNullOrWhiteSpace(login))
            return Unauthorized();

        try
        {
            var result = await _service.MarcarFechoAsync(
                boStamp,
                request,
                login,
                cancellationToken);
            return Ok(result);
        }
        catch (PortalBusinessException ex)
        {
            return StatusCode(ex.StatusCode, new ProblemDetails
            {
                Title = ex.StatusCode switch
                {
                    404 => "Não encontrado",
                    409 => "Conflito",
                    _ => "Pedido inválido"
                },
                Detail = ex.Message,
                Status = ex.StatusCode
            });
        }
    }
}
