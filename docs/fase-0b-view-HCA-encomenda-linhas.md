# Fase 0B — Criação da view_HCA_encomenda_linhas

> **HISTÓRICO (2026-09-29).** Criação 0B. Disponibilidade operacional na API/UI = **previsão** (não `ST.stock` / RN-018 deste doc). SoT: [`PROJECT-STATE.md`](./PROJECT-STATE.md).

| | |
| --- | --- |
| Projeto | Liliana & Seródio — Portal de Logística |
| Objeto | `dbo.view_HCA_encomenda_linhas` |
| Script | [`sql/014_create_view_HCA_encomenda_linhas.sql`](../sql/014_create_view_HCA_encomenda_linhas.sql) |
| Validação | [`sql/015_validate_view_HCA_encomenda_linhas.sql`](../sql/015_validate_view_HCA_encomenda_linhas.sql) |
| Fonte | [ARCHITECTURE.md](../ARCHITECTURE.md) · [sql/002_views_and_procedures.md](../sql/002_views_and_procedures.md) |

---

## 1. Objetivo

A vista devolve o **detalhe das linhas** (`BI`) das encomendas da série `ndos = 1`, para o ecrã de detalhe do Portal Logístico.

A API .NET lê via **Dapper** (`GET /encomendas/{boStamp}` → `WHERE bostamp = @boStamp`). Inclui restante (com `u_qttorig`), preço (`edebito` / `u_prcorig`), autorização e stock disponível (`ST.stock`, RN-018).

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

- [x] Campos BI: `u_prcorig`, `u_qttorig`, `u_qtdautdt`, `u_qtdaut`, `u_qtdautur`
- [x] `view_HCA_utilizadores` validada em UAT
- [x] `view_HCA_encomendas_abertas` validada em UAT (útil para cruzar no script `015`)
- [x] Tabelas `BO`, `BI`, `ST` confirmadas
- [x] `BO.ndos = 1` = série de encomendas
- [x] Permissões para criar views em UAT
- [x] Script `014` executado em UAT
- [x] Script `015` validado em UAT

---

## 4. Campos de Utilizador Relevantes

| Campo | Tipo | Uso |
| --- | --- | --- |
| `BI.u_qttorig` | `numeric(16,2) NOT NULL` | Qtd original; **0** = ainda não preenchido (RN-020) |
| `BI.u_prcorig` | `numeric(16,2) NOT NULL` | Preço original; **0** = ainda não preenchido (RN-021) |
| `BI.u_qtdaut` | `numeric(16,2) NOT NULL` | Quantidade autorizada |
| `BI.u_qtdautur` | `varchar(100) NOT NULL` | Quem autorizou |
| `BI.u_qtdautdt` | `datetime NOT NULL` | Quando autorizou |

Nativos expostos: `BI.qtt`, `BI.qtt2`, `BI.edebito`, `BI.usrinis` / `usrdata` / `usrhora`, `ST.stock`.

---

## 5. Fórmula de Restante

```text
ISNULL(NULLIF(BI.u_qttorig, 0), BI.qtt) - BI.qtt2
```

Alias na vista: `quantidade_por_satisfazer`.

- `u_qttorig = 0` → original considerada = `BI.qtt`
- `u_qttorig <> 0` → original considerada = `BI.u_qttorig`
- Restante = original considerada − `BI.qtt2`

**Nota:** esta vista **não** filtra por restante > 0 nem por `fecho = 0` (devolve todas as linhas da série 1). O filtro de encomenda aberta fica na listagem (`view_HCA_encomendas_abertas`) e no `bostamp` pedido pela API. A coluna `fecho` e `quantidade_por_satisfazer` permitem filtrar no consumidor se necessário.

---

## 6. Script executado

Ficheiro: [`../sql/014_create_view_HCA_encomenda_linhas.sql`](../sql/014_create_view_HCA_encomenda_linhas.sql)

