using Portal.Application.Cliente;

namespace Portal.UnitTests;

public class ClientePedidoListaOrdenacaoTests
{
    [Fact]
    public void MergeTop_ordena_mais_recentes_primeiro_e_respeita_top()
    {
        var internos = new[]
        {
            Item(pedidoId: 1, data: new DateTime(2026, 10, 1), origem: "interno"),
            Item(pedidoId: 3, data: new DateTime(2026, 10, 3), origem: "interno"),
        };
        var legado = new[]
        {
            Item(pedidoId: null, obrano: 50, data: new DateTime(2026, 10, 2), origem: "legado"),
            Item(pedidoId: null, obrano: 99, data: new DateTime(2026, 10, 4), origem: "legado"),
        };

        var merged = ClientePedidoListaOrdenacao.MergeTop(internos, legado, top: 3);

        Assert.Equal(3, merged.Count);
        Assert.Equal(99, merged[0].Obrano);
        Assert.Equal(3, merged[1].PedidoId);
        Assert.Equal(50, merged[2].Obrano);
    }

    [Fact]
    public void MergeTop_desempate_PedidoId_DESC_depois_Obrano_DESC()
    {
        var sameDay = new DateTime(2026, 10, 28, 12, 0, 0, DateTimeKind.Utc);
        var items = new[]
        {
            Item(pedidoId: 10, data: sameDay, origem: "interno"),
            Item(pedidoId: 20, data: sameDay, origem: "interno"),
            Item(pedidoId: null, obrano: 5, data: sameDay, origem: "legado"),
            Item(pedidoId: null, obrano: 8, data: sameDay, origem: "legado"),
        };

        var merged = ClientePedidoListaOrdenacao.MergeTop(items, [], top: 10);

        Assert.Equal(new long?[] { 20, 10, null, null }, merged.Select(x => x.PedidoId).ToArray());
        Assert.Equal(8m, merged[2].Obrano);
        Assert.Equal(5m, merged[3].Obrano);
    }

    [Fact]
    public void MergeTop_nao_duplica_quando_mesma_referencia_aparece_numa_lista()
    {
        var a = Item(pedidoId: 7, data: new DateTime(2026, 10, 5), origem: "interno");
        var merged = ClientePedidoListaOrdenacao.MergeTop([a], [], top: 10);
        Assert.Single(merged);
        Assert.Equal(7, merged[0].PedidoId);
    }

    [Fact]
    public void MergeTop_exclui_legado_com_mesmo_bostamp_que_interno_integrado()
    {
        var interno = Item(
            pedidoId: 19,
            data: new DateTime(2026, 10, 28, 12, 0, 0, DateTimeKind.Utc),
            origem: "interno",
            bostamp: "BOSTAMP-19");
        var legadoMesmo = Item(
            pedidoId: null,
            obrano: 19,
            data: new DateTime(2026, 10, 28, 11, 0, 0, DateTimeKind.Utc),
            origem: "legado",
            bostamp: "BOSTAMP-19");
        var legadoOutro = Item(
            pedidoId: null,
            obrano: 3,
            data: new DateTime(2026, 10, 20),
            origem: "legado",
            bostamp: "BOSTAMP-OTHER");

        var merged = ClientePedidoListaOrdenacao.MergeTop([interno], [legadoMesmo, legadoOutro], top: 10);

        Assert.Equal(2, merged.Count);
        Assert.Equal(19, merged[0].PedidoId);
        Assert.Equal("BOSTAMP-OTHER", merged[1].Bostamp);
        Assert.DoesNotContain(merged, x => x.Origem == "legado" && x.Bostamp == "BOSTAMP-19");
    }

    [Fact]
    public void MergeTop_bostamp_nulo_ou_vazio_nao_remove_legado_nem_interno()
    {
        var internoSemLink = Item(pedidoId: 5, data: new DateTime(2026, 10, 10), origem: "interno", bostamp: null);
        var internoVazio = Item(pedidoId: 6, data: new DateTime(2026, 10, 11), origem: "interno", bostamp: "  ");
        var legado = Item(pedidoId: null, obrano: 1, data: new DateTime(2026, 10, 9), origem: "legado", bostamp: "LEG-1");

        var merged = ClientePedidoListaOrdenacao.MergeTop(
            [internoSemLink, internoVazio], [legado], top: 10);

        Assert.Equal(3, merged.Count);
        Assert.Contains(merged, x => x.PedidoId == 5);
        Assert.Contains(merged, x => x.PedidoId == 6);
        Assert.Contains(merged, x => x.Bostamp == "LEG-1");
    }

    [Fact]
    public void MergeTop_bostamp_case_insensitive_e_top_apos_dedupe()
    {
        var interno = Item(pedidoId: 8, data: new DateTime(2026, 10, 15), origem: "interno", bostamp: "AbC");
        var legadoDup = Item(pedidoId: null, obrano: 8, data: new DateTime(2026, 10, 14), origem: "legado", bostamp: "abc");
        var legadoKeep = Item(pedidoId: null, obrano: 2, data: new DateTime(2026, 10, 16), origem: "legado", bostamp: "XYZ");

        var merged = ClientePedidoListaOrdenacao.MergeTop([interno], [legadoDup, legadoKeep], top: 1);

        Assert.Single(merged);
        Assert.Equal("XYZ", merged[0].Bostamp);
        Assert.Equal("legado", merged[0].Origem);
    }

    [Fact]
    public void MergeTop_datas_iguais_desempate_PedidoId_mantem_interno_sem_legado()
    {
        var day = new DateTime(2026, 10, 28, 10, 0, 0, DateTimeKind.Utc);
        var a = Item(pedidoId: 1, data: day, origem: "interno", bostamp: "S1");
        var b = Item(pedidoId: 2, data: day, origem: "interno", bostamp: "S2");
        var merged = ClientePedidoListaOrdenacao.MergeTop([a, b], [], top: 10);
        Assert.Equal(new long?[] { 2, 1 }, merged.Select(x => x.PedidoId).ToArray());
    }

    [Fact]
    public void ClampTop_limites_1_a_50()
    {
        Assert.Equal(1, ClientePedidoListaOrdenacao.ClampTop(0));
        Assert.Equal(50, ClientePedidoListaOrdenacao.ClampTop(999));
        Assert.Equal(10, ClientePedidoListaOrdenacao.ClampTop(10));
    }

    private static ClientePedidoListaItem Item(
        DateTime data,
        string origem,
        long? pedidoId = null,
        decimal? obrano = null,
        string? bostamp = null) =>
        new(
            Bostamp: bostamp ?? (origem == "legado" ? "STAMP" : null),
            Obrano: obrano,
            Boano: origem == "legado" ? 2026 : null,
            DataObra: data,
            Hora: null,
            EstadoCodigo: "recebido",
            EstadoEtiqueta: "Recebido",
            Etotaldeb: 1m,
            PodeCancelar: false,
            PedidoId: pedidoId,
            NumeroInterno: pedidoId is null ? null : $"PM-2026-{pedidoId:D6}",
            Origem: origem);
}
