namespace Portal.Application.Cliente;

/// <summary>Cor livre do Portal Mobile — persiste em BI.u_cor (varchar(100)).</summary>
public static class ClienteCorLimits
{
    public const int MaxLength = 100;

    /// <summary>Trim; vazio permitido; trunca a MaxLength (sem whitelist).</summary>
    public static string Normalize(string? raw)
    {
        var s = (raw ?? string.Empty).Trim();
        if (s.Length > MaxLength)
            s = s[..MaxLength];
        return s;
    }
}

public sealed record ClienteArtigoDto(
    string Ref,
    string Design,
    decimal PrecoUnitario,
    bool AvisoStockBaixo);

public interface IClienteCatalogoQuery
{
    Task<ClienteArtigoDto?> GetArtigoAsync(
        decimal clNo,
        decimal clEstab,
        string referencia,
        CancellationToken cancellationToken);
}
