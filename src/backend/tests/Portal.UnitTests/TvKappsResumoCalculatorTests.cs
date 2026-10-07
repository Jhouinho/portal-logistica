using Portal.Application.Painel;

namespace Portal.UnitTests;

public sealed class TvKappsResumoCalculatorTests
{
    [Theory]
    [InlineData(0, 0, 0, "espera", 0)]
    [InlineData(10, 0, 10, "espera", 0)]
    [InlineData(10, 4, 6, "curso", 40)]
    [InlineData(10, 10, 0, "concluido", 100)]
    [InlineData(10, 0, 0, "concluido", 100)] // pending=0 com qty>0 → concluído (Kapps)
    [InlineData(30, 10, 20, "curso", 33)]
    public void FromTotais_matches_kappsVisual_rules(
        double qty,
        double picked,
        double pending,
        string expectedKind,
        int expectedPct)
    {
        var (kind, pct) = TvKappsResumoCalculator.FromTotais(
            (decimal)qty,
            (decimal)picked,
            (decimal)pending);
        Assert.Equal(expectedKind, kind);
        Assert.Equal(expectedPct, pct);
    }

    [Fact]
    public void ToItem_trims_and_maps_activity()
    {
        var item = TvKappsResumoCalculator.ToItem(new TvKappsResumoRow
        {
            BoStamp = "  stamp1  ",
            Origem = " encomenda ",
            Qty = 10,
            Picked = 5,
            Pending = 5,
            ActiveTerminalId = 2,
            ActiveTerminalLabel = "  Term A  ",
            ActiveUserId = "  admin  ",
        });

        Assert.Equal("stamp1", item.BoStamp);
        Assert.Equal("encomenda", item.Origem);
        Assert.Equal("curso", item.Kind);
        Assert.Equal(50, item.Pct);
        Assert.Equal(2, item.ActiveTerminalId);
        Assert.Equal("Term A", item.ActiveTerminalLabel);
        Assert.Equal("admin", item.ActiveUserId);
    }
}
