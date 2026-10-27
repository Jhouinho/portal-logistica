namespace Portal.Infrastructure.Encomendas;

/// <summary>
/// Fragmentos SQL da resolução atómica da encomenda original (ndos=1) em
/// <see cref="PickingDossiersQuery"/>. Critério de desempate (empate em obrano):
/// <c>obrano DESC</c>, depois <c>bostamp COLLATE Latin1_General_BIN DESC</c>
/// (sem RTRIM — identidade do stamp intacta). Espelhado em
/// <c>OrigemEncomendaResolver</c> via <c>string.CompareOrdinal</c> no BoStamp tal como vem.
/// </summary>
public static class PickingDossiersOrigemSql
{
    /// <summary>Campos de origem no SELECT interno (mesmo BO para nº/data/hora; hop1 antes de hop2).</summary>
    public const string SelectCamposOrigem = """
                    COALESCE(origem_h1.obrano, origem_h2.obrano) AS obrano_origem,
                    CASE
                        WHEN origem_h1.obrano IS NOT NULL THEN origem_h1.ousrdata
                        ELSE origem_h2.ousrdata
                    END AS ousrdata_origem,
                    CASE
                        WHEN origem_h1.obrano IS NOT NULL THEN origem_h1.ousrhora
                        ELSE origem_h2.ousrhora
                    END AS ousrhora_origem
                    """;

    /// <summary>Hop1: 66 → 1 (BI.obistamp directo).</summary>
    public const string OuterApplyHop1_66para1 = """
                OUTER APPLY (
                    SELECT TOP (1)
                        o.obrano,
                        o.ousrdata,
                        CONVERT(varchar(12), o.ousrhora) AS ousrhora
                    FROM dbo.bi di WITH (NOLOCK)
                    INNER JOIN dbo.bi oi WITH (NOLOCK)
                        ON oi.bistamp COLLATE DATABASE_DEFAULT = di.obistamp COLLATE DATABASE_DEFAULT
                    INNER JOIN dbo.bo o WITH (NOLOCK)
                        ON o.bostamp COLLATE DATABASE_DEFAULT = oi.bostamp COLLATE DATABASE_DEFAULT
                    WHERE di.bostamp COLLATE DATABASE_DEFAULT = bo.bostamp COLLATE DATABASE_DEFAULT
                      AND o.ndos = @serieEncomendaDoc
                    ORDER BY o.obrano DESC, o.bostamp COLLATE Latin1_General_BIN DESC
                ) origem_h1
                """;

    /// <summary>Hop2: 65 → 66 → 1.</summary>
    public const string OuterApplyHop2_65para66para1 = """
                OUTER APPLY (
                    SELECT TOP (1)
                        o1.obrano,
                        o1.ousrdata,
                        CONVERT(varchar(12), o1.ousrhora) AS ousrhora
                    FROM dbo.bi di WITH (NOLOCK)
                    INNER JOIN dbo.bi mid WITH (NOLOCK)
                        ON mid.bistamp COLLATE DATABASE_DEFAULT = di.obistamp COLLATE DATABASE_DEFAULT
                    INNER JOIN dbo.bi oi WITH (NOLOCK)
                        ON oi.bistamp COLLATE DATABASE_DEFAULT = mid.obistamp COLLATE DATABASE_DEFAULT
                    INNER JOIN dbo.bo o1 WITH (NOLOCK)
                        ON o1.bostamp COLLATE DATABASE_DEFAULT = oi.bostamp COLLATE DATABASE_DEFAULT
                    WHERE di.bostamp COLLATE DATABASE_DEFAULT = bo.bostamp COLLATE DATABASE_DEFAULT
                      AND o1.ndos = @serieEncomendaDoc
                    ORDER BY o1.obrano DESC, o1.bostamp COLLATE Latin1_General_BIN DESC
                ) origem_h2
                """;

    /// <summary>Colunas de origem no GROUP BY (APPLY ≤1 linha por bo — não multiplica dossiers).</summary>
    public const string GroupByCamposOrigem = """
                    origem_h1.obrano,
                    origem_h1.ousrdata,
                    origem_h1.ousrhora,
                    origem_h2.obrano,
                    origem_h2.ousrdata,
                    origem_h2.ousrhora
                    """;
}
