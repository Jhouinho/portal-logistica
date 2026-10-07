using Dapper;
using Microsoft.Data.SqlClient;
using Microsoft.Extensions.Options;
using Portal.Application.Painel;
using Portal.Infrastructure.Options;

namespace Portal.Infrastructure.Painel;

public sealed class PainelQuery : IPainelQuery
{
    private readonly PhcOptions _options;

    public PainelQuery(IOptions<PhcOptions> options)
    {
        _options = options.Value;
    }

    public async Task<IReadOnlyList<PainelEncomendaAggRow>> ListarAbertasParaKpisAsync(
        int serieNdos,
        CancellationToken cancellationToken = default)
    {
        await using var connection = new SqlConnection(_options.ConnectionString);
        await connection.OpenAsync(cancellationToken);

        const string sql = """
            SELECT
                v.dataobra AS DataObra,
                CONVERT(varchar(12), v.ousrhora) AS Hora,
                v.cliente_no AS ClienteNo,
                v.quantidade_restante_total AS QuantidadePorSatisfazer,
                v.quantidade_autorizada_total AS QuantidadeAutorizada
            FROM dbo.view_HCA_encomendas_abertas v
            WHERE v.ndos = @serieNdos
              AND CAST(ISNULL(v.pronta_picking, 0) AS bit) = 0;
            """;

        var rows = await connection.QueryAsync<PainelEncomendaAggRow>(
            new CommandDefinition(sql, new { serieNdos }, cancellationToken: cancellationToken));

        return rows.ToList();
    }

    public async Task<int> ContarArtigosEmRuturaAsync(CancellationToken cancellationToken = default)
    {
        await using var connection = new SqlConnection(_options.ConnectionString);
        await connection.OpenAsync(cancellationToken);

        const string sql = """
            SELECT COUNT(1)
            FROM dbo.view_HCA_rastreio_artigos v
            WHERE v.em_rutura = 1;
            """;

        return await connection.ExecuteScalarAsync<int>(
            new CommandDefinition(sql, cancellationToken: cancellationToken));
    }