```sql
CREATE OR ALTER VIEW dbo.view_HCA_encomenda_linhas
AS
SELECT
    bi.bostamp,
    bi.bistamp,
    bo.obrano,
    bo.ndos,
    bo.nmdos,
    bo.dataobra,
    bo.ousrhora,
    ISNULL(bo.fecho, 0) AS fecho,
    bo.no AS cliente_no,
    bo.estab AS cliente_estab,
    LTRIM(RTRIM(bo.nome)) AS cliente_nome,
    LTRIM(RTRIM(bi.ref)) AS ref,
    LTRIM(RTRIM(bi.design)) AS design,
    LTRIM(RTRIM(bi.cor)) AS cor,
    bi.qtt AS quantidade_atual,
    bi.qtt2 AS quantidade_fornecida,
    bi.u_qttorig AS quantidade_original_campo,
    ISNULL(NULLIF(bi.u_qttorig, 0), bi.qtt) AS quantidade_original_considerada,
    (ISNULL(NULLIF(bi.u_qttorig, 0), bi.qtt) - bi.qtt2) AS quantidade_por_satisfazer,
    bi.edebito AS preco_unitario,
    bi.u_prcorig AS preco_original_campo,
    bi.u_qtdaut AS quantidade_autorizada,
    LTRIM(RTRIM(bi.u_qtdautur)) AS quantidade_autorizada_por,
    bi.u_qtdautdt AS quantidade_autorizada_em,
    ISNULL(st.stock, 0) AS stock_disponivel,
    LTRIM(RTRIM(bi.usrinis)) AS usrinis,
    bi.usrdata,
    bi.usrhora
FROM dbo.bi bi WITH (NOLOCK)
INNER JOIN dbo.bo bo WITH (NOLOCK)
    ON bo.bostamp = bi.bostamp
LEFT JOIN dbo.st st WITH (NOLOCK)
    ON LTRIM(RTRIM(st.ref)) = LTRIM(RTRIM(bi.ref))
WHERE bo.ndos = 1;
GO
```

---

## 7. Regras aplicadas

- Apenas documentos com `BO.ndos = 1`
- Uma linha por `BI.bistamp`
- Restante com sentinel **0** em `u_qttorig`
- Preço unitário = `BI.edebito` (RN-021)
- Stock disponível = `ST.stock` (RN-018), `LEFT JOIN` por `ref`
- Representante / vendedor: **fora de âmbito**
- Sem escrita; sem JWT / `U_PORTAL*`

---

## 8. Validação

Ficheiro: [`../sql/015_validate_view_HCA_encomenda_linhas.sql`](../sql/015_validate_view_HCA_encomenda_linhas.sql)

| # | Verificação | Esperado |
| --- | --- | --- |
| 1 | `TOP 50` | Linhas com colunas de detalhe |
| 2 | `COUNT(*)` | Total de linhas série 1 |
| 3 | `GROUP BY ndos` | Só `ndos = 1` |
| 4 | Linhas de um `@bostamp` aberto | Coerente com cabeçalho |
| 5 | Totais agregado vs detalhe | `total_linhas` e restante alinham |
| 6 | Fórmula restante ≠ BI | **0 linhas** |
| 7 | `stock_disponivel` vs `ST.stock` | Coerente |

Checklist:

- [x] Só `ndos = 1`
- [x] `quantidade_por_satisfazer` correta
- [x] `preco_unitario` = `edebito`
- [x] Autorização (`u_qtdaut*`) visível
- [x] `stock_disponivel` coerente com `ST`
- [x] Cruzamento com `view_HCA_encomendas_abertas` OK

---

## 9. Resultado esperado

Uma linha por linha de encomenda (`BI`) da série 1, com cliente, quantidades, restante, preço, autorização, stock e `usr*` da última alteração.

---

## 10. Permissões SQL

```sql
GRANT SELECT ON dbo.view_HCA_encomenda_linhas TO [NOME_UTILIZADOR_SQL_APP];
```

Substituir o nome do utilizador SQL da aplicação antes de Produção.

---

## 11. Repetição em Produção

**Política:** só após implementação completa e **GO formal**.

- [ ] Confirmar backup / janela de intervenção
- [ ] Confirmar campos BI e `ST.stock`
- [ ] Confirmar `BO.ndos = 1`
- [ ] Executar `sql/014_create_view_HCA_encomenda_linhas.sql`
- [ ] Executar `sql/015_validate_view_HCA_encomenda_linhas.sql`
- [ ] Confirmar resultados
- [ ] Aplicar `GRANT SELECT`
- [ ] Registar data/hora e responsável

---

## 12. Rollback

```sql
DROP VIEW dbo.view_HCA_encomenda_linhas;
```

Vista só de leitura — não altera dados PHC.

---

## 13. Estado

| Campo | Valor |
| --- | --- |
| Estado em Teste/UAT | **Validado** (2026-08-10) |
| Estado em Produção | **Pendente** (GO formal) |
| Observações | Criação + validação OK em UAT; Produção diferida |
