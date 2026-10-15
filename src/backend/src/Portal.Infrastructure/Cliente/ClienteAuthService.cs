using System.Security.Cryptography;
using System.Text.Json;
using Dapper;
using Microsoft.AspNetCore.DataProtection;
using Microsoft.AspNetCore.Identity;
using Microsoft.Data.SqlClient;
using Microsoft.Extensions.Options;
using Portal.Application.Cliente;
using Portal.Infrastructure.Options;

namespace Portal.Infrastructure.Cliente;

public sealed class ClienteAuthService : IClienteAuthService
{
    private readonly PhcOptions _options;
    private readonly IPasswordHasher<ClientePasswordUser> _hasher;
    private readonly IDataProtector _protector;
    private static readonly ClientePasswordUser HasherUser = new();

    public ClienteAuthService(
        IOptions<PhcOptions> options,
        IPasswordHasher<ClientePasswordUser> hasher,
        IDataProtectionProvider dataProtection)
    {
        _options = options.Value;
        _hasher = hasher;
        _protector = dataProtection.CreateProtector("Portal.Cliente.Challenge.v1");
    }

    public async Task<(ClienteElegibilidade Status, ClienteFicha? Ficha)> ResolverPorNifAsync(
        string nif,
        CancellationToken cancellationToken)
    {
        nif = ClienteElegibilidadeRules.NormalizeNif(nif);
        if (ClienteElegibilidadeRules.IsConsumidorFinal(nif))
            return (ClienteElegibilidade.ConsumidorFinal, null);

        await using var conn = new SqlConnection(_options.ConnectionString);
        var rows = (await conn.QueryAsync<ClienteFicha>(new CommandDefinition(
            """
            SELECT
                CAST(cl.no AS decimal(18,0)) AS No,
                CAST(cl.estab AS decimal(18,0)) AS Estab,
                RTRIM(cl.nome) AS Nome,
                LTRIM(RTRIM(cl.ncont)) AS Ncont,
                NULLIF(LTRIM(RTRIM(cl.tlmvl)), '') AS Tlmvl,
                NULLIF(LTRIM(RTRIM(cl.telefone)), '') AS Telefone
            FROM dbo.cl cl WITH (NOLOCK)
            WHERE LTRIM(RTRIM(cl.ncont)) = @nif
              AND ISNULL(cl.inactivo, 0) = 0
            """,
            new { nif },
            cancellationToken: cancellationToken))).ToList();

        var status = ClienteElegibilidadeRules.Classify(nif, rows);
        return status == ClienteElegibilidade.Ok
            ? (status, rows[0])
            : (status, null);
    }

    public async Task<ClienteFicha?> GetFichaAsync(decimal no, decimal estab, CancellationToken cancellationToken)
    {
        await using var conn = new SqlConnection(_options.ConnectionString);
        return await conn.QuerySingleOrDefaultAsync<ClienteFicha>(new CommandDefinition(
            """
            SELECT
                CAST(cl.no AS decimal(18,0)) AS No,
                CAST(cl.estab AS decimal(18,0)) AS Estab,
                RTRIM(cl.nome) AS Nome,
                LTRIM(RTRIM(cl.ncont)) AS Ncont,
                NULLIF(LTRIM(RTRIM(cl.tlmvl)), '') AS Tlmvl,
                NULLIF(LTRIM(RTRIM(cl.telefone)), '') AS Telefone
            FROM dbo.cl cl WITH (NOLOCK)
            WHERE cl.no = @no AND cl.estab = @estab
              AND ISNULL(cl.inactivo, 0) = 0
            """,
            new { no, estab },
            cancellationToken: cancellationToken));
    }

    public async Task EnsureAuthRowAsync(decimal no, decimal estab, CancellationToken cancellationToken)
    {
        await using var conn = new SqlConnection(_options.ConnectionString);
        await conn.ExecuteAsync(new CommandDefinition(
            """
            IF NOT EXISTS (
                SELECT 1 FROM dbo.u_HcaClienteAuth WITH (UPDLOCK, HOLDLOCK)
                WHERE ClNo = @no AND ClEstab = @estab)
            BEGIN
                INSERT INTO dbo.u_HcaClienteAuth (ClNo, ClEstab, PasswordHash, UpdatedAt)
                VALUES (@no, @estab, NULL, SYSUTCDATETIME());
            END
            """,
            new { no, estab },
            cancellationToken: cancellationToken));
    }

