# Validação Pedidos Mobile — cópia HCA-SQL

| | |
| --- | --- |
| **Ambiente** | Cópia de teste `LillianaSerodioPhc` no servidor `HCA-SQL` (`192.168.0.3`) |
| **Código de referência** | Branch `wip/portal-mobile-qr-20261022`, HEAD `4ded0451582d10d8dda998e48df40175902b632c` |
| **Janela** | Outubro 2026 (fases 67D–78; consolidação documental **71** / **77**) |
| **Estado** | Validação funcional **parcial** na cópia (incl. runtime `portal_app` na **74**/**78**); **não** é validação de produção |

Documentação relacionada (não substituída):

- [`entrega-tecnica-pedidos-mobile-uat.md`](./entrega-tecnica-pedidos-mobile-uat.md) — entrega UAT `portal-local` (21/10/2026; pedidos 4 e 5)
- [`plano-testes-pendentes-pedidos-mobile.md`](./plano-testes-pendentes-pedidos-mobile.md) — testes pendentes e estado pós-74 / consolidação **77**
- [`portal-mobile-estados.md`](./portal-mobile-estados.md) — estados do dossier **legado** cliente (distinto de `u_HcaPmPedido`)
- Scripts RO / docs SQL: `sql/101_*`, `sql/102_*`, `sql/103_*`, `sql/104_*`
- Runbooks de produção: [`prod-passo-a-passo-aplicar-pedidos-mobile.md`](./prod-passo-a-passo-aplicar-pedidos-mobile.md) (âmbito **distinto**; não confundir com esta cópia)

---

## 1. Ambiente e âmbito

### 1.1. O que foi validado aqui

Testes controlados via API local (`http://localhost:5080`) e, na 70I, um host de teste **temporário fora do repositório**, contra a BD de teste acima, com:

- Flag `Portal:Cliente:PedidosInternosEnabled=true` **apenas** no processo da API (variável de ambiente), **sem** persistência em ficheiros ou user-secrets.
- Contas de teste de cliente e staff já disponibilizadas (credenciais **não** registadas neste documento).
- Backup / recuperação da cópia: afirmados pelo utilizador antes das escritas; procedimento de restauro **não** foi reexecutado nestas fases.
- **Fase 74 (reportada):** API com identidade SQL `portal_app` via `Phc__ConnectionString` **só no processo** (user-secrets inalterados). Passwords **não** constam deste documento.

### 1.2. Limites explícitos

| Incluído | Excluído |
| --- | --- |
| Submissão interna, rejeição, aprovação → `ndos=67`, operação `pronto_levantamento` / `concluir` | Etapa 4 / produção / IIS de destino |
| Pré-requisitos SQL em modo **READ-ONLY** (67D) | SQL manual de escrita; DELETE de dossiers `bo`/`bi` |
| Edição de linhas E2E (70F-A); concorrência 2 sessões (70G); falha parcial controlada + recuperação (70I) | Stress / carga além de 2 clientes; todos os modos de falha possíveis |
| Runtime API com `portal_app` nos fluxos reportados na **74** | Produção; IIS destino; rotação de password nesta documentação |
| | Frontend; builds de produto; commit/push nestas fases de teste |

**Esta cópia ≠ produção.** Resultados não autorizam activação em ambiente real. Dossiers sintéticos **não** são dados de produção; **não** se propõe eliminação manual de `bo`/`bi`.

### 1.3. Estados após aprovação (`integrado` vs `em_separacao`)

| Aspeto | Evidência |
| --- | --- |
| Valor **persistido** após aprovação no código actual | `EstadoInterno = N'em_separacao'` em `ClientePmPedidoStore.TryMarcarIntegradoAsync` |
| Observado na cópia (69B/70B/70G/70I; **74** reportada) | Pedidos **11**, **13**, **14**, **16**: pós-aprovação `em_separacao` (11 depois → `concluido`) |
| Papel de `integrado` | Constante e ramo de regras ainda activos; SQL **104** descreve-o como **legado equivalente** a `em_separacao` |
| Documentação UAT 21/10/2026 | [`entrega-tecnica-pedidos-mobile-uat.md`](./entrega-tecnica-pedidos-mobile-uat.md) §3: pedidos 4/5 medidos como `integrado` nessa janela |

**Resolução documental:** usar `em_separacao` para o estado pós-aprovação **actual**. Tratar `integrado` como valor legado ainda aceite. Não afirmar que os pedidos UAT 4/5 “eram” `em_separacao` sem evidência dessa data.

---

## 2. Matriz consolidada (fases 68B–74)

Nota (consolidação **77**): as evidências SQL da Fase **74** são as **reportadas** nesse relatório de execução; esta fase documental **não** reexecutou SQL nem API.

Legenda de **tipo de evidência**:

| Código | Significado |
| --- | --- |
| **E** | Execução real (HTTP/API e/ou SQL RO reportado na mesma fase) |
| **U** | Relato do utilizador |
| **C** | Análise estática / leitura de código |
| **T** | Teste com fakes / unitários (não reexecutados nesta consolidação) |
| **—** | Não testado |

| Fase e cenário | Tipo | Resultado observado | Limitações | Referência |
| --- | --- | --- | --- | --- |
| **67D** — pré-requisitos SQL RO | **E** | Objectos TVP/`edebito`, SP, `u_HcaPm*`, idem, grants `portal_app` visíveis | Grants ≠ runtime API | Alvo `HCA-SQL` / `LillianaSerodioPhc` |
| **68B** — rejeição | **E** | Pedido **10** `PM-2026-000010` → `rejeitado`; sem dossier PHC | Um pedido sintético | Pedido 10 |
| **69B** — aprovação + 2.ª aprovação | **E** | Pedido **11** `PM-2026-000011` → `em_separacao`; `ndos=67`, `obrano=14`, `boano=2026`; 2.ª aprovação devolveu o **mesmo** dossier (`alreadyIntegrated` / `alreadyExistsBo`) | **Sem** contagem SQL independente de dossiers nesta fase; não atribuir evidência RO de 70G/70I | Pedido 11 |
| **70A** — consolidação matriz / planeamento | **C** | Matriz e lacunas documentadas | Sem novas escritas | Docs 70A/70C |
| **70B** — operação | **E** | Pedido **11**: `pronto_levantamento` → `concluir` → `concluido`; **uma** chamada por acção | Repetição idempotente de operação **não** observada experimentalmente | Pedido 11 |
| **70C / 70D** — docs / coerência estados | **C** | Docs de validação e plano; `em_separacao` vs `integrado` | Sem execução de testes | Docs |
| **70E** — revisão estática Grupo A | **C** | Contratos P1–P3; classificação preparação | Sem HTTP/SQL | Plano §5 (70E) |
| **70F** — PUT `/linhas` (tentativa) | **E** (só RO) | Sem alvo sintético elegível (10/11 terminais; 6 sem marcador inequívoco) → **sem escrita** | Bloqueio por critério de segurança | Relatório 70F |
| **70F-A** — PUT `/linhas` E2E | **E** | Pedido **12** `PM-2026-000012`, `70FATEST`: qtt, add/remove linha, qtt=0 → 400, restore; `PrecoSubmissao` preservado; ficou `recebido` sem PHC | Cancelamento interno recusado (`interno_proibido`); resíduo | Pedido 12 |
| **70G** — concorrência (2× aprovar) | **E** | Pedido **13** `PM-2026-000013`, `70GATEST`; ambos HTTP 200; **1** linha idem + **1** `bo` (RO); `em_separacao`, `ndos=67`, `obrano=15`, `boano=2026` | Uma corrida com 2 clientes; `alreadyExistsBo` / `alreadyIntegrated` **diferiram** entre respostas com o mesmo resultado persistido (observação, **sem** concluir defeito) | Pedido 13; chave `HCA-PM-APROV-13` |
| **70H** — falha parcial (prep.) | **C** | Execução **bloqueada**: sem mecanismo de injecção disponível | Sem escrita; sem pedido novo | Relatório 70H |
| **70I** — falha parcial + recuperação | **E** | Pedido **14** `PM-2026-000014`, `70IATEST`; harness TEMP (gateway+store reais); SP OK → falha antes do mark → `em_aprovacao` sem IDs no pedido; RO: 1 idem + 1 BO; 1× recover → `em_separacao`, `obrano=16`, `boano=2026`, `ndos=67`, mesmo Bostamp; pós-RO ainda 1+1 | Ensaio **controlado** único; não cobre todos os modos de falha; harness removido | Pedido 14; chave `HCA-PM-APROV-14` |
| Preços `PUT …/precos` | **U** (+ **T**) | Utilizador confirmou; unitários existem | Sem acta HTTP nesta sequência | — |
| Percurso legado (`PedidosInternosEnabled=false`) | **—** | — | Flag activa nas criações desta cópia | Plano P2-02 |
| **72** — permissões `portal_app` (RO / impersonação) | **C** + RO catalog | Grants/HAS_PERMS; leitura PM OK sob impersonação; INSERT PHC directo ausente | Sem EXEC SP; sem login API | Relatório 72 |
| **73** — ownership chaining SPs | **C** | SPs `CALLER`, owners dbo→dbo; chaining **provável** | Sem EXEC como `portal_app` | Relatório 73 |
| **74** — runtime API `portal_app` | **E** (reportada) | Health/login/lista/detalhe 12; pedido **15** `74TEST` criado+rejeitado sem BO; pedido **16** `74APPROVE` aprovado → `em_separacao`; reportado: 1 idem `HCA-PM-APROV-16` + 1 `bo` (`ndos=67`, `obrano=17`, `boano=2026`); CS só processo; API encerrada / 5080 livre | Só fluxos reportados; **não** produção; evidência SQL não revalidada na 77 | Pedidos 15, 16 |
| **75 / 76** — login/auth `portal_app` | **E** (76) / **C** (75) | Login+user associados; auth SQL candidata **VALIDADA** na 76 após reset operador | Password **fora** desta doc | Relatórios 75–76 |
| **78** — idempotência `pronto_levantamento` / `concluir` | **E** | Pedido **17** `PM-2026-000017` (`78OPTEST`), `portal_app` processo; aprovado → `em_separacao` (`ndos=67`, `obrano=18`, `boano=2026`); 1.ª+2.ª `pronto_levantamento` HTTP **200**, estado estável, auditoria/IDs inalterados na 2.ª; 1.ª+2.ª `concluir` HTTP **200** → `concluido`, auditoria/IDs inalterados na 2.ª; RO: 1 idem `HCA-PM-APROV-17` + 1 `bo` + 1 `bi` | Uma sessão sequencial; não carga; timestamps com precisão de segundo | Pedido 17 |
| **79** — multi-linha / totais (sem aprovar) | **E** (parcial) | Pedido **18** `PM-2026-000018` (`79VATTEST`); 2 linhas na criação → PUT 3 linhas com qtt/preços distintos; `TotalLinha`/`Etotaldeb` = Round 6dp AwayFromZero; `PrecoSubmissao` preservado em L1/L2; sem Bostamp/Obrano/Ndos; sem idem aprovação / `bo`; **IVA não** no modelo PM interno | IVA só na SP/`bo`/`bi` (fora do ensaio); 2.º PUT com `linhaOrd=null` gerou gap `LinhaOrd` 3→4 | Pedido 18 |
| **80** — investigação `LinhaOrd` (estática) | **C** | Causa do gap 3→4: `null` = linha **nova**; órfãs fora de `keptOrigens` são DELETE; `maxOrd` usa snapshot **pré-delete** → INSERT `max+1`. UI operador reenvia `linhaOrd` após save. SP/`lordem` aceita gaps. Helper `BuildLinhasSubstituicao` renumeraria 1..n mas **não** é usado pelo store real | Sem correção nesta fase; pedido **18** preservado | Relatório 80 |
| Multi-linha / IVA nesta cópia | **parcial (79) + PHC (82)** | 79: totais PM; 82: IVA/BO67 | Ver 79/82 | Plano P2-04 |
| **81** — filtros lista + auth 401/(403) | **E** (parcial) | GET staff filtros `pendentes`/`em_separacao`/`integrados`/`pronto_levantamento`/`concluidos`/`rejeitados`/`todos` + `top`; alias `integrados`≡`em_separacao` (incl. 3× `integrado`→codigo `em_separacao`); sem sessão→401; cliente↛staff e staff↛cliente→401; staff admin OK | **403** não demonstrado (sem password de Identity não-Admin; PM só `[Authorize]`); pesquisa UI é client-side | Relatório 81 |
| **82** — IVA/totais no BO67 | **E** | Pedido **19** `82IVATEST`; gate SP100+`regiva`; 2×1051; approve → `ndos=67`/`obrano=19`; BI `iva=6`/`ivaincl=1`/`ettdeb` OK; `BO.etotaldeb=38.91`; 1 idem + 1 `bo` + 2 `bi` | Sem descontos; só taxa PT 6%; um artigo | Pedido 19 |
| Filtros listagem sistemáticos | **parcial (81)** | Filtros estado/`top` OK | Pesquisa texto só na UI | Plano P3-01 |
| Matriz 401/403 | **parcial (81)** | 401 + isolamentoação esquemas OK | 403 role Admin não E2E | Plano P3-02 |
| Carga / concorrência >2 clientes | **—** | — | — | — |

---

## 3. Inventário de pedidos sintéticos conhecidos

Lista dos registos **conhecidos nas fases anteriores** (incl. relatório **74**). **Não** é o resultado de uma consulta actual à base de dados (consolidação documental **77**; sem SQL nesta fase).

| Pedido | Identificação | Estado / conclusão conhecida |
| --- | --- | --- |
| 10 | `PM-2026-000010` | Rejeitado, sem dossier |
| 11 | `PM-2026-000011` | Concluído, dossier `ndos=67`, `obrano=14`, `boano=2026` |
| 12 | `PM-2026-000012` (`70FATEST`) | Resíduo de edição de linhas; `recebido` à data 70F-A; sem dossier |
| 13 | `PM-2026-000013` (`70GATEST`) | `em_separacao`, dossier `ndos=67`, `obrano=15`, `boano=2026` |
| 14 | `PM-2026-000014` (`70IATEST`) | `em_separacao`, dossier `ndos=67`, `obrano=16`, `boano=2026` |
| 15 | `PM-2026-000015` (`74TEST`) | Rejeitado (74, `portal_app`); sem dossier — **reportado** |
| 16 | `PM-2026-000016` (`74APPROVE`) | `em_separacao` (74, `portal_app`); dossier `ndos=67`, `obrano=17`, `boano=2026` — **reportado** |
| 17 | `PM-2026-000017` (`78OPTEST`) | `concluido` (78, `portal_app`); dossier `ndos=67`, `obrano=18`, `boano=2026`; repeats operação HTTP 200 sem regravar auditoria |
| 18 | `PM-2026-000018` (`79VATTEST`) | `recebido` (79); 3 linhas; `Etotaldeb=81.203703`; sem PHC; resíduo edição; `LinhaOrd` final 1,2,4 |
| 19 | `PM-2026-000019` (`82IVATEST`) | `em_separacao` (82); dossier `ndos=67`, `obrano=19`, `boano=2026`; `BO.etotaldeb=38.91`; 2 `bi` IVA 6% |

Estes dossiers são **dados de teste** na cópia. Não eliminar `bo`/`bi` manualmente; limpeza preferida = restauro da cópia quando autorizado.

---

## 4. Evidências operacionais (síntese por pedido)

### 4.1. Pedido 10 — rejeição (68B)

| Campo | Valor observado |
| --- | --- |
| Criação | `origem=interno`, `recebido`, sem ligação PHC |
| Rejeição | `POST …/rejeitar` → HTTP **200** → `rejeitado` |
| PHC | Sem `Bostamp` / `Obrano` / `Ndos` após rejeição |

### 4.2. Pedido 11 — aprovação e operação (69B, 70B)

| Campo | Valor observado |
| --- | --- |
| 1.ª aprovação | HTTP **200** → `em_separacao`; `ndos=67`, `obrano=14`, `boano=2026` |
| 2.ª aprovação | HTTP **200**; mesmos identificadores (evidência **HTTP**; sem COUNT SQL nesta fase) |
| `pronto_levantamento` / `concluir` | Uma chamada cada → estado final **`concluido`**; IDs dossier estáveis |

### 4.3. Pedido 12 — linhas (70F-A)

| Campo | Valor observado |
| --- | --- |
| Casos | A qtt; B add; C remove; D qtt=0 → **400**; restore |
| `PrecoSubmissao` | Preservado nas alterações observadas |
| Final | `recebido`, sem PHC; cancelar → `interno_proibido` → **resíduo** |

### 4.4. Pedido 13 — concorrência (70G)

| Campo | Valor observado |
| --- | --- |
| 2× `POST …/aprovar` | Ambos **200** (~paralelo) |
| SQL RO | `u_HcaPedidoMobileIdem` = **1**; `bo` = **1** |
| Final | `em_separacao`; `obrano=15`, `boano=2026`, `ndos=67` |
| Flags HTTP | `alreadyExistsBo` / `alreadyIntegrated` diferiram entre as duas respostas |

### 4.5. Pedido 14 — falha parcial + recuperação (70I)

| Campo | Valor observado |
| --- | --- |
| Injecção | Host TEMP: após SP OK, antes de `TryMarcarIntegradoAsync` |
| Parcial | `em_aprovacao`; pedido sem IDs PHC; RO: 1 idem + 1 BO (`obrano=16`) |
| Recuperação | Uma aprovação → `em_separacao`; mesmos IDs; RO pós: 1+1 |
| Limpeza | Harness removido; API parada; sem artefactos 70I no repo |

### 4.6. Pedidos 15 e 16 — runtime `portal_app` (Fase 74, reportada)

Evidência **reportada pelo operador** no relatório de execução da Fase 74. A consolidação **77** **não** reexecutou HTTP, SQL, builds nem testes. Alvo: `HCA-SQL` / `LillianaSerodioPhc`. Identidade SQL: `portal_app` via `Phc__ConnectionString` só no processo (user-secrets inalterados). Password **ausente** desta documentação.

| Campo | Valor reportado |
| --- | --- |
| `/health` | HTTP **200** |
| Login staff e cliente | HTTP **200** |
| Lista staff + detalhe pedido **12** | HTTP **200** |
| Pedido **15** (`74TEST`) | Criado e **rejeitado**; sem dossier PHC |
| Pedido **16** (`74APPROVE`) | Criado e **aprovado uma vez** → `em_separacao` |
| Dossier (16) | `ndos=67`, `obrano=17`, `boano=2026` |
| SQL (reportado) | 1 idempotência `HCA-PM-APROV-16`; 1 `bo` correspondente |
| Encerramento | API terminada; porta **5080** livre |
| Não alterado (74) | Grants, login, password, user-secrets (segundo relatório) |

**Não** é validação de produção. Fluxos não listados acima permanecem **não** cobertos pela 74.

### 4.7. Pedido 17 — idempotência operacional (Fase 78)

| Campo | Valor observado |
| --- | --- |
| Criação | `origem=interno`, marcador `78OPTEST`, `recebido`, sem dossier |
| Aprovação | HTTP **200** → `em_separacao`; `ndos=67`, `obrano=18`, `boano=2026`; `Bostamp=1A7F54E4-B66E-46B9-ABCA` |
| `pronto_levantamento` 1.ª | HTTP **200** → `pronto_levantamento`; IDs dossier estáveis |
| `pronto_levantamento` 2.ª | HTTP **200**; mesmo estado; `DecididoPor` / `DataDecisao` / `DataAlteracao` / IDs **inalterados** vs 1.ª |
| `concluir` 1.ª | HTTP **200** → `concluido`; `DataDecisao`/`DataAlteracao` actualizados nesta transição |
| `concluir` 2.ª | HTTP **200**; mesmo estado; auditoria e IDs **inalterados** vs 1.ª |
| SQL RO | 1× `HCA-PM-APROV-17`; 1× `bo` (`ndos=67`/`obrano=18`/`boano=2026`); 1× `bi`; linha cor `78OPTEST` |
| Runtime | `portal_app` via `Phc__ConnectionString` só processo; user-secrets inalterados (`sa`) |

Comportamento alinhado com early-return no código quando já no destino (sem regravar auditoria). **Não** é teste de carga nem de produção.

### 4.8. Anomalia `LinhaOrd` — investigação estática (Fase 80)

**Sintoma (79):** após 1.º `PUT /linhas` com L3 `linhaOrd=null` → ord **3**; 2.º PUT com o **mesmo** payload (L3 ainda `null`) → ord **4** (posições `1,2,4`).

**Causa provável (código `TrySubstituirLinhasOperadorAsync`):**

1. `LinhaOrd` no pedido = **identidade de origem** para UPDATE + preservação de `PrecoSubmissao`; `null` = INSERT novo.
2. Linhas existentes cujo `LinhaOrd` **não** aparece no payload entram em `toDelete` e são apagadas.
3. `maxOrd` é calculado a partir do snapshot `existentes` **antes** dos DELETE (o comentário “após deletes” não corresponde ao código): com existentes `1,2,3` e keep `1,2`, `maxOrd` fica **3**; após apagar `3`, o INSERT faz `maxOrd++` → **4**.

**Papel de `LinhaOrd`:** chave de ordenação/identidade estável no pedido interno (`UQ (PedidoId, LinhaOrd)`), **não** exige contiguuidade. Na aprovação, TVP/`linha_ord` → `bi.lordem = linha_ord * 10000` (SP); gaps são aceites desde que únicos.

**Consumidores:**

| Consumidor | Dependência de contíguos? |
| --- | --- |
| `OperadorPedidoDetailView` | Não — após save usa `linhaOrd` devolvido (`linhaOrdOrigem`); `null` só em linhas ainda não gravadas |
| `PedidosMobileDetailPage` (preços) | Usa `linhaOrd` como chave de mapa/UI; gaps OK |
| Detalhe API / `ORDER BY LinhaOrd` | Ordem crescente; sem renumeração |
| `PedidoMobileLinhaTvp` + SP 100 | Unicidade de `linha_ord`; **não** exige 1..n sem buracos |
| `StaffPmPrecoRules.BuildLinhasSubstituicao` | Renumeraria 1..n (testes unitários / fakes); **não** chamado pelo store de produção |

**Severidade:** baixa para integração PHC; cosmética na UI se o número for mostrado; risco se um cliente reenviar `null` para linha já persistida (DELETE+INSERT, possível reset de `PrecoSubmissao` em linhas “novas” recriadas).

**Correção mínima proposta (não implementada na 80):**

1. **Store (preferível, pequena):** após os DELETE, recalcular `maxOrd` só a partir das linhas **mantidas** (`keptOrigens`), p.ex. `maxOrd = keptOrigens.Count == 0 ? 0 : keptOrigens.Max()` — no cenário 79 o INSERT reutilizaria **3**.
2. **Alternativa alinhada aos testes:** persistir via `BuildLinhasSubstituicao` (renumeração 1..n) — maior impacto, mas remove a divergência store vs helper.
3. **Mitigação operacional (já na UI):** nunca reenviar `null` após o servidor ter atribuído `LinhaOrd`; o ensaio 79 violou esse contrato de propósito.

Pedido **18** e restantes sintéticos: **preservados** (fase só análise).

### 4.9. Operações pós-aprovação (código — 70B/70E/78)

`POST …/operacao`: actualiza só `u_HcaPmPedido`; **não** chama a SP nem altera `bo`/`bi`/idem neste percurso. Idempotência de repeat `pronto_levantamento`/`concluir`: **prevista no código** e **demonstrada** na 78 (pedido 17).

---

## 5. Idempotência e recuperação — estado actual

| Cenário | Estado da validação |
| --- | --- |
| Aprovação repetida (mesmo `PedidoId`, sequencial) | **Validada** (69B, HTTP) |
| Chave SP `HCA-PM-APROV-{PedidoId}` | Código + 69B/70G/70I; chave `HCA-PM-APROV-16` **reportada** na 74 |
| Concorrência real (2 sessões) + COUNT RO | **Validada** num ensaio (70G); não generalizar a carga |
| Falha parcial SP OK → mark falha → re-aprovar | **Validada** num ensaio controlado (70I); não todos os modos de falha |
| Runtime API `portal_app` (fluxos 74 / 78) | **Validado** na cópia para os fluxos **reportados/ensaiados**; **não** produção |
| Repetir `pronto_levantamento` / `concluir` | **Validado** (78, pedido 17; sequencial; early-return sem regravar auditoria) |
| Percurso legado / multi-linha nesta cópia / filtros / 401–403 | **Não** validados |

---

## 5bis. Segurança — `portal_app` (cópia; consolidação 77)

| Aspeto | Registo |
| --- | --- |
| Âmbito | Validado **apenas** na cópia de teste e para os fluxos reportados na **74** |
| Password | **Não** deve constar de documentação, código, logs ou repositório |
| Fase 74 | Sem alteração de grants, login, password ou user-secrets (relatório recebido) |
| Produção | Prontidão **não** demonstrada |
| Rotação futura | Considerar serviços dependentes do mesmo login; **não** efectuada nesta fase |

---

## 6. Limitações e riscos pendentes

1. ~~Idempotência **repetida** de `pronto_levantamento` e `concluir`~~ — **validada** na 78 (pedido 17); residual: só ensaio sequencial, não carga.
2. Criação com `PedidosInternosEnabled=false`.
3. Runtime `portal_app`: **parcialmente** coberto (fluxos 74 + operação 78); **não** cobre produção nem todos os cenários do plano.
4. Pedidos multi-linha e IVA/totais **nesta** cópia.
5. Cobertura completa de filtros e estados históricos na listagem.
6. Testes 401/403.
7. Concorrência / carga além de dois clientes.
8. Recuperação: validada num ensaio instrumentado (70I), **não** em todos os cenários de falha (timeouts de rede, falhas SQL no mark, etc.).
9. Compatibilidade operacional explícita com estado legado `integrado` (aceite no código; sem ensaio dedicado nesta cópia além da documentação).
10. Produção / Etapa 4: **fora de âmbito**.
11. Limpeza de dossiers de teste: sem DELETE seguro; preferir restauro da cópia.
12. Evidência SQL da 74: **reportada**; não revalidada na consolidação 77.

---

## 7. Encerramento das sessões de teste

Nos finais de sessão reportados (68B–70I e **74**):

- API local parada quando iniciada; porta **5080** livre no encerramento (incl. relatório 74).
- Flag temporária **não** persistida.
- Frontend **não** iniciado.
- Sem SQL manual de escrita nas fases de teste; harness 70I apenas em TEMP e removido.
- Mockups PNG não rastreados a preservar:
  - `Dashboard de Pedidos Mobile em Azul Escuro.png`
  - `Gestão de Pedidos Mobile em Ecrãs.png`

### Estado Git na consolidação documental (71 / 77)

| Momento | Observação |
| --- | --- |
| Início 71 | Branch `wip/portal-mobile-qr-20261022`, HEAD `4ded045…`; docs `M`/`??` e 2 PNG `??` pré-existentes |
| Fim 71 | Mesmo HEAD; apenas alterações documentais neste ciclo (**sem** commit) |
| Início / fim **77** | Mesmo branch e HEAD `4ded045…`; só docs; mockups `??` intactos; **sem** commit / push; **sem** API, SQL, builds ou testes nesta fase |
| Fim **78** | Mesmo HEAD; API 5080 encerrada; CS/`PedidosInternos` de processo limpos; docs actualizados; mockups intactos; **sem** commit / push |

---

## 8. Conclusão

Na cópia `HCA-SQL` / `LillianaSerodioPhc` foram exercitados, com pedidos sintéticos distintos: rejeição (**10**), aprovação + operação até `concluido` (**11**), edição de linhas (**12**), concorrência de aprovação com evidência RO (**13**), recuperação após falha parcial controlada (**14**), e — **reportado** na Fase **74** sob `portal_app` — rejeição (**15**) e aprovação (**16**, `obrano=17`); e na Fase **78** — operação + repeats até `concluido` (**17**, `obrano=18`).

A confiança é **alta** para os percursos ensaiados (e reportados) descritos. A ausência de falhas nesses cenários **não** garante ausência geral de defeitos. Permanecem lacunas materiais (secção 6). **Etapa 4 / produção:** continua **bloqueada**.

Lacunas e próximos testes: [`plano-testes-pendentes-pedidos-mobile.md`](./plano-testes-pendentes-pedidos-mobile.md).
