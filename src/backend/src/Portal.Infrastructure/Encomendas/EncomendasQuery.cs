using System.Data;
using System.Text;
using Dapper;
using Microsoft.Data.SqlClient;
using Microsoft.Extensions.Options;
using Portal.Application.Encomendas;
using Portal.Domain.Encomendas;
using Portal.Infrastructure.Options;

namespace Portal.Infrastructure.Encomendas;

public sealed class EncomendasQuery : IEncomendasQuery
{
    private readonly PhcOptions _options;

    /// <summary>
    /// PR2-B2 / PR3-C — Disponibilidade operacional = Previsto − Alocado (previsão aberta, Ref + BI.u_cor).
    /// Pode ser negativo quando Alocado &gt; Previsto. Sem linha de previsão → 0. Não usa ST.stock.
    /// Mantém o nome de coluna stock_disponivel no SELECT por compatibilidade de mapeamento DTO.
    /// </summary>
    private const string DisponivelPrevisaoSql = """
        ISNULL((
            SELECT TOP (1)
                lin.QuantidadePrevista - ISNULL((
                    SELECT SUM(ISNULL(bi2a.u_qtdaut, 0))
                    FROM dbo.bi2 bi2a WITH (NOLOCK)
                    INNER JOIN dbo.bi bi_a WITH (NOLOCK)
                        ON bi_a.bistamp COLLATE DATABASE_DEFAULT
                         = bi2a.bi2stamp COLLATE DATABASE_DEFAULT
                    WHERE LTRIM(RTRIM(ISNULL(bi2a.u_previd, ''))) COLLATE DATABASE_DEFAULT
                          = CONVERT(varchar(50), p.Id) COLLATE DATABASE_DEFAULT
                      AND LTRIM(RTRIM(bi_a.ref)) COLLATE DATABASE_DEFAULT
                          = LTRIM(RTRIM(l.ref)) COLLATE DATABASE_DEFAULT
                      AND bi_a.u_cor COLLATE DATABASE_DEFAULT
                          = bi_cap.u_cor COLLATE DATABASE_DEFAULT
                ), 0)
            FROM dbo.u_HcaPrevEntrada p WITH (NOLOCK)
            INNER JOIN dbo.u_HcaPrevEntradaLin lin WITH (NOLOCK)
                ON lin.PrevisaoId = p.Id
            INNER JOIN dbo.bi bi_cap WITH (NOLOCK)
                ON bi_cap.bistamp COLLATE DATABASE_DEFAULT
                 = l.bistamp COLLATE DATABASE_DEFAULT
            WHERE ISNULL(p.Fechada, 0) = 0
              AND LTRIM(RTRIM(lin.Ref)) COLLATE DATABASE_DEFAULT
                  = LTRIM(RTRIM(l.ref)) COLLATE DATABASE_DEFAULT
              AND lin.Cor COLLATE DATABASE_DEFAULT
                  = bi_cap.u_cor COLLATE DATABASE_DEFAULT
            ORDER BY p.DataInicio ASC, p.DataFim ASC
        ), 0)
        """;

    /// <summary>
    /// PR4 — Data de entrega = BO3.TAXPOINTDT (leitura). Datas inválidas / sentinel PHC → NULL.
    /// </summary>
    private const string DataEntregaSql = """
        CASE
            WHEN bo3.TAXPOINTDT IS NULL OR YEAR(bo3.TAXPOINTDT) < 1950 THEN CAST(NULL AS datetime)
            ELSE CAST(bo3.TAXPOINTDT AS datetime)
        END
        """;

    /// <summary>
    /// PR6 — Método de expedição = BO3.u_modExp (leitura; valor PHC sem normalização).
    /// </summary>
    private const string MetodoExpedicaoSql = """
        LTRIM(RTRIM(ISNULL(bo3.u_modExp, '')))
        """;

    /// <summary>
    /// Morada de entrega = BO2.u_mEntrega (texto corrido; sem normalização).
    /// Relação: BO.bostamp = BO2.bo2stamp.
    /// </summary>
    private const string MoradaEntregaSql = """
        LTRIM(RTRIM(ISNULL(bo2.u_mEntrega, '')))
        """;

    /// <summary>
    /// Progresso Kapps por encomenda: PickingKey = bostamp da encomenda
    /// OU bostamp de dossier ndos=SeriePicking (66) cujas linhas apontam (obistamp) a esta encomenda.
    /// </summary>
    private string KappsAggApplySql => $"""
        OUTER APPLY (
            SELECT
                SUM(ISNULL(k.Quantity, 0)) AS qty,
                SUM(ISNULL(k.QuantityPicked, 0)) AS picked,
                SUM(ISNULL(k.QuantityPending, 0)) AS pending
            FROM dbo.v_Kapps_Picking_Lines k WITH (NOLOCK)
            WHERE k.PickingKey COLLATE DATABASE_DEFAULT = v.bostamp COLLATE DATABASE_DEFAULT
               OR k.PickingKey COLLATE DATABASE_DEFAULT IN (
                    SELECT DISTINCT bo66.bostamp
                    FROM dbo.bo bo66 WITH (NOLOCK)
                    INNER JOIN dbo.bi di WITH (NOLOCK)
                        ON di.bostamp COLLATE DATABASE_DEFAULT = bo66.bostamp COLLATE DATABASE_DEFAULT
                    INNER JOIN dbo.bi oi WITH (NOLOCK)
                        ON oi.bistamp COLLATE DATABASE_DEFAULT = di.obistamp COLLATE DATABASE_DEFAULT
                    WHERE bo66.ndos = {_options.SeriePickingNdos}
                      AND oi.bostamp COLLATE DATABASE_DEFAULT = v.bostamp COLLATE DATABASE_DEFAULT
               )
        ) kapps
        """;

    /// <summary>
    /// Em Picking: ainda há linha operacional por separar —
    /// <c>BI.qtt &gt; SUM(66.BI.qtt)</c> por <c>obistamp = bistamp</c>
    /// (todos os 66 ligados; sem filtro fechada/u_chkin). Sem 66 → SUM=0 → qtt&gt;0.
    /// </summary>
    private string TemLinhaPorSepararSql => $"""
         AND EXISTS (
            SELECT 1
            FROM dbo.bi bi1 WITH (NOLOCK)
            WHERE bi1.bostamp COLLATE DATABASE_DEFAULT = v.bostamp COLLATE DATABASE_DEFAULT
              AND bi1.qtt > ISNULL((
                    SELECT SUM(ISNULL(bi66.qtt, 0))
                    FROM dbo.bi bi66 WITH (NOLOCK)
                    INNER JOIN dbo.bo bo66 WITH (NOLOCK)
                        ON bo66.bostamp COLLATE DATABASE_DEFAULT
                         = bi66.bostamp COLLATE DATABASE_DEFAULT
                    WHERE bo66.ndos = {_options.SeriePickingNdos}
                      AND bi66.obistamp COLLATE DATABASE_DEFAULT
                          = bi1.bistamp COLLATE DATABASE_DEFAULT
                ), 0)
        )
        """;

