using System.Data;
using Dapper;
using Microsoft.Data.SqlClient;
using Microsoft.Extensions.Logging;
using Microsoft.Extensions.Options;
using Portal.Application.Cliente;
using Portal.Application.Encomendas;
using Portal.Infrastructure.Options;

namespace Portal.Infrastructure.Cliente;

public sealed class StaffPmBo67Gateway : IStaffPmBo67Gateway
{
    private readonly PhcOptions _phc;
    private readonly PortalClienteOptions _cliente;
    private readonly ILogger<StaffPmBo67Gateway> _log;

    public StaffPmBo67Gateway(
        IOptions<PhcOptions> phc,
        IOptions<PortalClienteOptions> cliente,
        ILogger<StaffPmBo67Gateway> log)
    {
        _phc = phc.Value;
        _cliente = cliente.Value;
        _log = log;
    }

    public async Task<StaffPmBo67CreateResult> CriarAsync(
        ClientePmPedidoPersistido pedido,
        string usrinis,
        CancellationToken cancellationToken)
    {
        var idemKey = StaffPmPedidoRules.FormatAprovacaoIdempotencyKey(pedido.PedidoId);

        await using var conn = new SqlConnection(_phc.ConnectionString);
        await conn.OpenAsync(cancellationToken);

        var tvp = PedidoMobileLinhaTvp.BuildStaffComPrecoOperador(pedido.Linhas!);

        var p = new DynamicParameters();
        p.Add("@no", pedido.ClNo);
        p.Add("@estab", pedido.ClEstab);
        p.Add("@Linhas", tvp.AsTableValuedParameter("dbo.HCA_PedidoMobileLinhaType"));
        p.Add("@IdempotencyKey", idemKey);
        p.Add("@usrinis", usrinis);

        try
        {
            var sp = await conn.QuerySingleAsync<SpCriarResult>(new CommandDefinition(
                "dbo.sp_HCA_criar_pedido_mobile",
                p,
                commandType: CommandType.StoredProcedure,
                cancellationToken: cancellationToken));

            return new StaffPmBo67CreateResult(
                sp.alreadyExists,
                sp.bostamp.Trim(),
                sp.obrano,
                sp.boano,
                sp.ndos);
        }
        catch (SqlException ex)
        {
            _log.LogError(ex, "Falha SP sp_HCA_criar_pedido_mobile PedidoId={PedidoId}", pedido.PedidoId);
            throw new PortalBusinessException(
                $"Falha ao criar dossier PHC (ndos={_cliente.PedidoMobileNdos}): {ex.Message}",
                statusCode: 502);
        }
    }

    private sealed class SpCriarResult
    {
        public bool alreadyExists { get; init; }
        public string bostamp { get; init; } = "";
        public decimal obrano { get; init; }
        public decimal boano { get; init; }
        public decimal ndos { get; init; }
    }
}
