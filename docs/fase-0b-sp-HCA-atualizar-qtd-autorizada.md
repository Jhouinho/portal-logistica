# Fase 0B — `sp_HCA_atualizar_qtd_autorizada`

> **SUPERSEDED nas regras de teto (2026-09-29).**  
> Comportamento actual: SQL [`082_alter_sp_HCA_atualizar_qtd_autorizada_sem_teto_prev.sql`](../sql/082_alter_sp_HCA_atualizar_qtd_autorizada_sem_teto_prev.sql) (PR3-C) + [`068`](../sql/068_alter_sp_HCA_atualizar_qtd_autorizada_prev.sql).  
> **Sem** teto `ST.stock`; **sem** teto previsão; disponibilidade = Previsto − Alocado (pode ser negativa).  
> SoT: [`PROJECT-STATE.md`](./PROJECT-STATE.md) · [`business-flows.md`](./business-flows.md).

| | |
| --- | --- |
| Script original 0B | [`sql/024_create_sp_HCA_atualizar_qtd_autorizada.sql`](../sql/024_create_sp_HCA_atualizar_qtd_autorizada.sql) |
| Validação | [`sql/025_validate_sp_HCA_atualizar_qtd_autorizada.sql`](../sql/025_validate_sp_HCA_atualizar_qtd_autorizada.sql) |
| Evolução actual | `068` → `082` (previsão, sem teto) |

## Objetivo
Gravar `BI.u_qtdaut`, `u_qtdautur`, `u_qtdautdt`.

Na **1.ª** alteração de `u_qtdaut` (detectada por `u_qtdautur` vazio):
1. `u_qttorig ← qtt` actual
2. `qtt ← quantidade autorizada` (+ `ettdeb`)

Alterações seguintes: só `u_qtdaut*`.

## Regras
- Ultrapassar restante: **permitido** (MVP)
- `soma(auth do artigo) > ST.stock` → **erro** (API mapeia 409), salvo confirmação UI (`@permitir_acima_stock`)
- Concorrência opcional: `@valor_anterior_esperado`

## Parâmetros
`@bistamp`, `@quantidade_autorizada`, `@usrlogin`, `@valor_anterior_esperado`, `@permitir_acima_stock`, `@usrinis`

## Nota UAT
Artigo piloto com stock 0: só `@quantidade_autorizada = 0` deve passar (sem confirmação).

## Estado UAT
**Validado** (2026-08-10); regra 1.ª autorização em curso.
