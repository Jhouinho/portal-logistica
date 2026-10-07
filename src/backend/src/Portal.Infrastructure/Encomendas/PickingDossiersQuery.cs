using System.Data;
using System.Text;
using Dapper;
using Microsoft.Data.SqlClient;
using Microsoft.Extensions.Options;
using Portal.Application.Encomendas;
using Portal.Domain.Encomendas;
using Portal.Infrastructure.Options;

namespace Portal.Infrastructure.Encomendas;

public sealed class PickingDossiersQuery : IPickingDossiersQuery
{
    private readonly PhcOptions _options;

    public PickingDossiersQuery(IOptions<PhcOptions> options)
    {
        _options = options.Value;
    }

    public async Task<(IReadOnlyList<EncomendaResumo> Items, int Total)> ListarAsync(
        EncomendasFiltro filtro,
        int seriePickingNdos,
        bool fechada,
        CancellationToken cancellationToken = default)
    {
        await using var connection = new SqlConnection(_options.ConnectionString);
        await connection.OpenAsync(cancellationToken);

        var where = new StringBuilder("""
            WHERE v.ndos = @seriePickingNdos
              AND ISNULL(CAST(v.fechada AS int), 0) = @fechada
            """);
        var p = new DynamicParameters();
        p.Add("seriePickingNdos", seriePickingNdos);
        p.Add("fechada", fechada ? 1 : 0);
        p.Add("serieEncomendaDoc", _options.SerieEncomendasNdos);
        p.Add("seriePickingDoc", _options.SeriePickingNdos);
        p.Add("serieSeparacaoDoc", _options.SerieSeparacaoNdos);

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

        if (!string.IsNullOrWhiteSpace(filtro.ClienteNomeContem))
        {
            where.Append(" AND v.cliente_nome LIKE @clienteNomePadrao ESCAPE '\\'");
            p.Add("clienteNomePadrao", $"%{EscapeLike(filtro.ClienteNomeContem.Trim())}%");
        }

        if (!string.IsNullOrWhiteSpace(filtro.ArtigoRef) || !string.IsNullOrWhiteSpace(filtro.ArtigoCor))
        {
            where.Append("""
                 AND EXISTS (
                    SELECT 1
                    FROM dbo.bi bi WITH (NOLOCK)
                    WHERE bi.bostamp COLLATE DATABASE_DEFAULT = v.bostamp COLLATE DATABASE_DEFAULT
                """);

            if (!string.IsNullOrWhiteSpace(filtro.ArtigoRef))
            {
                where.Append("""
                      AND (
                           LTRIM(RTRIM(bi.ref)) LIKE @artigoPadrao ESCAPE '\'
                        OR LTRIM(RTRIM(bi.design)) LIKE @artigoPadrao ESCAPE '\'
                      )
                    """);
                p.Add("artigoPadrao", $"%{EscapeLike(filtro.ArtigoRef.Trim())}%");
            }

            if (!string.IsNullOrWhiteSpace(filtro.ArtigoCor))
            {
                where.Append("""
                      AND LTRIM(RTRIM(COALESCE(
                            NULLIF(LTRIM(RTRIM(ISNULL(bi.cor, ''))), ''),
                            NULLIF(LTRIM(RTRIM(ISNULL(bi.u_cor, ''))), ''),
                            ''
                          ))) LIKE @corPadrao ESCAPE '\'
                    """);
                p.Add("corPadrao", $"%{EscapeLike(filtro.ArtigoCor.Trim())}%");
            }

            where.Append("""
                )
                """);
        }

        if (filtro.CheckIn is not null)
        {
            where.Append(" AND ISNULL(CAST(v.check_in AS int), 0) = @checkIn");
            p.Add("checkIn", filtro.CheckIn.Value ? 1 : 0);
        }

        if (filtro.ApenasComPendenteEntrega)
        {
            where.Append(" AND v.quantidade_pendente_entrega > 0");
        }

        if (filtro.Obrano is not null)
        {
            where.Append(" AND CAST(COALESCE(v.obrano_origem, v.obrano) AS int) = @obrano");
            p.Add("obrano", filtro.Obrano.Value);
        }

        var page = Math.Max(1, filtro.Page);
        var pageSize = Math.Clamp(filtro.PageSize, 1, 5000);
        var offset = (page - 1) * pageSize;
        p.Add("offset", offset);
        p.Add("pageSize", pageSize);

        const string fromSql = """
            FROM (
                SELECT
                    bo.bostamp,
                    bo.obrano,
                    -- Cadeia documental: Encomenda (1) ← Picking (66) ← Separação (65).
                    COALESCE(
                        (
                            SELECT MAX(o.obrano)
                            FROM dbo.bi di WITH (NOLOCK)
                            INNER JOIN dbo.bi oi WITH (NOLOCK)
                                ON oi.bistamp COLLATE DATABASE_DEFAULT = di.obistamp COLLATE DATABASE_DEFAULT
                            INNER JOIN dbo.bo o WITH (NOLOCK)
                                ON o.bostamp COLLATE DATABASE_DEFAULT = oi.bostamp COLLATE DATABASE_DEFAULT
                            WHERE di.bostamp COLLATE DATABASE_DEFAULT = bo.bostamp COLLATE DATABASE_DEFAULT
                              AND o.ndos = @serieEncomendaDoc
                        ),
                        (
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
                        )
                    ) AS obrano_origem,
                    CASE
                        WHEN bo.ndos = @seriePickingDoc THEN bo.obrano
                        ELSE (
                            SELECT MAX(pbo.obrano)
                            FROM dbo.bi di WITH (NOLOCK)
                            INNER JOIN dbo.bi mid WITH (NOLOCK)
                                ON mid.bistamp COLLATE DATABASE_DEFAULT = di.obistamp COLLATE DATABASE_DEFAULT
                            INNER JOIN dbo.bo pbo WITH (NOLOCK)
                                ON pbo.bostamp COLLATE DATABASE_DEFAULT = mid.bostamp COLLATE DATABASE_DEFAULT
                            WHERE di.bostamp COLLATE DATABASE_DEFAULT = bo.bostamp COLLATE DATABASE_DEFAULT
                              AND pbo.ndos = @seriePickingDoc
                        )
                    END AS obrano_picking,
                    CASE
                        WHEN bo.ndos = @serieSeparacaoDoc THEN bo.obrano
                        ELSE CAST(NULL AS int)
                    END AS obrano_separacao,
                    bo.ndos,
                    bo.nmdos,
                    bo.dataobra,
                    bo.ousrhora,
                    bo.no AS cliente_no,
                    bo.estab AS cliente_estab,
                    LTRIM(RTRIM(bo.nome)) AS cliente_nome,
                    LTRIM(RTRIM(ISNULL(bo.nome2, ''))) AS cliente_nome2,
                    ISNULL(bo.fechada, 0) AS fechada,
                    COUNT(bi.bistamp) AS total_linhas,
                    SUM(ISNULL(NULLIF(bi2.u_qttorig, 0), bi.qtt)) AS quantidade_original_total,
                    SUM(bi.qtt) AS quantidade_atual_total,
                    SUM(ISNULL(NULLIF(bi2.u_qttorig, 0), bi.qtt) - bi.qtt2) AS quantidade_restante_total,
                    SUM(ISNULL(bi2.u_qtdaut, 0)) AS quantidade_autorizada_total,
                    -- Expedição (ndos=66): documento / expedida / pendente — sem u_qttorig.
                    SUM(bi.qtt) AS quantidade_documento,
                    SUM(bi.qtt2) AS quantidade_expedida,
                    SUM(bi.qtt - bi.qtt2) AS quantidade_pendente_entrega,
                    CAST(ISNULL(bo3.u_pickrdy, 0) AS bit) AS pronta_picking,
                    LTRIM(RTRIM(ISNULL(bo3.u_pickrdr, ''))) AS pronta_picking_por,
                    CASE
                        WHEN bo3.u_pickrdt IS NULL OR YEAR(bo3.u_pickrdt) < 1950 THEN CAST(NULL AS datetime)
                        ELSE bo3.u_pickrdt
                    END AS pronta_picking_em,
                    CAST(ISNULL(TRY_CONVERT(int, bo3.u_pickstat), 0) AS int) AS pick_status,
                    CAST(ISNULL(bo3.u_urgente, 0) AS bit) AS urgente,
                    CAST(ISNULL(bo3.u_chkin, 0) AS bit) AS check_in,
                    LTRIM(RTRIM(ISNULL(bo3.u_chkinur, ''))) AS check_in_por,
                    CASE
                        WHEN bo3.u_chkindt IS NULL OR YEAR(bo3.u_chkindt) < 1950 THEN CAST(NULL AS datetime)
                        ELSE bo3.u_chkindt
                    END AS check_in_em,
                    LTRIM(RTRIM(ISNULL(bo3.u_modExp, ''))) AS metodo_expedicao,
                    LTRIM(RTRIM(ISNULL(bo2.u_mEntrega, ''))) AS morada_entrega
                FROM dbo.bo bo WITH (NOLOCK)
                INNER JOIN dbo.bi bi WITH (NOLOCK)
                    ON bi.bostamp COLLATE DATABASE_DEFAULT = bo.bostamp COLLATE DATABASE_DEFAULT
                LEFT JOIN dbo.bi2 bi2 WITH (NOLOCK)
                    ON bi2.bi2stamp COLLATE DATABASE_DEFAULT = bi.bistamp COLLATE DATABASE_DEFAULT
                LEFT JOIN dbo.bo2 bo2 WITH (NOLOCK)
                    ON bo2.bo2stamp COLLATE DATABASE_DEFAULT = bo.bostamp COLLATE DATABASE_DEFAULT
                LEFT JOIN dbo.bo3 bo3 WITH (NOLOCK)
                    ON bo3.bo3stamp COLLATE DATABASE_DEFAULT = bo.bostamp COLLATE DATABASE_DEFAULT
                WHERE bo.ndos = @seriePickingNdos
                GROUP BY
                    bo.bostamp,
                    bo.obrano,
                    bo.ndos,
                    bo.nmdos,
                    bo.dataobra,
                    bo.ousrhora,
                    bo.no,
                    bo.estab,
                    bo.nome,
                    bo.nome2,
                    bo.fechada,
                    bo3.u_pickrdy,
                    bo3.u_pickrdr,
                    bo3.u_pickrdt,
                    bo3.u_pickstat,
                    bo3.u_urgente,
                    bo3.u_chkin,
                    bo3.u_chkinur,
                    bo3.u_chkindt,
                    bo3.u_modExp,
                    bo2.u_mEntrega
            ) v
            """;

        var countSql = $"""
            SELECT COUNT(1)
            {fromSql}
            {where};
            """;

        var listSql = $"""
            SELECT
                v.bostamp,
                CAST(COALESCE(v.obrano_origem, v.obrano) AS int) AS obrano,
                CAST(v.obrano AS int) AS obrano_dossier,
                CAST(v.obrano_picking AS int) AS obrano_picking,
                CAST(v.obrano_separacao AS int) AS obrano_separacao,
                v.ndos,
                v.nmdos,
                v.dataobra,
                CONVERT(varchar(12), v.ousrhora) AS ousrhora,
                v.cliente_no,
                v.cliente_estab,
                v.cliente_nome,
                v.cliente_nome2,
                v.total_linhas,
                v.quantidade_original_total,
                v.quantidade_atual_total,
                v.quantidade_restante_total,
                v.quantidade_autorizada_total,
                v.quantidade_documento,
                v.quantidade_expedida,
                v.quantidade_pendente_entrega,
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
                v.check_in,
                COALESCE(
                    (
                        SELECT TOP (1) LTRIM(RTRIM(us.usercode))
                        FROM dbo.us us WITH (NOLOCK)
                        WHERE ISNULL(us.inactivo, 0) = 0
                          AND (
                            LOWER(LTRIM(RTRIM(us.usercode))) = LOWER(LTRIM(RTRIM(ISNULL(v.check_in_por, ''))))
                            OR (
                              CHARINDEX('@', LTRIM(RTRIM(ISNULL(v.check_in_por, '')))) > 0
                              AND LOWER(LTRIM(RTRIM(ISNULL(us.email, '')))) = LOWER(LTRIM(RTRIM(v.check_in_por)))
                            )
                          )
                    ),
                    NULLIF(LTRIM(RTRIM(v.check_in_por)), '')
                ) AS check_in_por,
                v.check_in_em,
                v.metodo_expedicao,
                v.morada_entrega
            {fromSql}
            {where}
            ORDER BY COALESCE(v.obrano_origem, v.obrano) ASC
            OFFSET @offset ROWS FETCH NEXT @pageSize ROWS ONLY;
            """;

        // seriePickingNdos is used both in subquery and outer WHERE
        var total = await connection.ExecuteScalarAsync<int>(
            new CommandDefinition(countSql, p, cancellationToken: cancellationToken));

        var rows = await connection.QueryAsync<Row>(
            new CommandDefinition(listSql, p, cancellationToken: cancellationToken));

        var items = rows.Select(r => new EncomendaResumo
        {
            BoStamp = r.bostamp?.Trim() ?? string.Empty,
            NumeroEncomenda = r.obrano,
            NumeroDossier = r.obrano_dossier,
            NumeroPicking = r.obrano_picking,
            NumeroSeparacao = r.obrano_separacao,
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
            QuantidadeDocumento = r.quantidade_documento,
            QuantidadeExpedida = r.quantidade_expedida,
            QuantidadePendenteEntrega = r.quantidade_pendente_entrega,
            ProntaPicking = r.pronta_picking,
            ProntaPickingPor = r.pronta_picking_por?.Trim() ?? string.Empty,
            ProntaPickingEm = r.pronta_picking_em,
            // Em Separação (ndos picking): u_pickstat 0 ≡ Em espera (1).
            PickStatus = r.pick_status == 0 ? 1 : r.pick_status,
            Urgente = r.urgente,
            CheckIn = r.check_in,
            CheckInPor = r.check_in_por?.Trim() ?? string.Empty,
            CheckInEm = r.check_in_em,
            MetodoExpedicao = r.metodo_expedicao?.Trim() ?? string.Empty,
            MoradaEntrega = r.morada_entrega?.Trim() ?? string.Empty
        }).ToList();

        return (items, total);
    }

