using Dapper;
using Microsoft.Data.SqlClient;
using Microsoft.Extensions.Options;
using Portal.Application.Realtime;
using Portal.Infrastructure.Options;

namespace Portal.Infrastructure.Realtime;

/// <summary>
/// Leituras TOP 1 dos cursores máximos (BO/BI por ndos + Kapps).
/// Apenas colunas necessárias ao watermark; sem discovery de IDs.
/// </summary>
public sealed class ExternalChangeCursorQuery : IExternalChangeCursorQuery
{
    private readonly PhcOptions _options;

    public ExternalChangeCursorQuery(IOptions<PhcOptions> options)
    {
        _options = options.Value;
    }

    public async Task<BoBiCursor?> GetMaxBoCursorAsync(int ndos, CancellationToken cancellationToken = default)
    {
        await using var connection = new SqlConnection(_options.ConnectionString);
        await connection.OpenAsync(cancellationToken);

        const string sql = """
            SELECT TOP (1)
                bo.usrdata AS UsrData,
                CONVERT(varchar(12), bo.usrhora) AS UsrHora,
                RTRIM(bo.bostamp) AS [Key]
            FROM dbo.bo bo WITH (NOLOCK)
            WHERE bo.ndos = @ndos
            ORDER BY
                bo.usrdata DESC,
                CONVERT(varchar(12), bo.usrhora) DESC,
                bo.bostamp DESC;
            """;

        return await connection.QuerySingleOrDefaultAsync<BoBiCursor>(
            new CommandDefinition(sql, new { ndos }, cancellationToken: cancellationToken));
    }

    public async Task<BoBiCursor?> GetMaxBiCursorAsync(int ndos, CancellationToken cancellationToken = default)
    {
        await using var connection = new SqlConnection(_options.ConnectionString);
        await connection.OpenAsync(cancellationToken);

        // BI não tem ndos: filtrar pela série do cabeçalho BO.
        const string sql = """
            SELECT TOP (1)
                bi.usrdata AS UsrData,
                CONVERT(varchar(12), bi.usrhora) AS UsrHora,
                RTRIM(bi.bistamp) AS [Key]
            FROM dbo.bi bi WITH (NOLOCK)
            INNER JOIN dbo.bo bo WITH (NOLOCK)
                ON bo.bostamp COLLATE DATABASE_DEFAULT = bi.bostamp COLLATE DATABASE_DEFAULT
            WHERE bo.ndos = @ndos
            ORDER BY
                bi.usrdata DESC,
                CONVERT(varchar(12), bi.usrhora) DESC,
                bi.bistamp DESC;
            """;

        return await connection.QuerySingleOrDefaultAsync<BoBiCursor>(
            new CommandDefinition(sql, new { ndos }, cancellationToken: cancellationToken));
    }

    public async Task<KappsCursor?> GetMaxKappsCursorAsync(CancellationToken cancellationToken = default)
    {
        await using var connection = new SqlConnection(_options.ConnectionString);
        await connection.OpenAsync(cancellationToken);

        // Quarteto único em UAT (54/54); MovDate/MovTime nvarchar ordenáveis ordinalmente (yyyyMMdd / HHmmss).
        const string sql = """
            SELECT TOP (1)
                LTRIM(RTRIM(ISNULL(d.MovDate, ''))) AS MovDate,
                LTRIM(RTRIM(ISNULL(d.MovTime, ''))) AS MovTime,
                LTRIM(RTRIM(ISNULL(d.StampBo, ''))) AS StampBo,
                LTRIM(RTRIM(ISNULL(d.StampBi, ''))) AS StampBi
            FROM dbo.u_Kapps_DossierLin d WITH (NOLOCK)
            ORDER BY
                LTRIM(RTRIM(ISNULL(d.MovDate, ''))) DESC,
                LTRIM(RTRIM(ISNULL(d.MovTime, ''))) DESC,
                LTRIM(RTRIM(ISNULL(d.StampBo, ''))) DESC,
                LTRIM(RTRIM(ISNULL(d.StampBi, ''))) DESC;
            """;

        var row = await connection.QuerySingleOrDefaultAsync<KappsCursor>(
            new CommandDefinition(sql, cancellationToken: cancellationToken));

        if (row is null)
            return null;

        // Tabela vazia vs linha “toda vazia”: tratar quarteto vazio como ausência.
        if (string.IsNullOrEmpty(row.NormalizedMovDate)
            && string.IsNullOrEmpty(row.NormalizedMovTime)
            && string.IsNullOrEmpty(row.NormalizedStampBo)
            && string.IsNullOrEmpty(row.NormalizedStampBi))
            return null;

        return row;
    }
}
