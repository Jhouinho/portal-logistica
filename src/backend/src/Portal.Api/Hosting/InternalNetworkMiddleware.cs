using Microsoft.Extensions.Options;

namespace Portal.Api.Hosting;

/// <summary>
/// Allowlist por IP/CIDR para o Portal Cliente Mobile.
/// Colocar após <c>UseForwardedHeaders</c> e antes de static files / auth / Map*.
/// Usa apenas <see cref="ConnectionInfo.RemoteIpAddress"/> (já processado por ForwardedHeaders
/// quando o peer imediato é um proxy conhecido). Não interpreta X-Forwarded-For directamente.
/// Em IIS+ANCM o peer é tipicamente loopback: sem X-Forwarded-For aplicado, todos os clientes
/// apareceriam como 127.0.0.1/::1 — a allowlist CIDR só é correcta se o ANCM encaminhar o IP real.
/// </summary>
public sealed class InternalNetworkMiddleware
{
    private readonly RequestDelegate _next;
    private readonly InternalNetworkOptions _options;
    private readonly ILogger<InternalNetworkMiddleware> _logger;

    public InternalNetworkMiddleware(
        RequestDelegate next,
        IOptions<InternalNetworkOptions> options,
        ILogger<InternalNetworkMiddleware> logger)
    {
        _next = next;
        _options = options.Value;
        _logger = logger;
    }

    public Task InvokeAsync(HttpContext context)
    {
        if (!_options.Enabled)
            return _next(context);

        var result = InternalNetworkAccess.Evaluate(
            enabled: true,
            _options.AllowedNetworks,
            context.Connection.RemoteIpAddress,
            context.Request.Path.Value);

        if (!result.InScope || result.Allowed)
            return _next(context);

        // Diagnóstico seguro: razão + família do IP (sem dump de redes configuradas nem payloads).
        _logger.LogWarning(
            "Portal cliente blocked by InternalNetwork reason={Reason} pathScope={Path}",
            result.Reason,
            ClassifyPath(context.Request.Path.Value));

        var status = _options.BlockedStatusCode;
        if (status is < 400 or >= 600)
            status = StatusCodes.Status403Forbidden;

        context.Response.StatusCode = status;
        return Task.CompletedTask;
    }

    private static string ClassifyPath(string? path)
    {
        if (string.IsNullOrEmpty(path))
            return "unknown";
        if (path.StartsWith("/api/v1/cliente", StringComparison.OrdinalIgnoreCase))
            return "cliente-api";
        if (path.StartsWith("/cliente", StringComparison.OrdinalIgnoreCase))
            return "cliente-spa";
        return "other";
    }
}

public static class InternalNetworkMiddlewareExtensions
{
    public static IApplicationBuilder UseInternalNetworkFilter(this IApplicationBuilder app) =>
        app.UseMiddleware<InternalNetworkMiddleware>();
}
