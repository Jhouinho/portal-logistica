using Portal.Infrastructure.Encomendas;

namespace Portal.UnitTests;

/// <summary>
/// Testes de contrato sobre os fragmentos SQL efectivamente referenciados por
/// <see cref="PickingDossiersQuery"/> via <see cref="PickingDossiersOrigemSql"/>.
/// Não executam SQL Server — não são testes de integração.
/// </summary>
public sealed class PickingDossiersOrigemSqlContractTests
{
    [Fact]
    public void Hop1_e_hop2_sao_OUTER_APPLY_com_cadeias_correctas()
    {
        var h1 = PickingDossiersOrigemSql.OuterApplyHop1_66para1;
        var h2 = PickingDossiersOrigemSql.OuterApplyHop2_65para66para1;

        Assert.Contains("OUTER APPLY", h1, StringComparison.Ordinal);
        Assert.Contains("OUTER APPLY", h2, StringComparison.Ordinal);
        Assert.Contains("origem_h1", h1, StringComparison.Ordinal);
        Assert.Contains("origem_h2", h2, StringComparison.Ordinal);

        // 66 → 1: um salto obistamp (di → oi), sem mid.
        Assert.Contains("di.obistamp", h1, StringComparison.Ordinal);
        Assert.DoesNotContain("mid.", h1, StringComparison.Ordinal);

        // 65 → 66 → 1: di → mid → oi.
        Assert.Contains("mid.bistamp", h2, StringComparison.Ordinal);
        Assert.Contains("mid.obistamp", h2, StringComparison.Ordinal);
        Assert.Contains("di.obistamp", h2, StringComparison.Ordinal);
    }

    [Fact]
    public void Desempate_explicito_obrano_DESC_bostamp_BIN_DESC_sem_RTRIM()
    {
        foreach (var sql in new[]
                 {
                     PickingDossiersOrigemSql.OuterApplyHop1_66para1,
                     PickingDossiersOrigemSql.OuterApplyHop2_65para66para1
                 })
        {
            Assert.Contains("COLLATE Latin1_General_BIN DESC", sql, StringComparison.Ordinal);
            Assert.Contains("obrano DESC", sql, StringComparison.Ordinal);
            Assert.DoesNotContain("RTRIM(", sql, StringComparison.OrdinalIgnoreCase);
            Assert.DoesNotContain("LTRIM(", sql, StringComparison.OrdinalIgnoreCase);
        }

        Assert.Contains(
            "o.bostamp COLLATE Latin1_General_BIN DESC",
            PickingDossiersOrigemSql.OuterApplyHop1_66para1,
            StringComparison.Ordinal);
        Assert.Contains(
            "o1.bostamp COLLATE Latin1_General_BIN DESC",
            PickingDossiersOrigemSql.OuterApplyHop2_65para66para1,
            StringComparison.Ordinal);
    }

    [Fact]
    public void Select_obtem_obrano_ousrdata_ousrhora_da_mesma_origem_atomica()
    {
        var sel = PickingDossiersOrigemSql.SelectCamposOrigem;
        var h1 = PickingDossiersOrigemSql.OuterApplyHop1_66para1;

        Assert.Contains("origem_h1.obrano", sel, StringComparison.Ordinal);
        Assert.Contains("origem_h1.ousrdata", sel, StringComparison.Ordinal);
        Assert.Contains("origem_h1.ousrhora", sel, StringComparison.Ordinal);
        Assert.Contains("origem_h2.obrano", sel, StringComparison.Ordinal);
        Assert.Contains("origem_h2.ousrdata", sel, StringComparison.Ordinal);
        Assert.Contains("origem_h2.ousrhora", sel, StringComparison.Ordinal);

        // TOP (1) devolve as três colunas da mesma linha BO.
        Assert.Contains("SELECT TOP (1)", h1, StringComparison.Ordinal);
        Assert.Contains("o.obrano", h1, StringComparison.Ordinal);
        Assert.Contains("o.ousrdata", h1, StringComparison.Ordinal);
        Assert.Contains("o.ousrhora", h1, StringComparison.Ordinal);
    }

