using System.Data;
using Dapper;
using Microsoft.Data.SqlClient;
using Microsoft.Extensions.Options;
using Portal.Application.Encomendas;
using Portal.Infrastructure.Options;

namespace Portal.Infrastructure.Encomendas;

public sealed class EncomendasCommands : IEncomendasCommands
{
    private readonly PhcOptions _options;

    public EncomendasCommands(IOptions<PhcOptions> options)
    {
        _options = options.Value;
    }

    public async Task<QuantidadeAutorizadaAtualizadaDto> AtualizarQuantidadeAutorizadaAsync(
        string biStamp,
        decimal quantidadeAutorizada,
        string usrLogin,
        decimal? valorAnteriorEsperado,
        bool permitirAcimaStock = false,
        string? usrinis = null,
        CancellationToken cancellationToken = default)
    {
        await using var connection = new SqlConnection(_options.ConnectionString);
        await connection.OpenAsync(cancellationToken);

        try
        {
            var rows = (await connection.QueryAsync<QtdAutRow>(
                new CommandDefinition(
                    "dbo.sp_HCA_atualizar_qtd_autorizada",
                    new
                    {
                        bistamp = biStamp.Trim(),
                        quantidade_autorizada = quantidadeAutorizada,
                        usrlogin = usrLogin.Trim(),
                        valor_anterior_esperado = valorAnteriorEsperado,
                        permitir_acima_stock = permitirAcimaStock,
                        usrinis = string.IsNullOrWhiteSpace(usrinis) ? null : usrinis.Trim()
                    },
                    commandType: CommandType.StoredProcedure,
                    cancellationToken: cancellationToken))).ToList();

            var row = rows.FirstOrDefault()
                ?? throw new PortalBusinessException("Linha não encontrada após actualização.", 404);

            var original = row.quantidade_original_considerada != 0
                ? row.quantidade_original_considerada
                : (row.quantidade_original_campo != 0
                    ? row.quantidade_original_campo
                    : row.quantidade_atual);

            return new QuantidadeAutorizadaAtualizadaDto(
                row.bistamp.Trim(),
                row.quantidade_autorizada,
                string.IsNullOrWhiteSpace(row.quantidade_autorizada_por)
                    ? null
                    : row.quantidade_autorizada_por.Trim(),
                row.quantidade_autorizada_em,
                row.quantidade_atual,
                original,
                original - row.quantidade_fornecida,
                row.primeira_autorizacao);
        }
        catch (SqlException ex)
        {
            throw MapSql(ex);
        }
    }

    public async Task<LinhaAtualizadaDto> AtualizarLinhaQttPrecoAsync(
        string biStamp,
        decimal? quantidade,
        decimal? precoUnitario,
        string usrinis,
        decimal? quantidadeAnteriorEsperada,
        decimal? precoAnteriorEsperado,
        CancellationToken cancellationToken = default)
    {
        await using var connection = new SqlConnection(_options.ConnectionString);
        await connection.OpenAsync(cancellationToken);

        try
        {
            var rows = (await connection.QueryAsync<LinhaQttPrecoRow>(
                new CommandDefinition(
                    "dbo.sp_HCA_atualizar_linha_qtt_preco",
                    new
                    {
                        bistamp = biStamp.Trim(),
                        quantidade,
                        preco = precoUnitario,
                        usrinis = usrinis.Trim(),
                        qtt_anterior_esperado = quantidadeAnteriorEsperada,
                        preco_anterior_esperado = precoAnteriorEsperado
                    },
                    commandType: CommandType.StoredProcedure,
                    cancellationToken: cancellationToken))).ToList();

            var row = rows.FirstOrDefault()
                ?? throw new PortalBusinessException("Linha não encontrada após actualização.", 404);

            var originalQtt = row.quantidade_original_campo != 0
                ? row.quantidade_original_campo
                : row.quantidade_atual;
            var originalPreco = row.preco_original_campo != 0
                ? row.preco_original_campo
                : row.preco_unitario;

            return new LinhaAtualizadaDto(
                row.bistamp.Trim(),
                row.quantidade_atual,
                originalQtt,
                row.preco_unitario,
                originalPreco,
                string.IsNullOrWhiteSpace(row.usrinis) ? null : row.usrinis.Trim(),
                row.usrdata?.ToString("yyyy-MM-dd"),
                string.IsNullOrWhiteSpace(row.usrhora) ? null : row.usrhora.Trim());
        }
        catch (SqlException ex)
        {
            throw MapSql(ex);
        }
    }

