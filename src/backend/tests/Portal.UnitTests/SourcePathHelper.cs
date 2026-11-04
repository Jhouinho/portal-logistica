namespace Portal.UnitTests;

internal static class SourcePathHelper
{
    /// <summary>
    /// Resolve ficheiros sob <c>src/backend/src/...</c> a partir de
    /// <c>Portal.UnitTests/bin/Debug/net8.0</c>.
    /// </summary>
    public static string ResolveBackendSrc(params string[] relativeUnderSrc)
    {
        var dir = new DirectoryInfo(AppContext.BaseDirectory);
        // net8.0 → Debug → bin → Portal.UnitTests → tests → backend
        for (var i = 0; i < 5 && dir.Parent is not null; i++)
            dir = dir.Parent;

        var parts = new List<string> { dir.FullName, "src" };
        parts.AddRange(relativeUnderSrc);
        var path = Path.Combine(parts.ToArray());
        if (!File.Exists(path))
            throw new FileNotFoundException("Fonte não encontrada: " + path);
        return path;
    }
}
