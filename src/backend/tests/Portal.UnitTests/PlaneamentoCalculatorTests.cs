using Portal.Application.Encomendas;

namespace Portal.UnitTests;

public sealed class PlaneamentoCalculatorTests
{
    private const string Dia = "Monday";
    private const string Hora = "12:00";
    private const string Fuso = "Europe/Lisbon";

    [Theory]
    // Segunda antes das 12:00 → Dentro
    [InlineData("2026-08-10", "11:59:59", "DP")]
    // Segunda às 12:00 ou depois → Após
    [InlineData("2026-08-10", "12:00:00", "AC")]
    [InlineData("2026-08-10", "17:09:06", "AC")]
    // Terça da mesma semana → Após (já passou a Segunda 12:00 dessa semana)
    [InlineData("2026-08-11", "12:00:52", "AC")]
    // Sábado → Após
    [InlineData("2026-08-08", "15:16:39", "AC")]
    // Domingo (semana ISO a começar Segunda anterior) → Após
    [InlineData("2026-08-09", "10:00:00", "AC")]
    public void Classificar_usa_segunda_da_semana_da_encomenda(string data, string hora, string codigoEsperado)
    {
        var dataObra = DateTime.Parse(data);
        var (_, codigo) = PlaneamentoCalculator.Classificar(dataObra, hora, Dia, Hora, Fuso);
        Assert.Equal(codigoEsperado, codigo);
    }

    [Fact]
    public void Classificar_nao_usa_segunda_da_semana_actual()
    {
        // Encomenda antiga: com a regra errada (Segunda de "agora") cairia em DP em Setembro;
        // com Apêndice A deve ser AC (depois da Segunda 12:00 da sua semana).
        var (_, codigo) = PlaneamentoCalculator.Classificar(
            new DateTime(2026, 8, 11),
            "12:00:52",
            Dia,
            Hora,
            Fuso,
            agoraUtc: new DateTime(2026, 9, 2, 8, 0, 0, DateTimeKind.Utc));

        Assert.Equal("AC", codigo);
    }
}

