using System.IO;
using Microsoft.AspNetCore.DataProtection;
using Microsoft.EntityFrameworkCore;
using Portal.Api.Hubs;
using Portal.Api.Realtime;
using Portal.Application;
using Portal.Infrastructure;
using Portal.Infrastructure.Auth;
using Portal.Infrastructure.Identity;
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
    builder.Services.AddInfrastructure(builder.Configuration);

    var keysPath = builder.Configuration["DataProtection:KeysPath"];
    if (string.IsNullOrWhiteSpace(keysPath))
        keysPath = Path.Combine(builder.Environment.ContentRootPath, "dp-keys");
    Directory.CreateDirectory(keysPath);
    builder.Services.AddDataProtection()
        .PersistKeysToFileSystem(new DirectoryInfo(keysPath))
        .SetApplicationName("LilianaSerodio.Portal");

    builder.Services.AddAuthorization();
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

    using (var scope = app.Services.CreateScope())
    {
        var db = scope.ServiceProvider.GetRequiredService<PortalIdentityDbContext>();
        var cs = app.Configuration["Phc:ConnectionString"];
        if (!string.IsNullOrWhiteSpace(cs))
        {
            db.Database.Migrate();
            await PortalIdentitySeed.EnsureAdminAsync(app.Services);
        }
    }

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
