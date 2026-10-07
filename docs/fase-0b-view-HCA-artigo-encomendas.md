# Fase 0B — Criação da view_HCA_artigo_encomendas

> **HISTÓRICO (2026-09-29).** Menções a `ST.stock` = 0B. Capacidade actual = previsão. SoT: [`PROJECT-STATE.md`](./PROJECT-STATE.md).

| | |
| --- | --- |
| Projeto | Liliana & Seródio — Portal de Logística |
| Objeto | `dbo.view_HCA_artigo_encomendas` |
| Script | [`sql/018_create_view_HCA_artigo_encomendas.sql`](../sql/018_create_view_HCA_artigo_encomendas.sql) |
| Validação | [`sql/019_validate_view_HCA_artigo_encomendas.sql`](../sql/019_validate_view_HCA_artigo_encomendas.sql) |
| API | `GET /artigos/{ref}/encomendas-abertas` |

---

## 1. Objetivo

Listar **encomendas/linhas abertas** associadas a um artigo (`ref`), para expandir o rastreio e alimentar alocação proporcional.

A API filtra: `WHERE ref = @ref`.

---

## 2. Ambiente

| Campo | Valor |
| --- | --- |
| Servidor SQL | *(preencher)* |
| Base de dados | *(preencher)* |
| Ambiente | Teste / UAT — **Produção só no GO formal** |
| Data de execução | *(preencher)* |
| Executado por | *(preencher)* |
| Validado por | *(preencher)* |

---

## 3. Pré-requisitos

- [x] Campos BI e `ST.stock`
- [x] Preferível: `view_HCA_rastreio_artigos` criada (`016`) para cruzar no `019`
- [x] Script `018` executado em UAT
- [x] Script `019` validado em UAT

---

## 4. Campos relevantes

| Campo | Alias / uso |
| --- | --- |
| `bistamp` / `bostamp` | Identificadores linha / documento |
| `obrano` | Número encomenda |
| `cliente_*` | Cliente |
| `quantidade_pedida` | `ISNULL(NULLIF(u_qttorig,0), qtt)` |
| `quantidade_por_satisfazer` | Restante |
| `quantidade_autorizada` | `u_qtdaut` |
| `stock_disponivel` | `ST.stock` (mesmo valor por `ref`) |

---

## 5. Fórmula de Restante

```text
ISNULL(NULLIF(BI.u_qttorig, 0), BI.qtt) - BI.qtt2
```

Filtros: `ndos = 1`, `ISNULL(BO.fechada, 0) = 0`, restante `> 0`.

---

## 6. Script

Ver [`../sql/018_create_view_HCA_artigo_encomendas.sql`](../sql/018_create_view_HCA_artigo_encomendas.sql).

---

## 7. Regras

- Uma linha por `BI` em aberto do artigo
- Sem filtro de representante
- Alinhada com `view_HCA_rastreio_artigos` (mesmos filtros de abertura)

---

## 8. Validação

[`../sql/019_validate_view_HCA_artigo_encomendas.sql`](../sql/019_validate_view_HCA_artigo_encomendas.sql)

- [x] Só `ndos = 1`
- [x] `fecho = 0` e restante `> 0`
- [x] Totais do `@ref` = totais em `view_HCA_rastreio_artigos`

---

## 9. Resultado esperado

Para cada `ref`, a lista de linhas/encomendas abertas com quantidades e stock.

---

## 10. Permissões

```sql
GRANT SELECT ON dbo.view_HCA_artigo_encomendas TO [NOME_UTILIZADOR_SQL_APP];
```

---

## 11. Produção (GO formal)

- [ ] Backup / janela
- [ ] Executar `018` + `019`
- [ ] `GRANT SELECT`
- [ ] Registar data / responsável

---

## 12. Rollback

```sql
DROP VIEW dbo.view_HCA_artigo_encomendas;
```

---

## 13. Estado

| Campo | Valor |
| --- | --- |
| Estado em Teste/UAT | **Validado** (2026-08-10) — linha `D0394583` / cliente 10881 |
| Estado em Produção | **Pendente** |
| Observações | `u_qttorig = 0` → pedida = `qtt` (sentinel OK); auth ainda base (`1900-01-01`) |