    public async Task<CentroEstadosContagemRow> ContarEstadosCentroAsync(
        int serieNdos,
        int seriePickingNdos,
        int serieSeparacaoNdos,
        CancellationToken cancellationToken = default)
    {
        await using var connection = new SqlConnection(_options.ConnectionString);
        await connection.OpenAsync(cancellationToken);

        const string sql = """
            SELECT
                (
                    SELECT COUNT(1)
                    FROM dbo.view_HCA_encomendas_abertas v
                    WHERE v.ndos = @serieNdos
                      AND CAST(ISNULL(v.pronta_picking, 0) AS bit) = 0
                ) AS EmAberto,
                (
                    SELECT COUNT(1)
                    FROM dbo.view_HCA_encomendas_abertas v
                    WHERE v.ndos = @serieNdos
                      AND CAST(ISNULL(v.pronta_picking, 0) AS bit) = 1
                      AND EXISTS (
                          SELECT 1
                          FROM dbo.bi bi1 WITH (NOLOCK)
                          WHERE bi1.bostamp COLLATE DATABASE_DEFAULT
                                = v.bostamp COLLATE DATABASE_DEFAULT
                            AND bi1.qtt > ISNULL((
                                  SELECT SUM(ISNULL(bi66.qtt, 0))
                                  FROM dbo.bi bi66 WITH (NOLOCK)
                                  INNER JOIN dbo.bo bo66 WITH (NOLOCK)
                                      ON bo66.bostamp COLLATE DATABASE_DEFAULT
                                       = bi66.bostamp COLLATE DATABASE_DEFAULT
                                  WHERE bo66.ndos = @seriePickingNdos
                                    AND bi66.obistamp COLLATE DATABASE_DEFAULT
                                        = bi1.bistamp COLLATE DATABASE_DEFAULT
                              ), 0)
                      )
                ) AS EmPicking,
                (
                    SELECT COUNT(1)
                    FROM dbo.bo bo WITH (NOLOCK)
                    WHERE bo.ndos = @seriePickingNdos
                      AND ISNULL(bo.fechada, 0) = 0
                ) AS Expedicao,
                (
                    SELECT COUNT(1)
                    FROM dbo.bo bo WITH (NOLOCK)
                    LEFT JOIN dbo.bo3 bo3 WITH (NOLOCK)
                        ON bo3.bo3stamp COLLATE DATABASE_DEFAULT = bo.bostamp COLLATE DATABASE_DEFAULT
                    WHERE bo.ndos = @seriePickingNdos
                      AND ISNULL(bo.fechada, 0) = 0
                      AND CAST(ISNULL(bo3.u_chkin, 0) AS bit) = 0
                ) AS Separado,
                (
                    SELECT COUNT(1)
                    FROM dbo.bo bo WITH (NOLOCK)
                    INNER JOIN dbo.bo3 bo3 WITH (NOLOCK)
                        ON bo3.bo3stamp COLLATE DATABASE_DEFAULT = bo.bostamp COLLATE DATABASE_DEFAULT
                    WHERE bo.ndos = @seriePickingNdos
                      AND ISNULL(bo.fechada, 0) = 0
                      AND CAST(ISNULL(bo3.u_chkin, 0) AS bit) = 1
                ) AS EmEntrega,
                (
                    SELECT COUNT(1)
                    FROM dbo.bo bo WITH (NOLOCK)
                    WHERE bo.ndos = @serieSeparacaoNdos
                      AND ISNULL(bo.fechada, 0) = 0
                ) AS Expedido,
                (
                    SELECT COUNT(1)
                    FROM dbo.bo bo WITH (NOLOCK)
                    WHERE bo.ndos = @serieSeparacaoNdos
                      AND ISNULL(bo.fechada, 0) = 1
                ) AS Concluidas;
            """;

        var row = await connection.QuerySingleAsync<CentroEstadosContagemRow>(
            new CommandDefinition(
                sql,
                new
                {
                    serieNdos,
                    seriePickingNdos,
                    serieSeparacaoNdos,
                },
                cancellationToken: cancellationToken));

        return row;
    }

