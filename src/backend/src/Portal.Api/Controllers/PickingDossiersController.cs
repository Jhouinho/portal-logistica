using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using Microsoft.AspNetCore.SignalR;
using Portal.Api.Hubs;
using Portal.Application.Auth;
using Portal.Application.Encomendas;

namespace Portal.Api.Controllers;

[ApiController]
[Authorize]
[Route("api/v1/picking-dossiers")]
public sealed class PickingDossiersController : ControllerBase
{
    private readonly PickingDossiersService _service;
    private readonly KappsPickingService _kappsPicking;
    private readonly IHubContext<OperacoesHub> _hub;
    private readonly IUserLookup _phcUsers;

    public PickingDossiersController(
        PickingDossiersService service,
        KappsPickingService kappsPicking,
        IHubContext<OperacoesHub> hub,
        IUserLookup phcUsers)
    {
        _service = service;
        _kappsPicking = kappsPicking;
        _hub = hub;
        _phcUsers = phcUsers;
    }

    /// <summary>Lista dossiers ndos=66 — leitura também pela Vista TV (sem login).</summary>
    [AllowAnonymous]
    [HttpGet]
    public async Task<ActionResult<EncomendaListaResponseDto>> Listar(
        [FromQuery] bool fechada = false,
        [FromQuery] string? dataDe = null,
        [FromQuery] string? dataAte = null,
        [FromQuery] string? horaDe = null,
        [FromQuery] string? horaAte = null,
        [FromQuery] int? clienteNo = null,
        [FromQuery] string? clienteNoContem = null,
        [FromQuery] string? clienteNomeContem = null,
        [FromQuery] string? artigoRef = null,
        [FromQuery] string? artigoCor = null,
        [FromQuery] string? estadoPlaneamento = null,
        [FromQuery] string? metodoExpedicao = null,
        [FromQuery] int? pickStatus = null,
        [FromQuery] bool? checkIn = null,
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
            ClienteNomeContem = clienteNomeContem,
            ArtigoRef = artigoRef,
            ArtigoCor = artigoCor,
            EstadoPlaneamento = estadoPlaneamento,
            MetodoExpedicao = metodoExpedicao,
            PickStatus = pickStatus,
            CheckIn = checkIn,
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

    /// <summary>
    /// Picking Kapps associado ao dossier ndos=66 (PickingKey = bostamp do dossier).
    /// 404 se o dossier não existir; 204 se existir sem picking Kapps visível.
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
        var result = await _kappsPicking.ObterPorDossierAsync(boStamp, cancellationToken);

        if (!result.Existe)
            return NotFound(new ProblemDetails
            {
                Title = "Não encontrado",
                Detail = "Dossier de picking não encontrado ou fora da série configurada (ndos 66).",
                Status = StatusCodes.Status404NotFound
            });

        if (result.Detalhe is null)
            return NoContent();

        return Ok(result.Detalhe);
    }

    /// <summary>
    /// Check-in em lote: marca BO3.u_chkin=1 nos dossiers ndos=66 abertos seleccionados.
    /// Idempotente por dossier (já com check-in → 409 no item, sem sobrescrever ur/dt).
    /// </summary>
    [HttpPost("check-in")]
    public async Task<ActionResult<CheckInLoteResponseDto>> MarcarCheckIn(
        [FromBody] MarcarCheckInRequest request,
        CancellationToken cancellationToken = default)
    {
        var usercode = await ResolvePhcUsercodeAsync(cancellationToken);
        if (string.IsNullOrWhiteSpace(usercode))
            return Unauthorized();

        try
        {
            var iniciais = await ResolveIniciaisClaimAsync(cancellationToken);
            var result = await _service.MarcarCheckInLoteAsync(
                request,
                usercode,
                iniciais,
                cancellationToken);

            foreach (var item in result.Resultados.Where(r => r.Ok && r.Resultado is not null))
            {
                await _hub.Clients.Group("operacoes").SendAsync(
                    OperacoesHubEvents.EncomendaAlterada,
                    item.Resultado,
                    cancellationToken);
            }

            return Ok(result);
        }
        catch (PortalBusinessException ex)
        {
            return StatusCode(ex.StatusCode, new ProblemDetails
            {
                Title = ex.StatusCode switch
                {
                    401 => "Não autenticado",
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
    /// Reverte Check-in: BO3.u_chkin=0 num dossier ndos=66 aberto com check-in activo.
    /// </summary>
    [HttpPost("{boStamp}/reverter-check-in")]
    public async Task<ActionResult<CheckInAtualizadaDto>> ReverterCheckIn(
        string boStamp,
        CancellationToken cancellationToken = default)
    {
        var usercode = await ResolvePhcUsercodeAsync(cancellationToken);
        if (string.IsNullOrWhiteSpace(usercode))
            return Unauthorized();

        try
        {
            var iniciais = await ResolveIniciaisClaimAsync(cancellationToken);
            var result = await _service.ReverterCheckInAsync(
                boStamp,
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
                    401 => "Não autenticado",
                    404 => "Não encontrado",
                    409 => "Conflito",
                    _ => "Pedido inválido"
                },
                Detail = ex.Message,
                Status = ex.StatusCode
            });
        }
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
}
