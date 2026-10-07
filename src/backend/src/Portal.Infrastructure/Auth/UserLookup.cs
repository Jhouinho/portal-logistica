using Dapper;
using Microsoft.Data.SqlClient;
using Microsoft.Extensions.Options;
using Portal.Application.Auth;
using Portal.Domain.Auth;
using Portal.Infrastructure.Options;

namespace Portal.Infrastructure.Auth;

public sealed class UserLookup : IUserLookup
{
    private readonly PhcOptions _options;

    public UserLookup(IOptions<PhcOptions> options)
    {
        _options = options.Value;
    }

    public async Task<PortalUser?> FindByLoginAsync(string login, CancellationToken cancellationToken = default)
    {
        await using var connection = new SqlConnection(_options.ConnectionString);
        await connection.OpenAsync(cancellationToken);

        const string sql = """
            EXEC dbo.sp_HCA_validar_login @login;
            """;

        var row = await connection.QuerySingleOrDefaultAsync<UserRow>(
            new CommandDefinition(sql, new { login }, cancellationToken: cancellationToken));

        if (row is null)
            return null;

        return Map(row);
    }

    public async Task<PortalUser?> FindByEmailAsync(string email, CancellationToken cancellationToken = default)
    {
        if (string.IsNullOrWhiteSpace(email))
            return null;

        await using var connection = new SqlConnection(_options.ConnectionString);
        await connection.OpenAsync(cancellationToken);

        const string sql = """
            SELECT TOP (1)
                us.usstamp AS userstamp,
                LTRIM(RTRIM(us.usercode)) AS login,
                LTRIM(RTRIM(us.username)) AS nome,
                LTRIM(RTRIM(us.iniciais)) AS usrinis,
                LTRIM(RTRIM(us.email)) AS email,
                us.u_portalph AS portal_hash
            FROM dbo.us us WITH (NOLOCK)
            WHERE LOWER(LTRIM(RTRIM(ISNULL(us.email, '')))) = LOWER(LTRIM(RTRIM(@email)))
              AND ISNULL(us.inactivo, 0) = 0
              AND us.u_usaPort = 1;
            """;

        var row = await connection.QuerySingleOrDefaultAsync<UserRow>(
            new CommandDefinition(sql, new { email = email.Trim() }, cancellationToken: cancellationToken));

        return row is null ? null : Map(row);
    }

    private static PortalUser Map(UserRow row) => new()
    {
        UserStamp = row.userstamp?.Trim() ?? string.Empty,
        Login = row.login?.Trim() ?? string.Empty,
        Nome = row.nome?.Trim() ?? string.Empty,
        Usrinis = row.usrinis?.Trim() ?? string.Empty,
        Email = row.email?.Trim() ?? string.Empty,
        PortalHash = row.portal_hash?.Trim() ?? string.Empty
    };

    private sealed class UserRow
    {
        public string? userstamp { get; init; }
        public string? login { get; init; }
        public string? nome { get; init; }
        public string? usrinis { get; init; }
        public string? email { get; init; }
        public string? portal_hash { get; init; }
    }
}
