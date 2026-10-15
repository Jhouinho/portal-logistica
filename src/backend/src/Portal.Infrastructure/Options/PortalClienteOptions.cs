namespace Portal.Infrastructure.Options;

public sealed class PortalClienteOptions
{
    public const string SectionName = "Portal:Cliente";

    /// <summary>Null ou &lt;=0 = aviso de stock baixo desligado.</summary>
    public decimal? StockBaixoLimiar { get; set; }

    public int PedidoMobileNdos { get; set; } = 67;
}
