namespace Portal.Application.Realtime;

/// <summary>Resultado da comparação lexicográfica de dois cursores.</summary>
public enum CursorChangeKind
{
    /// <summary>Cursores iguais (ou ambos ausentes).</summary>
    Unchanged = 0,

    /// <summary>O cursor observado é estritamente maior que o conhecido.</summary>
    Advanced = 1,

    /// <summary>O cursor observado é estritamente menor — anomalia; não recuar.</summary>
    Regressed = 2,
}

/// <summary>
/// Comparação lexicográfica determinística dos watermarks.
/// Não concatena data+hora numa única string para ordenar.
/// </summary>
public static class CursorComparison
{
    public static CursorChangeKind Compare(BoBiCursor? known, BoBiCursor? observed)
    {
        if (known is null && observed is null)
            return CursorChangeKind.Unchanged;
        if (known is null)
            return CursorChangeKind.Advanced;
        if (observed is null)
            return CursorChangeKind.Regressed;

        var byDate = known.UsrData.Date.CompareTo(observed.UsrData.Date);
        if (byDate < 0)
            return CursorChangeKind.Advanced;
        if (byDate > 0)
            return CursorChangeKind.Regressed;

        var byHora = string.CompareOrdinal(known.NormalizedHora, observed.NormalizedHora);
        if (byHora < 0)
            return CursorChangeKind.Advanced;
        if (byHora > 0)
            return CursorChangeKind.Regressed;

        var byKey = string.CompareOrdinal(known.NormalizedKey, observed.NormalizedKey);
        if (byKey < 0)
            return CursorChangeKind.Advanced;
        if (byKey > 0)
            return CursorChangeKind.Regressed;

        return CursorChangeKind.Unchanged;
    }

    public static CursorChangeKind Compare(KappsCursor? known, KappsCursor? observed)
    {
        if (known is null && observed is null)
            return CursorChangeKind.Unchanged;
        if (known is null)
            return CursorChangeKind.Advanced;
        if (observed is null)
            return CursorChangeKind.Regressed;

        var byDate = string.CompareOrdinal(known.NormalizedMovDate, observed.NormalizedMovDate);
        if (byDate < 0)
            return CursorChangeKind.Advanced;
        if (byDate > 0)
            return CursorChangeKind.Regressed;

        var byTime = string.CompareOrdinal(known.NormalizedMovTime, observed.NormalizedMovTime);
        if (byTime < 0)
            return CursorChangeKind.Advanced;
        if (byTime > 0)
            return CursorChangeKind.Regressed;

        var byBo = string.CompareOrdinal(known.NormalizedStampBo, observed.NormalizedStampBo);
        if (byBo < 0)
            return CursorChangeKind.Advanced;
        if (byBo > 0)
            return CursorChangeKind.Regressed;

        var byBi = string.CompareOrdinal(known.NormalizedStampBi, observed.NormalizedStampBi);
        if (byBi < 0)
            return CursorChangeKind.Advanced;
        if (byBi > 0)
            return CursorChangeKind.Regressed;

        return CursorChangeKind.Unchanged;
    }
}
