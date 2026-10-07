# Fase 0B — Procedimentos `sp_HCA_*`

> **HISTÓRICO (2026-09-29).** Hub 0B. Regras de teto `ST.stock` em SPs de autorização/alocação estão **supersedidas** (`068`/`069`/`082` + previsão). SoT: [`PROJECT-STATE.md`](./PROJECT-STATE.md).

| | |
| --- | --- |
| Projeto | Liliana & Seródio — Portal de Logística |
| Política BD | **Só UAT** até GO formal em Produção |
| Catálogo | [`sql/002_views_and_procedures.md`](../sql/002_views_and_procedures.md) |

---

## Estado

| Procedimento | Scripts | Estado UAT | Estado Prod |
| --- | --- | --- | --- |
| `sp_HCA_validar_login` | [`020`](../sql/020_create_sp_HCA_validar_login.sql) · [`021`](../sql/021_validate_sp_HCA_validar_login.sql) | **Validado** (2026-08-10) | Pendente |
| `sp_HCA_atualizar_linha_qtt_preco` | [`022`](../sql/022_create_sp_HCA_atualizar_linha_qtt_preco.sql) · [`023`](../sql/023_validate_sp_HCA_atualizar_linha_qtt_preco.sql) | **Validado** (2026-08-10) | Pendente |
| `sp_HCA_atualizar_qtd_autorizada` | [`024`](../sql/024_create_sp_HCA_atualizar_qtd_autorizada.sql) · [`025`](../sql/025_validate_sp_HCA_atualizar_qtd_autorizada.sql) | **Validado** (2026-08-10) | Pendente |
| `sp_HCA_alocacao_proporcional` | [`026`](../sql/026_create_sp_HCA_alocacao_proporcional.sql) · [`027`](../sql/027_validate_sp_HCA_alocacao_proporcional.sql) | **Validado** (2026-08-10) | Pendente |

**Catálogo MVP de procedimentos completo em UAT** (2026-08-10). Produção diferida até GO formal.

---

## Ordem recomendada em UAT

1. **`020` + `021`** — só leitura (seguro). Substituir `COLOCAR_USERCODE_PILOTO`.
2. **`022`**: criar SP → correr **só a secção 0** do `023` (colunas `bo.etotal` / `bo.eboiva`). Se falharem nomes, reportar antes do EXEC que altera dados.
3. **`024` + `025`**: com stock 0 no artigo piloto, testar `@quantidade_autorizada = 0`; valores `> 0` devem falhar por stock.
4. **`026` + `027`**: primeiro `@simular = 1` (não grava); só depois `@simular = 0` se stock > 0.

---

## Resumo funcional

### `sp_HCA_validar_login`
Exceção técnica. Devolve dados de `US` activo com **`u_usaPort = 1`** por `@email` (gate após Identity).

### `sp_HCA_atualizar_linha_qtt_preco`
RN-020/021 + `usr*` BI/BO + `ettdeb = qtt * edebito`. Sem `etiliquido` nesta BD — totais BO após [`023a`](../sql/023a_discover_totais_BI_BO.sql).

### `sp_HCA_atualizar_qtd_autorizada`
`u_qtdaut*` + validação `sum(auth) ≤ ST.stock`. Ultrapassar restante permitido.

### `sp_HCA_alocacao_proporcional`
Apêndice B. `@simular=1` pré-visualiza; `@simular=0` grava.

---

## Rollback

```sql
DROP PROCEDURE dbo.sp_HCA_validar_login;
DROP PROCEDURE dbo.sp_HCA_atualizar_linha_qtt_preco;
DROP PROCEDURE dbo.sp_HCA_atualizar_qtd_autorizada;
DROP PROCEDURE dbo.sp_HCA_alocacao_proporcional;
```

---

## Guias detalhados

- [fase-0b-sp-HCA-validar-login.md](./fase-0b-sp-HCA-validar-login.md)
- [fase-0b-sp-HCA-atualizar-linha-qtt-preco.md](./fase-0b-sp-HCA-atualizar-linha-qtt-preco.md)
- [fase-0b-sp-HCA-atualizar-qtd-autorizada.md](./fase-0b-sp-HCA-atualizar-qtd-autorizada.md)
- [fase-0b-sp-HCA-alocacao-proporcional.md](./fase-0b-sp-HCA-alocacao-proporcional.md)
