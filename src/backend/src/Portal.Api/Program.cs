using System.IO;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.DataProtection;
using Microsoft.AspNetCore.HttpOverrides;
using Microsoft.AspNetCore.Identity;
using Portal.Api.Errors;
using Portal.Api.Hubs;
using Portal.Api.Realtime;
using Portal.Application;
using Portal.Application.Cliente;
using Portal.Infrastructure;
using Serilog;

Log.Logger = new LoggerConfiguration()
    .WriteTo.Console()
    .CreateBootstrapLogger();

try
{
    var builder = WebApplication.CreateBuilder(args);

    builder.Host.UseSerilog((ctx, cfg) =>
        cfg.ReadFrom.Configuration(ctx.Configuration)
            .WriteTo.Console()
            .Enrich.FromLogContext());

    builder.Services.AddApplication();
    builder.Services.AddInfrastructure(builder.Configuration, builder.Environment);

    builder.Services.Configure<ForwardedHeadersOptions>(options =>
    {
        options.ForwardedHeaders = ForwardedHeaders.XForwardedFor | ForwardedHeaders.XForwardedProto;
        // IIS / proxy inverso: o esquema HTTPS chega via X-Forwarded-Proto.
        options.KnownNetworks.Clear();
        options.KnownProxies.Clear();
    });

    builder.Services.AddExceptionHandler<PortalExceptionHandler>();
    builder.Services.AddProblemDetails();

    var keysPath = builder.Configuration["DataProtection:KeysPath"];
    if (string.IsNullOrWhiteSpace(keysPath))
        keysPath = Path.Combine(builder.Environment.ContentRootPath, "dp-keys");
    Directory.CreateDirectory(keysPath);
    builder.Services.AddDataProtection()
        .PersistKeysToFileSystem(new DirectoryInfo(keysPath))
        .SetApplicationName("LilianaSerodio.Portal");

    builder.Services.AddAuthorization(options =>
    {
        options.DefaultPolicy = new AuthorizationPolicyBuilder(IdentityConstants.ApplicationScheme)
            .RequireAuthenticatedUser()
            .Build();
        options.AddPolicy(ClienteAuthConstants.PolicyName, policy =>
        {
            policy.AddAuthenticationSchemes(ClienteAuthConstants.CookieScheme);
            policy.RequireAuthenticatedUser();
            policy.RequireClaim(ClienteAuthConstants.ClaimNo);
            policy.RequireClaim(ClienteAuthConstants.ClaimEstab);
        });
    });
    builder.Services.AddControllers();
    builder.Services.AddSignalR();
    builder.Services.AddHostedService<ExternalChangeRealtimeHostedService>();
    builder.Services.AddEndpointsApiExplorer();
    builder.Services.AddSwaggerGen();
    builder.Services.AddHealthChecks();

    var corsOrigins = builder.Configuration.GetSection("Cors:Origins").Get<string[]>()
                      ?? ["http://localhost:5173"];
    builder.Services.AddCors(options =>
    {
        options.AddPolicy("Spa", policy =>
            policy.WithOrigins(corsOrigins)
                .AllowAnyHeader()
                .AllowAnyMethod()
                .AllowCredentials());
    });

    var app = builder.Build();

    // Schema Identity e role Admin: apenas via scripts SQL (029+, 033) ou UI Admin — nunca no arranque.

    app.UseForwardedHeaders();
    app.UseExceptionHandler();

    if (app.Environment.IsDevelopment())
    {
        app.UseSwagger();
        app.UseSwaggerUI();
    }

    app.UseSerilogRequestLogging();
    app.UseCors("Spa");
    // SPA estática (IIS / publish com wwwroot) — mesmo origin que /api e /hubs (cookies).
    app.UseDefaultFiles();
    app.UseStaticFiles();
    app.UseAuthentication();
    app.UseAuthorization();
    app.MapControllers();
    app.MapHub<OperacoesHub>(OperacoesHub.Path);
    app.MapHub<TvHub>(TvHub.Path);
    app.MapHealthChecks("/health");
    app.MapFallbackToFile("index.html");

    app.Run();
}
catch (Exception ex)
{
    Log.Fatal(ex, "API terminou inesperadamente");
}
finally
{
    Log.CloseAndFlush();
}

public partial class Program;
