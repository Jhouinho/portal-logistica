using System.Net;
using Microsoft.AspNetCore.HttpOverrides;

namespace Portal.Api.Hosting;

/// <summary>
/// Configura forwarded headers de forma restritiva.
/// Topologia documentada: IIS + ASP.NET Core Module (proxy local/loopback).
/// Proxies adicionais apenas via configuração explícita — nunca Clear() de KnownProxies/Networks.
/// </summary>
public static class ForwardedHeadersSetup
{
    public const string SectionName = "ForwardedHeaders";

    public static void Configure(IServiceCollection services, IConfiguration configuration)
    {
        services.Configure<ForwardedHeadersOptions>(options =>
        {
            Apply(options, configuration);
        });
    }

    /// <summary>Aplicação pura das opções (testável sem DI completo).</summary>
    public static void Apply(ForwardedHeadersOptions options, IConfiguration configuration)
    {
        ArgumentNullException.ThrowIfNull(options);
        ArgumentNullException.ThrowIfNull(configuration);

        options.ForwardedHeaders = ForwardedHeaders.XForwardedFor | ForwardedHeaders.XForwardedProto;

        // Mantém os defaults do ASP.NET Core (loopback). Não limpar — evita confiar em qualquer origem.
        var proxies = configuration.GetSection($"{SectionName}:KnownProxies").Get<string[]>()
                      ?? Array.Empty<string>();
        foreach (var raw in proxies)
        {
            if (string.IsNullOrWhiteSpace(raw))
                continue;
            if (IPAddress.TryParse(raw.Trim(), out var ip))
                options.KnownProxies.Add(ip);
        }

        var networks = configuration.GetSection($"{SectionName}:KnownNetworks").Get<string[]>()
                       ?? Array.Empty<string>();
        foreach (var raw in networks)
        {
            if (TryParseCidr(raw, out var network))
                options.KnownNetworks.Add(network);
        }
    }

    public static bool TryParseCidr(string? cidr, out Microsoft.AspNetCore.HttpOverrides.IPNetwork network)
    {
        network = null!;
        if (string.IsNullOrWhiteSpace(cidr))
            return false;

        var parts = cidr.Trim().Split('/', 2, StringSplitOptions.TrimEntries);
        if (parts.Length != 2)
            return false;
        if (!IPAddress.TryParse(parts[0], out var prefix))
            return false;
        if (!int.TryParse(parts[1], out var prefixLength))
            return false;
        if (prefixLength < 0 || prefixLength > (prefix.AddressFamily == System.Net.Sockets.AddressFamily.InterNetwork ? 32 : 128))
            return false;

        network = new Microsoft.AspNetCore.HttpOverrides.IPNetwork(prefix, prefixLength);
        return true;
    }

    /// <summary>Resumo testável sem expor tipos de HttpOverrides aos projectos de teste.</summary>
    public static (string[] Proxies, int NetworkCount, bool ForwardsProtoAndFor) DescribeTrust(IConfiguration configuration)
    {
        var options = new ForwardedHeadersOptions();
        Apply(options, configuration);
        return (
            options.KnownProxies.Select(p => p.ToString()).ToArray(),
            options.KnownNetworks.Count,
            options.ForwardedHeaders == (ForwardedHeaders.XForwardedFor | ForwardedHeaders.XForwardedProto));
    }
}
