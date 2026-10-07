using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.SignalR;

namespace Portal.Api.Hubs;

/// <summary>
/// Hub operacional — eventos de encomenda/linhas (Sprint 2 base; produtores nos sprints 3+).
/// </summary>
[Authorize]
public sealed class OperacoesHub : Hub
{
    public const string Path = "/hubs/operacoes";

    public override async Task OnConnectedAsync()
    {
        await Groups.AddToGroupAsync(Context.ConnectionId, "operacoes");
        await base.OnConnectedAsync();
    }
}

/// <summary>Nomes de eventos SignalR (contrato PT).</summary>
public static class OperacoesHubEvents
{
    public const string EncomendaAlterada = "encomendaAlterada";
    public const string LinhaQuantidadePreco = "linhaQuantidadePreco";
    public const string QuantidadeAutorizada = "quantidadeAutorizada";
    public const string StockAlterado = "stockAlterado";

    /// <summary>Invalidação: universo dossiers ndos=66 mudou (sem payload).</summary>
    public const string Dossier66Alterado = "dossier66Alterado";

    /// <summary>Invalidação: universo dossiers ndos=65 mudou (sem payload).</summary>
    public const string Dossier65Alterado = "dossier65Alterado";

    /// <summary>Invalidação: actividade Kapps mudou (sem payload).</summary>
    public const string KappsAlterado = "kappsAlterado";
}
