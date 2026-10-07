using Portal.Application.Painel;

namespace Portal.UnitTests;

public sealed class DistribuicaoLogicaCalculatorTests
{
    private static void AssertContrib(
        DistribuicaoLogicaCalculator.Contribuicao c,
        decimal aberto = 0,
        decimal picking = 0,
        decimal separado = 0,
        decimal entrega = 0,
        decimal expedicao = 0,
        decimal nao = 0)
    {
        Assert.Equal(aberto, c.EmAberto);
        Assert.Equal(picking, c.EmPicking);
        Assert.Equal(separado, c.Separado);
        Assert.Equal(entrega, c.EmEntrega);
        Assert.Equal(expedicao, c.EmExpedicao);
        Assert.Equal(nao, c.NaoClassificada);
        Assert.Equal(1m, c.Total);
    }

    [Fact]
    public void Sem_66_nem_65_EmAberto()
    {
        var c = DistribuicaoLogicaCalculator.Contribuir(0, 0, false, prontaPicking: false);
        AssertContrib(c, aberto: 1m);
    }

    [Fact]
    public void Sem_66_nem_65_EmPicking()
    {
        var c = DistribuicaoLogicaCalculator.Contribuir(0, 0, false, prontaPicking: true);
        AssertContrib(c, picking: 1m);
    }

    [Fact]
    public void Um_66_Separado_vale_1()
    {
        // pickrdy sem residual → só momento 66
        var c = DistribuicaoLogicaCalculator.Contribuir(1, 0, false, prontaPicking: true);
        AssertContrib(c, separado: 1m);
    }

    [Fact]
    public void Um_66_com_ainda_em_picking_reparte_50_50()
    {
        // Enc. em ndos=1 (residual) + ndos=66 → dois momentos
        var c = DistribuicaoLogicaCalculator.Contribuir(
            1, 0, false, prontaPicking: true, aindaEmPicking: true);
        AssertContrib(c, picking: 0.5m, separado: 0.5m);
    }

    [Fact]
    public void Picking_mais_66_mais_65_reparte_em_tercos()
    {
        var c = DistribuicaoLogicaCalculator.Contribuir(
            1, 0, true, prontaPicking: true, aindaEmPicking: true);
        Assert.Equal(1m / 3m, c.EmPicking);
        Assert.Equal(1m / 3m, c.Separado);
        Assert.Equal(1m - c.EmPicking - c.Separado, c.EmExpedicao);
        Assert.Equal(1m, c.Total);
    }

    [Fact]
    public void So_65_com_ainda_em_picking_reparte_50_50()
    {
        var c = DistribuicaoLogicaCalculator.Contribuir(
            0, 0, true, prontaPicking: true, aindaEmPicking: true);
        AssertContrib(c, picking: 0.5m, expedicao: 0.5m);
    }

    [Fact]
    public void Dois_66_Separado_repartem_50_50()
    {
        var c = DistribuicaoLogicaCalculator.Contribuir(2, 0, false, null);
        AssertContrib(c, separado: 0.5m + 0.5m); // 1.0 no estado Separado
        Assert.Equal(1m, c.Separado);
    }

    [Fact]
    public void Tres_66_Separado_cada_um_terco_no_estado()
    {
        var c = DistribuicaoLogicaCalculator.Contribuir(3, 0, false, null);
        Assert.Equal(1m, c.Separado);
        Assert.Equal(1m, c.Total);
    }

    [Fact]
    public void So_65_vale_1_EmExpedicao()
    {
        var c = DistribuicaoLogicaCalculator.Contribuir(0, 0, true, prontaPicking: true);
        AssertContrib(c, expedicao: 1m);
    }

    [Fact]
    public void Um_66_mais_65_reparte_50_50()
    {
        var c = DistribuicaoLogicaCalculator.Contribuir(1, 0, true, true);
        AssertContrib(c, separado: 0.5m, expedicao: 0.5m);
    }

    [Fact]
    public void Dois_66_mais_65_25_25_50()
    {
        var c = DistribuicaoLogicaCalculator.Contribuir(2, 0, true, true);
        AssertContrib(c, separado: 0.5m, expedicao: 0.5m); // 0.25+0.25 no Separado
        Assert.Equal(0.5m, c.Separado);
        Assert.Equal(0.5m, c.EmExpedicao);
    }

    [Fact]
    public void Tres_66_mais_65_cada_66_um_sexto()
    {
        var c = DistribuicaoLogicaCalculator.Contribuir(3, 0, true, false);
        Assert.Equal(0.5m, c.Separado); // 3 * (0.5/3)
        Assert.Equal(0.5m, c.EmExpedicao);
        Assert.Equal(1m, c.Total);
    }

