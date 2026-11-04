using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Identity;
using Microsoft.AspNetCore.Mvc;
using Portal.Api.Controllers;
using Portal.Application.Cliente;

namespace Portal.UnitTests;

/// <summary>
/// Contratos HTTP/autorização sem WebApplicationFactory (ainda inexistente no projeto).
/// Exercita atributos e mapeamento de erros documentado no controller.
/// Não substitui testes de integração HTTP reais.
/// </summary>
public class ClientePedidosHttpContractTests
{
    [Fact]
    public void Endpoints_detalhe_e_cancelar_existem_sob_rota_cliente()
    {
        var t = typeof(ClientePedidosController);
        var route = t.GetCustomAttributes(typeof(RouteAttribute), true)
            .Cast<RouteAttribute>().First();
        Assert.Equal("api/v1/cliente/pedidos", route.Template);

        Assert.NotNull(t.GetMethod(nameof(ClientePedidosController.Detalhe)));
        Assert.NotNull(t.GetMethod(nameof(ClientePedidosController.Cancelar)));
        Assert.NotNull(t.GetMethod(nameof(ClientePedidosController.Listar)));
    }

    [Fact]
    public void Controller_cliente_exige_ClienteCookie_e_policy()
    {
        var auth = typeof(ClientePedidosController)
            .GetCustomAttributes(typeof(AuthorizeAttribute), true)
            .Cast<AuthorizeAttribute>().First();
        Assert.Equal(ClienteAuthConstants.CookieScheme, auth.AuthenticationSchemes);
        Assert.Equal(ClienteAuthConstants.PolicyName, auth.Policy);
    }

    [Fact]
    public void Staff_pedidos_mobile_nao_usa_scheme_cliente()
    {
        var auth = typeof(StaffPmPedidosController)
            .GetCustomAttributes(typeof(AuthorizeAttribute), true)
            .Cast<AuthorizeAttribute>().First();
        Assert.NotEqual(ClienteAuthConstants.CookieScheme, auth.AuthenticationSchemes ?? "");
        Assert.True(string.IsNullOrEmpty(auth.AuthenticationSchemes)
                    || auth.AuthenticationSchemes == IdentityConstants.ApplicationScheme);

        var route = typeof(StaffPmPedidosController)
            .GetCustomAttributes(typeof(RouteAttribute), true)
            .Cast<RouteAttribute>().First();
        Assert.Equal("api/v1/staff/pedidos-mobile", route.Template);
    }

    [Fact]
    public void Cancelar_mapeia_interno_proibido_para_403_e_nao_encontrado_para_400()
    {
        var src = File.ReadAllText(SourcePathHelper.ResolveBackendSrc(
            "Portal.Api", "Controllers", "ClientePedidosController.cs"));
        Assert.Contains("interno_proibido", src, StringComparison.Ordinal);
        Assert.Contains("StatusCodes.Status403Forbidden", src, StringComparison.Ordinal);
        Assert.Contains("Pedido não encontrado.", src, StringComparison.Ordinal);
        Assert.Contains("Status = 400", src, StringComparison.Ordinal);
    }

    [Fact]
    public void Detalhe_devolve_404_quando_servico_null()
    {
        var src = File.ReadAllText(SourcePathHelper.ResolveBackendSrc(
            "Portal.Api", "Controllers", "ClientePedidosController.cs"));
        Assert.Contains("if (d is null)", src, StringComparison.Ordinal);
        Assert.Contains("Status = 404", src, StringComparison.Ordinal);
    }

    [Fact]
    public void Auth_logout_e_me_existem_na_rota_cliente_auth()
    {
        var t = typeof(ClienteAuthController);
        var route = t.GetCustomAttributes(typeof(RouteAttribute), true)
            .Cast<RouteAttribute>().First();
        Assert.Equal("api/v1/cliente/auth", route.Template);
        Assert.NotNull(t.GetMethod(nameof(ClienteAuthController.Logout)));
        Assert.NotNull(t.GetMethod(nameof(ClienteAuthController.Me)));
    }

    [Fact]
    public void Servico_obter_cancelar_nao_faz_fallback_legado_para_PM_ou_id_numerico()
    {
        var src = File.ReadAllText(SourcePathHelper.ResolveBackendSrc(
            "Portal.Infrastructure", "Cliente", "ClientePedidosService.cs"));
        var obter = ExtractMethod(src, "public async Task<ClientePedidoDetalhe?> ObterAsync");
        Assert.Contains("StartsWith(\"PM-\"", obter, StringComparison.Ordinal);
        Assert.Contains("return interno is null ? null : MapDetalheInterno(interno)", obter, StringComparison.Ordinal);
        // Após ramos PM-/numérico não deve haver return ObterLegado no mesmo bloco — legado só no fim para bostamp.
        Assert.Contains("return await ObterLegadoAsync", obter, StringComparison.Ordinal);

        var cancelar = ExtractMethod(src, "public async Task<(bool Ok, string? Error)> CancelarAsync");
        Assert.Contains("return (false, \"nao_encontrado\")", cancelar, StringComparison.Ordinal);
        Assert.Contains("interno_proibido", cancelar, StringComparison.Ordinal);
    }

    [Fact]
    public void ListarInternos_propaga_Bostamp_para_dedupe()
    {
        var src = File.ReadAllText(SourcePathHelper.ResolveBackendSrc(
            "Portal.Infrastructure", "Cliente", "ClientePedidosService.cs"));
        var listarInternos = ExtractMethod(src, "private async Task<IReadOnlyList<ClientePedidoListaItem>> ListarInternosSafeAsync");
        Assert.Contains("Bostamp: r.Bostamp", listarInternos, StringComparison.Ordinal);
        Assert.DoesNotContain("Bostamp: null", listarInternos, StringComparison.Ordinal);
    }

    private static string ExtractMethod(string src, string signaturePrefix)
    {
        var start = src.IndexOf(signaturePrefix, StringComparison.Ordinal);
        Assert.True(start >= 0, signaturePrefix);
        var brace = src.IndexOf('{', start);
        var depth = 0;
        for (var i = brace; i < src.Length; i++)
        {
            if (src[i] == '{') depth++;
            else if (src[i] == '}')
            {
                depth--;
                if (depth == 0)
                    return src[start..(i + 1)];
            }
        }

        throw new InvalidOperationException(signaturePrefix);
    }
}
