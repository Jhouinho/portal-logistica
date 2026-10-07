using System.Data;
using Dapper;
using Microsoft.Data.SqlClient;
using Microsoft.Extensions.Options;
using Portal.Application.Encomendas;
using Portal.Infrastructure.Options;

namespace Portal.Infrastructure.Encomendas;

public sealed class PickingDossiersCommands : IPickingDossiersCommands
{
    private readonly PhcOptions _options;

    public PickingDossiersCommands(IOptions<PhcOptions> options)
    {
        _options = options.Value;
    }

    public async Task<FechoPickingAtualizadaDto> MarcarFechoAsync(
        string boStamp,
        bool fechada,
        int seriePickingNdos,
        string? usrLogin,
        CancellationToken cancellationToken = default)
    {
        await using var connection = new SqlConnection(_options.ConnectionString);
        await connection.OpenAsync(cancellationToken);

        try
        {
            var row = await connection.QuerySingleOrDefaultAsync<FechoRow>(
                new CommandDefinition(
                    "dbo.sp_HCA_marcar_fecho_picking_dossier",
                    new
                    {
                        bostamp = boStamp.Trim(),
                        fechada,
                        serie_picking = seriePickingNdos,
                        usrlogin = string.IsNullOrWhiteSpace(usrLogin) ? null : usrLogin.Trim()
                    },
                    commandType: CommandType.StoredProcedure,
                    cancellationToken: cancellationToken));

            if (row is null)
                throw new PortalBusinessException("Dossier não encontrado após actualização.", 404);

            return new FechoPickingAtualizadaDto(
                row.bostamp.Trim(),
                row.fechada,
                row.obrano,
                row.ndos);
        }
        catch (SqlException ex)
        {
            var msg = ex.Message ?? string.Empty;
            if (msg.Contains("não encontrado", StringComparison.OrdinalIgnoreCase) ||
                msg.Contains("série inválida", StringComparison.OrdinalIgnoreCase))
                throw new PortalBusinessException(msg, 404);

            throw new PortalBusinessException(msg, 400);
        }
    }

    public Task<FechoPickingAtualizadaDto> FecharExpedicaoAsync(
        string boStamp,
        int serieSeparacaoNdos,
        string? usrLogin,
        CancellationToken cancellationToken = default) =>
        ExecutarFechoExpedicaoSpAsync(
            "dbo.sp_HCA_fechar_expedicao_dossier",
            boStamp,
            serieSeparacaoNdos,
            usrLogin,
            cancellationToken);

    public Task<FechoPickingAtualizadaDto> ReabrirExpedicaoAsync(
        string boStamp,
        int serieSeparacaoNdos,
        string? usrLogin,
        CancellationToken cancellationToken = default) =>
        ExecutarFechoExpedicaoSpAsync(
            "dbo.sp_HCA_reabrir_expedicao_dossier",
            boStamp,
            serieSeparacaoNdos,
            usrLogin,
            cancellationToken);

    private async Task<FechoPickingAtualizadaDto> ExecutarFechoExpedicaoSpAsync(
        string procedureName,
        string boStamp,
        int serieSeparacaoNdos,
        string? usrLogin,
        CancellationToken cancellationToken)
    {
        await using var connection = new SqlConnection(_options.ConnectionString);
        await connection.OpenAsync(cancellationToken);

        try
        {
            var row = await connection.QuerySingleOrDefaultAsync<FechoRow>(
                new CommandDefinition(
                    procedureName,
                    new
                    {
                        bostamp = boStamp.Trim(),
                        serie_separacao = serieSeparacaoNdos,
                        usrlogin = string.IsNullOrWhiteSpace(usrLogin) ? null : usrLogin.Trim()
                    },
                    commandType: CommandType.StoredProcedure,
                    cancellationToken: cancellationToken));

            if (row is null)
                throw new PortalBusinessException("Dossier não encontrado após actualização.", 404);

            return new FechoPickingAtualizadaDto(
                row.bostamp.Trim(),
                row.fechada,
                row.obrano,
                row.ndos);
        }
        catch (SqlException ex)
        {
            var msg = ex.Message ?? string.Empty;
            if (msg.Contains("não encontrado", StringComparison.OrdinalIgnoreCase) ||
                msg.Contains("série inválida", StringComparison.OrdinalIgnoreCase))
                throw new PortalBusinessException(msg, 404);

            if (msg.Contains("já fechada", StringComparison.OrdinalIgnoreCase) ||
                msg.Contains("já aberta", StringComparison.OrdinalIgnoreCase))
                throw new PortalBusinessException(msg, 409);

            throw new PortalBusinessException(msg, 400);
        }
    }

