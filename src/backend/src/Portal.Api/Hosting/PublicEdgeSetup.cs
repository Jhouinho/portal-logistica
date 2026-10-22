using Microsoft.Extensions.Options;

namespace Portal.Api.Hosting;

/// <summary>
/// Registo de <see cref="PublicEdgeOptions"/> com validação no arranque (ValidateOnStart).
/// Default: Enabled=false — sem impacto até config Production explícita.
/// </summary>
public static class PublicEdgeSetup
{
    public static void Configure(IServiceCollection services, IConfiguration configuration)
    {
        services.AddOptions<PublicEdgeOptions>()
            .Bind(configuration.GetSection(PublicEdgeOptions.SectionName))
            .Validate(
                static o => PublicEdgePathMatcher.TryValidateWhenEnabled(o.Enabled, o.PublicHosts, out _),
                "Portal:PublicEdge:Enabled is true but PublicHosts has no valid hostnames. " +
                "Configure at least one public hostname or set Enabled to false.")
            .ValidateOnStart();
    }
}
