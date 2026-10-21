namespace Portal.Application.Cliente;

/// <summary>Regras puras de decisão staff sobre pedidos internos (Fase 1).</summary>
public static class StaffPmPedidoRules
{
    public const string EstadoRecebido = "recebido";
    public const string EstadoEmAnalise = "em_analise";
    /// <summary>Claim atómico antes da criação do dossier PHC; bloqueia rejeição e preços.</summary>
    public const string EstadoEmAprovacao = "em_aprovacao";
    public const string EstadoIntegrado = "integrado";
    public const string EstadoRejeitado = "rejeitado";
    public const string EstadoCancelado = "cancelado";

    public static string FormatAprovacaoIdempotencyKey(long pedidoId) =>
        $"HCA-PM-APROV-{pedidoId}";

    public static string NormalizeEstado(string? estadoInterno) =>
        (estadoInterno ?? "").Trim().ToLowerInvariant();

    /// <summary>Pendente de análise: editável e rejeitável (ainda sem claim de aprovação).</summary>
    public static bool IsPendente(string? estadoInterno, string? bostamp)
    {
        if (!string.IsNullOrWhiteSpace(bostamp))
            return false;
        var e = NormalizeEstado(estadoInterno);
        return e is EstadoRecebido or EstadoEmAnalise;
    }

    public static bool IsEmAprovacao(string? estadoInterno) =>
        NormalizeEstado(estadoInterno) == EstadoEmAprovacao;

    /// <summary>Claim feito; dossier ainda não ligado ao pedido — pode (re)chamar a SP.</summary>
    public static bool CanContinueBo67(string? estadoInterno, string? bostamp) =>
        IsEmAprovacao(estadoInterno) && string.IsNullOrWhiteSpace(bostamp);

    public static bool IsIntegradoCompleto(string? estadoInterno, string? bostamp) =>
        NormalizeEstado(estadoInterno) == EstadoIntegrado
        && !string.IsNullOrWhiteSpace(bostamp);

    /// <summary>BO já referenciado no pedido mas estado ainda não é integrado (crash / timeout).</summary>
    public static bool NeedsReconcile(string? estadoInterno, string? bostamp)
    {
        if (string.IsNullOrWhiteSpace(bostamp))
            return false;
        var e = NormalizeEstado(estadoInterno);
        return e is EstadoRecebido or EstadoEmAnalise or EstadoEmAprovacao;
    }

    public static bool IsBlockedFromApprove(string? estadoInterno)
    {
        var e = NormalizeEstado(estadoInterno);
        return e is EstadoRejeitado or EstadoCancelado;
    }

    public static bool CanCreateBo67(string? estadoInterno, string? bostamp) =>
        IsPendente(estadoInterno, bostamp) || CanContinueBo67(estadoInterno, bostamp);

    public static bool CanReject(string? estadoInterno, string? bostamp) =>
        IsPendente(estadoInterno, bostamp);

    public static bool ShowApproveAction(string? estadoInterno, string? bostamp) =>
        CanCreateBo67(estadoInterno, bostamp) || NeedsReconcile(estadoInterno, bostamp);
}
