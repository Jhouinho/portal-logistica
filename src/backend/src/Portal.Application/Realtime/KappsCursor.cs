namespace Portal.Application.Realtime;

/// <summary>
/// Cursor lexicográfico Kapps (u_Kapps_DossierLin): (MovDate, MovTime, StampBo, StampBi).
/// MovDate/MovTime são nvarchar no PHC (ex. 20260929 / 122011); comparação ordinal.
/// </summary>
public sealed record KappsCursor(
    string MovDate,
    string MovTime,
    string StampBo,
    string StampBi)
{
    public string NormalizedMovDate => Normalize(MovDate);

    public string NormalizedMovTime => Normalize(MovTime);

    public string NormalizedStampBo => Normalize(StampBo);

    public string NormalizedStampBi => Normalize(StampBi);

    public static string Normalize(string? value) =>
        string.IsNullOrWhiteSpace(value) ? string.Empty : value.Trim();
}