    /// <summary>
    /// REGRA B: existe quantidade materializada em ndos=66
    /// (<c>SUM(66.BI.qtt) &gt; 0</c> por <c>obistamp</c>; sem filtro fechada/u_chkin).
    /// </summary>
    private string TemQtt66SelectSqlFor(string bostampExpr) => $"""
        CAST(CASE WHEN EXISTS (
            SELECT 1
            FROM dbo.bi bi1 WITH (NOLOCK)
            WHERE bi1.bostamp COLLATE DATABASE_DEFAULT = {bostampExpr} COLLATE DATABASE_DEFAULT
              AND ISNULL((
                    SELECT SUM(ISNULL(bi66.qtt, 0))
                    FROM dbo.bi bi66 WITH (NOLOCK)
                    INNER JOIN dbo.bo bo66 WITH (NOLOCK)
                        ON bo66.bostamp COLLATE DATABASE_DEFAULT
                         = bi66.bostamp COLLATE DATABASE_DEFAULT
                    WHERE bo66.ndos = {_options.SeriePickingNdos}
                      AND bi66.obistamp COLLATE DATABASE_DEFAULT
                          = bi1.bistamp COLLATE DATABASE_DEFAULT
                ), 0) > 0
        ) THEN 1 ELSE 0 END AS bit)
        """;

    /// <summary>
    /// Estado efectivo: Kapps concluído→3, parcial→2; senão legado u_pickstat (pronta+0→1).
    /// Requer <see cref="KappsAggApplySql"/> no FROM.
    /// Kapps pode deixar QuantityPicked=0 com QuantityPending=0 no fim → trata-se como concluído.
    /// </summary>
    private const string PickStatusEfectivoSql = """
        CASE
            WHEN ISNULL(kapps.qty, 0) > 0
             AND (
                  ISNULL(kapps.picked, 0) >= kapps.qty
                  OR ISNULL(kapps.pending, 0) <= 0
                 ) THEN 3
            WHEN ISNULL(kapps.picked, 0) > 0
             AND ISNULL(kapps.picked, 0) < ISNULL(kapps.qty, 0) THEN 2
            WHEN ISNULL(CAST(v.pronta_picking AS int), 0) = 1
             AND ISNULL(v.pick_status, 0) = 0 THEN 1
            ELSE ISNULL(v.pick_status, 0)
        END
        """;

    public EncomendasQuery(IOptions<PhcOptions> options)
    {
        _options = options.Value;
    }

    public async Task<(IReadOnlyList<EncomendaResumo> Items, int Total)> ListarAbertasAsync(
        EncomendasFiltro filtro,
        int serieNdos,
        CancellationToken cancellationToken = default)
    {
        await using var connection = new SqlConnection(_options.ConnectionString);
        await connection.OpenAsync(cancellationToken);

        var where = new StringBuilder("WHERE v.ndos = @serieNdos");
        var p = new DynamicParameters();
        p.Add("serieNdos", serieNdos);
        var kappsApply = string.Empty;

        if (filtro.DataDe is not null)
        {
            var dataDe = DateQuery.Normalize(filtro.DataDe);
            if (dataDe is not null)
            {
                where.Append(" AND CAST(v.dataobra AS date) >= @dataDe");
                p.Add("dataDe", dataDe.Value, DbType.Date);
            }
        }

        if (filtro.DataAte is not null)
        {
            var dataAte = DateQuery.Normalize(filtro.DataAte);
            if (dataAte is not null)
            {
                where.Append(" AND CAST(v.dataobra AS date) <= @dataAte");
                p.Add("dataAte", dataAte.Value, DbType.Date);
            }
        }

        if (!string.IsNullOrWhiteSpace(filtro.HoraDe))
        {
            var horaDe = TimeQuery.ToSqlTime(TimeQuery.ParseHoraDe(filtro.HoraDe));
            if (horaDe is not null)
            {
                where.Append("""
                     AND TRY_CONVERT(time(0), LTRIM(RTRIM(CONVERT(varchar(12), v.ousrhora)))) >= TRY_CONVERT(time(0), @horaDe)
                    """);
                p.Add("horaDe", horaDe);
            }
        }

        if (!string.IsNullOrWhiteSpace(filtro.HoraAte))
        {
            var horaAte = TimeQuery.ToSqlTime(TimeQuery.ParseHoraAte(filtro.HoraAte));
            if (horaAte is not null)
            {
                where.Append("""
                     AND TRY_CONVERT(time(0), LTRIM(RTRIM(CONVERT(varchar(12), v.ousrhora)))) <= TRY_CONVERT(time(0), @horaAte)
                    """);
                p.Add("horaAte", horaAte);
            }
        }

        if (filtro.ClienteNo is not null)
        {
            where.Append(" AND v.cliente_no = @clienteNo");
            p.Add("clienteNo", filtro.ClienteNo.Value);
        }

        if (!string.IsNullOrWhiteSpace(filtro.ClienteNoContem))
        {
            where.Append(" AND CONVERT(varchar(20), v.cliente_no) LIKE @clienteNoPadrao ESCAPE '\\'");
            p.Add("clienteNoPadrao", $"%{EscapeLike(filtro.ClienteNoContem.Trim())}%");
        }

        if (!string.IsNullOrWhiteSpace(filtro.ArtigoRef) || !string.IsNullOrWhiteSpace(filtro.ArtigoCor))
        {
            where.Append("""
                 AND EXISTS (
                    SELECT 1
                    FROM dbo.view_HCA_encomenda_linhas l
                    WHERE l.bostamp = v.bostamp
                """);

            if (!string.IsNullOrWhiteSpace(filtro.ArtigoRef))
            {
                where.Append("""
                      AND (
                           LTRIM(RTRIM(l.ref)) LIKE @artigoPadrao ESCAPE '\'
                        OR LTRIM(RTRIM(l.design)) LIKE @artigoPadrao ESCAPE '\'
                      )
                    """);
                p.Add("artigoPadrao", $"%{EscapeLike(filtro.ArtigoRef.Trim())}%");
            }

            if (!string.IsNullOrWhiteSpace(filtro.ArtigoCor))
            {
                where.Append("""
                      AND LTRIM(RTRIM(ISNULL(l.cor, ''))) LIKE @corPadrao ESCAPE '\'
                    """);
                p.Add("corPadrao", $"%{EscapeLike(filtro.ArtigoCor.Trim())}%");
            }

            where.Append("""
                )
                """);
        }

        // 0 = ecrã Encomendas; 1 = ecrã Picking (só marcadas).
        if (filtro.ProntaPicking is not null)
        {
            where.Append(" AND ISNULL(CAST(v.pronta_picking AS int), 0) = @prontaPicking");
            p.Add("prontaPicking", filtro.ProntaPicking.Value ? 1 : 0);
            // Em Picking: progresso Kapps (encomenda ou dossier 66 ligado) para badge/filtro;
            // + só documentos com pelo menos uma linha ainda não totalmente separada (SUM 66).
            if (filtro.ProntaPicking.Value)
            {
                kappsApply = KappsAggApplySql;
                where.Append(TemLinhaPorSepararSql);
            }
        }

        if (filtro.PickStatus is not null)
        {
            // Alinhado ao badge Em Picking: progresso Kapps tem prioridade sobre u_pickstat.
            kappsApply = KappsAggApplySql;
            where.Append($"""
                 AND ({PickStatusEfectivoSql}) = @pickStatus
                """);
            p.Add("pickStatus", filtro.PickStatus.Value);
        }

        var pickStatusSelect = string.IsNullOrEmpty(kappsApply)
            ? "v.pick_status"
            : $"({PickStatusEfectivoSql})";

        var page = Math.Max(1, filtro.Page);
        var pageSize = Math.Clamp(filtro.PageSize, 1, 5000);
        var offset = (page - 1) * pageSize;
        p.Add("offset", offset);
        p.Add("pageSize", pageSize);

        var countSql = $"""
            SELECT COUNT(1)
            FROM dbo.view_HCA_encomendas_abertas v
            {kappsApply}
            {where};
            """;

        var listSql = $"""
            SELECT
                v.bostamp,
                v.obrano,
                v.ndos,
                v.nmdos,
                v.dataobra,
                CONVERT(varchar(12), v.ousrhora) AS ousrhora,
                v.cliente_no,
                v.cliente_estab,
                v.cliente_nome,
                LTRIM(RTRIM(ISNULL(bo.nome2, ''))) AS cliente_nome2,
                v.total_linhas,
                v.quantidade_original_total,
                v.quantidade_atual_total,
                v.quantidade_restante_total,
                v.quantidade_autorizada_total,
                v.pronta_picking,
                COALESCE(
                    (
                        SELECT TOP (1) LTRIM(RTRIM(us.usercode))
                        FROM dbo.us us WITH (NOLOCK)
                        WHERE ISNULL(us.inactivo, 0) = 0
                          AND (
                            LOWER(LTRIM(RTRIM(us.usercode))) = LOWER(LTRIM(RTRIM(ISNULL(v.pronta_picking_por, ''))))
                            OR (
                              CHARINDEX('@', LTRIM(RTRIM(ISNULL(v.pronta_picking_por, '')))) > 0
                              AND LOWER(LTRIM(RTRIM(ISNULL(us.email, '')))) = LOWER(LTRIM(RTRIM(v.pronta_picking_por)))
                            )
                          )
                    ),
                    NULLIF(LTRIM(RTRIM(v.pronta_picking_por)), '')
                ) AS pronta_picking_por,
                v.pronta_picking_em,
                {pickStatusSelect} AS pick_status,
                v.urgente,
                {DataEntregaSql} AS data_entrega,
                {MetodoExpedicaoSql} AS metodo_expedicao,
                {MoradaEntregaSql} AS morada_entrega,
                {TemQtt66SelectSqlFor("v.bostamp")} AS tem_qtt_66
            FROM dbo.view_HCA_encomendas_abertas v
            LEFT JOIN dbo.bo bo WITH (NOLOCK)
                ON bo.bostamp COLLATE DATABASE_DEFAULT = v.bostamp COLLATE DATABASE_DEFAULT
            LEFT JOIN dbo.bo2 bo2 WITH (NOLOCK)
                ON bo2.bo2stamp COLLATE DATABASE_DEFAULT = v.bostamp COLLATE DATABASE_DEFAULT
            LEFT JOIN dbo.bo3 bo3 WITH (NOLOCK)
                ON bo3.bo3stamp COLLATE DATABASE_DEFAULT = v.bostamp COLLATE DATABASE_DEFAULT
            {kappsApply}
            {where}
            ORDER BY v.obrano ASC
            OFFSET @offset ROWS FETCH NEXT @pageSize ROWS ONLY;
            """;

        var total = await connection.ExecuteScalarAsync<int>(
            new CommandDefinition(countSql, p, cancellationToken: cancellationToken));

        var rows = await connection.QueryAsync<EncomendaAbertaRow>(
            new CommandDefinition(listSql, p, cancellationToken: cancellationToken));

        var items = rows.Select(MapResumo).ToList();
        return (items, total);
    }

