using System.Net;
using Microsoft.AspNetCore.Authentication.Cookies;
using Microsoft.AspNetCore.Http;
using Microsoft.AspNetCore.Identity;
using Microsoft.Extensions.Configuration;
using Microsoft.Extensions.DependencyInjection;
using Microsoft.Extensions.FileProviders;
using Microsoft.Extensions.Hosting;
using Microsoft.Extensions.Options;
using Portal.Api.Controllers;
using Portal.Api.Hosting;
using Portal.Application.Auth;
using Portal.Application.Cliente;
using Portal.Infrastructure;
using Portal.Infrastructure.Auth;

namespace Portal.UnitTests;

public class SecurityHardeningTests
{
    [Theory]
    [InlineData("Production")]
    [InlineData("Staging")]
    [InlineData("UAT")]
    public void Cookies_DI_exigem_Secure_fora_de_Development(string environmentName)
    {
        var (staff, cliente) = ResolveCookieOptions(environmentName, allowInsecure: false);

        Assert.Equal(CookieSecurePolicy.Always, staff.Cookie.SecurePolicy);
        Assert.Equal(CookieSecurePolicy.Always, cliente.Cookie.SecurePolicy);
        Assert.True(staff.Cookie.HttpOnly);
        Assert.True(cliente.Cookie.HttpOnly);
        Assert.Equal("ls_portal_auth", staff.Cookie.Name);
        Assert.Equal(ClienteAuthConstants.CookieName, cliente.Cookie.Name);
        Assert.NotEqual(staff.Cookie.Name, cliente.Cookie.Name);
        Assert.NotEqual(ClienteAuthConstants.CookieScheme, IdentityConstants.ApplicationScheme);
    }

    [Fact]
    public void Cookies_DI_Development_com_flag_permite_SameAsRequest()
    {
        var (staff, cliente) = ResolveCookieOptions(Environments.Development, allowInsecure: true);
        Assert.Equal(CookieSecurePolicy.SameAsRequest, staff.Cookie.SecurePolicy);
        Assert.Equal(CookieSecurePolicy.SameAsRequest, cliente.Cookie.SecurePolicy);
    }

    [Fact]
    public void Cookies_DI_Staging_ignora_pedido_inseguro_explicito()
    {
        var config = new ConfigurationBuilder().AddInMemoryCollection(new Dictionary<string, string?>
        {
            ["Phc:ConnectionString"] = "",
            ["Portal:AllowInsecureAuthCookies"] = "true",
            ["Portal:CookieSecurePolicy"] = "SameAsRequest"
        }).Build();

        var (staff, _) = ResolveCookieOptions("Staging", config);
        Assert.Equal(CookieSecurePolicy.Always, staff.Cookie.SecurePolicy);
    }

    [Fact]
    public void ForwardedHeaders_nao_limpa_defaults_e_aceita_proxy_explicito()
    {
        var empty = ForwardedHeadersSetup.DescribeTrust(new ConfigurationBuilder().AddInMemoryCollection().Build());
        var withProxy = ForwardedHeadersSetup.DescribeTrust(new ConfigurationBuilder().AddInMemoryCollection(
            new Dictionary<string, string?> { ["ForwardedHeaders:KnownProxies:0"] = "10.0.0.5" }).Build());

        Assert.True(empty.ForwardsProtoAndFor);
        Assert.True(withProxy.ForwardsProtoAndFor);
        Assert.Equal(empty.NetworkCount, withProxy.NetworkCount);
        Assert.Contains("10.0.0.5", withProxy.Proxies);
        Assert.True(withProxy.Proxies.Length >= empty.Proxies.Length);
    }

    [Fact]
    public void ForwardedHeaders_origem_nao_configurada_nao_e_adicionada_automaticamente()
    {
        var snapshot = ForwardedHeadersSetup.DescribeTrust(new ConfigurationBuilder().AddInMemoryCollection().Build());
        Assert.DoesNotContain("203.0.113.10", snapshot.Proxies);
        Assert.All(snapshot.Proxies, p =>
            Assert.True(IPAddress.IsLoopback(IPAddress.Parse(p)) || p is "127.0.0.1" or "::1"));
    }

