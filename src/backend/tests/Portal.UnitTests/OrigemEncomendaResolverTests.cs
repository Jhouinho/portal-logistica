using Portal.Application.Encomendas;

namespace Portal.UnitTests;

public sealed class OrigemEncomendaResolverTests
{
    [Fact]
    public void Preferir_hop1_sobre_hop2_mesmo_quando_hop2_tem_obrano_maior()
    {
        var hop1 = new[]
        {
            new OrigemEncomendaResolver.Candidato(
                100, "stamp-a", new DateTime(2026, 3, 10), "09:00:00")
        };
        var hop2 = new[]
        {
            new OrigemEncomendaResolver.Candidato(
                999, "stamp-z", new DateTime(2026, 1, 1), "23:59:59")
        };

        var r = OrigemEncomendaResolver.Resolver(hop1, hop2);

        Assert.NotNull(r);
        Assert.Equal(100, r!.Obrano);
        Assert.Equal(new DateTime(2026, 3, 10), r.Ousrdata);
        Assert.Equal("09:00:00", r.Ousrhora);
    }

    [Fact]
    public void Sem_hop1_usa_hop2_65_66_1()
    {
        var hop2 = new[]
        {
            new OrigemEncomendaResolver.Candidato(
                50, "bo-sep", new DateTime(2026, 2, 5), "14:30:00")
        };

        var r = OrigemEncomendaResolver.Resolver(
            Array.Empty<OrigemEncomendaResolver.Candidato>(), hop2);

        Assert.NotNull(r);
        Assert.Equal(50, r!.Obrano);
        Assert.Equal(new DateTime(2026, 2, 5), r.Ousrdata);
        Assert.Equal("14:30:00", r.Ousrhora);
    }

    [Fact]
    public void Multiplas_origens_escolhe_MAX_obrano_e_data_hora_do_mesmo_BO()
    {
        // Candidato com ousrdata/hora “maiores” lexicalmente/cronologicamente mas obrano menor
        // — o critério legado é MAX(obrano), não MAX(ousrdata)/MAX(ousrhora).
        var hop1 = new[]
        {
            new OrigemEncomendaResolver.Candidato(
                10, "bo-low", new DateTime(2026, 12, 31), "23:59:59"),
            new OrigemEncomendaResolver.Candidato(
                20, "bo-high", new DateTime(2026, 1, 2), "08:15:00"),
            new OrigemEncomendaResolver.Candidato(
                15, "bo-mid", new DateTime(2026, 6, 1), "12:00:00")
        };

        var r = OrigemEncomendaResolver.Resolver(
            hop1, Array.Empty<OrigemEncomendaResolver.Candidato>());

        Assert.NotNull(r);
        Assert.Equal(20, r!.Obrano);
        Assert.Equal(new DateTime(2026, 1, 2), r.Ousrdata);
        Assert.Equal("08:15:00", r.Ousrhora);
        // Prova de atomicidade: não misturou 31/12 com 08:15 nem 01/02 com 23:59.
        Assert.NotEqual(new DateTime(2026, 12, 31), r.Ousrdata);
        Assert.NotEqual("23:59:59", r.Ousrhora);
    }

    [Fact]
    public void Empate_obrano_desempata_por_bostamp_DESC_mantendo_par_temporal()
    {
        var hop1 = new[]
        {
            new OrigemEncomendaResolver.Candidato(
                7, "stamp-aaa", new DateTime(2026, 4, 1), "10:00:00"),
            new OrigemEncomendaResolver.Candidato(
                7, "stamp-zzz", new DateTime(2026, 4, 2), "11:00:00")
        };

        var r = OrigemEncomendaResolver.Resolver(
            hop1, Array.Empty<OrigemEncomendaResolver.Candidato>());

        Assert.NotNull(r);
        Assert.Equal(7, r!.Obrano);
        Assert.Equal(new DateTime(2026, 4, 2), r.Ousrdata);
        Assert.Equal("11:00:00", r.Ousrhora);
    }

    [Fact]
    public void Sem_candidatos_devolve_null_sem_inventar_datas()
    {
        var r = OrigemEncomendaResolver.Resolver(
            Array.Empty<OrigemEncomendaResolver.Candidato>(),
            Array.Empty<OrigemEncomendaResolver.Candidato>());

        Assert.Null(r);
    }

    [Fact]
    public void Hop1_com_ousrdata_null_nao_cai_para_hop2()
    {
        // COALESCE(ousrdata) antigo falhava aqui: NULL no hop1 abria hop2.
        var hop1 = new[]
        {
            new OrigemEncomendaResolver.Candidato(1, "bo-1", null, null)
        };
        var hop2 = new[]
        {
            new OrigemEncomendaResolver.Candidato(
                2, "bo-2", new DateTime(2026, 5, 1), "12:00:00")
        };

        var r = OrigemEncomendaResolver.Resolver(hop1, hop2);

        Assert.NotNull(r);
        Assert.Equal(1, r!.Obrano);
        Assert.Null(r.Ousrdata);
        Assert.Equal(string.Empty, r.Ousrhora);
    }
}
