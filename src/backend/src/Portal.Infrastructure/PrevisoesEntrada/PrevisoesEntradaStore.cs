using System.Data;
using System.Text.Json;
using Dapper;
using Microsoft.Data.SqlClient;
using Microsoft.Extensions.Options;
using Portal.Application.Encomendas;
using Portal.Application.PrevisoesEntrada;
using Portal.Infrastructure.Options;

namespace Portal.Infrastructure.PrevisoesEntrada;

public sealed class PrevisoesEntradaStore : IPrevisoesEntradaStore
{
    private readonly PhcOptions _options;

    public PrevisoesEntradaStore(IOptions<PhcOptions> options)
    {
        _options = options.Value;
    }

    public async Task<IReadOnlyList<PrevisaoEntradaListaRow>> ListarAsync(
        CancellationToken cancellationToken = default)
    {
        await using var connection = new SqlConnection(_options.ConnectionString);
        await connection.OpenAsync(cancellationToken);

        var rows = await connection.QueryAsync<ListaDb>(
            new CommandDefinition(
                "dbo.sp_HCA_prev_entrada_listar",
                commandType: CommandType.StoredProcedure,
                cancellationToken: cancellationToken));

        return rows.Select(r => new PrevisaoEntradaListaRow(
            r.Id,
            r.DataInicio,
            r.DataFim,
            r.Fechada,
            r.FechadaEm,
            r.FechadaPor,
            r.TotalLinhas,
            r.QuantidadeTotal)).ToList();
    }

    public async Task<PrevisaoEntradaDetalheRow?> ObterAsync(
        Guid id,
        CancellationToken cancellationToken = default)
    {
        await using var connection = new SqlConnection(_options.ConnectionString);
        await connection.OpenAsync(cancellationToken);

        await using var multi = await connection.QueryMultipleAsync(
            new CommandDefinition(
                "dbo.sp_HCA_prev_entrada_obter",
                new { id },
                commandType: CommandType.StoredProcedure,
                commandTimeout: 60,
                cancellationToken: cancellationToken));

        var cab = await multi.ReadSingleOrDefaultAsync<CabDb>();
        if (cab is null) return null;

        var linhas = (await multi.ReadAsync<LinhaDb>()).ToList();
        return MapDetalhe(cab, linhas);
    }

    public async Task<(Guid Id, DateOnly DataInicio, DateOnly DataFim)> CriarAsync(
        DateOnly dataInicio,
        DateOnly dataFim,
        string usrLogin,
        CancellationToken cancellationToken = default)
    {
        await using var connection = new SqlConnection(_options.ConnectionString);
        await connection.OpenAsync(cancellationToken);

        var p = new DynamicParameters();
        p.Add("dataInicio", dataInicio.ToDateTime(TimeOnly.MinValue));
        p.Add("dataFim", dataFim.ToDateTime(TimeOnly.MinValue));
        p.Add("usrlogin", usrLogin ?? string.Empty);
        p.Add("id", dbType: DbType.Guid, direction: ParameterDirection.Output);

        try
        {
            var row = await connection.QuerySingleAsync<CriarDb>(
                new CommandDefinition(
                    "dbo.sp_HCA_prev_entrada_criar",
                    p,
                    commandType: CommandType.StoredProcedure,
                    cancellationToken: cancellationToken));

            return (
                row.Id,
                DateOnly.FromDateTime(row.DataInicio),
                DateOnly.FromDateTime(row.DataFim));
        }
        catch (SqlException ex) when (IsConflict(ex))
        {
            throw new PortalBusinessException(ex.Message, 409);
        }
        catch (SqlException ex) when (ex.Number >= 50000)
        {
            throw new PortalBusinessException(ex.Message);
        }
    }

