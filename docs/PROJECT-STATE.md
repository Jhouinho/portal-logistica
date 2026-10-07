# Liliana & Seródio — Portal de Logística

## Estado do projeto (fonte de verdade)

| | |
| --- | --- |
| Documento | `docs/PROJECT-STATE.md` |
| Idioma | Português de Portugal |
| Propósito | Estado actual, decisões, validação UAT, hipóteses, pendentes e o que **não** implementar sem nova evidência |
| Actualizado | 2026-10-07 |

### Legenda de estados neste documento

| Marcador | Significado |
| --- | --- |
| **CONFIRMADO** | Observado em código, SQL ou evidência directa |
| **IMPLEMENTADO** | Existe no Portal e foi validado tecnicamente (build/testes) |
| **VALIDADO EM UAT** | Comportamento observado numa instalação/teste real |
| **HIPÓTESE** | Provável, ainda sem confirmação suficiente |
| **PENDENTE DE VALIDAÇÃO** | Sabemos o que testar; ainda não reproduzível / não testado |
| **FORA DE ESCOPO** | Decisão explícita de não implementar agora |

**Não transformar HIPÓTESE em regra de negócio.**

---

## Resumo executivo

O Portal é uma camada operacional sobre o PHC CS (SQL Server): lê e actua no PHC; Identity só autentica. O circuito documental **1 → 66 → 65** está **VALIDADO EM UAT** (29/09/2026). Realtime por invalidação SignalR (OperacoesHub autenticado + TvHub público) está **IMPLEMENTADO**; a TV e as listas/centro usam `tv-kapps-resumo` para evitar N+1 Kapps (**IMPLEMENTADO**, medido em UAT na TV).

