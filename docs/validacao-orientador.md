# Liliana & Seródio — Briefing para Orientador de Projeto

> **Actualizado 2026-09-29.** Detalhe operacional: [`PROJECT-STATE.md`](./PROJECT-STATE.md).

| | |
| --- | --- |
| Projeto | Portal de Logística e B2B |
| Cliente | Liliana & Seródio |
| ERP | PHC CS (SQL Server) |
| Estado | **UAT activo** — circuito 1→66→65 validado; realtime + TV; autorização por previsão |
| Documento de estado | [`PROJECT-STATE.md`](./PROJECT-STATE.md) |
| Baseline arquitectura | [ARCHITECTURE.md](../ARCHITECTURE.md) |

---

## O que estamos a desenvolver

Um **portal web interno** de logística operacional sobre o PHC: encomendas, autorização de quantidades (previsão de entrada), picking/separação/expedição, check-in, centro de operações e vista TV.

### Já implementado / em UAT (resumo)

- Auth **ASP.NET Identity** + gate `US.u_usaPort` (cookie)
- Centro operacional + Vista TV pública (`/tv`)
- Circuito **1 → 66 → 65** (encomenda → separado → expedição/concluídas)
- Quantidade/preço de linha; quantidade autorizada **sem teto** `ST.stock` (fonte = previsão)
- Rastreio de artigos e alocação proporcional (previsão)
- Previsões de entrada; check-in / reverter
- SignalR por **invalidação** (`OperacoesHub` + `TvHub`); `tv-kapps-resumo` (anti N+1)

### Fora do âmbito imediato

- Portal Cliente B2B (Fase 2)
- Cash & Carry
- JWT / AD / Entra
- Hipóteses não validadas (ex. sessão Kapps PIK aberta) — ver PROJECT-STATE

---

## Método

1. Dados de negócio no PHC SQL (`view_HCA_*` / `sp_HCA_*`); Identity só autentica
2. Documentação viva: `PROJECT-STATE.md` > `business-flows.md` > contrato API
3. Não transformar HIPÓTESE em regra; não alterar `ST.stock` para capacidade operacional
4. Realtime = invalidação → refetch das APIs

---

## Forma de validação

- Build/testes técnicos + **UAT** no ambiente do cliente
- Evidência do circuito 1→66→65 registada em PROJECT-STATE (29/09/2026)
- TV: negotiate `/hubs/tv` + latência `tv-kapps-resumo` medida em UAT

---

## Referências rápidas

| Tema | Doc |
| --- | --- |
| Estado / pendentes | [`PROJECT-STATE.md`](./PROJECT-STATE.md) |
| Fluxos UI | [`business-flows.md`](./business-flows.md) |
| Auth | [`auth-portal-identity.md`](./auth-portal-identity.md) |
| API | [`api-contract.md`](./api-contract.md) |
| Índice | [`README.md`](./README.md) |