    public async Task<PrevisaoEntradaDetalheRow> GuardarAsync(
        Guid id,
        string usrLogin,
        DateOnly dataInicio,
        DateOnly dataFim,
        IReadOnlyList<(string Ref, string Cor, decimal QuantidadePrevista)> linhas,
        CancellationToken cancellationToken = default)
    {
        await using var connection = new SqlConnection(_options.ConnectionString);
        await connection.OpenAsync(cancellationToken);

        var payload = JsonSerializer.Serialize(
            linhas.Select(l => new
            {
                @ref = l.Ref,
                cor = l.Cor ?? string.Empty,
                quantidadePrevista = l.QuantidadePrevista
            }));

        try
        {
            await using var multi = await connection.QueryMultipleAsync(
                new CommandDefinition(
                    "dbo.sp_HCA_prev_entrada_guardar",
                    new
                    {
                        id,
                        usrlogin = usrLogin ?? string.Empty,
                        linhas = payload,
                        dataInicio = dataInicio.ToDateTime(TimeOnly.MinValue),
                        dataFim = dataFim.ToDateTime(TimeOnly.MinValue)
                    },
                    commandType: CommandType.StoredProcedure,
                    cancellationToken: cancellationToken));

            var cab = await multi.ReadSingleOrDefaultAsync<CabDb>();
            if (cab is null)
                throw new PortalBusinessException("Previsão não encontrada.", 404);

            var linhasDb = (await multi.ReadAsync<LinhaDb>()).ToList();
            return MapDetalhe(cab, linhasDb);
        }
        catch (SqlException ex) when (IsConflict(ex))
        {
            throw new PortalBusinessException(ex.Message, 409);
        }
        catch (SqlException ex) when (ex.Number >= 50000)
        {
            var status = ex.Message.Contains("não encontrada", StringComparison.OrdinalIgnoreCase)
                ? 404
                : ex.Message.Contains("fechada", StringComparison.OrdinalIgnoreCase)
                    ? 409
                    : 400;
            throw new PortalBusinessException(ex.Message, status);
        }
    }

    public async Task<IReadOnlyList<PrevisaoArtigoSugestaoRow>> SugerirArtigosAsync(
        string termo,
        int limit = 20,
        CancellationToken cancellationToken = default)
    {
        await using var connection = new SqlConnection(_options.ConnectionString);
        await connection.OpenAsync(cancellationToken);

        var rows = await connection.QueryAsync<SugestaoDb>(
            new CommandDefinition(
                "dbo.sp_HCA_prev_entrada_sugerir_artigos",
                new { q = termo, limit = Math.Clamp(limit, 1, 50) },
                commandType: CommandType.StoredProcedure,
                cancellationToken: cancellationToken));

        return rows
            .Where(r => !string.IsNullOrWhiteSpace(r.Ref))
            .Select(r => new PrevisaoArtigoSugestaoRow(
                r.Ref!.Trim(),
                (r.Design ?? string.Empty).Trim()))
            .ToList();
    }

    public async Task<IReadOnlyList<PrevisaoCorSugestaoRow>> SugerirCoresAsync(
        string artigoRef,
        string? termo = null,
        int limit = 30,
        CancellationToken cancellationToken = default)
    {
        await using var connection = new SqlConnection(_options.ConnectionString);
        await connection.OpenAsync(cancellationToken);

        var rows = await connection.QueryAsync<CorSugestaoDb>(
            new CommandDefinition(
                "dbo.sp_HCA_prev_entrada_sugerir_cores",
                new
                {
                    @ref = artigoRef,
                    q = string.IsNullOrWhiteSpace(termo) ? null : termo,
                    limit = Math.Clamp(limit, 1, 100)
                },
                commandType: CommandType.StoredProcedure,
                cancellationToken: cancellationToken));

        return rows
            .Select(r => new PrevisaoCorSugestaoRow(r.Cor ?? string.Empty))
            .ToList();
    }

    public async Task<PrevisaoEntradaDetalheRow> FecharAsync(
        Guid id,
        string usrLogin,
        CancellationToken cancellationToken = default)
    {
        await using var connection = new SqlConnection(_options.ConnectionString);
        await connection.OpenAsync(cancellationToken);

        try
        {
            await using var multi = await connection.QueryMultipleAsync(
                new CommandDefinition(
                    "dbo.sp_HCA_prev_entrada_fechar",
                    new { id, usrlogin = usrLogin ?? string.Empty },
                    commandType: CommandType.StoredProcedure,
                    cancellationToken: cancellationToken));

            var cab = await multi.ReadSingleOrDefaultAsync<CabDb>();
            if (cab is null)
                throw new PortalBusinessException("Previsão não encontrada.", 404);

            var linhasDb = (await multi.ReadAsync<LinhaDb>()).ToList();
            return MapDetalhe(cab, linhasDb);
        }
        catch (SqlException ex) when (IsConflict(ex))
        {
            throw new PortalBusinessException(ex.Message, 409);
        }
        catch (SqlException ex) when (ex.Number >= 50000)
        {
            var status = ex.Message.Contains("não encontrada", StringComparison.OrdinalIgnoreCase)
                ? 404
                : ex.Message.Contains("fechada", StringComparison.OrdinalIgnoreCase)
                    ? 409
                    : 400;
            throw new PortalBusinessException(ex.Message, status);
        }
    }

