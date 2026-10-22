using Portal.Api.Hosting;

namespace Portal.UnitTests;

public class PublicEdgePathMatcherTests
{
    private static readonly string[] PublicHosts = ["mobile.cliente.example"];

    [Fact]
    public void Disabled_permite_qualquer_path_e_host()
    {
        var r = PublicEdgePathMatcher.Evaluate(
            enabled: false,
            PublicHosts,
            "mobile.cliente.example",
            "GET",
            "/api/v1/encomendas/abertas");

        Assert.False(r.IsPublicHost);
        Assert.True(r.Allowed);
        Assert.Equal("disabled", r.Reason);
    }

    [Fact]
    public void Enabled_sem_hosts_validos_nega_tudo_fail_closed()
    {
        var r = PublicEdgePathMatcher.Evaluate(
            enabled: true,
            ["", "  ", "http://evil", "*"],
            "portal-interno",
            "GET",
            "/cliente/login");

        Assert.True(r.IsPublicHost);
        Assert.False(r.Allowed);
        Assert.Equal("enabled-without-hosts", r.Reason);
    }

    [Fact]
    public void TryValidateWhenEnabled_exige_hosts_quando_activo()
    {
        Assert.True(PublicEdgePathMatcher.TryValidateWhenEnabled(false, [], out var errOff));
        Assert.Null(errOff);

        Assert.False(PublicEdgePathMatcher.TryValidateWhenEnabled(true, [], out var errEmpty));
        Assert.Contains("PublicHosts", errEmpty, StringComparison.Ordinal);

        Assert.True(PublicEdgePathMatcher.TryValidateWhenEnabled(true, PublicHosts, out var errOk));
        Assert.Null(errOk);
    }

    [Theory]
    [InlineData("Mobile.Cliente.Example", true)]
    [InlineData("mobile.cliente.example.", true)]
    [InlineData("portal-interno", false)]
    [InlineData("", false)]
    public void Host_publico_e_normalizado(string requestHost, bool expectPublic)
    {
        var r = PublicEdgePathMatcher.Evaluate(true, PublicHosts, requestHost, "GET", "/cliente/login");
        Assert.Equal(expectPublic, r.IsPublicHost);
        Assert.True(r.Allowed); // login permitido no público; interno também allow
    }

    [Theory]
    [InlineData("mobile.cliente.example")]
    [InlineData(" mobile.cliente.example ")]
    [InlineData("Mobile.Cliente.Example:443")]
    public void NormalizePublicHosts_aceita_entradas_validas(string entry)
    {
        var hosts = PublicEdgePathMatcher.NormalizePublicHosts([entry]);
        Assert.Equal(["mobile.cliente.example"], hosts);
    }

    [Theory]
    [InlineData(null)]
    [InlineData("")]
    [InlineData("https://mobile.example")]
    [InlineData("mobile.example/path")]
    [InlineData("*")]
    [InlineData("localhost")]
    public void NormalizePublicHosts_rejeita_entradas_invalidas(string? entry)
    {
        Assert.Empty(PublicEdgePathMatcher.NormalizePublicHosts([entry]));
    }

    [Theory]
    [InlineData("GET", "/cliente")]
    [InlineData("HEAD", "/cliente/login")]
    [InlineData("GET", "/cliente/novo")]
    [InlineData("GET", "/cliente/pedidos/ABC")]
    [InlineData("GET", "/api/v1/cliente/auth/me")]
    [InlineData("POST", "/api/v1/cliente/auth/login")]
    [InlineData("POST", "/api/v1/cliente/auth/primeiro-acesso/iniciar")]
    [InlineData("POST", "/api/v1/cliente/pedidos")]
    [InlineData("POST", "/api/v1/cliente/pedidos/1/cancelar")]
    [InlineData("GET", "/api/v1/cliente/artigos/REF1")]
    [InlineData("GET", "/api/v1/cliente/artigos/REF1/imagem")]
    [InlineData("GET", "/assets/index-abc.js")]
    [InlineData("GET", "/favicon.png")]
    [InlineData("GET", "/favicon-32.png")]
    [InlineData("GET", "/apple-touch-icon.png")]
    [InlineData("GET", "/manifest.webmanifest")]
    [InlineData("GET", "/pwa-192.png")]
    [InlineData("GET", "/pwa-512.png")]
    public void PublicHost_permite_rotas_mobile_confirmadas(string method, string path)
    {
        var r = PublicEdgePathMatcher.Evaluate(true, PublicHosts, PublicHosts[0], method, path);
        Assert.True(r.IsPublicHost);
        Assert.True(r.Allowed, $"{method} {path} → {r.Reason}");
    }

