# criar-utilizador-portal

Cria o primeiro utilizador em `u_HcaLogiUsers` (ASP.NET Identity) para UAT.

## Pré-requisitos

1. Scripts SQL `028` (`u_usaPort`), `010`, `020` aplicados
2. Em `US`: email do utilizador, `inactivo = 0`, `u_usaPort = 1`
3. Connection string (`Phc:ConnectionString` nos User Secrets da API ou `--connection`)

## Uso

```powershell
Set-Location -LiteralPath "c:\Users\User\Documents\joao_lopes\Liliana&Serodio"
$env:Phc__ConnectionString = "Server=...\SQLEXPRESS;Database=Digicanola;User Id=...;Password=...;TrustServerCertificate=True;"

# Criar
dotnet run --project .\tools\criar-utilizador-portal -- "email@dominio.pt" "Password1"

# Repor password
dotnet run --project .\tools\criar-utilizador-portal -- "email@dominio.pt" "Password1" --reset
```

Depois: login no portal com o mesmo email/password. Confirme `US.u_usaPort = 1`.
