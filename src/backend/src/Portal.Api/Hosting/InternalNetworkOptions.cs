namespace Portal.Api.Hosting;

/// <summary>
/// Restrição do Portal Cliente Mobile à rede interna (<c>Portal:InternalNetwork</c>).
/// Independente de <see cref="PublicEdgeOptions"/> (hostname público ≠ allowlist IP).
/// Default seguro: <see cref="Enabled"/> false — sem impacto até confirmação IT das redes.
/// </summary>
public sealed class InternalNetworkOptions
{
    public const string SectionName = "Portal:InternalNetwork";

    /// <summary>Quando false, o filtro não restringe pedidos.</summary>
    public bool Enabled { get; set; }

    /// <summary>
    /// Redes autorizadas em CIDR (IPv4/IPv6), ex. <c>10.0.0.0/8</c>, <c>fd00::/8</c>.
    /// Com <see cref="Enabled"/> true, lista vazia ou sem CIDR válido = fail-closed (nega tudo o que estiver no âmbito).
    /// </summary>
    public string[] AllowedNetworks { get; set; } = [];

    /// <summary>Status HTTP quando a origem não está autorizada (default 403).</summary>
    public int BlockedStatusCode { get; set; } = StatusCodes.Status403Forbidden;
}
