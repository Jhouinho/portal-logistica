using System.Data;
using Dapper;
using Microsoft.Data.SqlClient;
using Microsoft.Extensions.Options;
using Portal.Application.Cliente;
using Portal.Infrastructure.Options;

namespace Portal.Infrastructure.Cliente;

public sealed class ClientePedidosService : IClientePedidosService
{
    private readonly PhcOptions _phc;
    private readonly PortalClienteOptions _cliente;

    public ClientePedidosService(IOptions<PhcOptions> phc, IOptions<PortalClienteOptions> cliente)
    {
        _phc = phc.Value;
        _cliente = cliente.Value;
    }

    public async Task<ClientePedidoCreateResult> CriarAsync(
        decimal no,
        decimal estab,
        string idempotencyKey,
        IReadOnlyList<ClientePedidoLinhaInput> linhas,
        CancellationToken cancellationToken)
    {
        await using var conn = new SqlConnection(_phc.ConnectionString);
        await conn.OpenAsync(cancellationToken);

        var tvp = new DataTable();
        tvp.Columns.Add("linha_ord", typeof(int));
        tvp.Columns.Add("ref", typeof(string));
        tvp.Columns.Add("qtt", typeof(decimal));
        tvp.Columns.Add("cor", typeof(string));
        foreach (var l in linhas.OrderBy(x => x.LinhaOrd))
        {
            tvp.Rows.Add(
                l.LinhaOrd,
                l.Ref.Trim(),
                l.Qtt,
                (l.Cor ?? string.Empty).Trim());
        }

        var p = new DynamicParameters();
        p.Add("@no", no);
        p.Add("@estab", estab);
        p.Add("@Linhas", tvp.AsTableValuedParameter("dbo.HCA_PedidoMobileLinhaType"));
        p.Add("@IdempotencyKey", idempotencyKey);
        p.Add("@usrinis", "MOB");

        var result = await conn.QuerySingleAsync<SpResult>(new CommandDefinition(
            "dbo.sp_HCA_criar_pedido_mobile",
            p,
            commandType: CommandType.StoredProcedure,
            cancellationToken: cancellationToken));

        return new ClientePedidoCreateResult(
            result.alreadyExists,
            result.bostamp.Trim(),
            result.obrano,
            result.boano,
            result.ndos,
            result.nmdos?.Trim() ?? "",
            result.etotaldeb,
            result.totaldeb,
            result.linhas);
    }

    public async Task<IReadOnlyList<ClientePedidoListaItem>> ListarAsync(
        decimal no,
        decimal estab,
        int top,
        CancellationToken cancellationToken)
    {
        top = Math.Clamp(top, 1, 50);
        await using var conn = new SqlConnection(_phc.ConnectionString);
        var rows = await conn.QueryAsync<ListaRow>(new CommandDefinition(
            """
            SELECT TOP (@top)
                RTRIM(bo.bostamp) AS Bostamp,
                bo.obrano AS Obrano,
                bo.boano AS Boano,
                CAST(bo.dataobra AS datetime2) AS DataObra,
                NULLIF(RTRIM(bo.ousrhora), '') AS Hora,
                CAST(bo.etotaldeb AS decimal(18,6)) AS Etotaldeb,
                CASE WHEN c.bostamp IS NULL THEN CAST(0 AS bit) ELSE CAST(1 AS bit) END AS Cancelado
            FROM dbo.bo bo WITH (NOLOCK)
            LEFT JOIN dbo.u_HcaPedidoMobileCancel c WITH (NOLOCK)
                ON c.bostamp = bo.bostamp
            WHERE bo.ndos = @ndos
              AND bo.no = @no
              AND bo.estab = @estab
              AND c.bostamp IS NULL
            ORDER BY bo.dataobra DESC, bo.obrano DESC
            """,
            new { top, ndos = _cliente.PedidoMobileNdos, no, estab },
            cancellationToken: cancellationToken));

        return rows.Select(r =>
        {
            var (codigo, etiqueta, podeCancelar) = MapEstado(r.Bostamp, cancelado: false);
            return new ClientePedidoListaItem(
                r.Bostamp, r.Obrano, r.Boano, r.DataObra, r.Hora,
                codigo, etiqueta, r.Etotaldeb, podeCancelar);
        }).ToList();
    }