    public async Task<ClienteAuthRow?> GetAuthAsync(decimal no, decimal estab, CancellationToken cancellationToken)
    {
        await using var conn = new SqlConnection(_options.ConnectionString);
        return await conn.QuerySingleOrDefaultAsync<ClienteAuthRow>(new CommandDefinition(
            """
            SELECT ClNo, ClEstab, PasswordHash, FailedPhoneAttempts, PhoneLockoutEnd,
                   FailedLoginAttempts, LoginLockoutEnd, PasswordSetAt
            FROM dbo.u_HcaClienteAuth WITH (NOLOCK)
            WHERE ClNo = @no AND ClEstab = @estab
            """,
            new { no, estab },
            cancellationToken: cancellationToken));
    }

    public async Task<(bool Ok, string? ErrorCode)> ValidarTelemovelAsync(
        decimal no,
        decimal estab,
        string telemovel,
        string? tlmvl,
        string? telefone,
        CancellationToken cancellationToken)
    {
        await EnsureAuthRowAsync(no, estab, cancellationToken);
        var auth = await GetAuthAsync(no, estab, cancellationToken);
        if (auth is null)
            return (false, "erro");

        var now = DateTime.UtcNow;
        if (auth.PhoneLockoutEnd is { } until && until > now)
            return (false, "bloqueado");

        if (!PhoneNormalizer.Matches(telemovel, tlmvl, telefone))
        {
            await using var conn = new SqlConnection(_options.ConnectionString);
            // Incremento atómico na BD — evita corrida RMW que ultrapassava o limite.
            var updated = await conn.QuerySingleOrDefaultAsync<LockoutUpdateRow>(new CommandDefinition(
                """
                UPDATE dbo.u_HcaClienteAuth
                SET
                    FailedPhoneAttempts = CASE
                        WHEN FailedPhoneAttempts + 1 >= @max THEN 0
                        ELSE FailedPhoneAttempts + 1 END,
                    PhoneLockoutEnd = CASE
                        WHEN FailedPhoneAttempts + 1 >= @max
                        THEN DATEADD(minute, @minutes, SYSUTCDATETIME())
                        ELSE PhoneLockoutEnd END,
                    UpdatedAt = SYSUTCDATETIME()
                OUTPUT inserted.FailedPhoneAttempts AS FailedAttempts, inserted.PhoneLockoutEnd AS LockoutEnd
                WHERE ClNo = @no AND ClEstab = @estab
                  AND (PhoneLockoutEnd IS NULL OR PhoneLockoutEnd <= SYSUTCDATETIME())
                """,
                new
                {
                    no,
                    estab,
                    max = ClienteAuthConstants.PhoneMaxFailures,
                    minutes = ClienteAuthConstants.PhoneLockoutMinutes
                },
                cancellationToken: cancellationToken));

            if (updated is null)
                return (false, "bloqueado");

            return (false, ClienteAuthLockoutRules.FailureErrorCode(
                updated.LockoutEnd, DateTime.UtcNow, "telemovel_invalido"));
        }

        await using (var conn = new SqlConnection(_options.ConnectionString))
        {
            await conn.ExecuteAsync(new CommandDefinition(
                """
                UPDATE dbo.u_HcaClienteAuth
                SET FailedPhoneAttempts = 0, PhoneLockoutEnd = NULL, UpdatedAt = SYSUTCDATETIME()
                WHERE ClNo = @no AND ClEstab = @estab
                """,
                new { no, estab },
                cancellationToken: cancellationToken));
        }

        return (true, null);
    }

    public async Task DefinirPasswordAsync(decimal no, decimal estab, string password, CancellationToken cancellationToken)
    {
        await EnsureAuthRowAsync(no, estab, cancellationToken);
        var hash = _hasher.HashPassword(HasherUser, password);
        await using var conn = new SqlConnection(_options.ConnectionString);
        await conn.ExecuteAsync(new CommandDefinition(
            """
            UPDATE dbo.u_HcaClienteAuth
            SET PasswordHash = @hash,
                PasswordSetAt = SYSUTCDATETIME(),
                FailedLoginAttempts = 0,
                LoginLockoutEnd = NULL,
                UpdatedAt = SYSUTCDATETIME()
            WHERE ClNo = @no AND ClEstab = @estab
            """,
            new { no, estab, hash },
            cancellationToken: cancellationToken));
    }

