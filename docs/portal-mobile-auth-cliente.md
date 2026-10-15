# Portal Mobile — Autenticação de clientes

| | |
| --- | --- |
| Actualizado | 2026-10-15 |
| Ambiente | UAT |

## Isolamento

| | Colaboradores | Clientes |
| --- | --- | --- |
| Cookie | `ls_portal_auth` | `ls_cliente_auth` |
| Scheme | Identity Application | `ClienteCookie` |
| Policy | Default `[Authorize]` | `ClienteAutenticado` |
| Sessão | 8 h sliding | **30 min** sliding |
| Store | `u_HcaLogi*` | `u_HcaClienteAuth` |

Não se usa `CL2.u_passp`.

## Regras de NIF

- `999999990` bloqueado no servidor (login, 1.º acesso, recuperação).
- 0 fichas activas ou várias → mensagem de balcão.
- 1 ficha activa → claims `cl_no` + `cl_estab`.

## Scripts

- `sql/092_create_u_HcaClienteAuth.sql`
- `sql/092b_grant_u_HcaClienteAuth.sql`

## API

Base: `/api/v1/cliente/auth/*` — ver implementação em `ClienteAuthController`.
