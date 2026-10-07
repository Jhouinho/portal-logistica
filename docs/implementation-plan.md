# Plano de Implementação por Sprint

> **SUPERSEDED como plano activo (2026-09-29).**  
> Estado actual, UAT e pendentes: [`PROJECT-STATE.md`](./PROJECT-STATE.md).  
> Fluxos de ecrã: [`business-flows.md`](./business-flows.md).  
> Este ficheiro mantém-se como **histórico de sprints / Marco 0A–0B**. Afirmações sobre Centro mock, teto `ST.stock` (RN-018), auth só `US.u_portalph` ou “próximo = Sprint 1” estão **desactualizadas**.

| | |
| --- | --- |
| Projeto | Liliana & Seródio — Portal de Logística e B2B |
| Fonte histórica | [ARCHITECTURE.md](../ARCHITECTURE.md) |
| Fonte operacional | [`PROJECT-STATE.md`](./PROJECT-STATE.md) |
| Princípio governante | **RN-022 — Arquitetura Orientada à Mudança** |
| Estado | **Operação UAT ativa** — circuito 1→66→65 validado; realtime + TV + `tv-kapps-resumo`; autorização/alocação por previsão (sem teto ST.stock); Identity `u_HcaLogi*` |
| MVP actual (resumo) | Auth Identity + cookie · Centro / TV · Encomendas · Qtt/Preço · Autorização (previsão) · Rastreio · Alocação · Previsões · Check-in · SignalR invalidação |
| Fora do MVP | JWT · RN-019 · Perfis obrigatórios · `U_PORTALAUDIT` · Cash & Carry · Portal Cliente B2B (Fase 2) |
| Equipa típica | 1–2 full-stack |
| Actualizado | 2026-09-29 |

Dependência transversal histórica: **0A confirmada**; **0B** executada em UAT — ver discovery e `sql/002_views_and_procedures.md`. Evoluções posteriores: SQL `068`/`069`/`082` (previsão), Identity, Centro/TV reais.

---

## RN-022 – Arquitetura Orientada à Mudança

