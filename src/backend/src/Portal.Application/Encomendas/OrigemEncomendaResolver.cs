namespace Portal.Application.Encomendas;

/// <summary>
/// Critério de seleção da encomenda original (ndos=1) espelhado em
/// <c>PickingDossiersQuery</c>: preferir hop1 (66→1) se existir candidato;
/// senão hop2 (65→66→1). Dentro do hop, <c>MAX(obrano)</c> e desempate
/// <c>bostamp</c> DESC — data e hora vêm sempre do mesmo BO.
/// </summary>
public static class OrigemEncomendaResolver
{
    public sealed record Candidato(
        int Obrano,
        string BoStamp,
        DateTime? Ousrdata,
        string? Ousrhora);

    public sealed record Resultado(
        int Obrano,
        DateTime? Ousrdata,
        string Ousrhora);

    /// <summary>
    /// Resolve a origem temporal atómica. Sem candidatos → <c>null</c>
    /// (dossier permanece; sem fallback para datas do 66/65).
    /// </summary>
    public static Resultado? Resolver(
        IEnumerable<Candidato> hop1_66para1,
        IEnumerable<Candidato> hop2_65para66para1)
    {
        var escolhido = Escolher(hop1_66para1) ?? Escolher(hop2_65para66para1);
        if (escolhido is null)
            return null;

        return new Resultado(
            escolhido.Obrano,
            escolhido.Ousrdata,
            escolhido.Ousrhora?.Trim() ?? string.Empty);
    }

    private static Candidato? Escolher(IEnumerable<Candidato> candidatos)
    {
        Candidato? melhor = null;
        foreach (var c in candidatos)
        {
            if (melhor is null
                || c.Obrano > melhor.Obrano
                || (c.Obrano == melhor.Obrano
                    && string.CompareOrdinal(c.BoStamp, melhor.BoStamp) > 0))
            {
                melhor = c;
            }
        }

        return melhor;
    }
}
