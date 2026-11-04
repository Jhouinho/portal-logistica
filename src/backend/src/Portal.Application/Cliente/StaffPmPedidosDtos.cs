namespace Portal.Application.Cliente;

public sealed record StaffPmPedidoListaItemDto(
    long PedidoId,
    string NumeroInterno,
    decimal ClNo,
    decimal ClEstab,
    string ClienteNome,
    string EstadoInterno,
    string EstadoCodigo,
    string EstadoEtiqueta,
    DateTime DataSubmissao,
    decimal Etotaldeb,
    string? Bostamp,
    decimal? Obrano,
    decimal? Ndos,
    bool PodeAprovar,
    bool PodeRejeitar,
    bool PodeMarcarProntoLevantamento,
    bool PodeMarcarConcluido);

public sealed record StaffPmPedidoLinhaDto(
    int LinhaOrd,
    string Ref,
    string Design,
    string Cor,
    decimal Qtt,
    decimal PrecoSubmissao,
    decimal PrecoUnitario,
    decimal TotalLinha);

public sealed record StaffPmPedidoDetalheDto(
    long PedidoId,
    string NumeroInterno,
    decimal ClNo,
    decimal ClEstab,
    string ClienteNome,
    string EstadoInterno,
    string EstadoCodigo,
    string EstadoEtiqueta,
    DateTime DataSubmissao,
    DateTime DataAlteracao,
    decimal Etotaldeb,
    string? Bostamp,
    decimal? Obrano,
    decimal? Boano,
    decimal? Ndos,
    string? MotivoRejeicao,
    string? DecididoPor,
    DateTime? DataDecisao,
    bool PodeAprovar,
    bool PodeRejeitar,
    bool PodeEditarPrecos,
    bool PodeMarcarProntoLevantamento,
    bool PodeMarcarConcluido,
    IReadOnlyList<StaffPmPedidoLinhaDto> Linhas);

public sealed record StaffPmPrecoLinhaRequest(int LinhaOrd, decimal PrecoUnitario);

public sealed record StaffPmGuardarPrecosRequest(IReadOnlyList<StaffPmPrecoLinhaRequest> Linhas);

/// <summary>
/// Linha editável pelo operador antes da aprovação.
/// <see cref="LinhaOrd"/> = ordem original (preserva PrecoSubmissao); null = linha nova.
/// </summary>
public sealed record StaffPmLinhaEditRequest(
    int? LinhaOrd,
    string Ref,
    string Design,
    string Cor,
    decimal Qtt,
    decimal PrecoUnitario);

public sealed record StaffPmGuardarLinhasRequest(IReadOnlyList<StaffPmLinhaEditRequest> Linhas);

public sealed record StaffPmAprovarResultDto(
    long PedidoId,
    string NumeroInterno,
    string EstadoInterno,
    string EstadoCodigo,
    string EstadoEtiqueta,
    string Bostamp,
    decimal Obrano,
    decimal Boano,
    decimal Ndos,
    bool AlreadyIntegrated,
    bool AlreadyExistsBo);

public sealed record StaffPmRejeitarResultDto(
    long PedidoId,
    string NumeroInterno,
    string EstadoInterno,
    string EstadoCodigo,
    string EstadoEtiqueta,
    string? MotivoRejeicao);

public sealed record StaffPmRejeitarRequest(string? Motivo);

/// <summary>Legado — endpoint operacao desactivado (circuito balcão).</summary>
public sealed record StaffPmOperacaoRequest(string? Acao);

public sealed record StaffPmOperacaoResultDto(
    long PedidoId,
    string NumeroInterno,
    string EstadoInterno,
    string EstadoCodigo,
    string EstadoEtiqueta);

public interface IStaffPmPedidosService
{
    Task<IReadOnlyList<StaffPmPedidoListaItemDto>> ListarAsync(
        string? filtroEstado,
        int top,
        CancellationToken cancellationToken);

    Task<StaffPmPedidoDetalheDto?> ObterAsync(long pedidoId, CancellationToken cancellationToken);

    Task<StaffPmAprovarResultDto> AprovarAsync(
        long pedidoId,
        string usrinis,
        string? decididoPor,
        CancellationToken cancellationToken);

    Task<StaffPmRejeitarResultDto> RejeitarAsync(
        long pedidoId,
        string? motivo,
        string? decididoPor,
        CancellationToken cancellationToken);

    Task<StaffPmPedidoDetalheDto> GuardarPrecosAsync(
        long pedidoId,
        IReadOnlyList<StaffPmPrecoLinhaRequest> linhas,
        CancellationToken cancellationToken);

    /// <summary>
    /// Substitui o conjunto de linhas (qtt/preço/adicionar/eliminar) enquanto pendente.
    /// </summary>
    Task<StaffPmPedidoDetalheDto> GuardarLinhasAsync(
        long pedidoId,
        IReadOnlyList<StaffPmLinhaEditRequest> linhas,
        CancellationToken cancellationToken);

    Task<StaffPmOperacaoResultDto> AvancarOperacaoAsync(
        long pedidoId,
        string? acao,
        string? decididoPor,
        CancellationToken cancellationToken);
}
