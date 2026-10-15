namespace Portal.Application.Cliente;

public sealed record ClienteCorItem(string Codigo, string Nome);

public sealed record ClienteArtigoDto(
    string Ref,
    string Design,
    decimal PrecoUnitario,
    bool AvisoStockBaixo,
    IReadOnlyList<ClienteCorItem> Cores);

public interface IClienteCatalogoQuery
{
    Task<ClienteArtigoDto?> GetArtigoAsync(
        decimal clNo,
        decimal clEstab,
        string referencia,
        CancellationToken cancellationToken);

    Task<IReadOnlyList<ClienteCorItem>> ListarCoresAsync(CancellationToken cancellationToken);
}
