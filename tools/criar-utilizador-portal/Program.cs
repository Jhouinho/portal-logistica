using Microsoft.AspNetCore.Identity;
using Microsoft.EntityFrameworkCore;
using Microsoft.Extensions.Configuration;
using Microsoft.Extensions.DependencyInjection;
using Portal.Infrastructure.Identity;

// Uso (UAT):
//   dotnet run --project tools/criar-utilizador-portal -- <email> <password> [--connection "..."] [--reset]
// Requisito: US com o mesmo email, inactivo=0 e u_usaPort=1.

if (args.Length < 2)
{
    Console.Error.WriteLine("Uso: criar-utilizador-portal <email> <password> [--connection \"...\"] [--reset]");
    return 1;
}

var email = args[0].Trim();
var password = args[1];
string? connection = null;
var reset = args.Any(a => a is "--reset" or "-r");
for (var i = 2; i < args.Length - 1; i++)
{
    if (args[i] is "--connection" or "-c")
        connection = args[i + 1];
}

var config = new ConfigurationBuilder()
    .SetBasePath(Directory.GetCurrentDirectory())
    .AddEnvironmentVariables()
    .Build();

connection ??= Environment.GetEnvironmentVariable("Phc__ConnectionString")
               ?? config["Phc:ConnectionString"];
if (string.IsNullOrWhiteSpace(connection))
{
    Console.Error.WriteLine("Connection string em falta (--connection ou env Phc__ConnectionString).");
    return 1;
}

var services = new ServiceCollection();
services.AddLogging();
services.AddDbContext<PortalIdentityDbContext>(o => o.UseSqlServer(connection));
services
    .AddIdentityCore<PortalUserIdentity>(o =>
    {
        o.User.RequireUniqueEmail = true;
        o.Password.RequiredLength = 8;
        o.Password.RequireDigit = true;
        o.Password.RequireLowercase = true;
        o.Password.RequireUppercase = true;
        o.Password.RequireNonAlphanumeric = false;
    })
    .AddRoles<IdentityRole>()
    .AddEntityFrameworkStores<PortalIdentityDbContext>();

await using var sp = services.BuildServiceProvider();
await using var scope = sp.CreateAsyncScope();
var db = scope.ServiceProvider.GetRequiredService<PortalIdentityDbContext>();
await db.Database.MigrateAsync();

var users = scope.ServiceProvider.GetRequiredService<UserManager<PortalUserIdentity>>();
var existing = await users.FindByEmailAsync(email);
if (existing is not null)
{
    if (!reset)
    {
        Console.WriteLine($"Utilizador Identity já existe: {email}");
        Console.WriteLine("Para repor a password: acrescente --reset");
        return 0;
    }

    var remove = await users.RemovePasswordAsync(existing);
    if (!remove.Succeeded)
    {
        foreach (var err in remove.Errors)
            Console.Error.WriteLine($"{err.Code}: {err.Description}");
        return 1;
    }

    var add = await users.AddPasswordAsync(existing, password);
    if (!add.Succeeded)
    {
        foreach (var err in add.Errors)
            Console.Error.WriteLine($"{err.Code}: {err.Description}");
        return 1;
    }

    await users.SetLockoutEndDateAsync(existing, null);
    await users.ResetAccessFailedCountAsync(existing);
    Console.WriteLine($"Password reposta para: {email}");
    return 0;
}

var user = new PortalUserIdentity
{
    UserName = email,
    Email = email,
    EmailConfirmed = true
};

var result = await users.CreateAsync(user, password);
if (!result.Succeeded)
{
    foreach (var err in result.Errors)
        Console.Error.WriteLine($"{err.Code}: {err.Description}");
    return 1;
}

Console.WriteLine($"Criado u_HcaLogiUsers: {email}");
Console.WriteLine("Confirme US.u_usaPort = 1 para este email antes de fazer login.");
return 0;