    public async Task<ClientePedidoDetalhe?> ObterAsync(
        decimal no,
        decimal estab,
        string bostamp,
        CancellationToken cancellationToken)
    {
        bostamp = (bostamp ?? "").Trim();
        await using var conn = new SqlConnection(_phc.ConnectionString);
        var cab = await conn.QuerySingleOrDefaultAsync<ListaRow>(new CommandDefinition(
            """
            SELECT
                RTRIM(bo.bostamp) AS Bostamp,
                bo.obrano AS Obrano,
                bo.boano AS Boano,
                CAST(bo.dataobra AS datetime2) AS DataObra,
                NULLIF(RTRIM(bo.ousrhora), '') AS Hora,
                CAST(bo.etotaldeb AS decimal(18,6)) AS Etotaldeb,
                CASE WHEN c.bostamp IS NULL THEN CAST(0 AS bit) ELSE CAST(1 AS bit) END AS Cancelado
            FROM dbo.bo bo WITH (NOLOCK)
            LEFT JOIN dbo.u_HcaPedidoMobileCancel c WITH (NOLOCK)
                ON c.bostamp = bo.bostamp
            WHERE bo.ndos = @ndos
              AND bo.no = @no
              AND bo.estab = @estab
              AND RTRIM(bo.bostamp) = @bostamp
            """,
            new { ndos = _cliente.PedidoMobileNdos, no, estab, bostamp },
            cancellationToken: cancellationToken));

        if (cab is null || cab.Cancelado)
            return null;

        var linhas = (await conn.QueryAsync<LinhaRow>(new CommandDefinition(
            """
            SELECT
                LTRIM(RTRIM(bi.ref)) AS Ref,
                LTRIM(RTRIM(bi.design)) AS Design,
                LTRIM(RTRIM(ISNULL(bi.u_cor, ''))) AS Cor,
                CAST(bi.qtt AS decimal(18,4)) AS Qtt,
                CAST(bi.edebito AS decimal(18,6)) AS PrecoUnitario,
                CAST(bi.ettdeb AS decimal(18,6)) AS TotalLinha
            FROM dbo.bi bi WITH (NOLOCK)
            WHERE RTRIM(bi.bostamp) = @bostamp
            ORDER BY bi.lordem, bi.ref
            """,
            new { bostamp },
            cancellationToken: cancellationToken))).ToList();

        var (codigo, etiqueta, podeCancelar) = MapEstado(cab.Bostamp, cancelado: false);
        return new ClientePedidoDetalhe(
            cab.Bostamp, cab.Obrano, cab.Boano, cab.DataObra, cab.Hora,
            codigo, etiqueta, cab.Etotaldeb, podeCancelar,
            linhas.Select(l => new ClientePedidoLinhaDetalhe(
                l.Ref, l.Design, l.Cor, l.Qtt, l.PrecoUnitario, l.TotalLinha)).ToList());
    }

    public async Task<(bool Ok, string? Error)> CancelarAsync(
        decimal no,
        decimal estab,
        string bostamp,
        CancellationToken cancellationToken)
    {
        bostamp = (bostamp ?? "").Trim();
        var detalhe = await ObterAsync(no, estab, bostamp, cancellationToken);
        if (detalhe is null)
            return (false, "nao_encontrado");
        if (!detalhe.PodeCancelar)
            return (false, "estado_invalido");

        await using var conn = new SqlConnection(_phc.ConnectionString);
        try
        {
            await conn.ExecuteAsync(new CommandDefinition(
                """
                INSERT INTO dbo.u_HcaPedidoMobileCancel (bostamp, ClNo, ClEstab, Motivo)
                VALUES (@bostamp, @no, @estab, N'Cancelado pelo cliente no Portal Mobile')
                """,
                new { bostamp, no, estab },
                cancellationToken: cancellationToken));
            return (true, null);
        }
        catch (SqlException ex) when (ex.Number is 2627 or 2601)
        {
            return (false, "ja_cancelado");
        }
    }

    /// <summary>
    /// Estados 1–2: submetido enquanto sem associação conhecida a destino.
    /// Associação Cópia de Dossier ainda sem campos confirmados (Etapa 8) —
    /// por agora tudo não cancelado = Pedido submetido (cancelável).
    /// </summary>
    private static (string Codigo, string Etiqueta, bool PodeCancelar) MapEstado(string bostamp, bool cancelado)
    {
        _ = bostamp;
        if (cancelado)
            return ("cancelado", "Cancelado", false);
        return ("submetido", "Pedido submetido", true);
    }

    private sealed class SpResult
    {
        public bool alreadyExists { get; init; }
        public string bostamp { get; init; } = "";
        public decimal obrano { get; init; }
        public decimal boano { get; init; }
        public decimal ndos { get; init; }
        public string? nmdos { get; init; }
        public decimal etotaldeb { get; init; }
        public decimal totaldeb { get; init; }
        public int linhas { get; init; }
    }

    private sealed class ListaRow
    {
        public string Bostamp { get; init; } = "";
        public decimal Obrano { get; init; }
        public decimal Boano { get; init; }
        public DateTime DataObra { get; init; }
        public string? Hora { get; init; }
        public decimal Etotaldeb { get; init; }
        public bool Cancelado { get; init; }
    }

    private sealed class LinhaRow
    {
        public string Ref { get; init; } = "";
        public string Design { get; init; } = "";
        public string Cor { get; init; } = "";
        public decimal Qtt { get; init; }
        public decimal PrecoUnitario { get; init; }
        public decimal TotalLinha { get; init; }
    }
}