    public async Task<CheckInAtualizadaDto> MarcarCheckInAsync(
        string boStamp,
        bool checkIn,
        int seriePickingNdos,
        string usrLogin,
        string? usrinis,
        CancellationToken cancellationToken = default)
    {
        await using var connection = new SqlConnection(_options.ConnectionString);
        await connection.OpenAsync(cancellationToken);

        try
        {
            var row = await connection.QuerySingleOrDefaultAsync<CheckInRow>(
                new CommandDefinition(
                    "dbo.sp_HCA_marcar_checkin_dossier",
                    new
                    {
                        bostamp = boStamp.Trim(),
                        checkin = checkIn,
                        serie_picking = seriePickingNdos,
                        usrlogin = usrLogin.Trim(),
                        usrinis = string.IsNullOrWhiteSpace(usrinis) ? null : usrinis.Trim()
                    },
                    commandType: CommandType.StoredProcedure,
                    cancellationToken: cancellationToken));

            if (row is null)
                throw new PortalBusinessException("Dossier não encontrado após Check-in.", 404);

            return new CheckInAtualizadaDto(
                row.bostamp.Trim(),
                row.check_in,
                string.IsNullOrWhiteSpace(row.check_in_por) ? null : row.check_in_por.Trim(),
                row.check_in_em,
                row.obrano,
                row.ndos);
        }
        catch (SqlException ex)
        {
            var msg = ex.Message ?? string.Empty;
            if (msg.Contains("não encontrado", StringComparison.OrdinalIgnoreCase) ||
                msg.Contains("série inválida", StringComparison.OrdinalIgnoreCase) ||
                msg.Contains("fora da série", StringComparison.OrdinalIgnoreCase))
                throw new PortalBusinessException(msg, 404);

            if (msg.Contains("já realizado", StringComparison.OrdinalIgnoreCase))
                throw new PortalBusinessException(msg, 409);

            throw new PortalBusinessException(msg, 400);
        }
    }

    public async Task<CheckInAtualizadaDto> ReverterCheckInAsync(
        string boStamp,
        int seriePickingNdos,
        string usrLogin,
        string? usrinis,
        CancellationToken cancellationToken = default)
    {
        await using var connection = new SqlConnection(_options.ConnectionString);
        await connection.OpenAsync(cancellationToken);

        try
        {
            var row = await connection.QuerySingleOrDefaultAsync<CheckInRow>(
                new CommandDefinition(
                    "dbo.sp_HCA_reverter_checkin_dossier",
                    new
                    {
                        bostamp = boStamp.Trim(),
                        serie_picking = seriePickingNdos,
                        usrlogin = usrLogin.Trim(),
                        usrinis = string.IsNullOrWhiteSpace(usrinis) ? null : usrinis.Trim()
                    },
                    commandType: CommandType.StoredProcedure,
                    cancellationToken: cancellationToken));

            if (row is null)
                throw new PortalBusinessException("Dossier não encontrado após reverter Check-in.", 404);

            return new CheckInAtualizadaDto(
                row.bostamp.Trim(),
                row.check_in,
                string.IsNullOrWhiteSpace(row.check_in_por) ? null : row.check_in_por.Trim(),
                row.check_in_em,
                row.obrano,
                row.ndos);
        }
        catch (SqlException ex)
        {
            var msg = ex.Message ?? string.Empty;
            if (msg.Contains("não encontrado", StringComparison.OrdinalIgnoreCase) ||
                msg.Contains("série inválida", StringComparison.OrdinalIgnoreCase) ||
                msg.Contains("fora da série", StringComparison.OrdinalIgnoreCase))
                throw new PortalBusinessException(msg, 404);

            if (msg.Contains("sem Check-in", StringComparison.OrdinalIgnoreCase))
                throw new PortalBusinessException(msg, 409);

            throw new PortalBusinessException(msg, 400);
        }
    }

    private sealed class FechoRow
    {
        public string bostamp { get; init; } = string.Empty;
        public bool fechada { get; init; }
        public int obrano { get; init; }
        public int ndos { get; init; }
    }

    private sealed class CheckInRow
    {
        public string bostamp { get; init; } = string.Empty;
        public bool check_in { get; init; }
        public string? check_in_por { get; init; }
        public DateTime? check_in_em { get; init; }
        public int obrano { get; init; }
        public int ndos { get; init; }
    }
}
