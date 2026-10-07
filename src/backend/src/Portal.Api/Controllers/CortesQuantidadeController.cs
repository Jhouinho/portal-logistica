using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using Portal.Application.Encomendas;

namespace Portal.Api.Controllers;

[ApiController]
[Authorize]
[Route("api/v1/cortes-quantidade")]
public sealed class CortesQuantidadeController : ControllerBase
{
    private readonly EncomendasService _service;

    public CortesQuantidadeController(EncomendasService service)
    {
        _service = service;
    }

    [HttpGet]
    public async Task<ActionResult<CortesQuantidadeResponseDto>> Listar(
        [FromQuery] string? dataDe,
        [FromQuery] string? dataAte,
        [FromQuery] int? obrano,
        [FromQuery] string? artigoRef,
        [FromQuery] string? artigoCor,
        [FromQuery] int page = 1,
        [FromQuery] int pageSize = 50,
        CancellationToken cancellationToken = default)
    {
        var filtro = new CortesQuantidadeFiltro
        {
            DataDe = DateQuery.ParseDateOnly(dataDe),
            DataAte = DateQuery.ParseDateOnly(dataAte),
            Obrano = obrano,
            ArtigoRef = artigoRef,
            ArtigoCor = artigoCor,
            Page = page,
            PageSize = pageSize
        };

        var result = await _service.ListarCortesQuantidadeAsync(filtro, cancellationToken);
        return Ok(result);
    }

    [HttpGet("{boStamp}/linhas")]
    public async Task<ActionResult<IReadOnlyList<CorteQuantidadeLinhaDto>>> Linhas(
        string boStamp,
        [FromQuery] string? artigoRef,
        [FromQuery] string? artigoCor,
        CancellationToken cancellationToken = default)
    {
        var linhas = await _service.ListarCortesLinhasAsync(
            boStamp,
            artigoRef,
            artigoCor,
            cancellationToken);
        return Ok(linhas);
    }
}
