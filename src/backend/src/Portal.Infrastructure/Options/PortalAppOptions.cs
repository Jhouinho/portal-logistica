namespace Portal.Infrastructure.Options;

public sealed class PortalAppOptions
{
    public const string SectionName = "Portal";

    /// <summary>Base URL do SPA (ex.: http://localhost:5173) para links de convite.</summary>
    public string SpaBaseUrl { get; set; } = "http://localhost:5173";
}
