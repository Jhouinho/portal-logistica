namespace Portal.Infrastructure.Encomendas;

/// <summary>
/// Fragmentos SQL da resolução da encomenda original (ndos=1) em
/// <see cref="PickingDossiersQuery"/>.
/// </summary>
/// <remarks>
/// Temporário (hotfix produção): origem desligada (NULL) para isolar o 500 em
/// <c>picking-dossiers</c> no SQL Server do cliente. A UI usa
/// <c>COALESCE(obrano_origem, obrano)</c> → mostra o nº do dossier 66.
/// Reactivar hops (MAX/APPLY) só com evidência SQL e teste no mesmo motor.
/// </remarks>
public static class PickingDossiersOrigemSql
{
    /// <summary>Origem desligada — hotfix.</summary>
    public const string SelectCamposOrigem = """
                    CAST(NULL AS int) AS obrano_origem,
                    CAST(NULL AS datetime) AS ousrdata_origem,
                    CAST(NULL AS varchar(12)) AS ousrhora_origem
                    """;

    /// <summary>Legado — vazio (sem APPLY no FROM).</summary>
    public const string OuterApplyHop1_66para1 = "";

    /// <summary>Legado — vazio.</summary>
    public const string OuterApplyHop2_65para66para1 = "";

    /// <summary>Placeholder no GROUP BY (evita vírgula órfã).</summary>
    public const string GroupByCamposOrigem = """
                    bo.bostamp
                    """;

    /// <summary>Contrato hop1 (documentação / testes) — cadeia 66→1.</summary>
    public const string Hop1SqlContrato = """
                    SELECT MAX(o.obrano)
                    FROM dbo.bi di WITH (NOLOCK)
                    INNER JOIN dbo.bi oi WITH (NOLOCK)
                        ON oi.bistamp COLLATE DATABASE_DEFAULT = di.obistamp COLLATE DATABASE_DEFAULT
                    INNER JOIN dbo.bo o WITH (NOLOCK)
                        ON o.bostamp COLLATE DATABASE_DEFAULT = oi.bostamp COLLATE DATABASE_DEFAULT
                    WHERE di.bostamp COLLATE DATABASE_DEFAULT = bo.bostamp COLLATE DATABASE_DEFAULT
                      AND o.ndos = @serieEncomendaDoc
                    """;

    /// <summary>Contrato hop2 (documentação / testes) — cadeia 65→66→1.</summary>
    public const string Hop2SqlContrato = """
                    SELECT MAX(o1.obrano)
                    FROM dbo.bi di WITH (NOLOCK)
                    INNER JOIN dbo.bi mid WITH (NOLOCK)
                        ON mid.bistamp COLLATE DATABASE_DEFAULT = di.obistamp COLLATE DATABASE_DEFAULT
                    INNER JOIN dbo.bi oi WITH (NOLOCK)
                        ON oi.bistamp COLLATE DATABASE_DEFAULT = mid.obistamp COLLATE DATABASE_DEFAULT
                    INNER JOIN dbo.bo o1 WITH (NOLOCK)
                        ON o1.bostamp COLLATE DATABASE_DEFAULT = oi.bostamp COLLATE DATABASE_DEFAULT
                    WHERE di.bostamp COLLATE DATABASE_DEFAULT = bo.bostamp COLLATE DATABASE_DEFAULT
                      AND o1.ndos = @serieEncomendaDoc
                    """;
}