    public async Task<DistribuicaoLogicaContagemRow> ContarDistribuicaoLogicaAsync(
        int serieNdos,
        int seriePickingNdos,
        int serieSeparacaoNdos,
        CancellationToken cancellationToken = default)
    {
        await using var connection = new SqlConnection(_options.ConnectionString);
        await connection.OpenAsync(cancellationToken);

        // Encomenda lógica = bostamp ndos=1. Cadeia: 65.BI.obistamp→66.BI → 66.BI.obistamp→1.BI.
        // Pesos fraccionados em C# (DistribuicaoLogicaCalculator.Contribuir).
        // 66 activo = fechada=0 e SUM(qtt−qtt2)>0; 65 activo = fechada=0.
        // Vários 65 → Tem65=1 (conjunto Em Expedição; sem repartir por documento 65).
        const string sql = """
            ;WITH v1 AS (
                SELECT
                    LTRIM(RTRIM(v.bostamp)) AS bostamp1,
                    CAST(ISNULL(v.pronta_picking, 0) AS bit) AS pickrdy
                FROM dbo.view_HCA_encomendas_abertas v
                WHERE v.ndos = @serieNdos
            ),
            map66 AS (
                SELECT
                    LTRIM(RTRIM(bo.bostamp)) AS bostamp66,
                    CAST(ISNULL(bo3.u_chkin, 0) AS bit) AS chkin,
                    ISNULL((
                        SELECT SUM(bi.qtt - bi.qtt2)
                        FROM dbo.bi bi WITH (NOLOCK)
                        WHERE bi.bostamp COLLATE DATABASE_DEFAULT = bo.bostamp COLLATE DATABASE_DEFAULT
                    ), 0) AS pendente,
                    (
                        SELECT TOP (1) LTRIM(RTRIM(o.bostamp))
                        FROM dbo.bi di WITH (NOLOCK)
                        INNER JOIN dbo.bi oi WITH (NOLOCK)
                            ON oi.bistamp COLLATE DATABASE_DEFAULT = di.obistamp COLLATE DATABASE_DEFAULT
                        INNER JOIN dbo.bo o WITH (NOLOCK)
                            ON o.bostamp COLLATE DATABASE_DEFAULT = oi.bostamp COLLATE DATABASE_DEFAULT
                        WHERE di.bostamp COLLATE DATABASE_DEFAULT = bo.bostamp COLLATE DATABASE_DEFAULT
                          AND o.ndos = @serieNdos
                        ORDER BY o.bostamp
                    ) AS bostamp1
                FROM dbo.bo bo WITH (NOLOCK)
                LEFT JOIN dbo.bo3 bo3 WITH (NOLOCK)
                    ON bo3.bo3stamp COLLATE DATABASE_DEFAULT = bo.bostamp COLLATE DATABASE_DEFAULT
                WHERE bo.ndos = @seriePickingNdos
                  AND ISNULL(bo.fechada, 0) = 0
            ),
            map65 AS (
                SELECT
                    LTRIM(RTRIM(bo.bostamp)) AS bostamp65,
                    COALESCE(
                        (
                            SELECT TOP (1) LTRIM(RTRIM(o.bostamp))
                            FROM dbo.bi di WITH (NOLOCK)
                            INNER JOIN dbo.bi mid WITH (NOLOCK)
                                ON mid.bistamp COLLATE DATABASE_DEFAULT = di.obistamp COLLATE DATABASE_DEFAULT
                            INNER JOIN dbo.bi oi WITH (NOLOCK)
                                ON oi.bistamp COLLATE DATABASE_DEFAULT = mid.obistamp COLLATE DATABASE_DEFAULT
                            INNER JOIN dbo.bo o WITH (NOLOCK)
                                ON o.bostamp COLLATE DATABASE_DEFAULT = oi.bostamp COLLATE DATABASE_DEFAULT
                            WHERE di.bostamp COLLATE DATABASE_DEFAULT = bo.bostamp COLLATE DATABASE_DEFAULT
                              AND o.ndos = @serieNdos
                            ORDER BY o.bostamp
                        ),
                        (
                            SELECT TOP (1) LTRIM(RTRIM(o.bostamp))
                            FROM dbo.bi di WITH (NOLOCK)
                            INNER JOIN dbo.bi oi WITH (NOLOCK)
                                ON oi.bistamp COLLATE DATABASE_DEFAULT = di.obistamp COLLATE DATABASE_DEFAULT
                            INNER JOIN dbo.bo o WITH (NOLOCK)
                                ON o.bostamp COLLATE DATABASE_DEFAULT = oi.bostamp COLLATE DATABASE_DEFAULT
                            WHERE di.bostamp COLLATE DATABASE_DEFAULT = bo.bostamp COLLATE DATABASE_DEFAULT
                              AND o.ndos = @serieNdos
                            ORDER BY o.bostamp
                        )
                    ) AS bostamp1
                FROM dbo.bo bo WITH (NOLOCK)
                WHERE bo.ndos = @serieSeparacaoNdos
                  AND ISNULL(bo.fechada, 0) = 0
            ),
            universe_keys AS (
                SELECT bostamp1 AS k FROM v1
                UNION
                SELECT bostamp1 FROM map66 WHERE bostamp1 IS NOT NULL
                UNION
                SELECT bostamp1 FROM map65 WHERE bostamp1 IS NOT NULL
            ),
            agg66 AS (
                SELECT
                    bostamp1,
                    SUM(CASE WHEN pendente > 0 AND chkin = 0 THEN 1 ELSE 0 END) AS n_sep,
                    SUM(CASE WHEN pendente > 0 AND chkin = 1 THEN 1 ELSE 0 END) AS n_ent
                FROM map66
                WHERE bostamp1 IS NOT NULL
                GROUP BY bostamp1
            ),
            agg65 AS (
                SELECT bostamp1, COUNT_BIG(1) AS n65
                FROM map65
                WHERE bostamp1 IS NOT NULL
                GROUP BY bostamp1
            )
            SELECT
                ISNULL(a66.n_sep, 0) AS N66Separado,
                ISNULL(a66.n_ent, 0) AS N66EmEntrega,
                CAST(CASE WHEN ISNULL(a65.n65, 0) > 0 THEN 1 ELSE 0 END AS bit) AS Tem65,
                CASE
                    WHEN v.bostamp1 IS NULL THEN CAST(NULL AS bit)
                    ELSE v.pickrdy
                END AS ProntaPicking,
                CAST(CASE
                    WHEN v.bostamp1 IS NULL OR v.pickrdy = 0 THEN 0
                    WHEN EXISTS (
                        SELECT 1
                        FROM dbo.bi bi1 WITH (NOLOCK)
                        WHERE bi1.bostamp COLLATE DATABASE_DEFAULT
                              = v.bostamp1 COLLATE DATABASE_DEFAULT
                          AND bi1.qtt > ISNULL((
                                SELECT SUM(ISNULL(bi66.qtt, 0))
                                FROM dbo.bi bi66 WITH (NOLOCK)
                                INNER JOIN dbo.bo bo66 WITH (NOLOCK)
                                    ON bo66.bostamp COLLATE DATABASE_DEFAULT
                                     = bi66.bostamp COLLATE DATABASE_DEFAULT
                                WHERE bo66.ndos = @seriePickingNdos
                                  AND bi66.obistamp COLLATE DATABASE_DEFAULT
                                      = bi1.bistamp COLLATE DATABASE_DEFAULT
                            ), 0)
                    ) THEN 1
                    ELSE 0
                END AS bit) AS AindaEmPicking
            FROM universe_keys u
            LEFT JOIN v1 v ON v.bostamp1 = u.k
            LEFT JOIN agg66 a66 ON a66.bostamp1 = u.k
            LEFT JOIN agg65 a65 ON a65.bostamp1 = u.k;
            """;

        var factos = (await connection.QueryAsync<DistribuicaoLogicaFactoRow>(
            new CommandDefinition(
                sql,
                new
                {
                    serieNdos,
                    seriePickingNdos,
                    serieSeparacaoNdos,
                },
                cancellationToken: cancellationToken))).AsList();

        decimal emAberto = 0, emPicking = 0, separado = 0, emEntrega = 0, emExpedicao = 0, nao = 0;
        foreach (var f in factos)
        {
            var c = DistribuicaoLogicaCalculator.Contribuir(
                f.N66Separado,
                f.N66EmEntrega,
                f.Tem65,
                f.ProntaPicking,
                f.AindaEmPicking);
            emAberto += c.EmAberto;
            emPicking += c.EmPicking;
            separado += c.Separado;
            emEntrega += c.EmEntrega;
            emExpedicao += c.EmExpedicao;
            nao += c.NaoClassificada;
        }

        return new DistribuicaoLogicaContagemRow
        {
            EmAberto = emAberto,
            EmPicking = emPicking,
            Separado = separado,
            EmEntrega = emEntrega,
            EmExpedicao = emExpedicao,
            NaoClassificadas = nao,
            TotalEncomendasLogicas = factos.Count,
        };
    }

