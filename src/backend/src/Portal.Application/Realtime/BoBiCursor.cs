namespace Portal.Application.Realtime;

/// <summary>
/// Cursor lexicográfico BO/BI: (usrdata, usrhora, chave).
/// <para>
/// Limitação conhecida: resolve empates entre linhas diferentes; não distingue
/// duas alterações da mesma linha no mesmo segundo se usrdata/usrhora não mudarem.
/// </para>
/// </summary>
public sealed record BoBiCursor(
    DateTime UsrData,
    string UsrHora,
    string Key)
{
    public string NormalizedHora => NormalizeHora(UsrHora);

    public string NormalizedKey => (Key ?? string.Empty).Trim();

    public static string NormalizeHora(string? hora) =>
        string.IsNullOrWhiteSpace(hora) ? string.Empty : hora.Trim();
}
