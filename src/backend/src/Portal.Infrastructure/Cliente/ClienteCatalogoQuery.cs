using Dapper;
using Microsoft.Data.SqlClient;
using Microsoft.Extensions.Logging;
using Microsoft.Extensions.Options;
using Portal.Application.Cliente;
using Portal.Infrastructure.Options;

namespace Portal.Infrastructure.Cliente;

public sealed class ClienteCatalogoQuery : IClienteCatalogoQuery
{
    private static readonly Dictionary<string, string> ContentTypesByExt = new(StringComparer.OrdinalIgnoreCase)
    {
        [".jpg"] = "image/jpeg",
        [".jpeg"] = "image/jpeg",
        [".jpe"] = "image/jpeg",
        [".png"] = "image/png",
        [".gif"] = "image/gif",
        [".bmp"] = "image/bmp",
        [".dib"] = "image/bmp",
        [".webp"] = "image/webp",
    };

    private readonly PhcOptions _phc;
    private readonly PortalClienteOptions _cliente;
    private readonly ILogger<ClienteCatalogoQuery> _log;

    public ClienteCatalogoQuery(
        IOptions<PhcOptions> phc,
        IOptions<PortalClienteOptions> cliente,
        ILogger<ClienteCatalogoQuery> log)
    {
        _phc = phc.Value;
        _cliente = cliente.Value;
        _log = log;
    }

    public async Task<ClienteArtigoDto?> GetArtigoAsync(
        decimal clNo,
        decimal clEstab,
        string referencia,
        CancellationToken cancellationToken)
    {
        var row = await LoadArtigoRowAsync(clNo, clEstab, referencia, cancellationToken);
        if (row is null || row.Inactivo)
            return null;

        var aviso = false;
        if (_cliente.StockBaixoLimiar is { } limiar and > 0)
            aviso = row.Stock <= limiar;

        var temImagem = !string.IsNullOrWhiteSpace(row.ImagemPath) || row.IflCount > 0;
        return new ClienteArtigoDto(row.Ref, row.Design, row.PrecoUnitario, aviso, temImagem);
    }

    public async Task<ClienteArtigoImagemDto?> GetArtigoImagemAsync(
        decimal clNo,
        decimal clEstab,
        string referencia,
        CancellationToken cancellationToken)
    {
        var row = await LoadArtigoRowAsync(clNo, clEstab, referencia, cancellationToken);
        if (row is null || row.Inactivo)
            return null;

        // Preferência: IFL (blob) — documentalmente a fonte “na BD”; depois ST.imagem (caminho).
        if (row.IflCount > 0)
        {
            var fromIfl = await TryLoadFromIflAsync(row.Ststamp, cancellationToken);
            if (fromIfl is not null)
                return fromIfl;
        }

        if (!string.IsNullOrWhiteSpace(row.ImagemPath))
            return TryLoadFromPath(row.ImagemPath);

        return null;
    }

    private async Task<ArtigoRow?> LoadArtigoRowAsync(
        decimal clNo,
        decimal clEstab,
        string referencia,
        CancellationToken cancellationToken)
    {
        referencia = (referencia ?? string.Empty).Trim();
        if (referencia.Length == 0)
            return null;

        await using var conn = new SqlConnection(_phc.ConnectionString);
        return await conn.QuerySingleOrDefaultAsync<ArtigoRow>(new CommandDefinition(
            """
            SELECT
                LTRIM(RTRIM(st.ref)) AS Ref,
                LTRIM(RTRIM(st.design)) AS Design,
                LTRIM(RTRIM(st.ststamp)) AS Ststamp,
                LTRIM(RTRIM(CAST(st.imagem AS nvarchar(500)))) AS ImagemPath,
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
                , 6) AS decimal(18,6)) AS PrecoUnitario,
                (
                    SELECT COUNT_BIG(1)
                    FROM dbo.ifl i WITH (NOLOCK)
                    WHERE i.oritable = 'ST'
                      AND i.recstamp = st.ststamp
                      AND (i.uniqueid = 'imagem' OR i.uniqueid = 'imgqlook')
                      AND i.bdados IS NOT NULL
                      AND DATALENGTH(i.bdados) > 0
                ) AS IflCount
            FROM dbo.st st WITH (NOLOCK)
            INNER JOIN dbo.cl cl WITH (NOLOCK)
                ON cl.no = @clNo AND cl.estab = @clEstab
            WHERE RTRIM(st.ref) = RTRIM(@referencia)
            """,
            new { clNo, clEstab, referencia },
            cancellationToken: cancellationToken));
    }

    private async Task<ClienteArtigoImagemDto?> TryLoadFromIflAsync(
        string ststamp,
        CancellationToken cancellationToken)
    {
        if (string.IsNullOrWhiteSpace(ststamp))
            return null;

        await using var conn = new SqlConnection(_phc.ConnectionString);
        var blob = await conn.QuerySingleOrDefaultAsync<IflRow>(new CommandDefinition(
            """
            SELECT TOP (1)
                i.bdados AS Bdados,
                LTRIM(RTRIM(ISNULL(i.fext, ''))) AS Fext
            FROM dbo.ifl i WITH (NOLOCK)
            WHERE i.oritable = 'ST'
              AND i.recstamp = @ststamp
              AND (i.uniqueid = 'imagem' OR i.uniqueid = 'imgqlook')
              AND i.bdados IS NOT NULL
              AND DATALENGTH(i.bdados) > 0
            ORDER BY
                CASE WHEN i.uniqueid = 'imagem' THEN 0 ELSE 1 END,
                i.iflstamp
            """,
            new { ststamp },
            cancellationToken: cancellationToken));

        if (blob?.Bdados is null || blob.Bdados.Length == 0)
            return null;

        var ext = NormalizeExt(blob.Fext);
        var contentType = ResolveContentType(ext);
        var fileName = string.IsNullOrEmpty(ext) ? "artigo" : $"artigo{ext}";
        return new ClienteArtigoImagemDto(blob.Bdados, contentType, fileName);
    }

