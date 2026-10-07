using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using Microsoft.AspNetCore.SignalR;
using Portal.Api.Hubs;
using Portal.Application.Auth;
using Portal.Application.Encomendas;

namespace Portal.Api.Controllers;

[ApiController]
[Authorize]
[Route("api/v1/encomendas")]
public sealed class EncomendasController : ControllerBase
{
    private readonly EncomendasService _service;
    private readonly KappsPickingService _kappsPicking;
    private readonly IHubContext<OperacoesHub> _hub;
    private readonly IUserLookup _phcUsers;

    public EncomendasController(
        EncomendasService service,
        KappsPickingService kappsPicking,
        IHubContext<OperacoesHub> hub,
        IUserLookup phcUsers)
    {
        _service = service;
        _kappsPicking = kappsPicking;
        _hub = hub;
        _phcUsers = phcUsers;
    }

    /// <summary>Lista abertas — leitura também pela Vista TV (sem login).</summary>
    [AllowAnonymous]
    [HttpGet("abertas")]
    public async Task<ActionResult<EncomendaListaResponseDto>> ListarAbertas(
        [FromQuery] string? dataDe,
        [FromQuery] string? dataAte,
        [FromQuery] string? horaDe,
        [FromQuery] string? horaAte,
        [FromQuery] int? clienteNo,
        [FromQuery] string? clienteNoContem,
        [FromQuery] string? artigoRef,
        [FromQuery] string? artigoCor,
        [FromQuery] string? estadoPlaneamento,
        [FromQuery] string? metodoExpedicao = null,
        [FromQuery] bool prontaPicking = false,
        [FromQuery] int? pickStatus = null,
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
            ProntaPicking = prontaPicking,
            PickStatus = pickStatus,
            Page = page,
            PageSize = pageSize
        };