    [Fact]
    public void Sessenta_seis_fechado_nao_participa_so_65()
    {
        // n66=0 (fechado fora do facto) + 65 → 100% Em Expedição
        var c = DistribuicaoLogicaCalculator.Contribuir(0, 0, true, false);
        AssertContrib(c, expedicao: 1m);
    }

    [Fact]
    public void Sessenta_seis_sem_pendente_nao_conta_como_activo()
    {
        // n66=0 apesar de 66 aberto sem pendente; +65 → Em Expedição
        var c = DistribuicaoLogicaCalculator.Contribuir(0, 0, true, true);
        AssertContrib(c, expedicao: 1m);
    }

    [Fact]
    public void Checkin_mais_65_parcela_EmEntrega()
    {
        var c = DistribuicaoLogicaCalculator.Contribuir(0, 1, true, true);
        AssertContrib(c, entrega: 0.5m, expedicao: 0.5m);
    }

    [Fact]
    public void Mix_Separado_e_EmEntrega_com_65()
    {
        // 66#1 Separado + 66#2 Em Entrega + 65 → 0.25 + 0.25 + 0.50
        var c = DistribuicaoLogicaCalculator.Contribuir(1, 1, true, true);
        Assert.Equal(0.25m, c.Separado);
        Assert.Equal(0.25m, c.EmEntrega);
        Assert.Equal(0.5m, c.EmExpedicao);
        Assert.Equal(1m, c.Total);
    }

    [Fact]
    public void Duas_encomendas_independentes_somam_2()
    {
        var dto = DistribuicaoLogicaCalculator.FromContribuicoes(
        [
            DistribuicaoLogicaCalculator.Contribuir(1, 0, true, true),   // 0.5 sep + 0.5 exp
            DistribuicaoLogicaCalculator.Contribuir(0, 0, false, true), // 1 picking
        ]);
        Assert.Equal(2, dto.TotalEncomendasLogicas);
        Assert.Equal(0.5m, dto.Separado.Quantidade);
        Assert.Equal(0.5m, dto.EmExpedicao.Quantidade);
        Assert.Equal(1m, dto.EmPicking.Quantidade);
        var soma = dto.EmAberto.Quantidade + dto.EmPicking.Quantidade + dto.Separado.Quantidade
            + dto.EmEntrega.Quantidade + dto.EmExpedicao.Quantidade + dto.NaoClassificadas;
        Assert.Equal(2m, soma);
    }

    [Fact]
    public void NaoClassificada_quando_fora_da_vista_sem_docs()
    {
        var c = DistribuicaoLogicaCalculator.Contribuir(0, 0, false, null);
        AssertContrib(c, nao: 1m);
    }

    [Fact]
    public void Percentagens_fraccionadas_sobre_total()
    {
        // 1 encomenda: 0.5 Separado + 0.5 Em Expedição → 50% / 50%
        var dto = DistribuicaoLogicaCalculator.FromContribuicoes(
        [
            DistribuicaoLogicaCalculator.Contribuir(1, 0, true, true),
        ]);
        Assert.Equal(1, dto.TotalEncomendasLogicas);
        Assert.Equal(0.5m, dto.Separado.Quantidade);
        Assert.Equal(50m, dto.Separado.Percentagem);
        Assert.Equal(0.5m, dto.EmExpedicao.Quantidade);
        Assert.Equal(50m, dto.EmExpedicao.Percentagem);
    }

    [Fact]
    public void NaoClassificadas_contam_no_total_mas_nao_nos_cinco()
    {
        var dto = DistribuicaoLogicaCalculator.FromContribuicoes(
        [
            DistribuicaoLogicaCalculator.Contribuir(0, 0, false, true),
            DistribuicaoLogicaCalculator.Contribuir(0, 0, false, null),
        ]);
        Assert.Equal(2, dto.TotalEncomendasLogicas);
        Assert.Equal(1m, dto.EmPicking.Quantidade);
        Assert.Equal(50m, dto.EmPicking.Percentagem);
        Assert.Equal(1, dto.NaoClassificadas);
    }

    [Fact]
    public void Total_zero_percentagens_zero()
    {
        var dto = DistribuicaoLogicaCalculator.FromContagens(new DistribuicaoLogicaContagemRow());
        Assert.Equal(0, dto.TotalEncomendasLogicas);
        Assert.Equal(0m, dto.EmAberto.Percentagem);
    }

    [Fact]
    public void Soma_unidades_igual_total_encomendas_em_cenario_3x66_mais_65()
    {
        var c = DistribuicaoLogicaCalculator.Contribuir(3, 0, true, true);
        Assert.Equal(1m, c.Total);
        Assert.Equal(0.5m, c.Separado);
        Assert.Equal(0.5m, c.EmExpedicao);
    }
}
