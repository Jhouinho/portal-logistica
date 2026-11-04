using System.Net;
using Microsoft.AspNetCore.Http;
using Microsoft.Extensions.Configuration;
using Microsoft.Extensions.DependencyInjection;
using Microsoft.Extensions.Logging.Abstractions;
using Microsoft.Extensions.Options;
using Portal.Api.Hosting;

namespace Portal.UnitTests;

/// <summary>
/// Revisão Fase 92: lacunas de pipeline, âmbito de rotas e configuração.
/// Não substitui validação IIS/ANCM em runtime.
/// </summary>
public class InternalNetworkPipelineReviewTests
{
    [Fact]
    public void ForwardedHeaders_defaults_preservam_loopback_ForwardLimit_1_sem_Host()
    {
        var d = ForwardedHeadersSetup.DescribeTrustDetails(
            new ConfigurationBuilder().AddInMemoryCollection().Build());

        Assert.True(d.ForwardsProtoAndFor);
        Assert.False(d.ForwardsHost);
        Assert.Equal(1, d.ForwardLimit);
        Assert.Contains(d.Proxies, p => p is "127.0.0.1" or "::1" || IPAddress.IsLoopback(IPAddress.Parse(p)));
        // ASP.NET Core inclui por omissão KnownNetworks com 127.0.0.0/8 (além de KnownProxies loopback).
        Assert.True(d.NetworkCount >= 1);
        Assert.DoesNotContain("203.0.113.1", d.Proxies);
    }

    [Fact]
    public void ForwardedHeaders_repo_appsettings_nao_adiciona_proxies_extra()
    {
        var path = SourcePathHelper.ResolveBackendSrc("Portal.Api", "appsettings.json");
        var cfg = new ConfigurationBuilder().AddJsonFile(path).Build();
        var empty = ForwardedHeadersSetup.DescribeTrustDetails(
            new ConfigurationBuilder().AddInMemoryCollection().Build());
        var d = ForwardedHeadersSetup.DescribeTrustDetails(cfg);

        Assert.All(d.Proxies, p =>
            Assert.True(IPAddress.IsLoopback(IPAddress.Parse(p)) || p is "127.0.0.1" or "::1"));
        Assert.Equal(empty.NetworkCount, d.NetworkCount);
        Assert.Equal(empty.Proxies.Length, d.Proxies.Length);
        Assert.Equal(1, d.ForwardLimit);
    }

    [Fact]
    public void SectionName_InternalNetwork_alinha_Options_Setup_e_appsettings()
    {
        Assert.Equal("Portal:InternalNetwork", InternalNetworkOptions.SectionName);

        var path = SourcePathHelper.ResolveBackendSrc("Portal.Api", "appsettings.json");
        var cfg = new ConfigurationBuilder().AddJsonFile(path).Build();
        var opts = new InternalNetworkOptions();
        cfg.GetSection(InternalNetworkOptions.SectionName).Bind(opts);

        Assert.False(opts.Enabled);
        Assert.Empty(opts.AllowedNetworks);
        Assert.Equal(403, opts.BlockedStatusCode);
    }

    [Fact]
    public void ValidateOnStart_rejeita_Enabled_sem_CIDR_valido()
    {
        var services = new ServiceCollection();
        var cfg = new ConfigurationBuilder().AddInMemoryCollection(new Dictionary<string, string?>
        {
            ["Portal:InternalNetwork:Enabled"] = "true",
            ["Portal:InternalNetwork:AllowedNetworks:0"] = "nao-e-cidr"
        }).Build();

        InternalNetworkSetup.Configure(services, cfg);
        services.AddLogging();
        using var sp = services.BuildServiceProvider();

        var ex = Assert.Throws<OptionsValidationException>(() =>
            sp.GetRequiredService<IOptions<InternalNetworkOptions>>().Value);
        Assert.Contains("AllowedNetworks", ex.Message, StringComparison.Ordinal);
    }

    [Fact]
    public void ValidateOnStart_aceita_Enabled_false_com_lista_vazia()
    {
        var services = new ServiceCollection();
        var cfg = new ConfigurationBuilder().AddInMemoryCollection(new Dictionary<string, string?>
        {
            ["Portal:InternalNetwork:Enabled"] = "false"
        }).Build();

        InternalNetworkSetup.Configure(services, cfg);
        using var sp = services.BuildServiceProvider();
        var opts = sp.GetRequiredService<IOptions<InternalNetworkOptions>>().Value;
        Assert.False(opts.Enabled);
    }

    [Theory]
    [InlineData("/cliente")]
    [InlineData("/cliente/")]
    [InlineData("/CLIENTE/login")]
    [InlineData("/Cliente/Carrinho")]
    [InlineData("/api/v1/cliente")]
    [InlineData("/API/V1/CLIENTE/auth/login")]
    [InlineData("/api/v1/cliente/")]
    [InlineData("/cliente?x=1")]
    [InlineData("/api/v1/cliente/pedidos?page=1")]
    public void Ambito_variantes_case_e_trailing_slash_protegidas(string path)
    {
        Assert.True(InternalNetworkAccess.IsClienteProtectedPath(path));
        var r = InternalNetworkAccess.Evaluate(
            true, ["10.0.0.0/8"], IPAddress.Parse("203.0.113.1"), path);
        Assert.True(r.InScope);
        Assert.False(r.Allowed);
    }

