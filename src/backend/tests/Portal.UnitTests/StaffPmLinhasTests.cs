using Portal.Application.Cliente;

namespace Portal.UnitTests;

public class StaffPmLinhasTests
{
    [Fact]
    public void ValidateLinhasOperador_exige_pelo_menos_uma()
    {
        Assert.NotNull(StaffPmPrecoRules.ValidateLinhasOperador([]));
    }

    [Fact]
    public void ValidateLinhasOperador_rejeita_qtt_fracionaria_ou_zero()
    {
        var baseOk = new StaffPmLinhaEditRequest(1, "1051", "A", "", 1m, 1m);
        Assert.NotNull(StaffPmPrecoRules.ValidateLinhasOperador(
            [baseOk with { Qtt = 0 }]));
        Assert.NotNull(StaffPmPrecoRules.ValidateLinhasOperador(
            [baseOk with { Qtt = 1.5m }]));
    }

    [Fact]
    public void ValidateLinhasOperador_ok()
    {
        Assert.Null(StaffPmPrecoRules.ValidateLinhasOperador(
        [
            new StaffPmLinhaEditRequest(1, "1051", "Celosia", "vermelho", 2m, 9.5m),
            new StaffPmLinhaEditRequest(null, "1052", "Nova", "", 1m, 3m)
        ]));
    }

    [Fact]
    public void BuildLinhasSubstituicao_preserva_preco_submissao_e_renumerada()
    {
        var existentes = new[]
        {
            new ClientePmLinhaPersistida(1, "1051", "A", "azul", 2m, 1.5m, 3m, 1.5m),
            new ClientePmLinhaPersistida(2, "1052", "B", "", 1m, 4m, 4m, 4m)
        };

        var built = StaffPmPrecoRules.BuildLinhasSubstituicao(
            existentes,
            [
                new StaffPmLinhaEditRequest(1, "1051", "A", "azul", 5m, 9.5m),
                new StaffPmLinhaEditRequest(null, "1099", "Nova", "rosa", 1m, 2m)
            ]);

        Assert.Equal(2, built.Count);
        Assert.Equal(1, built[0].LinhaOrd);
        Assert.Equal(5m, built[0].Qtt);
        Assert.Equal(9.5m, built[0].PrecoUnitario);
        Assert.Equal(1.5m, built[0].PrecoSubmissao);
        Assert.Equal(47.5m, built[0].TotalLinha);

        Assert.Equal(2, built[1].LinhaOrd);
        Assert.Equal("1099", built[1].Ref);
        Assert.Equal(2m, built[1].PrecoSubmissao);
        Assert.Equal(2m, built[1].TotalLinha);
    }

    [Fact]
    public void BuildLinhasSubstituicao_eliminar_linha_original()
    {
        var existentes = new[]
        {
            new ClientePmLinhaPersistida(1, "1051", "A", "", 1m, 1m, 1m, 1m),
            new ClientePmLinhaPersistida(2, "1052", "B", "", 1m, 2m, 2m, 2m)
        };

        var built = StaffPmPrecoRules.BuildLinhasSubstituicao(
            existentes,
            [new StaffPmLinhaEditRequest(2, "1052", "B", "", 3m, 2m)]);

        Assert.Single(built);
        Assert.Equal(1, built[0].LinhaOrd);
        Assert.Equal("1052", built[0].Ref);
        Assert.Equal(2m, built[0].PrecoSubmissao);
        Assert.Equal(6m, built[0].TotalLinha);
    }
}
