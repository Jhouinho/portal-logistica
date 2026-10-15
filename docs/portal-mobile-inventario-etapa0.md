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
| `BI.u_cor` | Existe |
| Tabela `sfcor` | Existe (`cor`, `nome`, `marcada`); **0 linhas** |
| Cores em uso em `BI.u_cor` | Ex.: Azul, Vermelha, Castanha, Branco, … |
| `ST` preços | `epv1`..`epv5`, `design`, `ref`, `stock` |
| NIF duplicados | 14 (ver auditoria anterior); `999999990` ×4 |

## Fonte de cores (decisão técnica)

1. Preferir `dbo.sfcor` (`cor` / `nome`) quando houver linhas.
2. Se `sfcor` estiver vazia: fallback `DISTINCT` de `BI.u_cor` não vazio (lista operacional observada), documentado como provisório até o negócio preencher `sfcor`.

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
