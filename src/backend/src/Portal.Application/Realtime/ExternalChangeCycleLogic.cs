namespace Portal.Application.Realtime;

/// <summary>
/// Universos de invalidação realtime (mapeados para eventos SignalR na Api).
/// Sem payload / IDs — apenas invalidação.
/// </summary>
public enum ExternalRealtimeUniverse
{
    Encomenda = 1,
    Dossier66 = 2,
    Dossier65 = 3,
    Kapps = 4,
}

/// <summary>
/// Orquestração testável: planear publicações e avançar watermarks só após sucesso por universo.
/// </summary>
public static class ExternalChangeCycleLogic
{
    public static IReadOnlyList<ExternalRealtimeUniverse> PlanPublishes(ExternalChangeDetectionResult detection)
    {
        if (detection.WasColdStart)
            return Array.Empty<ExternalRealtimeUniverse>();

        var plan = new List<ExternalRealtimeUniverse>(4);
        if (detection.Bo1Advanced || detection.Bi1Advanced)
            plan.Add(ExternalRealtimeUniverse.Encomenda);
        if (detection.Bo66Advanced || detection.Bi66Advanced)
            plan.Add(ExternalRealtimeUniverse.Dossier66);
        if (detection.Bo65Advanced || detection.Bi65Advanced)
            plan.Add(ExternalRealtimeUniverse.Dossier65);
        if (detection.KappsAdvanced)
            plan.Add(ExternalRealtimeUniverse.Kapps);
        return plan;
    }

    /// <summary>
    /// Avança apenas os cursores cujo universo foi publicado com sucesso.
    /// Universos com falha de publish mantêm o watermark anterior (re-detecção no próximo ciclo).
    /// </summary>
    public static ExternalChangeWatermarks MergeAfterPublish(
        ExternalChangeWatermarks known,
        ExternalChangeDetectionResult detection,
        IReadOnlySet<ExternalRealtimeUniverse> publishedOk)
    {
        if (detection.WasColdStart)
            return detection.NextWatermarks;

        var next = detection.NextWatermarks;
        var needs1 = detection.Bo1Advanced || detection.Bi1Advanced;
        var needs66 = detection.Bo66Advanced || detection.Bi66Advanced;
        var needs65 = detection.Bo65Advanced || detection.Bi65Advanced;
        var needsKapps = detection.KappsAdvanced;
        var ok1 = publishedOk.Contains(ExternalRealtimeUniverse.Encomenda);
        var ok66 = publishedOk.Contains(ExternalRealtimeUniverse.Dossier66);
        var ok65 = publishedOk.Contains(ExternalRealtimeUniverse.Dossier65);
        var okKapps = publishedOk.Contains(ExternalRealtimeUniverse.Kapps);

        return new ExternalChangeWatermarks
        {
            IsInitialized = true,
            Bo1 = needs1 ? (ok1 ? next.Bo1 : known.Bo1) : next.Bo1,
            Bi1 = needs1 ? (ok1 ? next.Bi1 : known.Bi1) : next.Bi1,
            Bo66 = needs66 ? (ok66 ? next.Bo66 : known.Bo66) : next.Bo66,
            Bi66 = needs66 ? (ok66 ? next.Bi66 : known.Bi66) : next.Bi66,
            Bo65 = needs65 ? (ok65 ? next.Bo65 : known.Bo65) : next.Bo65,
            Bi65 = needs65 ? (ok65 ? next.Bi65 : known.Bi65) : next.Bi65,
            Kapps = needsKapps ? (okKapps ? next.Kapps : known.Kapps) : next.Kapps,
        };
    }

    public static string DescribeUniverse(ExternalRealtimeUniverse universe) =>
        universe switch
        {
            ExternalRealtimeUniverse.Encomenda => "encomenda",
            ExternalRealtimeUniverse.Dossier66 => "dossier66",
            ExternalRealtimeUniverse.Dossier65 => "dossier65",
            ExternalRealtimeUniverse.Kapps => "kapps",
            _ => universe.ToString(),
        };
}