    public async Task<(bool Ok, string? ErrorCode, ClienteFicha? Ficha)> ValidarLoginAsync(
        string nif,
        string password,
        CancellationToken cancellationToken)
    {
        var (status, ficha) = await ResolverPorNifAsync(nif, cancellationToken);
        if (status == ClienteElegibilidade.ConsumidorFinal)
            return (false, "consumidor_final", null);
        if (status is ClienteElegibilidade.SemFicha or ClienteElegibilidade.VariasFichas)
            return (false, "balcao", null);
        if (ficha is null)
            return (false, "credenciais", null);

        await EnsureAuthRowAsync(ficha.No, ficha.Estab, cancellationToken);
        var auth = await GetAuthAsync(ficha.No, ficha.Estab, cancellationToken);
        if (auth is null || string.IsNullOrEmpty(auth.PasswordHash))
            return (false, "credenciais", null);

        var now = DateTime.UtcNow;
        if (auth.LoginLockoutEnd is { } until && until > now)
            return (false, "bloqueado", null);

        var verify = _hasher.VerifyHashedPassword(HasherUser, auth.PasswordHash, password);
        if (verify == PasswordVerificationResult.Failed)
        {
            await using var conn = new SqlConnection(_options.ConnectionString);
            var updated = await conn.QuerySingleOrDefaultAsync<LockoutUpdateRow>(new CommandDefinition(
                """
                UPDATE dbo.u_HcaClienteAuth
                SET
                    FailedLoginAttempts = CASE
                        WHEN FailedLoginAttempts + 1 >= @max THEN 0
                        ELSE FailedLoginAttempts + 1 END,
                    LoginLockoutEnd = CASE
                        WHEN FailedLoginAttempts + 1 >= @max
                        THEN DATEADD(minute, @minutes, SYSUTCDATETIME())
                        ELSE LoginLockoutEnd END,
                    UpdatedAt = SYSUTCDATETIME()
                OUTPUT inserted.FailedLoginAttempts AS FailedAttempts, inserted.LoginLockoutEnd AS LockoutEnd
                WHERE ClNo = @no AND ClEstab = @estab
                  AND (LoginLockoutEnd IS NULL OR LoginLockoutEnd <= SYSUTCDATETIME())
                """,
                new
                {
                    no = ficha.No,
                    estab = ficha.Estab,
                    max = ClienteAuthConstants.LoginMaxFailures,
                    minutes = ClienteAuthConstants.LoginLockoutMinutes
                },
                cancellationToken: cancellationToken));

            if (updated is null)
                return (false, "bloqueado", null);

            return (false, ClienteAuthLockoutRules.FailureErrorCode(
                updated.LockoutEnd, DateTime.UtcNow, "credenciais"), null);
        }

        await using (var conn = new SqlConnection(_options.ConnectionString))
        {
            await conn.ExecuteAsync(new CommandDefinition(
                """
                UPDATE dbo.u_HcaClienteAuth
                SET FailedLoginAttempts = 0, LoginLockoutEnd = NULL, UpdatedAt = SYSUTCDATETIME()
                WHERE ClNo = @no AND ClEstab = @estab
                """,
                new { no = ficha.No, estab = ficha.Estab },
                cancellationToken: cancellationToken));
        }

        return (true, null, ficha);
    }

    public string CreateChallengeToken(decimal no, decimal estab, string purpose, TimeSpan lifetime)
    {
        var payload = JsonSerializer.Serialize(new ChallengePayload(
            no, estab, purpose, DateTimeOffset.UtcNow.Add(lifetime).ToUnixTimeSeconds()));
        return _protector.Protect(payload);
    }

    public bool TryReadChallengeToken(string token, string expectedPurpose, out decimal no, out decimal estab)
    {
        no = 0;
        estab = 0;
        try
        {
            var json = _protector.Unprotect(token);
            var p = JsonSerializer.Deserialize<ChallengePayload>(json);
            if (p is null)
                return false;
            if (!string.Equals(p.Purpose, expectedPurpose, StringComparison.Ordinal))
                return false;
            if (DateTimeOffset.UtcNow.ToUnixTimeSeconds() > p.Exp)
                return false;
            no = p.No;
            estab = p.Estab;
            return true;
        }
        catch (CryptographicException)
        {
            return false;
        }
        catch (FormatException)
        {
            return false;
        }
    }

    private sealed record ChallengePayload(decimal No, decimal Estab, string Purpose, long Exp);

    private sealed class LockoutUpdateRow
    {
        public int FailedAttempts { get; init; }
        public DateTime? LockoutEnd { get; init; }
    }
}