    public async Task<(EncomendaResumo? Cabecalho, IReadOnlyList<EncomendaLinha> Linhas)> ObterDetalheAsync(
        string boStamp,
        int serieNdos,
        CancellationToken cancellationToken = default)
    {
        await using var connection = new SqlConnection(_options.ConnectionString);
        await connection.OpenAsync(cancellationToken);

        var cabSql = $"""
            SELECT TOP 1
                v.bostamp,
                v.obrano,
                v.ndos,
                v.nmdos,
                v.dataobra,
                CONVERT(varchar(12), v.ousrhora) AS ousrhora,
                v.cliente_no,
                v.cliente_estab,
                v.cliente_nome,
                LTRIM(RTRIM(ISNULL(bo.nome2, ''))) AS cliente_nome2,
                v.total_linhas,
                v.quantidade_original_total,
                v.quantidade_atual_total,
                v.quantidade_restante_total,
                v.quantidade_autorizada_total,
                v.pronta_picking,
                COALESCE(
                    (
                        SELECT TOP (1) LTRIM(RTRIM(us.usercode))
                        FROM dbo.us us WITH (NOLOCK)
                        WHERE ISNULL(us.inactivo, 0) = 0
                          AND (
                            LOWER(LTRIM(RTRIM(us.usercode))) = LOWER(LTRIM(RTRIM(ISNULL(v.pronta_picking_por, ''))))
                            OR (
                              CHARINDEX('@', LTRIM(RTRIM(ISNULL(v.pronta_picking_por, '')))) > 0
                              AND LOWER(LTRIM(RTRIM(ISNULL(us.email, '')))) = LOWER(LTRIM(RTRIM(v.pronta_picking_por)))
                            )
                          )
                    ),
                    NULLIF(LTRIM(RTRIM(v.pronta_picking_por)), '')
                ) AS pronta_picking_por,
                v.pronta_picking_em,
                v.pick_status,
                v.urgente,
                {DataEntregaSql} AS data_entrega,
                {MetodoExpedicaoSql} AS metodo_expedicao,
                {MoradaEntregaSql} AS morada_entrega,
                {TemQtt66SelectSqlFor("v.bostamp")} AS tem_qtt_66
            FROM dbo.view_HCA_encomendas_abertas v
            LEFT JOIN dbo.bo bo WITH (NOLOCK)
                ON bo.bostamp COLLATE DATABASE_DEFAULT = v.bostamp COLLATE DATABASE_DEFAULT
            LEFT JOIN dbo.bo2 bo2 WITH (NOLOCK)
                ON bo2.bo2stamp COLLATE DATABASE_DEFAULT = v.bostamp COLLATE DATABASE_DEFAULT
            LEFT JOIN dbo.bo3 bo3 WITH (NOLOCK)
                ON bo3.bo3stamp COLLATE DATABASE_DEFAULT = v.bostamp COLLATE DATABASE_DEFAULT
            WHERE v.bostamp = @boStamp
              AND v.ndos = @serieNdos;
            """;

        var cab = await connection.QuerySingleOrDefaultAsync<EncomendaAbertaRow>(
            new CommandDefinition(
                cabSql,
                new { boStamp, serieNdos },
                cancellationToken: cancellationToken));

        // Detalhe também para encomendas já sem restante (só abertas na lista); fallback linhas por stamp+ndos
        if (cab is null)
        {
            var cabLinhasSql = $"""
                SELECT TOP 1
                    l.bostamp,
                    l.obrano,
                    l.ndos,
                    l.nmdos,
                    l.dataobra,
                    CONVERT(varchar(12), l.ousrhora) AS ousrhora,
                    l.cliente_no,
                    l.cliente_estab,
                    l.cliente_nome,
                    LTRIM(RTRIM(ISNULL(bo.nome2, ''))) AS cliente_nome2,
                    COUNT(1) OVER () AS total_linhas,
                    CAST(0 AS decimal(18,4)) AS quantidade_original_total,
                    CAST(0 AS decimal(18,4)) AS quantidade_atual_total,
                    CAST(0 AS decimal(18,4)) AS quantidade_restante_total,
                    CAST(0 AS decimal(18,4)) AS quantidade_autorizada_total,
                    CAST(ISNULL(bo3.u_pickrdy, 0) AS bit) AS pronta_picking,
                    COALESCE(
                        (
                            SELECT TOP (1) LTRIM(RTRIM(us.usercode))
                            FROM dbo.us us WITH (NOLOCK)
                            WHERE ISNULL(us.inactivo, 0) = 0
                              AND (
                                LOWER(LTRIM(RTRIM(us.usercode))) = LOWER(LTRIM(RTRIM(ISNULL(bo3.u_pickrdr, ''))))
                                OR (
                                  CHARINDEX('@', LTRIM(RTRIM(ISNULL(bo3.u_pickrdr, '')))) > 0
                                  AND LOWER(LTRIM(RTRIM(ISNULL(us.email, '')))) = LOWER(LTRIM(RTRIM(bo3.u_pickrdr)))
                                )
                              )
                        ),
                        NULLIF(LTRIM(RTRIM(bo3.u_pickrdr)), '')
                    ) AS pronta_picking_por,
                    CASE
                        WHEN bo3.u_pickrdt IS NULL OR YEAR(bo3.u_pickrdt) < 1950 THEN CAST(NULL AS datetime)
                        ELSE bo3.u_pickrdt
                    END AS pronta_picking_em,
                    CAST(ISNULL(bo3.u_pickstat, 0) AS int) AS pick_status,
                    CAST(ISNULL(bo3.u_urgente, 0) AS bit) AS urgente,
                    {DataEntregaSql} AS data_entrega,
                    {MetodoExpedicaoSql} AS metodo_expedicao,
                    {MoradaEntregaSql} AS morada_entrega,
                    {TemQtt66SelectSqlFor("l.bostamp")} AS tem_qtt_66
                FROM dbo.view_HCA_encomenda_linhas l
                INNER JOIN dbo.bo bo WITH (NOLOCK)
                    ON bo.bostamp COLLATE DATABASE_DEFAULT = l.bostamp COLLATE DATABASE_DEFAULT
                LEFT JOIN dbo.bo2 bo2 WITH (NOLOCK)
                    ON bo2.bo2stamp COLLATE DATABASE_DEFAULT = bo.bostamp COLLATE DATABASE_DEFAULT
                LEFT JOIN dbo.bo3 bo3 WITH (NOLOCK)
                    ON bo3.bo3stamp COLLATE DATABASE_DEFAULT = bo.bostamp COLLATE DATABASE_DEFAULT
                WHERE l.bostamp = @boStamp
                  AND l.ndos = @serieNdos;
                """;

            cab = await connection.QuerySingleOrDefaultAsync<EncomendaAbertaRow>(
                new CommandDefinition(
                    cabLinhasSql,
                    new { boStamp, serieNdos },
                    cancellationToken: cancellationToken));

            if (cab is null)
                return (null, Array.Empty<EncomendaLinha>());
        }

        var linhasSql = """
            SELECT
                l.bistamp,
                l.bostamp,
                l.ref,
                l.design,
                l.cor,
                l.unidade,
                l.quantidade_atual,
                l.quantidade_fornecida,
                l.quantidade_original_campo,
                l.quantidade_original_considerada,
                l.quantidade_por_satisfazer,
                l.preco_unitario,
                l.preco_original_campo,
                l.quantidade_autorizada,
                l.quantidade_autorizada_por,
                l.quantidade_autorizada_em,
                <<DISPONIVEL_PREV>> AS stock_disponivel,
                l.disponivel_no_portal,
                l.usrinis,
                l.usrdata,
                CONVERT(varchar(12), l.usrhora) AS usrhora
            FROM dbo.view_HCA_encomenda_linhas l
            WHERE l.bostamp = @boStamp
              AND l.ndos = @serieNdos
            ORDER BY l.ref, l.bistamp;
            """.Replace("<<DISPONIVEL_PREV>>", DisponivelPrevisaoSql, StringComparison.Ordinal);

        var linhas = await connection.QueryAsync<EncomendaLinhaRow>(
            new CommandDefinition(
                linhasSql,
                new { boStamp, serieNdos },
                cancellationToken: cancellationToken));

        return (MapResumo(cab), linhas.Select(MapLinha).ToList());
    }