        var result = await _service.ListarAbertasAsync(filtro, cancellationToken);
        return Ok(result);
    }

    [HttpGet("{boStamp}")]
    public async Task<ActionResult<EncomendaDetalheDto>> Obter(
        string boStamp,
        CancellationToken cancellationToken = default)
    {
        var detalhe = await _service.ObterDetalheAsync(boStamp, cancellationToken);
        if (detalhe is null)
            return NotFound(new ProblemDetails
            {
                Title = "Não encontrado",
                Detail = "Encomenda não encontrada ou fora da série configurada.",
                Status = StatusCodes.Status404NotFound
            });

        return Ok(detalhe);
    }

    /// <summary>
    /// Picking Kapps associado à encomenda (leitura das views Kapps).
    /// 404 se a encomenda não existir; 204 se existir sem picking Kapps visível.
    /// Leitura também pela Vista TV (sem login).
    /// </summary>
    [AllowAnonymous]
    [HttpGet("{boStamp}/picking-kapps")]
    [ProducesResponseType(typeof(KappsPickingDetalheDto), StatusCodes.Status200OK)]
    [ProducesResponseType(StatusCodes.Status204NoContent)]
    [ProducesResponseType(StatusCodes.Status404NotFound)]
    public async Task<ActionResult<KappsPickingDetalheDto>> ObterPickingKapps(
        string boStamp,
        CancellationToken cancellationToken = default)
    {
        var result = await _kappsPicking.ObterPorEncomendaAsync(boStamp, cancellationToken);

        if (!result.Existe)
            return NotFound(new ProblemDetails
            {
                Title = "Não encontrado",
                Detail = "Encomenda não encontrada ou fora da série configurada.",
                Status = StatusCodes.Status404NotFound
            });

        if (result.Detalhe is null)
            return NoContent();

        return Ok(result.Detalhe);
    }

    [HttpPatch("{boStamp}/urgente")]
    public async Task<ActionResult<UrgenteAtualizadaDto>> MarcarUrgente(
        string boStamp,
        [FromBody] MarcarUrgenteRequest request,
        CancellationToken cancellationToken = default)
    {
        var usercode = await ResolvePhcUsercodeAsync(cancellationToken);
        if (string.IsNullOrWhiteSpace(usercode))
            return Unauthorized();

        try
        {
            var iniciais = await ResolveIniciaisClaimAsync(cancellationToken);
            var result = await _service.MarcarUrgenteAsync(
                boStamp,
                request,
                usercode,
                iniciais,
                cancellationToken);

            await _hub.Clients.Group("operacoes").SendAsync(
                OperacoesHubEvents.EncomendaAlterada,
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

    [HttpPost("{boStamp}/cancelar")]
    public async Task<ActionResult<CancelarEncomendaAtualizadaDto>> CancelarEncomenda(
        string boStamp,
        [FromBody] CancelarEncomendaRequest? request,
        CancellationToken cancellationToken = default)
    {
        var usercode = await ResolvePhcUsercodeAsync(cancellationToken);
        if (string.IsNullOrWhiteSpace(usercode))
            return Unauthorized();

        try
        {
            var iniciais = await ResolveIniciaisClaimAsync(cancellationToken);
            var result = await _service.CancelarEncomendaAsync(
                boStamp,
                request ?? new CancelarEncomendaRequest(""),
                usercode,
                iniciais,
                cancellationToken);

            await _hub.Clients.Group("operacoes").SendAsync(
                OperacoesHubEvents.EncomendaAlterada,
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

    [HttpPatch("{boStamp}/pronta-picking")]
    public async Task<ActionResult<ProntaPickingAtualizadaDto>> MarcarProntaPicking(
        string boStamp,
        [FromBody] MarcarProntaPickingRequest request,
        CancellationToken cancellationToken = default)
    {
        var usercode = await ResolvePhcUsercodeAsync(cancellationToken);
        if (string.IsNullOrWhiteSpace(usercode))
            return Unauthorized();

        try
        {
            var iniciais = await ResolveIniciaisClaimAsync(cancellationToken);
            var result = await _service.MarcarProntaPickingAsync(
                boStamp,
                request,
                usercode,
                iniciais,
                cancellationToken);

            await _hub.Clients.Group("operacoes").SendAsync(
                OperacoesHubEvents.EncomendaAlterada,
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

    [HttpPatch("linhas/{biStamp}")]
    public async Task<ActionResult<LinhaAtualizadaDto>> AtualizarLinha(
        string biStamp,
        [FromBody] AtualizarLinhaRequest request,
        CancellationToken cancellationToken = default)
    {
        var iniciais = await ResolveIniciaisClaimAsync(cancellationToken);
        if (string.IsNullOrWhiteSpace(iniciais))
            return BadRequest(new ProblemDetails
            {
                Title = "Pedido inválido",
                Detail = "Utilizador PHC sem iniciais (US.iniciais).",
                Status = StatusCodes.Status400BadRequest
            });

        try
        {
            // Valor de US.iniciais → parâmetro SP @usrinis → campos BI/BO.usrinis do dossier.
            var result = await _service.AtualizarLinhaAsync(
                biStamp,
                request,
                iniciais,
                cancellationToken);

            await _hub.Clients.Group("operacoes").SendAsync(
                OperacoesHubEvents.LinhaQuantidadePreco,
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

    /// <summary>
    /// Claim <c>iniciais</c> = <c>US.iniciais</c>.
    /// Esse valor é depois escrito no dossier em <c>BI/BO.usrinis</c> (campo nativo PHC distinto).
    /// </summary>
    private async Task<string?> ResolveIniciaisClaimAsync(CancellationToken cancellationToken)
    {
        var fromClaim = User.FindFirst("iniciais")?.Value?.Trim();
        if (!string.IsNullOrWhiteSpace(fromClaim))
            return fromClaim.Length <= 3 ? fromClaim : fromClaim[..3];

        var usercode = await ResolvePhcUsercodeAsync(cancellationToken);
        if (string.IsNullOrWhiteSpace(usercode))
            return null;

        var phc = usercode.Contains('@')
            ? await _phcUsers.FindByEmailAsync(usercode, cancellationToken)
            : await _phcUsers.FindByLoginAsync(usercode, cancellationToken);
        var iniciais = phc?.Usrinis?.Trim();
        if (string.IsNullOrWhiteSpace(iniciais))
            return null;

        return iniciais.Length <= 3 ? iniciais : iniciais[..3];
    }

    /// <summary>US.usercode — nunca o email Identity.</summary>
    private async Task<string?> ResolvePhcUsercodeAsync(CancellationToken cancellationToken)
    {
        var usercodeClaim = User.FindFirst("usercode")?.Value?.Trim();
        if (!string.IsNullOrWhiteSpace(usercodeClaim) && !usercodeClaim.Contains('@'))
            return usercodeClaim;

        var nameClaims = User.FindAll(System.Security.Claims.ClaimTypes.Name)
            .Select(c => c.Value?.Trim())
            .Where(v => !string.IsNullOrWhiteSpace(v))
            .Cast<string>()
            .ToList();
        var nonEmail = nameClaims.FirstOrDefault(v => !v.Contains('@'));
        if (!string.IsNullOrWhiteSpace(nonEmail))
            return nonEmail;

        var identityName = User.Identity?.Name?.Trim();
        if (string.IsNullOrWhiteSpace(identityName))
            return null;

        if (identityName.Contains('@'))
        {
            var byEmail = await _phcUsers.FindByEmailAsync(identityName, cancellationToken);
            if (!string.IsNullOrWhiteSpace(byEmail?.Login))
                return byEmail.Login;
        }

        var byLogin = await _phcUsers.FindByLoginAsync(identityName, cancellationToken);
        return !string.IsNullOrWhiteSpace(byLogin?.Login) ? byLogin.Login : identityName;
    }

    [HttpPatch("linhas/{biStamp}/quantidade-autorizada")]
    public async Task<ActionResult<QuantidadeAutorizadaAtualizadaDto>> AtualizarQuantidadeAutorizada(
        string biStamp,
        [FromBody] AtualizarQuantidadeAutorizadaRequest request,
        CancellationToken cancellationToken = default)
    {
        var login = User.Identity?.Name;
        if (string.IsNullOrWhiteSpace(login))
            return Unauthorized();

        try
        {
            var iniciais = await ResolveIniciaisClaimAsync(cancellationToken);
            var result = await _service.AtualizarQuantidadeAutorizadaAsync(
                biStamp,
                request,
                login,
                iniciais,
                cancellationToken);

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
