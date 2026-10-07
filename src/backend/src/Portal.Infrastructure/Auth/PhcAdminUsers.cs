using Dapper;
using Microsoft.Data.SqlClient;
using Microsoft.Extensions.Options;
using Portal.Application.Auth;
using Portal.Infrastructure.Options;

namespace Portal.Infrastructure.Auth;

public sealed class PhcAdminUsers : IPhcAdminUsers
{
    private readonly PhcOptions _options;

    public PhcAdminUsers(IOptions<PhcOptions> options)
    {
        _options = options.Value;
    }

    public async Task<IReadOnlyList<PhcAdminUserRow>> ListarActivosAsync(
        CancellationToken cancellationToken = default)
    {
        await using var connection = new SqlConnection(_options.ConnectionString);
        await connection.OpenAsync(cancellationToken);

        const string sql = """
            EXEC dbo.sp_HCA_listar_utilizadores_admin;
            """;

        var rows = await connection.QueryAsync<Row>(
            new CommandDefinition(sql, cancellationToken: cancellationToken));

        return rows.Select(Map).ToList();
    }

    public async Task<PhcAdminUserRow?> ActualizarUsaPortAsync(
        string email,
        bool usaPort,
        CancellationToken cancellationToken = default)
    {
        await using var connection = new SqlConnection(_options.ConnectionString);
        await connection.OpenAsync(cancellationToken);

        const string sql = """
            EXEC dbo.sp_HCA_actualizar_usa_port @email, @usaPort;
            """;

        try
        {
            var row = await connection.QuerySingleOrDefaultAsync<Row>(
                new CommandDefinition(
                    sql,
                    new { email, usaPort },
                    cancellationToken: cancellationToken));

            return row is null ? null : Map(row);
        }
        catch (SqlException ex) when (ex.Number >= 50000)
        {
            return null;
        }
    }

    public async Task<PhcAdminUserRow?> FindByEmailAsync(
        string email,
        CancellationToken cancellationToken = default)
    {
        var all = await ListarActivosAsync(cancellationToken);
        return all.FirstOrDefault(u =>
            string.Equals(u.Email, email.Trim(), StringComparison.OrdinalIgnoreCase));
    }

    private static PhcAdminUserRow Map(Row row) => new()
    {
        Userstamp = row.userstamp?.Trim() ?? string.Empty,
        Login = row.login?.Trim() ?? string.Empty,
        Nome = row.nome?.Trim() ?? string.Empty,
        Usrinis = row.usrinis?.Trim() ?? string.Empty,
        Email = row.email?.Trim() ?? string.Empty,
        UsaPort = row.usa_port
    };

    private sealed class Row
    {
        public string? userstamp { get; init; }
        public string? login { get; init; }
        public string? nome { get; init; }
        public string? usrinis { get; init; }
        public string? email { get; init; }
        public bool usa_port { get; init; }
    }
}
