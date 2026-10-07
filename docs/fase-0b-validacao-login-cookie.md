# Validação login cookie (Sprint 1 / GO item 6)

> **HISTÓRICO (2026-09-29).** Fluxo 0B com `u_portalph`. Auth actual: [`auth-portal-identity.md`](./auth-portal-identity.md). SoT: [`PROJECT-STATE.md`](./PROJECT-STATE.md).

| | |
| --- | --- |
| Piloto UAT | `sa` / `usrinis=ADM` (hash em `u_portalph`) |
| API | `src/backend` — http://localhost:5080 |
| SPA | `src/frontend` — http://localhost:5173 |
| Pré-requisito SQL | UAT: `sa` OK; produção: `portal_app` + [`030`](../sql/030_grant_portal_app.sql) |
| Validado | **2026-08-10** — cookie `ls_portal_auth` + piloto `sa` |

---

## Passos

1. Executar GRANTs ([fase-0b-permissoes-sql-app.md](./fase-0b-permissoes-sql-app.md)).
2. Configurar connection string:

```powershell
cd src/backend
dotnet user-secrets set "Phc:ConnectionString" "Server=...;Database=...;User Id=portal_app;Password=...;TrustServerCertificate=True;" --project src/Portal.Api
dotnet run --project src/Portal.Api
```

3. Frontend (requer Node.js):

```powershell
cd src/frontend
npm install
npm run dev
```

4. Abrir http://localhost:5173/login — entrar com `sa` + password do hash.
5. Confirmar cookie `ls_portal_auth`, redirecionamento ao Painel, `GET /api/v1/auth/me`.
6. Terminar sessão e confirmar que rotas internas pedem login de novo.

## Swagger (alternativa sem UI)

`POST /api/v1/auth/login` com body `{ "utilizador": "sa", "password": "..." }` — response com `Set-Cookie`.

## Estado

| Item | Estado |
| --- | --- |
| Scaffold API + SPA | **Criado** |
| Validação cookie em UAT | **Validado** (2026-08-10) — piloto `sa` |

Checklist GO #6 e “Validar hash + login cookie” marcados.
