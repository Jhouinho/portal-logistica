using System.Globalization;

namespace Portal.Application.Encomendas;

/// <summary>Parse seguro de datas de query (yyyy-MM-dd) — evita DateTime.MinValue / overflow SQL.</summary>
public static class DateQuery
{
    public static DateTime? ParseDateOnly(string? raw)
    {
        if (string.IsNullOrWhiteSpace(raw))
            return null;

        var s = raw.Trim();
        if (DateOnly.TryParseExact(
                s,
                "yyyy-MM-dd",
                CultureInfo.InvariantCulture,
                DateTimeStyles.None,
                out var d))
            return d.ToDateTime(TimeOnly.MinValue);

        if (DateOnly.TryParse(s, CultureInfo.InvariantCulture, DateTimeStyles.None, out d))
            return d.ToDateTime(TimeOnly.MinValue);

        if (DateTime.TryParse(
                s,
                CultureInfo.InvariantCulture,
                DateTimeStyles.AssumeLocal | DateTimeStyles.AllowWhiteSpaces,
                out var dt))
        {
            if (dt.Year < 1753 || dt.Year > 9999)
                return null;
            return dt.Date;
        }

        return null;
    }

    public static DateTime? Normalize(DateTime? value)
    {
        if (value is null)
            return null;
        var d = value.Value.Date;
        if (d.Year < 1753 || d.Year > 9999)
            return null;
        return DateTime.SpecifyKind(d, DateTimeKind.Unspecified);
    }
}
