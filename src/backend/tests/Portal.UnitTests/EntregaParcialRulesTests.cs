using Portal.Application.Encomendas;

namespace Portal.UnitTests;

public sealed class EntregaParcialRulesTests
{
    [Theory]
    [InlineData(5, 0, 5, false)] // nunca expedido
    [InlineData(5, 3, 2, true)] // parcial
    [InlineData(5, 5, 0, false)] // totalmente satisfeito
    [InlineData(0, 0, 0, false)]
    [InlineData(10, 0.01, 9.99, true)]
    public void IsEntregaParcial_from_agregados(
        double documento,
        double expedida,
        double pendente,
        bool esperado)
    {
        var doc = (decimal)documento;
        var exp = (decimal)expedida;
        var pend = EntregaParcialRules.QuantidadePendente(doc, exp);
        Assert.Equal((decimal)pendente, pend);
        Assert.Equal(esperado, EntregaParcialRules.IsEntregaParcial(exp, pend));
    }

    [Fact]
    public void Varias_linhas_algumas_totais_ainda_parcial_no_dossier()
    {
        // 1309: 5/3/2, 1310: 3/3/0, 5597: 2/1/1
        var documento = 5m + 3m + 2m;
        var expedida = 3m + 3m + 1m;
        var pendente = EntregaParcialRules.QuantidadePendente(documento, expedida);
        Assert.Equal(10m, documento);
        Assert.Equal(7m, expedida);
        Assert.Equal(3m, pendente);
        Assert.True(EntregaParcialRules.IsEntregaParcial(expedida, pendente));
    }

    [Theory]
    [InlineData(5, 0, false)]
    [InlineData(5, 3, true)]
    [InlineData(5, 5, false)]
    [InlineData(3, 3, false)] // linha totalmente satisfeita isolada
    public void IsEntregaParcialFromLinha(double qtt, double qtt2, bool esperado) =>
        Assert.Equal(esperado, EntregaParcialRules.IsEntregaParcialFromLinha((decimal)qtt, (decimal)qtt2));

    [Fact]
    public void Agregados_documento_expedida_pendente_equivalentes_a_somas_linhas()
    {
        var linhas = new (decimal qtt, decimal qtt2)[]
        {
            (5, 3),
            (3, 3),
            (2, 1),
        };
        var quantidadeDocumento = linhas.Sum(l => l.qtt);
        var quantidadeExpedida = linhas.Sum(l => l.qtt2);
        var quantidadePendenteEntrega = linhas.Sum(l => l.qtt - l.qtt2);
        Assert.Equal(quantidadeDocumento - quantidadeExpedida, quantidadePendenteEntrega);
        Assert.Equal(
            quantidadePendenteEntrega,
            EntregaParcialRules.QuantidadePendente(quantidadeDocumento, quantidadeExpedida));
    }
}
