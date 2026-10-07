# Fase 0B — `sp_HCA_atualizar_linha_qtt_preco`

> **HISTÓRICO (2026-09-29).** Objecto 0B (RN-020/021). SoT: [`PROJECT-STATE.md`](./PROJECT-STATE.md).

| | |
| --- | --- |
| Script | [`sql/022_create_sp_HCA_atualizar_linha_qtt_preco.sql`](../sql/022_create_sp_HCA_atualizar_linha_qtt_preco.sql) |
| Validação | [`sql/023_validate_sp_HCA_atualizar_linha_qtt_preco.sql`](../sql/023_validate_sp_HCA_atualizar_linha_qtt_preco.sql) |

## Objetivo
RN-020 / RN-021: quantidade e/ou preço; originais; `usr*`; totais.

## Parâmetros
| Param | Notas |
| --- | --- |
| `@bistamp` | Linha |
| `@quantidade` | Opcional (RN-020) |
| `@preco` | Opcional → `edebito` (RN-021) |
| `@usrinis` | Iniciais (máx. 3) |
| `@qtt_anterior_esperado` / `@preco_anterior_esperado` | Concorrência opcional |

## Totais (equiv. BOTOTS MVP — UAT Liliana)

- **Total da linha = `BI.ettdeb`** (confirmado cliente)
- Fórmula SP: `ettdeb = ROUND(qtt * edebito, 2)`
- `BI.etiliquido` **não existe** nesta BD
- Cabeçalho `BO`: por agora só `usr*`; totais de documento após `023a` se necessário

## Estado UAT
**Validado** (2026-08-10)

| Teste | Resultado |
| --- | --- |
| RN-020 | `u_qttorig` 0 → 1.00; `usrhora` atualizado |
| RN-021 | `u_prcorig` → 20.00; `edebito` → 19.50; `ettdeb` → 19.50 |
| BO `usr*` | Atualizado (`ADM` / 17:51:02) |
