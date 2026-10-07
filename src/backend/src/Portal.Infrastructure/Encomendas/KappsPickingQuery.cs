using Dapper;
using Microsoft.Data.SqlClient;
using Microsoft.Extensions.Options;
using Portal.Application.Encomendas;
using Portal.Infrastructure.Options;

namespace Portal.Infrastructure.Encomendas;

public sealed class KappsPickingQuery : IKappsPickingQuery
{
    private readonly PhcOptions _options;

    public KappsPickingQuery(IOptions<PhcOptions> options)
    {
        _options = options.Value;
    }

    public async Task<bool> ExisteBoNaSerieAsync(
        string boStamp,
        int ndos,
        CancellationToken cancellationToken = default)
    {
        if (string.IsNullOrWhiteSpace(boStamp))
            return false;

        await using var connection = new SqlConnection(_options.ConnectionString);
        await connection.OpenAsync(cancellationToken);

        const string sql = """
            SELECT TOP (1) 1
            FROM dbo.bo WITH (NOLOCK)
            WHERE bostamp COLLATE DATABASE_DEFAULT = @boStamp COLLATE DATABASE_DEFAULT
              AND ndos = @ndos;
            """;

        var found = await connection.ExecuteScalarAsync<int?>(
            new CommandDefinition(
                sql,
                new { boStamp = boStamp.Trim(), ndos },
                cancellationToken: cancellationToken));

        return found is 1;
    }

    public async Task<string?> ResolverPickingKeyAsync(
        string boStampEncomenda,
        int serieEncomendas,
        int seriePicking,
        CancellationToken cancellationToken = default)
    {
        _ = serieEncomendas;
        if (string.IsNullOrWhiteSpace(boStampEncomenda))
            return null;

        var stamp = boStampEncomenda.Trim();

        await using var connection = new SqlConnection(_options.ConnectionString);
        await connection.OpenAsync(cancellationToken);

        // Preferir a chave Kapps com mais progresso: encomenda (ndos=1) ou dossier 66 ligado por obistamp.
        const string sql = """
            ;WITH keys AS (
                SELECT CAST(@stamp AS varchar(25)) AS PickingKey, 0 AS prio
                UNION ALL
                SELECT DISTINCT bo66.bostamp, 1
                FROM dbo.bo bo66 WITH (NOLOCK)
                INNER JOIN dbo.bi di WITH (NOLOCK)
                    ON di.bostamp COLLATE DATABASE_DEFAULT = bo66.bostamp COLLATE DATABASE_DEFAULT
                INNER JOIN dbo.bi oi WITH (NOLOCK)
                    ON oi.bistamp COLLATE DATABASE_DEFAULT = di.obistamp COLLATE DATABASE_DEFAULT
                WHERE bo66.ndos = @seriePicking
                  AND oi.bostamp COLLATE DATABASE_DEFAULT = @stamp COLLATE DATABASE_DEFAULT
            )
            SELECT TOP (1) k.PickingKey
            FROM keys k
            INNER JOIN dbo.v_Kapps_Picking_Lines l WITH (NOLOCK)
                ON l.PickingKey COLLATE DATABASE_DEFAULT = k.PickingKey COLLATE DATABASE_DEFAULT
            GROUP BY k.PickingKey, k.prio
            ORDER BY
                CASE
                    WHEN SUM(ISNULL(l.Quantity, 0)) > 0
                     AND SUM(ISNULL(l.QuantityPicked, 0)) >= SUM(ISNULL(l.Quantity, 0))
                    THEN 0 ELSE 1
                END,
                SUM(ISNULL(l.QuantityPicked, 0)) DESC,
                k.prio ASC;
            """;

        var key = await connection.ExecuteScalarAsync<string?>(
            new CommandDefinition(
                sql,
                new { stamp, seriePicking },
                cancellationToken: cancellationToken));

        return string.IsNullOrWhiteSpace(key) ? stamp : key.Trim();
    }

