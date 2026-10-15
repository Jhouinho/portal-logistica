using System.Text;
using System.Text.Json;
using Microsoft.AspNetCore.Http;
using Microsoft.Extensions.Logging.Abstractions;
using Portal.Api.Errors;
using Portal.Application.Encomendas;

namespace Portal.UnitTests;

public class PortalExceptionHandlerTests
{
    [Fact]
    public async Task Negocio_devolve_status_e_detail_esperados()
    {
        var handler = new PortalExceptionHandler(NullLogger<PortalExceptionHandler>.Instance);
        var ctx = NewContext();

        var ok = await handler.TryHandleAsync(
            ctx,
            new PortalBusinessException("Quantidade inválida.", 400),
            CancellationToken.None);

        Assert.True(ok);
        Assert.Equal(400, ctx.Response.StatusCode);
        var body = await ReadBody(ctx);
        using var doc = JsonDocument.Parse(body);
        Assert.Equal("Quantidade inválida.", doc.RootElement.GetProperty("detail").GetString());
        Assert.Equal(400, doc.RootElement.GetProperty("status").GetInt32());
    }

    [Fact]
    public async Task Unexpected_nao_expoe_mensagem_original_e_tem_correlationId()
    {
        var handler = new PortalExceptionHandler(NullLogger<PortalExceptionHandler>.Instance);
        var ctx = NewContext();
        ctx.TraceIdentifier = "corr-test-abc";

        const string secret = "Login failed for user 'sa'. Connection string leaked.";
        var ok = await handler.TryHandleAsync(
            ctx,
            new InvalidOperationException(secret),
            CancellationToken.None);

        Assert.True(ok);
        Assert.Equal(500, ctx.Response.StatusCode);
        var body = await ReadBody(ctx);
        Assert.DoesNotContain(secret, body, StringComparison.Ordinal);
        Assert.DoesNotContain("Connection string", body, StringComparison.OrdinalIgnoreCase);

        using var doc = JsonDocument.Parse(body);
        Assert.Equal(PortalExceptionHandler.GenericMessage, doc.RootElement.GetProperty("detail").GetString());
        Assert.Equal(500, doc.RootElement.GetProperty("status").GetInt32());

        string? correlation = null;
        if (doc.RootElement.TryGetProperty("correlationId", out var cid))
            correlation = cid.GetString();
        else if (doc.RootElement.TryGetProperty("extensions", out var ext)
                 && ext.TryGetProperty("correlationId", out var cid2))
            correlation = cid2.GetString();

        Assert.Equal("corr-test-abc", correlation);
    }

    private static DefaultHttpContext NewContext()
    {
        var ctx = new DefaultHttpContext();
        ctx.Response.Body = new MemoryStream();
        ctx.Request.Path = "/api/v1/cliente/pedidos";
        ctx.Request.Method = "POST";
        return ctx;
    }

    private static async Task<string> ReadBody(HttpContext ctx)
    {
        ctx.Response.Body.Position = 0;
        using var reader = new StreamReader(ctx.Response.Body, Encoding.UTF8, leaveOpen: true);
        return await reader.ReadToEndAsync();
    }
}
