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
    bool PodeRejeitar);

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
    IReadOnlyList<StaffPmPedidoLinhaDto> Linhas);

public sealed record StaffPmPrecoLinhaRequest(int LinhaOrd, decimal PrecoUnitario);

public sealed record StaffPmGuardarPrecosRequest(IReadOnlyList<StaffPmPrecoLinhaRequest> Linhas);

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
}
