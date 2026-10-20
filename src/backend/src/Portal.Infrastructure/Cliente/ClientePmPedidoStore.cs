using Dapper;
using Microsoft.Data.SqlClient;
using Microsoft.Extensions.Options;
using Portal.Application.Cliente;
using Portal.Application.Encomendas;
using Portal.Infrastructure.Options;

namespace Portal.Infrastructure.Cliente;

public sealed class ClientePmPedidoStore : IClientePmPedidoStore
{
    private readonly PhcOptions _phc;

    public ClientePmPedidoStore(IOptions<PhcOptions> phc) => _phc = phc.Value;

    public async Task<ClientePmCreateOutcome> CriarAsync(
        decimal clNo,
        decimal clEstab,
        string idempotencyKey,
        string payloadHash,
        IReadOnlyList<ClientePmLinhaPersistida> linhas,
        CancellationToken cancellationToken)
    {
        if (linhas.Count == 0)
            throw new PortalBusinessException("É obrigatória pelo menos uma linha.");

        var etotal = linhas.Sum(l => l.TotalLinha);

        await using var conn = new SqlConnection(_phc.ConnectionString);
        await conn.OpenAsync(cancellationToken);
        await using var tx = (SqlTransaction)await conn.BeginTransactionAsync(cancellationToken);
        var rolledBack = false;

        async Task RollbackOnceAsync()
        {
            if (rolledBack)
                return;
            await tx.RollbackAsync(cancellationToken);
            rolledBack = true;
        }

        try
        {
            long pedidoId;
            DateTime dataSubmissao;
            try
            {
                var inserted = await conn.QuerySingleAsync<InsertCabRow>(new CommandDefinition(
                    """
                    INSERT INTO dbo.u_HcaPmPedido
                    (
                        NumeroInterno, ClNo, ClEstab, EstadoInterno,
                        DataSubmissao, DataAlteracao, Etotaldeb,
                        SubmissaoIdempotencyKey, SubmissaoPayloadHash, CriadoPor
                    )
                    OUTPUT INSERTED.PedidoId, INSERTED.DataSubmissao
                    VALUES
                    (
                        NULL, @clNo, @clEstab, N'recebido',
                        SYSUTCDATETIME(), SYSUTCDATETIME(), @etotal,
                        @idempotencyKey, @payloadHash, N'MOB'
                    )
                    """,
                    new { clNo, clEstab, etotal, idempotencyKey, payloadHash },
                    transaction: tx,
                    cancellationToken: cancellationToken));

                pedidoId = inserted.PedidoId;
                dataSubmissao = DateTime.SpecifyKind(inserted.DataSubmissao, DateTimeKind.Utc);
            }
            catch (SqlException ex) when (ex.Number is 2627 or 2601)
            {
                await RollbackOnceAsync();
                // P5: só tratar como idempotência a UK da chave; outras UK → erro genérico.
                if (!ClientePmSqlErrorRules.IsIdempotencyKeyUniqueViolation(ex.Number, ex.Message))
                {
                    throw new PortalBusinessException(
                        "Não foi possível gravar o pedido (conflito de dados).",
                        statusCode: 409);
                }

                // P1: já fizemos rollback — Resolve pode lançar 409 sem novo Rollback.
                return await ResolveIdempotentAsync(
                    conn, clNo, clEstab, idempotencyKey, payloadHash, cancellationToken);
            }

            var numero = ClientePedidoIdempotency.FormatNumeroInterno(pedidoId, dataSubmissao);
            var updated = await conn.ExecuteAsync(new CommandDefinition(
                """
                UPDATE dbo.u_HcaPmPedido
                SET NumeroInterno = @numero,
                    DataAlteracao = SYSUTCDATETIME()
                WHERE PedidoId = @pedidoId
                  AND NumeroInterno IS NULL
                """,
                new { numero, pedidoId },
                transaction: tx,
                cancellationToken: cancellationToken));

            if (updated != 1)
            {
                await RollbackOnceAsync();
                throw new InvalidOperationException("Falha a atribuir NumeroInterno ao pedido interno.");
            }

            foreach (var l in linhas.OrderBy(x => x.LinhaOrd))
            {
                await conn.ExecuteAsync(new CommandDefinition(
                    """
                    INSERT INTO dbo.u_HcaPmPedidoLin
                    (PedidoId, LinhaOrd, Ref, Design, Cor, Qtt, PrecoUnitario, TotalLinha)
                    VALUES
                    (@PedidoId, @LinhaOrd, @Ref, @Design, @Cor, @Qtt, @PrecoUnitario, @TotalLinha)
                    """,
                    new
                    {
                        PedidoId = pedidoId,
                        l.LinhaOrd,
                        Ref = l.Ref.Length > 18 ? l.Ref[..18] : l.Ref,
                        Design = l.Design.Length > 60 ? l.Design[..60] : l.Design,
                        Cor = l.Cor.Length > 100 ? l.Cor[..100] : l.Cor,
                        l.Qtt,
                        l.PrecoUnitario,
                        l.TotalLinha
                    },
                    transaction: tx,
                    cancellationToken: cancellationToken));
            }

            await tx.CommitAsync(cancellationToken);

            return new ClientePmCreateOutcome(
                false,
                new ClientePmPedidoPersistido(
                    pedidoId,
                    numero,
                    clNo,
                    clEstab,
                    "recebido",
                    dataSubmissao,
                    dataSubmissao,
                    etotal,
                    payloadHash,
                    linhas));
        }
        catch (PortalBusinessException)
        {
            await RollbackOnceAsync();
            throw;
        }
        catch
        {
            await RollbackOnceAsync();
            throw;
        }
    }