**Princípio governante** de todos os sprints (MVP e futuros). Detalhe: [ARCHITECTURE.md — RN-022](../ARCHITECTURE.md#rn-022--arquitetura-orientada-à-mudança).

### Premissa

Os requisitos podem mudar durante o desenvolvimento e após produção. Cada sprint deve **minimizar retrabalho** e facilitar extensão.

### Diretrizes por sprint

| Diretriz | Aplicação prática |
| --- | --- |
| Configuração > hardcode | MVP: defaults em appsettings/constantes; config em BD opcional no futuro (sem inventar `U_PORTALCFG` agora) |
| Módulos isolados | Autenticação · Encomendas · Rastreio · Alocação · Administração · (futuro) Portal Cliente · Cash & Carry |
| Baixo acoplamento | Alterar um módulo sem tocar nos não relacionados |
| Extensão > reescrita | Novas features por composição; preservar núcleo estável |
| UI reutilizável | Tabelas, filtros, diálogos, formulários partilhados |
| PHC encapsulado | SQL crítico na BD (**`view_HCA_*`** leitura · **`sp_HCA_*`** escritas de negócio); API só Dapper para esses objetos; **exceção técnica:** `sp_HCA_validar_login` (login vs `US`, sem escrita de negócio) |
| Preparado para o futuro | Cash & Carry, Portal Cliente, novos documentos/fluxos/permissões/estados **sem redesenhar** o MVP |

### Critério transversal de aceitação (todos os sprints)

- Novas regras de negócio preferem configuração ou extensão de módulo isolado  
- Sem “knowledge leak” de tabelas PHC para a UI ou controllers  
- Componentes de UI reutilizados quando o padrão já existe  

---

## Marco 0 — Fase 0A / 0B

A antiga Fase 0 / Marco 0 divide-se em duas partes. Detalhe: [ARCHITECTURE.md — Fase 0A/0B](../ARCHITECTURE.md#fase-0a--0b--discovery-e-preparação-do-ambiente).

### Marco 0A — Discovery estrutural (**confirmada**)

| | |
| --- | --- |
| Estado | **Confirmada** (2026-08-10) |
| Base | Enciclopédia PHC + decisões de negócio |
| Bloqueia Sprint 1? | Não |

Entregáveis fechados: `BO`/`BI`/`ST`/`CL`, `edebito`, totais/BOTOTS, `usr*`/`ousr*`, RN-017–018/020–022, regras de restante e encomenda aberta. Identidade MVP = `US` + cookie/sessão (aprovada).

### Marco 0B — Preparação do ambiente (**bloqueia Sprint 1**)

| | |
| --- | --- |
| Estado | **Em curso / pendente** |
| Local | BD / ambiente do cliente |
| Bloqueia Sprint 1? | **Sim** |

#### Objetivos (checklist oficial 0B)

- Confirmar tabela `US` e campos de login / nome / iniciais (`usrinis`)  
- **Criar apenas** `US.u_portalph`  
- Criar campos `U_*` de logística em **BI** (sem `CL.u_portalactive` no MVP)  
- Criar vistas `view_HCA_*` e procedimentos `sp_HCA_*` ([sql/002](../sql/002_views_and_procedures.md))  
- Confirmar `BI.edebito`, `ST.stock`, `SerieEncomendasNdos = 1`  
- Confirmar updates `usr*` + recálculo de totais  
- Validar hash + login cookie  
- **Não criar:** `U_PORTAL*`, `u_portalperfil` / `u_portalativo` / `u_portalfalhas` / `u_portallockuntil`, `CL.u_portalactive`, setup JWT  

#### Entregáveis

- [ ] Confirmar tabela `US`  
- [ ] Confirmar campo de login em `US`  
- [ ] Confirmar campo de nome em `US`  
- [ ] Confirmar campo de iniciais / fonte para `usrinis`  
- [ ] Criar **apenas** `US.u_portalph`  
- [ ] Criar campos `U_*` obrigatórios em **BI** (`u_cc*` **opcionais**; **sem** campos novos em `CL`)  
- [ ] Criar vistas `view_HCA_*`  
- [ ] Criar procedimentos `sp_HCA_*`  
- [ ] Validar `SELECT` nas `view_HCA_*` e `EXEC` nas `sp_HCA_*`  
- [ ] Permissões SQL com a nomenclatura oficial  
- [ ] Confirmar `BI.edebito`, `ST.stock`  
- [ ] Confirmar `SerieEncomendasNdos = 1`  
- [ ] Confirmar `usr*` updates + totais  
- [ ] **Não** criar `U_PORTALUSER` / `U_PORTALREFRESH` / `U_PORTALCFG` / `U_PORTALAUDIT`  
- [ ] **Não** criar `u_portalperfil` / `u_portalativo` / `u_portalfalhas` / `u_portallockuntil`  
- [ ] **Não** criar `CL.u_portalactive` (possível futuro Fase 2)  
- [ ] Login SQL dedicado  
- [ ] Arranque: pelo menos um utilizador `US` com `u_portalph` (via PHC)  
- [ ] Validar hash + login cookie  

> Campos Cash & Carry (`u_cc*`) são **opcionais**. **Não bloqueiam** GO nem go-live do MVP.  
> Corte/séries: sem `U_PORTALCFG` — usar appsettings/constantes.

#### Critérios de conclusão

[GO Sprint 1](../ARCHITECTURE.md#critérios-para-início-de-desenvolvimento-go-sprint-1) — itens 0B.

#### Regra

**Só após Marco 0B** (GO) pode começar o **Sprint 1**.

---

## Sprint 1 — Fundação

### Objetivos

- Monorepo e Clean Architecture
- Identidade interna: `US` + cookie / sessão web
- Authentication · diagnóstico (opcional) · layout base React (PT-PT, tema escuro)
- **Sem** JWT · **sem** RN-019 · **sem** políticas por perfil · **sem** consulta `U_PORTALAUDIT`

### Tarefas — Servidor (API)

- Solution .NET 8: `Portal.Api`, `Portal.Application`, `Portal.Domain`, `Portal.Infrastructure`
- Estrutura modular; acesso PHC **só** via Dapper → `view_HCA_*` / `sp_HCA_*` (**RN-022**)
- DI, Serilog, health checks, Swagger
- Dapper: infraestrutura orientada a `view_HCA_*` (leitura) e `sp_HCA_*` (escritas de negócio); **exceção técnica:** `sp_HCA_validar_login` (auth)
- **Não** consultas diretas a `BO`/`BI`/`ST`/`CL`/`US` na API
- Autenticação: Microsoft Entra (`GET /auth/microsoft/login` + callback) → cookie; `POST /auth/logout`, `GET /auth/me` — **sem** refresh / JWT Bearer nas APIs
- Defaults de corte / `SerieEncomendasNdos` em appsettings
- Diagnóstico operacional (opcional; sem auditoria `U_PORTALAUDIT` / sem `/administracao/auditoria` no MVP)
- Ligação SQL Server + secrets por ambiente (Data Protection / cookie)
- **Não implementar** CRUD de utilizadores, gestão de passwords, config UI, JWT, lockout, perfis

### Tarefas — Interface

- React + TypeScript + Vite + Material UI
- Tema escuro operacional
- Login (mensagens PT) — credenciais de cookie (sem guardar tokens)
- Layout e menus MVP: **Painel Principal · Encomendas · Rastreio de Artigos · Administração** (se necessário)
- Guards de rota (sessão autenticada — sem perfil)
- Ecrã Administração (opcional): **diagnóstico / info operacional** (sem users / passwords / config / auditoria detalhada / sessões)
  - A consulta de auditoria detalhada é uma melhoria futura. No MVP, a auditoria operacional é assegurada pelos campos nativos PHC `usr*` em `BO` e `BI`.
- Catálogo de etiquetas PT

### Entregáveis

- API + SPA compiláveis
- Login funcional em UAT com utilizador `US` + hash
- Cookie na response; logout limpa sessão
- Diagnóstico opcional

### Dependências

- **Marco 0B concluído (GO Sprint 1)** — 0A já confirmada
- `US.u_portalph` + campos BI
- Connection string UAT
- Pelo menos um utilizador com hash

### Critérios de aceitação

- Login devolve `{ utilizador: { login, nome } }` + Set-Cookie — **sem** accessToken / refreshToken / expiresAt / perfil
- Passwords nunca em claro; hash só em `u_portalph`
- Logout limpa cookie; `GET /auth/me` reflete a sessão (`login`, `nome` apenas)
- Utilizador autenticado = acesso operacional completo (sem matriz de perfis)
- **Não existem** ecrãs nem APIs de CRUD de utilizadores / passwords / config de corte / gestão de sessões / auditoria `U_PORTALAUDIT`
- UI entregue 100% em português
- Rotas internas protegidas com cookie/sessão

---

## Sprint 2 — Painel Principal e Encomendas

### Objetivos

- KPIs do Painel Principal (âmbito MVP)
- Lista e detalhe de encomendas em aberto
- Estados Dentro do Limite Definido / Após Limite Definido

### Tarefas

- Dapper: consumir `view_HCA_encomendas_abertas` e `view_HCA_encomenda_linhas` (+ filtros)
- Cálculo de limite definido semanal (defaults appsettings)
- `GET /encomendas/abertas`, `GET /encomendas/{boStamp}`, `GET /painel/kpis`
- UI Painel Principal
- UI Encomendas: filtros touch, cores DP/AC, detalhe
- Paginação server-side
- SignalR base (ligação; eventos de encomenda; auth cookie)

### Entregáveis

- Painel utilizável em tablet
- Lista de encomendas com destaque Após Limite Definido
- Detalhe com linhas (original, qtt, qtt2, por satisfazer = original−qtt2, preço, autorização)

### Dependências

- Sprint 1
- `SerieEncomendasNdos = 1` confirmado
- Colunas `dataobra` / hora confirmadas

### Critérios de aceitação

- Só série correta, documentos abertos, restante > 0
- Filtros data, hora, cliente, artigo (sem representante)
- KPI Após Limite Definido alinhado com Segunda 12:00 (defaults MVP)
- Paginação sem carregar a tabela inteira

**KPIs do MVP:** Encomendas em Aberto · Encomendas Após Limite Definido · Artigos em Rutura · Quantidade por Satisfazer · Quantidade Autorizada · Clientes Afetados

*(KPI “Encomendas Cash & Carry Pendentes” fica reservado para capacidade futura.)*

---

## Sprint 3 — Gestão de Quantidade e Preço

### Objetivos

- Ajuste de quantidade da linha (**RN-020**) — `BI.qtt` + originais + totais + `usr*`
- Alteração de preço unitário (**RN-021**) — **`BI.edebito`** + originais + totais + `usr*`

### Tarefas

- `PATCH /encomendas/linhas/{biStamp}` → Dapper `EXECUTE sp_HCA_atualizar_linha_qtt_preco`
- Na 1.ª alteração de qtt: se `u_qttorig = 0` → gravar; nunca sobrescrever se `<> 0` (**na SP**)
- Na 1.ª alteração de preço: se `u_prcorig = 0` → gravar; nunca sobrescrever se `<> 0` (**na SP**)
- SPs atualizam `BI.qtt` / **`BI.edebito`** + totais + `usr*` BI/BO; **não** alterar `ousr*`
- **Sem** escrita obrigatória em `U_PORTALAUDIT`
- UI detalhe: edição touch de Quantidade e Preço por linha + Guardar
- SignalR: alteração de linha (qtt / preço)

### Entregáveis

- Ciclo: abrir encomenda → ajustar qtt/preço → preservar originais → marcar `usr*`
- Notificação em tempo real

### Dependências

- Procedimento `sp_HCA_atualizar_linha_qtt_preco` (RN-020/021) + vistas de leitura
- Campos BI `u_qttorig`, `u_prcorig`
- Nome físico do preço unitário: **`BI.edebito`**
- Recálculo de totais linha/cabeçalho obrigatório (equiv. BOTOTS)
- Confirmação de `usrinis`/`usrdata`/`usrhora` em BO/BI e mapeamento `US` → `usrinis`
- Sprint 2

### Critérios de aceitação

- Utilizador autenticado edita quantidade e preço
- Preço livre (10→9.50, 10→7, 10→15 todos válidos)
- `u_qttorig` e `u_prcorig`: preenchidos na 1.ª alteração (quando `= 0`); nunca sobrescritos se `<> 0`
- `BI.qtt` e `BI.edebito` atualizados (com totais recalculados)
- `BO`/`BI` `usrinis`/`usrdata`/`usrhora` atualizados; `ousr*` intactos

---

## Sprint 4 — Rastreio de Artigos e quantidade autorizada

### Objetivos

- Vista agregada por artigo
- Quantidade autorizada a expedir (`u_qtdaut`)
- Alocação proporcional (pré-visualizar + confirmar)

### Tarefas

- `PATCH .../quantidade-autorizada` e `POST .../lote` → `sp_HCA_atualizar_qtd_autorizada` (campos BI + stock RN-018)
- `GET /artigos/procura-aberta` → `view_HCA_rastreio_artigos`
- `GET /artigos/{ref}/encomendas-abertas` → `view_HCA_artigo_encomendas`
- Algoritmo proporcional (Apêndice B da arquitetura)
- `POST .../previsualizar` e `POST .../alocar` → `sp_HCA_alocacao_proporcional` quando aplicável
- Testes unitários do algoritmo
- UI expandível + diálogo de alocação
- Transação SQL + revalidação de `ST.stock` (RN-018)
- Ultrapassar restante e confirmação: **utilizador autenticado** (sem perfis; restrições por perfil = futuro)

### Entregáveis

- Ecrã Rastreio de Artigos completo
- Autorização a expedir + alocação

### Dependências

- Sprint 3
- Campos BI de autorização
- `ST.stock` como disponibilidade (RN-018)

### Critérios de aceitação

- Autorização e ultrapassar restante disponíveis a utilizadores autenticados (MVP)
- Totais coerentes com linhas abertas
- Pré-visualização não grava
- Commit de alocação: autenticado (MVP)
- `sum(auth) <= ST.stock` e `auth_i <= restante_i`
- Idempotency-Key no alocar

---

## Sprint 5 — Estabilização

### Objetivos

- Qualidade, segurança, desempenho e go-live do MVP

### Tarefas

- Índices com DBA
- Testes de carga ligeiros nas listagens
- Revisão `docs/security-permissions.md`
- Playwright: login (cookie), encomendas, autorização, rastreio/alocação
- Formação operacional
- Checklist de instalação (itens MVP) + IIS / Hosting Bundle / HTTPS
- Go-live + monitorização (Serilog, Event Viewer)

### Entregáveis

- Produção do MVP
- Acta de aceitação Fase 1 (sem Cash & Carry, sem Portal Cliente)

### Dependências

- Sprints 1–4 estáveis em UAT

### Critérios de aceitação

- Validação final do checklist (âmbito MVP) cumprida
- TLS e secrets corretos; cookie auth estável
- Equipa opera Painel, Encomendas, Autorização e Rastreio sem apoio contínuo

---

## Sprint 6 — Portal Cliente B2B (futuro)

Planeamento futuro — **não** bloqueia o go-live do MVP. **Portal Cliente = Fase 2.**

### Objetivos

- Self-service B2B no âmbito fechado da Fase 2

### Âmbito

- Registo QR (RN-017) · Login Cliente · Catálogo (imagens, preços, stock)
- Nova encomenda · Histórico · Estado · Faturas · PDF
- OTP SMS (posterior)

### Nota

Cash & Carry **não** faz parte deste sprint nem de nenhum sprint do MVP. Um portal C&C futuro **pode usar um modelo de autenticação diferente**, a definir mais tarde.

---

## Capacidade futura (sem sprint)

### RN-019 / perfis / `U_PORTALAUDIT`

Melhorias futuras — **não** no MVP (não criar campos/tabelas na 0B).

### Cash & Carry

A arquitetura prevê campos `U_*` em `BO` e rotas reservadas para um fluxo de aprovação Cash & Carry.  

**Não há** tarefas, ecrãs, contratos detalhados de request/response nem critérios de aceitação neste plano até decisão explícita de produto. Auth C&C a definir mais tarde.

---

### Ordem de desenvolvimento (após Marco 0B)

1. Confirmar GO Sprint 1 (`US` + só `u_portalph` + campos BI + SQL + `ndos=1` + utilizador piloto; 0A já feita)  
2. Connection string UAT + Data Protection  
3. Sprint 1 (cookie auth + layout + admin opcional) — estrutura modular e repositórios PHC (**RN-022**)  
4. Continuar sprints do MVP  

---

*Plano alinhado com arquitetura aprovada e **RN-022**; Sprint 1 bloqueado até **Marco 0B**.*
