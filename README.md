# Liliana & Seródio — Portal de Logística e B2B

Portal web operacional sobre **PHC CS (SQL Server)**. Dados de negócio no PHC; Identity (`u_HcaLogi*`) na mesma connection string — **não** é uma BD de negócio separada.

## Estado actual (ler primeiro)

| | |
| --- | --- |
| **Fonte de verdade** | [`docs/PROJECT-STATE.md`](./docs/PROJECT-STATE.md) |
| **Fluxos de ecrã** | [`docs/business-flows.md`](./docs/business-flows.md) |
| **Índice docs** | [`docs/README.md`](./docs/README.md) |
| **Actualizado** | 2026-10-07 |
| **GitHub** | [Jhouinho/portal-logistica](https://github.com/Jhouinho/portal-logistica) (público) |

**Resumo:** circuito documental **1 → 66 → 65** validado em UAT; autorização/alocação por **previsão de entrada** (sem teto `ST.stock`); realtime SignalR por **invalidação** (`OperacoesHub` + `TvHub` público); TV/Centro com o **mesmo modelo UI** e `GET /api/v1/painel/tv-kapps-resumo`; KPIs = COUNT documentos + % lógica fraccionada (incl. momento `aindaEmPicking`); «Separado — em progresso» inclui 66 com check-in se Kapps em curso; Disponível na UI desconta Autorizada sugerida não gravada.

Pendentes e hipóteses (ex. sessão Kapps PIK aberta): ver `PROJECT-STATE.md` — **não implementar** hipóteses sem evidência.

**Marca:** logotipo PNG **não** está no repositório público; a UI usa texto (`BrandLogo`).

## Documentação

| Prioridade | Documento | Uso |
| --- | --- | --- |
| 1 | [`docs/PROJECT-STATE.md`](./docs/PROJECT-STATE.md) | Estado, UAT, realtime, TV, o que não fazer |
| 2 | [`docs/business-flows.md`](./docs/business-flows.md) | Fluxos UI / MVP |
| 3 | [`docs/auth-portal-identity.md`](./docs/auth-portal-identity.md) | Identity + `u_usaPort` |
| 4 | [`docs/api-contract.md`](./docs/api-contract.md) | Contrato `/api/v1` (emendas 2026-09) |
| — | [`ARCHITECTURE.md`](./ARCHITECTURE.md) | Baseline de arquitectura (com emendas; **não** substitui PROJECT-STATE) |
| — | [`docs/README.md`](./docs/README.md) | Índice completo + docs históricos SUPERSEDED |

Docs `fase-0b-*`, `baseline-v1.0-*`, discovery e checklists antigos são **auditoria** da fase 0B; regras de stock/`ST.stock` e Centro mock neles estão supersedidas.

## Stack

| Camada | Tecnologia |
| --- | --- |
| API | .NET 8, Dapper → `view_HCA_*` / `sp_HCA_*`, SignalR |
| UI | React 18, TypeScript, Vite, MUI, PWA mínima |
| Auth | ASP.NET Identity (cookie) + gate PHC `US.u_usaPort` |
| Dados | SQL Server PHC (`Phc:ConnectionString`) |

Arranque: [`src/backend/README.md`](./src/backend/README.md) · [`src/frontend/README.md`](./src/frontend/README.md).

## Implantação

**On-premises:** Windows Server 2022+ · IIS 10+ · ASP.NET Core .NET 8 · SQL Server PHC.  
- **Passo a passo no servidor do cliente:** [`docs/PASSO_A_PASSO_PRODUCAO.md`](./docs/PASSO_A_PASSO_PRODUCAO.md)  
- Topologia / TLS / DR: [`docs/deployment-architecture.md`](./docs/deployment-architecture.md)

## Identidade (resumo)

- Contas portal: Identity `u_HcaLogi*` (email/password)
- Gate PHC: `US.email` + activo + `u_usaPort = 1`
- Sessão: cookie — **sem** JWT / Bearer na UI
- Admin: role Identity `Admin` (gestão de utilizadores portal)

Guia: [`docs/auth-portal-identity.md`](./docs/auth-portal-identity.md).

## Princípios

- **RN-022** — Arquitectura Orientada à Mudança ([ARCHITECTURE.md](./ARCHITECTURE.md))
- Capacidade operacional = previsão (Previsto − Alocado); **não** alterar `ST.stock` para esse fim
- Realtime = invalidação → refetch; sem payload de negócio nos hubs