    public async Task<(PrevisaoEntradaDetalheRow Detalhe, int LinhasAdicionadas)> AtualizarLinhasAsync(
        Guid id,
        string usrLogin,
        CancellationToken cancellationToken = default)
    {
        await using var connection = new SqlConnection(_options.ConnectionString);
        await connection.OpenAsync(cancellationToken);

        try
        {
            await using var multi = await connection.QueryMultipleAsync(
                new CommandDefinition(
                    "dbo.sp_HCA_prev_entrada_atualizar_linhas",
                    new { id, usrlogin = usrLogin ?? string.Empty },
                    commandType: CommandType.StoredProcedure,
                    cancellationToken: cancellationToken));

            var meta = await multi.ReadSingleOrDefaultAsync<AtualizarMetaDb>();
            var cab = await multi.ReadSingleOrDefaultAsync<CabDb>();
            if (cab is null)
                throw new PortalBusinessException("Previsão não encontrada.", 404);

            var linhasDb = (await multi.ReadAsync<LinhaDb>()).ToList();
            return (MapDetalhe(cab, linhasDb), meta?.LinhasAdicionadas ?? 0);
        }
        catch (SqlException ex) when (IsConflict(ex))
        {
            throw new PortalBusinessException(ex.Message, 409);
        }
        catch (SqlException ex) when (ex.Number >= 50000)
        {
            var status = ex.Message.Contains("não encontrada", StringComparison.OrdinalIgnoreCase)
                ? 404
                : ex.Message.Contains("fechada", StringComparison.OrdinalIgnoreCase)
                    ? 409
                    : 400;
            throw new PortalBusinessException(ex.Message, status);
        }
    }

    private static PrevisaoEntradaDetalheRow MapDetalhe(CabDb cab, IReadOnlyList<LinhaDb> linhas) =>
        new(
            cab.Id,
            cab.DataInicio,
            cab.DataFim,
            cab.Fechada,
            cab.FechadaEm,
            cab.FechadaPor,
            linhas.Select(l => new PrevisaoEntradaLinhaRow(
                l.Id,
                l.PrevisaoId,
                (l.Ref ?? string.Empty).Trim(),
                l.Cor ?? string.Empty,
                (l.Design ?? string.Empty).Trim(),
                l.QuantidadePrevista,
                l.QuantidadeAlocada,
                l.QuantidadeDisponivel)).ToList());

    private static bool IsConflict(SqlException ex) =>
        ex.Number == 2627 || ex.Number == 2601
        || (ex.Number >= 50000 && (
            ex.Message.Contains("sobreposto", StringComparison.OrdinalIgnoreCase)
            || ex.Message.Contains("previsão aberta", StringComparison.OrdinalIgnoreCase)
            || ex.Message.Contains("fechada", StringComparison.OrdinalIgnoreCase)));

    private sealed class ListaDb
    {
        public Guid Id { get; init; }
        public DateTime DataInicio { get; init; }
        public DateTime DataFim { get; init; }
        public bool Fechada { get; init; }
        public DateTime? FechadaEm { get; init; }
        public string? FechadaPor { get; init; }
        public int TotalLinhas { get; init; }
        public decimal QuantidadeTotal { get; init; }
    }

    private sealed class CabDb
    {
        public Guid Id { get; init; }
        public DateTime DataInicio { get; init; }
        public DateTime DataFim { get; init; }
        public bool Fechada { get; init; }
        public DateTime? FechadaEm { get; init; }
        public string? FechadaPor { get; init; }
    }

    private sealed class LinhaDb
    {
        public Guid Id { get; init; }
        public Guid PrevisaoId { get; init; }
        public string? Ref { get; init; }
        public string? Cor { get; init; }
        public string? Design { get; init; }
        public decimal QuantidadePrevista { get; init; }
        public decimal QuantidadeAlocada { get; init; }
        public decimal QuantidadeDisponivel { get; init; }
    }

    private sealed class CriarDb
    {
        public Guid Id { get; init; }
        public DateTime DataInicio { get; init; }
        public DateTime DataFim { get; init; }
    }

    private sealed class SugestaoDb
    {
        public string? Ref { get; init; }
        public string? Design { get; init; }
    }

    private sealed class CorSugestaoDb
    {
        public string? Cor { get; init; }
    }

    private sealed class AtualizarMetaDb
    {
        public int LinhasAdicionadas { get; init; }
    }
}
