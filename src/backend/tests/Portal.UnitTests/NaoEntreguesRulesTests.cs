using Portal.Application.Encomendas;

namespace Portal.UnitTests;

public sealed class NaoEntreguesRulesTests
{
    [Theory]
    [InlineData(true, 1, true)]   // 66 fechado + pendente > 0 → aparece
    [InlineData(true, 0, false)]  // 66 fechado + pendente = 0 → não aparece
    [InlineData(false, 1, false)] // 66 aberto + pendente > 0 → não aparece
    [InlineData(false, 0, false)] // 66 aberto + pendente = 0 → não aparece
    [InlineData(true, 0.01, true)]
    [InlineData(true, -1, false)]
    public void DeveAparecerNaLista(bool fechada, double pendente, bool esperado) =>
        Assert.Equal(
            esperado,
            NaoEntreguesRules.DeveAparecerNaLista(fechada, (decimal)pendente));

    [Theory]
    [InlineData(5, 3, 2)]
    [InlineData(3, 3, 0)]
    [InlineData(2, 1, 1)]
    public void Pendente_por_linha_qtt_menos_qtt2(double qtt, double qtt2, double pendente) =>
        Assert.Equal(
            (decimal)pendente,
            NaoEntreguesRules.QuantidadePendente((decimal)qtt, (decimal)qtt2));

    [Fact]
    public void Detalhe_mostra_todas_as_linhas_incluindo_pendente_zero()
    {
        // Caso UAT: 1309, 1310, 5597 — a linha com pendente=0 permanece no detalhe.
        var linhas = new (decimal qtt, decimal qtt2)[]
        {
            (5, 3),
            (3, 3),
            (2, 1),
        };

        var detalhes = linhas
            .Select(l => (
                Documento: l.qtt,
                Expedida: l.qtt2,
                Pendente: NaoEntreguesRules.QuantidadePendente(l.qtt, l.qtt2)))
            .ToList();

        Assert.Equal(3, detalhes.Count);
        Assert.Equal(2m, detalhes[0].Pendente);
        Assert.Equal(0m, detalhes[1].Pendente);
        Assert.Equal(1m, detalhes[2].Pendente);
        Assert.Contains(detalhes, d => d.Pendente == 0m);

        var pendenteDossier = detalhes.Sum(d => d.Pendente);
        Assert.Equal(3m, pendenteDossier);
        Assert.True(NaoEntreguesRules.DeveAparecerNaLista(fechada: true, pendenteDossier));
        Assert.False(NaoEntreguesRules.DeveAparecerNaLista(fechada: false, pendenteDossier));
        Assert.False(NaoEntreguesRules.DeveAparecerNaLista(fechada: true, 0m));
    }
}
