using Portal.Application.Encomendas;
using Xunit;

namespace Portal.UnitTests;

public sealed class PickingCancelRulesTests
{
    [Theory]
    [InlineData(true, false, false, true)]
    [InlineData(true, true, false, false)]
    [InlineData(true, false, true, false)]
    [InlineData(true, true, true, false)]
    [InlineData(false, false, false, false)]
    public void PodeCancelarNaUi_combina_modo_temQtt66_e_emAndamento(
        bool modoPicking,
        bool temQtt66,
        bool emAndamento,
        bool esperado)
    {
        Assert.Equal(
            esperado,
            PickingCancelRules.PodeCancelarNaUi(modoPicking, temQtt66, emAndamento));
    }

    [Fact]
    public void CancelamentoBloqueadoPorQtt66_quando_tem_materializado()
    {
        Assert.True(PickingCancelRules.CancelamentoBloqueadoPorQtt66(true));
        Assert.False(PickingCancelRules.CancelamentoBloqueadoPorQtt66(false));
    }
}
