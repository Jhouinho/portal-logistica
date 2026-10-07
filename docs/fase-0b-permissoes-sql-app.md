# Fase 0B — Permissões SQL da aplicação

> **HISTÓRICO (2026-09-29).** Grants 0B; evoluir com objectos novos (Identity, previsão). SoT: [`PROJECT-STATE.md`](./PROJECT-STATE.md).

| | |
| --- | --- |
| Script | [`sql/030_grant_portal_app.sql`](../sql/030_grant_portal_app.sql) |
| Ambiente | **UAT** primeiro · Produção só no GO formal |
| Princípio | App só `SELECT` em `view_HCA_*` e `EXECUTE` em `sp_HCA_*` |

---

## 1. Criar login SQL (não usar `sa`)

No SSMS (UAT), como administrador:

```sql
USE [master];
CREATE LOGIN [portal_app] WITH PASSWORD = N'TROCAR_PASSWORD_FORTE', CHECK_POLICY = ON;

USE [NOME_BD_PHC_UAT];  -- nome real da BD
CREATE USER [portal_app] FOR LOGIN [portal_app];
```

Guardar a password no secret store / User Secrets da API — **não** no repositório.

---

## 2. Conceder permissões

1. Abrir [`030_grant_portal_app.sql`](../sql/030_grant_portal_app.sql).
2. Substituir `[portal_app]` se o nome do user for outro.
3. Executar na BD PHC UAT.

---

## 3. Validar

```sql
-- Como portal_app (ou via EXECUTE AS)
EXECUTE AS USER = 'portal_app';
SELECT TOP 1 login FROM dbo.view_HCA_utilizadores;
EXEC dbo.sp_HCA_validar_login @login = N'sa';
REVERT;
```

Confirmar que `SELECT` directo a `dbo.us` / `dbo.bo` **falha** (sem permissão) — desejável.

---

## 4. Connection string (API)

```text
Server=...;Database=...;User Id=portal_app;Password=...;TrustServerCertificate=True;
```

User Secrets / variáveis de ambiente — nunca `appsettings.json` com password real.

---

## Estado

| Campo | Valor |
| --- | --- |
| Script | Criado |
| Execução UAT | Pendente (criar login + correr `030`) |
| Produção | Pendente (GO formal) |