    public async Task<KappsPickingDetalheDto?> ObterDocumentoComLinhasAsync(
        string pickingKey,
        CancellationToken cancellationToken = default)
    {
        await using var connection = new SqlConnection(_options.ConnectionString);
        await connection.OpenAsync(cancellationToken);

        const string docSql = """
            SELECT
                PickingKey,
                Number,
                CustomerName,
                Date,
                Customer,
                Document,
                DocumentName,
                EXR,
                SEC,
                TPD,
                NDC,
                DeliveryCustomer,
                DeliveryCode,
                Barcode,
                AllowNewProduct,
                UseSDR
            FROM dbo.v_Kapps_Picking_Documents
            WHERE PickingKey COLLATE DATABASE_DEFAULT = @pickingKey COLLATE DATABASE_DEFAULT;
            """;

        var doc = await connection.QuerySingleOrDefaultAsync<DocRow>(
            new CommandDefinition(docSql, new { pickingKey }, cancellationToken: cancellationToken));

        const string linhasSql = """
            SELECT
                k.PickingLineKey,
                k.Article,
                k.Description,
                k.Quantity,
                ISNULL(NULLIF(bi2.u_qttorig, 0), ISNULL(bi.qtt, k.Quantity)) AS QuantityOriginal,
                k.QuantitySatisfied,
                k.QuantityPending,
                k.QuantityPicked,
                k.BaseUnit,
                k.BusyUnit,
                k.ConversionFator,
                k.Warehouse,
                k.PickingKey,
                k.OriginalLineNumber,
                k.Location,
                k.Lot,
                k.AllowReplacement,
                k.LinObs,
                k.HasReservedQty
            FROM dbo.v_Kapps_Picking_Lines k
            LEFT JOIN dbo.bi bi WITH (NOLOCK)
                ON bi.bistamp COLLATE DATABASE_DEFAULT = k.PickingLineKey COLLATE DATABASE_DEFAULT
            LEFT JOIN dbo.bi2 bi2 WITH (NOLOCK)
                ON bi2.bi2stamp COLLATE DATABASE_DEFAULT = bi.bistamp COLLATE DATABASE_DEFAULT
            WHERE k.PickingKey COLLATE DATABASE_DEFAULT = @pickingKey COLLATE DATABASE_DEFAULT
            ORDER BY k.OriginalLineNumber, k.PickingLineKey;
            """;

        var linhas = (await connection.QueryAsync<LinhaRow>(
            new CommandDefinition(linhasSql, new { pickingKey }, cancellationToken: cancellationToken))).ToList();

        // Sem documento nem linhas nas views Kapps → ainda sem picking.
        if (doc is null && linhas.Count == 0)
            return null;

        var actividade = await connection.QuerySingleOrDefaultAsync<ActividadeRow>(
            new CommandDefinition(
                """
                SELECT TOP (1)
                    d.TerminalID,
                    LTRIM(RTRIM(d.UserID)) AS UserID,
                    LTRIM(RTRIM(t.TerminalDescription)) AS TerminalDescription
                FROM dbo.u_Kapps_DossierLin d WITH (NOLOCK)
                LEFT JOIN dbo.u_Kapps_Terminals t WITH (NOLOCK)
                    ON LTRIM(RTRIM(t.TerminalID)) = CONVERT(varchar(20), d.TerminalID)
                WHERE d.StampBo COLLATE DATABASE_DEFAULT = @pickingKey COLLATE DATABASE_DEFAULT
                  AND (
                    ISNULL(d.TerminalID, 0) <> 0
                    OR LTRIM(RTRIM(ISNULL(d.UserID, ''))) <> ''
                  )
                ORDER BY
                    CASE WHEN ISNULL(d.TerminalID, 0) <> 0 THEN 0 ELSE 1 END,
                    d.MovDate DESC,
                    d.MovTime DESC;
                """,
                new { pickingKey },
                cancellationToken: cancellationToken));

        int? terminalId = actividade is { TerminalID: > 0 } ? actividade.TerminalID : null;
        string? terminalLabel = null;
        if (terminalId is int tid)
        {
            var desc = actividade?.TerminalDescription?.Trim();
            terminalLabel = string.IsNullOrWhiteSpace(desc) ? $"Terminal {tid}" : desc;
        }

        var activeUser = string.IsNullOrWhiteSpace(actividade?.UserID)
            ? null
            : actividade!.UserID.Trim();

        return new KappsPickingDetalheDto(
            (doc?.PickingKey ?? pickingKey).Trim(),
            doc?.Number ?? 0,
            doc?.CustomerName?.Trim() ?? string.Empty,
            doc?.Date,
            doc?.Customer?.Trim() ?? string.Empty,
            FormatDocument(doc?.Document),
            doc?.DocumentName?.Trim() ?? string.Empty,
            doc?.EXR?.Trim(),
            doc?.SEC?.Trim(),
            doc?.TPD?.Trim(),
            doc?.NDC,
            doc?.DeliveryCustomer?.Trim(),
            doc?.DeliveryCode?.Trim(),
            doc?.Barcode?.Trim(),
            doc?.AllowNewProduct ?? 0,
            doc?.UseSDR ?? 0,
            terminalId,
            terminalLabel,
            activeUser,
            linhas.Select(MapLinha).ToList());
    }