    public async Task<IReadOnlyList<EncomendaLinha>> ListarLinhasAsync(
        string boStamp,
        int seriePickingNdos,
        CancellationToken cancellationToken = default)
    {
        await using var connection = new SqlConnection(_options.ConnectionString);
        await connection.OpenAsync(cancellationToken);

        const string sql = """
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
                l.stock_disponivel,
                l.usrinis,
                l.usrdata,
                CONVERT(varchar(12), l.usrhora) AS usrhora
            FROM dbo.view_HCA_encomenda_linhas l
            WHERE l.bostamp = @boStamp
              AND l.ndos = @seriePickingNdos
            ORDER BY l.ref, l.bistamp;
            """;

        var rows = await connection.QueryAsync<LinhaRow>(
            new CommandDefinition(
                sql,
                new { boStamp, seriePickingNdos },
                cancellationToken: cancellationToken));

        return rows.Select(r => new EncomendaLinha
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
            Usrinis = r.usrinis?.Trim() ?? string.Empty,
            Usrdata = r.usrdata,
            Usrhora = r.usrhora?.Trim() ?? string.Empty
        }).ToList();
    }

    private static string EscapeLike(string value) =>
        value.Replace("\\", "\\\\", StringComparison.Ordinal)
            .Replace("%", "\\%", StringComparison.Ordinal)
            .Replace("_", "\\_", StringComparison.Ordinal);

    private sealed class Row
    {
        public string? bostamp { get; init; }
        public int obrano { get; init; }
        public int? obrano_dossier { get; init; }
        public int? obrano_picking { get; init; }
        public int? obrano_separacao { get; init; }
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
        public decimal quantidade_documento { get; init; }
        public decimal quantidade_expedida { get; init; }
        public decimal quantidade_pendente_entrega { get; init; }
        public bool pronta_picking { get; init; }
        public string? pronta_picking_por { get; init; }
        public DateTime? pronta_picking_em { get; init; }
        public int pick_status { get; init; }
        public bool urgente { get; init; }
        public bool check_in { get; init; }
        public string? check_in_por { get; init; }
        public DateTime? check_in_em { get; init; }
        public string? metodo_expedicao { get; init; }
        public string? morada_entrega { get; init; }
    }

    private sealed class LinhaRow
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
        public string? usrinis { get; init; }
        public DateTime? usrdata { get; init; }
        public string? usrhora { get; init; }
    }
}
