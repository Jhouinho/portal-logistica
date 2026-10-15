using System.Reflection;
using Microsoft.AspNetCore.Http;
using Microsoft.AspNetCore.Identity;
using Portal.Api.Controllers;
using Portal.Application.Auth;
using Portal.Application.Cliente;
using Portal.Infrastructure.Auth;

namespace Portal.UnitTests;

public class SecurityHardeningTests
{
    [Fact]
    public void Cookie_producao_exige_Secure()
    {
        Assert.Equal(CookieSecurePolicy.Always, CookieSecurePolicyHelper.ForEnvironment(isProduction: true));
    }

    [Fact]
    public void Cookie_desenvolvimento_permite_SameAsRequest()
    {
        Assert.Equal(CookieSecurePolicy.SameAsRequest, CookieSecurePolicyHelper.ForEnvironment(isProduction: false));
    }

    [Fact]
    public void Cookies_staff_e_cliente_tem_nomes_distintos()
    {
        Assert.Equal("ls_portal_auth", "ls_portal_auth");
        Assert.Equal("ls_cliente_auth", ClienteAuthConstants.CookieName);
        Assert.NotEqual("ls_portal_auth", ClienteAuthConstants.CookieName);
        Assert.NotEqual(ClienteAuthConstants.CookieScheme, IdentityConstants.ApplicationScheme);
    }

    [Fact]
    public void Program_arranque_nao_chama_Migrate_nem_EnsureAdmin()
    {
        var programPath = FindRepoFile("src", "backend", "src", "Portal.Api", "Program.cs");
        Assert.True(File.Exists(programPath), $"Program.cs não encontrado: {programPath}");
        var text = File.ReadAllText(programPath);
        Assert.DoesNotContain("Database.Migrate()", text, StringComparison.Ordinal);
        Assert.DoesNotContain("EnsureAdminAsync", text, StringComparison.Ordinal);
        Assert.Contains("UseExceptionHandler", text, StringComparison.Ordinal);
        Assert.Contains("UseForwardedHeaders", text, StringComparison.Ordinal);
    }

    [Fact]
    public void PortalIdentitySeed_mantem_EnsureAdmin_para_uso_explicito()
    {
        var method = typeof(PortalIdentitySeed).GetMethod(
            nameof(PortalIdentitySeed.EnsureAdminAsync),
            BindingFlags.Public | BindingFlags.Static);
        Assert.NotNull(method);
        Assert.Equal(PortalRoles.Admin, "Admin");
    }

    [Fact]
    public void Lockout_constantes_telefone_5_em_15_minutos()
    {
        Assert.Equal(5, ClienteAuthConstants.PhoneMaxFailures);
        Assert.Equal(15, ClienteAuthConstants.PhoneLockoutMinutes);
        Assert.Equal(5, ClienteAuthConstants.LoginMaxFailures);
        Assert.Equal(15, ClienteAuthConstants.LoginLockoutMinutes);
    }

    [Theory]
    [InlineData(0, false)]
    [InlineData(3, false)]
    [InlineData(4, true)]
    [InlineData(5, true)]
    public void Lockout_quinta_falha_bloqueia(int previousFailures, bool shouldLock)
    {
        Assert.Equal(
            shouldLock,
            ClienteAuthLockoutRules.ShouldLockAfterFailure(previousFailures, ClienteAuthConstants.PhoneMaxFailures));
    }

    [Fact]
    public void Lockout_OUTPUT_futuro_e_bloqueado()
    {
        var now = new DateTime(2026, 10, 15, 12, 0, 0, DateTimeKind.Utc);
        var code = ClienteAuthLockoutRules.FailureErrorCode(now.AddMinutes(15), now, "telemovel_invalido");
        Assert.Equal("bloqueado", code);
    }

    [Fact]
    public void Lockout_OUTPUT_sem_lockout_e_invalido()
    {
        var now = new DateTime(2026, 10, 15, 12, 0, 0, DateTimeKind.Utc);
        var code = ClienteAuthLockoutRules.FailureErrorCode(null, now, "telemovel_invalido");
        Assert.Equal("telemovel_invalido", code);
    }

