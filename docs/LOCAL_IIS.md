# IIS local (ensaio no PC)

| | |
| --- | --- |
| Site | `PortalLocal` |
| URL | http://localhost:8088 |
| TV | http://localhost:8088/tv |
| Pasta | `C:\inetpub\portal-local\api` |
| Health | http://localhost:8088/health |

## O que foi instalado / criado

- ASP.NET Core **8 Hosting Bundle** + **URL Rewrite**
- App Pool `PortalLocalAppPool` (No Managed Code)
- API + SPA no **mesmo site** (`wwwroot` + `MapFallbackToFile`) → cookies no mesmo origin
- `appsettings.Production.json` **só** em `C:\inetpub\portal-local\api\` (fora do Git; connection string dos user-secrets)

## Republicar após alterações de código

```powershell
$root = 'C:\inetpub\portal-local\api'
Set-Location -LiteralPath '...\Liliana&Serodio\src\frontend'
npm run build
Set-Location -LiteralPath '...\Liliana&Serodio\src\backend'
dotnet publish .\src\Portal.Api\Portal.Api.csproj -c Release -o $root
Copy-Item .\src\frontend\dist\* "$root\wwwroot" -Recurse -Force
# NÃO sobrescrever appsettings.Production.json se o publish o apagar — voltar a criar se preciso
Import-Module WebAdministration
Restart-WebAppPool PortalLocalAppPool
```

## Remover o site local

```powershell
Import-Module WebAdministration
Remove-Website PortalLocal
Remove-WebAppPool PortalLocalAppPool
# opcional: Remove-Item C:\inetpub\portal-local -Recurse -Force
```

## Notas

- Ambiente: `ASPNETCORE_ENVIRONMENT=Production` no `web.config` do publish.
- SQL: usa a BD configurada em `appsettings.Production.json` (rede acessível a partir do PC).
- Ensaio do cliente: seguir depois [`PASSO_A_PASSO_PRODUCAO.md`](./PASSO_A_PASSO_PRODUCAO.md) / [`GO_LIVE_SEMANA.md`](./GO_LIVE_SEMANA.md).
