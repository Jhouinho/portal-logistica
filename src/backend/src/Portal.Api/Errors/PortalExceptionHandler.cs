using System.Diagnostics;
using Microsoft.AspNetCore.Diagnostics;
using Microsoft.AspNetCore.Mvc;
using Portal.Application.Encomendas;

namespace Portal.Api.Errors;

/// <summary>
/// Tratamento centralizado: erros de negócio expõem a mensagem;
/// erros inesperados devolvem mensagem genérica + correlationId (detalhe só no log).
/// Em Development, o Detail inclui a mensagem da excepção (ex. SQL) para diagnóstico.
/// </summary>
public sealed class PortalExceptionHandler : IExceptionHandler
{
    public const string GenericMessage = "Ocorreu um erro. Tente novamente.";

    private readonly ILogger<PortalExceptionHandler> _logger;
    private readonly IHostEnvironment _env;

    public PortalExceptionHandler(ILogger<PortalExceptionHandler> logger, IHostEnvironment env)
    {
        _logger = logger;
        _env = env;
    }

    public async ValueTask<bool> TryHandleAsync(
        HttpContext httpContext,
        Exception exception,
        CancellationToken cancellationToken)
    {
        if (exception is PortalBusinessException business)
        {
            httpContext.Response.StatusCode = business.StatusCode;
            await httpContext.Response.WriteAsJsonAsync(
                new ProblemDetails
                {
                    Title = business.StatusCode switch
                    {
                        StatusCodes.Status404NotFound => "Não encontrado",
                        StatusCodes.Status409Conflict => "Conflito",
                        StatusCodes.Status401Unauthorized => "Não autenticado",
                        StatusCodes.Status403Forbidden => "Acesso negado",
                        _ => "Pedido inválido"
                    },
                    Detail = business.Message,
                    Status = business.StatusCode
                },
                cancellationToken);
            return true;
        }

        var correlationId = Activity.Current?.Id
                            ?? httpContext.TraceIdentifier
                            ?? Guid.NewGuid().ToString("N");

        _logger.LogError(
            exception,
            "Excepção não tratada. CorrelationId={CorrelationId} Path={Path} Method={Method}",
            correlationId,
            httpContext.Request.Path.Value,
            httpContext.Request.Method);

        // Development: mensagem da excepção. Production: genérica (detalhe só no log).
        var detail = GenericMessage;
        if (_env.IsDevelopment())
            detail = exception.GetBaseException().Message;

        httpContext.Response.StatusCode = StatusCodes.Status500InternalServerError;
        await httpContext.Response.WriteAsJsonAsync(
            new ProblemDetails
            {
                Title = "Erro interno",
                Detail = detail,
                Status = StatusCodes.Status500InternalServerError,
                Extensions = { ["correlationId"] = correlationId }
            },
            cancellationToken);
        return true;
    }
}
