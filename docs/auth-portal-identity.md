# Autenticação — ASP.NET Identity (`u_HcaLogi*`) + `US.u_usaPort`

| | |
| --- | --- |
| Identity | Email/password em tabelas `u_HcaLogi*` (mesma BD PHC / `Phc:ConnectionString`) |
| Gate PHC | `US.email` + `inactivo = 0` + **`u_usaPort = 1`** |
| Sessão | Cookie Identity (`ls_portal_auth`) |
| Estado operacional | [`PROJECT-STATE.md`](./PROJECT-STATE.md) |
| Actualizado | 2026-09-29 |

## Scripts SQL (fonte oficial)

| Script | Função |
| --- | --- |
| [`sql/028_add_us_u_usaPort.sql`](../sql/028_add_us_u_usaPort.sql) | Campo `US.u_usaPort bit` |
| [`sql/029_create_u_HcaLogi_identity_tables.sql`](../sql/029_create_u_HcaLogi_identity_tables.sql) | **CREATE** das 7 tabelas `u_HcaLogi*` + `__EFMigrationsHistory` |
| [`sql/029b_validate_u_HcaLogi_identity_tables.sql`](../sql/029b_validate_u_HcaLogi_identity_tables.sql) | Validação |
| [`sql/010`](../sql/010_create_view_HCA_utilizadores.sql) / [`sql/020`](../sql/020_create_sp_HCA_validar_login.sql) | Vista/SP login com `u_usaPort = 1` |
| [`sql/031`](../sql/031_create_sp_HCA_listar_utilizadores_admin.sql) | Lista US activos para Administração |
| [`sql/031b`](../sql/031b_validate_sp_HCA_listar_utilizadores_admin.sql) | Validação do SP listar |
| [`sql/032`](../sql/032_create_sp_HCA_actualizar_usa_port.sql) | Actualiza `u_usaPort` por email |
| [`sql/032b`](../sql/032b_validate_sp_HCA_actualizar_usa_port.sql) | Validação do SP actualizar (email inexistente) |
| [`sql/033`](../sql/033_seed_role_Admin.sql) | **Seed** role `Admin` + atribuição ao Identity do `sa` |
| [`sql/033b`](../sql/033b_validate_role_Admin.sql) | Validação role/admins |
| [`sql/030`](../sql/030_grant_portal_app.sql) | Grants (inclui SPs admin + tabelas Identity) |

Guia passo a passo: [`fase-0b-u-HcaLogi-identity-tables.md`](./fase-0b-u-HcaLogi-identity-tables.md)

A API pode aplicar a mesma schema via EF `Migrate()` no arranque; o script `029` evita duplicar se já registado em `__EFMigrationsHistory`.

## Tabelas

| Tabela | Conteúdo |
| --- | --- |
| `u_HcaLogiUsers` | Utilizadores Identity |
| `u_HcaLogiRoles` | Roles (`Admin`, …) |
| `u_HcaLogiUserRoles` | User–Role |
| `u_HcaLogiUserClaims` | Claims |
| `u_HcaLogiUserLogins` | Logins externos (não usados no MVP) |
| `u_HcaLogiUserTokens` | Tokens |
| `u_HcaLogiRoleClaims` | Role claims |

## Endpoints

| Método | Rota | Função |
| --- | --- | --- |
| POST | `/api/v1/auth/login` | `{ login, password }` → cookie (+ roles); `login` = `US.usercode` |
| POST | `/api/v1/auth/logout` | Limpa cookie |
| GET | `/api/v1/auth/me` | `{ login, nome, isAdmin }` |
| POST | `/api/v1/auth/definir-password` | Anónimo — 1.º acesso / reset via token de convite |
| GET | `/api/v1/admin/utilizadores` | Lista US + estado Identity/roles (`[Authorize(Roles=Admin)]`) |
| POST | `/api/v1/admin/utilizadores/acesso` | `u_usaPort=1`, ensure Identity sem password, devolve link |
| POST | `/api/v1/admin/utilizadores/revogar` | `u_usaPort=0` (+ lockout Identity) |
| POST | `/api/v1/admin/utilizadores/reenviar-convite` | Alias de reset-password |
| POST | `/api/v1/admin/utilizadores/reset-password` | Remove password actual + novo link `/definir-password` |
| POST / DELETE | `/api/v1/admin/utilizadores/admin` | Atribuir / remover role `Admin` (impede remover o último) |

## Perfil Admin

- Role Identity `Admin` em `u_HcaLogiRoles`.
- Fonte SQL: [`033_seed_role_Admin.sql`](../sql/033_seed_role_Admin.sql) (idempotente). A API (`PortalIdentitySeed`) faz o mesmo no arranque se a connection string estiver configurada — **não substitui** o script para UAT/Produção via SSMS.
- Atribuição piloto: Identity ligado ao PHC `US.usercode = sa` (por `Usercode` ou email).
- UI `/administracao` e menu Administração só para `isAdmin`.
- SPA pública: `/definir-password?email=…&token=…` (token Base64Url do Identity `ResetPassword`).
- `Portal:SpaBaseUrl` em appsettings define o host do link de convite.

## Activar acesso (admin na UI ou API)

1. Admin escolhe um `US` activo da lista.
2. `POST …/acesso` → `u_usaPort = 1` + cria `u_HcaLogiUsers` **sem** password (se ainda não existir).
3. Admin copia o `definirPasswordUrl` e entrega-o ao utilizador (sem SMTP no MVP).
4. Utilizador define password em `/definir-password` → `POST /auth/definir-password`.
5. Login normal com email/password.

## Activar acesso PHC (SQL manual)

```sql
UPDATE dbo.us SET u_usaPort = 1
WHERE LOWER(LTRIM(RTRIM(email))) = LOWER(N'seu@email.pt');
```

## Criar 1º utilizador (UAT)

Ver [`tools/criar-utilizador-portal/README.md`](../tools/criar-utilizador-portal/README.md).
