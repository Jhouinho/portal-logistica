namespace Portal.Application.Realtime;

/// <summary>
/// Resultado técnico de uma detecção — sem nomes SignalR.
/// Em regressão o cursor conhecido mantém-se (não recua).
/// </summary>
public sealed class ExternalChangeDetectionResult
{
    public required bool WasColdStart { get; init; }

    public required bool Bo1Advanced { get; init; }

    public required bool Bi1Advanced { get; init; }

    public required bool Bo66Advanced { get; init; }

    public required bool Bi66Advanced { get; init; }

    public required bool Bo65Advanced { get; init; }

    public required bool Bi65Advanced { get; init; }

    public required bool KappsAdvanced { get; init; }

    public required bool Bo1Regressed { get; init; }

    public required bool Bi1Regressed { get; init; }

    public required bool Bo66Regressed { get; init; }

    public required bool Bi66Regressed { get; init; }

    public required bool Bo65Regressed { get; init; }

    public required bool Bi65Regressed { get; init; }

    public required bool KappsRegressed { get; init; }

    /// <summary>
    /// Estado a persistir em memória pelo chamador após este ciclo.
    /// Em cold start: snapshot completo. Em regressão: mantém o cursor anterior desse universo.
    /// </summary>
    public required ExternalChangeWatermarks NextWatermarks { get; init; }

    public bool AnyAdvanced =>
        Bo1Advanced || Bi1Advanced
        || Bo66Advanced || Bi66Advanced
        || Bo65Advanced || Bi65Advanced
        || KappsAdvanced;

    public bool AnyRegressed =>
        Bo1Regressed || Bi1Regressed
        || Bo66Regressed || Bi66Regressed
        || Bo65Regressed || Bi65Regressed
        || KappsRegressed;
}

public interface IExternalChangeCursorQuery
{
    /// <summary>Máximo lexicográfico BO para o ndos indicado; null se não houver linhas.</summary>
    Task<BoBiCursor?> GetMaxBoCursorAsync(int ndos, CancellationToken cancellationToken = default);

    /// <summary>Máximo lexicográfico BI (via join BO.ndos); null se não houver linhas.</summary>
    Task<BoBiCursor?> GetMaxBiCursorAsync(int ndos, CancellationToken cancellationToken = default);

    /// <summary>Máximo lexicográfico Kapps; null se a tabela estiver vazia.</summary>
    Task<KappsCursor?> GetMaxKappsCursorAsync(CancellationToken cancellationToken = default);
}