    public async Task<IReadOnlyList<ArtigoSugestaoDto>> SugerirArtigosAsync(
        string termo,
        int serieNdos,
        int limit = 20,
        CancellationToken cancellationToken = default)
    {
        if (string.IsNullOrWhiteSpace(termo) || termo.Trim().Length < 1)
            return Array.Empty<ArtigoSugestaoDto>();

        await using var connection = new SqlConnection(_options.ConnectionString);
        await connection.OpenAsync(cancellationToken);

        const string sql = """
            SELECT DISTINCT TOP (@limit)
                LTRIM(RTRIM(l.ref)) AS Ref,
                LTRIM(RTRIM(l.design)) AS Design,
                LTRIM(RTRIM(ISNULL(l.cor, ''))) AS Cor
            FROM dbo.view_HCA_encomenda_linhas l
            INNER JOIN dbo.stobs stobs WITH (NOLOCK)
                ON LTRIM(RTRIM(stobs.ref)) = LTRIM(RTRIM(l.ref))
            WHERE l.ndos = @serieNdos
              AND CAST(ISNULL(stobs.u_dispPort, 0) AS bit) = 1
              AND (
                   LTRIM(RTRIM(l.ref)) LIKE @artigoPadrao ESCAPE '\'
                OR LTRIM(RTRIM(l.design)) LIKE @artigoPadrao ESCAPE '\'
              )
            ORDER BY LTRIM(RTRIM(l.ref));
            """;

        var padrao = $"%{EscapeLike(termo.Trim())}%";
        var rows = await connection.QueryAsync<ArtigoSugestaoDto>(
            new CommandDefinition(
                sql,
                new { serieNdos, limit = Math.Clamp(limit, 1, 50), artigoPadrao = padrao },
                cancellationToken: cancellationToken));

        return rows.ToList();
    }

    public async Task<IReadOnlyList<string>> SugerirCoresAsync(
        string termo,
        int serieNdos,
        int limit = 20,
        CancellationToken cancellationToken = default)
    {
        if (string.IsNullOrWhiteSpace(termo) || termo.Trim().Length < 1)
            return Array.Empty<string>();

        await using var connection = new SqlConnection(_options.ConnectionString);
        await connection.OpenAsync(cancellationToken);

        const string sql = """
            SELECT DISTINCT TOP (@limit)
                LTRIM(RTRIM(l.cor)) AS Cor
            FROM dbo.view_HCA_encomenda_linhas l
            WHERE l.ndos = @serieNdos
              AND LTRIM(RTRIM(ISNULL(l.cor, ''))) <> ''
              AND LTRIM(RTRIM(l.cor)) LIKE @corPadrao ESCAPE '\'
            ORDER BY LTRIM(RTRIM(l.cor));
            """;

        var padrao = $"%{EscapeLike(termo.Trim())}%";
        var rows = await connection.QueryAsync<string>(
            new CommandDefinition(
                sql,
                new { serieNdos, limit = Math.Clamp(limit, 1, 50), corPadrao = padrao },
                cancellationToken: cancellationToken));

        return rows.Where(c => !string.IsNullOrWhiteSpace(c)).Select(c => c.Trim()).ToList();
    }