    [Theory]
    [InlineData("GET", "/")]
    [InlineData("GET", "/login")]
    [InlineData("GET", "/tv")]
    [InlineData("GET", "/centro-tv")]
    [InlineData("GET", "/health")]
    [InlineData("GET", "/swagger")]
    [InlineData("GET", "/sw.js")]
    [InlineData("GET", "/uat.cer")]
    [InlineData("GET", "/hubs/tv")]
    [InlineData("GET", "/hubs/operacoes")]
    [InlineData("GET", "/api/v1/encomendas/abertas")]
    [InlineData("GET", "/api/v1/encomendas/x/picking-kapps")]
    [InlineData("GET", "/api/v1/picking-dossiers")]
    [InlineData("GET", "/api/v1/painel/centro-estados")]
    [InlineData("GET", "/api/v1/painel/tv-kapps-resumo")]
    [InlineData("POST", "/api/v1/auth/login")]
    [InlineData("GET", "/api/v1/staff/pedidos-mobile")]
    [InlineData("GET", "/api/v1/admin/utilizadores")]
    public void PublicHost_bloqueia_internos_e_anonymous_ops(string method, string path)
    {
        var r = PublicEdgePathMatcher.Evaluate(true, PublicHosts, PublicHosts[0], method, path);
        Assert.True(r.IsPublicHost);
        Assert.False(r.Allowed, $"{method} {path} deveria negar");
    }

    [Theory]
    [InlineData("/clienteevil")]
    [InlineData("/cliente-extra")]
    [InlineData("/api/v1/clienteevil")]
    [InlineData("/api/v1/clienteextra/auth/login")]
    [InlineData("/assetsx/x.js")]
    public void PublicHost_rejeita_prefixos_parecidos_por_segmento(string path)
    {
        var r = PublicEdgePathMatcher.Evaluate(true, PublicHosts, PublicHosts[0], "GET", path);
        Assert.False(r.Allowed);
    }

    [Theory]
    [InlineData("PUT", "/cliente/login")]
    [InlineData("DELETE", "/api/v1/cliente/pedidos/1")]
    [InlineData("PATCH", "/api/v1/cliente/artigos/x")]
    [InlineData("POST", "/cliente/login")]
    [InlineData("POST", "/assets/x.js")]
    [InlineData("TRACE", "/api/v1/cliente/auth/login")]
    public void PublicHost_rejeita_metodos_nao_permitidos_na_rota(string method, string path)
    {
        var r = PublicEdgePathMatcher.Evaluate(true, PublicHosts, PublicHosts[0], method, path);
        Assert.False(r.Allowed);
    }

    [Fact]
    public void Query_string_ignorada_na_decisao()
    {
        var allow = PublicEdgePathMatcher.Evaluate(
            true, PublicHosts, PublicHosts[0], "GET", "/cliente/login?next=/tv");
        Assert.True(allow.Allowed);

        var deny = PublicEdgePathMatcher.Evaluate(
            true, PublicHosts, PublicHosts[0], "GET", "/tv?redirect=/cliente");
        Assert.False(deny.Allowed);
    }

    [Theory]
    [InlineData("/cliente/login/")]
    [InlineData("/Cliente/Login")]
    public void Path_normaliza_case_e_trailing_slash(string path)
    {
        var r = PublicEdgePathMatcher.Evaluate(true, PublicHosts, PublicHosts[0], "GET", path);
        Assert.True(r.Allowed);
    }

    [Theory]
    [InlineData("/%63liente/login")] // %63 = 'c' → /cliente/login
    [InlineData("/cliente/%6clogin")] // login
    public void Path_codificado_valido_e_avaliado_apos_unescape(string path)
    {
        var r = PublicEdgePathMatcher.Evaluate(true, PublicHosts, PublicHosts[0], "GET", path);
        Assert.True(r.Allowed, r.Reason);
    }

    [Theory]
    [InlineData("/cliente/../login")]
    [InlineData("/cliente/./login")]
    [InlineData("/api/v1/cliente/../../encomendas/abertas")]
    public void Path_com_dot_segments_e_rejeitado(string path)
    {
        var r = PublicEdgePathMatcher.Evaluate(true, PublicHosts, PublicHosts[0], "GET", path);
        Assert.False(r.Allowed);
        Assert.Equal("dot-segment", r.Reason);
    }

