# Fase 0B — Criação da view_HCA_encomendas_abertas

> **HISTÓRICO (2026-09-29).** Objecto 0B. SoT operacional: [`PROJECT-STATE.md`](./PROJECT-STATE.md).

| | |
| --- | --- |
| Projeto | Liliana & Seródio — Portal de Logística |
| Objeto | `dbo.view_HCA_encomendas_abertas` |
| Script | [`sql/012_create_view_HCA_encomendas_abertas.sql`](../sql/012_create_view_HCA_encomendas_abertas.sql) |
| Validação | [`sql/013_validate_view_HCA_encomendas_abertas.sql`](../sql/013_validate_view_HCA_encomendas_abertas.sql) |
| Fonte | [ARCHITECTURE.md](../ARCHITECTURE.md) · [sql/002_views_and_procedures.md](../sql/002_views_and_procedures.md) |

---

## 1. Objetivo

A vista lista **encomendas em aberto** para o Portal Logístico: uma linha por documento (`BO`), com totais agregados das linhas `BI` ainda por satisfazer.

A API .NET lê esta vista via **Dapper** (`GET /encomendas/abertas`). Não escreve em `BO`/`BI`. Stock por artigo (`ST.stock`) e detalhe de linhas ficam noutras vistas.

---

## 2. Ambiente

| Campo | Valor |
| --- | --- |
| Servidor SQL | *(preencher)* |
| Base de dados | *(preencher)* |
| Ambiente | Teste / UAT / Produção — **trabalhar só em Teste/UAT até GO formal** |
| Data de execução | *(preencher)* |
| Executado por | *(preencher)* |
| Validado por | *(preencher)* |

---

## 3. Pré-requisitos

- [x] Campos BI já criados: `u_prcorig`, `u_qttorig`, `u_qtdautdt`, `u_qtdaut`, `u_qtdautur`
- [x] `view_HCA_utilizadores` já criada e validada em UAT
- [x] Tabelas `BO` e `BI` confirmadas
- [x] `BO.ndos = 1` confirmado como série de encomendas
- [x] Permissões para criar views na base de dados teste/UAT
- [x] Script `012` executado em UAT
- [x] Script `013` validado em UAT

---

## 4. Campos de Utilizador Relevantes

### `BI.u_qttorig`

| | |
| --- | --- |
| Tipo | `numeric(16,2) NOT NULL` |
| Uso | Quantidade originalmente encomendada antes de alteração do portal |
| Regra | **0** significa “ainda não preenchido” |

### `BI.u_qtdaut`

| | |
| --- | --- |
| Tipo | `numeric(16,2) NOT NULL` |
| Uso | Quantidade autorizada para expedição |

### `BI.u_qtdautur`

| | |
| --- | --- |
| Tipo | `varchar(100) NOT NULL` |
| Uso | Utilizador que alterou a quantidade autorizada |

### `BI.u_qtdautdt`

| | |
| --- | --- |
| Tipo | `datetime NOT NULL` |
| Uso | Data/hora da alteração da quantidade autorizada |

`BI.u_prcorig` existe na tabela (RN-021) mas **não** entra nesta vista agregada de cabeçalho.

---

## 5. Fórmula de Restante

```text
ISNULL(NULLIF(BI.u_qttorig, 0), BI.qtt) - BI.qtt2
```

- Se `u_qttorig = 0`, a quantidade original considerada é `BI.qtt`.
- Se `u_qttorig <> 0`, a quantidade original considerada é `BI.u_qttorig`.
- O restante subtrai `BI.qtt2` (já fornecida).
- Só entram linhas com **restante > 0**; o documento só aparece se tiver pelo menos uma dessas linhas e `fecho = 0`.

---

## 6. Script executado

Ficheiro: [`../sql/012_create_view_HCA_encomendas_abertas.sql`](../sql/012_create_view_HCA_encomendas_abertas.sql)

