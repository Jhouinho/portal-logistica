using System.Runtime.ExceptionServices;
using Microsoft.Data.SqlClient;
using Portal.Application.Encomendas;

namespace Portal.Infrastructure.Sql;

/// <summary>
/// Converte apenas erros SQL de negócio conhecidos (RAISERROR de SPs / conflitos Unique)
/// em <see cref="PortalBusinessException"/> com mensagens públicas fixas.
/// Falhas técnicas não mapeadas devem ser re-lançadas para o handler central (500 genérico).
/// </summary>
public static class SqlBusinessErrorMapper
{
    public static bool TryMap(SqlException ex, out PortalBusinessException business)
    {
        ArgumentNullException.ThrowIfNull(ex);
        return TryMap(ex.Number, ex.Message, out business);
    }

    /// <summary>Variante testável sem instanciar <see cref="SqlException"/>.</summary>
    public static bool TryMap(int number, string? message, out PortalBusinessException business)
    {
        var msg = message ?? string.Empty;

        if (number is 2627 or 2601)
        {
            business = new PortalBusinessException("Conflito de dados.", 409);
            return true;
        }

        // Apenas erros de utilizador (RAISERROR / THROW com número >= 50000) são candidatos a negócio.
        if (number < 50000)
        {
            business = null!;
            return false;
        }

        if (Contains(msg, "LINHAS_SEM_AUTORIZACAO"))
        {
            business = new PortalBusinessException(
                "LINHAS_SEM_AUTORIZACAO: Existem linhas com quantidade autorizada a 0. Confirme para avançar.",
                409);
            return true;
        }

        if (Contains(msg, "sobrep") || Contains(msg, "previsão aberta"))
        {
            business = new PortalBusinessException(
                "Já existe uma previsão em conflito com este período.",
                409);
            return true;
        }

        if (Contains(msg, "previsão fechada") || (Contains(msg, "fechada") && Contains(msg, "previsão")))
        {
            business = new PortalBusinessException("A previsão está fechada.", 409);
            return true;
        }

        if (Contains(msg, "Quantidade prevista insuficiente"))
        {
            business = new PortalBusinessException("Quantidade prevista insuficiente.", 409);
            return true;
        }

        if (Contains(msg, "Não existe uma previsão de entrada aberta"))
        {
            business = new PortalBusinessException("Não existe uma previsão de entrada aberta.", 409);
            return true;
        }

        if (Contains(msg, "não tem quantidade prevista registada"))
        {
            business = new PortalBusinessException(
                "O artigo não tem quantidade prevista registada.",
                409);
            return true;
        }

        if (Contains(msg, "Stock insuficiente"))
        {
            business = new PortalBusinessException("Stock insuficiente.", 409);
            return true;
        }

        if (Contains(msg, "Conflito") || Contains(msg, "Transição inválida") || Contains(msg, "congelada"))
        {
            business = new PortalBusinessException("Operação em conflito com o estado actual.", 409);
            return true;
        }

        if (Contains(msg, "já fechada") || Contains(msg, "já aberta") || Contains(msg, "já realizado"))
        {
            business = new PortalBusinessException("Operação em conflito com o estado actual.", 409);
            return true;
        }

        if (Contains(msg, "sem Check-in"))
        {
            business = new PortalBusinessException("O dossier não tem Check-in activo.", 409);
            return true;
        }

        if (Contains(msg, "não encontrada") || Contains(msg, "não encontrado")
            || Contains(msg, "série inválida") || Contains(msg, "fora da série"))
        {
            business = new PortalBusinessException("Registo não encontrado.", 404);
            return true;
        }

        if (Contains(msg, "inválida") || Contains(msg, "obrigatório") || Contains(msg, "Indicar"))
        {
            business = new PortalBusinessException("Dados inválidos para a operação.", 400);
            return true;
        }

        // RAISERROR desconhecido: não expor texto SQL cru.
        business = new PortalBusinessException("Operação não efectuada.", 400);
        return true;
    }

    /// <summary>
    /// Mapeia para negócio ou re-lança a <see cref="SqlException"/> (falha técnica → handler 500).
    /// </summary>
    public static void ThrowMappedOrRethrow(SqlException ex)
    {
        if (TryMap(ex, out var business))
            throw business;
        ExceptionDispatchInfo.Capture(ex).Throw();
    }

    private static bool Contains(string haystack, string needle) =>
        haystack.Contains(needle, StringComparison.OrdinalIgnoreCase);
}
