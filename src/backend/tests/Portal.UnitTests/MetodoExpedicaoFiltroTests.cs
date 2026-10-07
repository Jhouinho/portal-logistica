using Portal.Application.Encomendas;
using Xunit;

namespace Portal.UnitTests;

public sealed class MetodoExpedicaoFiltroTests
{
    [Theory]
    [InlineData(null, null, true)]
    [InlineData("", "", true)]
    [InlineData("N/Viatura", null, true)]
    [InlineData("N/Viatura", "Todos", true)]
    [InlineData("N/Viatura", "todos", true)]
    [InlineData("N/Viatura", "N/Viatura", true)]
    [InlineData(" N/Viatura ", "N/Viatura", true)]
    [InlineData("Transportadora", "N/Viatura", false)]
    [InlineData("", "nao_definido", true)]
    [InlineData("  ", "nao_definido", true)]
    [InlineData(null, "nao_definido", true)]
    [InlineData("N/Viatura", "nao_definido", false)]
    [InlineData("Levantamento em Armazem", "Levantamento em Armazem", true)]
    public void Coincide_match(string? metodo, string? filtro, bool expected)
    {
        Assert.Equal(expected, MetodoExpedicaoFiltro.Coincide(metodo, filtro));
    }
}
