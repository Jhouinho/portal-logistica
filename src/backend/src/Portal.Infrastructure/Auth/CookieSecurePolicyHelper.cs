using Microsoft.AspNetCore.Http;
using Microsoft.Extensions.Configuration;
using Microsoft.Extensions.Hosting;

namespace Portal.Infrastructure.Auth;

public static class CookieSecurePolicyHelper
{
    public const string AllowInsecureConfigKey = "Portal:AllowInsecureAuthCookies";
    public const string ExplicitPolicyConfigKey = "Portal:CookieSecurePolicy";

    /// <summary>
    /// Secure por omissão em todos os ambientes.
    /// SameAsRequest só com Development + Portal:AllowInsecureAuthCookies=true
    /// (ou política explícita Always). Políticas inseguras fora de Development são ignoradas.
    /// </summary>
    public static CookieSecurePolicy Resolve(IHostEnvironment? environment, IConfiguration configuration)
    {
        ArgumentNullException.ThrowIfNull(configuration);

        var allowInsecure = configuration.GetValue(AllowInsecureConfigKey, false);
        var isDev = environment?.IsDevelopment() == true;

        var explicitRaw = configuration[ExplicitPolicyConfigKey];
        if (!string.IsNullOrWhiteSpace(explicitRaw)
            && Enum.TryParse<CookieSecurePolicy>(explicitRaw, ignoreCase: true, out var explicitPolicy))
        {
            if (explicitPolicy == CookieSecurePolicy.Always)
                return CookieSecurePolicy.Always;

            if (allowInsecure && isDev)
                return explicitPolicy;

            // Pedido inseguro fora de Development seguro: forçar Always.
            return CookieSecurePolicy.Always;
        }

        if (allowInsecure && isDev)
            return CookieSecurePolicy.SameAsRequest;

        return CookieSecurePolicy.Always;
    }
}
