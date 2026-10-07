using Microsoft.AspNetCore.Identity;

if (args.Length == 0 || args.Contains("-h") || args.Contains("--help"))
{
    PrintHelp();
    Environment.Exit(args.Length == 0 ? 1 : 0);
}

string? password = null;
string? usercode = null;
string? hashToVerify = null;

for (var i = 0; i < args.Length; i++)
{
    switch (args[i])
    {
        case "--password":
        case "-p":
            password = i + 1 < args.Length ? args[++i] : null;
            break;
        case "--usercode":
        case "-u":
            usercode = i + 1 < args.Length ? args[++i] : null;
            break;
        case "--verify":
        case "-v":
            hashToVerify = i + 1 < args.Length ? args[++i] : null;
            break;
        default:
            Console.Error.WriteLine($"Argumento desconhecido: {args[i]}");
            PrintHelp();
            Environment.Exit(1);
            break;
    }
}

if (string.IsNullOrEmpty(password))
{
    Console.Error.WriteLine("Indicar --password \"...\"");
    Environment.Exit(1);
}

var hasher = new PasswordHasher<object>();

if (!string.IsNullOrEmpty(hashToVerify))
{
    var result = hasher.VerifyHashedPassword(new object(), hashToVerify, password);
    Console.WriteLine(result switch
    {
        PasswordVerificationResult.Success => "OK — hash válido para esta password.",
        PasswordVerificationResult.SuccessRehashNeeded => "OK — hash válido (convém rehash no futuro).",
        _ => "FALHA — password não corresponde ao hash."
    });
    Environment.Exit(result == PasswordVerificationResult.Failed ? 2 : 0);
}

var hash = hasher.HashPassword(new object(), password);

if (hash.Length > 254)
{
    Console.Error.WriteLine($"AVISO: hash tem {hash.Length} chars (> 254). Não cabe em u_portalph.");
    Environment.Exit(3);
}

Console.WriteLine("=== Hash (colar em US.u_portalph) ===");
Console.WriteLine(hash);
Console.WriteLine();
Console.WriteLine($"Comprimento: {hash.Length} / 254");
Console.WriteLine();
Console.WriteLine("=== SQL (UAT) ===");

var code = string.IsNullOrWhiteSpace(usercode) ? "TEU_USERCODE" : usercode.Trim();
var hashSql = hash.Replace("'", "''", StringComparison.Ordinal);
var codeSql = code.Replace("'", "''", StringComparison.Ordinal);

Console.WriteLine($"""
    UPDATE dbo.us
    SET u_portalph = N'{hashSql}'
    WHERE LTRIM(RTRIM(usercode)) = N'{codeSql}'
      AND ISNULL(inactivo, 0) = 0;

    SELECT usercode, username, iniciais,
           LEN(LTRIM(RTRIM(u_portalph))) AS hash_len
    FROM dbo.us WITH (NOLOCK)
    WHERE LTRIM(RTRIM(usercode)) = N'{codeSql}';
    """);

static void PrintHelp()
{
    Console.WriteLine("""
        gerar-hash-portalph — gera hash ASP.NET PasswordHasher para US.u_portalph

        Uso:
          dotnet run --project tools/gerar-hash-portalph -- --password "MinhaPassword"
          dotnet run --project tools/gerar-hash-portalph -- --password "MinhaPassword" --usercode ANA
          dotnet run --project tools/gerar-hash-portalph -- --verify "AQAAAA..." --password "MinhaPassword"

        Notas:
          - Nunca guardar a password em texto na BD.
          - Colar o hash no UPDATE de US.u_portalph (UAT primeiro).
          - varchar(254) NOT NULL — confirmar LENGTH(hash) <= 254.
        """);
}