    public async Task<IReadOnlyList<ArtigoLinhaAberta>> ListarLinhasAbertasProcuraAsync(
        int serieNdos,
        ArtigoProcuraLinhasFiltro? filtro = null,
        CancellationToken cancellationToken = default)
    {
        await using var connection = new SqlConnection(_options.ConnectionString);
        await connection.OpenAsync(cancellationToken);

        var where = new StringBuilder("""
            WHERE l.ndos = @serieNdos
              AND ISNULL(l.fecho, 0) = 0
              AND ISNULL(l.pronta_picking, 0) = 0
              AND l.quantidade_por_satisfazer > 0
            """);
        var p = new DynamicParameters();
        p.Add("serieNdos", serieNdos);

        if (!string.IsNullOrWhiteSpace(filtro?.RefExact))
        {
            where.Append(" AND LTRIM(RTRIM(l.ref)) = @refExact");
            p.Add("refExact", filtro!.RefExact.Trim());
        }

        if (filtro?.CorExact is not null)
        {
            // CorExact "" = só linhas sem cor; null = todas as cores
            where.Append(" AND LTRIM(RTRIM(ISNULL(l.cor, ''))) = @corExact");
            p.Add("corExact", filtro.CorExact.Trim());
        }

        if (!string.IsNullOrWhiteSpace(filtro?.RefOuDesignContem))
        {
            where.Append("""
                 AND (
                      LTRIM(RTRIM(l.ref)) LIKE @refDesignPadrao
                   OR LTRIM(RTRIM(l.design)) LIKE @refDesignPadrao
                 )
                """);
            p.Add("refDesignPadrao", "%" + filtro!.RefOuDesignContem.Trim() + "%");
        }

        if (!string.IsNullOrWhiteSpace(filtro?.CorContem))
        {
            where.Append(" AND LTRIM(RTRIM(ISNULL(l.cor, ''))) LIKE @corPadrao");
            p.Add("corPadrao", "%" + filtro!.CorContem.Trim() + "%");
        }

        if (filtro?.DataDe is not null)
        {
            where.Append(" AND CAST(l.dataobra AS date) >= @dataDe");
            p.Add("dataDe", filtro.DataDe.Value.Date);
        }

        if (filtro?.DataAte is not null)
        {
            where.Append(" AND CAST(l.dataobra AS date) <= @dataAte");
            p.Add("dataAte", filtro.DataAte.Value.Date);
        }

        if (filtro?.HoraDe is not null)
        {
            where.Append(" AND TRY_CONVERT(time, CONVERT(varchar(12), l.ousrhora)) >= @horaDe");
            p.Add("horaDe", filtro.HoraDe.Value);
        }

        if (filtro?.HoraAte is not null)
        {
            where.Append(" AND TRY_CONVERT(time, CONVERT(varchar(12), l.ousrhora)) <= @horaAte");
            p.Add("horaAte", filtro.HoraAte.Value);
        }

        if (!string.IsNullOrWhiteSpace(filtro?.ClienteNoContem))
        {
            where.Append(" AND CONVERT(varchar(20), l.cliente_no) LIKE @clientePadrao");
            p.Add("clientePadrao", "%" + filtro!.ClienteNoContem.Trim() + "%");
        }

        var metodo = filtro?.MetodoExpedicao?.Trim();
        if (!string.IsNullOrWhiteSpace(metodo) &&
            !metodo.Equals("Todos", StringComparison.OrdinalIgnoreCase) &&
            !metodo.Equals("todos", StringComparison.OrdinalIgnoreCase))
        {
            if (metodo.Equals(MetodoExpedicaoFiltro.NaoDefinido, StringComparison.OrdinalIgnoreCase))
            {
                where.Append($" AND LTRIM(RTRIM(ISNULL(({MetodoExpedicaoSql}), ''))) = ''");
            }
            else
            {
                where.Append($" AND LTRIM(RTRIM(ISNULL(({MetodoExpedicaoSql}), ''))) = @metodoExpedicao");
                p.Add("metodoExpedicao", metodo);
            }
        }

        // Fase 1A: só LinhasAbertas (sem Prev*/stock). Stock via ObterStockDisponivelPrevPorChavesAsync.
        var sql = $"""
            SELECT
                l.bistamp,
                l.bostamp,
                l.obrano,
                l.dataobra,
                CONVERT(varchar(12), l.ousrhora) AS ousrhora,
                l.cliente_no,
                l.cliente_nome,
                LTRIM(RTRIM(ISNULL(bo.nome2, ''))) AS cliente_nome2,
                l.ref,
                l.design,
                l.cor,
                l.unidade,
                l.quantidade_atual,
                l.quantidade_fornecida,
                l.quantidade_original_considerada,
                l.quantidade_por_satisfazer,
                l.preco_unitario,
                l.preco_original_campo,
                l.quantidade_autorizada,
                l.quantidade_autorizada_por,
                l.quantidade_autorizada_em,
                CAST(0 AS decimal(18, 6)) AS stock_disponivel,
                CAST(ISNULL(l.urgente, 0) AS bit) AS urgente,
                l.usrinis,
                l.usrdata,
                CONVERT(varchar(12), l.usrhora) AS usrhora,
                {DataEntregaSql} AS data_entrega,
                {MetodoExpedicaoSql} AS metodo_expedicao
            FROM dbo.view_HCA_encomenda_linhas l
            LEFT JOIN dbo.bo bo WITH (NOLOCK)
                ON bo.bostamp = l.bostamp
            LEFT JOIN dbo.bo3 bo3 WITH (NOLOCK)
                ON bo3.bo3stamp = l.bostamp
            {where}
            ORDER BY l.obrano ASC, l.bistamp;
            """;

        var rows = await connection.QueryAsync<ArtigoLinhaAbertaRow>(
            new CommandDefinition(sql, p, cancellationToken: cancellationToken));

        return rows.Select(MapArtigoLinha).ToList();
    }

