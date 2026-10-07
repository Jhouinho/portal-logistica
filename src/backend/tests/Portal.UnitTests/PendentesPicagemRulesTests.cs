using Portal.Application.Encomendas;

namespace Portal.UnitTests;

public sealed class PendentesPicagemRulesTests
{
    [Fact]
    public void Nenhuma_linha_iniciou_encomenda_excluida()
    {
        // Todas Picked=0, SUM66=0 → encomenda não iniciou
        Assert.False(PendentesPicagemRules.EncomendaIniciouPicking(new[]
        {
            (0m, 0m),
            (0m, 0m),
        }));

        var r = PendentesPicagemRules.AvaliarLinha(10, 0, 0, 0, encomendaIniciou: false);
        Assert.False(r.Incluir);
    }

    [Fact]
    public void Abort_sem_66_encomenda_nao_iniciou()
    {
        Assert.False(PendentesPicagemRules.EncomendaIniciouPicking(new[] { (0m, 0m) }));
        var r = PendentesPicagemRules.AvaliarLinha(10, 0, 0, 0, encomendaIniciou: false);
        Assert.False(r.Incluir);
    }

    [Fact]
    public void Kapps_parcial_usa_quantity_pending()
    {
        Assert.True(PendentesPicagemRules.EncomendaIniciouPicking(new[] { (3m, 0m) }));
        var r = PendentesPicagemRules.AvaliarLinha(qtt: 10, qtt2: 0, sum66: 0, picked: 3, encomendaIniciou: true);
        Assert.True(r.Incluir);
        Assert.Equal(7m, r.Pending);
        Assert.Equal(PendentesPicagemFonte.Kapps, r.Fonte);
        Assert.Equal(7m, PendentesPicagemRules.QuantityPendingKapps(10, 0, 3));
    }

    [Fact]
    public void Integrado_parcial_usa_qtt_menos_sum66()
    {
        Assert.True(PendentesPicagemRules.EncomendaIniciouPicking(new[] { (0m, 3m) }));
        var r = PendentesPicagemRules.AvaliarLinha(qtt: 10, qtt2: 3, sum66: 3, picked: 0, encomendaIniciou: true);
        Assert.True(r.Incluir);
        Assert.Equal(7m, r.Pending);
        Assert.Equal(PendentesPicagemFonte.Sum66, r.Fonte);
    }

    [Fact]
    public void Irmas_sem_inicio_individual_aparecem_com_pending_qtt()
    {
        // Linha A iniciou (SUM66=3); B e C não — encomenda iniciou; B/C → Pending=qtt
        var linhas = new[] { (0m, 3m), (0m, 0m), (0m, 0m) };
        Assert.True(PendentesPicagemRules.EncomendaIniciouPicking(linhas));

        var a = PendentesPicagemRules.AvaliarLinha(7, 3, 3, 0, true);
        var b = PendentesPicagemRules.AvaliarLinha(3, 0, 0, 0, true);
        var c = PendentesPicagemRules.AvaliarLinha(2, 0, 0, 0, true);

        Assert.True(a.Incluir);
        Assert.Equal(4m, a.Pending);
        Assert.True(b.Incluir);
        Assert.Equal(3m, b.Pending);
        Assert.True(c.Incluir);
        Assert.Equal(2m, c.Pending);
        Assert.Equal(
            9m,
            PendentesPicagemRules.SomarPendentesEncomenda(new[] { a.Pending, b.Pending, c.Pending }));
    }

    [Fact]
    public void Hibrido_kapps_sum66_e_irma()
    {
        // A: Picked>0 → Kapps; B: SUM66>0 → qtt-SUM66; C: irmã → qtt
        var a = PendentesPicagemRules.AvaliarLinha(10, 3, 3, 2, true); // Kapps → 5
        var b = PendentesPicagemRules.AvaliarLinha(10, 3, 3, 0, true); // Sum66 → 7
        var c = PendentesPicagemRules.AvaliarLinha(5, 0, 0, 0, true);  // irmã → 5

        Assert.Equal(PendentesPicagemFonte.Kapps, a.Fonte);
        Assert.Equal(5m, a.Pending);
        Assert.Equal(PendentesPicagemFonte.Sum66, b.Fonte);
        Assert.Equal(7m, b.Pending);
        Assert.Equal(5m, c.Pending);
        Assert.NotEqual(12m, a.Pending); // nunca qtt-SUM66-Picked
    }

    [Fact]
    public void Sum66_mais_kapps_ativa_usa_apenas_kapps_pending()
    {
        var r = PendentesPicagemRules.AvaliarLinha(qtt: 10, qtt2: 3, sum66: 3, picked: 2, encomendaIniciou: true);
        Assert.True(r.Incluir);
        Assert.Equal(5m, r.Pending);
        Assert.Equal(PendentesPicagemFonte.Kapps, r.Fonte);
        Assert.NotEqual(7m, r.Pending);
        Assert.NotEqual(12m, r.Pending);
    }