    public async Task<IReadOnlyList<ClientePmPedidoPersistido>> ListarAsync(
        decimal clNo,
        decimal clEstab,
        int top,
        CancellationToken cancellationToken)
    {
        top = Math.Clamp(top, 1, 50);
        await using var conn = new SqlConnection(_phc.ConnectionString);
        var rows = await conn.QueryAsync<CabRow>(new CommandDefinition(
            """
            SELECT TOP (@top)
                PedidoId,
                NumeroInterno,
                ClNo,
                ClEstab,
                EstadoInterno,
                DataSubmissao,
                DataAlteracao,
                CAST(Etotaldeb AS decimal(19,6)) AS Etotaldeb,
                SubmissaoPayloadHash
            FROM dbo.u_HcaPmPedido WITH (READCOMMITTED)
            WHERE ClNo = @clNo
              AND ClEstab = @clEstab
              AND NumeroInterno IS NOT NULL
            ORDER BY DataSubmissao DESC, PedidoId DESC
            """,
            new { top, clNo, clEstab },
            cancellationToken: cancellationToken));

        return rows.Select(MapCab).ToList();
    }

    public Task<ClientePmPedidoPersistido?> ObterPorIdAsync(
        decimal clNo,
        decimal clEstab,
        long pedidoId,
        CancellationToken cancellationToken) =>
        ObterAsync(clNo, clEstab, pedidoId: pedidoId, numeroInterno: null, cancellationToken);

    public Task<ClientePmPedidoPersistido?> ObterPorNumeroAsync(
        decimal clNo,
        decimal clEstab,
        string numeroInterno,
        CancellationToken cancellationToken) =>
        ObterAsync(clNo, clEstab, pedidoId: null, numeroInterno: numeroInterno, cancellationToken);

    private async Task<ClientePmPedidoPersistido?> ObterAsync(
        decimal clNo,
        decimal clEstab,
        long? pedidoId,
        string? numeroInterno,
        CancellationToken cancellationToken)
    {
        await using var conn = new SqlConnection(_phc.ConnectionString);
        var cab = await conn.QuerySingleOrDefaultAsync<CabRow>(new CommandDefinition(
            """
            SELECT
                PedidoId,
                NumeroInterno,
                ClNo,
                ClEstab,
                EstadoInterno,
                DataSubmissao,
                DataAlteracao,
                CAST(Etotaldeb AS decimal(19,6)) AS Etotaldeb,
                SubmissaoPayloadHash
            FROM dbo.u_HcaPmPedido WITH (READCOMMITTED)
            WHERE ClNo = @clNo
              AND ClEstab = @clEstab
              AND NumeroInterno IS NOT NULL
              AND (
                    (@pedidoId IS NOT NULL AND PedidoId = @pedidoId)
                 OR (@numeroInterno IS NOT NULL AND NumeroInterno = @numeroInterno)
              )
            """,
            new { clNo, clEstab, pedidoId, numeroInterno },
            cancellationToken: cancellationToken));

        if (cab is null)
            return null;

        var linhas = (await conn.QueryAsync<LinRow>(new CommandDefinition(
            """
            SELECT
                LinhaOrd,
                LTRIM(RTRIM(Ref)) AS Ref,
                LTRIM(RTRIM(Design)) AS Design,
                LTRIM(RTRIM(Cor)) AS Cor,
                CAST(Qtt AS decimal(18,4)) AS Qtt,
                CAST(PrecoUnitario AS decimal(19,6)) AS PrecoUnitario,
                CAST(TotalLinha AS decimal(19,6)) AS TotalLinha
            FROM dbo.u_HcaPmPedidoLin WITH (READCOMMITTED)
            WHERE PedidoId = @pedidoId
            ORDER BY LinhaOrd
            """,
            new { pedidoId = cab.PedidoId },
            cancellationToken: cancellationToken))).ToList();

        var mapped = MapCab(cab);
        return mapped with
        {
            Linhas = linhas.Select(l => new ClientePmLinhaPersistida(
                l.LinhaOrd, l.Ref, l.Design, l.Cor, l.Qtt, l.PrecoUnitario, l.TotalLinha)).ToList()
        };
    }

