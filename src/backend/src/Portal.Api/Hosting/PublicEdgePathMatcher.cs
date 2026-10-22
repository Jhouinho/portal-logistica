using System.Diagnostics.CodeAnalysis;

namespace Portal.Api.Hosting;

/// <summary>
/// Decisão pura (sem HTTP/DI) para a allowlist do hostname público.
/// Não confia em X-Forwarded-Host — o chamador deve passar o host já resolvido
/// (tipicamente <c>Request.Host.Host</c> após ForwardedHeaders sem Host forwarding).
/// </summary>
public static class PublicEdgePathMatcher
{
    public readonly record struct EvaluateResult(bool IsPublicHost, bool Allowed, string Reason);

    /// <summary>
    /// Com <paramref name="enabled"/> true, exige pelo menos um hostname válido em
    /// <paramref name="publicHosts"/>. Usar no Passo B no arranque da aplicação.
    /// </summary>
    public static bool TryValidateWhenEnabled(
        bool enabled,
        IEnumerable<string?>? publicHosts,
        [NotNullWhen(false)] out string? error)
    {
        error = null;
        if (!enabled)
            return true;

        if (NormalizePublicHosts(publicHosts).Count == 0)
        {
            error =
                "Portal:PublicEdge:Enabled is true but PublicHosts has no valid hostnames. " +
                "Configure at least one public hostname or set Enabled to false.";
            return false;
        }

        return true;
    }

    /// <summary>Normaliza entradas de config: trim, lower-invariant, rejeita inválidas.</summary>
    public static IReadOnlyList<string> NormalizePublicHosts(IEnumerable<string?>? publicHosts)
    {
        if (publicHosts is null)
            return Array.Empty<string>();

        var list = new List<string>();
        var seen = new HashSet<string>(StringComparer.Ordinal);
        foreach (var raw in publicHosts)
        {
            if (!TryNormalizeHostEntry(raw, out var host))
                continue;
            if (seen.Add(host))
                list.Add(host);
        }

        return list;
    }

    public static bool TryNormalizeHostEntry(string? raw, [NotNullWhen(true)] out string? host)
    {
        host = null;
        if (string.IsNullOrWhiteSpace(raw))
            return false;

        var s = raw.Trim();
        if (s.Contains("://", StringComparison.Ordinal) ||
            s.Contains('/') ||
            s.Contains('\\') ||
            s.Contains('*') ||
            s.Contains(' ') ||
            s.Contains('\t'))
            return false;

        // Aceitar "host:port" na config mas guardar só o host.
        if (s.StartsWith('[') && s.Contains(']', StringComparison.Ordinal))
        {
            // [IPv6]:port
            var end = s.IndexOf(']');
            s = s[1..end];
        }
        else
        {
            var colon = s.LastIndexOf(':');
            if (colon > 0 && s.IndexOf(':') == colon && int.TryParse(s[(colon + 1)..], out _))
                s = s[..colon];
        }

        if (string.IsNullOrWhiteSpace(s) || s.Equals("localhost", StringComparison.OrdinalIgnoreCase))
            return false;

        host = s.Trim().TrimEnd('.').ToLowerInvariant();
        return host.Length > 0;
    }

    /// <summary>
    /// Normaliza o host do pedido. Remove porta (<c>host:443</c> / <c>[ipv6]:port</c>)
    /// para não tratar um hostname público com porta como “interno” (fail-open).
    /// Preferir passar <c>HttpRequest.Host.Host</c>; esta função tolera também <c>Host.Value</c>.
    /// </summary>
    public static string NormalizeRequestHost(string? requestHost)
    {
        if (string.IsNullOrWhiteSpace(requestHost))
            return string.Empty;

        var s = requestHost.Trim();
        if (s.Contains("://", StringComparison.Ordinal) ||
            s.Contains('/') ||
            s.Contains('\\') ||
            s.Contains('*') ||
            s.Contains(' ') ||
            s.Contains('\t'))
            return string.Empty;

        if (s.StartsWith('['))
        {
            var end = s.IndexOf(']');
            if (end <= 1)
                return string.Empty;
            s = s[1..end];
        }
        else
        {
            // host:port (um único ':') — igual à normalização de entradas de config.
            var colon = s.LastIndexOf(':');
            if (colon > 0 && s.IndexOf(':') == colon && int.TryParse(s[(colon + 1)..], out _))
                s = s[..colon];
        }

        return s.Trim().TrimEnd('.').ToLowerInvariant();
    }

