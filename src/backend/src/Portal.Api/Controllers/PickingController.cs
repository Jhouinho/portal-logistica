using System.Security.Claims;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using Microsoft.AspNetCore.SignalR;
using Portal.Api.Hubs;
using Portal.Application.Auth;
using Portal.Application.Encomendas;

namespace Portal.Api.Controllers;

/// <summary>
/// Workflow de picking em encomendas PHC (ndos=1). Não afecta dossiers ndos=66.
/// </summary>
[ApiController]
[Authorize]
[Route("api/v1/picking")]
public sealed class PickingController : ControllerBase
{
    private readonly EncomendasService _service;
    private readonly IHubContext<OperacoesHub> _hub;
    private readonly IUserLookup _phcUsers;

    public PickingController(
        EncomendasService service,
        IHubContext<OperacoesHub> hub,
        IUserLookup phcUsers)
    {
        _service = service;
        _hub = hub;
        _phcUsers = phcUsers;
    }

    [HttpPost("{boStamp}/start")]
    public Task<ActionResult<PickWorkflowAtualizadaDto>> Start(
        string boStamp,
        CancellationToken cancellationToken = default)
        => ExecutarAsync(boStamp, _service.PickingStartAsync, cancellationToken);

    [HttpPost("{boStamp}/complete")]
    public Task<ActionResult<PickWorkflowAtualizadaDto>> Complete(
        string boStamp,
        CancellationToken cancellationToken = default)
        => ExecutarAsync(boStamp, _service.PickingCompleteAsync, cancellationToken);

    [HttpPost("{boStamp}/cancel")]
    public async Task<ActionResult<PickWorkflowAtualizadaDto>> Cancel(
        string boStamp,
        [FromBody] CancelPickingRequest? request,
        CancellationToken cancellationToken = default)
    {
        var usercode = await ResolvePhcUsercodeAsync(cancellationToken);
        if (string.IsNullOrWhiteSpace(usercode))
            return Unauthorized();

        try
        {
            var iniciais = await ResolveIniciaisClaimAsync(cancellationToken);
            var result = await _service.PickingCancelAsync(
                boStamp,
                usercode,
                iniciais,
                request?.Motivo,
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

    /// <summary>Voltar a Preparado (Em Curso → Preparado).</summary>
    [HttpPost("{boStamp}/ready")]
    public Task<ActionResult<PickWorkflowAtualizadaDto>> BackToReady(
        string boStamp,
        CancellationToken cancellationToken = default)
        => ExecutarAsync(boStamp, _service.PickingBackToReadyAsync, cancellationToken);

    [HttpPost("{boStamp}/reopen")]
    public Task<ActionResult<PickWorkflowAtualizadaDto>> Reopen(
        string boStamp,
        CancellationToken cancellationToken = default)
        => ExecutarAsync(boStamp, _service.PickingReopenAsync, cancellationToken);

    private async Task<ActionResult<PickWorkflowAtualizadaDto>> ExecutarAsync(
        string boStamp,
        Func<string, string, string?, CancellationToken, Task<PickWorkflowAtualizadaDto>> action,
        CancellationToken cancellationToken)
    {
        var usercode = await ResolvePhcUsercodeAsync(cancellationToken);
        if (string.IsNullOrWhiteSpace(usercode))
            return Unauthorized();

        try
        {
            var iniciais = await ResolveIniciaisClaimAsync(cancellationToken);
            // u_pickrdr / auditoria: usercode PHC (não email Identity).
            var result = await action(boStamp, usercode, iniciais, cancellationToken);

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

    /// <summary>US.usercode — nunca o email Identity.</summary>
    private async Task<string?> ResolvePhcUsercodeAsync(CancellationToken cancellationToken)
    {
        var usercodeClaim = User.FindFirst("usercode")?.Value?.Trim();
        if (!string.IsNullOrWhiteSpace(usercodeClaim) && !usercodeClaim.Contains('@'))
            return usercodeClaim;

        var nameClaims = User.FindAll(ClaimTypes.Name)
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
}
