using System.Net;
using System.Net.Sockets;

namespace Portal.Api.Hosting;

/// <summary>
/// Avaliação pura da restrição por rede interna ao Portal Cliente Mobile.
/// Usa o IP já resolvido pelo host (<c>Connection.RemoteIpAddress</c> após ForwardedHeaders);
/// não lê cabeçalhos X-Forwarded-* directamente.
/// </summary>
public static class InternalNetworkAccess
{
    public readonly record struct EvaluateResult(
        bool InScope,
        bool Allowed,
        string Reason);

    /// <summary>
    /// Valida configuração quando o controlo está activo.
    /// Com Enabled=false, qualquer lista é aceite.
    /// </summary>
    public static bool TryValidateWhenEnabled(
        bool enabled,
        IEnumerable<string?>? allowedNetworks,
        out string error)
    {
        error = "";
        if (!enabled)
            return true;

        if (ParseAllowedNetworks(allowedNetworks).Count == 0)
        {
            error =
                "Portal:InternalNetwork:Enabled is true but AllowedNetworks has no valid CIDR entries. " +
                "Configure at least one authorized network or set Enabled to false.";
            return false;
        }

        return true;
    }

    /// <summary>
    /// Avalia se o pedido seria permitido.
    /// <list type="bullet">
    /// <item>Enabled=false → Allowed (filtro inactivo; InScope=false).</item>
    /// <item>Path fora de /cliente e /api/v1/cliente → Allowed (fora de âmbito).</item>
    /// <item>Enabled=true sem redes válidas → fail-closed (nega).</item>
    /// <item>RemoteIp ausente → fail-closed.</item>
    /// <item>IP (normalizado) contido numa rede autorizada → Allowed.</item>
    /// </list>
    /// </summary>
    public static EvaluateResult Evaluate(
        bool enabled,
        IEnumerable<string?>? allowedNetworks,
        IPAddress? remoteIp,
        string? pathAndQuery)
    {
        if (!enabled)
            return new EvaluateResult(false, true, "disabled");

        if (!IsClienteProtectedPath(pathAndQuery))
            return new EvaluateResult(false, true, "out-of-scope");

        var networks = ParseAllowedNetworks(allowedNetworks);
        if (networks.Count == 0)
            return new EvaluateResult(true, false, "enabled-without-networks");

        if (remoteIp is null)
            return new EvaluateResult(true, false, "missing-remote-ip");

        var candidate = NormalizeRemoteIp(remoteIp);
        foreach (var network in networks)
        {
            if (Contains(network, candidate))
                return new EvaluateResult(true, true, "allowlist");
        }

        return new EvaluateResult(true, false, "deny-not-in-allowlist");
    }

    /// <summary>
    /// Paths no âmbito: <c>/cliente</c>, <c>/cliente/**</c>, <c>/api/v1/cliente</c>, <c>/api/v1/cliente/**</c>.
    /// Assets partilhados (<c>/assets</c>), staff e fallback de outras rotas ficam fora.
    /// </summary>
    public static bool IsClienteProtectedPath(string? pathAndQuery)
    {
        if (!TryGetPathSegments(pathAndQuery, out var segments))
            // Path ambíguo no âmbito potencial → tratar como protegido (fail-closed no Evaluate se enabled).
            return true;

        if (segments.Count == 0)
            return false;

        if (segments[0] == "cliente")
            return true;

        return segments.Count >= 3
               && segments[0] == "api"
               && segments[1] == "v1"
               && segments[2] == "cliente";
    }

    public static IPAddress NormalizeRemoteIp(IPAddress ip)
    {
        if (ip.IsIPv4MappedToIPv6)
            return ip.MapToIPv4();
        return ip;
    }

    public static IReadOnlyList<IPNetwork> ParseAllowedNetworks(IEnumerable<string?>? raw)
    {
        var list = new List<IPNetwork>();
        if (raw is null)
            return list;

        foreach (var entry in raw)
        {
            if (TryParseCidr(entry, out var network))
                list.Add(network);
        }

        return list;
    }

    public static bool TryParseCidr(string? cidr, out IPNetwork network)
    {
        network = default;
        if (string.IsNullOrWhiteSpace(cidr))
            return false;

        var text = cidr.Trim();
        // System.Net.IPNetwork (.NET 8+) — rejeita prefixos inválidos.
        if (!IPNetwork.TryParse(text, out network))
            return false;

        // Rejeitar prefix length impossível já é feito por TryParse; garantir família coerente.
        return network.BaseAddress.AddressFamily is AddressFamily.InterNetwork
            or AddressFamily.InterNetworkV6;
    }

    public static bool Contains(IPNetwork network, IPAddress address)
    {
        var candidate = NormalizeRemoteIp(address);
        if (network.BaseAddress.AddressFamily != candidate.AddressFamily)
            return false;
        return network.Contains(candidate);
    }

    /// <summary>
    /// Extrai segmentos de path (query ignorada). Devolve false se o path for ambíguo.
    /// </summary>
    public static bool TryGetPathSegments(string? pathAndQuery, out IReadOnlyList<string> segments)
    {
        segments = Array.Empty<string>();
        if (string.IsNullOrWhiteSpace(pathAndQuery))
            return true;

        var path = pathAndQuery;
        var q = path.IndexOf('?', StringComparison.Ordinal);
        if (q >= 0)
            path = path[..q];

        path = path.Trim();
        if (path.Length == 0 || path == "/")
            return true;

        string decoded;
        try
        {
            decoded = Uri.UnescapeDataString(path.Replace('+', ' '));
        }
        catch (UriFormatException)
        {
            return false;
        }

        if (decoded.Contains('\\', StringComparison.Ordinal) ||
            decoded.Contains('\0', StringComparison.Ordinal))
            return false;

        var parts = decoded.Split('/', StringSplitOptions.RemoveEmptyEntries | StringSplitOptions.TrimEntries);
        var list = new List<string>(parts.Length);
        foreach (var part in parts)
        {
            if (part is "." or ".." || part.Length == 0)
                return false;
            list.Add(part.ToLowerInvariant());
        }

        segments = list;
        return true;
    }
}
