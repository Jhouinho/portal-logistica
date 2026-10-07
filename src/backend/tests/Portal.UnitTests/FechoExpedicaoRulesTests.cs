using Portal.Application.Encomendas;

namespace Portal.UnitTests;

/// <summary>
/// Contratos de erro esperados pelas SPs de fecho/reabertura operacional (ndos=65).
/// </summary>
public sealed class FechoExpedicaoRulesTests
{
    [Theory]
    [InlineData("Expedição já fechada.", 409)]
    [InlineData("Expedição já aberta.", 409)]
    [InlineData("Dossier de expedição não encontrado ou série inválida.", 404)]
    [InlineData("bostamp obrigatório.", 400)]
    public void Mapear_mensagem_sp_para_status(string mensagem, int statusEsperado)
    {
        var status = MapStatus(mensagem);
        Assert.Equal(statusEsperado, status);
    }

    private static int MapStatus(string msg)
    {
        if (msg.Contains("não encontrado", StringComparison.OrdinalIgnoreCase) ||
            msg.Contains("série inválida", StringComparison.OrdinalIgnoreCase))
            return 404;
        if (msg.Contains("já fechada", StringComparison.OrdinalIgnoreCase) ||
            msg.Contains("já aberta", StringComparison.OrdinalIgnoreCase))
            return 409;
        return 400;
    }
}
