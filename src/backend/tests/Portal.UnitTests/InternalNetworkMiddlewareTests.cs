using System.Net;
using Microsoft.AspNetCore.Http;
using Microsoft.Extensions.Logging.Abstractions;
using Microsoft.Extensions.Options;
using Portal.Api.Hosting;

namespace Portal.UnitTests;

public class InternalNetworkMiddlewareTests
{
    private static InternalNetworkMiddleware Create(
        InternalNetworkOptions options,
        RequestDelegate next) =>
        new(next, Options.Create(options), NullLogger<InternalNetworkMiddleware>.Instance);

    private static DefaultHttpContext CreateContext(
        string method,
        string path,
        IPAddress? remoteIp,
        Action<HttpRequest>? configure = null)
    {
        var ctx = new DefaultHttpContext();
        ctx.Request.Method = method;
        ctx.Request.Path = path;
        ctx.Connection.RemoteIpAddress = remoteIp;
        configure?.Invoke(ctx.Request);
        return ctx;
    }

    [Fact]
    public async Task Disabled_chama_next_para_cliente_com_ip_externo()
    {
        var nextCalled = false;
        var mw = Create(
            new InternalNetworkOptions { Enabled = false, AllowedNetworks = ["10.0.0.0/8"] },
            _ =>
            {
                nextCalled = true;
                return Task.CompletedTask;
            });

        var ctx = CreateContext("GET", "/cliente/login", IPAddress.Parse("203.0.113.1"));
        await mw.InvokeAsync(ctx);

        Assert.True(nextCalled);
        Assert.Equal(StatusCodes.Status200OK, ctx.Response.StatusCode);
    }

    [Theory]
    [InlineData("/cliente/login")]
    [InlineData("/api/v1/cliente/auth/login")]
    public async Task Enabled_ip_interno_permite_cliente_spa_e_api(string path)
    {
        var nextCalled = false;
        var mw = Create(
            new InternalNetworkOptions { Enabled = true, AllowedNetworks = ["192.168.0.0/16"] },
            _ =>
            {
                nextCalled = true;
                return Task.CompletedTask;
            });

        var ctx = CreateContext("POST", path, IPAddress.Parse("192.168.0.55"));
        await mw.InvokeAsync(ctx);

        Assert.True(nextCalled);
        Assert.Equal(StatusCodes.Status200OK, ctx.Response.StatusCode);
    }

    [Fact]
    public async Task Enabled_ip_externo_bloqueia_cliente_com_403_sem_chamar_next()
    {
        var nextCalled = false;
        var mw = Create(
            new InternalNetworkOptions
            {
                Enabled = true,
                AllowedNetworks = ["10.0.0.0/8"],
                BlockedStatusCode = 403
            },
            _ =>
            {
                nextCalled = true;
                return Task.CompletedTask;
            });

        var ctx = CreateContext("GET", "/api/v1/cliente/pedidos", IPAddress.Parse("198.51.100.2"));
        await mw.InvokeAsync(ctx);

        Assert.False(nextCalled);
        Assert.Equal(StatusCodes.Status403Forbidden, ctx.Response.StatusCode);
        Assert.Equal(0, ctx.Response.Body.Length);
    }

    [Fact]
    public async Task Enabled_staff_e_assets_nao_sao_bloqueados_por_ip_externo()
    {
        foreach (var path in new[]
                 {
                     "/api/v1/encomendas/abertas",
                     "/assets/app.js",
                     "/health",
                     "/login"
                 })
        {
            var nextCalled = false;
            var mw = Create(
                new InternalNetworkOptions { Enabled = true, AllowedNetworks = ["10.0.0.0/8"] },
                _ =>
                {
                    nextCalled = true;
                    return Task.CompletedTask;
                });

            var ctx = CreateContext("GET", path, IPAddress.Parse("198.51.100.2"));
            await mw.InvokeAsync(ctx);

            Assert.True(nextCalled, path);
            Assert.Equal(StatusCodes.Status200OK, ctx.Response.StatusCode);
        }
    }