    private static string FormatDocument(object? document)
    {
        if (document is null)
            return string.Empty;
        return Convert.ToString(document)?.Trim() ?? string.Empty;
    }

    private static KappsPickingLinhaDto MapLinha(LinhaRow r) =>
        new(
            r.PickingLineKey?.Trim() ?? string.Empty,
            r.Article?.Trim() ?? string.Empty,
            r.Description?.Trim() ?? string.Empty,
            r.Quantity,
            r.QuantityOriginal,
            r.QuantitySatisfied,
            r.QuantityPending,
            r.QuantityPicked,
            r.BaseUnit?.Trim() ?? string.Empty,
            r.BusyUnit?.Trim() ?? string.Empty,
            r.ConversionFator,
            r.Warehouse,
            r.PickingKey?.Trim() ?? string.Empty,
            r.OriginalLineNumber,
            string.IsNullOrWhiteSpace(r.Location) ? null : r.Location.Trim(),
            string.IsNullOrWhiteSpace(r.Lot) ? null : r.Lot.Trim(),
            r.AllowReplacement,
            string.IsNullOrWhiteSpace(r.LinObs) ? null : r.LinObs.Trim(),
            r.HasReservedQty);

    private sealed class DocRow
    {
        public string? PickingKey { get; init; }
        public decimal Number { get; init; }
        public string? CustomerName { get; init; }
        public DateTime? Date { get; init; }
        public string? Customer { get; init; }
        public object? Document { get; init; }
        public string? DocumentName { get; init; }
        public string? EXR { get; init; }
        public string? SEC { get; init; }
        public string? TPD { get; init; }
        public decimal? NDC { get; init; }
        public string? DeliveryCustomer { get; init; }
        public string? DeliveryCode { get; init; }
        public string? Barcode { get; init; }
        public int AllowNewProduct { get; init; }
        public int UseSDR { get; init; }
    }

    private sealed class ActividadeRow
    {
        public int TerminalID { get; init; }
        public string? UserID { get; init; }
        public string? TerminalDescription { get; init; }
    }

    private sealed class LinhaRow
    {
        public string? PickingLineKey { get; init; }
        public string? Article { get; init; }
        public string? Description { get; init; }
        public decimal Quantity { get; init; }
        public decimal QuantityOriginal { get; init; }
        public decimal QuantitySatisfied { get; init; }
        public decimal QuantityPending { get; init; }
        public decimal QuantityPicked { get; init; }
        public string? BaseUnit { get; init; }
        public string? BusyUnit { get; init; }
        public int ConversionFator { get; init; }
        public decimal Warehouse { get; init; }
        public string? PickingKey { get; init; }
        public decimal OriginalLineNumber { get; init; }
        public string? Location { get; init; }
        public string? Lot { get; init; }
        public int AllowReplacement { get; init; }
        public string? LinObs { get; init; }
        public int HasReservedQty { get; init; }
    }
}
