namespace Portal.Application.Cliente;

public sealed record ClientePmLinhaPersistida(
    int LinhaOrd,
    string Ref,
    string Design,
    string Cor,
    decimal Qtt,
    decimal PrecoUnitario,
    decimal TotalLinha,
    /// <summary>Preço calculado na submissão (imutável). Null só em linhas pré-099 sem backfill.</summary>
    decimal? PrecoSubmissao = null);

public sealed record ClientePmPedidoPersistido(
    long PedidoId,
    string NumeroInterno,
    decimal ClNo,
    decimal ClEstab,
    string EstadoInterno,
    DateTime DataSubmissao,
    DateTime DataAlteracao,
    decimal Etotaldeb,
    string SubmissaoPayloadHash,
    IReadOnlyList<ClientePmLinhaPersistida>? Linhas,
    string? Bostamp = null,
    decimal? Obrano = null,
    decimal? Boano = null,
    decimal? Ndos = null,
    string? MotivoRejeicao = null,
    string? DecididoPor = null,
    DateTime? DataDecisao = null,
    string? ClienteNome = null);

public sealed record ClientePmCreateOutcome(
    bool AlreadyExists,
    ClientePmPedidoPersistido Pedido);

public sealed record ClientePmIntegracaoResult(
    bool Updated,
    ClientePmPedidoPersistido? Pedido);

/// <summary>Persistência de pedidos Mobile internos (Fase 1).</summary>
public interface IClientePmPedidoStore
{
    Task<ClientePmCreateOutcome> CriarAsync(
        decimal clNo,
        decimal clEstab,
        string idempotencyKey,
        string payloadHash,
        IReadOnlyList<ClientePmLinhaPersistida> linhas,
        CancellationToken cancellationToken);

    Task<IReadOnlyList<ClientePmPedidoPersistido>> ListarAsync(
        decimal clNo,
        decimal clEstab,
        int top,
        CancellationToken cancellationToken);

    Task<ClientePmPedidoPersistido?> ObterPorIdAsync(
        decimal clNo,
        decimal clEstab,
        long pedidoId,
        CancellationToken cancellationToken);

    Task<ClientePmPedidoPersistido?> ObterPorNumeroAsync(
        decimal clNo,
        decimal clEstab,
        string numeroInterno,
        CancellationToken cancellationToken);

    /// <summary>
    /// Lista staff (sem filtro de cliente).
    /// filtroEstado: pendentes|integrados|em_separacao|pronto_levantamento|concluidos|rejeitados|todos.
    /// </summary>
    Task<IReadOnlyList<ClientePmPedidoPersistido>> ListarStaffAsync(
        string? filtroEstado,
        int top,
        CancellationToken cancellationToken);

    Task<ClientePmPedidoPersistido?> ObterPorIdStaffAsync(
        long pedidoId,
        bool incluirLinhas,
        CancellationToken cancellationToken);

    /// <summary>
    /// Claim atómico: recebido/em_analise → em_aprovacao (sem Bostamp).
    /// Impede rejeição e edição de preços concurrentes com a aprovação.
    /// </summary>
    Task<ClientePmIntegracaoResult> TryClaimAprovacaoAsync(
        long pedidoId,
        CancellationToken cancellationToken);

    /// <summary>
    /// Marca em_separacao + ligação PHC a partir de pendente, em_aprovacao ou reconciliação.
    /// </summary>
    Task<ClientePmIntegracaoResult> TryMarcarIntegradoAsync(
        long pedidoId,
        string bostamp,
        decimal obrano,
        decimal boano,
        decimal ndos,
        string? decididoPor,
        CancellationToken cancellationToken);

    /// <summary>
    /// Avanço operacional pós-PHC: em_separacao/integrado → pronto_levantamento → concluido.
    /// </summary>
    Task<ClientePmIntegracaoResult> TryAvancarEstadoOperacionalAsync(
        long pedidoId,
        string estadoDestino,
        string? decididoPor,
        CancellationToken cancellationToken);

    Task<ClientePmIntegracaoResult> TryRejeitarAsync(
        long pedidoId,
        string? motivo,
        string? decididoPor,
        CancellationToken cancellationToken);

    /// <summary>
    /// Actualiza PrecoUnitario/TotalLinha e Etotaldeb apenas se o pedido estiver pendente
    /// (recebido/em_analise, sem Bostamp). Não altera PrecoSubmissao.
    /// </summary>
    Task<ClientePmIntegracaoResult> TryAtualizarPrecosOperadorAsync(
        long pedidoId,
        IReadOnlyList<(int LinhaOrd, decimal PrecoUnitario)> precos,
        CancellationToken cancellationToken);

    /// <summary>
    /// Actualiza/insere/remove linhas (qtt/preço/add/remove) se pendente sem Bostamp.
    /// Preserva PrecoSubmissao quando <see cref="StaffPmLinhaEditRequest.LinhaOrd"/> aponta
    /// para uma linha existente. Remoções usam DELETE (requer GRANT — script 105).
    /// </summary>
    Task<ClientePmIntegracaoResult> TrySubstituirLinhasOperadorAsync(
        long pedidoId,
        IReadOnlyList<StaffPmLinhaEditRequest> linhas,
        CancellationToken cancellationToken);
}