    /// <inheritdoc />
    public async Task<IReadOnlyList<ArtigoStockPrevDto>> ObterStockDisponivelPrevPorChavesAsync(
        IReadOnlyList<ArtigoRefCorChave> chaves,
        CancellationToken cancellationToken = default)
    {
        if (chaves is null || chaves.Count == 0)
            return Array.Empty<ArtigoStockPrevDto>();

        // DISTINCT Ref+Cor (trim); mesma semântica visual / B2.
        var distinct = chaves
            .Select(c => new ArtigoRefCorChave(
                (c.Ref ?? string.Empty).Trim(),
                (c.Cor ?? string.Empty).Trim()))
            .GroupBy(c => (c.Ref.ToUpperInvariant(), c.Cor.ToUpperInvariant()))
            .Select(g => g.First())
            .ToList();

        if (distinct.Count == 0)
            return Array.Empty<ArtigoStockPrevDto>();

        var chavesJson = System.Text.Json.JsonSerializer.Serialize(
            distinct.Select(c => new { @ref = c.Ref, cor = c.Cor }));

        await using var connection = new SqlConnection(_options.ConnectionString);
        await connection.OpenAsync(cancellationToken);

        // B2 restrito a ChavesPagina (OPENJSON) — sem filtros ndos/fecho/pronta_picking no alocado.
        const string sql = """
            ;WITH ChavesLinhas AS (
                SELECT DISTINCT
                    LTRIM(RTRIM(j.ref)) AS ref,
                    j.cor AS cor
                FROM OPENJSON(@chavesJson)
                WITH (
                    ref nvarchar(100) '$.ref',
                    cor nvarchar(100) '$.cor'
                ) j
            ),
            PrevAlocado AS (
                SELECT
                    bi2a.u_previd AS previd,
                    LTRIM(RTRIM(bi_a.ref)) AS ref,
                    bi_a.u_cor AS cor_u,
                    SUM(ISNULL(bi2a.u_qtdaut, 0)) AS alocado
                FROM ChavesLinhas k
                INNER JOIN dbo.bi bi_a WITH (NOLOCK)
                    ON LTRIM(RTRIM(bi_a.ref)) = k.ref
                   AND bi_a.u_cor = k.cor
                INNER JOIN dbo.bi2 bi2a WITH (NOLOCK)
                    ON bi2a.bi2stamp = bi_a.bistamp
                WHERE bi2a.u_previd IN (
                    SELECT UPPER(CONVERT(varchar(50), p.Id))
                    FROM dbo.u_HcaPrevEntrada p WITH (NOLOCK)
                    WHERE ISNULL(p.Fechada, 0) = 0
                )
                GROUP BY
                    bi2a.u_previd,
                    LTRIM(RTRIM(bi_a.ref)),
                    bi_a.u_cor
            ),
            PrevDisp AS (
                SELECT
                    LTRIM(RTRIM(lin.Ref)) AS ref,
                    lin.Cor AS cor_u,
                    lin.QuantidadePrevista - ISNULL(a.alocado, 0) AS disponivel,
                    ROW_NUMBER() OVER (
                        PARTITION BY LTRIM(RTRIM(lin.Ref)), lin.Cor
                        ORDER BY p.DataInicio ASC, p.DataFim ASC
                    ) AS rn
                FROM dbo.u_HcaPrevEntrada p WITH (NOLOCK)
                INNER JOIN dbo.u_HcaPrevEntradaLin lin WITH (NOLOCK)
                    ON lin.PrevisaoId = p.Id
                INNER JOIN ChavesLinhas k
                    ON k.ref = LTRIM(RTRIM(lin.Ref))
                   AND k.cor = lin.Cor
                LEFT JOIN PrevAlocado a
                    ON a.previd = UPPER(CONVERT(varchar(50), p.Id))
                   AND a.ref = LTRIM(RTRIM(lin.Ref))
                   AND a.cor_u = lin.Cor
                WHERE ISNULL(p.Fechada, 0) = 0
            )
            SELECT
                pd.ref AS Ref,
                pd.cor_u AS Cor,
                ISNULL(pd.disponivel, 0) AS StockDisponivel
            FROM PrevDisp pd
            WHERE pd.rn = 1;
            """;

        var p = new DynamicParameters();
        p.Add("chavesJson", chavesJson);

        var rows = await connection.QueryAsync<ArtigoStockPrevDto>(
            new CommandDefinition(sql, p, cancellationToken: cancellationToken));

        return rows.ToList();
    }

    public async Task<(IReadOnlyList<CorteQuantidadeEncomenda> Items, int Total)> ListarCortesEncomendasAsync(
        CortesQuantidadeFiltro filtro,
        int serieNdos,
        CancellationToken cancellationToken = default)
    {
        await using var connection = new SqlConnection(_options.ConnectionString);
        await connection.OpenAsync(cancellationToken);

        var (where, p) = BuildCortesWhere(filtro, serieNdos);

        var page = Math.Max(1, filtro.Page);
        var pageSize = Math.Clamp(filtro.PageSize, 1, 200);
        var offset = (page - 1) * pageSize;
        p.Add("offset", offset);
        p.Add("pageSize", pageSize);

        var countSql = $"""
            SELECT COUNT(1) FROM (
                SELECT v.bostamp
                FROM dbo.view_HCA_cortes_quantidade v
                {where}
                GROUP BY v.bostamp
            ) x;
            """;

        var listSql = $"""
            SELECT
                v.bostamp,
                MAX(v.obrano) AS obrano,
                MAX(v.dataobra) AS dataobra,
                MAX(CONVERT(varchar(12), v.ousrhora)) AS ousrhora,
                MAX(v.cliente_no) AS cliente_no,
                MAX(v.cliente_nome) AS cliente_nome,
                COUNT(1) AS total_linhas,
                SUM(v.quantidade_original) AS quantidade_original_total,
                SUM(v.quantidade_autorizada) AS quantidade_autorizada_total,
                SUM(v.quantidade_nao_autorizada) AS quantidade_nao_autorizada_total,
                CAST(MAX(CASE WHEN v.pronta_picking = 1 THEN 1 ELSE 0 END) AS bit) AS pronta_picking,
                MAX(CASE WHEN v.fecho <> 0 THEN 1 ELSE 0 END) AS fecho,
                CAST(MAX(CASE WHEN v.urgente = 1 THEN 1 ELSE 0 END) AS bit) AS urgente
            FROM dbo.view_HCA_cortes_quantidade v
            {where}
            GROUP BY v.bostamp
            ORDER BY MAX(v.dataobra) DESC, MAX(v.obrano) DESC, v.bostamp
            OFFSET @offset ROWS FETCH NEXT @pageSize ROWS ONLY;
            """;

        var total = await connection.ExecuteScalarAsync<int>(
            new CommandDefinition(countSql, p, cancellationToken: cancellationToken));

        var rows = await connection.QueryAsync<CorteEncomendaAggRow>(
            new CommandDefinition(listSql, p, cancellationToken: cancellationToken));

        var items = rows.Select(r => new CorteQuantidadeEncomenda
        {
            BoStamp = r.bostamp?.Trim() ?? string.Empty,
            NumeroEncomenda = r.obrano,
            DataObra = r.dataobra,
            Hora = r.ousrhora?.Trim() ?? string.Empty,
            ClienteNo = r.cliente_no,
            ClienteNome = r.cliente_nome?.Trim() ?? string.Empty,
            TotalLinhas = r.total_linhas,
            QuantidadeOriginalTotal = r.quantidade_original_total,
            QuantidadeAutorizadaTotal = r.quantidade_autorizada_total,
            QuantidadeNaoAutorizadaTotal = r.quantidade_nao_autorizada_total,
            ProntaPicking = r.pronta_picking,
            Fechada = r.fecho != 0,
            Urgente = r.urgente
        }).ToList();

        return (items, total);
    }

