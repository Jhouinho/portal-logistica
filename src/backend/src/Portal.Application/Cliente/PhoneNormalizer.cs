using System.Text;

namespace Portal.Application.Cliente;

/// <summary>Normalização RN-017: espaços, hífenes, parênteses e prefixo +351.</summary>
public static class PhoneNormalizer
{
    public static string Normalize(string? raw)
    {
        if (string.IsNullOrWhiteSpace(raw))
            return string.Empty;

        var sb = new StringBuilder(raw.Length);
        foreach (var ch in raw.Trim())
        {
            if (ch is ' ' or '-' or '(' or ')' or '.')
                continue;
            sb.Append(ch);
        }

        var s = sb.ToString();
        if (s.StartsWith("+351", StringComparison.Ordinal))
            s = s[4..];
        else if (s.StartsWith("00351", StringComparison.Ordinal))
            s = s[5..];

        return s;
    }

    public static bool Matches(string? input, string? tlmvl, string? telefone)
    {
        var want = Normalize(input);
        if (want.Length == 0)
            return false;

        var p1 = Normalize(tlmvl);
        if (p1.Length > 0)
            return string.Equals(want, p1, StringComparison.Ordinal);

        var p2 = Normalize(telefone);
        return p2.Length > 0 && string.Equals(want, p2, StringComparison.Ordinal);
    }
}