    [Theory]
    [InlineData("/clientes")]
    [InlineData("/cliente-extra")]
    [InlineData("/api/v1/clientes")]
    [InlineData("/api/v1/cliente-extra")]
    [InlineData("/api/v1/cliente2")]
    [InlineData("/api/v2/cliente")]
    [InlineData("/api/cliente")]
    [InlineData("/v1/cliente")]
    public void Prefixos_semelhantes_fora_de_ambito_nao_sao_rotas_cliente(string path)
    {
        // Controllers cliente só em api/v1/cliente/* — estes paths não contornam nem são protegidos.
        Assert.False(InternalNetworkAccess.IsClienteProtectedPath(path));
        var r = InternalNetworkAccess.Evaluate(
            true, ["10.0.0.0/8"], IPAddress.Parse("203.0.113.1"), path);
        Assert.False(r.InScope);
        Assert.True(r.Allowed);
    }

    [Theory]
    [InlineData("/api/v1/staff/pedidos-mobile")]
    [InlineData("/api/v1/auth/login")]
    [InlineData("/api/v1/encomendas/abertas")]
    [InlineData("/assets/index-hash.js")]
    [InlineData("/health")]
    [InlineData("/hubs/operacoes")]
    [InlineData("/hubs/tv")]
    [InlineData("/favicon.png")]
    [InlineData("/manifest.webmanifest")]
    public void Staff_assets_health_hubs_permanecem_fora_de_ambito(string path)
    {
        var r = InternalNetworkAccess.Evaluate(
            true, ["10.0.0.0/8"], IPAddress.Parse("198.51.100.1"), path);
        Assert.False(r.InScope);
        Assert.True(r.Allowed);
    }

    [Fact]
    public void Path_com_dot_segments_e_fail_closed_no_ambito()
    {
        // Ambíguo → tratado como protegido (não permitir bypass por normalização).
        Assert.True(InternalNetworkAccess.IsClienteProtectedPath("/api/v1/../cliente/auth"));
        var r = InternalNetworkAccess.Evaluate(
            true, ["10.0.0.0/8"], IPAddress.Parse("203.0.113.1"), "/api/v1/../cliente/auth");
        Assert.True(r.InScope);
        Assert.False(r.Allowed);
    }

    [Fact]
    public void Path_percent_encoded_cliente_continua_no_ambito()
    {
        // Um Unescape: %63liente → cliente no primeiro segmento se path for /%63liente
        Assert.True(InternalNetworkAccess.IsClienteProtectedPath("/%63liente/login"));
        Assert.True(InternalNetworkAccess.IsClienteProtectedPath("/api/v1/%63liente/me"));
    }

    [Fact]
    public void Loopback_sem_estar_na_allowlist_e_negado_quando_Enabled()
    {
        // Sem XFF (ou Kestrel directo): RemoteIp=127.0.0.1. Se IT não incluir loopback nos CIDRs, nega.
        var r = InternalNetworkAccess.Evaluate(
            true,
            ["192.168.0.0/16"],
            IPAddress.Loopback,
            "/cliente/login");

        Assert.True(r.InScope);
        Assert.False(r.Allowed);
        Assert.Equal("deny-not-in-allowlist", r.Reason);
    }

    [Fact]
    public async Task Middleware_Enabled_false_nao_altera_status_nem_bloqueia_loopback()
    {
        var nextCalled = false;
        var mw = new InternalNetworkMiddleware(
            _ =>
            {
                nextCalled = true;
                return Task.CompletedTask;
            },
            Options.Create(new InternalNetworkOptions { Enabled = false }),
            NullLogger<InternalNetworkMiddleware>.Instance);

        var ctx = new DefaultHttpContext();
        ctx.Request.Path = "/cliente/login";
        ctx.Connection.RemoteIpAddress = IPAddress.Loopback;
        ctx.Response.StatusCode = StatusCodes.Status200OK;

        await mw.InvokeAsync(ctx);

        Assert.True(nextCalled);
        Assert.Equal(StatusCodes.Status200OK, ctx.Response.StatusCode);
    }

    [Fact]
    public void Controllers_cliente_so_sob_api_v1_cliente()
    {
        var auth = SourcePathHelper.ResolveBackendSrc("Portal.Api", "Controllers", "ClienteAuthController.cs");
        var artigos = SourcePathHelper.ResolveBackendSrc("Portal.Api", "Controllers", "ClienteArtigosController.cs");
        var pedidos = SourcePathHelper.ResolveBackendSrc("Portal.Api", "Controllers", "ClientePedidosController.cs");

        foreach (var file in new[] { auth, artigos, pedidos })
        {
            var text = File.ReadAllText(file);
            Assert.Contains("[Route(\"api/v1/cliente", text, StringComparison.Ordinal);
            Assert.DoesNotContain("[Route(\"api/cliente", text, StringComparison.Ordinal);
            Assert.DoesNotContain("[Route(\"cliente", text, StringComparison.Ordinal);
        }
    }
}
