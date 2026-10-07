# Fase 0B — `sp_HCA_alocacao_proporcional`

> **SUPERSEDED na fonte de capacidade (2026-09-29).**  
> Comportamento actual: SQL [`069_alter_sp_HCA_alocacao_proporcional_prev.sql`](../sql/069_alter_sp_HCA_alocacao_proporcional_prev.sql) — `@disponivel` e `ST.stock` **ignorados**; fonte = previsão aberta; `fonteStock` API = `u_HcaPrevEntrada`.  
> SoT: [`PROJECT-STATE.md`](./PROJECT-STATE.md) · [`business-flows.md`](./business-flows.md).

| | |
| --- | --- |
| Script base | [`sql/026_create_sp_HCA_alocacao_proporcional.sql`](../sql/026_create_sp_HCA_alocacao_proporcional.sql) |
| Evolução 0B | [`sql/035_alter_sp_HCA_alocacao_proporcional_disponivel_cor.sql`](../sql/035_alter_sp_HCA_alocacao_proporcional_disponivel_cor.sql) |
| Evolução actual | [`sql/069_alter_sp_HCA_alocacao_proporcional_prev.sql`](../sql/069_alter_sp_HCA_alocacao_proporcional_prev.sql) |
| Validação | [`sql/027_validate_sp_HCA_alocacao_proporcional.sql`](../sql/027_validate_sp_HCA_alocacao_proporcional.sql) · [`sql/035b_validate_sp_HCA_alocacao_proporcional.sql`](../sql/035b_validate_sp_HCA_alocacao_proporcional.sql) |



## Objetivo

Apêndice B: distribuir quantidade disponível pelas linhas abertas do artigo em `BI.u_qtdaut*`.



## Parâmetros

| Param | Notas |

| --- | --- |

| `@ref` | Artigo |

| `@usrlogin` | Obrigatório se `@simular = 0` |

| `@simular` | `1` = pré-visualizar; `0` = gravar `u_qtdaut*` |

| `@disponivel` | Opcional. Se NULL → usa `ST.stock`. Senão usa o valor indicado (`max(0, @disponivel)`); stock PHC é só referência |

| `@cor` | Usado só se `@filtrar_cor = 1` (`''` = linhas sem cor) |

| `@filtrar_cor` | `0` = todas as cores do `ref`; `1` = filtrar por `@cor` |



## Algoritmo

`disponivel_usado` (tecto stock); proporção por restante; `floor` + distribuição da sobra; `min(auth, restante)`.



## Resultsets

1. Cabeçalho: `ref`, `stock_disponivel`, `disponivel_usado`, `simular`, `soma_proposta`

2. Linhas: `bistamp`, `bostamp`, `obrano`, `dataobra`, `quantidade_por_satisfazer`, `bruto`, `quantidade_proposta`



## Estado UAT

**Validado** (2026-08-10) — `@simular = 1` (stock 0)  

**Actualizado** (2026-09-02) — `@disponivel` / `@filtrar_cor` via script `035`



Nota: `@simular = 0` com stock > 0 para testes com dados reais.


