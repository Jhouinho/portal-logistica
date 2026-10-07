# Portal API — Liliana & Seródio

## Arranque (dev)

```powershell
cd src/backend
dotnet user-secrets init --project src/Portal.Api
dotnet user-secrets set "Phc:ConnectionString" "Server=...;Database=...;User Id=portal_app;Password=...;TrustServerCertificate=True;" --project src/Portal.Api
dotnet run --project src/Portal.Api
```

Swagger: http://localhost:5080/swagger

## Auth (cookie)

| Método | Caminho |
| --- | --- |
| POST | `/api/v1/auth/login` `{ "utilizador", "password" }` |
| POST | `/api/v1/auth/logout` |
| GET | `/api/v1/auth/me` |

Sem JWT. PasswordHasher + `sp_HCA_validar_login`.

`SerieEncomendasNdos` default = **1** (`Phc:SerieEncomendasNdos`).
