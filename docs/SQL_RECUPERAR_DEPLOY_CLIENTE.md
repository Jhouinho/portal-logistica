# Recuperar deploy SQL no cliente (erros Msg 207 / portal_app / BOM)

## O que aconteceu

O ficheiro `DEPLOY_CLIENTE_COMPLETO.sql` inclui scripts antigos (`012`…`040`) que leem `BI.u_qttorig`, `BO.u_upickrdr`, etc. No PHC CS do cliente os campos estão em **`BI2` / `BO3`** (`u_pickrdr` / `u_pickrdt`). Daí:

| Erro | Causa |
| --- | --- |
| `Invalid column name 'u_qttorig'` (e afins) | Script legado aponta a `BI`/`BO` em vez de `BI2`/`BO3` |
| `Cannot find the user 'portal_app'` | Login/user SQL da app ainda não criado |
| `Incorrect syntax near '﻿'` | BOM UTF-8 a meio do pack antigo |
| `sp_HCA_reabrir_expedicao_dossier` inexistente | Cascata: scripts anteriores falharam |

Avisos de índice Identity (900 bytes) são esperados e **não** bloqueiam.

## O que fazer agora (ordem)

1. **Backup** da BD PHC.
2. Correr [`sql/000_verificar_campos_bi2_bo3.sql`](../sql/000_verificar_campos_bi2_bo3.sql) — todos os `bytes` devem ser NOT NULL.
3. Editar e correr [`sql/000_criar_login_portal_app.sql`](../sql/000_criar_login_portal_app.sql) (`NOME_BD_PHC` + password).
4. Correr **[`sql/DEPLOY_CLIENTE_BI2_BO3.sql`](../sql/DEPLOY_CLIENTE_BI2_BO3.sql)** (não o pack “COMPLETO”).
5. Confirmar: `SELECT OBJECT_ID('dbo.view_HCA_encomendas_abertas'), OBJECT_ID('dbo.sp_HCA_reabrir_expedicao_dossier');`
6. Utilizador Identity + `US.u_usaPort = 1`.

O pack BI2/BO3 é `CREATE OR ALTER` / idempotente — pode reexecutar após falhas parciais.

## Não usar

- `DEPLOY_CLIENTE_COMPLETO.sql` em BD com campos já em BI2/BO3
- `090_seed_clone_encomendas_teste.sql` em produção
