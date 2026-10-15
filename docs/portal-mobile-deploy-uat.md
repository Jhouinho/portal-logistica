# Portal Mobile — Deploy UAT (sem produção)

## Pré-requisitos SQL (UAT)

Aplicar por ordem:

1. `091_create_sp_HCA_criar_pedido_mobile.sql` (se ainda não aplicado)
2. `091c_grant_sp_HCA_criar_pedido_mobile.sql`
3. `092_create_u_HcaClienteAuth.sql` + `092b_grant_u_HcaClienteAuth.sql`
4. `093_alter_sp_HCA_criar_pedido_mobile_cor.sql`
5. `094_create_u_HcaPedidoMobileCancel.sql`

## API / IIS

- Mesmo site do portal logístico.
- Percurso UI: `/cliente` (SPA).
- API: `/api/v1/cliente/*` com cookie `ls_cliente_auth`.
- Config: `Portal:Cliente:StockBaixoLimiar` (null = aviso desligado), `PedidoMobileNdos=67`.
- Em Production: preferir `CookieSecurePolicy.Always` para o cookie cliente.

## Pendências que impedem “pronto para produção”

- Autorização explícita de produção.
- B05 número definitivo; B06–B08 Cópia de Dossier / estados 3–4.
- Limiar de stock; preenchimento de `sfcor` (fallback actual = `BI.u_cor`).
