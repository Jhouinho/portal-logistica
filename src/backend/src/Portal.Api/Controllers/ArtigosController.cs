using Microsoft.AspNetCore.Authorization;

using Microsoft.AspNetCore.Mvc;

using Microsoft.AspNetCore.SignalR;

using Portal.Api.Hubs;

using Portal.Application.Encomendas;



namespace Portal.Api.Controllers;



[ApiController]

[Authorize]

[Route("api/v1/artigos")]

public sealed class ArtigosController : ControllerBase

{

    private readonly EncomendasService _encomendas;

    private readonly IHubContext<OperacoesHub> _hub;



    public ArtigosController(EncomendasService encomendas, IHubContext<OperacoesHub> hub)

    {

        _encomendas = encomendas;

        _hub = hub;

    }



    /// <summary>Autocomplete: ref / designação (contém) em linhas de encomendas da série.</summary>

    [HttpGet("sugestoes")]

    public async Task<ActionResult<IReadOnlyList<ArtigoSugestaoDto>>> Sugestoes(

        [FromQuery] string? q,

        [FromQuery] int limit = 20,

        CancellationToken cancellationToken = default)

    {

        if (string.IsNullOrWhiteSpace(q))

            return Ok(Array.Empty<ArtigoSugestaoDto>());



        var items = await _encomendas.SugerirArtigosAsync(q.Trim(), limit, cancellationToken);

        return Ok(items);

    }



    /// <summary>Autocomplete: cor (contém) em linhas de encomendas da série.</summary>

    [HttpGet("sugestoes-cor")]

    public async Task<ActionResult<IReadOnlyList<string>>> SugestoesCor(

        [FromQuery] string? q,

        [FromQuery] int limit = 20,

        CancellationToken cancellationToken = default)

    {

        if (string.IsNullOrWhiteSpace(q))

            return Ok(Array.Empty<string>());



        var items = await _encomendas.SugerirCoresAsync(q.Trim(), limit, cancellationToken);

        return Ok(items);

    }



    /// <summary>Resumo da procura aberta por artigo (ref+cor), classificado por limite de planeamento.</summary>
    [HttpGet("procura-aberta")]
    public async Task<ActionResult<ArtigoProcuraResponseDto>> ProcuraAberta(
        [FromQuery] string? estadoPlaneamento,
        [FromQuery] string? q,
        [FromQuery] string? cor,
        [FromQuery] string? dataDe,
        [FromQuery] string? dataAte,
        [FromQuery] string? horaDe,
        [FromQuery] string? horaAte,
        [FromQuery] string? clienteNoContem,
        [FromQuery] string? metodoExpedicao,
        [FromQuery] int page = 1,
        [FromQuery] int? pageSize = null,
        CancellationToken cancellationToken = default)
    {
        var result = await _encomendas.ListarProcuraAbertaAsync(
            estadoPlaneamento,
            q,
            cor,
            DateQuery.ParseDateOnly(dataDe),
            DateQuery.ParseDateOnly(dataAte),
            horaDe,
            horaAte,
            clienteNoContem,
            metodoExpedicao,
            page,
            pageSize,
            cancellationToken);
        return Ok(result);
    }



    /// <summary>Distribuição por encomenda de um artigo (expand do resumo).</summary>

    [HttpGet("{ref}/encomendas-abertas")]

    public async Task<ActionResult<ArtigoEncomendasAbertasResponseDto>> EncomendasAbertas(

        [FromRoute] string @ref,

        [FromQuery] string? cor,

        [FromQuery] string? estadoPlaneamento,

        CancellationToken cancellationToken = default)

    {

        // cor ausente → não filtrar; cor="" → só linhas sem cor (Request.Query contém a chave).

        string? corFiltro = null;

        if (Request.Query.ContainsKey("cor"))

            corFiltro = cor ?? string.Empty;



        var result = await _encomendas.ObterEncomendasAbertasPorArtigoAsync(

            @ref,

            corFiltro,

            estadoPlaneamento,

            cancellationToken);



        if (result is null)

            return BadRequest();



        return Ok(result);

    }



    /// <summary>Simula alocação proporcional (não grava).</summary>

    [HttpPost("{ref}/alocar/previsualizar")]

    public async Task<ActionResult<AlocarArtigoResponseDto>> PrevisualizarAlocacao(

        [FromRoute] string @ref,

        [FromBody] AlocarArtigoRequest request,

        CancellationToken cancellationToken = default)

    {

        try

        {

            var login = User.Identity?.Name ?? string.Empty;

            var result = await _encomendas.AlocarArtigoAsync(@ref, request, login, simular: true, cancellationToken);

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



    /// <summary>Alocação proporcional e gravação em u_qtdaut*.</summary>

    [HttpPost("{ref}/alocar")]

    public async Task<ActionResult<AlocarArtigoResponseDto>> Alocar(

        [FromRoute] string @ref,

        [FromBody] AlocarArtigoRequest request,

        CancellationToken cancellationToken = default)

    {

        var login = User.Identity?.Name;

        if (string.IsNullOrWhiteSpace(login))

            return Unauthorized();



        try

        {

            var result = await _encomendas.AlocarArtigoAsync(@ref, request, login, simular: false, cancellationToken);



            await _hub.Clients.Group("operacoes").SendAsync(

                OperacoesHubEvents.QuantidadeAutorizada,

                result,

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