    [Fact]
    public async Task Enabled_lista_vazia_fail_closed_no_middleware()
    {
        var nextCalled = false;
        var mw = Create(
            new InternalNetworkOptions { Enabled = true, AllowedNetworks = [] },
            _ =>
            {
                nextCalled = true;
                return Task.CompletedTask;
            });

        var ctx = CreateContext("GET", "/cliente", IPAddress.Parse("10.0.0.1"));
        await mw.InvokeAsync(ctx);

        Assert.False(nextCalled);
        Assert.Equal(StatusCodes.Status403Forbidden, ctx.Response.StatusCode);
    }

    [Fact]
    public async Task XForwardedFor_falsificado_nao_e_lido_pelo_middleware()
    {
        // Contrato: o middleware usa só RemoteIpAddress. Cabeçalho XFF não altera a decisão.
        var nextCalled = false;
        var mw = Create(
            new InternalNetworkOptions { Enabled = true, AllowedNetworks = ["192.168.0.0/16"] },
            _ =>
            {
                nextCalled = true;
                return Task.CompletedTask;
            });

        var ctx = CreateContext(
            "GET",
            "/cliente/login",
            IPAddress.Parse("203.0.113.80"),
            req => req.Headers["X-Forwarded-For"] = "192.168.0.10");

        await mw.InvokeAsync(ctx);

        Assert.False(nextCalled);
        Assert.Equal(StatusCodes.Status403Forbidden, ctx.Response.StatusCode);
        // RemoteIp inalterado pelo nosso middleware
        Assert.Equal(IPAddress.Parse("203.0.113.80"), ctx.Connection.RemoteIpAddress);
    }

    [Fact]
    public async Task Apos_proxy_confiavel_usa_RemoteIp_ja_resolvido_da_LAN()
    {
        // Contrato: confiança em XFF é só do ForwardedHeaders (KnownProxies/Networks).
        // Este middleware consome o RemoteIpAddress já resolvido — simula pós-FH com IP LAN.
        var nextCalled = false;
        var mw = Create(
            new InternalNetworkOptions { Enabled = true, AllowedNetworks = ["10.50.0.0/16"] },
            _ =>
            {
                nextCalled = true;
                return Task.CompletedTask;
            });

        var ctx = CreateContext(
            "GET",
            "/api/v1/cliente/me",
            IPAddress.Parse("10.50.9.3"),
            req => req.Headers["X-Forwarded-For"] = "10.50.9.3");

        await mw.InvokeAsync(ctx);

        Assert.True(nextCalled);
        Assert.Equal(StatusCodes.Status200OK, ctx.Response.StatusCode);
    }

    [Fact]
    public async Task Sem_proxy_confiavel_RemoteIp_externo_com_xff_spoof_continua_bloqueado()
    {
        // Espelha o resultado do ForwardedHeaders quando o peer não é KnownProxy:
        // RemoteIp permanece o IP externo; XFF não é aplicado nem lido aqui.
        var nextCalled = false;
        var mw = Create(
            new InternalNetworkOptions { Enabled = true, AllowedNetworks = ["10.50.0.0/16"] },
            _ =>
            {
                nextCalled = true;
                return Task.CompletedTask;
            });

        var external = IPAddress.Parse("198.51.100.20");
        var ctx = CreateContext(
            "GET",
            "/cliente/login",
            external,
            req => req.Headers["X-Forwarded-For"] = "10.50.1.1");

        await mw.InvokeAsync(ctx);

        Assert.Equal(external, ctx.Connection.RemoteIpAddress);
        Assert.False(nextCalled);
        Assert.Equal(StatusCodes.Status403Forbidden, ctx.Response.StatusCode);
    }

    [Fact]
    public async Task Enabled_ipv4_mapped_permitido()
    {
        var nextCalled = false;
        var mw = Create(
            new InternalNetworkOptions { Enabled = true, AllowedNetworks = ["172.16.0.0/12"] },
            _ =>
            {
                nextCalled = true;
                return Task.CompletedTask;
            });

        var ctx = CreateContext(
            "GET",
            "/cliente",
            IPAddress.Parse("::ffff:172.16.5.5"));

        await mw.InvokeAsync(ctx);

        Assert.True(nextCalled);
    }
}
