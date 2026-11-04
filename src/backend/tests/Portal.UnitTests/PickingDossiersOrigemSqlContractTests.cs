using Portal.Infrastructure.Encomendas;

namespace Portal.UnitTests;

/// <summary>
/// Testes de contrato — hotfix origem NULL (sem APPLY / hops activos no SELECT).
/// </summary>
public sealed class PickingDossiersOrigemSqlContractTests
{
    [Fact]
    public void Select_hotfix_origem_null_sem_APPLY()
    {
        var sel = PickingDossiersOrigemSql.SelectCamposOrigem;
        Assert.Contains("CAST(NULL AS int) AS obrano_origem", sel, StringComparison.Ordinal);
        Assert.Contains("ousrdata_origem", sel, StringComparison.Ordinal);
        Assert.Contains("ousrhora_origem", sel, StringComparison.Ordinal);
        Assert.DoesNotContain("APPLY", sel, StringComparison.OrdinalIgnoreCase);
        Assert.DoesNotContain("ORDER BY", sel, StringComparison.OrdinalIgnoreCase);
        Assert.DoesNotContain("SELECT MAX", sel, StringComparison.OrdinalIgnoreCase);
    }

    [Fact]
    public void Concat_apos_comentario_SQL_nao_engole_CAST()
    {
        // Raw string omite newline antes do """ final → CAST cola na linha do "--".
        const string prefix = """
                    bo.obrano,
                    -- comentario perigoso.
            """;
        var glued = prefix + PickingDossiersOrigemSql.SelectCamposOrigem;
        Assert.Contains("-- comentario perigoso.CAST", glued, StringComparison.Ordinal);

        var safe = prefix + "\n" + PickingDossiersOrigemSql.SelectCamposOrigem;
        Assert.DoesNotContain("-- comentario perigoso.CAST", safe, StringComparison.Ordinal);
        Assert.Contains("\nCAST(NULL AS int) AS obrano_origem", safe, StringComparison.Ordinal);
    }

    [Fact]
    public void OuterApply_vazio()
    {
        Assert.True(string.IsNullOrEmpty(PickingDossiersOrigemSql.OuterApplyHop1_66para1));
        Assert.True(string.IsNullOrEmpty(PickingDossiersOrigemSql.OuterApplyHop2_65para66para1));
    }

    [Fact]
    public void Hop_contratos_preservam_cadeias()
    {
        var h1 = PickingDossiersOrigemSql.Hop1SqlContrato;
        var h2 = PickingDossiersOrigemSql.Hop2SqlContrato;
        Assert.Contains("di.obistamp", h1, StringComparison.Ordinal);
        Assert.DoesNotContain("mid.", h1, StringComparison.Ordinal);
        Assert.Contains("mid.bistamp", h2, StringComparison.Ordinal);
    }

    [Fact]
    public void PickingDossiersQuery_compila()
    {
        Assert.False(string.IsNullOrWhiteSpace(PickingDossiersOrigemSql.SelectCamposOrigem));
        Assert.NotNull(typeof(PickingDossiersQuery));
    }
}
