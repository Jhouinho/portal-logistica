using System.Net;
using System.Text.Json;
using Portal.Api.Hosting;

namespace Portal.UnitTests;

public class InternalNetworkAccessTests
{
    [Fact]
    public void Disabled_permite_qualquer_ip_e_path()
    {
        var r = InternalNetworkAccess.Evaluate(
            enabled: false,
            allowedNetworks: ["10.0.0.0/8"],
            remoteIp: IPAddress.Parse("8.8.8.8"),
            pathAndQuery: "/api/v1/cliente/auth/login");

        Assert.False(r.InScope);
        Assert.True(r.Allowed);
        Assert.Equal("disabled", r.Reason);
    }

    [Fact]
    public void Enabled_ip_dentro_da_subnet_v4_permite()
    {
        var r = InternalNetworkAccess.Evaluate(
            enabled: true,
            allowedNetworks: ["192.168.10.0/24"],
            remoteIp: IPAddress.Parse("192.168.10.42"),
            pathAndQuery: "/cliente/login");

        Assert.True(r.InScope);
        Assert.True(r.Allowed);
        Assert.Equal("allowlist", r.Reason);
    }

    [Fact]
    public void Enabled_ip_fora_da_subnet_nega()
    {
        var r = InternalNetworkAccess.Evaluate(
            enabled: true,
            allowedNetworks: ["192.168.10.0/24"],
            remoteIp: IPAddress.Parse("203.0.113.9"),
            pathAndQuery: "/api/v1/cliente/pedidos");

        Assert.True(r.InScope);
        Assert.False(r.Allowed);
        Assert.Equal("deny-not-in-allowlist", r.Reason);
    }

    [Fact]
    public void Enabled_ipv6_dentro_permite()
    {
        var r = InternalNetworkAccess.Evaluate(
            enabled: true,
            allowedNetworks: ["fd12:3456:789a::/48"],
            remoteIp: IPAddress.Parse("fd12:3456:789a::1"),
            pathAndQuery: "/cliente");

        Assert.True(r.InScope);
        Assert.True(r.Allowed);
        Assert.Equal("allowlist", r.Reason);
    }

    [Fact]
    public void Enabled_ipv6_fora_nega()
    {
        var r = InternalNetworkAccess.Evaluate(
            enabled: true,
            allowedNetworks: ["fd12:3456:789a::/48"],
            remoteIp: IPAddress.Parse("2001:db8::1"),
            pathAndQuery: "/api/v1/cliente/me");

        Assert.True(r.InScope);
        Assert.False(r.Allowed);
        Assert.Equal("deny-not-in-allowlist", r.Reason);
    }

    [Fact]
    public void Enabled_ipv4_mapeado_em_ipv6_casa_com_cidr_v4()
    {
        var mapped = IPAddress.Parse("::ffff:192.168.10.7");
        Assert.True(mapped.IsIPv4MappedToIPv6);

        var r = InternalNetworkAccess.Evaluate(
            enabled: true,
            allowedNetworks: ["192.168.10.0/24"],
            remoteIp: mapped,
            pathAndQuery: "/cliente/carrinho");

        Assert.True(r.InScope);
        Assert.True(r.Allowed);
        Assert.Equal("allowlist", r.Reason);
    }

    [Fact]
    public void Enabled_lista_vazia_fail_closed()
    {
        var r = InternalNetworkAccess.Evaluate(
            enabled: true,
            allowedNetworks: [],
            remoteIp: IPAddress.Parse("192.168.10.1"),
            pathAndQuery: "/cliente");

        Assert.True(r.InScope);
        Assert.False(r.Allowed);
        Assert.Equal("enabled-without-networks", r.Reason);
    }

    [Fact]
    public void Enabled_so_cidr_invalidos_fail_closed()
    {
        var r = InternalNetworkAccess.Evaluate(
            enabled: true,
            allowedNetworks: ["not-a-cidr", "10.0.0.0/99", ""],
            remoteIp: IPAddress.Parse("10.0.0.1"),
            pathAndQuery: "/api/v1/cliente/artigos");

        Assert.True(r.InScope);
        Assert.False(r.Allowed);
        Assert.Equal("enabled-without-networks", r.Reason);
    }

