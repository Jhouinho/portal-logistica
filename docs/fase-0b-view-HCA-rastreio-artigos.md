# Fase 0B — Criação da view_HCA_rastreio_artigos

> **HISTÓRICO (2026-09-29).** Menções a `ST.stock` / RN-018 = regras **0B**. Capacidade actual = previsão. SoT: [`PROJECT-STATE.md`](./PROJECT-STATE.md).

| | |
| --- | --- |
| Projeto | Liliana & Seródio — Portal de Logística |
| Objeto | `dbo.view_HCA_rastreio_artigos` |
| Script | [`sql/016_create_view_HCA_rastreio_artigos.sql`](../sql/016_create_view_HCA_rastreio_artigos.sql) |
| Validação | [`sql/017_validate_view_HCA_rastreio_artigos.sql`](../sql/017_validate_view_HCA_rastreio_artigos.sql) |
| API | `GET /artigos/procura-aberta` |

---

## 1. Objetivo

Agregar a **procura em aberto por artigo** (`ref`): totais de quantidade encomendada / fornecida / por satisfazer / autorizada, mais **stock disponível** (`ST.stock`, RN-018) e indicador de rutura.

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

- [x] Campos BI `u_qttorig`, `u_qtdaut*`
- [x] `view_HCA_encomendas_abertas` e `view_HCA_encomenda_linhas` validadas em UAT
- [x] `ST.stock` confirmado (RN-018)
- [x] Script `016` executado em UAT
- [x] Script `017` validado em UAT

---

## 4. Campos relevantes

| Campo | Uso |
| --- | --- |
| `BI.ref` / `BI.design` | Artigo |
| `BI.u_qttorig` / `qtt` / `qtt2` | Restante e totais |
| `BI.u_qtdaut` | Autorização agregada |
| `ST.stock` | Stock disponível |
| `BO.fechada` | Documento aberto (`= 0`); alias lógico “fecho” na documentação |

---

## 5. Fórmula de Restante

```text
ISNULL(NULLIF(BI.u_qttorig, 0), BI.qtt) - BI.qtt2
```

Só entram linhas com restante `> 0`, `ndos = 1` e `ISNULL(BO.fechada, 0) = 0`.

---

## 6. Script

Ver [`../sql/016_create_view_HCA_rastreio_artigos.sql`](../sql/016_create_view_HCA_rastreio_artigos.sql).

Colunas: `ref`, `design`, `total_linhas`, `total_encomendas`, `quantidade_encomendada_total`, `quantidade_fornecida_total`, `quantidade_por_satisfazer_total`, `quantidade_autorizada_total`, `stock_disponivel`, `em_rutura`.

Stock é feito com `LEFT JOIN` **depois** do `GROUP BY` para não duplicar linhas se `ST` tiver anomalias.

---

## 7. Regras

- Uma linha por `ref` com procura aberta
- Sem filtro de representante
- `em_rutura = 1` quando `stock_disponivel <= 0` (KPI Painel)

---

## 8. Validação

[`../sql/017_validate_view_HCA_rastreio_artigos.sql`](../sql/017_validate_view_HCA_rastreio_artigos.sql)

- [x] Listagem e contagem OK
- [x] Restante total sempre `> 0`
- [x] `stock_disponivel` = `ST.stock`
- [x] Totais de um `@ref` batem certo com agregação BI

---

## 9. Resultado esperado

Catálogo de artigos com procura aberta + stock, pronto para o ecrã Rastreio.

---

## 10. Permissões

```sql
GRANT SELECT ON dbo.view_HCA_rastreio_artigos TO [NOME_UTILIZADOR_SQL_APP];
```

---

## 11. Produção (GO formal)

- [ ] Backup / janela
- [ ] Executar `016` + `017`
- [ ] `GRANT SELECT`
- [ ] Registar data / responsável

---

## 12. Rollback

```sql
DROP VIEW dbo.view_HCA_rastreio_artigos;
```

---

## 13. Estado

| Campo | Valor |
| --- | --- |
| Estado em Teste/UAT | **Validado** (2026-08-10) — artigo piloto `D0394583`, stock 0 / rutura |
| Estado em Produção | **Pendente** |
| Observações | UAT com 1 artigo em procura; totais alinhados com BI |