    [Fact]
    public void Tudo_materializado_exclui_linhas_e_encomenda_sem_pending()
    {
        var r = PendentesPicagemRules.AvaliarLinha(qtt: 10, qtt2: 10, sum66: 10, picked: 0, encomendaIniciou: true);
        Assert.False(r.Incluir);
        Assert.Equal(0m, r.Pending);
        // Encomenda iniciou (SUM66>0) mas nenhuma linha com Pending>0 → não aparece
        Assert.True(PendentesPicagemRules.EncomendaIniciouPicking(new[] { (0m, 10m) }));
    }

    [Fact]
    public void Sum66_superior_a_qtt_exclui_sem_negativo()
    {
        var r = PendentesPicagemRules.AvaliarLinha(qtt: 10, qtt2: 12, sum66: 12, picked: 0, encomendaIniciou: true);
        Assert.False(r.Incluir);
        Assert.Equal(0m, r.Pending);
    }

    [Fact]
    public void Multiplos_66_agregados_num_sum66()
    {
        var r = PendentesPicagemRules.AvaliarLinha(qtt: 10, qtt2: 5, sum66: 5, picked: 0, encomendaIniciou: true);
        Assert.True(r.Incluir);
        Assert.Equal(5m, r.Pending);
        Assert.Equal(PendentesPicagemFonte.Sum66, r.Fonte);
    }

    [Fact]
    public void Multiplos_dossierlin_usam_picked_agregado()
    {
        const decimal pickedAgg = 2m + 1m;
        var r = PendentesPicagemRules.AvaliarLinha(qtt: 10, qtt2: 0, sum66: 0, picked: pickedAgg, encomendaIniciou: true);
        Assert.True(r.Incluir);
        Assert.Equal(7m, r.Pending);
        Assert.Equal(PendentesPicagemFonte.Kapps, r.Fonte);
    }

    [Fact]
    public void Varias_linhas_soma_encomenda()
    {
        var a = PendentesPicagemRules.AvaliarLinha(10, 3, 3, 0, true); // Sum66 → 7
        var b = PendentesPicagemRules.AvaliarLinha(5, 0, 0, 2, true);  // Kapps → 3
        Assert.True(a.Incluir);
        Assert.True(b.Incluir);
        Assert.Equal(
            10m,
            PendentesPicagemRules.SomarPendentesEncomenda(new[] { a.Pending, b.Pending }));
    }

    [Fact]
    public void Kapps_pending_zero_ou_negativo_exclui()
    {
        var r = PendentesPicagemRules.AvaliarLinha(qtt: 5, qtt2: 0, sum66: 0, picked: 5, encomendaIniciou: true);
        Assert.False(r.Incluir);
    }

    /// <summary>
    /// Regressão: o filtro de artigo/cor não pode eliminar a linha que iniciou o picking
    /// antes de calcular <c>started</c>. O started usa todas as linhas; a irmã filtrada
    /// permanece elegível.
    /// </summary>
    [Fact]
    public void Filtro_referencia_nao_impede_started_via_linha_irma()
    {
        // A (1280) iniciou; B (1053) não. Filtro conceptual só a B.
        var todasLinhasDaEncomenda = new[]
        {
            (0m, 3m), // A — iniciou
            (0m, 0m), // B — filtrada na pesquisa
        };

        // started SOBRE TODAS as linhas (não só as filtradas)
        var iniciou = PendentesPicagemRules.EncomendaIniciouPicking(todasLinhasDaEncomenda);
        Assert.True(iniciou);

        // B continua elegível apesar do filtro conceptual só a B
        var b = PendentesPicagemRules.AvaliarLinha(qtt: 3, qtt2: 0, sum66: 0, picked: 0, encomendaIniciou: iniciou);
        Assert.True(b.Incluir);
        Assert.Equal(3m, b.Pending);

        // Se started fosse calculado só sobre o conjunto filtrado (só B), falharia:
        var startedErradoSoFiltradas = PendentesPicagemRules.EncomendaIniciouPicking(new[] { (0m, 0m) });
        Assert.False(startedErradoSoFiltradas);
        var bSeStartedErrado = PendentesPicagemRules.AvaliarLinha(3, 0, 0, 0, startedErradoSoFiltradas);
        Assert.False(bSeStartedErrado.Incluir);
    }

    [Fact]
    public void Caso3_integrado_mais_irma_sem_inicio()
    {
        Assert.True(PendentesPicagemRules.EncomendaIniciouPicking(new[] { (0m, 3m), (0m, 0m) }));
        var a = PendentesPicagemRules.AvaliarLinha(7, 0, 3, 0, true);
        var b = PendentesPicagemRules.AvaliarLinha(5, 0, 0, 0, true);
        Assert.Equal(4m, a.Pending);
        Assert.Equal(5m, b.Pending);
    }
}