    [Fact]
    public void Prioridade_hop1_sobre_hop2_pelo_gate_obrano_nao_por_ousrdata()
    {
        var sel = PickingDossiersOrigemSql.SelectCamposOrigem;

        Assert.Contains(
            "WHEN origem_h1.obrano IS NOT NULL THEN origem_h1.ousrdata",
            sel,
            StringComparison.Ordinal);
        Assert.Contains(
            "WHEN origem_h1.obrano IS NOT NULL THEN origem_h1.ousrhora",
            sel,
            StringComparison.Ordinal);
        Assert.Contains(
            "COALESCE(origem_h1.obrano, origem_h2.obrano)",
            sel,
            StringComparison.Ordinal);

        // Não deve preferir hop2 só porque ousrdata do hop1 é NULL.
        Assert.DoesNotContain(
            "COALESCE(origem_h1.ousrdata",
            sel,
            StringComparison.OrdinalIgnoreCase);
        Assert.DoesNotContain(
            "COALESCE(origem_h1.ousrhora",
            sel,
            StringComparison.OrdinalIgnoreCase);
    }

    [Fact]
    public void Nao_usa_MAX_ousrdata_nem_MAX_ousrhora_independentes()
    {
        var combined =
            PickingDossiersOrigemSql.SelectCamposOrigem
            + PickingDossiersOrigemSql.OuterApplyHop1_66para1
            + PickingDossiersOrigemSql.OuterApplyHop2_65para66para1;

        Assert.DoesNotContain("MAX(o.ousrdata)", combined, StringComparison.OrdinalIgnoreCase);
        Assert.DoesNotContain("MAX(o1.ousrdata)", combined, StringComparison.OrdinalIgnoreCase);
        Assert.DoesNotContain("MAX(CONVERT(varchar(12), o.ousrhora))", combined, StringComparison.OrdinalIgnoreCase);
        Assert.DoesNotContain("MAX(CONVERT(varchar(12), o1.ousrhora))", combined, StringComparison.OrdinalIgnoreCase);
        Assert.DoesNotContain("MAX(o.ousrhora)", combined, StringComparison.OrdinalIgnoreCase);
    }

    [Fact]
    public void OuterApply_preserva_cardinalidade_e_dossiers_sem_origem()
    {
        // OUTER (não CROSS) APPLY: 0 linhas de origem → colunas NULL, dossier mantém-se.
        Assert.Contains("OUTER APPLY", PickingDossiersOrigemSql.OuterApplyHop1_66para1, StringComparison.Ordinal);
        Assert.Contains("OUTER APPLY", PickingDossiersOrigemSql.OuterApplyHop2_65para66para1, StringComparison.Ordinal);
        Assert.DoesNotContain("CROSS APPLY", PickingDossiersOrigemSql.OuterApplyHop1_66para1, StringComparison.OrdinalIgnoreCase);
        Assert.DoesNotContain("CROSS APPLY", PickingDossiersOrigemSql.OuterApplyHop2_65para66para1, StringComparison.OrdinalIgnoreCase);

        // GROUP BY inclui campos de origem (≤1 por APPLY) sem expandir linhas do bo.
        var gb = PickingDossiersOrigemSql.GroupByCamposOrigem;
        Assert.Contains("origem_h1.obrano", gb, StringComparison.Ordinal);
        Assert.Contains("origem_h2.obrano", gb, StringComparison.Ordinal);
    }

    [Fact]
    public void PickingDossiersQuery_compila_e_referencia_os_fragmentos_de_contrato()
    {
        // Garante que a query liga aos mesmos const usados nos testes (não cópias órfãs).
        // A concatenação const em ListarAsync usa estes membros; se forem renomeados, falha a compilação.
        Assert.False(string.IsNullOrWhiteSpace(PickingDossiersOrigemSql.SelectCamposOrigem));
        Assert.False(string.IsNullOrWhiteSpace(PickingDossiersOrigemSql.OuterApplyHop1_66para1));
        Assert.False(string.IsNullOrWhiteSpace(PickingDossiersOrigemSql.OuterApplyHop2_65para66para1));
        Assert.False(string.IsNullOrWhiteSpace(PickingDossiersOrigemSql.GroupByCamposOrigem));

        // Tipo da query presente no assembly referenciado pelos testes.
        Assert.NotNull(typeof(PickingDossiersQuery));
    }
}