    private async Task<ClientePmCreateOutcome> ResolveIdempotentAsync(
        SqlConnection conn,
        decimal callerClNo,
        decimal callerClEstab,
        string idempotencyKey,
        string payloadHash,
        CancellationToken cancellationToken)
    {
        var existing = await conn.QuerySingleOrDefaultAsync<CabRow>(new CommandDefinition(
            """
            SELECT
                PedidoId,
                NumeroInterno,
                ClNo,
                ClEstab,
                EstadoInterno,
                DataSubmissao,
                DataAlteracao,
                CAST(Etotaldeb AS decimal(19,6)) AS Etotaldeb,
                SubmissaoPayloadHash
            FROM dbo.u_HcaPmPedido WITH (READCOMMITTED)
            WHERE SubmissaoIdempotencyKey = @idempotencyKey
            """,
            new { idempotencyKey },
            cancellationToken: cancellationToken));

        var kind = ClientePmIdempotencyResolve.Classify(
            callerClNo,
            callerClEstab,
            existing?.ClNo,
            existing?.ClEstab,
            existing?.NumeroInterno,
            existing?.SubmissaoPayloadHash,
            payloadHash);

        switch (kind)
        {
            case ClientePmIdempotencyResolve.OutcomeKind.IncompleteOrMissing:
                throw new PortalBusinessException(
                    "Não foi possível concluir a submissão. Tente novamente.",
                    statusCode: 503);

            case ClientePmIdempotencyResolve.OutcomeKind.OtherClientOrEstab:
                // P2: sem dados do outro cliente.
                throw new PortalBusinessException(
                    "Idempotency-Key já utilizada.",
                    statusCode: 409);

            case ClientePmIdempotencyResolve.OutcomeKind.SameClientDifferentHash:
                throw new PortalBusinessException(
                    "Idempotency-Key já utilizada com um pedido diferente.",
                    statusCode: 409);

            case ClientePmIdempotencyResolve.OutcomeKind.SameClientSameHash:
                break;

            default:
                throw new PortalBusinessException(
                    "Não foi possível concluir a submissão. Tente novamente.",
                    statusCode: 503);
        }

        var full = await ObterPorIdAsync(
            callerClNo, callerClEstab, existing!.PedidoId, cancellationToken);
        if (full is null)
        {
            throw new PortalBusinessException(
                "Não foi possível concluir a submissão. Tente novamente.",
                statusCode: 503);
        }

        return new ClientePmCreateOutcome(true, full);
    }

    private static ClientePmPedidoPersistido MapCab(CabRow r) =>
        new(
            r.PedidoId,
            r.NumeroInterno ?? "",
            r.ClNo,
            r.ClEstab,
            r.EstadoInterno,
            DateTime.SpecifyKind(r.DataSubmissao, DateTimeKind.Utc),
            DateTime.SpecifyKind(r.DataAlteracao, DateTimeKind.Utc),
            r.Etotaldeb,
            r.SubmissaoPayloadHash,
            null);

    private sealed class InsertCabRow
    {
        public long PedidoId { get; init; }
        public DateTime DataSubmissao { get; init; }
    }

    private sealed class CabRow
    {
        public long PedidoId { get; init; }
        public string? NumeroInterno { get; init; }
        public decimal ClNo { get; init; }
        public decimal ClEstab { get; init; }
        public string EstadoInterno { get; init; } = "";
        public DateTime DataSubmissao { get; init; }
        public DateTime DataAlteracao { get; init; }
        public decimal Etotaldeb { get; init; }
        public string SubmissaoPayloadHash { get; init; } = "";
    }

    private sealed class LinRow
    {
        public int LinhaOrd { get; init; }
        public string Ref { get; init; } = "";
        public string Design { get; init; } = "";
        public string Cor { get; init; } = "";
        public decimal Qtt { get; init; }
        public decimal PrecoUnitario { get; init; }
        public decimal TotalLinha { get; init; }
    }
}
