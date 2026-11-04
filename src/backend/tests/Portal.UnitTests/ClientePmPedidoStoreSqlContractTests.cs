namespace Portal.UnitTests;

/// <summary>
/// Contrato estático: listagem cliente = recentes DESC; staff = FIFO ASC.
/// Evita regressão do bug da Fase 86 sem SQL runtime.
/// </summary>
public class ClientePmPedidoStoreSqlContractTests
{
    [Fact]
    public void ListarAsync_cliente_ordena_DataSubmissao_PedidoId_DESC()
    {
        var src = ReadStoreSource();
        var listar = ExtractMethodBody(src, "public async Task<IReadOnlyList<ClientePmPedidoPersistido>> ListarAsync");
        Assert.Contains("ORDER BY DataSubmissao DESC, PedidoId DESC", listar, StringComparison.Ordinal);
        Assert.DoesNotContain("ORDER BY DataSubmissao ASC", listar, StringComparison.Ordinal);
        Assert.Contains("WHERE ClNo = @clNo", listar, StringComparison.Ordinal);
        Assert.Contains("AND ClEstab = @clEstab", listar, StringComparison.Ordinal);
    }

    [Fact]
    public void ListarStaffAsync_ordena_DataSubmissao_PedidoId_ASC()
    {
        var src = ReadStoreSource();
        var listar = ExtractMethodBody(src, "public async Task<IReadOnlyList<ClientePmPedidoPersistido>> ListarStaffAsync");
        Assert.Contains("ORDER BY p.DataSubmissao ASC, p.PedidoId ASC", listar, StringComparison.Ordinal);
        Assert.DoesNotContain("ClNo = @clNo", listar, StringComparison.Ordinal);
    }

    [Fact]
    public void ObterAsync_filtra_sempre_por_ClNo_e_ClEstab()
    {
        var src = ReadStoreSource();
        var obter = ExtractMethodBody(src, "private async Task<ClientePmPedidoPersistido?> ObterAsync");
        Assert.Contains("WHERE ClNo = @clNo", obter, StringComparison.Ordinal);
        Assert.Contains("AND ClEstab = @clEstab", obter, StringComparison.Ordinal);
    }

    [Fact]
    public void ListarAsync_seleciona_Bostamp_necessario_ao_dedupe()
    {
        var src = ReadStoreSource();
        var listar = ExtractMethodBody(src, "public async Task<IReadOnlyList<ClientePmPedidoPersistido>> ListarAsync");
        Assert.Contains("AS Bostamp", listar, StringComparison.Ordinal);
        Assert.Contains("ORDER BY DataSubmissao DESC, PedidoId DESC", listar, StringComparison.Ordinal);
    }

    private static string ReadStoreSource() =>
        File.ReadAllText(SourcePathHelper.ResolveBackendSrc(
            "Portal.Infrastructure", "Cliente", "ClientePmPedidoStore.cs"));

    private static string ExtractMethodBody(string src, string signaturePrefix)
    {
        var start = src.IndexOf(signaturePrefix, StringComparison.Ordinal);
        Assert.True(start >= 0, "Assinatura não encontrada: " + signaturePrefix);
        var brace = src.IndexOf('{', start);
        Assert.True(brace > start);
        var depth = 0;
        for (var i = brace; i < src.Length; i++)
        {
            if (src[i] == '{') depth++;
            else if (src[i] == '}')
            {
                depth--;
                if (depth == 0)
                    return src[start..(i + 1)];
            }
        }

        throw new InvalidOperationException("Corpo do método incompleto.");
    }
}