**Sólido/validado:** fluxo operacional principal, check-in, previsões, quantidades pós-autorização, data entrega / nome2 / método expedição, realtime + TV pública, optimização Kapps TV/listas/centro, Separado com Qtd. documento / entrega parcial; **«Quantidades não entregues»** = 66 fechado com `qtt−qtt2>0` (**IMPLEMENTADO** / **VALIDADO EM UAT** 30/09/2026); **«Pendentes de Picagem»** = ndos=1 iniciada (∃ `Picked`∨`SUM66`) + `Pending>0` por linha (**FECHADO COM RESSALVA DE UAT** 07/10/2026, #27); **fecho operacional Em Expedição→Concluídas** sem faturação (**IMPLEMENTADO** 30/09/2026); **KPIs Centro/TV** = 5 cards com COUNT operacional + % de encomenda lógica **fraccionada** (`distribuicaoLogica`) (**IMPLEMENTADO** / **VALIDADO EM UAT** Cenário A 06/10/2026); **Em Picking** sai da lista quando `SUM(66.BI.qtt) ≥ BI.qtt` por linha (**IMPLEMENTADO** 06/10/2026); **Cancelar Picking — REGRA B** bloqueado após `SUM(66.qtt)>0` (**IMPLEMENTADO** / **VALIDADO EM UAT** 07/10/2026, enc. 27); **morada** `BO2.u_mEntrega` + ⓘ; **filtro Modo de Expedição** nas listas (**IMPLEMENTADO** 30/09/2026); propagação Kapps `u_mEntrega` / `u_modExp` em `SP_u_Kapps_DossiersUSR` (**IMPLEMENTADO** em UAT; smoke circuito novo pendente); **Em Aberto por referência — Backend 1A** (**IMPLEMENTADO** / **VALIDADO EM UAT** 06/10/2026 nos cenários observáveis; baseline HTTP registada; FE ainda sem paginação).

**Principal trabalho pendente:** fechar distinção formal “Não picada” vs “Não entregue”; 2×65 na mesma linha do 66 (se surgir); Cenário B `2×66 ativos + 1×65` se surgir; smoke UAT do filtro Modo de Expedição e da cópia 1→66→65; **paginação no frontend** da vista Em Aberto por referência (consumir `page` / `pageSize` / `totalItems` do backend 1A).

**Investigações em aberto:** `u_Kapps_Session_Docs` — pausa/retoma/aborto **PASS** (§33–§34); múltiplos 65 abertos (linhas distintas do mesmo 66) **PASS** (§35); **não** usar `SessionEndDateTime IS NULL` como “em curso” universal. Ainda **NÃO OBSERVÁVEL**: 2×65 abertos na **mesma linha** do mesmo 66; Cenário B `2×66 ativos + 1×65`.

---

## Estado atual

### O que é o Portal

Camada web operacional de logística da Liliana & Seródio, ligada ao **PHC CS**. Não substitui o PHC: operadores usam o Portal para fluxos de armazém; a lógica crítica permanece no ecossistema PHC/SQL.

### Stack (**CONFIRMADO** no repositório)

| Camada | Tecnologia |
| --- | --- |
| API | ASP.NET Core 8, Dapper |
| UI | React 18, TypeScript, Vite, MUI |
| Dados | SQL Server (PHC) |
| Auth | ASP.NET Identity (tabelas próprias; cookie) |
| Realtime | SignalR (invalidação) |
| Extra | PWA mínima |

### Arquitectura de dados (**CONFIRMADO**)

**O Portal não possui uma base de dados de negócio própria/separada para os dados operacionais.** Os dados de negócio do Portal são lidos e escritos diretamente no SQL Server do PHC, através das tabelas, views e stored procedures existentes. O Portal possui tabelas próprias de autenticação/Identity (`u_HcaLogi*`), mas estas **não** constituem uma base de dados de negócio separada do Portal.

Distinção explícita:

| Afirmação | Estado |
| --- | --- |
| Não existe uma BD de negócio própria do Portal | **CONFIRMADO** (leituras/escritas operacionais via Dapper em `Phc:ConnectionString`) |
| Existem tabelas próprias do Portal para autenticação/Identity (`u_HcaLogi*`) | **CONFIRMADO** (`PortalIdentityDbContext` → `u_HcaLogiUsers`, Roles, Claims, …) |
| Os dados operacionais permanecem no PHC SQL Server | **CONFIRMADO** |

Connection string (**CONFIRMADO** em `Portal.Infrastructure/DependencyInjection.cs`):

- Operacional (Dapper) e Identity (EF Core) usam a **mesma** configuração: `Phc:ConnectionString` (fallback `ConnectionStrings:Phc`).
- Ou seja, as tabelas `u_HcaLogi*` vivem **no mesmo SQL Server / mesma connection string configurada para o PHC**; não há um segundo `AddDbContext` com outra BD de negócio.

Leituras via views/`view_HCA_*` e queries Dapper; escritas via SPs/`sp_HCA_*` e queries controladas. Gate PHC de acesso: utilizador activo com `u_usaPort` (ver `docs/auth-portal-identity.md`).

---

## Arquitetura

```text
Browser (React / PWA)
    ↓ cookie Identity (portal autenticado)
    ↓ anónimo (/tv, hubs/tv, alguns GETs de leitura TV)
Portal.Api (ASP.NET Core)
    ├── Dapper  → dados operacionais PHC (BO/BI/BO3, Kapps, views/SPs HCA)
    └── EF Core Identity → tabelas u_HcaLogi* (auth)
              ↓
        mesma Phc:ConnectionString
              ↓
        SQL Server do PHC
```

Realtime:

```text
PHC / Syslog (alterações BO/BI 66/65 + Kapps)
      ↓
ExternalChangeDetector (5 watermarks)
      ↓
ExternalChangeRealtimeHostedService (intervalo 5 s)
      ├── OperacoesHub  → grupo operacoes  → páginas autenticadas → refetch APIs
      └── TvHub         → grupo tv         → CentroTvPage         → carregar()
```

**Princípio (*IMPLEMENTADO*):** realtime = **invalidação**, não sincronização de DTOs. Eventos sem payload de negócio.

---

## Fluxo operacional

### Circuito de estados (UI e séries)

Rotas e labels (**IMPLEMENTADO** em `App.tsx` / `labels.ts`):

| Estado UI | Rota | Série típica | Critério operacional (resumo) |
| --- | --- | --- | --- |
| Encomendas / Em aberto | `/encomendas` | ndos = 1 | Abertas; `pronta_picking` conforme vista |
| Em Picking | `/picking` | ndos = 1 | `pronta_picking=1` **e** existe linha com `BI.qtt > SUM(66.BI.qtt)` por `obistamp` (todos os 66 ligados; sem filtrar `fechada`/`u_chkin`); Kapps na UI |
| Separado | `/expedicao` | ndos = 66 | `fechada = 0`, `u_chkin = 0`; badge **Entrega parcial** se `SUM(qtt2)>0` ∧ `SUM(qtt−qtt2)>0` |
| Check-in / A Preparar Entrega | `/check-in`, `/em-entrega` | ndos = 66 | `u_chkin = 1`, `fechada = 0`; acção UI **Voltar ao Separado** = `POST …/reverter-check-in` |
| Em Expedição | `/expedido` | ndos = 65 | `fechada = 0`; acção UI **Fechar expedição** = fecho operacional sem faturação → Concluídas |
| Concluídas | `/concluidas` | **ndos = 65** `fechada = 1`; acção **Reabrir** (BO+BI) |
| Quantidades não entregues | `/nao-entregues` | ndos = **66** `fechada = 1` + `SUM(qtt−qtt2)>0` (**IMPLEMENTADO**) | |
| Pendentes de Picagem | `/pendentes-picagem` | ndos = **1** | Aberta + `u_pickrdy=1` + **Picking iniciado** (encomenda) + linhas com `Pending>0` — **≠** Em Picking |

Notas:

- **`/expedicao`** = rota técnica do estado **Separado** (label `Separado`).
- **`/expedido`** = rota técnica do estado **Em Expedição** (label `Em Expedição`).
- O backend/API pode manter nomes técnicos (`expedicao`, `separacao`, `SerieSeparacaoNdos`) sem renomear só por UX.

### Diagrama lógico

```text
Encomenda (ndos=1)
      ↓  pronta picking / Kapps
Em Picking (ndos=1)
      ↓  Syslog / dossier
Separado (ndos=66, fechada=0, u_chkin=0)
      ↓  check-in
A Preparar Entrega (ndos=66, fechada=0, u_chkin=1)
      ↓
Em Expedição (ndos=65, fechada=0)
      ↓  Fechar expedição (Portal, sem faturação)  ou  fecho Syslog/faturação PHC
Concluídas (ndos=65, fechada=1)   ← IMPLEMENTADO (lista + KPI Centro)
```

> **Atenção:** «Concluídas» = **ndos=65 fechado**. Um `66` fechado com pendente pertence a **Quantidades não entregues**, não a Concluídas (`PainelQuery.ContarEstadosCentroAsync`).

### Centro / TV — COUNT operacional vs % lógica (**IMPLEMENTADO** / **VALIDADO EM UAT** 06/10/2026)

Os 5 cards do Centro operacional (`/`) e da Vista TV (`/tv`) mostram **duas métricas distintas** no mesmo cartão. **Não** são a mesma coisa.

| Elemento no card | Fonte API | Unidade | Semântica |
| --- | --- | --- | --- |
| Número grande | `GET /api/v1/painel/centro-estados` → campos `emAberto` / `emPicking` / `separado` / `emEntrega` / `expedido` | **Documentos** (dossiers) | `PainelQuery.ContarEstadosCentroAsync` — COUNT por série/filtro operacional (igual às listas) |
| Texto secundário `X% encomendas` | `centro-estados.distribuicaoLogica.*.percentagem` | **Encomendas lógicas** (`bostamp` ndos=1) | `ContarDistribuicaoLogicaAsync` + `DistribuicaoLogicaCalculator.Contribuir` — **1 encomenda = 1,0 unidade**, **repartida** pelos 66/65 activos |

Cards apresentados (sem Concluídas / total / barra de progresso nos KPIs):

```text
Em aberto · Em Picking · Separado · Em Entrega · Em Expedição
```

**COUNT operacional (número grande)** — alinhado às rotas/listas:

| Card | Critério de contagem |
| --- | --- |
| Em aberto | `view_HCA_encomendas_abertas`, `pronta_picking = 0` |
| Em Picking | mesma vista, `pronta_picking = 1` **e** `EXISTS` linha com `BI.qtt > SUM(66.BI.qtt)` por `obistamp` |
| Separado | ndos=66, `fechada=0`, `u_chkin=0` |
| Em Entrega | ndos=66, `fechada=0`, `u_chkin=1` |
| Em Expedição | ndos=65, `fechada=0` |

**Distribuição lógica (% )** — universo = encomendas `ndos=1` ligadas ao circuito via cadeia `BI.obistamp` (1↔66↔65). Cada encomenda contribui **exactamente 1,0**; pesos fraccionados:

```text
66 activo = fechada=0 ∧ SUM(qtt−qtt2)>0
  u_chkin=0 → Separado
  u_chkin=1 → Em Entrega

65 activo = fechada=0 → Em Expedição (conjunto 65 = um balde)

Só 66 (n activos): cada 66 = 1/n
Só 65: Em Expedição = 1,0
66 + 65: conjunto 66 = 0,5 (repartido pelos n 66); Em Expedição = 0,5
Sem 66/65 activos: Em Picking / Em Aberto / Não classificada (via pronta_picking na vista)
```

Exemplo: `1×66 (chkin=0) + 1×65` → Separado **0,5** + Em Expedição **0,5**.  
Exemplo: `2×66 ativos + 1×65` → cada 66 **0,25** + Em Expedição **0,5** (regra mantida; **UAT PENDENTE / NÃO OBSERVÁVEL** 07/10/2026 — ver abaixo).

Percentagens: `round(100 * quantidadeEstado / totalEncomendasLogicas, 1)` — `quantidade` pode ser decimal (ex. `9.5`).

**Implicação UX (CONFIRMADO):** COUNT documental e % lógica **divergem** de propósito. Uma encomenda com 66+65 conta **1 documento** em Separado e **1** em Em Expedição nos números grandes, mas só **0,5 + 0,5** nas %.

**Evidência UAT (06/10/2026) — Cenário A (`1×66 ativo + 1×65`):**

| Campo | Valor |
| --- | --- |
| Encomenda | `ADM26092937019,063000002` (obrano 11) |
| 66 activo | `Syslog_20261001175034816`, `u_chkin=0`, pendente=20 |
| 65 aberto | `Syslog_20260930145140016`, `fechada=0` |
| API | `separado.quantidade=9.5`, `emExpedicao.quantidade=0.5` (contribuição do caso = 0,5+0,5) |
| TV | Separado **39,6%** · Em Expedição **2,1%** (alinhado à API) |
| Veredicto | **PASS** |

**UAT (07/10/2026) — Cenário B (`2×66 ativos + 1×65 aberto`):** pesquisa read-only em `LillianaSerodioPhc` — **não existe caso real** (0 encomendas com ≥2 66 ativos; 0 com ≥2 66 ativos ∧ ≥1 65 aberto). Near-miss: enc. **11** = 1×66 ativo + 1×65 (já PASS); enc. **16** = 2×66 fechados + 2×65 abertos (já PASS). Regra `25%+25%+50%` **mantida**; coberta por testes unitários `DistribuicaoLogicaCalculator`; **não** classificado como FAIL. Detalhe: [`auditoria-picking-kapps-distribuicao.md`](./auditoria-picking-kapps-distribuicao.md) §21A. Veredicto: **UAT PENDENTE / NÃO OBSERVÁVEL**.

Código: `PainelQuery.ContarEstadosCentroAsync` / `ContarDistribuicaoLogicaAsync`, `DistribuicaoLogicaCalculator`, UI `KpiStrip` / `MiniStat` (`centroUi.tsx`).

### Em Picking — quantidade ainda por separar (**IMPLEMENTADO** 06/10/2026)

Registo consolidado (auditorias + alterações): [`auditoria-picking-kapps-distribuicao.md`](./auditoria-picking-kapps-distribuicao.md).

`u_pickrdy=1` = pertença ao universo de Picking (**não** auto-alterado pelo Portal ao criar 66).

Lista `/picking` (`GET /encomendas/abertas?prontaPicking=true`):

```text
view abertas ∩ pronta_picking=1
∩ EXISTS (linha BI.qtt > ISNULL(SUM(66.BI.qtt por obistamp), 0))
```

- Soma **todos** os 66 ligados à linha (`obistamp = bistamp`), **sem** filtrar `fechada` / `u_chkin`.
- Não usa `1.BI.qtt2`, `66.qtt2`, Kapps nem `u_pickstat` para sair da lista.
- Contador menu Em Picking (`ContarEstadosCentroAsync`) usa a **mesma** condição.
- Realtime: em modo Picking, `dossier66Alterado` invalida também `encomendas-lista/abertas` (`EncomendasListPage`).

### Cancelar Picking — REGRA B (**IMPLEMENTADO** / **VALIDADO EM UAT** 07/10/2026)

Decisão funcional final (detalhe: [`auditoria-picking-kapps-distribuicao.md`](./auditoria-picking-kapps-distribuicao.md) §32):

> Depois de existir quantidade materializada num ndos=66 para qualquer linha da encomenda, o Picking **não** pode ser cancelado.

Critério: `EXISTS` linha com `SUM(66.BI.qtt) > 0` (`66.BI.obistamp = 1.BI.bistamp`, série `SeriePickingNdos`). **Não** usar `BI.qtt2`, Kapps (`QuantityPicked` / `QuantitySatisfied`) nem ndos=65.

A lista Em Picking continua a usar `BI.qtt > SUM(66.qtt)` — por isso uma encomenda pode estar **ao mesmo tempo** em Picking, com quantidade já em 66, e com Cancelar bloqueado.

Motivação: Cancelar restaura `BI.qtt` via `BI2.u_qttorig` e limpa autorizações; **não** altera documentos 66. Após separação materializada em 66, essa operação não se reverte por «Cancelar Picking».

| | |
| --- | --- |
| API | `temQtt66` em lista/detalhe |
| UI | Cancelar oculto em `/picking`; desmarcar pronta bloqueado no detalhe |
| SP | `sp_HCA_picking_cancel` / `sp_HCA_marcar_pronta_picking` — [`086`](../sql/086_alter_picking_cancel_block_when_qtt66.sql) |
| UAT | Encomenda **27** (`qtt=7`, SUM66=`3`, restante=`4`, 66 aberto, sem 65) → `temQtt66=true`, Cancelar/desmarcar bloqueados — **PASS** |

### Pendentes de Picagem (**FECHADO COM RESSALVA DE UAT** 07/10/2026)

Consulta de **encomendas** (`ndos=1`) que **já iniciaram fisicamente o Picking** e ainda têm quantidades por picar. **Não** confundir com:

| Conceito | Critério |
| --- | --- |
| **Em Picking** (lista `/picking`) | `u_pickrdy=1` ∧ `EXISTS` linha com `BI.qtt > SUM(66.qtt)` |
| **Pendentes de Picagem** (`/pendentes-picagem`) | `u_pickrdy=1` ∧ encomenda **iniciou** (∃ linha `Picked>0` ∨ `SUM66>0`) ∧ linhas com `Pending>0` |

**Universo base:** `BO.ndos=1` ∧ `fechada=0` ∧ `BO3.u_pickrdy=1` (+ filtros de documento: data, nº, cliente).

**Picking iniciado (nível encomenda):** sobre **todas** as linhas da encomenda, **antes** dos filtros de referência/artigo/cor:

```text
∃ linha: Picked > 0  OU  SUM66 > 0
```

- `Picked` = `SUM(u_KApps_DossierLin.Qty2)` com `Status='A'` ∧ `Integrada='N'` (por `stampbi`)
- `SUM66` = `SUM(66.BI.qtt)` por `obistamp` (série `SeriePickingNdos`; **sem** filtrar `fechada` / `u_chkin`)
- **65** não participa; **`u_Kapps_Session_Docs`** não participa directamente no cálculo

**Pending por linha** (só se a encomenda iniciou; híbrido — **nunca** `qtt − SUM66 − Picked`):

```text
SE Picked > 0 → Pending = BI.qtt − BI.qtt2 − Picked
SENÃO         → Pending = BI.qtt − SUM66
```

Incluir linha ⇔ `Pending > 0`. Linhas irmãs **ainda sem início individual** podem aparecer (`Pending = qtt` quando `SUM66=0`).

**API / UI:** `GET /api/v1/pendentes-picagem`, `/por-referencia`, `/{boStamp}/linhas`; vistas Por encomenda / Por referência; cliente (`clienteNo` / `clienteNome` / `clienteNome2`) na expansão por referência; frontend **não** recalcula Pending. Paginação **1A** (linhas elegíveis → agrupar → ordenar → paginar). Realtime: `encomendaAlterada` / `dossier66Alterado` / `kappsAlterado` → reload.

**UAT #27 (07/10/2026):** 1280→4, 1053→3, 1277→2, total **9**; filtro `artigoRef=1053` → #27 com 1053→3 (started preservado). Testes unitários **15/15 PASS**.

**Ressalva de UAT (não é FAIL):** não foi observado em dados reais um caso simultâneo `SUM66>0` ∧ `Picked>0` na **mesma** linha. A regra híbrida está implementada e coberta por testes.

Código: `PendentesPicagemRules`, `PendentesPicagemQuery`, `PendentesPicagemService`, `PendentesPicagemController`; FE `PendentesPicagemHubPage`.

### Em Expedição — fecho operacional sem faturação (**IMPLEMENTADO** 30/09/2026)

Na UI `/expedido`, o utilizador pode **Fechar expedição** sem faturar no PHC:

```text
ndos=65 AND BO.fechada=0
  → BO.fechada=1 + BI.fechada=1 (todas as linhas do bostamp)
  → aparece em Concluídas
```

| | |
| --- | --- |
| API | `PATCH /api/v1/separacao-dossiers/{boStamp}/fechada` com `{ "fechada": true }` |
| SP | `sp_HCA_fechar_expedicao_dossier` ([`083`](../sql/083_create_sp_HCA_fechar_expedicao_dossier.sql)) |
| Reabrir | `{ "fechada": false }` → `sp_HCA_reabrir_expedicao_dossier` ([`084`](../sql/084_create_sp_HCA_reabrir_expedicao_dossier.sql)) — `BO`+`BI.fechada=0` |
| Não altera | `qtt`, `qtt2`, `u_chkin`, Kapps, dossiers 66/1; **sem** faturação / docs novos |
| Conflitos | Já fechado / já aberto → **409**; série/ndos incorrectos → **404** |
| SP legado | `sp_HCA_marcar_fecho_picking_dossier` (**048**) — **inalterada**; continua disponível para dossiers 66 via `picking-dossiers` |

Realtime: actualização de `usrdata`/`usrhora` em BO/BI avança cursores 65 → evento `dossier65Alterado` (sem SignalR novo).

Cadeia documental (**VALIDADO EM UAT** 29/09/2026):

```text
1 → 66 → 65
65.BI.obistamp → 66.BI.bistamp
66.BI.obistamp → 1.BI.bistamp
```

O 65 **não** aponta directamente para o 1.

### Separado — quantidades e entrega parcial (**IMPLEMENTADO** 2026-09-30)

No ecrã Separado (`ndos=66`), a quantidade operacional do **documento** usa exclusivamente `BI` do próprio 66:

| Label UI | Campo |
| --- | --- |
| Qtd. documento | `BI.qtt` (`SUM` na lista; `qtt` na linha) |
| Expedida | `BI.qtt2` |
| Pendente | `BI.qtt − BI.qtt2` |

**Não** usar nesta apresentação: `u_qttorig`, `u_qtdaut`, `quantidadeTotal`, `quantidadePorSatisfazer`, Kapps / picagem parcial.

Campos API aditivos na listagem `GET /api/v1/picking-dossiers`: `quantidadeDocumento`, `quantidadeExpedida`, `quantidadePendenteEntrega`.  
`quantidadeTotal` / `quantidadePorSatisfazer` mantêm a semântica histórica (`u_qttorig`) — **não** redefinidos.

**Entrega parcial** (badge visual, não é estado PHC):

```text
quantidadeExpedida > 0 AND quantidadePendenteEntrega > 0
```

Todas as referências do dossier permanecem visíveis (incluindo pendente = 0).  
Equivalência `1.u_qtdaut ≡ 66.BI.qtt` após Syslog: observada em UAT, **não** invariante no código do Portal.

**Voltar ao Separado:** UI em A Preparar Entrega; endpoint técnico `POST /api/v1/picking-dossiers/{boStamp}/reverter-check-in` → só `u_chkin 1→0` (não altera `qtt`/`qtt2`/expedição).

### Quantidades não entregues — regra funcional (**VALIDADO EM UAT** 30/09/2026)

Dois conceitos **distintos** (não misturar):

| Conceito | Âmbito | Regra |
| --- | --- | --- |
| **Corte de autorização** (legado / histórico) | Encomenda `ndos=1` | `u_qttorig > u_qtdaut` (após pronta picking ou fecho). Vista `view_HCA_cortes_quantidade` — **sem consumidor activo** na API/UI (código de query legado permanece) |
| **Quantidades não entregues** (operacional **actual**) | Dossier `ndos=66` | `fechada=1` e `SUM(BI.qtt − BI.qtt2) > 0` |

Regra funcional alvo da área UI `/nao-entregues` («Quantidades não entregues»):

```text
BO.ndos = 66
AND BO.fechada = 1
AND SUM(BI.qtt − BI.qtt2) > 0
```

| Label | Campo (documento 66) |
| --- | --- |
| Qtd. documento | `BI.qtt` |
| Expedida | `BI.qtt2` |
| Pendente / Não entregue | `BI.qtt − BI.qtt2` |

**Não** usar nesta funcionalidade: `u_qttorig`, `u_qtdaut`, diferença autorização, Kapps, `u_pickstat`, nem `autorizada − SUM(65.qtt)` como regra principal.

Lista: dossier aparece se existe pendente agregada `> 0`.  
Expand: **todas** as linhas do 66 (incluindo pendente = 0), com Documento / Expedida / Pendente.

**Evidência UAT (circuito parcial real):** 1 → 66 → expedição parcial → 65; 66 mantém `qtt`/`qtt2`/pendente; Voltar ao Separado; restante expedido; fecho Syslog do 66 origem. Confirma a semântica `qtt`/`qtt2` no 66.  

**Estado código:** **IMPLEMENTADO** — `/nao-entregues` + `GET /api/v1/cortes-quantidade` usam `PickingDossiersQuery` (`ndos=66`, `fechada=1`, `quantidade_pendente_entrega > 0`). Vista `view_HCA_cortes_quantidade` / script 043 mantidos sem alteração; query legado em `EncomendasQuery.ListarCortes*` sem consumidor.

---

## Dados e regras de negócio

### Universo de artigos (**CONFIRMADO** / **IMPLEMENTADO**)

| Campo | Regra |
| --- | --- |
| `STOBS.u_dispPort` | `1` = no universo Portal; `0` = não disponível para novas operações |
| `ST.u_dispPort` | **Não existe** |
| Backfill automático | **Não** |
| Independência | Independente de `ST.stock` |

Linhas de encomendas antigas com artigo já fora do universo: visíveis; linha → “Não disponível no Portal”; encomenda → aviso se contiver tais artigos.

### Quantidades (**CONFIRMADO** — crítico)

Após autorização:

| Campo | Significado |
| --- | --- |
| `BI2.u_qttorig` | Quantidade originalmente pedida |
| `BI2.u_qtdaut` | Quantidade explicitamente autorizada |
| `BI.qtt` | Quantidade operacional actual (normalmente a autorizada **depois** da autorização) |
| `BI.qtt2` | Campo externo / read-only no Portal (`QuantitySatisfied` Kapps); **writer efetivo não determinado** (ver [`auditoria-picking-kapps-distribuicao.md`](./auditoria-picking-kapps-distribuicao.md) §7) |

**Não assumir** que `BI.qtt` continua a ser a quantidade original após autorização.

Regras adicionais:

- Autorização inicial = quantidade pedida a satisfazer.
- Sem teto imposto pela previsão.
- Disponibilidade da previsão pode ficar **negativa**.
- Isto **não** altera `ST.stock`.

### Previsões de entrada (**CONFIRMADO** / **IMPLEMENTADO**)

`u_HcaPrevEntrada`: Id, DataInicio, DataFim, metadata, Fechada, FechadaEm, FechadaPor.

`u_HcaPrevEntradaLin`: PrevisaoId, Ref, Cor, QuantidadePrevista.

| Regra | |
| --- | --- |
| Abertas | No máximo uma previsão aberta |
| Fechada | Imutável |
| Disponibilidade | Previsto − Alocado (pode ser negativa) |

`BI2.u_previd` (varchar(50), NOT NULL):

- `u_qtdaut > 0` → Id da previsão  
- `u_qtdaut = 0` → `''`  
- `NULL` nunca é válido  

Ligação: `BI2.bi2stamp = BI.bistamp` → `BI.ref` + `BI.u_cor` ↔ linha da previsão.

### Check-in (**CONFIRMADO** / **IMPLEMENTADO**)

BO3: `u_chkin`, `u_chkinur`, `u_chkindt`. SPs marcar / reverter.

Reverter: `u_chkin=0`, `u_chkinur=''`, `u_chkindt=1900-01-01`. Não altera `u_pickstat`, `fechada`, Kapps, linhas.

Filtro método de expedição no Check-in: Todos | Levantamento em Armazém | Transportadora | N/Viatura | Não definido (client-side sobre a lista carregada).

### Campos operacionais integrados (**IMPLEMENTADO**)

| Campo | Origem | UI |
| --- | --- | --- |
| Data de entrega | `BO3.TAXPOINTDT` | read-only; null / ano &lt; 1950 / 01-01-1900 → `—`; `dd/MM/yyyy` |
| Cliente | `BO.nome2` principal; `BO.nome` secundário | |
| Método expedição | `BO3.u_modExp` | coluna + ⓘ («Expedição»); vazio → `—` |
| Morada de entrega | `BO2.u_mEntrega` | texto corrido tal qual; vazio → omitir; ⓘ no cabeçalho |

**ⓘ (`DossierInfoButton`):** cliente, morada (se preenchida), data entrega (quando o contexto a tem), expedição. Sem fallback para `BO.morada` / outro documento.

### Filtro Modo de Expedição nas listas (**IMPLEMENTADO** 30/09/2026)

Query `metodoExpedicao`: omitido/`Todos` → sem filtro; valor PHC exacto; `nao_definido` → trim vazio. Aplicado **antes** da paginação (por encomenda) e **antes** do `GroupBy` (por referência). Sem N+1; sem SQL novo (`MetodoExpedicao` já vinha nas queries).

| Vista | Onde | API |
| --- | --- | --- |
| Por encomenda | Em Aberto, Em Picking, Separado, Em Entrega, Em Expedição, Concluídas | `encomendas/abertas`, `picking-dossiers`, `separacao-dossiers` |
| Por referência | Só Em Aberto (`/encomendas?vista=referencia`) | `artigos/procura-aberta` — referência visível se ≥1 linha corresponder; totais só dessas linhas |

Barra de filtros: **uma linha** (`nowrap`); Artigo com maior flex; overflow X só como fallback.

### Propagação Kapps 1→66→65 (**IMPLEMENTADO** em UAT BD)

Ponto: apenas `dbo.SP_u_Kapps_DossiersUSR` (pós-cabeçalho; `BO2`/`BO3` destino já existem).

| Campo | Origem → destino | `@ndos` |
| --- | --- | --- |
| `BO2.u_mEntrega` | `@InternalStampDoc` → `@bostamp` | 66 e 65 |
| `BO3.u_modExp` | idem (`bo3stamp = bostamp`) | 66 e 65 |

Não altera `SP_u_Kapps_Dossiers`. Sem backfill de documentos antigos. **PENDENTE DE VALIDAÇÃO UAT:** circuito Kapps novo com valores preenchidos no `ndos=1`.

---

## Em Aberto por referência — Backend 1A (**IMPLEMENTADO** / **VALIDADO EM UAT** 06/10/2026)

| | |
| --- | --- |
| Endpoint | `GET /api/v1/artigos/procura-aberta` |
| Estado | **1A FECHADA / BASELINE REGISTADO** — validado nos cenários observáveis |
| Frontend | Ainda **sem** paginação visual; continua a consumir `items` (compatível) |
| Próximo passo | Implementar paginação no FE consumindo `page`, `pageSize`, `totalItems` — **sem** alterar a semântica do backend 1A |

### Pipeline implementado

```text
GET /api/v1/artigos/procura-aberta
        │
        ▼
Fase 1 — SQL
linhas abertas + filtros
        │
        ▼
C# — PlaneamentoCalculator
        │
        ▼
CoincideFiltro
        │
        ▼
GroupBy
        │
        ▼
Agregações
        │
        ▼
OrderBy
        │
        ▼
totalItems
        │
        ▼
Skip / Take
        │
        ▼
Ref+Cor distintos da página
        │
        ▼
Fase 2 — Prev*
        │
        ▼
QuantidadeDisponivel
        │
        ▼
Response
```

A optimização **não migrou** a regra DP/AC para SQL: classificação e filtros de planeamento permanecem em C# (`PlaneamentoCalculator` / `CoincideFiltro`).

### Porque 1A (e não 1B nesta fase)

| Opção | Decisão |
| --- | --- |
| **1A** (implementada) | Mantém em C#: `PlaneamentoCalculator`, `CoincideFiltro`, GroupBy, agregações, OrderBy. Limita o cálculo pesado `PrevAlocado` / `PrevDisp` às chaves `(Ref, Cor)` presentes na página. |
| **1B** (não implementada) | Implicaria portar a classificação DP/AC para SQL, duplicando regra de negócio e risco de divergência — **sem necessidade** nesta fase. |

**1B não está rejeitada definitivamente.** É evolução futura **apenas se** o volume real o justificar.

### Compatibilidade `page` / `pageSize`

- `page` e `pageSize` adicionados ao endpoint.
- `pageSize` **opcional**; omitido → backend devolve **todos** os grupos (comportamento compatível com o FE actual).
- Quando omitido, `pageSize` na resposta = tamanho efectivo da lista completa.
- Máximo: `pageSize` clamp **200**.
- FE actual: consome `items`; **ainda não** utiliza paginação.

Contrato: [`api-contract.md`](./api-contract.md) § `GET /artigos/procura-aberta`.

### Validação técnica

| Item | Resultado |
| --- | --- |
| Build | Sem erros |
| Testes unitários | **117** aprovados |
| Auditoria read-only | Aprovada com ressalvas |
| API | Reiniciada com binários 1A (`procura-aberta 1A`) |
| UAT HTTP | Autenticado (piloto `sa`); cenários observáveis OK |

### UAT HTTP autenticado (06/10/2026) — resultados observados

| Cenário | HTTP | Tempo HTTP | Items | Total | Notas |
| --- | ---: | --- | ---: | ---: | --- |
| Universo (sem `pageSize`) | 200 | ~214–405 ms | 30 | 30 | `items.Count == totalItems` |
| `q=1368` | 200 | ~163–218 ms | 1 | 1 | AC; `QuantidadeDisponivel=20` |
| `q=1053` | 200 | ~174–180 ms | 1 | 1 | AC; `QuantidadeDisponivel=20` |
| `page=1&pageSize=10` | 200 | ~205 ms | 10 | 30 | Ordem = universo; sem duplicados vs page 2 |
| `page=2&pageSize=10` | 200 | ~191 ms | 10 | 30 | Idem |
| `page=9999&pageSize=10` | 200 | ~34 ms | 0 | 30 | Página além do fim |
| `estadoPlaneamento=DP` | 200 | ~34 ms | 0 | 0 | Universo UAT **sem** DP |
| `estadoPlaneamento=AC` | 200 | ~188–212 ms | 30 | 30 | Todos AC |
| `metodoExpedicao=Levantamento em Armazem` | 200 | ~194–244 ms | 20 | 20 | — |
| Expand `…/artigos/1368/encomendas-abertas` | 200 | ~174–209 ms | 1 enc. | — | AC; stock 20 |

**Stock observado** (`QuantidadeDisponivel`): 1309 → 7; 1368 → 20; 1135 → 20; 1310 → 20.

### Baseline 1A — UAT

Tempos = **HTTP total observado** (não SQL isolado). **Não** extrapolar para produção. Servem de baseline para alterações futuras.

```text
Universo: ~214–405 ms
q=1368:  ~163–218 ms
q=1053:  ~174–180 ms
AC:      ~188–212 ms
Método:  ~194–244 ms
```

### Limitações do UAT (não exercitados)

Classificação: *Não exercitados no UAT devido ao estado dos dados de teste.* **Nem PASS nem FAIL.**

- DP+AC no mesmo Ref+Cor  
- Filtro por cor preenchida  
- Ref+Cor com `QuantidadeDisponivel = 0`

**Trace:** o marcador `[procura-aberta 1A]` usa `Trace.WriteLine` e **não** ficou visível nos logs actuais; `msFase1` / `msFase2` **não** foram observados em runtime. Logging **não** alterado nesta fecho documental.

### O que a 1A **não** alterou

Semântica das quantidades · `PlaneamentoCalculator` · regra DP/AC · GroupBy · agregações · OrderBy · universo de linhas abertas · filtros de negócio · semântica Prev* · frontend · paginação visual.

Alteração: estrutural/performance + suporte de paginação no **backend**.

### Próximo passo

> **Próximo passo: implementar paginação no frontend da vista “Em Aberto por referência”, consumindo `page`, `pageSize` e `totalItems`, sem alterar a semântica do backend 1A.**

---

## Funcionalidades concluídas

| Funcionalidade | Estado |
| --- | --- |
| Universo artigos / `u_dispPort` | IMPLEMENTADO |
| Previsões de entrada | IMPLEMENTADO |
| Autorização quantidades (sem teto previsão) | IMPLEMENTADO |
| Data de entrega | IMPLEMENTADO |
| Nome cliente (nome2/nome) | IMPLEMENTADO |
| Método de expedição (`BO3.u_modExp` + ⓘ) | IMPLEMENTADO |
| Morada de entrega (`BO2.u_mEntrega` + ⓘ) | IMPLEMENTADO |
| Filtro método expedição no Check-in | IMPLEMENTADO |
| Filtro Modo de Expedição (listas por encomenda + por referência Em Aberto) | **IMPLEMENTADO** (30/09/2026); smoke UAT pendente |
| Kapps USR: copiar `u_mEntrega` + `u_modExp` (1→66→65) | **IMPLEMENTADO** em UAT (30/09/2026); smoke circuito novo pendente |
| Check-in + reverter (UI: Voltar ao Separado) | IMPLEMENTADO / VALIDADO EM UAT (circuito 29/09) |
| Separado: Qtd. documento / Expedida / Pendente + badge Entrega parcial | IMPLEMENTADO (2026-09-30) |
| Quantidades não entregues (`/nao-entregues` = 66 fechado + pendente) | **IMPLEMENTADO** / **VALIDADO EM UAT** (30/09/2026) |
| Pendentes de Picagem (`/pendentes-picagem`; started ao nível encomenda; híbrido Kapps/66) | **FECHADO COM RESSALVA DE UAT** (07/10/2026) — UAT #27 PASS; misto `SUM66+Picked` na mesma linha **não observável** (não é FAIL) |
| Fecho operacional Em Expedição → Concluídas (sem faturação; BO+BI) | **IMPLEMENTADO** (30/09/2026); smoke SQL UAT |
| Reabrir expedição (Concluídas → Em Expedição; BO+BI) | **IMPLEMENTADO** (30/09/2026) |
| Centro/TV: 5 KPIs = COUNT documentos + % encomenda lógica **fraccionada** | **IMPLEMENTADO** / **VALIDADO EM UAT** Cenário A (06/10/2026); Cenário B `2×66 ativos + 1×65` — **UAT PENDENTE / NÃO OBSERVÁVEL** (07/10/2026; unitários OK; não é FAIL) |
| Em Picking: sai da lista quando linhas totalmente separadas (`SUM(66.qtt)`) | **IMPLEMENTADO** (06/10/2026); contador menu alinhado |
| Realtime `/picking`: `dossier66Alterado` invalida lista abertas | **IMPLEMENTADO** (06/10/2026) |
| Realtime backend (detector + HostedService) | IMPLEMENTADO / VALIDADO EM UAT (latência ciclo ~s) |
| Realtime frontend (OperacoesHub) | IMPLEMENTADO |
| Realtime TV (TvHub público) | IMPLEMENTADO / VALIDADO EM UAT (negotiate + eventos) |
| `tv-kapps-resumo` (anti N+1) | IMPLEMENTADO / VALIDADO EM UAT (TV ~35–40 ms warm) |
| Uso do resumo em Em Picking / Separado / Centro | IMPLEMENTADO |
| PWA mínima | IMPLEMENTADO |
| Circuito UAT 1 → 66 → 65 | VALIDADO EM UAT 29/09/2026 |
| Em Aberto por referência — Backend 1A (Prev* por página; paginação API) | **IMPLEMENTADO** / **VALIDADO EM UAT** 06/10/2026 (cenários observáveis); FE sem paginação |
| Kapps: pausa picagem parcial | **VALIDADO EM UAT PASS** (07/10/2026, enc. 26) — Qty2/`QuantityPicked` mantêm-se; sem alteração BI/66 |
| Kapps: retoma após pausa | **VALIDADO EM UAT PASS** (07/10/2026) — novo `Session_Docs`, mesmo `SessionID`, `DossierLin` reutilizada |
| Kapps: aborto de picagem parcial | **VALIDADO EM UAT PASS** (07/10/2026, enc. 26) — remove `DossierLin`; `QuantityPicked`→0; BI/`u_pickrdy` inalterados; ≠ Cancelar Portal |
| Distribuição: múltiplos 65 abertos (mesmo 66, linhas distintas) | **VALIDADO EM UAT PASS** (07/10/2026, enc. 26) — `Tem65` único 50%; COUNT documental = 2 |
| Distribuição: 2×65 abertos na mesma linha do mesmo 66 | **NÃO OBSERVÁVEL** |

---

## Realtime

### Componentes (**IMPLEMENTADO**)

| Peça | Função |
| --- | --- |
| `ExternalChangeDetector` | Compara 5 watermarks (BO66, BI66, BO65, BI65, Kapps) |
| `ExternalChangeRealtimeHostedService` | Ciclo **5 s**; cold start silencioso; publish Portal depois TV |
| `OperacoesHub` | `/hubs/operacoes`, **`[Authorize]`**, grupo `operacoes` |
| `TvHub` | `/hubs/tv`, **`[AllowAnonymous]`**, grupo `tv`, read-only |

Eventos (sem payload): `dossier66Alterado`, `dossier65Alterado`, `kappsAlterado`, `encomendaAlterada`.

Consumo frontend relevante:

| Evento | Efeito típico |
| --- | --- |
| `encomendaAlterada` | Invalida `encomendas-lista/abertas` (Encomendas e/ou Picking) |
| `dossier66Alterado` | Invalida listas 66; **em modo `/picking`**, também invalida `encomendas-lista/abertas` (SUM 66 pode retirar a encomenda) |
| `dossier65Alterado` | Invalida listas 65 |
| `kappsAlterado` | Refresh Kapps (não a lista de documentos) |

Regras:

- Watermark só avança se publish do **OperacoesHub** OK; falha TV = Warning, não impede avanço se Portal OK.
- Falha de publicação Portal → watermark desse universo **não** avança.
- Cold start: estabelece watermarks, **não** publica.
- Intervalo **5 s**: **não alterar** sem nova medição (**FORA DE ESCOPO** de “otimizar à vontade”).

---

## TV

| Aspecto | Estado |
| --- | --- |
| Rotas `/tv`, `/centro-tv` | Públicas, sem login (**IMPLEMENTADO**) |
| SignalR | `/hubs/tv` (**IMPLEMENTADO**) |
| Polling | `REFRESH_MS = 30_000` como fallback (**IMPLEMENTADO**; manter) |
| Kapps | `GET /api/v1/painel/tv-kapps-resumo` em paralelo à wave1 |

Medição UAT (anti N+1):

| | Antes | Depois |
| --- | ---: | ---: |
| HTTP Kapps | ~13 | 1 |
| Tempo Kapps | ~3,2–4,3 s | ~35–40 ms (warm); frio ~500 ms |
| `carregar()` esperado | ~3,6–4,6 s | ~0,3–0,6 s |

**Não fazer mais optimizações da TV sem medir primeiro.**

---

## Evidência UAT

### Circuito completo 29/09/2026 (**VALIDADO EM UAT**)

**Encomenda**

- ndos = 1, obrano = 10  
- bostamp = `ADM26092936703,170000001`  
- cliente = `6343 AG FLORISUL LDA`  
- 2026-09-29 10:16:42  

**Separado / Syslog 66**

- ndos = 66, obrano = 8  
- bostamp = `Syslog_20260929103114483`  
- 10:31:14  
- Neste contexto observado: fechada = 1 e check-in = 1 (estado no momento da observação do circuito)

**Expedição / Syslog 65**

- ndos = 65, obrano = 1  
- bostamp = `Syslog_20260929105344836`  
- 10:53:44  

**Quantidades neste circuito**

- Quantidade autorizada total = 29  
- `65.BI.qtt` total = 29; `65.BI.qtt2` = 0; todas as linhas 65 com `qtt > 0`  
- Quantidades 65 coincidiram com autorizadas  
- Kapps: 8 linhas; `Quantity` = autorizada; `QuantityPicked = 0`; `QuantityPending = 0`; `QuantitySatisfied = Quantity`  

**Conclusão limitada a esta evidência:**

> Neste processo, `ndos=65.BI.qtt` representa a quantidade expedida.

**Não generalizar** além desta evidência.

### Realtime dossier66 após check-in (**VALIDADO EM UAT**)

Check-in POST → log “Alteração externa detectada: dossier66” em ~4 s (ordem do intervalo 5 s).

---

## Investigações em curso

### `u_Kapps_Session_Docs` (**CONFIRMADO** estrutura; pausa/retoma **VALIDADO EM UAT** 07/10/2026)

Colunas observadas: AppCode, TerminalID, SessionID, SessionUserID, SessionDocNumber, SessionStartDateTime, SessionEndDateTime, SessionType, SessionDocument.

Sessões vistas: `AppCode = SYT`, `SessionType = PIK`.

**CONFIRMADO:**

```text
u_Kapps_Session_Docs.SessionDocNumber = BO.bostamp
```

Exemplos: `ADM26092936703,170000001` → ndos 1; `Syslog_20260929103114483` → ndos 66.

**CONFIRMADO:** `SessionDocument` **não** equivale a `BO.ndos` (mesmo SessionDocument associado a ndos 1 e 66).

**NÃO utilizar `SessionDocument` como ndos.**

**UAT Kapps / multi-65 (enc. 26)** — detalhe: [`auditoria-picking-kapps-distribuicao.md`](./auditoria-picking-kapps-distribuicao.md) §33–§35:

| Cenário | Estado |
| --- | --- |
| Pausa | **PASS** |
| Retoma | **PASS** |
| Aborto | **PASS** |
| Múltiplos 65 abertos (mesmo 66, linhas distintas) | **PASS** |
| 2×65 na mesma linha do mesmo 66 | **NÃO OBSERVÁVEL** |

* Pausa: `DossierLin` `A`/`N` com `Qty2` parcial permanece; `Session_Docs` com End preenchido; sem mudança `BI`/66.
* Retoma: novo `Session_Docs`, **mesmo** `SessionID`; `DossierLin` reutilizada; sem duplicar `Qty2`.
* Aborto: **remove** `DossierLin`; `QuantityPicked` 3→0, `QuantityPending` 5→8; `BI`/`u_pickrdy`/`u_pickstat` inalterados; **não** cria 66/65. **Abortar Kapps ≠ Cancelar Picking Portal.**
* Multi-65: 66#20 → 65#8 (1406) + 65#9 (1414); `Tem65` único → Em Entrega **50%** + Em Expedição **50%**; COUNT documental Em Expedição = 2; Picking remaining ignora 65.

### Hipótese sessão PIK activa (**HIPÓTESE** — não implementar; restringida pelo UAT)

```text
BO.bostamp = SessionDocNumber
SessionType = 'PIK'
SessionEndDateTime IS NULL
  → ? picking efectivamente em curso
```

**Ressalva UAT (07/10/2026):** após pausa e após retoma, os `Session_Docs` observados tinham `SessionEndDateTime` **preenchido**. **Não** concluir que `IS NULL` = “em curso” universal. **Não** alterar código Portal com base nesta hipótese.

---

## Hipóteses não confirmadas

| Hipótese | Estado |
| --- | --- |
| Sessão PIK aberta (`SessionEndDateTime IS NULL`) = picking em curso | **HIPÓTESE** — **não** confirmada pelo UAT pausa/retoma (enc. 26); End preenchido nos snapshots |
| `SessionDocument` = ndos | **Refutada** (CONFIRMADO que não) |
| Quantidade não entregue = autorizada − SUM(qtt em 65 ligados) | **Supersedida** — regra funcional validada = 66 fechado + `SUM(qtt−qtt2)>0` (não usar SUM(65) como regra principal) |
| Distinção formal “Não picada” vs “Não entregue” | PENDENTE (definição de “Não picada”) |
| Kapps `QuantityPicked` = quantidade expedida | **Não usar** (contradiz evidência UAT) |

---

## Trabalho pendente

### Alta prioridade

1. Distinguir formalmente **“Não picada”** vs **“Não entregue”** (esta última já definida e implementada).  
2. Rever acções/transições de Picking.  
3. Se surgir: 2×65 na **mesma linha** do 66; Cenário B `2×66 ativos + 1×65` (pausa/retoma/aborto + multi-65 linhas distintas **PASS** 07/10/2026).  
4. Smoke UAT do fecho operacional Em Expedição na UI (além do smoke SQL já feito).  
5. **Paginação frontend** Em Aberto por referência (`page` / `pageSize` / `totalItems`) — backend 1A já fechado.

### Investigação pendente

7. ~~Validar `u_Kapps_Session_Docs` (pausa/retoma/aborto)~~ — **feito** §33–§34; multi-65 (linhas distintas) **feito** §35.  
8. **Não** decidir “em curso” só com `SessionEndDateTime IS NULL` (ressalva UAT).  
9. Operador / terminal / início a partir da sessão (com cautela).  
10. Fonte PHC mais precisa para “A Preparar Entrega”, se existir evidência.

### UX / informação

11. ~~Campo correcto da morada / método + ⓘ + filtros listas~~ — **IMPLEMENTADO** (30/09/2026). **PENDENTE DE VALIDAÇÃO UAT:** (a) smoke filtro Modo de Expedição nas etapas; (b) circuito Kapps novo com `u_mEntrega` + `u_modExp` preenchidos no `ndos=1` e confirmados em 66/65 + ⓘ.  
12. Navegação entre dossier original e 66/65.  
13. Duplicação de informação em cabeçalhos/linhas.

### Cleanup / documentação

14. Manter este documento alinhado às validações.  
15. Rever relatórios/estatísticas (semântica de quantidades).  
16. Consolidar decisões de arquitectura (este ficheiro é o ponto de partida).

### Futuro (**FORA DE ESCOPO** imediato)

17. Microsoft Login.  
18. Realtime de alterações `ndos=1` só se necessidade operacional comprovada.

---

## O que não implementar ainda

### Sem validação adicional — **não fazer**

- Usar `SessionDocument` como `ndos`.  
- Assumir sessão PIK aberta = picking em curso.  
- Alterar estados do Portal só com essa hipótese.  
- Usar Kapps `QuantityPicked` como quantidade expedida.  
- Usar `BI.qtt` como quantidade original após autorização.  
- Alterar `ST.stock` para disponibilidade da previsão.  
- Change Tracking / CDC / Service Broker nesta fase.  
- Nova BD só para realtime.  
- React Query / SWR só para “resolver” actualização.  
- Complexidade extra sem necessidade operacional comprovada.  
- Mais optimizações da TV sem medição.  
- Baixar intervalo do detector (5 s) sem nova medição.  
- Implementar “Não entregue” com a hipótese antiga `autorizada − SUM(65.qtt)` (regra supersedida).  
- Tratar corte de autorização (`u_qttorig − u_qtdaut` em ndos=1) como sinónimo de «Quantidades não entregues».

---

## Próxima sequência recomendada

1. **Definir “Não picada”** por escrito; só depois código.  
2. Smoke UAT UI: Fechar expedição em `/expedido` → Concluídas; Reabrir.  
3. Smoke UAT: filtro Modo de Expedição (por encomenda em todas as etapas + por referência Em Aberto).  
4. Smoke UAT Kapps: encomenda `ndos=1` com `u_modExp` (+ `u_mEntrega` se possível) → 66 → 65; confirmar BD e ⓘ.  
5. **Paginação FE** Em Aberto por referência (consumir contrato 1A; sem alterar backend).  
6. Quando houver operador em picking real: correr SELECT de sessões PIK abertas; registar resultados aqui (HIPÓTESE → CONFIRMADO ou refutada).  
7. Só então: eventuais ajustes de estado Picking / UI.  
8. Medir realtime/TV antes de qualquer mudança de intervalo ou refetch.

---

## Princípios de desenvolvimento

1. Primeiro confirmar o comportamento real no PHC.  
2. Depois definir a regra de negócio.  
3. Só depois implementar.  
4. Preferir alterações pequenas e isoladas.  
5. Não substituir lógica PHC sem necessidade.  
6. Reutilizar APIs/queries existentes quando possível.  
7. Realtime deve invalidar e provocar refetch, não replicar estado.  
8. Não introduzir infraestrutura pesada sem necessidade.  
9. Medir antes de otimizar.  
10. Não transformar hipóteses em regras de negócio.  
11. Preservar compatibilidade com o PHC.  
12. Se UAT não reproduz o cenário, documentar a limitação em vez de adivinhar.

---

## Tabela-resumo

| Tema | Estado | Confiança | Próxima ação |
| --- | --- | --- | --- |
| Arquitectura Portal sobre PHC | CONFIRMADO / IMPLEMENTADO | Alta | Manter |
| Circuito 1→66→65 | VALIDADO EM UAT | Alta | Usar como referência |
| 65.qtt = expedido (neste circuito) | VALIDADO EM UAT (caso único) | Média | Validar parciais |
| Concluídas = 65 fechado | IMPLEMENTADO | Alta | Não confundir com 66 fechado |
| Fecho operacional 65 (sem faturação) | IMPLEMENTADO | Alta | SPs 083/084; grant `portal_app` só se o user existir na BD |
| Check-in / reverter (UI: Voltar ao Separado) | IMPLEMENTADO / UAT | Alta | Manter |
| Separado: Qtd. documento + badge Entrega parcial | IMPLEMENTADO | Alta | Smoke UAT com parcial real |
| Regra «Quantidades não entregues» (66 fechado + pendente) | IMPLEMENTADO / UAT | Alta | Manter; vista 043 legado sem consumidor |
| `/nao-entregues` (código) | IMPLEMENTADO | Alta | Via `PickingDossiersQuery`; endpoint legado `/cortes-quantidade` |
| Previsões / u_previd / qtdaut | IMPLEMENTADO | Alta | Manter |
| Quantidades pós-autorização | CONFIRMADO | Alta | Não usar qtt como original |
| Realtime 5s + hubs | IMPLEMENTADO / UAT | Alta | Não mudar intervalo sem medir |
| TV pública + tv-kapps-resumo | IMPLEMENTADO / UAT | Alta | Não otimizar sem medir |
| Resumo Kapps em listas/centro | IMPLEMENTADO | Alta | Smoke UX |
| Centro/TV dual métrica (COUNT vs % lógica) | IMPLEMENTADO / UAT | Alta | Não fundir as duas semântica; ver secção Centro/TV |
| Morada `u_mEntrega` + método `u_modExp` + ⓘ | IMPLEMENTADO | Alta | Smoke Kapps 1→66→65 |
| Filtro Modo de Expedição (listas) | IMPLEMENTADO | Alta | Smoke UAT UI |
| Kapps USR cópia `u_mEntrega` / `u_modExp` | IMPLEMENTADO (BD UAT) | Média | Validar com doc novo preenchido |
| Em Aberto por referência — Backend 1A | IMPLEMENTADO / UAT (observáveis) | Alta | Baseline HTTP no § 1A; próximo = paginação FE |
| Sessão Kapps PIK aberta | HIPÓTESE | Baixa | Observar picking real |
| SessionDocument = ndos | Refutado | Alta | Nunca usar |
| Microsoft Login / CT-CDC | FORA DE ESCOPO | — | Adiar |

---

## Checklist SQL — sessão PIK aberta (quando houver picking real)

```sql
SELECT
    s.AppCode,
    s.TerminalID,
    s.SessionID,
    s.SessionUserID,
    s.SessionDocNumber,
    s.SessionStartDateTime,
    s.SessionEndDateTime,
    s.SessionType,
    s.SessionDocument,
    bo.ndos,
    bo.obrano,
    bo.nome
FROM u_Kapps_Session_Docs s
INNER JOIN BO bo
    ON bo.bostamp = s.SessionDocNumber
WHERE s.SessionType = 'PIK'
  AND s.SessionEndDateTime IS NULL;
```

Registar resultado neste documento (data, stamps, conclusão: confirma / refuta hipótese).

---

## Referências no repositório

| Recurso | Notas |
| --- | --- |
| `docs/business-flows.md` | Fluxos MVP; Centro/TV e circuito armazém alinhados à UI. Para hipóteses/UAT/pendentes preferir este ficheiro (`PROJECT-STATE`) |
| `docs/auth-portal-identity.md` | Identity |
| `docs/api-contract.md` | Contratos API (incl. `distribuicaoLogica` em `centro-estados`; `procura-aberta` + paginação 1A) |
| Código realtime | `Portal.Api/Realtime`, `Portal.Application/Realtime`, hubs |
| Código TV Kapps | `PainelQuery.ListarTvKappsResumoAsync`, `CentroTvPage`, `tvKappsResumo.ts` |
| Código distribuição lógica | `DistribuicaoLogicaCalculator`, `PainelQuery.ContarDistribuicaoLogicaAsync`, `centroUi.tsx` |
| Em Aberto por referência 1A | `EncomendasService.ListarProcuraAbertaAsync`, `EncomendasQuery` (Fase1 linhas / Fase2 Prev* por chaves); SoT: secção **Backend 1A** neste ficheiro |