    /// <summary>
    /// Avalia se o pedido seria permitido.
    /// <list type="bullet">
    /// <item>Enabled=false → sempre Allowed (filtro inactivo).</item>
    /// <item>Enabled=true sem hosts válidos → Always deny (fail-closed; arranque deve falhar no Passo B).</item>
    /// <item>Host não público → Allowed (tráfego interno).</item>
    /// <item>Host público → allowlist por segmentos + método.</item>
    /// </list>
    /// </summary>
    public static EvaluateResult Evaluate(
        bool enabled,
        IEnumerable<string?>? publicHosts,
        string? requestHost,
        string? method,
        string? pathAndQuery)
    {
        if (!enabled)
            return new EvaluateResult(false, true, "disabled");

        var hosts = NormalizePublicHosts(publicHosts);
        if (hosts.Count == 0)
            return new EvaluateResult(true, false, "enabled-without-hosts");

        var host = NormalizeRequestHost(requestHost);
        var isPublic = host.Length > 0 && hosts.Contains(host);
        if (!isPublic)
            return new EvaluateResult(false, true, "internal-host");

        if (string.IsNullOrWhiteSpace(method))
            return new EvaluateResult(true, false, "missing-method");

        var httpMethod = method.Trim().ToUpperInvariant();
        if (!TryGetPathSegments(pathAndQuery, out var segments, out var pathReason))
            return new EvaluateResult(true, false, pathReason);

        if (IsAllowedOnPublicHost(segments, httpMethod))
            return new EvaluateResult(true, true, "allowlist");

        return new EvaluateResult(true, false, "deny-by-default");
    }

    public static bool IsAllowedOnPublicHost(IReadOnlyList<string> segments, string httpMethodUpper)
    {
        if (segments.Count == 0)
            return false; // raiz "/"

        // /cliente e /cliente/**
        if (segments[0] == "cliente")
            return IsSafeReadMethod(httpMethodUpper);

        // /api/v1/cliente e /api/v1/cliente/**
        if (segments.Count >= 3 &&
            segments[0] == "api" &&
            segments[1] == "v1" &&
            segments[2] == "cliente")
        {
            // Controllers cliente: GET (me, artigos, pedidos, imagem) + POST (auth, pedidos, cancelar).
            return httpMethodUpper is "GET" or "HEAD" or "POST";
        }

        // /assets/**
        if (segments[0] == "assets")
            return IsSafeReadMethod(httpMethodUpper);

        // Ficheiros estáticos exactos na raiz do wwwroot (confirmados no index.html / vite PWA).
        if (segments.Count == 1 && IsSafeReadMethod(httpMethodUpper))
        {
            return segments[0] switch
            {
                "favicon.png" or "favicon-32.png" or "apple-touch-icon.png"
                    or "manifest.webmanifest" or "pwa-192.png" or "pwa-512.png" => true,
                _ => false
            };
        }

        return false;
    }

    private static bool IsSafeReadMethod(string httpMethodUpper) =>
        httpMethodUpper is "GET" or "HEAD";

    /// <summary>
    /// Extrai segmentos de path; rejeita ambíguos (.., ., vazio após decode, etc.).
    /// Query string é ignorada.
    /// </summary>
    public static bool TryGetPathSegments(
        string? pathAndQuery,
        out IReadOnlyList<string> segments,
        out string reason)
    {
        segments = Array.Empty<string>();
        reason = "ok";

        if (string.IsNullOrWhiteSpace(pathAndQuery))
        {
            // Path vazio ≈ "/"
            return true;
        }

        var path = pathAndQuery;
        var q = path.IndexOf('?', StringComparison.Ordinal);
        if (q >= 0)
            path = path[..q];

        path = path.Trim();
        if (path.Length == 0 || path == "/")
            return true;

        // Uma passagem de unescape (simula Path já descodificado pelo host ASP.NET).
        string decoded;
        try
        {
            decoded = Uri.UnescapeDataString(path.Replace('+', ' '));
        }
        catch (UriFormatException)
        {
            reason = "invalid-encoding";
            return false;
        }

        if (decoded.Contains('\\', StringComparison.Ordinal) ||
            decoded.Contains('\0', StringComparison.Ordinal))
        {
            reason = "ambiguous-path";
            return false;
        }

        var parts = decoded.Split('/', StringSplitOptions.RemoveEmptyEntries | StringSplitOptions.TrimEntries);
        var list = new List<string>(parts.Length);
        foreach (var part in parts)
        {
            if (part is "." or "..")
            {
                reason = "dot-segment";
                return false;
            }

            if (part.Length == 0)
            {
                reason = "empty-segment";
                return false;
            }

            list.Add(part.ToLowerInvariant());
        }

        segments = list;
        return true;
    }
}