    public async Task<AlocarArtigoResponseDto> AlocarProporcionalAsync(
        string artigoRef,
        string usrLogin,
        bool simular,
        decimal? quantidadeDisponivel,
        string? cor,
        bool filtrarCor,
        CancellationToken cancellationToken = default)
    {
        await using var connection = new SqlConnection(_options.ConnectionString);
        await connection.OpenAsync(cancellationToken);

        try
        {
            var p = new DynamicParameters();
            // PR2-A: capacidade vem só da previsão aberta no SP — não enviar stock do cliente.
            _ = quantidadeDisponivel;
            p.Add("ref", artigoRef.Trim());
            p.Add("usrlogin", usrLogin.Trim());
            p.Add("simular", simular);
            p.Add("disponivel", (decimal?)null);
            p.Add("cor", filtrarCor ? (cor ?? string.Empty) : null);
            p.Add("filtrar_cor", filtrarCor);

            await using var multi = await connection.QueryMultipleAsync(
                new CommandDefinition(
                    "dbo.sp_HCA_alocacao_proporcional",
                    p,
                    commandType: CommandType.StoredProcedure,
                    cancellationToken: cancellationToken));

            var cab = await multi.ReadSingleAsync<AlocacaoCabRow>();
            var linhas = (await multi.ReadAsync<AlocacaoLinhaRow>()).ToList();

            return new AlocarArtigoResponseDto(
                cab.Ref?.Trim() ?? artigoRef.Trim(),
                cab.stock_disponivel,
                cab.disponivel_usado,
                "u_HcaPrevEntrada",
                cab.simular,
                cab.soma_proposta,
                linhas.Select(l => new AlocacaoLinhaDto(
                    l.bistamp?.Trim() ?? string.Empty,
                    l.bostamp?.Trim() ?? string.Empty,
                    l.obrano,
                    l.quantidade_por_satisfazer,
                    l.quantidade_proposta)).ToList());
        }
        catch (SqlException ex)
        {
            throw MapSql(ex);
        }
    }

    public async Task<ProntaPickingAtualizadaDto> MarcarProntaPickingAsync(
        string boStamp,
        bool pronta,
        string usrLogin,
        string? usrinis = null,
        bool confirmarLinhasSemAutorizacao = false,
        string? motivo = null,
        CancellationToken cancellationToken = default)
    {
        await using var connection = new SqlConnection(_options.ConnectionString);
        await connection.OpenAsync(cancellationToken);

        try
        {
            var rows = (await connection.QueryAsync<ProntaPickingRow>(
                new CommandDefinition(
                    "dbo.sp_HCA_marcar_pronta_picking",
                    new
                    {
                        bostamp = boStamp.Trim(),
                        pronta,
                        usrlogin = usrLogin.Trim(),
                        usrinis = string.IsNullOrWhiteSpace(usrinis) ? null : usrinis.Trim(),
                        confirmar_linhas_zero = confirmarLinhasSemAutorizacao,
                        motivo = string.IsNullOrWhiteSpace(motivo) ? null : motivo.Trim()
                    },
                    commandType: CommandType.StoredProcedure,
                    cancellationToken: cancellationToken))).ToList();

            var row = rows.FirstOrDefault()
                ?? throw new PortalBusinessException("Encomenda não encontrada após actualização.", 404);

            return new ProntaPickingAtualizadaDto(
                row.bostamp.Trim(),
                row.pronta_picking,
                string.IsNullOrWhiteSpace(row.pronta_picking_por) ? null : row.pronta_picking_por.Trim(),
                row.pronta_picking_em,
                row.pick_status);
        }
        catch (SqlException ex)
        {
            throw MapSql(ex);
        }
    }

    public Task<PickWorkflowAtualizadaDto> PickingStartAsync(
        string boStamp,
        string usrLogin,
        string? usrinis = null,
        CancellationToken cancellationToken = default)
        => ExecutarPickingWorkflowAsync("dbo.sp_HCA_picking_start", boStamp, usrLogin, usrinis, null, cancellationToken);

    public Task<PickWorkflowAtualizadaDto> PickingCompleteAsync(
        string boStamp,
        string usrLogin,
        string? usrinis = null,
        CancellationToken cancellationToken = default)
        => ExecutarPickingWorkflowAsync("dbo.sp_HCA_picking_complete", boStamp, usrLogin, usrinis, null, cancellationToken);

    public Task<PickWorkflowAtualizadaDto> PickingCancelAsync(
        string boStamp,
        string usrLogin,
        string? usrinis = null,
        string? motivo = null,
        CancellationToken cancellationToken = default)
        => ExecutarPickingWorkflowAsync("dbo.sp_HCA_picking_cancel", boStamp, usrLogin, usrinis, motivo, cancellationToken);

