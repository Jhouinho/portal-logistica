using Portal.Application.Realtime;

namespace Portal.UnitTests;

public sealed class ExternalChangeCycleLogicTests
{
    private static BoBiCursor Bo(string date, string hora, string key) =>
        new(DateTime.Parse(date), hora, key);

    private static KappsCursor Kapps(string d, string t, string bo, string bi) =>
        new(d, t, bo, bi);

    private static ExternalChangeWatermarks Known(
        BoBiCursor? bo1 = null,
        BoBiCursor? bi1 = null,
        BoBiCursor? bo66 = null,
        BoBiCursor? bi66 = null,
        BoBiCursor? bo65 = null,
        BoBiCursor? bi65 = null,
        KappsCursor? kapps = null) =>
        new()
        {
            IsInitialized = true,
            Bo1 = bo1,
            Bi1 = bi1,
            Bo66 = bo66,
            Bi66 = bi66,
            Bo65 = bo65,
            Bi65 = bi65,
            Kapps = kapps,
        };

    private static ExternalChangeSnapshot Snap(
        BoBiCursor? bo1 = null,
        BoBiCursor? bi1 = null,
        BoBiCursor? bo66 = null,
        BoBiCursor? bi66 = null,
        BoBiCursor? bo65 = null,
        BoBiCursor? bi65 = null,
        KappsCursor? kapps = null) =>
        new()
        {
            Bo1 = bo1,
            Bi1 = bi1,
            Bo66 = bo66,
            Bi66 = bi66,
            Bo65 = bo65,
            Bi65 = bi65,
            Kapps = kapps,
        };

    private static ExternalChangeDetectionResult FromSnap(
        ExternalChangeWatermarks? known,
        ExternalChangeSnapshot snap) =>
        ExternalChangeDetector.DetectFromSnapshot(known, snap);

    [Fact]
    public void Cold_start_nao_planeia_publicacoes()
    {
        var snap = Snap(bo66: Bo("2026-09-29", "10:00:00", "A"));
        var detection = FromSnap(ExternalChangeWatermarks.Uninitialized, snap);
        Assert.True(detection.WasColdStart);
        Assert.Empty(ExternalChangeCycleLogic.PlanPublishes(detection));
    }

    [Fact]
    public void Bo1_avancou_publica_encomenda()
    {
        var known = Known(bo1: Bo("2026-09-29", "10:00:00", "A"));
        var detection = FromSnap(known, Snap(bo1: Bo("2026-09-29", "11:00:00", "B")));
        Assert.Equal(
            [ExternalRealtimeUniverse.Encomenda],
            ExternalChangeCycleLogic.PlanPublishes(detection));
    }

    [Fact]
    public void Bi1_avancou_publica_encomenda()
    {
        var known = Known(bi1: Bo("2026-09-29", "10:00:00", "A"));
        var detection = FromSnap(known, Snap(bi1: Bo("2026-09-29", "10:05:00", "B")));
        Assert.Equal(
            [ExternalRealtimeUniverse.Encomenda],
            ExternalChangeCycleLogic.PlanPublishes(detection));
    }

    [Fact]
    public void Bo66_avancou_publica_dossier66()
    {
        var known = Known(bo66: Bo("2026-09-29", "10:00:00", "A"));
        var detection = FromSnap(known, Snap(bo66: Bo("2026-09-29", "11:00:00", "B")));
        Assert.Equal(
            [ExternalRealtimeUniverse.Dossier66],
            ExternalChangeCycleLogic.PlanPublishes(detection));
    }

    [Fact]
    public void Bi66_avancou_publica_dossier66()
    {
        var known = Known(bi66: Bo("2026-09-29", "10:00:00", "A"));
        var detection = FromSnap(known, Snap(bi66: Bo("2026-09-29", "10:05:00", "B")));
        Assert.Equal(
            [ExternalRealtimeUniverse.Dossier66],
            ExternalChangeCycleLogic.PlanPublishes(detection));
    }

    [Fact]
    public void Bo66_e_Bi66_publicam_dossier66_uma_vez()
    {
        var known = Known(
            bo66: Bo("2026-09-29", "10:00:00", "A"),
            bi66: Bo("2026-09-29", "10:00:00", "X"));
        var detection = FromSnap(known, Snap(
            bo66: Bo("2026-09-29", "11:00:00", "B"),
            bi66: Bo("2026-09-29", "11:00:00", "Y")));
        var plan = ExternalChangeCycleLogic.PlanPublishes(detection);
        Assert.Single(plan);
        Assert.Equal(ExternalRealtimeUniverse.Dossier66, plan[0]);
    }

    [Fact]
    public void Bo65_avancou_publica_dossier65()
    {
        var known = Known(bo65: Bo("2026-09-29", "10:00:00", "A"));
        var detection = FromSnap(known, Snap(bo65: Bo("2026-09-29", "12:00:00", "B")));
        Assert.Equal(
            [ExternalRealtimeUniverse.Dossier65],
            ExternalChangeCycleLogic.PlanPublishes(detection));
    }

    [Fact]
    public void Bi65_avancou_publica_dossier65()
    {
        var known = Known(bi65: Bo("2026-09-29", "10:00:00", "A"));
        var detection = FromSnap(known, Snap(bi65: Bo("2026-09-29", "10:01:00", "B")));
        Assert.Equal(
            [ExternalRealtimeUniverse.Dossier65],
            ExternalChangeCycleLogic.PlanPublishes(detection));
    }