    [Fact]
    public void Host_interno_nao_aplica_allowlist()
    {
        var r = PublicEdgePathMatcher.Evaluate(
            true, PublicHosts, "portal.lan", "GET", "/api/v1/encomendas/abertas");
        Assert.False(r.IsPublicHost);
        Assert.True(r.Allowed);
        Assert.Equal("internal-host", r.Reason);
    }

    [Theory]
    [InlineData("mobile.cliente.example:443")]
    [InlineData("Mobile.Cliente.Example:8443")]
    [InlineData("mobile.cliente.example.")]
    public void PublicHost_com_porta_ou_ponto_final_continua_publico_e_filtrado(string requestHost)
    {
        var allow = PublicEdgePathMatcher.Evaluate(
            true, PublicHosts, requestHost, "GET", "/cliente/login");
        Assert.True(allow.IsPublicHost);
        Assert.True(allow.Allowed);

        var denyOps = PublicEdgePathMatcher.Evaluate(
            true, PublicHosts, requestHost, "GET", "/api/v1/encomendas/abertas");
        Assert.True(denyOps.IsPublicHost);
        Assert.False(denyOps.Allowed);
    }

    [Theory]
    [InlineData("/cliente/login\\x")]
    [InlineData("/cliente%5clogin")]
    [InlineData("/cliente/%5c../encomendas")]
    public void Path_com_backslash_ou_percent5c_e_rejeitado(string path)
    {
        var r = PublicEdgePathMatcher.Evaluate(true, PublicHosts, PublicHosts[0], "GET", path);
        Assert.False(r.Allowed);
    }

    [Fact]
    public void Barras_repetidas_em_cliente_sao_colapsadas_e_permitidas()
    {
        var r = PublicEdgePathMatcher.Evaluate(
            true, PublicHosts, PublicHosts[0], "GET", "//cliente/login");
        Assert.True(r.Allowed);
    }

    [Theory]
    [InlineData("/clienteX")]
    [InlineData("/clienteevil")]
    public void Segmentos_vizinhos_de_cliente_sao_bloqueados(string path)
    {
        var r = PublicEdgePathMatcher.Evaluate(true, PublicHosts, PublicHosts[0], "GET", path);
        Assert.False(r.Allowed);
    }

    [Theory]
    [InlineData(null)]
    [InlineData("")]
    [InlineData("   ")]
    public void Metodo_vazio_ou_nulo_e_negado_no_host_publico(string? method)
    {
        var r = PublicEdgePathMatcher.Evaluate(
            true, PublicHosts, PublicHosts[0], method, "/cliente/login");
        Assert.True(r.IsPublicHost);
        Assert.False(r.Allowed);
        Assert.Equal("missing-method", r.Reason);
    }

    [Theory]
    [InlineData("/cliente%2f../login")]
    [InlineData("/api/v1/cliente%2f..%2fencomendas/abertas")]
    public void Path_codificado_que_introduz_dot_segments_e_rejeitado(string path)
    {
        var r = PublicEdgePathMatcher.Evaluate(true, PublicHosts, PublicHosts[0], "GET", path);
        Assert.False(r.Allowed);
        Assert.Equal("dot-segment", r.Reason);
    }

    [Theory]
    [InlineData("https://mobile.cliente.example")]
    [InlineData("mobile.cliente.example/evil")]
    [InlineData("mobile.cliente.example\\evil")]
    public void NormalizeRequestHost_rejeita_entradas_invalidas(string raw)
    {
        Assert.Equal(string.Empty, PublicEdgePathMatcher.NormalizeRequestHost(raw));
    }

    [Fact]
    public void Options_defaults_seguros()
    {
        var o = new PublicEdgeOptions();
        Assert.False(o.Enabled);
        Assert.Empty(o.PublicHosts);
        Assert.Equal(404, o.BlockedStatusCode);
        Assert.Equal("Portal:PublicEdge", PublicEdgeOptions.SectionName);
    }

    [Fact]
    public void Documentacao_Passo_B_arranque_invalido()
    {
        // Passo B deve chamar TryValidateWhenEnabled no startup e falhar se false.
        // O matcher, em paralelo, nega tudo quando Enabled sem hosts (fail-closed).
        Assert.False(PublicEdgePathMatcher.TryValidateWhenEnabled(true, null, out _));
        var evaluate = PublicEdgePathMatcher.Evaluate(true, null, "any", "GET", "/cliente");
        Assert.False(evaluate.Allowed);
    }
}