    public async Task<IReadOnlyList<TvKappsResumoRow>> ListarTvKappsResumoAsync(
        int serieEncomendasNdos,
        int seriePickingNdos,
        CancellationToken cancellationToken = default)
    {
        await using var connection = new SqlConnection(_options.ConnectionString);
        await connection.OpenAsync(cancellationToken);

        // Agregados por linha alinhados a kappsRecolhidoLinha / kappsPendenteLinha (frontend).
        // Encomendas: resolve 1 PickingKey (mesma ordem que ResolverPickingKeyAsync).
        // Dossiers 66: PickingKey = bostamp.
        const string sql = """
            ;WITH enc AS (
                SELECT
                    LTRIM(RTRIM(v.bostamp)) AS BoStamp
                FROM dbo.view_HCA_encomendas_abertas v
                WHERE v.ndos = @serieEncomendasNdos
                  AND CAST(ISNULL(v.pronta_picking, 0) AS bit) = 1
            ),
            enc_keys AS (
                SELECT e.BoStamp, e.BoStamp AS PickingKey, 0 AS prio
                FROM enc e
                UNION ALL
                SELECT DISTINCT
                    e.BoStamp,
                    LTRIM(RTRIM(bo66.bostamp)) AS PickingKey,
                    1 AS prio
                FROM enc e
                INNER JOIN dbo.bi oi WITH (NOLOCK)
                    ON oi.bostamp COLLATE DATABASE_DEFAULT = e.BoStamp COLLATE DATABASE_DEFAULT
                INNER JOIN dbo.bi di WITH (NOLOCK)
                    ON di.obistamp COLLATE DATABASE_DEFAULT = oi.bistamp COLLATE DATABASE_DEFAULT
                INNER JOIN dbo.bo bo66 WITH (NOLOCK)
                    ON bo66.bostamp COLLATE DATABASE_DEFAULT = di.bostamp COLLATE DATABASE_DEFAULT
                WHERE bo66.ndos = @seriePickingNdos
            ),
            enc_ranked AS (
                SELECT
                    k.BoStamp,
                    k.PickingKey,
                    k.prio,
                    SUM(ISNULL(l.Quantity, 0)) AS qty,
                    SUM(ISNULL(l.QuantityPicked, 0)) AS picked_raw,
                    SUM(ISNULL(l.QuantityPending, 0)) AS pending_raw,
                    ROW_NUMBER() OVER (
                        PARTITION BY k.BoStamp
                        ORDER BY
                            CASE
                                WHEN SUM(ISNULL(l.Quantity, 0)) > 0
                                 AND SUM(ISNULL(l.QuantityPicked, 0)) >= SUM(ISNULL(l.Quantity, 0))
                                THEN 0 ELSE 1
                            END,
                            SUM(ISNULL(l.QuantityPicked, 0)) DESC,
                            k.prio ASC
                    ) AS rn
                FROM enc_keys k
                INNER JOIN dbo.v_Kapps_Picking_Lines l WITH (NOLOCK)
                    ON l.PickingKey COLLATE DATABASE_DEFAULT = k.PickingKey COLLATE DATABASE_DEFAULT
                GROUP BY k.BoStamp, k.PickingKey, k.prio
            ),
            enc_pick AS (
                SELECT BoStamp, PickingKey
                FROM enc_ranked
                WHERE rn = 1
            ),
            enc_agg AS (
                SELECT
                    e.BoStamp,
                    CAST('encomenda' AS varchar(20)) AS Origem,
                    ISNULL(SUM(ISNULL(l.Quantity, 0)), 0) AS Qty,
                    ISNULL(SUM(
                        CASE
                            WHEN ISNULL(l.QuantityPicked, 0) > 0 THEN ISNULL(l.QuantityPicked, 0)
                            WHEN ISNULL(l.Quantity, 0) > 0 AND ISNULL(l.QuantityPending, 0) <= 0 THEN ISNULL(l.Quantity, 0)
                            WHEN ISNULL(l.QuantitySatisfied, 0) > 0 THEN ISNULL(l.QuantitySatisfied, 0)
                            ELSE 0
                        END
                    ), 0) AS Picked,
                    ISNULL(SUM(
                        CASE
                            WHEN ISNULL(l.Quantity, 0) > 0 AND ISNULL(l.QuantityPending, 0) <= 0 THEN 0
                            WHEN ISNULL(l.QuantityPending, 0) > 0 THEN ISNULL(l.QuantityPending, 0)
                            ELSE CASE
                                WHEN ISNULL(l.Quantity, 0) - (
                                    CASE
                                        WHEN ISNULL(l.QuantityPicked, 0) > 0 THEN ISNULL(l.QuantityPicked, 0)
                                        WHEN ISNULL(l.Quantity, 0) > 0 AND ISNULL(l.QuantityPending, 0) <= 0 THEN ISNULL(l.Quantity, 0)
                                        WHEN ISNULL(l.QuantitySatisfied, 0) > 0 THEN ISNULL(l.QuantitySatisfied, 0)
                                        ELSE 0
                                    END
                                ) > 0
                                THEN ISNULL(l.Quantity, 0) - (
                                    CASE
                                        WHEN ISNULL(l.QuantityPicked, 0) > 0 THEN ISNULL(l.QuantityPicked, 0)
                                        WHEN ISNULL(l.Quantity, 0) > 0 AND ISNULL(l.QuantityPending, 0) <= 0 THEN ISNULL(l.Quantity, 0)
                                        WHEN ISNULL(l.QuantitySatisfied, 0) > 0 THEN ISNULL(l.QuantitySatisfied, 0)
                                        ELSE 0
                                    END
                                )
                                ELSE 0
                            END
                        END
                    ), 0) AS Pending,
                    pk.PickingKey AS ActivityKey
                FROM enc e
                LEFT JOIN enc_pick pk
                    ON pk.BoStamp COLLATE DATABASE_DEFAULT = e.BoStamp COLLATE DATABASE_DEFAULT
                LEFT JOIN dbo.v_Kapps_Picking_Lines l WITH (NOLOCK)
                    ON pk.PickingKey IS NOT NULL
                   AND l.PickingKey COLLATE DATABASE_DEFAULT = pk.PickingKey COLLATE DATABASE_DEFAULT
                GROUP BY e.BoStamp, pk.PickingKey
            ),
            -- Dossiers 66 abertos (com ou sem check-in): progresso Kapps no Centro/TV.
            -- u_chkin distingue Separado vs A Preparar Entrega nas listas/KPIs, não no resumo Kapps.
            dos AS (
                SELECT
                    LTRIM(RTRIM(bo.bostamp)) AS BoStamp
                FROM dbo.bo bo WITH (NOLOCK)
                WHERE bo.ndos = @seriePickingNdos
                  AND ISNULL(bo.fechada, 0) = 0
            ),
            dos_agg AS (
                SELECT
                    d.BoStamp,
                    CAST('dossier66' AS varchar(20)) AS Origem,
                    ISNULL(SUM(ISNULL(l.Quantity, 0)), 0) AS Qty,
                    ISNULL(SUM(
                        CASE
                            WHEN ISNULL(l.QuantityPicked, 0) > 0 THEN ISNULL(l.QuantityPicked, 0)
                            WHEN ISNULL(l.Quantity, 0) > 0 AND ISNULL(l.QuantityPending, 0) <= 0 THEN ISNULL(l.Quantity, 0)
                            WHEN ISNULL(l.QuantitySatisfied, 0) > 0 THEN ISNULL(l.QuantitySatisfied, 0)
                            ELSE 0
                        END
                    ), 0) AS Picked,
                    ISNULL(SUM(
                        CASE
                            WHEN ISNULL(l.Quantity, 0) > 0 AND ISNULL(l.QuantityPending, 0) <= 0 THEN 0
                            WHEN ISNULL(l.QuantityPending, 0) > 0 THEN ISNULL(l.QuantityPending, 0)
                            ELSE CASE
                                WHEN ISNULL(l.Quantity, 0) - (
                                    CASE
                                        WHEN ISNULL(l.QuantityPicked, 0) > 0 THEN ISNULL(l.QuantityPicked, 0)
                                        WHEN ISNULL(l.Quantity, 0) > 0 AND ISNULL(l.QuantityPending, 0) <= 0 THEN ISNULL(l.Quantity, 0)
                                        WHEN ISNULL(l.QuantitySatisfied, 0) > 0 THEN ISNULL(l.QuantitySatisfied, 0)
                                        ELSE 0
                                    END
                                ) > 0
                                THEN ISNULL(l.Quantity, 0) - (
                                    CASE
                                        WHEN ISNULL(l.QuantityPicked, 0) > 0 THEN ISNULL(l.QuantityPicked, 0)
                                        WHEN ISNULL(l.Quantity, 0) > 0 AND ISNULL(l.QuantityPending, 0) <= 0 THEN ISNULL(l.Quantity, 0)
                                        WHEN ISNULL(l.QuantitySatisfied, 0) > 0 THEN ISNULL(l.QuantitySatisfied, 0)
                                        ELSE 0
                                    END
                                )
                                ELSE 0
                            END
                        END
                    ), 0) AS Pending,
                    d.BoStamp AS ActivityKey
                FROM dos d
                LEFT JOIN dbo.v_Kapps_Picking_Lines l WITH (NOLOCK)
                    ON l.PickingKey COLLATE DATABASE_DEFAULT = d.BoStamp COLLATE DATABASE_DEFAULT
                GROUP BY d.BoStamp
            ),
            base AS (
                SELECT * FROM enc_agg
                UNION ALL
                SELECT * FROM dos_agg
            )
            SELECT
                b.BoStamp,
                b.Origem,
                b.Qty,
                b.Picked,
                b.Pending,
                CASE WHEN ISNULL(a.TerminalID, 0) > 0 THEN a.TerminalID ELSE NULL END AS ActiveTerminalId,
                CASE
                    WHEN ISNULL(a.TerminalID, 0) > 0 THEN
                        CASE
                            WHEN LTRIM(RTRIM(ISNULL(a.TerminalDescription, ''))) <> ''
                                THEN LTRIM(RTRIM(a.TerminalDescription))
                            ELSE CONCAT('Terminal ', CONVERT(varchar(20), a.TerminalID))
                        END
                    ELSE NULL
                END AS ActiveTerminalLabel,
                NULLIF(LTRIM(RTRIM(ISNULL(a.UserID, ''))), '') AS ActiveUserId
            FROM base b
            OUTER APPLY (
                SELECT TOP (1)
                    d.TerminalID,
                    LTRIM(RTRIM(d.UserID)) AS UserID,
                    LTRIM(RTRIM(t.TerminalDescription)) AS TerminalDescription
                FROM dbo.u_Kapps_DossierLin d WITH (NOLOCK)
                LEFT JOIN dbo.u_Kapps_Terminals t WITH (NOLOCK)
                    ON LTRIM(RTRIM(t.TerminalID)) = CONVERT(varchar(20), d.TerminalID)
                WHERE b.ActivityKey IS NOT NULL
                  AND d.StampBo COLLATE DATABASE_DEFAULT = b.ActivityKey COLLATE DATABASE_DEFAULT
                  AND (
                    ISNULL(d.TerminalID, 0) <> 0
                    OR LTRIM(RTRIM(ISNULL(d.UserID, ''))) <> ''
                  )
                ORDER BY
                    CASE WHEN ISNULL(d.TerminalID, 0) <> 0 THEN 0 ELSE 1 END,
                    d.MovDate DESC,
                    d.MovTime DESC
            ) a;
            """;

        var rows = await connection.QueryAsync<TvKappsResumoRow>(
            new CommandDefinition(
                sql,
                new { serieEncomendasNdos, seriePickingNdos },
                cancellationToken: cancellationToken));

        return rows.ToList();
    }
}
