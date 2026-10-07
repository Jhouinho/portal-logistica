using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.SignalR;

namespace Portal.Api.Hubs;

/// <summary>
/// Hub público read-only para a Vista TV (/tv). Sem autenticação.
/// Apenas recebe invalidação; não expõe métodos de negócio invocáveis pelo cliente.
/// </summary>
[AllowAnonymous]
public sealed class TvHub : Hub
{
    public const string Path = "/hubs/tv";
    public const string GroupName = "tv";

    public override async Task OnConnectedAsync()
    {
        await Groups.AddToGroupAsync(Context.ConnectionId, GroupName);
        await base.OnConnectedAsync();
    }
}

/// <summary>Eventos de invalidação TV (mesmos nomes que o Portal operacional).</summary>
public static class TvHubEvents
{
    public const string Dossier66Alterado = "dossier66Alterado";
    public const string Dossier65Alterado = "dossier65Alterado";
    public const string KappsAlterado = "kappsAlterado";
}
