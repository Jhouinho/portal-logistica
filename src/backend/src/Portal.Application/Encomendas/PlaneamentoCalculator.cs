namespace Portal.Application.Encomendas;

/// <summary>
/// Limite definido semanal (ARCHITECTURE Apêndice A):
/// corte = Segunda (ou DiaCorte) da <b>semana da encomenda</b> às HoraCorte;
/// dataHora &lt; corte → Dentro do Limite Definido (DP);
/// senão → Após Limite Definido (AC).
/// </summary>
public static class PlaneamentoCalculator
{
    public static (string Etiqueta, string Codigo) Classificar(
        DateTime dataObra,
        string ousrhora,
        string diaCorte,
        string horaCorte,
        string fuso,
        DateTime? agoraUtc = null)
    {
        // dataobra + ousrhora são hora de parede PHC (Lisboa); o fuso/agora não entram no corte da semana da encomenda.
        _ = fuso;
        _ = agoraUtc;

        var dataHoraEncomenda = CombinarDataHora(dataObra, ousrhora);
        var limite = CorteNaSemanaDaEncomenda(dataHoraEncomenda, diaCorte, horaCorte);

        if (dataHoraEncomenda < limite)
            return ("Dentro do Limite Definido", "DP");

        return ("Após Limite Definido", "AC");
    }

    public static bool CoincideFiltro(string codigo, string? filtroEstado)
    {
        if (string.IsNullOrWhiteSpace(filtroEstado) ||
            filtroEstado.Equals("Todos", StringComparison.OrdinalIgnoreCase))
            return true;

        if (filtroEstado.Equals("DP", StringComparison.OrdinalIgnoreCase) ||
            filtroEstado.Equals("AC", StringComparison.OrdinalIgnoreCase))
            return codigo.Equals(filtroEstado, StringComparison.OrdinalIgnoreCase);

        return filtroEstado.Equals("DentroDoPlaneamento", StringComparison.OrdinalIgnoreCase)
            ? codigo == "DP"
            : filtroEstado.Equals("AposCorte", StringComparison.OrdinalIgnoreCase) && codigo == "AC";
    }

    /// <summary>
    /// Segunda (DiaCorte) da semana que contém <paramref name="dataHora"/>, à HoraCorte.
    /// </summary>
    private static DateTime CorteNaSemanaDaEncomenda(DateTime dataHora, string diaCorte, string horaCorte)
    {
        if (!Enum.TryParse<DayOfWeek>(diaCorte, ignoreCase: true, out var dia))
            dia = DayOfWeek.Monday;

        if (!TimeSpan.TryParse(horaCorte, out var hora))
            hora = new TimeSpan(12, 0, 0);

        var diasDesde = ((int)dataHora.DayOfWeek - (int)dia + 7) % 7;
        return dataHora.Date.AddDays(-diasDesde).Add(hora);
    }

    private static DateTime CombinarDataHora(DateTime dataObra, string ousrhora)
    {
        var raw = ousrhora?.Trim() ?? string.Empty;
        if (TimeSpan.TryParse(raw, out var ts))
            return dataObra.Date.Add(ts);

        // PHC por vezes devolve "1900-01-01 12:00:52" / datetime completo
        if (DateTime.TryParse(raw, out var dt))
            return dataObra.Date.Add(dt.TimeOfDay);

        return dataObra.Date;
    }
}
