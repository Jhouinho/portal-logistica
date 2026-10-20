using Microsoft.AspNetCore.Http;
using Microsoft.Extensions.Configuration;
using Microsoft.Extensions.Hosting;

namespace Portal.Infrastructure.Auth;

public static class CookieSecurePolicyHelper
{
    public const string AllowInsecureConfigKey = "Portal:AllowInsecureAuthCookies";
    /// <summary>
    /// Opt-in explícito para HTTP local (ex. IIS no PC + telemóvel na LAN).
    /// Nunca activar em UAT/Produção reais.
    /// </summary>
    public const string AllowInsecureHttpCookiesConfigKey = "Portal:AllowInsecureHttpCookies";
    public const string ExplicitPolicyConfigKey = "Portal:CookieSecurePolicy";

    /// <summary>
    /// Secure por omissão em todos os ambientes.
    /// SameAsRequest só com:
    /// - Development + Portal:AllowInsecureAuthCookies=true, ou
    /// - Portal:AllowInsecureHttpCookies=true (ensaio HTTP local / LAN).
    /// Políticas inseguras fora destes casos são ignoradas.
    /// </summary>
    public static CookieSecurePolicy Resolve(IHostEnvironment? environment, IConfiguration configuration)
    {
        ArgumentNullException.ThrowIfNull(configuration);

        var allowInsecure = configuration.GetValue(AllowInsecureConfigKey, false);
        var allowInsecureHttp = configuration.GetValue(AllowInsecureHttpCookiesConfigKey, false);
        var isDev = environment?.IsDevelopment() == true;
        var insecureAllowed = allowInsecureHttp || (allowInsecure && isDev);

        var explicitRaw = configuration[ExplicitPolicyConfigKey];
        if (!string.IsNullOrWhiteSpace(explicitRaw)
            && Enum.TryParse<CookieSecurePolicy>(explicitRaw, ignoreCase: true, out var explicitPolicy))
        {
            if (explicitPolicy == CookieSecurePolicy.Always)
                return CookieSecurePolicy.Always;

            if (insecureAllowed)
                return explicitPolicy;

            return CookieSecurePolicy.Always;
        }

        if (insecureAllowed)
            return CookieSecurePolicy.SameAsRequest;

        return CookieSecurePolicy.Always;
    }
}
