using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using Portal.Application.Painel;

namespace Portal.Api.Controllers;

[ApiController]
[Authorize]
[Route("api/v1/painel")]
public sealed class PainelController : ControllerBase
{
    private readonly PainelService _service;

    public PainelController(PainelService service)
    {
        _service = service;
    }

    [HttpGet("kpis")]
    public async Task<ActionResult<PainelKpisDto>> Kpis(CancellationToken cancellationToken)
    {
        var kpis = await _service.ObterKpisAsync(cancellationToken);
        return Ok(kpis);
    }

    /// <summary>KPIs do fluxo operacional — usado pela Vista TV (parede), sem login.</summary>
    [AllowAnonymous]
    [HttpGet("centro-estados")]
    public async Task<ActionResult<CentroEstadosKpisDto>> CentroEstados(
        CancellationToken cancellationToken)
    {
        var kpis = await _service.ObterCentroEstadosAsync(cancellationToken);
        return Ok(kpis);
    }

    /// <summary>
    /// Resumo Kapps magro para Vista TV (kind/pct/operador) — sem N+1 detalhe.
    /// </summary>
    [AllowAnonymous]
    [HttpGet("tv-kapps-resumo")]
    public async Task<ActionResult<TvKappsResumoDto>> TvKappsResumo(
        CancellationToken cancellationToken)
    {
        var resumo = await _service.ObterTvKappsResumoAsync(cancellationToken);
        return Ok(resumo);
    }
}
