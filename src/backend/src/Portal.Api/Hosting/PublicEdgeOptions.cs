namespace Portal.Api.Hosting;

/// <summary>
/// Isolamento do hostname público do Portal Mobile (<c>Portal:PublicEdge</c>).
/// Default seguro: desactivado — LAN/UAT sem impacto até Passo B + config Production.
/// </summary>
public sealed class PublicEdgeOptions
{
    public const string SectionName = "Portal:PublicEdge";

    /// <summary>Quando false, o filtro não restringe pedidos (comportamento actual da app).</summary>
    public bool Enabled { get; set; }

    /// <summary>
    /// Hostnames públicos (sem esquema). Comparação case-insensitive.
    /// Vazio com <see cref="Enabled"/> true é configuração inválida (fail-closed no matcher;
    /// o Passo B deve falhar o arranque).
    /// </summary>
    public string[] PublicHosts { get; set; } = [];

    /// <summary>Status HTTP quando o hostname público rejeita o path (default 404).</summary>
    public int BlockedStatusCode { get; set; } = 404;
}
