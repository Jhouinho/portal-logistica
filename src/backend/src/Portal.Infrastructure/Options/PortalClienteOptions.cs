namespace Portal.Infrastructure.Options;

public sealed class PortalClienteOptions
{
    public const string SectionName = "Portal:Cliente";

    /// <summary>Null ou &lt;=0 = aviso de stock baixo desligado.</summary>
    public decimal? StockBaixoLimiar { get; set; }

    public int PedidoMobileNdos { get; set; } = 67;

    /// <summary>
    /// Quando true, novas submissões gravam-se em <c>u_HcaPm*</c> sem criar BO ndos=67.
    /// A leitura continua a incluir pedidos internos mesmo com false.
    /// </summary>
    public bool PedidosInternosEnabled { get; set; }

    /// <summary>
    /// Pastas-raiz permitidas para ler ficheiros de <c>ST.imagem</c> (UNC ou locais).
    /// Vazio = recusar caminhos em disco (só IFL).
    /// </summary>
    public string[] ImagensPastasPermitidas { get; set; } = [];

    /// <summary>
    /// Reescreve prefixos de caminho (ex.: UNC inacessível no IIS local → pasta espelho).
    /// </summary>
    public ImagensPathRewrite[] ImagensPathRewrite { get; set; } = [];
}

public sealed class ImagensPathRewrite
{
    public string From { get; set; } = "";
    public string To { get; set; } = "";
}