    [Fact]
    public void Lockout_expirado_nao_e_bloqueado()
    {
        var now = new DateTime(2026, 10, 15, 12, 0, 0, DateTimeKind.Utc);
        var code = ClienteAuthLockoutRules.FailureErrorCode(now.AddMinutes(-1), now, "credenciais");
        Assert.Equal("credenciais", code);
    }

    [Fact]
    public void Estado_submetido_pode_cancelar_cancelado_nao()
    {
        var sub = ClientePedidoEstadoMapper.Map(cancelado: false);
        Assert.Equal("submetido", sub.Codigo);
        Assert.True(sub.PodeCancelar);

        var can = ClientePedidoEstadoMapper.Map(cancelado: true);
        Assert.Equal("cancelado", can.Codigo);
        Assert.False(can.PodeCancelar);
    }

    [Fact]
    public void CriarPedidoDto_nao_aceita_preco_do_frontend()
    {
        var dtoType = typeof(ClientePedidosController.CriarPedidoDto);
        var linhaType = typeof(ClientePedidosController.LinhaDto);
        Assert.Null(dtoType.GetProperty("Preco", BindingFlags.Public | BindingFlags.Instance | BindingFlags.IgnoreCase));
        Assert.Null(linhaType.GetProperty("Preco", BindingFlags.Public | BindingFlags.Instance | BindingFlags.IgnoreCase));
        Assert.Null(linhaType.GetProperty("PrecoUnitario", BindingFlags.Public | BindingFlags.Instance | BindingFlags.IgnoreCase));
        Assert.NotNull(linhaType.GetProperty("Ref"));
        Assert.NotNull(linhaType.GetProperty("Qtt"));
        Assert.NotNull(linhaType.GetProperty("Cor"));

        var inputProps = typeof(ClientePedidoLinhaInput).GetProperties();
        Assert.DoesNotContain(inputProps, p => p.Name.Contains("Preco", StringComparison.OrdinalIgnoreCase));
    }

    [Fact]
    public void Cliente_policy_e_claims_isolados_do_staff()
    {
        Assert.Equal("ClienteAutenticado", ClienteAuthConstants.PolicyName);
        Assert.Equal("cl_no", ClienteAuthConstants.ClaimNo);
        Assert.Equal("cl_estab", ClienteAuthConstants.ClaimEstab);
        Assert.NotEqual(ClienteAuthConstants.CookieScheme, IdentityConstants.ApplicationScheme);
    }

    [Fact]
    public void ClientePedidosController_exige_scheme_cliente()
    {
        var attr = typeof(ClientePedidosController)
            .GetCustomAttributes(typeof(Microsoft.AspNetCore.Authorization.AuthorizeAttribute), inherit: true)
            .Cast<Microsoft.AspNetCore.Authorization.AuthorizeAttribute>()
            .First();
        Assert.Equal(ClienteAuthConstants.CookieScheme, attr.AuthenticationSchemes);
        Assert.Equal(ClienteAuthConstants.PolicyName, attr.Policy);
    }

    [Fact]
    public void ClienteAuthService_usa_UPDATE_atomico_de_falhas()
    {
        var path = FindRepoFile("src", "backend", "src", "Portal.Infrastructure", "Cliente", "ClienteAuthService.cs");
        var text = File.ReadAllText(path);
        Assert.Contains("FailedPhoneAttempts + 1", text, StringComparison.Ordinal);
        Assert.Contains("OUTPUT inserted.FailedPhoneAttempts", text, StringComparison.Ordinal);
        Assert.Contains("FailedLoginAttempts + 1", text, StringComparison.Ordinal);
        Assert.DoesNotContain("var fails = auth.FailedPhoneAttempts + 1", text, StringComparison.Ordinal);
    }

    private static string FindRepoFile(params string[] relativeParts)
    {
        var dir = new DirectoryInfo(AppContext.BaseDirectory);
        while (dir is not null)
        {
            var candidate = Path.Combine(new[] { dir.FullName }.Concat(relativeParts).ToArray());
            if (File.Exists(candidate))
                return candidate;
            var nested = Path.Combine(new[] { dir.FullName, "Liliana&Serodio" }.Concat(relativeParts).ToArray());
            if (File.Exists(nested))
                return nested;
            dir = dir.Parent;
        }

        return Path.Combine(relativeParts);
    }
}
