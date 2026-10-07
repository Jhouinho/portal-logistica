using Portal.Application.Realtime;

namespace Portal.UnitTests;

/// <summary>
/// Testes da comparação lexicográfica e do cold start do ExternalChangeDetector (Etapa 1).
/// Limitação documentada: (data,hora,chave) não distingue duas alterações da mesma linha
/// no mesmo segundo se usrdata/usrhora não mudarem.
/// </summary>
public sealed class ExternalChangeDetectorTests
{
    private static BoBiCursor Bo(string date, string hora, string key) =>
        new(DateTime.Parse(date), hora, key);

    private static KappsCursor Kapps(string movDate, string movTime, string stampBo, string stampBi) =>
        new(movDate, movTime, stampBo, stampBi);

    private static ExternalChangeWatermarks Initialized(
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

    private static ExternalChangeSnapshot Snapshot(
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

    [Fact]
    public void Compare_BoBi_iguais_Unchanged()
    {
        var a = Bo("2026-09-29", "10:50:17", "Syslog_A");
        Assert.Equal(CursorChangeKind.Unchanged, CursorComparison.Compare(a, a));
    }

    [Fact]
    public void Compare_BoBi_data_maior_Advanced()
    {
        var known = Bo("2026-09-28", "23:59:59", "Z");
        var observed = Bo("2026-09-29", "00:00:00", "A");
        Assert.Equal(CursorChangeKind.Advanced, CursorComparison.Compare(known, observed));
    }

    [Fact]
    public void Compare_BoBi_hora_maior_Advanced()
    {
        var known = Bo("2026-09-29", "10:50:16", "Same");
        var observed = Bo("2026-09-29", "10:50:17", "Same");
        Assert.Equal(CursorChangeKind.Advanced, CursorComparison.Compare(known, observed));
    }

    [Fact]
    public void Compare_BoBi_chave_maior_mesma_data_hora_Advanced()
    {
        var known = Bo("2026-09-29", "10:50:17", "AAA");
        var observed = Bo("2026-09-29", "10:50:17", "BBB");
        Assert.Equal(CursorChangeKind.Advanced, CursorComparison.Compare(known, observed));
    }

    [Fact]
    public void Compare_BoBi_chave_menor_mesma_data_hora_Regressed()
    {
        var known = Bo("2026-09-29", "10:50:17", "BBB");
        var observed = Bo("2026-09-29", "10:50:17", "AAA");
        Assert.Equal(CursorChangeKind.Regressed, CursorComparison.Compare(known, observed));
    }

    [Fact]
    public void Compare_BoBi_data_menor_Regressed()
    {
        var known = Bo("2026-09-29", "10:00:00", "A");
        var observed = Bo("2026-09-28", "23:59:59", "Z");
        Assert.Equal(CursorChangeKind.Regressed, CursorComparison.Compare(known, observed));
    }

    [Fact]
    public void Compare_BoBi_empate_completo_Unchanged()
    {
        var known = Bo("2026-09-29", "10:50:17", " Syslog_X ");
        var observed = Bo("2026-09-29", "10:50:17", "Syslog_X");
        Assert.Equal(CursorChangeKind.Unchanged, CursorComparison.Compare(known, observed));
    }

    [Fact]
    public void Detect_cold_start_inicializa_sem_alteracao()
    {
        var snap = Snapshot(
            bo1: Bo("2026-09-29", "09:00:00", "Bo1"),
            bi1: Bo("2026-09-29", "09:01:00", "Bi1"),
            bo66: Bo("2026-09-29", "10:50:17", "Bo66"),
            bi66: Bo("2026-09-29", "10:51:00", "Bi66"),
            bo65: Bo("2026-09-29", "11:00:00", "Bo65"),
            bi65: Bo("2026-09-29", "11:01:00", "Bi65"),
            kapps: Kapps("20260929", "122011", "StampBo", "StampBi"));

        var result = ExternalChangeDetector.DetectFromSnapshot(
            ExternalChangeWatermarks.Uninitialized,
            snap);

        Assert.True(result.WasColdStart);
        Assert.False(result.AnyAdvanced);
        Assert.False(result.AnyRegressed);
        Assert.True(result.NextWatermarks.IsInitialized);
        Assert.Equal("Bo1", result.NextWatermarks.Bo1!.NormalizedKey);
        Assert.Equal("Bi1", result.NextWatermarks.Bi1!.NormalizedKey);
        Assert.Equal("Bo66", result.NextWatermarks.Bo66!.NormalizedKey);
        Assert.Equal("Bi66", result.NextWatermarks.Bi66!.NormalizedKey);
        Assert.Equal("Bo65", result.NextWatermarks.Bo65!.NormalizedKey);
        Assert.Equal("Bi65", result.NextWatermarks.Bi65!.NormalizedKey);
        Assert.Equal("StampBo", result.NextWatermarks.Kapps!.NormalizedStampBo);
    }

    [Fact]
    public void Detect_Bo1_avancou()
    {
        var known = Initialized(bo1: Bo("2026-09-29", "10:00:00", "Bo1"));
        var snap = Snapshot(bo1: Bo("2026-09-29", "10:05:00", "Bo1Novo"));
        var result = ExternalChangeDetector.DetectFromSnapshot(known, snap);
        Assert.True(result.Bo1Advanced);
        Assert.Equal("Bo1Novo", result.NextWatermarks.Bo1!.NormalizedKey);
    }

    [Fact]
    public void Detect_Bo66_e_Bi66_independentes()
    {
        var known = Initialized(
            bo66: Bo("2026-09-29", "10:00:00", "Bo66"),
            bi66: Bo("2026-09-29", "10:00:00", "Bi66"));

        var snap = Snapshot(
            bo66: Bo("2026-09-29", "10:00:00", "Bo66"),
            bi66: Bo("2026-09-29", "10:05:00", "Bi66Novo"));

        var result = ExternalChangeDetector.DetectFromSnapshot(known, snap);

        Assert.False(result.WasColdStart);
        Assert.False(result.Bo66Advanced);
        Assert.True(result.Bi66Advanced);
        Assert.Equal("Bi66Novo", result.NextWatermarks.Bi66!.NormalizedKey);
        Assert.Equal("Bo66", result.NextWatermarks.Bo66!.NormalizedKey);
    }

    [Fact]
    public void Detect_Bo65_e_Bi65_independentes()
    {
        var known = Initialized(
            bo65: Bo("2026-09-29", "10:00:00", "Bo65"),
            bi65: Bo("2026-09-29", "10:00:00", "Bi65"));

        var snap = Snapshot(
            bo65: Bo("2026-09-29", "12:00:00", "Bo65Novo"),
            bi65: Bo("2026-09-29", "10:00:00", "Bi65"));

        var result = ExternalChangeDetector.DetectFromSnapshot(known, snap);

        Assert.True(result.Bo65Advanced);
        Assert.False(result.Bi65Advanced);
        Assert.Equal("Bo65Novo", result.NextWatermarks.Bo65!.NormalizedKey);
    }

    [Fact]
    public void Detect_regressao_nao_recua_cursor()
    {
        var knownCursor = Bo("2026-09-29", "12:00:00", "Z");
        var known = Initialized(bo66: knownCursor);
        var snap = Snapshot(bo66: Bo("2026-09-29", "11:00:00", "A"));

        var result = ExternalChangeDetector.DetectFromSnapshot(known, snap);

        Assert.True(result.Bo66Regressed);
        Assert.False(result.Bo66Advanced);
        Assert.Equal(knownCursor, result.NextWatermarks.Bo66);
    }

    [Fact]
    public void Compare_Kapps_MovDate_maior_Advanced()
    {
        var known = Kapps("20260928", "235959", "Z", "Z");
        var observed = Kapps("20260929", "000001", "A", "A");
        Assert.Equal(CursorChangeKind.Advanced, CursorComparison.Compare(known, observed));
    }

    [Fact]
    public void Compare_Kapps_MovTime_maior_Advanced()
    {
        var known = Kapps("20260929", "122010", "Same", "Same");
        var observed = Kapps("20260929", "122011", "Same", "Same");
        Assert.Equal(CursorChangeKind.Advanced, CursorComparison.Compare(known, observed));
    }

    [Fact]
    public void Compare_Kapps_StampBo_maior_mesmo_timestamp_Advanced()
    {
        var known = Kapps("20260929", "122011", "AAA", "ZZZ");
        var observed = Kapps("20260929", "122011", "BBB", "AAA");
        Assert.Equal(CursorChangeKind.Advanced, CursorComparison.Compare(known, observed));
    }

    [Fact]
    public void Compare_Kapps_StampBi_maior_quando_anteriores_empatam_Advanced()
    {
        var known = Kapps("20260929", "122011", "SameBo", "AAA");
        var observed = Kapps("20260929", "122011", "SameBo", "BBB");
        Assert.Equal(CursorChangeKind.Advanced, CursorComparison.Compare(known, observed));
    }

    [Fact]
    public void Compare_Kapps_iguais_Unchanged()
    {
        var a = Kapps("20260929", "122011", "Bo", "Bi");
        Assert.Equal(CursorChangeKind.Unchanged, CursorComparison.Compare(a, a));
    }
}
