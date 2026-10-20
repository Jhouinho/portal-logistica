using System.Data;
using System.Globalization;
using System.Text.RegularExpressions;
using Dapper;
using Microsoft.Data.SqlClient;
using Microsoft.Extensions.Logging;
using Microsoft.Extensions.Options;
using Portal.Application.Cliente;
using Portal.Application.Encomendas;
using Portal.Infrastructure.Options;

namespace Portal.Infrastructure.Cliente;

public sealed class ClientePedidosService : IClientePedidosService
{
    private static readonly Regex NumeroInternoRegex =
        new(@"^PM-\d{4}-\d+$", RegexOptions.IgnoreCase | RegexOptions.CultureInvariant | RegexOptions.Compiled);

    private readonly PhcOptions _phc;
    private readonly PortalClienteOptions _cliente;
    private readonly IClientePmPedidoStore _pmStore;
    private readonly IClienteCatalogoQuery _catalogo;
    private readonly ILogger<ClientePedidosService> _log;

    public ClientePedidosService(
        IOptions<PhcOptions> phc,
        IOptions<PortalClienteOptions> cliente,
        IClientePmPedidoStore pmStore,
        IClienteCatalogoQuery catalogo,
        ILogger<ClientePedidosService> log)
    {
        _phc = phc.Value;
        _cliente = cliente.Value;
        _pmStore = pmStore;
        _catalogo = catalogo;
        _log = log;
    }

    public async Task<ClientePedidoCreateResult> CriarAsync(
        decimal no,
        decimal estab,
        string idempotencyKey,
        IReadOnlyList<ClientePedidoLinhaInput> linhas,
        CancellationToken cancellationToken)
    {
        var linhasErro = ClientePedidoSubmitRules.ValidateLinhasOrError(linhas);
        if (linhasErro is not null)
            throw new PortalBusinessException(linhasErro);

        if (_cliente.PedidosInternosEnabled)
            return await CriarInternoAsync(no, estab, idempotencyKey, linhas, cancellationToken);

        return await CriarLegadoAsync(no, estab, idempotencyKey, linhas, cancellationToken);
    }

    public async Task<IReadOnlyList<ClientePedidoListaItem>> ListarAsync(
        decimal no,
        decimal estab,
        int top,
        CancellationToken cancellationToken)
    {
        top = Math.Clamp(top, 1, 50);

        var internos = await ListarInternosSafeAsync(no, estab, top, cancellationToken);
        var legado = await ListarLegadoAsync(no, estab, top, cancellationToken);

        return internos
            .Concat(legado)
            .OrderByDescending(x => x.DataObra)
            .ThenByDescending(x => x.PedidoId ?? 0)
            .ThenByDescending(x => x.Obrano ?? 0)
            .Take(top)
            .ToList();
    }

    public async Task<ClientePedidoDetalhe?> ObterAsync(
        decimal no,
        decimal estab,
        string id,
        CancellationToken cancellationToken)
    {
        id = (id ?? "").Trim();
        if (id.Length == 0)
            return null;

        if (TryParsePedidoId(id, out var pedidoId))
        {
            var interno = await ObterInternoSafeAsync(
                () => _pmStore.ObterPorIdAsync(no, estab, pedidoId, cancellationToken));
            if (interno is not null)
                return MapDetalheInterno(interno);
        }

        if (NumeroInternoRegex.IsMatch(id))
        {
            var interno = await ObterInternoSafeAsync(
                () => _pmStore.ObterPorNumeroAsync(no, estab, id.ToUpperInvariant(), cancellationToken));
            if (interno is not null)
                return MapDetalheInterno(interno);
        }

        return await ObterLegadoAsync(no, estab, id, cancellationToken);
    }

    public async Task<(bool Ok, string? Error)> CancelarAsync(
        decimal no,
        decimal estab,
        string id,
        CancellationToken cancellationToken)
    {
        id = (id ?? "").Trim();
        if (id.Length == 0)
            return (false, "nao_encontrado");

        if (TryParsePedidoId(id, out var pedidoId))
        {
            var interno = await ObterInternoSafeAsync(
                () => _pmStore.ObterPorIdAsync(no, estab, pedidoId, cancellationToken));
            if (interno is not null)
                return (false, "interno_proibido");
        }

        if (NumeroInternoRegex.IsMatch(id))
        {
            var interno = await ObterInternoSafeAsync(
                () => _pmStore.ObterPorNumeroAsync(no, estab, id.ToUpperInvariant(), cancellationToken));
            if (interno is not null)
                return (false, "interno_proibido");
        }

        return await CancelarLegadoAsync(no, estab, id, cancellationToken);
    }

