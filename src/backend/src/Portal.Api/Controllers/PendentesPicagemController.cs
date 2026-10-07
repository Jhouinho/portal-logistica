using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using Portal.Application.Encomendas;

namespace Portal.Api.Controllers;

/// <summary>
/// Fase 1 — API «Quantidades Pendentes de Picagens» (ndos=1, regra híbrida Kapps/SUM66).
/// </summary>
[ApiController]
[Authorize]
[Route("api/v1/pendentes-picagem")]
public sealed class PendentesPicagemController : ControllerBase
{
    private readonly PendentesPicagemService _service;

    public PendentesPicagemController(PendentesPicagemService service)
    {
        _service = service;
    }

    /// <summary>Lista agregada por encomenda (padrão paginação 1A: pageSize omitido = todos).</summary>
    [HttpGet]
    public async Task<ActionResult<PendentesPicagemEncomendaListaDto>> ListarPorEncomenda(
        [FromQuery] string? dataDe,
        [FromQuery] string? dataAte,
        [FromQuery] int? obrano,
        [FromQuery] string? artigoRef,
        [FromQuery] string? artigoCor,
        [FromQuery] string? clienteNomeContem,
        [FromQuery] int page = 1,
        [FromQuery] int? pageSize = null,
        CancellationToken cancellationToken = default)
    {
        var filtro = BuildFiltro(dataDe, dataAte, obrano, artigoRef, artigoCor, clienteNomeContem, page, pageSize);
        var result = await _service.ListarPorEncomendaAsync(filtro, cancellationToken);
        return Ok(result);
    }

    /// <summary>Lista agregada por referência.</summary>
    [HttpGet("por-referencia")]
    public async Task<ActionResult<PendentesPicagemReferenciaListaDto>> ListarPorReferencia(
        [FromQuery] string? dataDe,
        [FromQuery] string? dataAte,
        [FromQuery] int? obrano,
        [FromQuery] string? artigoRef,
        [FromQuery] string? artigoCor,
        [FromQuery] string? clienteNomeContem,
        [FromQuery] int page = 1,
        [FromQuery] int? pageSize = null,
        CancellationToken cancellationToken = default)
    {
        var filtro = BuildFiltro(dataDe, dataAte, obrano, artigoRef, artigoCor, clienteNomeContem, page, pageSize);
        var result = await _service.ListarPorReferenciaAsync(filtro, cancellationToken);
        return Ok(result);
    }

    [HttpGet("{boStamp}/linhas")]
    public async Task<ActionResult<IReadOnlyList<PendentesPicagemLinhaDto>>> Linhas(
        string boStamp,
        CancellationToken cancellationToken = default)
    {
        var linhas = await _service.ListarLinhasEncomendaAsync(boStamp, cancellationToken);
        return Ok(linhas);
    }

    private static PendentesPicagemFiltro BuildFiltro(
        string? dataDe,
        string? dataAte,
        int? obrano,
        string? artigoRef,
        string? artigoCor,
        string? clienteNomeContem,
        int page,
        int? pageSize) =>
        new()
        {
            DataDe = DateQuery.ParseDateOnly(dataDe),
            DataAte = DateQuery.ParseDateOnly(dataAte),
            Obrano = obrano,
            ArtigoRef = artigoRef,
            ArtigoCor = artigoCor,
            ClienteNomeContem = clienteNomeContem,
            Page = page,
            PageSize = pageSize
        };
}
