# Produção — índice curto (portal já instalado)

| | |
| --- | --- |
| Âmbito | Sequência conceptual para Pedidos Mobile |
| Ambiente | Hosts, BD e paths: **inventário IT** (fora do Git) |
| Procedimento completo | **[`prod-passo-a-passo-aplicar-pedidos-mobile.md`](./prod-passo-a-passo-aplicar-pedidos-mobile.md)** — execução, SQL, publish e **rollback** |
| Checklist DBA | [`prod-checklist-dba-pedidos-internos-pos-inventario.md`](./prod-checklist-dba-pedidos-internos-pos-inventario.md) |
| HTTPS / QR | [`prod-https-portal-passo-a-passo.md`](./prod-https-portal-passo-a-passo.md) |

> Não executar escrita em produção só com este índice. Usar o **passo a passo** como referência obrigatória.
>
> **Não apagar / sobrescrever:** `appsettings.Production.json` · pasta `dp-keys`.
>
> **Flag** `PedidosInternosEnabled`: manter **desligada** até smoke + autorização de negócio.

---

## Sequência

| # | Passo | Notas |
| --- | --- | --- |
| 1 | **Backup** BD + cópia datada da pasta da app | Preparação — ver Fase 0 do passo a passo |
| 2 | **Gates SQL** — diagnóstico RO (`103` + `102A`); escrita `098 → 099 → 103 → 100` só com GO; `097` **só se** faltarem grants Kapps/`portal_app` | Ver Fases 1–2 |
| 3 | **Publicação** — gerar release do commit/tag **autorizado no dia**; copiar para `<IIS_APP_PATH>` sem tocar em Production.json / dp-keys; reciclar `<IIS_APP_POOL>` | Fases 3–4 |
| 4 | **Smoke** — site carrega; PUT sem auth → **401** (não 405); flag continua **off** | Fase 5 |
| 5 | **Flag** `true` — apenas depois dos gates e decisão de negócio | Fase 6 |

Nenhum destes passos está concluído por este documento. Preencher gates e evidências no passo a passo / checklist no dia da execução.

---

## Se algo correr mal

Seguir a **Fase 7 — Rollback** do [`prod-passo-a-passo-aplicar-pedidos-mobile.md`](./prod-passo-a-passo-aplicar-pedidos-mobile.md) (filesystem e/ou BD). Não improvisar restauros a partir deste índice.