    public async Task<IReadOnlyList<CorteQuantidadeLinha>> ListarCortesLinhasPorEncomendaAsync(
        string boStamp,
        int serieNdos,
        string? artigoRef = null,
        string? artigoCor = null,
        CancellationToken cancellationToken = default)
    {
        await using var connection = new SqlConnection(_options.ConnectionString);
        await connection.OpenAsync(cancellationToken);

        var filtro = new CortesQuantidadeFiltro
        {
            ArtigoRef = artigoRef,
            ArtigoCor = artigoCor,
            Page = 1,
            PageSize = 5000
        };
        var (where, p) = BuildCortesWhere(filtro, serieNdos);
        where.Append(" AND v.bostamp COLLATE DATABASE_DEFAULT = @boStamp COLLATE DATABASE_DEFAULT");
        p.Add("boStamp", boStamp.Trim());

        var sql = $"""
            SELECT
                v.bistamp,
                v.bostamp,
                v.obrano,
                v.dataobra,
                v.cliente_no,
                v.cliente_nome,
                v.ref,
                v.design,
                v.cor,
                v.unidade,
                v.quantidade_original,
                v.quantidade_autorizada,
                v.quantidade_nao_autorizada,
                v.quantidade_fornecida,
                v.pronta_picking,
                v.fecho
            FROM dbo.view_HCA_cortes_quantidade v
            {where}
            ORDER BY v.ref, v.bistamp;
            """;

        var rows = await connection.QueryAsync<CorteQuantidadeRow>(
            new CommandDefinition(sql, p, cancellationToken: cancellationToken));

        return rows.Select(r => new CorteQuantidadeLinha
        {
            BiStamp = r.bistamp?.Trim() ?? string.Empty,
            BoStamp = r.bostamp?.Trim() ?? string.Empty,
            NumeroEncomenda = r.obrano,
            DataObra = r.dataobra,
            ClienteNo = r.cliente_no,
            ClienteNome = r.cliente_nome?.Trim() ?? string.Empty,
            Ref = r.@ref?.Trim() ?? string.Empty,
            Design = r.design?.Trim() ?? string.Empty,
            Cor = r.cor?.Trim() ?? string.Empty,
            Unidade = r.unidade?.Trim() ?? string.Empty,
            QuantidadeOriginal = r.quantidade_original,
            QuantidadeAutorizada = r.quantidade_autorizada,
            QuantidadeNaoAutorizada = r.quantidade_nao_autorizada,
            QuantidadeFornecida = r.quantidade_fornecida,
            ProntaPicking = r.pronta_picking,
            Fechada = r.fecho != 0
        }).ToList();
    }

    private static (StringBuilder Where, DynamicParameters Params) BuildCortesWhere(
        CortesQuantidadeFiltro filtro,
        int serieNdos)
    {
        // Só encomendas fechadas; linhas com pedido > autorizada já vêm da vista.
        var where = new StringBuilder("""
            WHERE v.ndos = @serieNdos
              AND ISNULL(v.fecho, 0) = 1
            """);
        var p = new DynamicParameters();
        p.Add("serieNdos", serieNdos);

        if (filtro.DataDe is not null)
        {
            var dataDe = DateQuery.Normalize(filtro.DataDe);
            if (dataDe is not null)
            {
                where.Append(" AND CAST(v.dataobra AS date) >= @dataDe");
                p.Add("dataDe", dataDe.Value, DbType.Date);
            }
        }

        if (filtro.DataAte is not null)
        {
            var dataAte = DateQuery.Normalize(filtro.DataAte);
            if (dataAte is not null)
            {
                where.Append(" AND CAST(v.dataobra AS date) <= @dataAte");
                p.Add("dataAte", dataAte.Value, DbType.Date);
            }
        }

        if (filtro.Obrano is not null)
        {
            where.Append(" AND v.obrano = @obrano");
            p.Add("obrano", filtro.Obrano.Value);
        }

        if (!string.IsNullOrWhiteSpace(filtro.ArtigoRef))
        {
            where.Append("""
                 AND (
                      LTRIM(RTRIM(v.ref)) LIKE @artigoPadrao ESCAPE '\'
                   OR LTRIM(RTRIM(v.design)) LIKE @artigoPadrao ESCAPE '\'
                 )
                """);
            p.Add("artigoPadrao", $"%{EscapeLike(filtro.ArtigoRef.Trim())}%");
        }

        if (!string.IsNullOrWhiteSpace(filtro.ArtigoCor))
        {
            where.Append(" AND LTRIM(RTRIM(ISNULL(v.cor, ''))) LIKE @corPadrao ESCAPE '\\'");
            p.Add("corPadrao", $"%{EscapeLike(filtro.ArtigoCor.Trim())}%");
        }

        return (where, p);
    }

    private static string EscapeLike(string value) =>
        value
            .Replace("\\", "\\\\", StringComparison.Ordinal)
            .Replace("%", "\\%", StringComparison.Ordinal)
            .Replace("_", "\\_", StringComparison.Ordinal)
            .Replace("[", "\\[", StringComparison.Ordinal);

    private static ArtigoLinhaAberta MapArtigoLinha(ArtigoLinhaAbertaRow r) => new()
    {
        BiStamp = r.bistamp?.Trim() ?? string.Empty,
        BoStamp = r.bostamp?.Trim() ?? string.Empty,
        NumeroEncomenda = r.obrano,
        DataObra = r.dataobra,
        Hora = r.ousrhora?.Trim() ?? string.Empty,
        ClienteNo = r.cliente_no,
        ClienteNome = r.cliente_nome?.Trim() ?? string.Empty,
        ClienteNome2 = r.cliente_nome2?.Trim() ?? string.Empty,
        Ref = r.@ref?.Trim() ?? string.Empty,
        Design = r.design?.Trim() ?? string.Empty,
        Cor = r.cor?.Trim() ?? string.Empty,
        Unidade = r.unidade?.Trim() ?? string.Empty,
        QuantidadeAtual = r.quantidade_atual,
        QuantidadeFornecida = r.quantidade_fornecida,
        QuantidadeOriginalConsiderada = r.quantidade_original_considerada,
        QuantidadePorSatisfazer = r.quantidade_por_satisfazer,
        PrecoUnitario = r.preco_unitario,
        PrecoOriginalCampo = r.preco_original_campo,
        QuantidadeAutorizada = r.quantidade_autorizada,
        QuantidadeAutorizadaPor = r.quantidade_autorizada_por?.Trim() ?? string.Empty,
        QuantidadeAutorizadaEm = r.quantidade_autorizada_em,
        StockDisponivel = r.stock_disponivel,
        Urgente = r.urgente,
        Usrinis = r.usrinis?.Trim() ?? string.Empty,
        Usrdata = r.usrdata,
        Usrhora = r.usrhora?.Trim() ?? string.Empty,
        DataEntrega = r.data_entrega,
        MetodoExpedicao = r.metodo_expedicao?.Trim() ?? string.Empty
    };

