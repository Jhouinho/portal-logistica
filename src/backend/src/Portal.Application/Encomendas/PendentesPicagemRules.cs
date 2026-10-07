namespace Portal.Application.Encomendas;

/// <summary>
/// Regra canónica «Quantidades Pendentes de Picagens» (ndos=1).
/// «Picking iniciado» é ao nível da <b>encomenda</b>; o Pending híbrido é por linha.
/// Isolada de Em Picking (<c>qtt &gt; SUM66</c>) e de <c>QuantityPending &gt; 0</c> isolado.
/// </summary>
public static class PendentesPicagemRules
{
    /// <summary>
    /// Semântica Kapps (<c>v_KApps_Picking_Lines</c>):
    /// <c>QuantityPending = BI.qtt − BI.qtt2 − Picked</c>
    /// com <c>Picked = SUM(DossierLin.Qty2)</c> Status=A ∧ Integrada=N.
    /// </summary>
    public static decimal QuantityPendingKapps(decimal qtt, decimal qtt2, decimal picked) =>
        qtt - qtt2 - picked;

    /// <summary>
    /// A encomenda iniciou fisicamente o picking se existir qualquer linha com
    /// <c>Picked &gt; 0</c> ou <c>SUM66 &gt; 0</c> (independente de filtros de artigo/cor).
    /// </summary>
    public static bool EncomendaIniciouPicking(
        IEnumerable<(decimal Picked, decimal Sum66)> linhas) =>
        linhas.Any(l => l.Picked > 0m || l.Sum66 > 0m);

    public static bool LinhaIniciouPicking(decimal picked, decimal sum66) =>
        picked > 0m || sum66 > 0m;

    /// <summary>
    /// Pending híbrido por linha, assumindo que a encomenda já iniciou.
    /// <c>Picked &gt; 0</c> → Kapps; senão → <c>qtt − SUM66</c> (mesmo se SUM66=0).
    /// Não devolve pending negativo.
    /// </summary>
    public static PendentesPicagemLinhaResult AvaliarLinhaEmEncomendaIniciada(
        decimal qtt,
        decimal qtt2,
        decimal sum66,
        decimal picked)
    {
        if (picked > 0m)
        {
            var pendingKapps = QuantityPendingKapps(qtt, qtt2, picked);
            if (pendingKapps <= 0m)
                return PendentesPicagemLinhaResult.Excluded;
            return PendentesPicagemLinhaResult.Included(pendingKapps, PendentesPicagemFonte.Kapps);
        }

        var pending = qtt - sum66;
        if (pending <= 0m)
            return PendentesPicagemLinhaResult.Excluded;
        return PendentesPicagemLinhaResult.Included(pending, PendentesPicagemFonte.Sum66);
    }

    /// <summary>
    /// Avalia uma linha no contexto da encomenda: se a encomenda não iniciou → excluir;
    /// senão aplicar o Pending híbrido.
    /// </summary>
    public static PendentesPicagemLinhaResult AvaliarLinha(
        decimal qtt,
        decimal qtt2,
        decimal sum66,
        decimal picked,
        bool encomendaIniciou)
    {
        if (!encomendaIniciou)
            return PendentesPicagemLinhaResult.Excluded;

        return AvaliarLinhaEmEncomendaIniciada(qtt, qtt2, sum66, picked);
    }

    public static decimal SomarPendentesEncomenda(IEnumerable<decimal> pendentesLinha) =>
        pendentesLinha.Sum();
}

public enum PendentesPicagemFonte
{
    Excluded = 0,
    Kapps = 1,
    Sum66 = 2
}

public readonly record struct PendentesPicagemLinhaResult(
    bool Incluir,
    decimal Pending,
    PendentesPicagemFonte Fonte)
{
    public static PendentesPicagemLinhaResult Excluded { get; } =
        new(false, 0m, PendentesPicagemFonte.Excluded);

    public static PendentesPicagemLinhaResult Included(decimal pending, PendentesPicagemFonte fonte) =>
        new(true, pending, fonte);
}