    private async Task<ClientePedidoCreateResult> CriarInternoAsync(
        decimal no,
        decimal estab,
        string idempotencyKey,
        IReadOnlyList<ClientePedidoLinhaInput> linhas,
        CancellationToken cancellationToken)
    {
        var hash = ClientePedidoIdempotency.ComputePayloadHash(linhas);
        var persistidas = new List<ClientePmLinhaPersistida>(linhas.Count);

        foreach (var l in linhas.OrderBy(x => x.LinhaOrd))
        {
            var artigo = await _catalogo.GetArtigoAsync(no, estab, l.Ref.Trim(), cancellationToken);
            if (artigo is null)
            {
                throw new PortalBusinessException(
                    $"Artigo «{l.Ref.Trim()}» não encontrado ou inactivo.");
            }

            var preco = Math.Round(artigo.PrecoUnitario, 6, MidpointRounding.AwayFromZero);
            var totalLinha = Math.Round(l.Qtt * preco, 6, MidpointRounding.AwayFromZero);
            persistidas.Add(new ClientePmLinhaPersistida(
                l.LinhaOrd,
                artigo.Ref,
                artigo.Design,
                ClienteCorLimits.Normalize(l.Cor),
                l.Qtt,
                preco,
                totalLinha));
        }

        var outcome = await _pmStore.CriarAsync(
            no, estab, idempotencyKey.Trim(), hash, persistidas, cancellationToken);

        var (codigo, etiqueta, _) = ClientePedidoEstadoMapper.MapInterno(outcome.Pedido.EstadoInterno);
        return new ClientePedidoCreateResult(
            outcome.AlreadyExists,
            Bostamp: null,
            Obrano: null,
            Boano: null,
            Ndos: null,
            Nmdos: null,
            outcome.Pedido.Etotaldeb,
            Totaldeb: null,
            outcome.Pedido.Linhas?.Count ?? persistidas.Count,
            outcome.Pedido.PedidoId,
            outcome.Pedido.NumeroInterno,
            ClientePedidoEstadoMapper.OrigemInterno,
            codigo,
            etiqueta);
    }

    private async Task<ClientePedidoCreateResult> CriarLegadoAsync(
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
                ClienteCorLimits.Normalize(l.Cor));
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

