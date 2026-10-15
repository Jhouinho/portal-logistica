using Portal.Application.Cliente;

namespace Portal.UnitTests;

public class ClienteAuthRulesTests
{
    [Theory]
    [InlineData("912 345 678", "912345678")]
    [InlineData("+351912345678", "912345678")]
    [InlineData("+351 912 345 678", "912345678")]
    [InlineData("(912)-345-678", "912345678")]
    [InlineData("00351912345678", "912345678")]
    public void Normalize_remove_separadores_e_prefixo(string raw, string expected)
    {
        Assert.Equal(expected, PhoneNormalizer.Normalize(raw));
    }

    [Fact]
    public void Matches_prioriza_tlmvl()
    {
        Assert.True(PhoneNormalizer.Matches("912345678", "912 345 678", "210000000"));
        Assert.False(PhoneNormalizer.Matches("210000000", "912345678", "210000000"));
    }

    [Fact]
    public void Matches_usa_telefone_se_tlmvl_vazio()
    {
        Assert.True(PhoneNormalizer.Matches("210000000", null, "210 000 000"));
    }

    [Fact]
    public void Elegibilidade_consumidor_final()
    {
        var status = ClienteElegibilidadeRules.Classify("999999990", []);
        Assert.Equal(ClienteElegibilidade.ConsumidorFinal, status);
    }

    [Fact]
    public void Elegibilidade_sem_ficha()
    {
        Assert.Equal(ClienteElegibilidade.SemFicha, ClienteElegibilidadeRules.Classify("123", []));
    }

    [Fact]
    public void Elegibilidade_varias_fichas()
    {
        var fichas = new[]
        {
            new ClienteFicha(1, 0, "A", "123", null, null),
            new ClienteFicha(2, 0, "B", "123", null, null),
        };
        Assert.Equal(ClienteElegibilidade.VariasFichas, ClienteElegibilidadeRules.Classify("123", fichas));
    }

    [Fact]
    public void Elegibilidade_unica_ok()
    {
        var fichas = new[] { new ClienteFicha(1911, 0, "X", "515240184", "912", null) };
        Assert.Equal(ClienteElegibilidade.Ok, ClienteElegibilidadeRules.Classify("515240184", fichas));
    }
}