    public Task<PickWorkflowAtualizadaDto> PickingBackToReadyAsync(
        string boStamp,
        string usrLogin,
        string? usrinis = null,
        CancellationToken cancellationToken = default)
        => ExecutarPickingWorkflowAsync("dbo.sp_HCA_picking_back_to_ready", boStamp, usrLogin, usrinis, null, cancellationToken);

    public Task<PickWorkflowAtualizadaDto> PickingReopenAsync(
        string boStamp,
        string usrLogin,
        string? usrinis = null,
        CancellationToken cancellationToken = default)
        => ExecutarPickingWorkflowAsync("dbo.sp_HCA_picking_reopen", boStamp, usrLogin, usrinis, null, cancellationToken);

    private async Task<PickWorkflowAtualizadaDto> ExecutarPickingWorkflowAsync(
        string procedureName,
        string boStamp,
        string usrLogin,
        string? usrinis,
        string? motivo,
        CancellationToken cancellationToken)
    {
        await using var connection = new SqlConnection(_options.ConnectionString);
        await connection.OpenAsync(cancellationToken);

        try
        {
            object parameters = motivo is null
                ? new
                {
                    bostamp = boStamp.Trim(),
                    usrlogin = usrLogin.Trim(),
                    usrinis = string.IsNullOrWhiteSpace(usrinis) ? null : usrinis.Trim()
                }
                : new
                {
                    bostamp = boStamp.Trim(),
                    usrlogin = usrLogin.Trim(),
                    usrinis = string.IsNullOrWhiteSpace(usrinis) ? null : usrinis.Trim(),
                    motivo = motivo.Trim()
                };

            var rows = (await connection.QueryAsync<PickWorkflowRow>(
                new CommandDefinition(
                    procedureName,
                    parameters,
                    commandType: CommandType.StoredProcedure,
                    cancellationToken: cancellationToken))).ToList();

            var row = rows.FirstOrDefault()
                ?? throw new PortalBusinessException("Encomenda não encontrada após actualização.", 404);

            return new PickWorkflowAtualizadaDto(
                row.bostamp.Trim(),
                row.pronta_picking,
                row.pick_status,
                string.IsNullOrWhiteSpace(row.pronta_picking_por) ? null : row.pronta_picking_por.Trim(),
                row.pronta_picking_em);
        }
        catch (SqlException ex)
        {
            throw MapSql(ex);
        }
    }

    public async Task<UrgenteAtualizadaDto> MarcarUrgenteAsync(
        string boStamp,
        bool urgente,
        string usrLogin,
        string? usrinis = null,
        CancellationToken cancellationToken = default)
    {
        await using var connection = new SqlConnection(_options.ConnectionString);
        await connection.OpenAsync(cancellationToken);

        try
        {
            var rows = (await connection.QueryAsync<UrgenteRow>(
                new CommandDefinition(
                    "dbo.sp_HCA_marcar_urgente_encomenda",
                    new
                    {
                        bostamp = boStamp.Trim(),
                        urgente,
                        usrlogin = usrLogin.Trim(),
                        usrinis = string.IsNullOrWhiteSpace(usrinis) ? null : usrinis.Trim()
                    },
                    commandType: CommandType.StoredProcedure,
                    cancellationToken: cancellationToken))).ToList();

            var row = rows.FirstOrDefault()
                ?? throw new PortalBusinessException("Encomenda não encontrada após actualização.", 404);

            return new UrgenteAtualizadaDto(row.bostamp.Trim(), row.urgente);
        }
        catch (SqlException ex)
        {
            throw MapSql(ex);
        }
    }

    public async Task<CancelarEncomendaAtualizadaDto> CancelarEncomendaAsync(
        string boStamp,
        string motivo,
        string usrLogin,
        string? usrinis = null,
        CancellationToken cancellationToken = default)
    {
        await using var connection = new SqlConnection(_options.ConnectionString);
        await connection.OpenAsync(cancellationToken);

        try
        {
            var rows = (await connection.QueryAsync<CancelarEncomendaRow>(
                new CommandDefinition(
                    "dbo.sp_HCA_cancelar_encomenda",
                    new
                    {
                        bostamp = boStamp.Trim(),
                        usrlogin = usrLogin.Trim(),
                        usrinis = string.IsNullOrWhiteSpace(usrinis) ? null : usrinis.Trim(),
                        motivo = motivo.Trim()
                    },
                    commandType: CommandType.StoredProcedure,
                    cancellationToken: cancellationToken))).ToList();

            var row = rows.FirstOrDefault()
                ?? throw new PortalBusinessException("Encomenda não encontrada após actualização.", 404);

            return new CancelarEncomendaAtualizadaDto(
                row.bostamp.Trim(),
                row.fechada,
                row.obrano,
                string.IsNullOrWhiteSpace(row.motivo) ? null : row.motivo.Trim());
        }
        catch (SqlException ex)
        {
            throw MapSql(ex);
        }
    }

