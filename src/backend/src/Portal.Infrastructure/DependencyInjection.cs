using Microsoft.AspNetCore.Http;
using Microsoft.AspNetCore.Identity;
using Microsoft.EntityFrameworkCore;
using Microsoft.Extensions.Configuration;
using Microsoft.Extensions.DependencyInjection;
using Microsoft.Extensions.Hosting;
using Portal.Application.Auth;
using Portal.Application.Cliente;
using Portal.Application.Encomendas;
using Portal.Application.Painel;
using Portal.Application.PrevisoesEntrada;
using Portal.Infrastructure.Auth;
using Portal.Infrastructure.Cliente;
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
    public static IServiceCollection AddInfrastructure(
        this IServiceCollection services,
        IConfiguration configuration,
        IHostEnvironment? environment = null)
    {
        services.Configure<PhcOptions>(configuration.GetSection(PhcOptions.SectionName));
        services.Configure<PortalAppOptions>(configuration.GetSection(PortalAppOptions.SectionName));
        services.Configure<PortalClienteOptions>(configuration.GetSection(PortalClienteOptions.SectionName));
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

        var securePolicy = CookieSecurePolicyHelper.Resolve(environment, configuration);

        services.ConfigureApplicationCookie(options =>
        {
            options.Cookie.Name = "ls_portal_auth";
            options.Cookie.HttpOnly = true;
            options.Cookie.SameSite = SameSiteMode.Lax;
            options.Cookie.SecurePolicy = securePolicy;
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

        services.AddAuthentication()
            .AddCookie(ClienteAuthConstants.CookieScheme, options =>
            {
                options.Cookie.Name = ClienteAuthConstants.CookieName;
                options.Cookie.HttpOnly = true;
                options.Cookie.SameSite = SameSiteMode.Lax;
                options.Cookie.SecurePolicy = securePolicy;
                options.SlidingExpiration = true;
                options.ExpireTimeSpan = TimeSpan.FromMinutes(ClienteAuthConstants.SessionMinutes);
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

        services.AddSingleton<IPasswordHasher<ClientePasswordUser>, PasswordHasher<ClientePasswordUser>>();
        services.AddScoped<IClienteAuthService, ClienteAuthService>();
        services.AddScoped<IClienteCatalogoQuery, ClienteCatalogoQuery>();
        services.AddScoped<IClientePedidosService, ClientePedidosService>();

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
