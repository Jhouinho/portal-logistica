using Portal.Application.Encomendas;

namespace Portal.UnitTests;

public sealed class ForaDePrazoCalculatorTests
{
    private const string Fuso = "Europe/Lisbon";

    /// <summary>Quarta 2026-08-12 12:00 Lisboa — semana seg 10/08 … dom 16/08; limite seg 10 12:30.</summary>
    private static readonly DateTime AgoraQuartaMesmaSemana = UtcFromLisbon(2026, 8, 12, 12, 0, 0);

    private static DateTime UtcFromLisbon(int y, int m, int d, int h, int mi, int s = 0)
    {
        var tz = ResolveTz();
        var local = new DateTime(y, m, d, h, mi, s, DateTimeKind.Unspecified);
        return TimeZoneInfo.ConvertTimeToUtc(local, tz);
    }

    private static TimeZoneInfo ResolveTz()
    {
        try
        {
            return TimeZoneInfo.FindSystemTimeZoneById(Fuso);
        }
        catch (TimeZoneNotFoundException)
        {
            return TimeZoneInfo.FindSystemTimeZoneById("GMT Standard Time");
        }
        catch (InvalidTimeZoneException)
        {
            return TimeZoneInfo.FindSystemTimeZoneById("GMT Standard Time");
        }
    }

    private static bool Classificar(string ousrdataDia, string ousrhora, DateTime agoraUtc) =>
        ForaDePrazoCalculator.Classificar(
            DateTime.Parse(ousrdataDia),
            ousrhora,
            agoraUtc,
            Fuso);

    [Theory]
    [InlineData("2026-08-10", "12:29:59", false)]
    [InlineData("2026-08-10", "12:30:00", false)]
    [InlineData("2026-08-10", "12:30:01", true)]
    [InlineData("2026-08-12", "09:00:00", true)]
    public void Semana_actual_limite_1230_inclusive(string dia, string hora, bool esperado) =>
        Assert.Equal(esperado, Classificar(dia, hora, AgoraQuartaMesmaSemana));

    [Fact]
    public void Semana_anterior_nunca_fora_de_prazo()
    {
        Assert.False(Classificar("2026-08-03", "15:00:00", AgoraQuartaMesmaSemana));
        // Caso referência n.º 19: 02/10/2026 com «agora» na semana 12–18/10.
        var agoraOut = UtcFromLisbon(2026, 10, 15, 10, 0, 0);
        Assert.False(Classificar("2026-10-02", "15:56:37", agoraOut));
    }

    [Fact]
    public void Semana_futura_usa_limite_da_semana_actual()
    {
        // Entrada na segunda seguinte 10:00 → já depois do limite 10/08 12:30 → true.
        Assert.True(Classificar("2026-08-17", "10:00:00", AgoraQuartaMesmaSemana));
        // Futura mas antes do limite da semana actual (impossível se futura > seg+7…);
        // segunda actual 12:00 (antes do limite) na mesma semana seria false; aqui futura.
        Assert.True(Classificar("2026-08-17", "12:30:01", AgoraQuartaMesmaSemana));
    }

    [Fact]
    public void Transicao_domingo_para_segunda()
    {
        // Domingo 16/08 18:00: semana ainda 10–16; entrada seg 10 15:00 → fora.
        var domingo = UtcFromLisbon(2026, 8, 16, 18, 0, 0);
        Assert.True(Classificar("2026-08-10", "15:00:00", domingo));

        // Segunda 17/08 10:00: nova semana; entrada 10/08 → semana anterior → false.
        var segundaManha = UtcFromLisbon(2026, 8, 17, 10, 0, 0);
        Assert.False(Classificar("2026-08-10", "15:00:00", segundaManha));

        // Segunda 17/08 15:00: limite da nova semana = 17 12:30; entrada 17 15:00 → true.
        var segundaTarde = UtcFromLisbon(2026, 8, 17, 15, 0, 0);
        Assert.True(Classificar("2026-08-17", "15:00:00", segundaTarde));
        Assert.False(Classificar("2026-08-17", "12:30:00", segundaTarde));
    }

    [Theory]
    [InlineData(null, "12:31:00")]
    [InlineData("2026-08-10", "")]
    [InlineData("2026-08-10", "xx:yy")]
    public void Temporal_invalido_false(string? dia, string hora)
    {
        DateTime? ousrdata = dia is null ? null : DateTime.Parse(dia);
        Assert.False(ForaDePrazoCalculator.Classificar(ousrdata, hora, AgoraQuartaMesmaSemana, Fuso));
    }

    [Fact]
    public void Ousrhora_como_datetime_texto_phc_e_aceitavel()
    {
        Assert.True(Classificar(
            "2026-08-10",
            "1900-01-01 15:00:00",
            AgoraQuartaMesmaSemana));
    }

    [Fact]
    public void Dst_primavera_e_outono_lisboa()
    {
        // Mudança de hora 2026-03-29; quarta 01/04 na semana da segunda 30/03.
        var agora = UtcFromLisbon(2026, 4, 1, 12, 0, 0);
        Assert.False(Classificar("2026-03-30", "12:30:00", agora));
        Assert.True(Classificar("2026-03-30", "12:30:01", agora));
        Assert.False(Classificar("2026-03-23", "18:00:00", agora));

        // Outono 2026-10-25; quarta 28/10, semana seg 26/10.
        agora = UtcFromLisbon(2026, 10, 28, 12, 0, 0);
        Assert.False(Classificar("2026-10-26", "12:30:00", agora));
        Assert.True(Classificar("2026-10-26", "12:30:01", agora));
        Assert.False(Classificar("2026-10-19", "18:00:00", agora));
    }
}
