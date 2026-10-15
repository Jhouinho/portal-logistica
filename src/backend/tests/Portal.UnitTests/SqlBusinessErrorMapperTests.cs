using Portal.Infrastructure.Sql;

namespace Portal.UnitTests;

public class SqlBusinessErrorMapperTests
{
    [Fact]
    public void Negocio_conhecido_nao_expoe_texto_sql_cru()
    {
        var ok = SqlBusinessErrorMapper.TryMap(
            50001,
            "Violation in dbo.u_HcaPrevEntrada: previsão sobreposta no período",
            out var biz);

        Assert.True(ok);
        Assert.Equal(409, biz.StatusCode);
        Assert.Equal("Já existe uma previsão em conflito com este período.", biz.Message);
        Assert.DoesNotContain("dbo.", biz.Message, StringComparison.OrdinalIgnoreCase);
        Assert.DoesNotContain("Violation", biz.Message, StringComparison.OrdinalIgnoreCase);
    }

    [Fact]
    public void Linhas_sem_autorizacao_mantem_contrato_publico()
    {
        var ok = SqlBusinessErrorMapper.TryMap(
            50000,
            "LINHAS_SEM_AUTORIZACAO: detalhes internos da SP",
            out var biz);

        Assert.True(ok);
        Assert.Equal(409, biz.StatusCode);
        Assert.StartsWith("LINHAS_SEM_AUTORIZACAO:", biz.Message, StringComparison.Ordinal);
        Assert.DoesNotContain("detalhes internos", biz.Message, StringComparison.Ordinal);
    }

    [Fact]
    public void Unique_constraint_devolve_conflito_generico()
    {
        Assert.True(SqlBusinessErrorMapper.TryMap(2627, "Cannot insert duplicate key in object 'dbo.segredo'", out var biz));
        Assert.Equal(409, biz.StatusCode);
        Assert.Equal("Conflito de dados.", biz.Message);
        Assert.DoesNotContain("dbo.segredo", biz.Message, StringComparison.Ordinal);
    }

    [Fact]
    public void Erro_tecnico_sistema_nao_mapeia_para_negocio()
    {
        var ok = SqlBusinessErrorMapper.TryMap(
            4060,
            "Cannot open database \"PHC\" requested by the login. Login failed for user 'portal_app'.",
            out _);

        Assert.False(ok);
    }

    [Fact]
    public void Raiserror_desconhecido_usa_mensagem_publica_sem_sql()
    {
        const string secret = "Invalid object name 'dbo.tabela_secreta'.";
        Assert.True(SqlBusinessErrorMapper.TryMap(50099, secret, out var biz));
        Assert.Equal(400, biz.StatusCode);
        Assert.Equal("Operação não efectuada.", biz.Message);
        Assert.DoesNotContain(secret, biz.Message, StringComparison.Ordinal);
    }

    [Fact]
    public void Registo_nao_encontrado_404()
    {
        Assert.True(SqlBusinessErrorMapper.TryMap(50000, "Previsão não encontrada.", out var biz));
        Assert.Equal(404, biz.StatusCode);
        Assert.Equal("Registo não encontrado.", biz.Message);
    }
}
