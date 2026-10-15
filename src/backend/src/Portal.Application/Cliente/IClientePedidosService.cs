namespace Portal.Application.Cliente;

public sealed record ClientePedidoLinhaInput(int LinhaOrd, string Ref, decimal Qtt, string Cor);

public sealed record ClientePedidoCreateResult(
    bool AlreadyExists,
    string Bostamp,
    decimal Obrano,
    decimal Boano,
    decimal Ndos,
    string Nmdos,
    decimal Etotaldeb,
    decimal Totaldeb,
    int Linhas);

public sealed record ClientePedidoListaItem(
    string Bostamp,
    decimal Obrano,
    decimal Boano,
    DateTime DataObra,
    string? Hora,
    string EstadoCodigo,
    string EstadoEtiqueta,
    decimal Etotaldeb,
    bool PodeCancelar);

public sealed record ClientePedidoLinhaDetalhe(
    string Ref,
    string Design,
    string Cor,
    decimal Qtt,
    decimal PrecoUnitario,
    decimal TotalLinha);

public sealed record ClientePedidoDetalhe(
    string Bostamp,
    decimal Obrano,
    decimal Boano,
    DateTime DataObra,
    string? Hora,
    string EstadoCodigo,
    string EstadoEtiqueta,
    decimal Etotaldeb,
    bool PodeCancelar,
    IReadOnlyList<ClientePedidoLinhaDetalhe> Linhas);

public interface IClientePedidosService
{
    Task<ClientePedidoCreateResult> CriarAsync(
        decimal no,
        decimal estab,
        string idempotencyKey,
        IReadOnlyList<ClientePedidoLinhaInput> linhas,
        CancellationToken cancellationToken);

    Task<IReadOnlyList<ClientePedidoListaItem>> ListarAsync(
        decimal no,
        decimal estab,
        int top,
        CancellationToken cancellationToken);

    Task<ClientePedidoDetalhe?> ObterAsync(
        decimal no,
        decimal estab,
        string bostamp,
        CancellationToken cancellationToken);

    Task<(bool Ok, string? Error)> CancelarAsync(
        decimal no,
        decimal estab,
        string bostamp,
        CancellationToken cancellationToken);
}
