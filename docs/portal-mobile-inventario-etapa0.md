# Portal Mobile — Inventário Etapa 0 (leitura)

| | |
| --- | --- |
| Actualizado | 2026-10-15 |
| Ambiente | UAT (`Phc__ConnectionString`) |

## AllowAnonymous (B10)

| Local | Rota / hub | Nota |
| --- | --- | --- |
| `AuthController` | `POST login`, `POST definir-password` | Staff — esperado |
| `EncomendasController` | 2 acções | TV / painel — existente |
| `PickingDossiersController` | 2 acções | TV / painel — existente |
| `PainelController` | 2 acções | TV pública |
| `TvHub` | SignalR | Anónimo |

Percurso `/cliente/*` e `/api/v1/cliente/*` **não** devem usar estes endpoints; APIs cliente usam scheme `ClienteCookie`.

## Metadados PHC

| Item | Resultado UAT |
| --- | --- |
| `BI.u_cor` | Existe — **fonte de persistência** da cor no pedido mobile (`varchar(100)`) |
| `BI.cor` | Nativo; **não** usado pelo Portal Mobile |
| Tabela `sfcor` | Existe no PHC; **não** usada pelo Portal Mobile |
| `ST` preços | `epv1`..`epv5`, `design`, `ref`, `stock` |
| NIF duplicados | 14 (ver auditoria anterior); `999999990` ×4 |

## Cor no Portal Mobile (decisão funcional)

1. Seleção: **texto livre** na UI (sem catálogo, sem `sfcor`, sem lista de opções).
2. Persistência e leitura: apenas `BI.u_cor`.
3. Cor vazia: permitida (string vazia após trim), alinhada ao comportamento actual da SP.

## Scripts a criar / alterar

| Script | Função |
| --- | --- |
| `092_create_u_HcaClienteAuth.sql` | Credenciais cliente |
| `092b_grant_u_HcaClienteAuth.sql` | GRANT |
| `093_alter_sp_HCA_criar_pedido_mobile_cor.sql` | TVP + `BI.u_cor` |
| `094_create_u_HcaPedidoMobileCancel.sql` | Cancelamento portal |
| Actualizar `091b` / testes cor | UAT |

## Gaps de código (confirmados)

Sem auth cliente, rotas `/cliente`, API mobile, cor na SP 091, histórico/cancel mobile.
