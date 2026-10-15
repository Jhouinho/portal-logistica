using Microsoft.AspNetCore.Http;

namespace Portal.Infrastructure.Auth;

public static class CookieSecurePolicyHelper
{
    /// <summary>
    /// Produção exige Secure; Development mantém SameAsRequest (HTTP localhost).
    /// </summary>
    public static CookieSecurePolicy ForEnvironment(bool isProduction) =>
        isProduction ? CookieSecurePolicy.Always : CookieSecurePolicy.SameAsRequest;
}