    [Fact]
    public void Resolve_cookie_policy_por_config()
    {
        var env = new TestEnv(Environments.Development);
        var insecure = new ConfigurationBuilder().AddInMemoryCollection(new Dictionary<string, string?>
        {
            ["Portal:AllowInsecureAuthCookies"] = "true"
        }).Build();
        Assert.Equal(CookieSecurePolicy.SameAsRequest, CookieSecurePolicyHelper.Resolve(env, insecure));

        var staging = new TestEnv("Staging");
        var secureDefault = new ConfigurationBuilder().AddInMemoryCollection().Build();
        Assert.Equal(CookieSecurePolicy.Always, CookieSecurePolicyHelper.Resolve(staging, secureDefault));
    }

    [Fact]
    public void Estado_submetido_pode_cancelar_cancelado_nao()
    {
        var sub = ClientePedidoEstadoMapper.Map(cancelado: false);
        Assert.Equal("submetido", sub.Codigo);
        Assert.True(sub.PodeCancelar);

        var can = ClientePedidoEstadoMapper.Map(cancelado: true);
        Assert.Equal("cancelado", can.Codigo);
        Assert.False(can.PodeCancelar);
    }

    [Fact]
    public void CriarPedidoDto_nao_aceita_preco_do_frontend()
    {
        var linhaType = typeof(ClientePedidosController.LinhaDto);
        Assert.Null(linhaType.GetProperty("Preco"));
        Assert.Null(linhaType.GetProperty("PrecoUnitario"));
        Assert.NotNull(linhaType.GetProperty("Ref"));
        Assert.NotNull(linhaType.GetProperty("Qtt"));
        Assert.DoesNotContain(
            typeof(ClientePedidoLinhaInput).GetProperties(),
            p => p.Name.Contains("Preco", StringComparison.OrdinalIgnoreCase));
    }

    [Fact]
    public void ClientePedidosController_exige_scheme_e_policy_cliente()
    {
        var attr = typeof(ClientePedidosController)
            .GetCustomAttributes(typeof(Microsoft.AspNetCore.Authorization.AuthorizeAttribute), inherit: true)
            .Cast<Microsoft.AspNetCore.Authorization.AuthorizeAttribute>()
            .First();
        Assert.Equal(ClienteAuthConstants.CookieScheme, attr.AuthenticationSchemes);
        Assert.Equal(ClienteAuthConstants.PolicyName, attr.Policy);
    }

    [Fact]
    public void Lockout_constantes_e_quinta_falha()
    {
        Assert.Equal(5, ClienteAuthConstants.PhoneMaxFailures);
        Assert.Equal(15, ClienteAuthConstants.PhoneLockoutMinutes);
        Assert.True(ClienteAuthLockoutRules.ShouldLockAfterFailure(4, 5));
        Assert.False(ClienteAuthLockoutRules.ShouldLockAfterFailure(3, 5));
    }

    [Fact]
    public void PortalIdentitySeed_EnsureAdmin_existe_para_uso_explicito()
    {
        Assert.NotNull(typeof(PortalIdentitySeed).GetMethod(nameof(PortalIdentitySeed.EnsureAdminAsync)));
        Assert.Equal("Admin", PortalRoles.Admin);
    }

    private static (CookieAuthenticationOptions Staff, CookieAuthenticationOptions Cliente) ResolveCookieOptions(
        string environmentName,
        bool allowInsecure)
    {
        var config = new ConfigurationBuilder().AddInMemoryCollection(new Dictionary<string, string?>
        {
            ["Phc:ConnectionString"] = "",
            ["Portal:AllowInsecureAuthCookies"] = allowInsecure ? "true" : "false"
        }).Build();
        return ResolveCookieOptions(environmentName, config);
    }

    private static (CookieAuthenticationOptions Staff, CookieAuthenticationOptions Cliente) ResolveCookieOptions(
        string environmentName,
        IConfiguration config)
    {
        var services = new ServiceCollection();
        services.AddLogging();
        services.AddInfrastructure(config, new TestEnv(environmentName));
        using var sp = services.BuildServiceProvider();
        var monitor = sp.GetRequiredService<IOptionsMonitor<CookieAuthenticationOptions>>();
        return (
            monitor.Get(IdentityConstants.ApplicationScheme),
            monitor.Get(ClienteAuthConstants.CookieScheme));
    }

    private sealed class TestEnv(string name) : IHostEnvironment
    {
        public string EnvironmentName { get; set; } = name;
        public string ApplicationName { get; set; } = "Portal.UnitTests";
        public string ContentRootPath { get; set; } = AppContext.BaseDirectory;
        public IFileProvider ContentRootFileProvider { get; set; } = new NullFileProvider();
    }
}