    private static EncomendaResumo MapResumo(EncomendaAbertaRow r) => new()
    {
        BoStamp = r.bostamp?.Trim() ?? string.Empty,
        NumeroEncomenda = r.obrano,
        Ndos = r.ndos,
        NomeSerie = r.nmdos?.Trim() ?? string.Empty,
        DataObra = r.dataobra,
        Hora = r.ousrhora?.Trim() ?? string.Empty,
        ClienteNo = r.cliente_no,
        ClienteEstab = r.cliente_estab,
        ClienteNome = r.cliente_nome?.Trim() ?? string.Empty,
        ClienteNome2 = r.cliente_nome2?.Trim() ?? string.Empty,
        TotalLinhas = r.total_linhas,
        QuantidadeOriginalTotal = r.quantidade_original_total,
        QuantidadeAtualTotal = r.quantidade_atual_total,
        QuantidadePorSatisfazer = r.quantidade_restante_total,
        QuantidadeAutorizadaTotal = r.quantidade_autorizada_total,
        ProntaPicking = r.pronta_picking,
        ProntaPickingPor = r.pronta_picking_por?.Trim() ?? string.Empty,
        ProntaPickingEm = r.pronta_picking_em,
        // Legado: pronta sem u_pickstat → Preparado (1)
        PickStatus = r.pronta_picking && r.pick_status == 0 ? 1 : r.pick_status,
        Urgente = r.urgente,
        DataEntrega = r.data_entrega,
        MetodoExpedicao = r.metodo_expedicao?.Trim() ?? string.Empty,
        MoradaEntrega = r.morada_entrega?.Trim() ?? string.Empty,
        TemQtt66 = r.tem_qtt_66
    };

    private static EncomendaLinha MapLinha(EncomendaLinhaRow r) => new()
    {
        BiStamp = r.bistamp?.Trim() ?? string.Empty,
        BoStamp = r.bostamp?.Trim() ?? string.Empty,
        Ref = r.@ref?.Trim() ?? string.Empty,
        Design = r.design?.Trim() ?? string.Empty,
        Cor = r.cor?.Trim() ?? string.Empty,
        Unidade = r.unidade?.Trim() ?? string.Empty,
        QuantidadeAtual = r.quantidade_atual,
        QuantidadeFornecida = r.quantidade_fornecida,
        QuantidadeOriginalCampo = r.quantidade_original_campo,
        QuantidadeOriginalConsiderada = r.quantidade_original_considerada,
        QuantidadePorSatisfazer = r.quantidade_por_satisfazer,
        PrecoUnitario = r.preco_unitario,
        PrecoOriginalCampo = r.preco_original_campo,
        QuantidadeAutorizada = r.quantidade_autorizada,
        QuantidadeAutorizadaPor = r.quantidade_autorizada_por?.Trim() ?? string.Empty,
        QuantidadeAutorizadaEm = r.quantidade_autorizada_em,
        StockDisponivel = r.stock_disponivel,
        DisponivelNoPortal = r.disponivel_no_portal,
        Usrinis = r.usrinis?.Trim() ?? string.Empty,
        Usrdata = r.usrdata,
        Usrhora = r.usrhora?.Trim() ?? string.Empty
    };

    private sealed class EncomendaAbertaRow
    {
        public string? bostamp { get; init; }
        public int obrano { get; init; }
        public int ndos { get; init; }
        public string? nmdos { get; init; }
        public DateTime dataobra { get; init; }
        public string? ousrhora { get; init; }
        public int cliente_no { get; init; }
        public int cliente_estab { get; init; }
        public string? cliente_nome { get; init; }
        public string? cliente_nome2 { get; init; }
        public int total_linhas { get; init; }
        public decimal quantidade_original_total { get; init; }
        public decimal quantidade_atual_total { get; init; }
        public decimal quantidade_restante_total { get; init; }
        public decimal quantidade_autorizada_total { get; init; }
        public bool pronta_picking { get; init; }
        public string? pronta_picking_por { get; init; }
        public DateTime? pronta_picking_em { get; init; }
        public int pick_status { get; init; }
        public bool urgente { get; init; }
        public DateTime? data_entrega { get; init; }
        public string? metodo_expedicao { get; init; }
        public string? morada_entrega { get; init; }
        public bool tem_qtt_66 { get; init; }
    }

    private sealed class EncomendaLinhaRow
    {
        public string? bistamp { get; init; }
        public string? bostamp { get; init; }
        public string? @ref { get; init; }
        public string? design { get; init; }
        public string? cor { get; init; }
        public string? unidade { get; init; }
        public decimal quantidade_atual { get; init; }
        public decimal quantidade_fornecida { get; init; }
        public decimal quantidade_original_campo { get; init; }
        public decimal quantidade_original_considerada { get; init; }
        public decimal quantidade_por_satisfazer { get; init; }
        public decimal preco_unitario { get; init; }
        public decimal preco_original_campo { get; init; }
        public decimal quantidade_autorizada { get; init; }
        public string? quantidade_autorizada_por { get; init; }
        public DateTime? quantidade_autorizada_em { get; init; }
        public decimal stock_disponivel { get; init; }
        public bool disponivel_no_portal { get; init; }
        public string? usrinis { get; init; }
        public DateTime? usrdata { get; init; }
        public string? usrhora { get; init; }
    }

    private sealed class ArtigoLinhaAbertaRow
    {
        public string? bistamp { get; init; }
        public string? bostamp { get; init; }
        public int obrano { get; init; }
        public DateTime dataobra { get; init; }
        public string? ousrhora { get; init; }
        public int cliente_no { get; init; }
        public string? cliente_nome { get; init; }
        public string? cliente_nome2 { get; init; }
        public string? @ref { get; init; }
        public string? design { get; init; }
        public string? cor { get; init; }
        public string? unidade { get; init; }
        public decimal quantidade_atual { get; init; }
        public decimal quantidade_fornecida { get; init; }
        public decimal quantidade_original_considerada { get; init; }
        public decimal quantidade_por_satisfazer { get; init; }
        public decimal preco_unitario { get; init; }
        public decimal preco_original_campo { get; init; }
        public decimal quantidade_autorizada { get; init; }
        public string? quantidade_autorizada_por { get; init; }
        public DateTime? quantidade_autorizada_em { get; init; }
        public decimal stock_disponivel { get; init; }
        public bool urgente { get; init; }
        public string? usrinis { get; init; }
        public DateTime? usrdata { get; init; }
        public string? usrhora { get; init; }
        public DateTime? data_entrega { get; init; }
        public string? metodo_expedicao { get; init; }
    }

    private sealed class CorteQuantidadeRow
    {
        public string? bistamp { get; init; }
        public string? bostamp { get; init; }
        public int obrano { get; init; }
        public DateTime dataobra { get; init; }
        public int cliente_no { get; init; }
        public string? cliente_nome { get; init; }
        public string? @ref { get; init; }
        public string? design { get; init; }
        public string? cor { get; init; }
        public string? unidade { get; init; }
        public decimal quantidade_original { get; init; }
        public decimal quantidade_autorizada { get; init; }
        public decimal quantidade_nao_autorizada { get; init; }
        public decimal quantidade_fornecida { get; init; }
        public bool pronta_picking { get; init; }
        public int fecho { get; init; }
    }

    private sealed class CorteEncomendaAggRow
    {
        public string? bostamp { get; init; }
        public int obrano { get; init; }
        public DateTime dataobra { get; init; }
        public string? ousrhora { get; init; }
        public int cliente_no { get; init; }
        public string? cliente_nome { get; init; }
        public int total_linhas { get; init; }
        public decimal quantidade_original_total { get; init; }
        public decimal quantidade_autorizada_total { get; init; }
        public decimal quantidade_nao_autorizada_total { get; init; }
        public bool pronta_picking { get; init; }
        public int fecho { get; init; }
        public bool urgente { get; init; }
    }
}
