namespace Portal.Application.Realtime;

/// <summary>
/// Estado dos watermarks independentes (encomendas ndos=1 + dossiers 66/65 + Kapps).
/// Mantido pelo chamador (ex. memória na Etapa 2); sem persistência nesta etapa.
/// </summary>
public sealed class ExternalChangeWatermarks
{
    public BoBiCursor? Bo1 { get; init; }

    public BoBiCursor? Bi1 { get; init; }

    public BoBiCursor? Bo66 { get; init; }

    public BoBiCursor? Bi66 { get; init; }

    public BoBiCursor? Bo65 { get; init; }

    public BoBiCursor? Bi65 { get; init; }

    public KappsCursor? Kapps { get; init; }

    /// <summary>False = ainda não houve cold start / captura inicial.</summary>
    public bool IsInitialized { get; init; }

    public static ExternalChangeWatermarks Uninitialized { get; } = new() { IsInitialized = false };

    public static ExternalChangeWatermarks FromSnapshot(ExternalChangeSnapshot snapshot) =>
        new()
        {
            IsInitialized = true,
            Bo1 = snapshot.Bo1,
            Bi1 = snapshot.Bi1,
            Bo66 = snapshot.Bo66,
            Bi66 = snapshot.Bi66,
            Bo65 = snapshot.Bo65,
            Bi65 = snapshot.Bi65,
            Kapps = snapshot.Kapps,
        };
}

/// <summary>Leitura pontual dos máximos actuais na BD.</summary>
public sealed class ExternalChangeSnapshot
{
    public required BoBiCursor? Bo1 { get; init; }

    public required BoBiCursor? Bi1 { get; init; }

    public required BoBiCursor? Bo66 { get; init; }

    public required BoBiCursor? Bi66 { get; init; }

    public required BoBiCursor? Bo65 { get; init; }

    public required BoBiCursor? Bi65 { get; init; }

    public required KappsCursor? Kapps { get; init; }
}
