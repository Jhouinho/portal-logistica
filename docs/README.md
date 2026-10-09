# Documentação — Liliana & Seródio Portal

## Fonte de verdade (hoje)

| Prioridade | Documento | Uso |
| --- | --- | --- |
| **1** | [`PROJECT-STATE.md`](./PROJECT-STATE.md) | Estado actual, UAT, realtime, TV, hipóteses, o que **não** implementar |
| **2** | [`business-flows.md`](./business-flows.md) | Fluxos de ecrã / MVP alinhados à UI (2026-09) |
| **3** | [`auth-portal-identity.md`](./auth-portal-identity.md) | Identity / cookie / `u_usaPort` |
| **4** | [`api-contract.md`](./api-contract.md) | Contrato API (emendas 2026-09) |

Arquitectura longa: [`../ARCHITECTURE.md`](../ARCHITECTURE.md) — **baseline** com emendas; **não** substitui `PROJECT-STATE.md`.  
Raiz do repo: [`../README.md`](../README.md).

## Índice por tema

| Tema | Onde ler |
| --- | --- |
| Circuito 1→66→65, check-in, Kapps TV, Centro/TV alinhados, % `aindaEmPicking`, Disponível UI | `PROJECT-STATE.md` |
| Em Aberto por referência — Backend 1A (performance / paginação API) | `PROJECT-STATE.md` (§ Backend 1A), `api-contract.md` (`/artigos/procura-aberta`) |
| Auditoria Picking / Kapps Quantity / distribuição fraccionada | [`auditoria-picking-kapps-distribuicao.md`](./auditoria-picking-kapps-distribuicao.md) |
| Rotas Separado / Em Expedição / Concluídas | `business-flows.md` + `PROJECT-STATE.md` |
| Separado: entrega parcial / Qtd. documento | `PROJECT-STATE.md`, `business-flows.md`, `api-contract.md` |
| Quantidades não entregues (66 fechado + pendente) | `PROJECT-STATE.md`, `business-flows.md`, `api-contract.md` — **≠** corte autorização (vista `043` legado) |
| Pendentes de Picagem (encomenda iniciada + Pending híbrido) | `PROJECT-STATE.md`, `business-flows.md`, `api-contract.md` — **≠** Em Picking; ressalva UAT misto Kapps+66 |
| Fecho operacional Em Expedição → Concluídas | `PROJECT-STATE.md`, `business-flows.md`, `api-contract.md` — SPs `083`/`084` |
| Autorização / alocação sem teto `ST.stock` | `PROJECT-STATE.md`, `business-flows.md`, SQL `068`/`069`/`082` |
| Identity `u_HcaLogi*` | `auth-portal-identity.md`, `fase-0b-u-HcaLogi-identity-tables.md` |
| Realtime / TvHub / `tv-kapps-resumo` | `PROJECT-STATE.md`, `api-contract.md` |
| Implantação IIS | `deployment-architecture.md` |
| **Passo a passo produção (cliente)** | [`PASSO_A_PASSO_PRODUCAO.md`](./PASSO_A_PASSO_PRODUCAO.md) |
| Briefing orientador | `validacao-orientador.md` |
| Plano de sprints (histórico) | `implementation-plan.md` |

## Histórico / Fase 0B (SUPERSEDED como SoT)

Ficheiros abaixo descrevem o estado **à data da 0B** (ex. teto `ST.stock`, Centro mock, auth só `u_portalph`). Mantêm-se para auditoria; regras operacionais actuais estão em `PROJECT-STATE.md`.

| Documento | Nota |
| --- | --- |
| `baseline-v1.0-documentacao-aprovada.md` | Baseline 2026-08 aprovada → 0B |
| `phc-database-discovery.md` | Discovery 0A |
| `fase-0b-preparacao-ambiente.md` | Hub 0B |
| `fase-0b-sp-HCA*.md`, `fase-0b-view-HCA*.md` | Objectos SQL 0B (+ banners de evolução) |
| `fase-0b-validacao-login-cookie.md` | Login 0B |
| `phc-installation-checklist.md` | Checklist 0B |
| `security-permissions.md` | Modelo 0B; auth actual → `auth-portal-identity.md` |
| `implementation-plan.md` | Sprints históricos |

## SQL de referência (evolução pós-0B)

| Script | Função |
| --- | --- |
| `068` / `082` | Autorização qtd + previsão (sem teto) |
| `069` | Alocação proporcional via previsão |
| `029` / Identity | Tabelas `u_HcaLogi*` |
