using Microsoft.AspNetCore.Http;
using Microsoft.Extensions.Options;
using Portal.Api.Hosting;

namespace Portal.UnitTests;

public class PublicEdgeMiddlewareTests
{
    private static readonly string PublicHost = "mobile.cliente.example";

    private static PublicEdgeMiddleware Create(
        PublicEdgeOptions options,
        RequestDelegate next) =>
        new(next, Options.Create(options));

    private static DefaultHttpContext CreateContext(string host, int? port, string method, string path)
    {
        var ctx = new DefaultHttpContext();
        ctx.Request.Method = method;
        ctx.Request.Path = path;
        ctx.Request.Host = port is int p ? new HostString(host, p) : new HostString(host);
        return ctx;
    }

    [Fact]
    public async Task Disabled_chama_next_mesmo_para_ops_anonymous()
    {
        var nextCalled = false;
        var mw = Create(
            new PublicEdgeOptions { Enabled = false, PublicHosts = [PublicHost] },
            _ =>
            {
                nextCalled = true;
                return Task.CompletedTask;
            });

        var ctx = CreateContext(PublicHost, 443, "GET", "/api/v1/encomendas/abertas");
        await mw.InvokeAsync(ctx);

        Assert.True(nextCalled);
        Assert.Equal(StatusCodes.Status200OK, ctx.Response.StatusCode);
    }

    [Fact]
    public async Task PublicHost_permite_cliente_login_e_chama_next()
    {
        var nextCalled = false;
        var mw = Create(
            new PublicEdgeOptions { Enabled = true, PublicHosts = [PublicHost], BlockedStatusCode = 404 },
            _ =>
            {
                nextCalled = true;
                return Task.CompletedTask;
            });

        var ctx = CreateContext(PublicHost, null, "GET", "/cliente/login");
        await mw.InvokeAsync(ctx);

        Assert.True(nextCalled);
        Assert.Equal(StatusCodes.Status200OK, ctx.Response.StatusCode);
    }

    [Fact]
    public async Task PublicHost_bloqueia_encomendas_abertas_sem_chamar_next()
    {
        var nextCalled = false;
        var mw = Create(
            new PublicEdgeOptions { Enabled = true, PublicHosts = [PublicHost], BlockedStatusCode = 404 },
            _ =>
            {
                nextCalled = true;
                return Task.CompletedTask;
            });

        var ctx = CreateContext(PublicHost, null, "GET", "/api/v1/encomendas/abertas");
        await mw.InvokeAsync(ctx);

        Assert.False(nextCalled);
        Assert.Equal(StatusCodes.Status404NotFound, ctx.Response.StatusCode);
        Assert.Null(ctx.Response.ContentType);
        Assert.Equal(0, ctx.Response.Body.Length);
    }

    [Fact]
    public async Task PublicHost_com_porta_no_HostString_usa_Host_sem_porta()
    {
        var nextCalled = false;
        var mw = Create(
            new PublicEdgeOptions { Enabled = true, PublicHosts = [PublicHost] },
            _ =>
            {
                nextCalled = true;
                return Task.CompletedTask;
            });

        // HostString(host, port) → Host.Host sem porta; Value inclui :443.
        var ctx = CreateContext(PublicHost, 443, "GET", "/api/v1/encomendas/abertas");
        Assert.Equal(PublicHost, ctx.Request.Host.Host);
        Assert.Contains(":443", ctx.Request.Host.Value, StringComparison.Ordinal);

        await mw.InvokeAsync(ctx);

        Assert.False(nextCalled);
        Assert.Equal(StatusCodes.Status404NotFound, ctx.Response.StatusCode);
    }

    [Fact]
    public async Task Host_interno_preserva_pipeline_para_ops()
    {
        var nextCalled = false;
        var mw = Create(
            new PublicEdgeOptions { Enabled = true, PublicHosts = [PublicHost] },
            _ =>
            {
                nextCalled = true;
                return Task.CompletedTask;
            });

        var ctx = CreateContext("portal.lan", 8088, "GET", "/api/v1/encomendas/abertas");
        await mw.InvokeAsync(ctx);

        Assert.True(nextCalled);
    }

    [Fact]
    public async Task BlockedStatusCode_invalido_cai_em_404()
    {
        var mw = Create(
            new PublicEdgeOptions
            {
                Enabled = true,
                PublicHosts = [PublicHost],
                BlockedStatusCode = 200
            },
            _ => Task.CompletedTask);

        var ctx = CreateContext(PublicHost, null, "GET", "/health");
        await mw.InvokeAsync(ctx);
        Assert.Equal(StatusCodes.Status404NotFound, ctx.Response.StatusCode);
    }
}
