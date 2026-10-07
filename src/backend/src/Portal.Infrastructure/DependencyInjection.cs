using Microsoft.AspNetCore.Http;
using Microsoft.AspNetCore.Identity;
using Microsoft.EntityFrameworkCore;
using Microsoft.Extensions.Configuration;
using Microsoft.Extensions.DependencyInjection;
using Portal.Application.Auth;
using Portal.Application.Encomendas;
using Portal.Application.Painel;
using Portal.Application.PrevisoesEntrada;
using Portal.Infrastructure.Auth;
using Portal.Infrastructure.Encomendas;
using Portal.Infrastructure.Identity;
using Portal.Infrastructure.Options;
using Portal.Application.Realtime;
using Portal.Infrastructure.Painel;
using Portal.Infrastructure.PrevisoesEntrada;
using Portal.Infrastructure.Realtime;

namespace Portal.Infrastructure;

public static class DependencyInjection
{
    public static IServiceCollection AddInfrastructure(this IServiceCollection services, IConfiguration configuration)
    {
        services.Configure<PhcOptions>(configuration.GetSection(PhcOptions.SectionName));
        services.Configure<PortalAppOptions>(configuration.GetSection(PortalAppOptions.SectionName));
        services.Configure<PlaneamentoOptions>(configuration.GetSection(PlaneamentoOptions.SectionName));
        services.Configure<PlaneamentoSettings>(configuration.GetSection(PlaneamentoSettings.SectionName));
        services.Configure<SerieEncomendasSettings>(configuration.GetSection(SerieEncomendasSettings.SectionName));

        var connectionString = configuration.GetSection(PhcOptions.SectionName)["ConnectionString"]
                               ?? configuration.GetConnectionString("Phc")
                               ?? string.Empty;

        services.AddDbContext<PortalIdentityDbContext>(options =>
            options.UseSqlServer(connectionString));

        services
            .AddIdentity<PortalUserIdentity, IdentityRole>(options =>
            {
                options.User.RequireUniqueEmail = true;
                options.Password.RequiredLength = 8;
                options.Password.RequireDigit = true;
                options.Password.RequireLowercase = true;
                options.Password.RequireUppercase = true;
                options.Password.RequireNonAlphanumeric = false;
                options.Lockout.AllowedForNewUsers = true;
                options.Lockout.MaxFailedAccessAttempts = 5;
                options.Lockout.DefaultLockoutTimeSpan = TimeSpan.FromMinutes(15);
            })
            .AddEntityFrameworkStores<PortalIdentityDbContext>()
            .AddDefaultTokenProviders();

        services.ConfigureApplicationCookie(options =>
        {
            options.Cookie.Name = "ls_portal_auth";
            options.Cookie.HttpOnly = true;
            options.Cookie.SameSite = SameSiteMode.Lax;
            options.Cookie.SecurePolicy = CookieSecurePolicy.SameAsRequest;
            options.SlidingExpiration = true;
            options.ExpireTimeSpan = TimeSpan.FromHours(8);
            options.Events.OnRedirectToLogin = context =>
            {
                context.Response.StatusCode = StatusCodes.Status401Unauthorized;
                return Task.CompletedTask;
            };
            options.Events.OnRedirectToAccessDenied = context =>
            {
                context.Response.StatusCode = StatusCodes.Status403Forbidden;
                return Task.CompletedTask;
            };
        });

        services.AddScoped<IUserLookup, UserLookup>();
        services.AddScoped<IPhcAdminUsers, PhcAdminUsers>();
        services.AddScoped<AdminUtilizadoresService>();
        services.AddScoped<IEncomendasQuery, EncomendasQuery>();
        services.AddScoped<IEncomendasCommands, EncomendasCommands>();
        services.AddScoped<IKappsPickingQuery, KappsPickingQuery>();
        services.AddScoped<IPickingDossiersQuery, PickingDossiersQuery>();
        services.AddScoped<IPickingDossiersCommands, PickingDossiersCommands>();
        services.AddScoped<IPendentesPicagemQuery, PendentesPicagemQuery>();
        services.AddScoped<IPainelQuery, PainelQuery>();
        services.AddScoped<IPrevisoesEntradaStore, PrevisoesEntradaStore>();
        services.AddScoped<IExternalChangeCursorQuery, ExternalChangeCursorQuery>();
        return services;
    }
}
