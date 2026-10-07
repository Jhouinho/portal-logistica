using System.Globalization;

namespace Portal.Application.Encomendas;

/// <summary>
/// Parse de horas de filtro (HTML time = HH:mm; PHC ousrhora = HH:mm:ss).
/// </summary>
public static class TimeQuery
{
    /// <summary>Início do intervalo (HH:mm → HH:mm:00).</summary>
    public static TimeSpan? ParseHoraDe(string? raw)
    {
        if (!TryParse(raw, out var ts))
            return null;
        return new TimeSpan(ts.Hours, ts.Minutes, ts.Seconds);
    }

    /// <summary>
    /// Fim do intervalo. Se o utilizador só indicou HH:mm, inclui o minuto inteiro (…:59).
    /// </summary>
    public static TimeSpan? ParseHoraAte(string? raw)
    {
        if (string.IsNullOrWhiteSpace(raw))
            return null;

        var s = raw.Trim();
        if (!TryParse(s, out var ts))
            return null;

        // "15:16" (sem segundos) → até 15:16:59
        if (s.Length <= 5 && s.Count(c => c == ':') == 1)
            return new TimeSpan(ts.Hours, ts.Minutes, 59);

        return new TimeSpan(ts.Hours, ts.Minutes, ts.Seconds);
    }

    public static string? ToSqlTime(TimeSpan? ts)
        => ts is null ? null : ts.Value.ToString(@"hh\:mm\:ss", CultureInfo.InvariantCulture);

    private static bool TryParse(string? raw, out TimeSpan ts)
    {
        ts = default;
        if (string.IsNullOrWhiteSpace(raw))
            return false;

        var s = raw.Trim();
        if (TimeSpan.TryParseExact(
                s,
                ["hh\\:mm\\:ss", "h\\:mm\\:ss", "hh\\:mm", "h\\:mm"],
                CultureInfo.InvariantCulture,
                out ts))
            return true;

        if (TimeSpan.TryParse(s, CultureInfo.InvariantCulture, out ts))
            return true;

        // Alguns browsers / URL: "15%3A16" já descodificado; ou "15.16"
        return false;
    }
}