    [Fact]
    public void Enabled_remote_ip_null_fail_closed()
    {
        var r = InternalNetworkAccess.Evaluate(
            enabled: true,
            allowedNetworks: ["10.0.0.0/8"],
            remoteIp: null,
            pathAndQuery: "/cliente/login");

        Assert.True(r.InScope);
        Assert.False(r.Allowed);
        Assert.Equal("missing-remote-ip", r.Reason);
    }

    [Fact]
    public void Staff_e_assets_fora_de_ambito()
    {
        foreach (var path in new[]
                 {
                     "/api/v1/encomendas/abertas",
                     "/login",
                     "/assets/index-abc.js",
                     "/health",
                     "/hubs/operacoes",
                     "/favicon.png",
                     "/"
                 })
        {
            var r = InternalNetworkAccess.Evaluate(
                enabled: true,
                allowedNetworks: ["10.0.0.0/8"],
                remoteIp: IPAddress.Parse("8.8.8.8"),
                pathAndQuery: path);

            Assert.False(r.InScope);
            Assert.True(r.Allowed);
            Assert.Equal("out-of-scope", r.Reason);
        }
    }

    [Theory]
    [InlineData("/cliente")]
    [InlineData("/cliente/")]
    [InlineData("/cliente/login")]
    [InlineData("/CLIENTE/pedidos")]
    [InlineData("/api/v1/cliente")]
    [InlineData("/api/v1/cliente/auth/login")]
    [InlineData("/api/v1/cliente/pedidos?x=1")]
    public void Paths_cliente_estao_no_ambito(string path)
    {
        Assert.True(InternalNetworkAccess.IsClienteProtectedPath(path));
    }

    [Fact]
    public void TryValidateWhenEnabled_false_aceita_lista_vazia()
    {
        Assert.True(InternalNetworkAccess.TryValidateWhenEnabled(false, [], out var err));
        Assert.Equal("", err);
    }

    [Fact]
    public void TryValidateWhenEnabled_true_sem_redes_falha()
    {
        Assert.False(InternalNetworkAccess.TryValidateWhenEnabled(true, ["bad"], out var err));
        Assert.Contains("AllowedNetworks", err, StringComparison.Ordinal);
    }

    [Fact]
    public void TryValidateWhenEnabled_true_com_cidr_valido_ok()
    {
        Assert.True(InternalNetworkAccess.TryValidateWhenEnabled(true, ["10.20.0.0/16"], out _));
    }

    [Fact]
    public void ParseAllowedNetworks_ignora_invalidos_mantem_validos()
    {
        var nets = InternalNetworkAccess.ParseAllowedNetworks(["nope", "10.0.0.0/8", "fd00::/8"]);
        Assert.Equal(2, nets.Count);
        Assert.True(InternalNetworkAccess.Contains(nets[0], IPAddress.Parse("10.1.2.3")));
        Assert.True(InternalNetworkAccess.Contains(nets[1], IPAddress.Parse("fd00::abcd")));
    }

    [Fact]
    public void Appsettings_repo_tem_InternalNetwork_desactivado_sem_redes_inventadas()
    {
        var path = SourcePathHelper.ResolveBackendSrc("Portal.Api", "appsettings.json");
        var json = File.ReadAllText(path);
        using var doc = System.Text.Json.JsonDocument.Parse(json);
        var section = doc.RootElement.GetProperty("Portal").GetProperty("InternalNetwork");
        Assert.False(section.GetProperty("Enabled").GetBoolean());
        Assert.Equal(JsonValueKind.Array, section.GetProperty("AllowedNetworks").ValueKind);
        Assert.Equal(0, section.GetProperty("AllowedNetworks").GetArrayLength());
        Assert.Equal(403, section.GetProperty("BlockedStatusCode").GetInt32());
    }
}