```sql
CREATE OR ALTER VIEW dbo.view_HCA_encomendas_abertas
AS
SELECT
    bo.bostamp,
    bo.obrano,
    bo.ndos,
    bo.nmdos,
    bo.dataobra,
    bo.ousrhora,
    bo.no AS cliente_no,
    bo.estab AS cliente_estab,
    LTRIM(RTRIM(bo.nome)) AS cliente_nome,

    COUNT(bi.bistamp) AS total_linhas,

    SUM(ISNULL(NULLIF(bi.u_qttorig, 0), bi.qtt)) AS quantidade_original_total,

    SUM(bi.qtt) AS quantidade_atual_total,

    SUM(bi.qtt2) AS quantidade_fornecida_total,

    SUM(ISNULL(NULLIF(bi.u_qttorig, 0), bi.qtt) - bi.qtt2) AS quantidade_restante_total,

    SUM(bi.u_qtdaut) AS quantidade_autorizada_total

FROM dbo.bo bo WITH (NOLOCK)
INNER JOIN dbo.bi bi WITH (NOLOCK)
    ON bi.bostamp = bo.bostamp
WHERE bo.ndos = 1
  AND ISNULL(bo.fecho, 0) = 0
  AND (ISNULL(NULLIF(bi.u_qttorig, 0), bi.qtt) - bi.qtt2) > 0
GROUP BY
    bo.bostamp,
    bo.obrano,
    bo.ndos,
    bo.nmdos,
    bo.dataobra,
    bo.ousrhora,
    bo.no,
    bo.estab,
    bo.nome;
GO
```

---

## 7. Regras aplicadas

- Apenas documentos com `BO.ndos = 1`
- Apenas documentos com `ISNULL(BO.fecho, 0) = 0`
- Apenas linhas com restante `> 0`
- Agregação por encomenda (`GROUP BY` cabeçalho `BO`)
- Representante / vendedor / `vendnm`: **fora de âmbito** — sem filtro funcional
- Sem join a `CL` / `ST` nesta vista (stock por artigo na vista de linhas / rastreio)

---

## 8. Validação

Ficheiro: [`../sql/013_validate_view_HCA_encomendas_abertas.sql`](../sql/013_validate_view_HCA_encomendas_abertas.sql)

Verificar:

| # | Query | Esperado |
| --- | --- | --- |
| 1 | `SELECT TOP 50 * … ORDER BY dataobra DESC` | Encomendas recentes com colunas agregadas |
| 2 | `COUNT(*)` | Número de encomendas abertas |
| 3 | `GROUP BY ndos` | Apenas `ndos = 1` |
| 4 | `WHERE quantidade_restante_total <= 0` | **0 linhas** |
| 5 | Detalhe por `@bostamp` | Totais da vista coerentes com linhas `BI` |

Checklist de coerência:

- [x] Só aparecem encomendas da série 1
- [x] Só aparecem encomendas abertas (`fecho = 0`)
- [x] `quantidade_restante_total` é positiva
- [x] `total_linhas` é coerente com linhas em aberto do documento
- [x] `quantidade_autorizada_total` soma `BI.u_qtdaut` das linhas incluídas
- [x] Fórmula do restante está correta face ao detalhe `BI`

---

## 9. Resultado esperado

A vista devolve **uma linha por encomenda aberta**, com totais agregados e quantidade restante calculada com base em `u_qttorig` quando aplicável (sentinel **0** = usar `qtt`).

Colunas: `bostamp`, `obrano`, `ndos`, `nmdos`, `dataobra`, `ousrhora`, `cliente_no`, `cliente_estab`, `cliente_nome`, `total_linhas`, `quantidade_original_total`, `quantidade_atual_total`, `quantidade_fornecida_total`, `quantidade_restante_total`, `quantidade_autorizada_total`.

---

## 10. Permissões SQL

```sql
GRANT SELECT ON dbo.view_HCA_encomendas_abertas TO [NOME_UTILIZADOR_SQL_APP];
```

Substituir `[NOME_UTILIZADOR_SQL_APP]` pelo login SQL real da aplicação **antes** de executar em Produção. Em UAT, usar o user da app de teste.

---

## 11. Repetição em Produção

**Política:** só após implementação completa e **GO formal**.

- [ ] Confirmar backup / janela de intervenção
- [ ] Confirmar campos BI existem
- [ ] Confirmar `BO.ndos = 1`
- [ ] Executar `sql/012_create_view_HCA_encomendas_abertas.sql`
- [ ] Executar `sql/013_validate_view_HCA_encomendas_abertas.sql`
- [ ] Confirmar resultados
- [ ] Aplicar `GRANT SELECT` ao utilizador SQL da aplicação
- [ ] Registar data/hora de execução
- [ ] Registar responsável

---

## 12. Rollback

```sql
DROP VIEW dbo.view_HCA_encomendas_abertas;
```

Executar apenas se for necessário remover a vista. A vista é **apenas leitura** e não altera dados PHC.

---

## 13. Estado

| Campo | Valor |
| --- | --- |
| Estado em Teste/UAT | **Validado** (2026-08-10) |
| Estado em Produção | **Pendente** (só no fim da implementação / GO formal) |
| Observações | Criação + validação OK em UAT; Produção diferida |
