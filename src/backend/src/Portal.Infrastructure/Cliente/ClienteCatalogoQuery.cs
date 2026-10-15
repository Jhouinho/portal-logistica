using Dapper;
using Microsoft.Data.SqlClient;
using Microsoft.Extensions.Options;
using Portal.Application.Cliente;
using Portal.Infrastructure.Options;

namespace Portal.Infrastructure.Cliente;

public sealed class ClienteCatalogoQuery : IClienteCatalogoQuery
{
    private readonly PhcOptions _phc;
    private readonly PortalClienteOptions _cliente;

    public ClienteCatalogoQuery(IOptions<PhcOptions> phc, IOptions<PortalClienteOptions> cliente)
    {
        _phc = phc.Value;
        _cliente = cliente.Value;
    }

    public async Task<ClienteArtigoDto?> GetArtigoAsync(
        decimal clNo,
        decimal clEstab,
        string referencia,
        CancellationToken cancellationToken)
    {
        referencia = (referencia ?? string.Empty).Trim();
        if (referencia.Length == 0)
            return null;

        await using var conn = new SqlConnection(_phc.ConnectionString);
        var row = await conn.QuerySingleOrDefaultAsync<ArtigoRow>(new CommandDefinition(
            """
            SELECT
                LTRIM(RTRIM(st.ref)) AS Ref,
                LTRIM(RTRIM(st.design)) AS Design,
                CAST(ISNULL(cl.preco, 1) AS int) AS PrecoTabela,
                CAST(ISNULL(st.stock, 0) AS decimal(18,4)) AS Stock,
                CAST(ISNULL(st.inactivo, 0) AS bit) AS Inactivo,
                CAST(ROUND(
                    CASE ISNULL(cl.preco, 1)
                        WHEN 1 THEN st.epv1
                        WHEN 2 THEN st.epv2
                        WHEN 3 THEN st.epv3
                        WHEN 4 THEN st.epv4
                        WHEN 5 THEN st.epv5
                        ELSE st.epv1
                    END
                , 6) AS decimal(18,6)) AS PrecoUnitario
            FROM dbo.st st WITH (NOLOCK)
            INNER JOIN dbo.cl cl WITH (NOLOCK)
                ON cl.no = @clNo AND cl.estab = @clEstab
            WHERE RTRIM(st.ref) = RTRIM(@referencia)
            """,
            new { clNo, clEstab, referencia },
            cancellationToken: cancellationToken));

        if (row is null || row.Inactivo)
            return null;

        var aviso = false;
        if (_cliente.StockBaixoLimiar is { } limiar and > 0)
            aviso = row.Stock <= limiar;

        return new ClienteArtigoDto(row.Ref, row.Design, row.PrecoUnitario, aviso);
    }

    private sealed class ArtigoRow
    {
        public string Ref { get; init; } = "";
        public string Design { get; init; } = "";
        public decimal PrecoUnitario { get; init; }
        public decimal Stock { get; init; }
        public bool Inactivo { get; init; }
    }
}