    private ClienteArtigoImagemDto? TryLoadFromPath(string rawPath)
    {
        var resolved = ApplyPathRewrite(rawPath.Trim());
        if (!IsPathAllowed(resolved))
        {
            _log.LogWarning("Imagem ST.imagem fora das pastas permitidas: {Path}", MaskPath(resolved));
            return null;
        }

        try
        {
            if (!File.Exists(resolved))
            {
                _log.LogWarning("Ficheiro de imagem inexistente ou inacessível: {Path}", MaskPath(resolved));
                return null;
            }

            var bytes = File.ReadAllBytes(resolved);
            if (bytes.Length == 0)
                return null;

            var ext = Path.GetExtension(resolved);
            return new ClienteArtigoImagemDto(bytes, ResolveContentType(ext), Path.GetFileName(resolved));
        }
        catch (Exception ex) when (ex is IOException or UnauthorizedAccessException or NotSupportedException)
        {
            _log.LogWarning(ex, "Falha a ler imagem em disco: {Path}", MaskPath(resolved));
            return null;
        }
    }

    private string ApplyPathRewrite(string path)
    {
        foreach (var rule in _cliente.ImagensPathRewrite)
        {
            var from = (rule.From ?? "").Trim();
            var to = (rule.To ?? "").Trim();
            if (from.Length == 0 || to.Length == 0)
                continue;
            if (path.StartsWith(from, StringComparison.OrdinalIgnoreCase))
                return to + path[from.Length..];
        }

        return path;
    }

    private bool IsPathAllowed(string path)
    {
        var roots = _cliente.ImagensPastasPermitidas ?? [];
        if (roots.Length == 0)
            return false;

        string full;
        try
        {
            full = Path.GetFullPath(path);
        }
        catch
        {
            return false;
        }

        foreach (var root in roots)
        {
            var r = (root ?? "").Trim();
            if (r.Length == 0)
                continue;

            // Após rewrite, a pasta permitida deve incluir também os destinos de rewrite.
            string rootFull;
            try
            {
                rootFull = Path.GetFullPath(r);
            }
            catch
            {
                continue;
            }

            if (!rootFull.EndsWith(Path.DirectorySeparatorChar) && !rootFull.EndsWith(Path.AltDirectorySeparatorChar))
                rootFull += Path.DirectorySeparatorChar;

            if (full.StartsWith(rootFull, StringComparison.OrdinalIgnoreCase))
                return true;

            // Comparar também contra prefixo UNC “cru” (GetFullPath normaliza).
            var rootNorm = r.TrimEnd('\\', '/') + Path.DirectorySeparatorChar;
            if (full.StartsWith(rootNorm, StringComparison.OrdinalIgnoreCase)
                || path.StartsWith(r.TrimEnd('\\', '/'), StringComparison.OrdinalIgnoreCase))
                return true;
        }

        // Destinos de rewrite também são permitidos implicitamente.
        foreach (var rule in _cliente.ImagensPathRewrite)
        {
            var to = (rule.To ?? "").Trim();
            if (to.Length == 0)
                continue;
            try
            {
                var toFull = Path.GetFullPath(to);
                if (!toFull.EndsWith(Path.DirectorySeparatorChar) && !toFull.EndsWith(Path.AltDirectorySeparatorChar))
                    toFull += Path.DirectorySeparatorChar;
                if (full.StartsWith(toFull, StringComparison.OrdinalIgnoreCase))
                    return true;
            }
            catch
            {
                /* ignore */
            }
        }

        return false;
    }

    private static string NormalizeExt(string? fext)
    {
        var e = (fext ?? "").Trim().TrimStart('.');
        if (e.Length == 0)
            return "";
        return "." + e.ToLowerInvariant();
    }

    private static string ResolveContentType(string? ext)
    {
        var e = NormalizeExt(ext);
        if (e.Length > 0 && ContentTypesByExt.TryGetValue(e, out var ct))
            return ct;
        return "application/octet-stream";
    }

    private static string MaskPath(string path)
    {
        if (string.IsNullOrEmpty(path) || path.Length < 24)
            return path;
        return path[..12] + "…" + path[^8..];
    }

    private sealed class ArtigoRow
    {
        public string Ref { get; init; } = "";
        public string Design { get; init; } = "";
        public string Ststamp { get; init; } = "";
        public string? ImagemPath { get; init; }
        public decimal PrecoUnitario { get; init; }
        public decimal Stock { get; init; }
        public bool Inactivo { get; init; }
        public long IflCount { get; init; }
    }

    private sealed class IflRow
    {
        public byte[]? Bdados { get; init; }
        public string Fext { get; init; } = "";
    }
}
