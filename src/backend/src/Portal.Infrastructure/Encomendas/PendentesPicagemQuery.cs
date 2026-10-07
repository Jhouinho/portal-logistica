using System.Text;
using Dapper;
using Microsoft.Data.SqlClient;
using Microsoft.Extensions.Options;
using Portal.Application.Encomendas;
using Portal.Infrastructure.Options;

namespace Portal.Infrastructure.Encomendas;

/// <summary>
/// Query set-based: encomendas candidatas → todas as linhas → Agg66/Kapps →
/// started POR ENCOMENDA (antes de filtros de artigo/cor) → Pending híbrido → Pending &gt; 0.
/// Não altera TemLinhaPorSeparar / temQtt66 / views Kapps.
/// </summary>
public sealed class PendentesPicagemQuery : IPendentesPicagemQuery
{
    private readonly PhcOptions _options;

    public PendentesPicagemQuery(IOptions<PhcOptions> options)
    {
        _options = options.Value;
    }

    public async Task<IReadOnlyList<PendentesPicagemLinhaDto>> ListarLinhasPendentesAsync(
        PendentesPicagemFiltro filtro,
        int serieEncomendasNdos,
        int seriePickingNdos,
        CancellationToken cancellationToken = default)
    {
        await using var connection = new SqlConnection(_options.ConnectionString);
        await connection.OpenAsync(cancellationToken);

        // Filtros de documento/encomenda — entram no universo antes do started.
        var orderWhere = new StringBuilder("""
            WHERE bo.ndos = @serieEncomendas
              AND ISNULL(bo.fechada, 0) = 0
              AND ISNULL(CAST(bo3.u_pickrdy AS int), 0) = 1
            """);
        var p = new DynamicParameters();
        p.Add("serieEncomendas", serieEncomendasNdos);
        p.Add("seriePicking", seriePickingNdos);

        if (filtro.DataDe is not null)
        {
            orderWhere.Append(" AND CAST(bo.dataobra AS date) >= @dataDe");
            p.Add("dataDe", filtro.DataDe.Value.Date);
        }

        if (filtro.DataAte is not null)
        {
            orderWhere.Append(" AND CAST(bo.dataobra AS date) <= @dataAte");
            p.Add("dataAte", filtro.DataAte.Value.Date);
        }

        if (filtro.Obrano is not null)
        {
            orderWhere.Append(" AND bo.obrano = @obrano");
            p.Add("obrano", filtro.Obrano.Value);
        }

        if (!string.IsNullOrWhiteSpace(filtro.ClienteNomeContem))
        {
            orderWhere.Append(" AND (bo.nome LIKE @cliente OR ISNULL(bo.nome2, '') LIKE @cliente)");
            p.Add("cliente", "%" + filtro.ClienteNomeContem.Trim() + "%");
        }

        // Filtros de linha — só depois do started por encomenda.
        var lineWhere = new StringBuilder();
        if (!string.IsNullOrWhiteSpace(filtro.ArtigoRef))
        {
            lineWhere.Append(" AND calc.ref LIKE @artigoRef");
            p.Add("artigoRef", "%" + filtro.ArtigoRef.Trim() + "%");
        }

        if (!string.IsNullOrWhiteSpace(filtro.ArtigoCor))
        {
            lineWhere.Append(" AND calc.cor LIKE @artigoCor");
            p.Add("artigoCor", "%" + filtro.ArtigoCor.Trim() + "%");
        }

        var sql = $"""
            ;WITH orders AS (
                SELECT
                    RTRIM(bo.bostamp) AS bostamp,
                    CAST(bo.obrano AS int) AS numero_encomenda,
                    bo.no AS cliente_no,
                    LTRIM(RTRIM(bo.nome)) AS cliente_nome,
                    LTRIM(RTRIM(ISNULL(bo.nome2, ''))) AS cliente_nome2,
                    CASE
                        WHEN bo3.TAXPOINTDT IS NULL OR YEAR(bo3.TAXPOINTDT) < 1950 THEN CAST(NULL AS datetime)
                        ELSE CAST(bo3.TAXPOINTDT AS datetime)
                    END AS data_entrega,
                    LTRIM(RTRIM(ISNULL(bo3.u_modExp, ''))) AS metodo_expedicao
                FROM dbo.bo bo WITH (NOLOCK)
                LEFT JOIN dbo.bo3 bo3 WITH (NOLOCK)
                    ON bo3.bo3stamp COLLATE DATABASE_DEFAULT = bo.bostamp COLLATE DATABASE_DEFAULT
                {orderWhere}
            ),
            all_lines AS (
                SELECT
                    RTRIM(bi.bistamp) AS bistamp,
                    o.bostamp,
                    o.numero_encomenda,
                    o.cliente_no,
                    o.cliente_nome,
                    o.cliente_nome2,
                    LTRIM(RTRIM(bi.ref)) AS ref,
                    LTRIM(RTRIM(ISNULL(bi.design, ''))) AS designacao,
                    LTRIM(RTRIM(COALESCE(
                        NULLIF(LTRIM(RTRIM(ISNULL(bi.cor, ''))), ''),
                        NULLIF(LTRIM(RTRIM(ISNULL(bi.u_cor, ''))), ''),
                        ''
                    ))) AS cor,
                    CAST(bi.qtt AS decimal(18, 4)) AS qtt,
                    CAST(bi.qtt2 AS decimal(18, 4)) AS qtt2,
                    o.data_entrega,
                    o.metodo_expedicao
                FROM orders o
                INNER JOIN dbo.bi bi WITH (NOLOCK)
                    ON bi.bostamp COLLATE DATABASE_DEFAULT = o.bostamp COLLATE DATABASE_DEFAULT
            ),
            keys AS (
                SELECT bistamp FROM all_lines
            ),
            agg66 AS (
                SELECT
                    bi66.obistamp AS bistamp,
                    SUM(CAST(bi66.qtt AS decimal(18, 4))) AS sum66
                FROM dbo.bi bi66 WITH (NOLOCK)
                INNER JOIN dbo.bo bo66 WITH (NOLOCK)
                    ON bo66.bostamp COLLATE DATABASE_DEFAULT = bi66.bostamp COLLATE DATABASE_DEFAULT
                INNER JOIN keys k
                    ON k.bistamp COLLATE DATABASE_DEFAULT = bi66.obistamp COLLATE DATABASE_DEFAULT
                WHERE bo66.ndos = @seriePicking
                GROUP BY bi66.obistamp
            ),
            agg_kapps AS (
                SELECT
                    d.stampbi AS bistamp,
                    SUM(CAST(d.Qty2 AS decimal(18, 4))) AS picked
                FROM dbo.u_Kapps_DossierLin d WITH (NOLOCK)
                INNER JOIN keys k
                    ON k.bistamp COLLATE DATABASE_DEFAULT = d.stampbi COLLATE DATABASE_DEFAULT
                WHERE d.Status = 'A'
                  AND d.Integrada = 'N'
                GROUP BY d.stampbi
            ),
            calc AS (
                SELECT
                    al.*,
                    CAST(ISNULL(a66.sum66, 0) AS decimal(18, 4)) AS sum66,
                    CAST(ISNULL(ak.picked, 0) AS decimal(18, 4)) AS picked,
                    CASE
                        WHEN ISNULL(ak.picked, 0) > 0
                            THEN CAST(al.qtt - al.qtt2 - ISNULL(ak.picked, 0) AS decimal(18, 4))
                        ELSE CAST(al.qtt - ISNULL(a66.sum66, 0) AS decimal(18, 4))
                    END AS pending,
                    CASE
                        WHEN ISNULL(ak.picked, 0) > 0 THEN 'Kapps'
                        ELSE 'Sum66'
                    END AS fonte
                FROM all_lines al
                LEFT JOIN agg66 a66
                    ON a66.bistamp COLLATE DATABASE_DEFAULT = al.bistamp COLLATE DATABASE_DEFAULT
                LEFT JOIN agg_kapps ak
                    ON ak.bistamp COLLATE DATABASE_DEFAULT = al.bistamp COLLATE DATABASE_DEFAULT
            ),
            started_orders AS (
                SELECT DISTINCT bostamp
                FROM calc
                WHERE picked > 0
                   OR sum66 > 0
            )
            SELECT
                calc.bostamp,
                calc.bistamp,
                calc.numero_encomenda,
                calc.cliente_no,
                calc.cliente_nome,
                calc.cliente_nome2,
                calc.ref,
                calc.designacao,
                calc.cor,
                calc.qtt,
                calc.qtt2,
                calc.sum66,
                calc.picked,
                calc.pending,
                calc.fonte,
                calc.data_entrega,
                calc.metodo_expedicao
            FROM calc
            INNER JOIN started_orders so
                ON so.bostamp COLLATE DATABASE_DEFAULT = calc.bostamp COLLATE DATABASE_DEFAULT
            WHERE calc.pending > 0
              {lineWhere}
            ORDER BY calc.numero_encomenda DESC, calc.ref, calc.bistamp;
            """;

        var rows = await connection.QueryAsync<Row>(
            new CommandDefinition(sql, p, cancellationToken: cancellationToken));

        return rows.Select(r => new PendentesPicagemLinhaDto(
            r.bostamp?.Trim() ?? string.Empty,
            r.bistamp?.Trim() ?? string.Empty,
            r.numero_encomenda,
            r.cliente_no,
            r.cliente_nome?.Trim() ?? string.Empty,
            string.IsNullOrWhiteSpace(r.cliente_nome2) ? null : r.cliente_nome2.Trim(),
            r.@ref?.Trim() ?? string.Empty,
            r.designacao?.Trim() ?? string.Empty,
            r.cor?.Trim() ?? string.Empty,
            r.qtt,
            r.qtt2,
            r.sum66,
            r.picked,
            r.pending,
            r.fonte?.Trim() ?? string.Empty,
            r.data_entrega,
            string.IsNullOrWhiteSpace(r.metodo_expedicao) ? null : r.metodo_expedicao.Trim()
        )).ToList();
    }

    private sealed class Row
    {
        public string? bostamp { get; init; }
        public string? bistamp { get; init; }
        public int numero_encomenda { get; init; }
        public int cliente_no { get; init; }
        public string? cliente_nome { get; init; }
        public string? cliente_nome2 { get; init; }
        public string? @ref { get; init; }
        public string? designacao { get; init; }
        public string? cor { get; init; }
        public decimal qtt { get; init; }
        public decimal qtt2 { get; init; }
        public decimal sum66 { get; init; }
        public decimal picked { get; init; }
        public decimal pending { get; init; }
        public string? fonte { get; init; }
        public DateTime? data_entrega { get; init; }
        public string? metodo_expedicao { get; init; }
    }
}
