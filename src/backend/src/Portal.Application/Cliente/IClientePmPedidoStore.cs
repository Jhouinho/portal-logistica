namespace Portal.Application.Cliente;

public sealed record ClientePmLinhaPersistida(
    int LinhaOrd,
    string Ref,
    string Design,
    string Cor,
    decimal Qtt,
    decimal PrecoUnitario,
    decimal TotalLinha);

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
    IReadOnlyList<ClientePmLinhaPersistida>? Linhas);

public sealed record ClientePmCreateOutcome(
    bool AlreadyExists,
    ClientePmPedidoPersistido Pedido);

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
}
