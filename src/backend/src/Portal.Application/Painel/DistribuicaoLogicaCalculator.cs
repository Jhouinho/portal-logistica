namespace Portal.Application.Painel;

/// <summary>
/// Distribuição fraccionada de uma encomenda lógica (bostamp ndos=1) pelos estados do circuito.
/// Cada encomenda contribui exactamente 1,0 unidade, repartida pelos 66/65 activos.
/// </summary>
public static class DistribuicaoLogicaCalculator
{
    public const string EstadoEmAberto = "EmAberto";
    public const string EstadoEmPicking = "EmPicking";
    public const string EstadoSeparado = "Separado";
    public const string EstadoEmEntrega = "EmEntrega";
    public const string EstadoEmExpedicao = "EmExpedicao";
    public const string EstadoNaoClassificada = "NaoClassificada";

    /// <summary>Pesos de uma encomenda lógica (soma = 1, excepto se vazia — não usado).</summary>
    public readonly record struct Contribuicao(
        decimal EmAberto,
        decimal EmPicking,
        decimal Separado,
        decimal EmEntrega,
        decimal EmExpedicao,
        decimal NaoClassificada)
    {
        public decimal Total =>
            EmAberto + EmPicking + Separado + EmEntrega + EmExpedicao + NaoClassificada;
    }

    /// <summary>
    /// Reparte 1,0 unidade pelos momentos activos do circuito.
    /// Momentos: Em Picking residual (ndos=1 ainda com linhas por cobrir), conjunto 66 activos,
    /// conjunto 65 activo — pesos iguais (ex.: picking+66 → 0,5+0,5; 66+65 → 0,5+0,5; três → ⅓).
    /// <paramref name="n66Separado"/> / <paramref name="n66EmEntrega"/> = contagens de 66 activos.
    /// <paramref name="prontaPicking"/> = null quando o ndos=1 não está na vista de abertas
    /// (só usado quando não há 66/65).
    /// <paramref name="aindaEmPicking"/> = mesmo critério do COUNT Em Picking (pronta + residual SUM66).
    /// Vários 65 activos: o conjunto 65 conta como um único balde Em Expedição.
    /// </summary>
    public static Contribuicao Contribuir(
        int n66Separado,
        int n66EmEntrega,
        bool tem65Aberto,
        bool? prontaPicking,
        bool aindaEmPicking = false)
    {
        if (n66Separado < 0)
            n66Separado = 0;
        if (n66EmEntrega < 0)
            n66EmEntrega = 0;

        var n66 = n66Separado + n66EmEntrega;

        if (n66 == 0 && !tem65Aberto)
        {
            if (prontaPicking == true)
                return new(0m, 1m, 0m, 0m, 0m, 0m);
            if (prontaPicking == false)
                return new(1m, 0m, 0m, 0m, 0m, 0m);
            return new(0m, 0m, 0m, 0m, 0m, 1m);
        }

        // Momentos activos com peso igual.
        var momentos = 0;
        if (aindaEmPicking)
            momentos++;
        if (n66 > 0)
            momentos++;
        if (tem65Aberto)
            momentos++;
        if (momentos == 0)
            return new(0m, 0m, 0m, 0m, 0m, 1m);

        var peso = 1m / momentos;
        var emPicking = aindaEmPicking ? peso : 0m;
        decimal separado = 0m;
        decimal emEntrega = 0m;

        if (n66 > 0)
        {
            // Conjunto 66 = um momento; repartido pelos 66 activos (Separado vs Em Entrega).
            separado = peso * n66Separado / n66;
            emEntrega = peso - separado;
        }

        // Último balde absorve resto decimal (ex. ⅓+⅓+⅓) para Total == 1.
        decimal emExpedicao;
        if (tem65Aberto)
            emExpedicao = 1m - emPicking - separado - emEntrega;
        else if (n66 > 0)
        {
            emExpedicao = 0m;
            var resto = 1m - emPicking - separado - emEntrega;
            if (resto != 0m)
            {
                if (n66EmEntrega > 0)
                    emEntrega += resto;
                else
                    separado += resto;
            }
        }
        else
            emExpedicao = 1m - emPicking;

        return new(0m, emPicking, separado, emEntrega, emExpedicao, 0m);
    }

    public static DistribuicaoLogicaDto FromContagens(DistribuicaoLogicaContagemRow row)
    {
        var classificadas =
            row.EmAberto
            + row.EmPicking
            + row.Separado
            + row.EmEntrega
            + row.EmExpedicao;
        var total = classificadas + row.NaoClassificadas;
        var totalEncomendas = row.TotalEncomendasLogicas > 0
            ? row.TotalEncomendasLogicas
            : (int)Math.Round(total, MidpointRounding.AwayFromZero);

        return new DistribuicaoLogicaDto(
            totalEncomendas,
            Estado(row.EmAberto, totalEncomendas),
            Estado(row.EmPicking, totalEncomendas),
            Estado(row.Separado, totalEncomendas),
            Estado(row.EmEntrega, totalEncomendas),
            Estado(row.EmExpedicao, totalEncomendas),
            (int)Math.Round(row.NaoClassificadas, MidpointRounding.AwayFromZero));
    }

    /// <summary>
    /// Agrega contribuições fraccionadas de várias encomendas.
    /// </summary>
    public static DistribuicaoLogicaDto FromContribuicoes(IReadOnlyList<Contribuicao> contribs)
    {
        decimal emAberto = 0, emPicking = 0, separado = 0, emEntrega = 0, emExpedicao = 0, nao = 0;
        foreach (var c in contribs)
        {
            emAberto += c.EmAberto;
            emPicking += c.EmPicking;
            separado += c.Separado;
            emEntrega += c.EmEntrega;
            emExpedicao += c.EmExpedicao;
            nao += c.NaoClassificada;
        }

        return FromContagens(
            new DistribuicaoLogicaContagemRow
            {
                EmAberto = emAberto,
                EmPicking = emPicking,
                Separado = separado,
                EmEntrega = emEntrega,
                EmExpedicao = emExpedicao,
                NaoClassificadas = nao,
                TotalEncomendasLogicas = contribs.Count,
            });
    }

    private static EstadoDistribuicaoLogicaDto Estado(decimal quantidade, int total) =>
        new(quantidade, Percentagem(quantidade, total));

    public static decimal Percentagem(decimal quantidade, int total)
    {
        if (total <= 0 || quantidade <= 0)
            return 0m;
        return Math.Round(
            100m * quantidade / total,
            1,
            MidpointRounding.AwayFromZero);
    }
}
