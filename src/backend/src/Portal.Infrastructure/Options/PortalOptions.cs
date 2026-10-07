namespace Portal.Infrastructure.Options;

public sealed class PhcOptions
{
    public const string SectionName = "Phc";

    public string ConnectionString { get; set; } = string.Empty;
    public int SerieEncomendasNdos { get; set; } = 1;
    public int SeriePickingNdos { get; set; } = 66;
    public int SerieSeparacaoNdos { get; set; } = 65;
}

public sealed class PlaneamentoOptions
{
    public const string SectionName = "Planeamento";

    /// <summary>DayOfWeek: Monday = 1 in config as string "Monday".</summary>
    public string DiaCorte { get; set; } = "Monday";
    public string HoraCorte { get; set; } = "12:00";
    public string Fuso { get; set; } = "Europe/Lisbon";
}
