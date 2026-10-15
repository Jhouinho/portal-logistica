namespace Portal.Application.Encomendas;

/// <summary>
/// Indicação visual «Fora de prazo» (independente de DP/AC):
/// instante de entrada = <c>ousrdata</c> (dia) + <c>ousrhora</c> (hora de parede Europe/Lisbon)
/// da encomenda original ndos=1;
/// limite = segunda-feira da <b>semana actual</b> às 12:30:00 (inclusive → <b>não</b> fora de prazo);
/// semanas anteriores → <c>false</c>;
/// semana actual e semanas futuras → <c>entrada &gt; limite</c> (limite da semana actual, não da semana da encomenda).
/// Valores nulos/inválidos → <c>false</c> (não lança).
/// </summary>
public static class ForaDePrazoCalculator
{
    private static readonly TimeSpan HoraLimite = new(12, 30, 0);

    /// <param name="ousrdata">Dia de criação/entrada PHC (hora do campo ignorada; usa-se só a data).</param>
    /// <param name="ousrhora">Hora PHC (<c>varchar</c>, tipicamente HH:mm:ss).</param>
    /// <param name="agoraUtc">Instante actual em UTC (testável; não usar relógio interno).</param>
    /// <param name="fuso">IANA preferido: <c>Europe/Lisbon</c>.</param>
    public static bool Classificar(
        DateTime? ousrdata,
        string? ousrhora,
        DateTime agoraUtc,
        string fuso = "Europe/Lisbon")
    {
        if (ousrdata is null)
            return false;

        if (!TryCombinarEntradaLisboa(ousrdata.Value, ousrhora, out var entradaLisboa))
            return false;

        if (!TryResolveTimeZone(fuso, out var tz))
            return false;

        var utc = NormalizeUtc(agoraUtc);
        DateTime agoraLisboa;
        try
        {
            agoraLisboa = TimeZoneInfo.ConvertTimeFromUtc(utc, tz);
        }
        catch (ArgumentException)
        {
            return false;
        }

        var segunda = InicioSemanaSegunda(agoraLisboa);
        var limite = segunda.Add(HoraLimite);

        // Semanas anteriores à semana actual: nunca «fora de prazo».
        if (entradaLisboa < segunda)
            return false;

        // Semana actual e futuras: limite = segunda 12:30 da semana actual.
        return entradaLisboa > limite;
    }

    private static bool TryCombinarEntradaLisboa(DateTime ousrdata, string? ousrhora, out DateTime entrada)
    {
        entrada = default;
        var raw = ousrhora?.Trim() ?? string.Empty;
        if (raw.Length == 0)
            return false;

        if (TimeSpan.TryParse(raw, out var ts))
        {
            entrada = ousrdata.Date.Add(ts);
            return true;
        }

        // PHC por vezes devolve "1900-01-01 12:00:52" / datetime completo
        if (DateTime.TryParse(raw, out var dt))
        {
            entrada = ousrdata.Date.Add(dt.TimeOfDay);
            return true;
        }

        return false;
    }

    private static DateTime InicioSemanaSegunda(DateTime agoraLisboa)
    {
        var diasDesdeSegunda = ((int)agoraLisboa.DayOfWeek - (int)DayOfWeek.Monday + 7) % 7;
        return agoraLisboa.Date.AddDays(-diasDesdeSegunda);
    }

    private static DateTime NormalizeUtc(DateTime agoraUtc) =>
        agoraUtc.Kind switch
        {
            DateTimeKind.Utc => agoraUtc,
            DateTimeKind.Local => agoraUtc.ToUniversalTime(),
            _ => DateTime.SpecifyKind(agoraUtc, DateTimeKind.Utc),
        };

    private static bool TryResolveTimeZone(string fuso, out TimeZoneInfo tz)
    {
        try
        {
            tz = TimeZoneInfo.FindSystemTimeZoneById(fuso);
            return true;
        }
        catch (TimeZoneNotFoundException)
        {
            // Windows: Europe/Lisbon → GMT Standard Time (com DST UK/PT alinhado na prática do portal).
        }
        catch (InvalidTimeZoneException)
        {
        }

        try
        {
            tz = TimeZoneInfo.FindSystemTimeZoneById("GMT Standard Time");
            return true;
        }
        catch (TimeZoneNotFoundException)
        {
            tz = null!;
            return false;
        }
        catch (InvalidTimeZoneException)
        {
            tz = null!;
            return false;
        }
    }
}