    private static PortalBusinessException MapSql(SqlException ex)
    {
        var msg = ex.Message ?? "Erro SQL.";
        if (msg.Contains("LINHAS_SEM_AUTORIZACAO", StringComparison.OrdinalIgnoreCase))
            return new PortalBusinessException(
                "LINHAS_SEM_AUTORIZACAO: Existem linhas com quantidade autorizada a 0. Confirme para avançar.",
                409);
        if (msg.Contains("não encontrada", StringComparison.OrdinalIgnoreCase) &&
            !msg.Contains("não tem quantidade prevista", StringComparison.OrdinalIgnoreCase))
            return new PortalBusinessException(msg, 404);
        if (msg.Contains("Conflito", StringComparison.OrdinalIgnoreCase) ||
            msg.Contains("Transição inválida", StringComparison.OrdinalIgnoreCase) ||
            msg.Contains("congelada", StringComparison.OrdinalIgnoreCase))
            return new PortalBusinessException(msg, 409);
        // PR3-C — erros de previsão (sem teto: mensagem "Quantidade prevista insuficiente" deixou de ser emitida)
        if (msg.Contains("Quantidade prevista insuficiente", StringComparison.OrdinalIgnoreCase) ||
            msg.Contains("Não existe uma previsão de entrada aberta", StringComparison.OrdinalIgnoreCase) ||
            msg.Contains("não tem quantidade prevista registada", StringComparison.OrdinalIgnoreCase) ||
            msg.Contains("previsão fechada", StringComparison.OrdinalIgnoreCase))
            return new PortalBusinessException(msg, 409);
        // Legado: mensagem antiga do SP pré-PR2-A
        if (msg.Contains("Stock insuficiente", StringComparison.OrdinalIgnoreCase))
            return new PortalBusinessException(msg, 409);
        if (msg.Contains("inválida", StringComparison.OrdinalIgnoreCase) ||
            msg.Contains("obrigatório", StringComparison.OrdinalIgnoreCase) ||
            msg.Contains("Indicar", StringComparison.OrdinalIgnoreCase))
            return new PortalBusinessException(msg, 400);
        return new PortalBusinessException(msg, 400);
    }

    private sealed class QtdAutRow
    {
        public string bistamp { get; init; } = "";
        public decimal quantidade_autorizada { get; init; }
        public string? quantidade_autorizada_por { get; init; }
        public DateTime? quantidade_autorizada_em { get; init; }
        public decimal quantidade_atual { get; init; }
        public decimal quantidade_original_campo { get; init; }
        public decimal quantidade_original_considerada { get; init; }
        public decimal quantidade_fornecida { get; init; }
        public bool primeira_autorizacao { get; init; }
    }

    private sealed class LinhaQttPrecoRow
    {
        public string bistamp { get; init; } = "";
        public decimal quantidade_atual { get; init; }
        public decimal quantidade_original_campo { get; init; }
        public decimal preco_unitario { get; init; }
        public decimal preco_original_campo { get; init; }
        public string? usrinis { get; init; }
        public DateTime? usrdata { get; init; }
        public string? usrhora { get; init; }
    }

    private sealed class AlocacaoCabRow
    {
        public string? Ref { get; init; }
        public decimal stock_disponivel { get; init; }
        public decimal disponivel_usado { get; init; }
        public bool simular { get; init; }
        public decimal soma_proposta { get; init; }
    }

    private sealed class AlocacaoLinhaRow
    {
        public string? bistamp { get; init; }
        public string? bostamp { get; init; }
        public int obrano { get; init; }
        public decimal quantidade_por_satisfazer { get; init; }
        public decimal quantidade_proposta { get; init; }
    }

    private sealed class ProntaPickingRow
    {
        public string bostamp { get; init; } = "";
        public bool pronta_picking { get; init; }
        public string? pronta_picking_por { get; init; }
        public DateTime? pronta_picking_em { get; init; }
        public int pick_status { get; init; }
    }

    private sealed class PickWorkflowRow
    {
        public string bostamp { get; init; } = "";
        public bool pronta_picking { get; init; }
        public int pick_status { get; init; }
        public string? pronta_picking_por { get; init; }
        public DateTime? pronta_picking_em { get; init; }
    }

    private sealed class UrgenteRow
    {
        public string bostamp { get; init; } = "";
        public bool urgente { get; init; }
    }

    private sealed class CancelarEncomendaRow
    {
        public string bostamp { get; init; } = "";
        public bool fechada { get; init; }
        public int obrano { get; init; }
        public string? motivo { get; init; }
    }
}
