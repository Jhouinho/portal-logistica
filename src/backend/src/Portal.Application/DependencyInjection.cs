using Microsoft.Extensions.DependencyInjection;
using Portal.Application.Encomendas;
using Portal.Application.Painel;
using Portal.Application.PrevisoesEntrada;
using Portal.Application.Realtime;

namespace Portal.Application;

public static class DependencyInjection
{
    public static IServiceCollection AddApplication(this IServiceCollection services)
    {
        services.AddScoped<EncomendasService>();
        services.AddScoped<KappsPickingService>();
        services.AddScoped<PickingDossiersService>();
        services.AddScoped<SeparacaoDossiersService>();
        services.AddScoped<PendentesPicagemService>();
        services.AddScoped<PainelService>();
        services.AddScoped<PrevisoesEntradaService>();
        services.AddScoped<ExternalChangeDetector>();
        return services;
    }
}
