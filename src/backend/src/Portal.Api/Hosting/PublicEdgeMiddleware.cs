using Microsoft.Extensions.Options;

namespace Portal.Api.Hosting;

/// <summary>
/// Allowlist no hostname público. Colocar após <c>UseForwardedHeaders</c> e antes de static files / auth / Map*.
/// Usa <see cref="HostString.Host"/> (sem porta). Não lê X-Forwarded-Host.
/// </summary>
public sealed class PublicEdgeMiddleware
{
    private readonly RequestDelegate _next;
    private readonly PublicEdgeOptions _options;

    public PublicEdgeMiddleware(RequestDelegate next, IOptions<PublicEdgeOptions> options)
    {
        _next = next;
        _options = options.Value;
    }

    public Task InvokeAsync(HttpContext context)
    {
        if (!_options.Enabled)
            return _next(context);

        var result = PublicEdgePathMatcher.Evaluate(
            enabled: true,
            _options.PublicHosts,
            context.Request.Host.Host,
            context.Request.Method,
            context.Request.Path.Value);

        if (result.Allowed)
            return _next(context);

        var status = _options.BlockedStatusCode;
        if (status is < 400 or >= 600)
            status = StatusCodes.Status404NotFound;

        context.Response.StatusCode = status;
        return Task.CompletedTask;
    }
}

public static class PublicEdgeMiddlewareExtensions
{
    public static IApplicationBuilder UsePublicEdgePathFilter(this IApplicationBuilder app) =>
        app.UseMiddleware<PublicEdgeMiddleware>();
}
