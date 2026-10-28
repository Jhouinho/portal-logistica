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
                var precoSub = l.PrecoSubmissao ?? l.PrecoUnitario;
                await conn.ExecuteAsync(new CommandDefinition(
                    """
                    INSERT INTO dbo.u_HcaPmPedidoLin
                    (PedidoId, LinhaOrd, Ref, Design, Cor, Qtt, PrecoUnitario, TotalLinha, PrecoSubmissao)
                    VALUES
                    (@PedidoId, @LinhaOrd, @Ref, @Design, @Cor, @Qtt, @PrecoUnitario, @TotalLinha, @PrecoSubmissao)
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
                        l.TotalLinha,
                        PrecoSubmissao = precoSub
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
                SubmissaoPayloadHash,
                NULLIF(LTRIM(RTRIM(Bostamp)), N'') AS Bostamp,
                Obrano,
                Boano,
                Ndos
            FROM dbo.u_HcaPmPedido WITH (READCOMMITTED)
            WHERE ClNo = @clNo
              AND ClEstab = @clEstab
              AND NumeroInterno IS NOT NULL
            ORDER BY DataSubmissao ASC, PedidoId ASC
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
                SubmissaoPayloadHash,
                NULLIF(LTRIM(RTRIM(Bostamp)), N'') AS Bostamp,
                Obrano,
                Boano,
                Ndos
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

        var linhas = await LoadLinhasAsync(conn, cab.PedidoId, cancellationToken);

        var mapped = MapCab(cab);
        return mapped with { Linhas = linhas };
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
                SubmissaoPayloadHash,
                NULLIF(LTRIM(RTRIM(Bostamp)), N'') AS Bostamp,
                Obrano,
                Boano,
                Ndos
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

    public async Task<IReadOnlyList<ClientePmPedidoPersistido>> ListarStaffAsync(
        string? filtroEstado,
        int top,
        CancellationToken cancellationToken)
    {
        top = Math.Clamp(top, 1, 200);
        var filtro = (filtroEstado ?? "pendentes").Trim().ToLowerInvariant();

        var where = filtro switch
        {
            "integrados" or "em_separacao" => """
                AND NULLIF(LTRIM(RTRIM(p.Bostamp)), N'') IS NOT NULL
                AND p.EstadoInterno IN (N'integrado', N'em_separacao')
                """,
            "pronto_levantamento" => """
                AND NULLIF(LTRIM(RTRIM(p.Bostamp)), N'') IS NOT NULL
                AND p.EstadoInterno = N'pronto_levantamento'
                """,
            "concluidos" or "concluido" => """
                AND NULLIF(LTRIM(RTRIM(p.Bostamp)), N'') IS NOT NULL
                AND p.EstadoInterno = N'concluido'
                """,
            "rejeitados" => "AND p.EstadoInterno = N'rejeitado'",
            "todos" => "",
            _ => """
                AND (
                     (p.EstadoInterno IN (N'recebido', N'em_analise')
                      AND NULLIF(LTRIM(RTRIM(p.Bostamp)), N'') IS NULL)
                  OR (p.EstadoInterno = N'em_aprovacao')
                )
                """
        };

        await using var conn = new SqlConnection(_phc.ConnectionString);
        var rows = await conn.QueryAsync<CabRow>(new CommandDefinition(
            $"""
            SELECT TOP (@top)
                p.PedidoId,
                p.NumeroInterno,
                p.ClNo,
                p.ClEstab,
                p.EstadoInterno,
                p.DataSubmissao,
                p.DataAlteracao,
                CAST(p.Etotaldeb AS decimal(19,6)) AS Etotaldeb,
                p.SubmissaoPayloadHash,
                NULLIF(LTRIM(RTRIM(p.Bostamp)), N'') AS Bostamp,
                p.Obrano,
                p.Boano,
                p.Ndos,
                p.MotivoRejeicao,
                p.DecididoPor,
                p.DataDecisao,
                LEFT(LTRIM(RTRIM(ISNULL(cl.nome, N''))), 55) AS ClienteNome
            FROM dbo.u_HcaPmPedido p WITH (READCOMMITTED)
            LEFT JOIN dbo.cl cl WITH (NOLOCK)
                ON cl.no = p.ClNo AND cl.estab = p.ClEstab
            WHERE p.NumeroInterno IS NOT NULL
              {where}
            ORDER BY p.DataSubmissao ASC, p.PedidoId ASC
            """,
            new { top },
            cancellationToken: cancellationToken));

        return rows.Select(MapCab).ToList();
    }

    public async Task<ClientePmPedidoPersistido?> ObterPorIdStaffAsync(
        long pedidoId,
        bool incluirLinhas,
        CancellationToken cancellationToken)
    {
        await using var conn = new SqlConnection(_phc.ConnectionString);
        var cab = await conn.QuerySingleOrDefaultAsync<CabRow>(new CommandDefinition(
            """
            SELECT
                p.PedidoId,
                p.NumeroInterno,
                p.ClNo,
                p.ClEstab,
                p.EstadoInterno,
                p.DataSubmissao,
                p.DataAlteracao,
                CAST(p.Etotaldeb AS decimal(19,6)) AS Etotaldeb,
                p.SubmissaoPayloadHash,
                NULLIF(LTRIM(RTRIM(p.Bostamp)), N'') AS Bostamp,
                p.Obrano,
                p.Boano,
                p.Ndos,
                p.MotivoRejeicao,
                p.DecididoPor,
                p.DataDecisao,
                LEFT(LTRIM(RTRIM(ISNULL(cl.nome, N''))), 55) AS ClienteNome
            FROM dbo.u_HcaPmPedido p WITH (READCOMMITTED)
            LEFT JOIN dbo.cl cl WITH (NOLOCK)
                ON cl.no = p.ClNo AND cl.estab = p.ClEstab
            WHERE p.PedidoId = @pedidoId
              AND p.NumeroInterno IS NOT NULL
            """,
            new { pedidoId },
            cancellationToken: cancellationToken));

        if (cab is null)
            return null;

        var mapped = MapCab(cab);
        if (!incluirLinhas)
            return mapped;

        var linhas = await LoadLinhasAsync(conn, pedidoId, cancellationToken);
        return mapped with { Linhas = linhas };
    }

    public async Task<ClientePmIntegracaoResult> TryAtualizarPrecosOperadorAsync(
        long pedidoId,
        IReadOnlyList<(int LinhaOrd, decimal PrecoUnitario)> precos,
        CancellationToken cancellationToken)
    {
        await using var conn = new SqlConnection(_phc.ConnectionString);
        await conn.OpenAsync(cancellationToken);
        await using var tx = await conn.BeginTransactionAsync(cancellationToken);

        async Task RollbackOnceAsync()
        {
            try { await tx.RollbackAsync(CancellationToken.None); }
            catch { /* ignore */ }
        }

        try
        {
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
                    SubmissaoPayloadHash,
                    NULLIF(LTRIM(RTRIM(Bostamp)), N'') AS Bostamp,
                    Obrano,
                    Boano,
                    Ndos,
                    MotivoRejeicao,
                    DecididoPor,
                    DataDecisao,
                    CAST(NULL AS varchar(55)) AS ClienteNome
                FROM dbo.u_HcaPmPedido WITH (UPDLOCK, ROWLOCK)
                WHERE PedidoId = @pedidoId
                  AND NumeroInterno IS NOT NULL
                """,
                new { pedidoId },
                transaction: tx,
                cancellationToken: cancellationToken));

            if (cab is null)
            {
                await RollbackOnceAsync();
                return new ClientePmIntegracaoResult(false, null);
            }

            if (!StaffPmPrecoRules.CanEditPrecos(cab.EstadoInterno, cab.Bostamp))
            {
                await RollbackOnceAsync();
                var blocked = await ObterPorIdStaffAsync(pedidoId, incluirLinhas: true, cancellationToken);
                return new ClientePmIntegracaoResult(false, blocked);
            }

            var linhas = await LoadLinhasAsync(conn, pedidoId, cancellationToken, tx);
            var err = StaffPmPrecoRules.ValidatePrecosOperador(linhas, precos);
            if (err is not null)
            {
                await RollbackOnceAsync();
                throw new PortalBusinessException(err);
            }

            decimal etotal = 0;
            foreach (var (ord, precoRaw) in precos)
            {
                var preco = StaffPmPrecoRules.RoundPreco(precoRaw);
                var qtt = linhas.First(l => l.LinhaOrd == ord).Qtt;
                var total = StaffPmPrecoRules.CalcTotalLinha(qtt, preco);
                etotal += total;

                var updatedLin = await conn.ExecuteAsync(new CommandDefinition(
                    """
                    UPDATE dbo.u_HcaPmPedidoLin
                    SET PrecoUnitario = @preco,
                        TotalLinha = @total
                    WHERE PedidoId = @pedidoId
                      AND LinhaOrd = @ord
                    """,
                    new { pedidoId, ord, preco, total },
                    transaction: tx,
                    cancellationToken: cancellationToken));

                if (updatedLin != 1)
                {
                    await RollbackOnceAsync();
                    throw new PortalBusinessException(
                        $"Falha a actualizar preço da linha {ord}.",
                        statusCode: 409);
                }
            }

            etotal = Math.Round(etotal, 6, MidpointRounding.AwayFromZero);
            var updatedCab = await conn.ExecuteAsync(new CommandDefinition(
                """
                UPDATE dbo.u_HcaPmPedido
                SET Etotaldeb = @etotal,
                    DataAlteracao = SYSUTCDATETIME()
                WHERE PedidoId = @pedidoId
                  AND EstadoInterno IN (N'recebido', N'em_analise')
                  AND NULLIF(LTRIM(RTRIM(Bostamp)), N'') IS NULL
                """,
                new { pedidoId, etotal },
                transaction: tx,
                cancellationToken: cancellationToken));

            if (updatedCab != 1)
            {
                await RollbackOnceAsync();
                throw new PortalBusinessException(
                    "O estado do pedido mudou — preços não foram gravados. Actualize e tente novamente.",
                    statusCode: 409);
            }

            await tx.CommitAsync(cancellationToken);
            var pedido = await ObterPorIdStaffAsync(pedidoId, incluirLinhas: true, cancellationToken);
            return new ClientePmIntegracaoResult(true, pedido);
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

    public async Task<ClientePmIntegracaoResult> TrySubstituirLinhasOperadorAsync(
        long pedidoId,
        IReadOnlyList<StaffPmLinhaEditRequest> pedidos,
        CancellationToken cancellationToken)
    {
        if (pedidos is null || pedidos.Count == 0)
            throw new PortalBusinessException("É obrigatória pelo menos uma linha.");

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
                    SubmissaoPayloadHash,
                    NULLIF(LTRIM(RTRIM(Bostamp)), N'') AS Bostamp,
                    Obrano,
                    Boano,
                    Ndos,
                    MotivoRejeicao,
                    DecididoPor,
                    DataDecisao,
                    CAST(NULL AS varchar(55)) AS ClienteNome
                FROM dbo.u_HcaPmPedido WITH (UPDLOCK, ROWLOCK)
                WHERE PedidoId = @pedidoId
                  AND NumeroInterno IS NOT NULL
                """,
                new { pedidoId },
                transaction: tx,
                cancellationToken: cancellationToken));

            if (cab is null)
            {
                await RollbackOnceAsync();
                return new ClientePmIntegracaoResult(false, null);
            }

            if (!StaffPmPrecoRules.CanEditPrecos(cab.EstadoInterno, cab.Bostamp))
            {
                await RollbackOnceAsync();
                var blocked = await ObterPorIdStaffAsync(pedidoId, incluirLinhas: true, cancellationToken);
                return new ClientePmIntegracaoResult(false, blocked);
            }

            var existentes = await LoadLinhasAsync(conn, pedidoId, cancellationToken, tx);
            var err = StaffPmPrecoRules.ValidateLinhasOperador(pedidos);
            if (err is not null)
            {
                await RollbackOnceAsync();
                throw new PortalBusinessException(err);
            }

            var byOrd = existentes.ToDictionary(l => l.LinhaOrd);
            var keptOrigens = new HashSet<int>();
            foreach (var p in pedidos)
            {
                if (p.LinhaOrd is int origem)
                {
                    if (!byOrd.ContainsKey(origem))
                    {
                        await RollbackOnceAsync();
                        throw new PortalBusinessException(
                            $"Linha {origem} já não existe neste pedido. Actualize e tente novamente.",
                            statusCode: 409);
                    }

                    if (!keptOrigens.Add(origem))
                    {
                        await RollbackOnceAsync();
                        throw new PortalBusinessException($"LinhaOrd de origem {origem} duplicado.");
                    }
                }
            }

            // Remoções (só quando necessário — evita DELETE em fluxos só UPDATE/INSERT).
            var toDelete = existentes.Where(e => !keptOrigens.Contains(e.LinhaOrd)).Select(e => e.LinhaOrd).ToList();
            foreach (var ord in toDelete)
            {
                try
                {
                    await conn.ExecuteAsync(new CommandDefinition(
                        """
                        DELETE FROM dbo.u_HcaPmPedidoLin
                        WHERE PedidoId = @pedidoId AND LinhaOrd = @ord
                        """,
                        new { pedidoId, ord },
                        transaction: tx,
                        cancellationToken: cancellationToken));
                }
                catch (SqlException ex) when (ex.Number is 229 or 230)
                {
                    await RollbackOnceAsync();
                    throw new PortalBusinessException(
                        "Sem permissão SQL para eliminar linhas (DELETE em u_HcaPmPedidoLin). Aplicar sql/105_grant_delete_u_HcaPmPedidoLin.sql.",
                        statusCode: 500);
                }
            }

            var maxOrd = existentes.Count == 0 ? 0 : existentes.Max(l => l.LinhaOrd);
            // Após deletes, recalcular max a partir das linhas mantidas + novas.
            if (keptOrigens.Count > 0)
                maxOrd = Math.Max(maxOrd, keptOrigens.Max());
            else
                maxOrd = 0;

            decimal etotal = 0;
            foreach (var p in pedidos)
            {
                var preco = StaffPmPrecoRules.RoundPreco(p.PrecoUnitario);
                var total = StaffPmPrecoRules.CalcTotalLinha(p.Qtt, preco);
                etotal += total;
                var refVal = (p.Ref ?? "").Trim();
                var designVal = (p.Design ?? "").Trim();
                var corVal = (p.Cor ?? "").Trim();
                if (refVal.Length > 18) refVal = refVal[..18];
                if (designVal.Length > 60) designVal = designVal[..60];
                if (corVal.Length > 100) corVal = corVal[..100];

                if (p.LinhaOrd is int origem)
                {
                    var updatedLin = await conn.ExecuteAsync(new CommandDefinition(
                        """
                        UPDATE dbo.u_HcaPmPedidoLin
                        SET Ref = @refVal,
                            Design = @designVal,
                            Cor = @corVal,
                            Qtt = @qtt,
                            PrecoUnitario = @preco,
                            TotalLinha = @total
                        WHERE PedidoId = @pedidoId
                          AND LinhaOrd = @origem
                        """,
                        new { pedidoId, origem, refVal, designVal, corVal, qtt = p.Qtt, preco, total },
                        transaction: tx,
                        cancellationToken: cancellationToken));

                    if (updatedLin != 1)
                    {
                        await RollbackOnceAsync();
                        throw new PortalBusinessException(
                            $"Falha a actualizar a linha {origem}.",
                            statusCode: 409);
                    }
                }
                else
                {
                    maxOrd++;
                    var precoSub = preco;
                    await conn.ExecuteAsync(new CommandDefinition(
                        """
                        INSERT INTO dbo.u_HcaPmPedidoLin
                        (PedidoId, LinhaOrd, Ref, Design, Cor, Qtt, PrecoUnitario, TotalLinha, PrecoSubmissao)
                        VALUES
                        (@pedidoId, @ord, @refVal, @designVal, @corVal, @qtt, @preco, @total, @precoSub)
                        """,
                        new
                        {
                            pedidoId,
                            ord = maxOrd,
                            refVal,
                            designVal,
                            corVal,
                            qtt = p.Qtt,
                            preco,
                            total,
                            precoSub
                        },
                        transaction: tx,
                        cancellationToken: cancellationToken));
                }
            }

            etotal = Math.Round(etotal, 6, MidpointRounding.AwayFromZero);
            var updatedCab = await conn.ExecuteAsync(new CommandDefinition(
                """
                UPDATE dbo.u_HcaPmPedido
                SET Etotaldeb = @etotal,
                    DataAlteracao = SYSUTCDATETIME()
                WHERE PedidoId = @pedidoId
                  AND EstadoInterno IN (N'recebido', N'em_analise')
                  AND NULLIF(LTRIM(RTRIM(Bostamp)), N'') IS NULL
                """,
                new { pedidoId, etotal },
                transaction: tx,
                cancellationToken: cancellationToken));

            if (updatedCab != 1)
            {
                await RollbackOnceAsync();
                throw new PortalBusinessException(
                    "O estado do pedido mudou — linhas não foram gravadas. Actualize e tente novamente.",
                    statusCode: 409);
            }

            await tx.CommitAsync(cancellationToken);
            var pedido = await ObterPorIdStaffAsync(pedidoId, incluirLinhas: true, cancellationToken);
            return new ClientePmIntegracaoResult(true, pedido);
        }
        catch (PortalBusinessException)
        {
            await RollbackOnceAsync();
            throw;
        }
        catch (SqlException ex) when (ex.Number is 229 or 230)
        {
            await RollbackOnceAsync();
            throw new PortalBusinessException(
                "Sem permissão SQL para gravar linhas do pedido. Verifique GRANTs em u_HcaPmPedidoLin (script 105).",
                statusCode: 500);
        }
        catch
        {
            await RollbackOnceAsync();
            throw;
        }
    }

    public async Task<ClientePmIntegracaoResult> TryClaimAprovacaoAsync(
        long pedidoId,
        CancellationToken cancellationToken)
    {
        await using var conn = new SqlConnection(_phc.ConnectionString);
        var updated = await conn.ExecuteAsync(new CommandDefinition(
            """
            UPDATE dbo.u_HcaPmPedido
            SET EstadoInterno = N'em_aprovacao',
                DataAlteracao = SYSUTCDATETIME()
            WHERE PedidoId = @pedidoId
              AND NumeroInterno IS NOT NULL
              AND EstadoInterno IN (N'recebido', N'em_analise')
              AND NULLIF(LTRIM(RTRIM(Bostamp)), N'') IS NULL
            """,
            new { pedidoId },
            cancellationToken: cancellationToken));

        var pedido = await ObterPorIdStaffAsync(pedidoId, incluirLinhas: true, cancellationToken);
        return new ClientePmIntegracaoResult(updated > 0, pedido);
    }

    public async Task<ClientePmIntegracaoResult> TryMarcarIntegradoAsync(
        long pedidoId,
        string bostamp,
        decimal obrano,
        decimal boano,
        decimal ndos,
        string? decididoPor,
        CancellationToken cancellationToken)
    {
        bostamp = bostamp.Trim();
        if (bostamp.Length == 0)
            throw new ArgumentException("bostamp obrigatório.", nameof(bostamp));

        await using var conn = new SqlConnection(_phc.ConnectionString);
        var updated = await conn.ExecuteAsync(new CommandDefinition(
            """
            UPDATE dbo.u_HcaPmPedido
            SET EstadoInterno = N'em_separacao',
                Bostamp = LEFT(@bostamp, 25),
                Obrano = @obrano,
                Boano = @boano,
                Ndos = @ndos,
                DecididoPor = LEFT(NULLIF(LTRIM(RTRIM(@decididoPor)), N''), 16),
                DataDecisao = SYSUTCDATETIME(),
                DataAlteracao = SYSUTCDATETIME()
            WHERE PedidoId = @pedidoId
              AND NumeroInterno IS NOT NULL
              AND EstadoInterno IN (N'recebido', N'em_analise', N'em_aprovacao')
              AND (
                    NULLIF(LTRIM(RTRIM(Bostamp)), N'') IS NULL
                 OR LTRIM(RTRIM(Bostamp)) = @bostamp
              )
            """,
            new { pedidoId, bostamp, obrano, boano, ndos, decididoPor },
            cancellationToken: cancellationToken));

        var pedido = await ObterPorIdStaffAsync(pedidoId, incluirLinhas: false, cancellationToken);
        return new ClientePmIntegracaoResult(updated > 0, pedido);
    }

    public async Task<ClientePmIntegracaoResult> TryAvancarEstadoOperacionalAsync(
        long pedidoId,
        string estadoDestino,
        string? decididoPor,
        CancellationToken cancellationToken)
    {
        var dest = (estadoDestino ?? "").Trim().ToLowerInvariant();
        if (dest is not ("pronto_levantamento" or "concluido"))
            throw new ArgumentException("estadoDestino inválido.", nameof(estadoDestino));

        var fromClause = dest == "pronto_levantamento"
            ? "AND EstadoInterno IN (N'integrado', N'em_separacao')"
            : "AND EstadoInterno = N'pronto_levantamento'";

        await using var conn = new SqlConnection(_phc.ConnectionString);
        var updated = await conn.ExecuteAsync(new CommandDefinition(
            $"""
            UPDATE dbo.u_HcaPmPedido
            SET EstadoInterno = @dest,
                DecididoPor = LEFT(NULLIF(LTRIM(RTRIM(@decididoPor)), N''), 16),
                DataDecisao = SYSUTCDATETIME(),
                DataAlteracao = SYSUTCDATETIME()
            WHERE PedidoId = @pedidoId
              AND NumeroInterno IS NOT NULL
              AND NULLIF(LTRIM(RTRIM(Bostamp)), N'') IS NOT NULL
              {fromClause}
            """,
            new { pedidoId, dest, decididoPor },
            cancellationToken: cancellationToken));

        var pedido = await ObterPorIdStaffAsync(pedidoId, incluirLinhas: false, cancellationToken);
        return new ClientePmIntegracaoResult(updated > 0, pedido);
    }

    public async Task<ClientePmIntegracaoResult> TryRejeitarAsync(
        long pedidoId,
        string? motivo,
        string? decididoPor,
        CancellationToken cancellationToken)
    {
        var motivoNorm = string.IsNullOrWhiteSpace(motivo)
            ? null
            : motivo.Trim();
        if (motivoNorm is { Length: > 500 })
            motivoNorm = motivoNorm[..500];

        await using var conn = new SqlConnection(_phc.ConnectionString);
        var updated = await conn.ExecuteAsync(new CommandDefinition(
            """
            UPDATE dbo.u_HcaPmPedido
            SET EstadoInterno = N'rejeitado',
                MotivoRejeicao = @motivoNorm,
                DecididoPor = LEFT(NULLIF(LTRIM(RTRIM(@decididoPor)), N''), 16),
                DataDecisao = SYSUTCDATETIME(),
                DataAlteracao = SYSUTCDATETIME()
            WHERE PedidoId = @pedidoId
              AND NumeroInterno IS NOT NULL
              AND EstadoInterno IN (N'recebido', N'em_analise')
              AND NULLIF(LTRIM(RTRIM(Bostamp)), N'') IS NULL
            """,
            new { pedidoId, motivoNorm, decididoPor },
            cancellationToken: cancellationToken));

        var pedido = await ObterPorIdStaffAsync(pedidoId, incluirLinhas: false, cancellationToken);
        return new ClientePmIntegracaoResult(updated > 0, pedido);
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
            null,
            r.Bostamp,
            r.Obrano,
            r.Boano,
            r.Ndos,
            r.MotivoRejeicao,
            r.DecididoPor,
            r.DataDecisao is null ? null : DateTime.SpecifyKind(r.DataDecisao.Value, DateTimeKind.Utc),
            r.ClienteNome);

    private static async Task<IReadOnlyList<ClientePmLinhaPersistida>> LoadLinhasAsync(
        SqlConnection conn,
        long pedidoId,
        CancellationToken cancellationToken,
        System.Data.Common.DbTransaction? tx = null)
    {
        var linhas = (await conn.QueryAsync<LinRow>(new CommandDefinition(
            """
            SELECT
                LinhaOrd,
                LTRIM(RTRIM(Ref)) AS Ref,
                LTRIM(RTRIM(Design)) AS Design,
                LTRIM(RTRIM(Cor)) AS Cor,
                CAST(Qtt AS decimal(18,4)) AS Qtt,
                CAST(PrecoUnitario AS decimal(19,6)) AS PrecoUnitario,
                CAST(TotalLinha AS decimal(19,6)) AS TotalLinha,
                CAST(PrecoSubmissao AS decimal(19,6)) AS PrecoSubmissao
            FROM dbo.u_HcaPmPedidoLin WITH (READCOMMITTED)
            WHERE PedidoId = @pedidoId
            ORDER BY LinhaOrd
            """,
            new { pedidoId },
            transaction: tx,
            cancellationToken: cancellationToken))).ToList();

        return linhas.Select(MapLinha).ToList();
    }

    private static ClientePmLinhaPersistida MapLinha(LinRow l) =>
        new(
            l.LinhaOrd,
            l.Ref,
            l.Design,
            l.Cor,
            l.Qtt,
            l.PrecoUnitario,
            l.TotalLinha,
            l.PrecoSubmissao ?? l.PrecoUnitario);

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
        public string? Bostamp { get; init; }
        public decimal? Obrano { get; init; }
        public decimal? Boano { get; init; }
        public decimal? Ndos { get; init; }
        public string? MotivoRejeicao { get; init; }
        public string? DecididoPor { get; init; }
        public DateTime? DataDecisao { get; init; }
        public string? ClienteNome { get; init; }
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
        public decimal? PrecoSubmissao { get; init; }
    }
}
