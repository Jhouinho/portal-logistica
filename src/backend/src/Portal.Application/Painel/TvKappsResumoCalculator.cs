namespace Portal.Application.Painel;

/// <summary>
/// Espelha <c>kappsTotais</c> / <c>kappsVisual</c> do frontend sobre agregados qty/picked/pending.
/// </summary>
public static class TvKappsResumoCalculator
{
    public const string KindEspera = "espera";
    public const string KindCurso = "curso";
    public const string KindConcluido = "concluido";

    public static (string Kind, int Pct) FromTotais(decimal qty, decimal picked, decimal pending)
    {
        var total = qty;
        var recolhido = picked;
        var concluido = total > 0 && pending <= 0;
        var emCurso = !concluido && recolhido > 0 && recolhido < total;
        var kind = concluido ? KindConcluido : emCurso ? KindCurso : KindEspera;
        var pct = total > 0
            ? Math.Max(0, Math.Min(100, (int)Math.Round(recolhido / total * 100m, MidpointRounding.AwayFromZero)))
            : 0;
        if (concluido)
            pct = 100;
        return (kind, pct);
    }

    public static TvKappsResumoItemDto ToItem(TvKappsResumoRow row)
    {
        var (kind, pct) = FromTotais(row.Qty, row.Picked, row.Pending);
        var terminalLabel = string.IsNullOrWhiteSpace(row.ActiveTerminalLabel)
            ? null
            : row.ActiveTerminalLabel.Trim();
        var userId = string.IsNullOrWhiteSpace(row.ActiveUserId)
            ? null
            : row.ActiveUserId.Trim();

        return new TvKappsResumoItemDto(
            row.BoStamp.Trim(),
            row.Origem.Trim(),
            row.Qty,
            row.Picked,
            row.Pending,
            kind,
            pct,
            row.ActiveTerminalId is > 0 ? row.ActiveTerminalId : null,
            terminalLabel,
            userId);
    }
}