        var (codigo, etiqueta, _) = ClientePedidoEstadoMapper.Map(cancelado: false);
        return new ClientePedidoCreateResult(
            result.alreadyExists,
            result.bostamp.Trim(),
            result.obrano,
            result.boano,
            result.ndos,
            result.nmdos?.Trim() ?? "",
            result.etotaldeb,
            result.totaldeb,
            result.linhas,
            PedidoId: null,
            NumeroInterno: null,
            ClientePedidoEstadoMapper.OrigemLegado,
            codigo,
            etiqueta);
    }

    private async Task<IReadOnlyList<ClientePedidoListaItem>> ListarInternosSafeAsync(
        decimal no,
        decimal estab,
        int top,
        CancellationToken cancellationToken)
    {
        try
        {
            var rows = await _pmStore.ListarAsync(no, estab, top, cancellationToken);
            return rows.Select(r =>
            {
                var (codigo, etiqueta, podeCancelar) = ClientePedidoEstadoMapper.MapInterno(r.EstadoInterno);
                return new ClientePedidoListaItem(
                    Bostamp: null,
                    Obrano: null,
                    Boano: null,
                    r.DataSubmissao,
                    Hora: null,
                    codigo,
                    etiqueta,
                    r.Etotaldeb,
                    podeCancelar,
                    r.PedidoId,
                    r.NumeroInterno,
                    ClientePedidoEstadoMapper.OrigemInterno);
            }).ToList();
        }
        catch (SqlException ex) when (ClientePmSqlErrorRules.IsMissingPmPedidoObject(ex.Number, ex.Message))
        {
            // Scripts 096 ainda não aplicados — lista só legado.
            _log.LogInformation(
                "Tabelas u_HcaPmPedido* indisponíveis (SQL {Number}); lista interna omitida.",
                ex.Number);
            return Array.Empty<ClientePedidoListaItem>();
        }
        catch (SqlException ex)
        {
            _log.LogError(ex, "Falha a listar pedidos internos Mobile (ClNo={ClNo}).", no);
            throw;
        }
    }

    private async Task<IReadOnlyList<ClientePedidoListaItem>> ListarLegadoAsync(
        decimal no,
        decimal estab,
        int top,
        CancellationToken cancellationToken)
    {
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
                CASE WHEN c.bostamp IS NULL THEN CAST(0 AS bit) ELSE CAST(1 AS bit) END AS Cancelado,
                CAST(ISNULL(bo.fechada, 0) AS bit) AS Fechada
            FROM dbo.bo bo WITH (NOLOCK)
            LEFT JOIN dbo.u_HcaPedidoMobileCancel c WITH (NOLOCK)
                ON c.bostamp = bo.bostamp
            WHERE bo.ndos = @ndos
              AND bo.no = @no
              AND bo.estab = @estab
              AND ISNULL(bo.fechada, 0) = 0
              AND c.bostamp IS NULL
            ORDER BY bo.dataobra DESC, bo.obrano DESC
            """,
            new { top, ndos = _cliente.PedidoMobileNdos, no, estab },
            cancellationToken: cancellationToken));

        return rows.Select(r =>
        {
            var (codigo, etiqueta, podeCancelar) = ClientePedidoEstadoMapper.Map(cancelado: false);
            return new ClientePedidoListaItem(
                r.Bostamp, r.Obrano, r.Boano, r.DataObra, r.Hora,
                codigo, etiqueta, r.Etotaldeb, podeCancelar,
                PedidoId: null,
                NumeroInterno: null,
                ClientePedidoEstadoMapper.OrigemLegado);
        }).ToList();
    }

    private async Task<ClientePedidoDetalhe?> ObterLegadoAsync(
        decimal no,
        decimal estab,
        string bostamp,
        CancellationToken cancellationToken)
    {
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
                CASE WHEN c.bostamp IS NULL THEN CAST(0 AS bit) ELSE CAST(1 AS bit) END AS Cancelado,
                CAST(ISNULL(bo.fechada, 0) AS bit) AS Fechada
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

        if (cab is null || cab.Cancelado || cab.Fechada)
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

        var (codigo, etiqueta, podeCancelar) = ClientePedidoEstadoMapper.Map(cancelado: false);
        return new ClientePedidoDetalhe(
            cab.Bostamp, cab.Obrano, cab.Boano, cab.DataObra, cab.Hora,
            codigo, etiqueta, cab.Etotaldeb, podeCancelar,
            linhas.Select(l => new ClientePedidoLinhaDetalhe(
                l.Ref, l.Design, l.Cor, l.Qtt, l.PrecoUnitario, l.TotalLinha)).ToList(),
            PedidoId: null,
            NumeroInterno: null,
            ClientePedidoEstadoMapper.OrigemLegado);
    }

    private async Task<(bool Ok, string? Error)> CancelarLegadoAsync(
        decimal no,
        decimal estab,
        string bostamp,
        CancellationToken cancellationToken)
    {
        var detalhe = await ObterLegadoAsync(no, estab, bostamp, cancellationToken);
        if (detalhe is null)
            return (false, "nao_encontrado");
        if (!detalhe.PodeCancelar)
            return (false, "estado_invalido");

        await using var conn = new SqlConnection(_phc.ConnectionString);
        try
        {
            var p = new DynamicParameters();
            p.Add("@bostamp", bostamp);
            p.Add("@no", no);
            p.Add("@estab", estab);
            p.Add("@ndos", _cliente.PedidoMobileNdos);
            p.Add("@motivo", "Cancelado pelo cliente no Portal Mobile");
            p.Add("@usrinis", "MOB");

            await conn.ExecuteAsync(new CommandDefinition(
                "dbo.sp_HCA_cancelar_pedido_mobile",
                p,
                commandType: CommandType.StoredProcedure,
                cancellationToken: cancellationToken));
            return (true, null);
        }
        catch (SqlException ex) when (ex.Number is 2627 or 2601)
        {
            return (false, "ja_cancelado");
        }
        catch (SqlException ex) when (
            ex.Message.Contains("já cancelado", StringComparison.OrdinalIgnoreCase)
            || ex.Message.Contains("já fechado", StringComparison.OrdinalIgnoreCase))
        {
            return (false, "ja_cancelado");
        }
    }

    private static ClientePedidoDetalhe MapDetalheInterno(ClientePmPedidoPersistido p)
    {
        var (codigo, etiqueta, podeCancelar) = ClientePedidoEstadoMapper.MapInterno(p.EstadoInterno);
        var linhas = (p.Linhas ?? Array.Empty<ClientePmLinhaPersistida>())
            .Select(l => new ClientePedidoLinhaDetalhe(
                l.Ref, l.Design, l.Cor, l.Qtt, l.PrecoUnitario, l.TotalLinha))
            .ToList();

        return new ClientePedidoDetalhe(
            Bostamp: null,
            Obrano: null,
            Boano: null,
            p.DataSubmissao,
            Hora: null,
            codigo,
            etiqueta,
            p.Etotaldeb,
            podeCancelar,
            linhas,
            p.PedidoId,
            p.NumeroInterno,
            ClientePedidoEstadoMapper.OrigemInterno);
    }

    private static async Task<ClientePmPedidoPersistido?> ObterInternoSafeAsync(
        Func<Task<ClientePmPedidoPersistido?>> load)
    {
        try
        {
            return await load();
        }
        catch (SqlException)
        {
            return null;
        }
    }

    /// <summary>
    /// bostamp PHC (NEWID truncado) contém letras/hífens e ~23 chars.
    /// PedidoId interno = só dígitos e comprimento curto — sem colisão prática.
    /// </summary>
    private static bool TryParsePedidoId(string id, out long pedidoId)
    {
        pedidoId = 0;
        if (id.Length is 0 or > 18)
            return false;
        for (var i = 0; i < id.Length; i++)
        {
            if (!char.IsAsciiDigit(id[i]))
                return false;
        }

        return long.TryParse(id, NumberStyles.None, CultureInfo.InvariantCulture, out pedidoId)
               && pedidoId > 0;
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
        public bool Fechada { get; init; }
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
