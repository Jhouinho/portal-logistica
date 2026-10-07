# Fase 0B — `sp_HCA_validar_login`

> **HISTÓRICO (2026-09-29).** SP ainda usada no gate; fluxo de login actual = Identity + este SP. Ver [`auth-portal-identity.md`](./auth-portal-identity.md).

| | |
| --- | --- |
| Script | [`sql/020_create_sp_HCA_validar_login.sql`](../sql/020_create_sp_HCA_validar_login.sql) |
| Validação | [`sql/021_validate_sp_HCA_validar_login.sql`](../sql/021_validate_sp_HCA_validar_login.sql) |
| Pré-requisito | [`028_add_us_u_usaPort.sql`](../sql/028_add_us_u_usaPort.sql) |

## Objetivo
Exceção técnica: devolver dados de `US` **activo** com **`u_usaPort = 1`** para o login do portal (`US.usercode`). O email devolvido liga à conta Identity.

## Parâmetros
| Param | Tipo | Notas |
| --- | --- | --- |
| `@login` | `varchar(20)` | = `US.usercode` (case-insensitive) |

## Resultado
0 linhas se inválido / inactivo / sem email / `u_usaPort = 0`.

Colunas: `userstamp`, `login`, `nome`, `usrinis`, `email`, `portal_hash` (legado).
