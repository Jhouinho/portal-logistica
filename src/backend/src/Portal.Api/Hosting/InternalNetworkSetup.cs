using Microsoft.Extensions.Options;

namespace Portal.Api.Hosting;

/// <summary>
/// Registo de <see cref="InternalNetworkOptions"/> com validação no arranque (ValidateOnStart).
/// Default: Enabled=false — sem impacto até redes confirmadas pela IT.
/// </summary>
public static class InternalNetworkSetup
{
    public static void Configure(IServiceCollection services, IConfiguration configuration)
    {
        services.AddOptions<InternalNetworkOptions>()
            .Bind(configuration.GetSection(InternalNetworkOptions.SectionName))
            .Validate(
                static o => InternalNetworkAccess.TryValidateWhenEnabled(o.Enabled, o.AllowedNetworks, out _),
                "Portal:InternalNetwork:Enabled is true but AllowedNetworks has no valid CIDR entries. " +
                "Configure at least one authorized network or set Enabled to false.")
            .ValidateOnStart();
    }
}
