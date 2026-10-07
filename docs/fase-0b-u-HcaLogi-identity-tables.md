# Fase 0B — Tabelas Identity `u_HcaLogi*`

> Guia de criação Identity — **ainda válido**. Estado operacional: [`PROJECT-STATE.md`](./PROJECT-STATE.md) · resumo: [`auth-portal-identity.md`](./auth-portal-identity.md).

| | |
| --- | --- |
| Script criação | [`sql/029_create_u_HcaLogi_identity_tables.sql`](../sql/029_create_u_HcaLogi_identity_tables.sql) |
| Validação | [`sql/029b_validate_u_HcaLogi_identity_tables.sql`](../sql/029b_validate_u_HcaLogi_identity_tables.sql) |
| Auth overview | [`auth-portal-identity.md`](./auth-portal-identity.md) |
| EF migration | `InitialIdentityHcaLogi` (Portal.Infrastructure) |

## Objetivo

Criar na **mesma BD PHC** as tabelas ASP.NET Core Identity com nomes físicos `u_HcaLogi*`.

A API também pode aplicar a migration no arranque (`Database.Migrate()`). O script `029` é a fonte SQL versionada para UAT/Produção (SSMS) e regista `__EFMigrationsHistory` para não duplicar.

## Ordem

1. [`028_add_us_u_usaPort.sql`](../sql/028_add_us_u_usaPort.sql)
2. **`029_create_u_HcaLogi_identity_tables.sql`**
3. `010` / `020` (vista e SP de login com `u_usaPort`)
4. Criar utilizador piloto: [`tools/criar-utilizador-portal`](../tools/criar-utilizador-portal/README.md)
5. Administração: `031` / `032` (SPs) + [`033_seed_role_Admin.sql`](../sql/033_seed_role_Admin.sql)
6. Grants: [`030_grant_portal_app.sql`](../sql/030_grant_portal_app.sql)

## Catálogo de tabelas

| Tabela | Função |
| --- | --- |
| `u_HcaLogiUsers` | Utilizadores (email, `PasswordHash`, `UsStamp`, `Usercode`) |
| `u_HcaLogiRoles` | Roles |
| `u_HcaLogiUserRoles` | Associação user–role |
| `u_HcaLogiUserClaims` | Claims do utilizador |
| `u_HcaLogiUserLogins` | Logins externos (não usados no MVP) |
| `u_HcaLogiUserTokens` | Tokens |
| `u_HcaLogiRoleClaims` | Claims da role |

## Colunas principais — `u_HcaLogiUsers`

| Coluna | Tipo | Notas |
| --- | --- | --- |
| `Id` | `nvarchar(450)` | PK Identity |
| `Email` / `NormalizedEmail` | `nvarchar(256)` | Login (= `US.email`) |
| `PasswordHash` | `nvarchar(max)` | Hash Identity |
| `UsStamp` | `nvarchar(25)` | PHC `US.usstamp` (preenchido no login) |
| `Usercode` | `nvarchar(20)` | PHC `US.usercode` |
| `Lockout*` / `AccessFailedCount` | — | Lockout Identity |

## Rollback (cuidado — apaga dados Identity)

```sql
DROP TABLE IF EXISTS dbo.u_HcaLogiRoleClaims;
DROP TABLE IF EXISTS dbo.u_HcaLogiUserClaims;
DROP TABLE IF EXISTS dbo.u_HcaLogiUserLogins;
DROP TABLE IF EXISTS dbo.u_HcaLogiUserRoles;
DROP TABLE IF EXISTS dbo.u_HcaLogiUserTokens;
DROP TABLE IF EXISTS dbo.u_HcaLogiRoles;
DROP TABLE IF EXISTS dbo.u_HcaLogiUsers;
DELETE FROM dbo.__EFMigrationsHistory
WHERE MigrationId = N'20260811092935_InitialIdentityHcaLogi';
```