    [Fact]
    public void Kapps_avancou_publica_kapps()
    {
        var known = Known(kapps: Kapps("20260929", "100000", "Bo", "Bi"));
        var detection = FromSnap(known, Snap(kapps: Kapps("20260929", "122011", "Bo2", "Bi2")));
        Assert.Equal(
            [ExternalRealtimeUniverse.Kapps],
            ExternalChangeCycleLogic.PlanPublishes(detection));
    }

    [Fact]
    public void Sem_avanco_nao_publica()
    {
        var cursor = Bo("2026-09-29", "10:00:00", "A");
        var known = Known(bo66: cursor);
        var detection = FromSnap(known, Snap(bo66: cursor));
        Assert.Empty(ExternalChangeCycleLogic.PlanPublishes(detection));
    }

    [Fact]
    public void SignalR_falha_nao_avanca_cursor_desse_universo()
    {
        var knownBo = Bo("2026-09-29", "10:00:00", "A");
        var known = Known(bo66: knownBo);
        var detection = FromSnap(known, Snap(bo66: Bo("2026-09-29", "11:00:00", "B")));

        var merged = ExternalChangeCycleLogic.MergeAfterPublish(
            known,
            detection,
            publishedOk: new HashSet<ExternalRealtimeUniverse>());

        Assert.Equal(knownBo, merged.Bo66);
        Assert.True(detection.Bo66Advanced);
    }

    [Fact]
    public void Proximo_ciclo_apos_falha_ainda_ve_avanco()
    {
        var knownBo = Bo("2026-09-29", "10:00:00", "A");
        var observed = Bo("2026-09-29", "11:00:00", "B");
        var known = Known(bo66: knownBo);
        var snap = Snap(bo66: observed);

        var detection1 = FromSnap(known, snap);
        var afterFail = ExternalChangeCycleLogic.MergeAfterPublish(
            known,
            detection1,
            new HashSet<ExternalRealtimeUniverse>());

        var detection2 = FromSnap(afterFail, snap);
        Assert.True(detection2.Bo66Advanced);
        Assert.Contains(
            ExternalRealtimeUniverse.Dossier66,
            ExternalChangeCycleLogic.PlanPublishes(detection2));
    }

    [Fact]
    public void Falha_parcial_avanca_apenas_universo_ok()
    {
        var known = Known(
            bo66: Bo("2026-09-29", "10:00:00", "A66"),
            bo65: Bo("2026-09-29", "10:00:00", "A65"));
        var detection = FromSnap(known, Snap(
            bo66: Bo("2026-09-29", "11:00:00", "B66"),
            bo65: Bo("2026-09-29", "11:00:00", "B65")));

        var merged = ExternalChangeCycleLogic.MergeAfterPublish(
            known,
            detection,
            new HashSet<ExternalRealtimeUniverse> { ExternalRealtimeUniverse.Dossier66 });

        Assert.Equal("B66", merged.Bo66!.NormalizedKey);
        Assert.Equal("A65", merged.Bo65!.NormalizedKey);
    }

    [Fact]
    public void Regressao_nao_recua_mesmo_com_merge()
    {
        var knownCursor = Bo("2026-09-29", "12:00:00", "Z");
        var known = Known(bo66: knownCursor);
        var detection = FromSnap(known, Snap(bo66: Bo("2026-09-29", "11:00:00", "A")));

        Assert.True(detection.Bo66Regressed);
        var merged = ExternalChangeCycleLogic.MergeAfterPublish(
            known,
            detection,
            new HashSet<ExternalRealtimeUniverse>());
        Assert.Equal(knownCursor, merged.Bo66);
    }

    [Fact]
    public void Publish_ok_avanca_ambos_cursores_66()
    {
        var known = Known(
            bo66: Bo("2026-09-29", "10:00:00", "A"),
            bi66: Bo("2026-09-29", "10:00:00", "X"));
        var detection = FromSnap(known, Snap(
            bo66: Bo("2026-09-29", "11:00:00", "B"),
            bi66: Bo("2026-09-29", "11:00:00", "Y")));

        var merged = ExternalChangeCycleLogic.MergeAfterPublish(
            known,
            detection,
            new HashSet<ExternalRealtimeUniverse> { ExternalRealtimeUniverse.Dossier66 });

        Assert.Equal("B", merged.Bo66!.NormalizedKey);
        Assert.Equal("Y", merged.Bi66!.NormalizedKey);
    }

    [Fact]
    public void Publish_ok_avanca_cursores_encomenda()
    {
        var known = Known(
            bo1: Bo("2026-09-29", "10:00:00", "A"),
            bi1: Bo("2026-09-29", "10:00:00", "X"));
        var detection = FromSnap(known, Snap(
            bo1: Bo("2026-09-29", "11:00:00", "B"),
            bi1: Bo("2026-09-29", "11:00:00", "Y")));

        var merged = ExternalChangeCycleLogic.MergeAfterPublish(
            known,
            detection,
            new HashSet<ExternalRealtimeUniverse> { ExternalRealtimeUniverse.Encomenda });

        Assert.Equal("B", merged.Bo1!.NormalizedKey);
        Assert.Equal("Y", merged.Bi1!.NormalizedKey);
    }
}
