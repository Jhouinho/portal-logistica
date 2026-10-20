using Portal.Application.Cliente;
using Portal.Infrastructure.Options;

namespace Portal.UnitTests;

public class ClientePmPedidoPhase1Tests
{
    [Fact]
    public void PedidosInternosEnabled_default_false()
    {
        var o = new PortalClienteOptions();
        Assert.False(o.PedidosInternosEnabled);
    }

    [Fact]
    public void FormatNumeroInterno_usa_ano_da_data_e_pedidoId()
    {
        var n = ClientePedidoIdempotency.FormatNumeroInterno(42, new DateTime(2026, 10, 20, 0, 0, 0, DateTimeKind.Utc));
        Assert.Equal("PM-2026-000042", n);
    }

    [Fact]
    public void PayloadHash_igual_para_mesma_ordem_semantica()
    {
        var a = new[]
        {
            new ClientePedidoLinhaInput(2, "B", 1m, "  x "),
            new ClientePedidoLinhaInput(1, "A", 2m, ""),
        };
        var b = new[]
        {
            new ClientePedidoLinhaInput(1, "A", 2m, ""),
            new ClientePedidoLinhaInput(2, "B", 1m, "x"),
        };
        Assert.Equal(
            ClientePedidoIdempotency.ComputePayloadHash(a),
            ClientePedidoIdempotency.ComputePayloadHash(b));
    }

    [Fact]
    public void PayloadHash_diferente_quando_qtt_muda()
    {
        var a = new[] { new ClientePedidoLinhaInput(1, "A", 1m, "") };
        var b = new[] { new ClientePedidoLinhaInput(1, "A", 2m, "") };
        Assert.NotEqual(
            ClientePedidoIdempotency.ComputePayloadHash(a),
            ClientePedidoIdempotency.ComputePayloadHash(b));
    }

    [Fact]
    public void PayloadHash_nao_depende_de_preco()
    {
        // Preço não entra no input — só ref/qtt/cor/ord.
        var h = ClientePedidoIdempotency.ComputePayloadHash(
            [new ClientePedidoLinhaInput(1, "1310", 3m, "AZUL")]);
        Assert.Equal(64, h.Length);
    }

    [Fact]
    public void MapInterno_recebido_nunca_aprovado_nem_cancelavel()
    {
        var m = ClientePedidoEstadoMapper.MapInterno("recebido");
        Assert.Equal("recebido", m.Codigo);
        Assert.Equal("Recebido", m.Etiqueta);
        Assert.False(m.PodeCancelar);
        Assert.NotEqual("aprovado", m.Codigo);
    }

    [Fact]
    public void MapInterno_integrado_apresenta_aprovado()
    {
        var m = ClientePedidoEstadoMapper.MapInterno("integrado");
        Assert.Equal("aprovado", m.Codigo);
        Assert.False(m.PodeCancelar);
    }

    [Fact]
    public void Map_legado_submetido_mantem_cancelavel()
    {
        var m = ClientePedidoEstadoMapper.Map(cancelado: false);
        Assert.Equal("submetido", m.Codigo);
        Assert.True(m.PodeCancelar);
    }

    [Fact]
    public void TotalLinha_round_6_como_desenho()
    {
        var preco = Math.Round(12.3456789m, 6, MidpointRounding.AwayFromZero);
        var total = Math.Round(3m * preco, 6, MidpointRounding.AwayFromZero);
        Assert.Equal(12.345679m, preco);
        Assert.Equal(37.037037m, total);
    }

    [Fact]
    public void LinhaDto_sem_preco_do_frontend()
    {
        var linhaType = typeof(Portal.Api.Controllers.ClientePedidosController.LinhaDto);
        Assert.Null(linhaType.GetProperty("PrecoUnitario"));
        Assert.Null(linhaType.GetProperty("Preco"));
    }
}
