using Portal.Application.Cliente;

namespace Portal.UnitTests;

public class StaffPmPedidosRulesTests
{
    [Fact]
    public void IdempotencyKey_aprovacao_estavel_por_pedidoId()
    {
        Assert.Equal("HCA-PM-APROV-42", StaffPmPedidoRules.FormatAprovacaoIdempotencyKey(42));
        Assert.Equal(
            StaffPmPedidoRules.FormatAprovacaoIdempotencyKey(7),
            StaffPmPedidoRules.FormatAprovacaoIdempotencyKey(7));
    }

    [Theory]
    [InlineData("recebido", null, true)]
    [InlineData("em_analise", null, true)]
    [InlineData("recebido", "ABC", false)]
    [InlineData("integrado", null, false)]
    [InlineData("rejeitado", null, false)]
    public void IsPendente(string estado, string? bostamp, bool expected) =>
        Assert.Equal(expected, StaffPmPedidoRules.IsPendente(estado, bostamp));

    [Fact]
    public void Rejeitado_bloqueia_aprovacao()
    {
        Assert.True(StaffPmPedidoRules.IsBlockedFromApprove("rejeitado"));
        Assert.False(StaffPmPedidoRules.CanCreateBo67("rejeitado", null));
        Assert.False(StaffPmPedidoRules.CanReject("rejeitado", null));
    }

    [Fact]
    public void Dupla_aprovacao_idempotente_quando_ja_integrado()
    {
        Assert.True(StaffPmPedidoRules.IsIntegradoCompleto("integrado", "stamp123"));
        Assert.False(StaffPmPedidoRules.CanCreateBo67("integrado", "stamp123"));
        Assert.False(StaffPmPedidoRules.ShowApproveAction("integrado", "stamp123"));
    }

    [Theory]
    [InlineData("integrado", "S1")]
    [InlineData("em_separacao", "S1")]
    [InlineData("pronto_levantamento", "S1")]
    [InlineData("concluido", "S1")]
    public void Circuito_balcao_pos_BO_continua_integrado_completo(string estado, string bostamp)
    {
        // Regras CanMarcar* mantêm-se no domínio; a API staff força flags false (balcão).
        Assert.True(StaffPmPedidoRules.IsIntegradoCompleto(estado, bostamp));
    }

    [Fact]
    public void MapInterno_estados_pos_validacao_balcao()
    {
        Assert.Equal(("validado", "Validado", false), ClientePedidoEstadoMapper.MapInterno("em_separacao"));
        Assert.Equal(("validado", "Validado", false), ClientePedidoEstadoMapper.MapInterno("integrado"));
        Assert.Equal(("validado", "Validado", false), ClientePedidoEstadoMapper.MapInterno("pronto_levantamento"));
        Assert.Equal(("validado", "Validado", false), ClientePedidoEstadoMapper.MapInterno("concluido"));
    }

    [Fact]
    public void NeedsReconcile_quando_bostamp_sem_estado_integrado()
    {
        Assert.True(StaffPmPedidoRules.NeedsReconcile("recebido", "BO123"));
        Assert.True(StaffPmPedidoRules.ShowApproveAction("recebido", "BO123"));
        Assert.False(StaffPmPedidoRules.CanReject("recebido", "BO123"));
    }

    [Fact]
    public void MapInterno_rejeitado()
    {
        var m = ClientePedidoEstadoMapper.MapInterno("rejeitado");
        Assert.Equal("rejeitado", m.Codigo);
        Assert.Equal("Rejeitado", m.Etiqueta);
        Assert.False(m.PodeCancelar);
    }

    [Fact]
    public void PedidoMobileNdos_default_67_distinto_do_circuito_armazem()
    {
        var cliente = new Portal.Infrastructure.Options.PortalClienteOptions();
        Assert.Equal(67, cliente.PedidoMobileNdos);
        // Séries do armazém (1/66/65) não coincidem com o dossier Mobile.
        Assert.NotEqual(1, cliente.PedidoMobileNdos);
        Assert.NotEqual(66, cliente.PedidoMobileNdos);
        Assert.NotEqual(65, cliente.PedidoMobileNdos);
    }

    [Fact]
    public void CanEditPrecos_alinha_com_pendente()
    {
        Assert.Equal(
            StaffPmPedidoRules.IsPendente("recebido", null),
            StaffPmPrecoRules.CanEditPrecos("recebido", null));
        Assert.False(StaffPmPrecoRules.CanEditPrecos("rejeitado", null));
    }

    [Fact]
    public void Em_aprovacao_bloqueia_rejeicao_e_precos_permite_continuar_aprovacao()
    {
        Assert.False(StaffPmPedidoRules.CanReject("em_aprovacao", null));
        Assert.False(StaffPmPrecoRules.CanEditPrecos("em_aprovacao", null));
        Assert.True(StaffPmPedidoRules.CanContinueBo67("em_aprovacao", null));
        Assert.True(StaffPmPedidoRules.ShowApproveAction("em_aprovacao", null));
        Assert.True(StaffPmPedidoRules.NeedsReconcile("em_aprovacao", "BO1"));
    }
}
