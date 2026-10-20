namespace Portal.Infrastructure.Options;

public sealed class PortalAppOptions
{
    public const string SectionName = "Portal";

    /// <summary>Base URL do SPA (ex.: http://localhost:5173) para links de convite.</summary>
    public string SpaBaseUrl { get; set; } = "http://localhost:5173";

    /// <summary>
    /// Permite cookies sem Secure apenas em Development (HTTP localhost).
    /// Em Staging/UAT/Production deve permanecer false.
    /// </summary>
    public bool AllowInsecureAuthCookies { get; set; }

    /// <summary>
    /// Opt-in para HTTP local (IIS no PC + telemóvel na LAN). Nunca em UAT/Prod reais.
    /// </summary>
    public bool AllowInsecureHttpCookies { get; set; }
}
