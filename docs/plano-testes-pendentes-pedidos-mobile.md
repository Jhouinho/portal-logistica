# Plano de testes pendentes — Pedidos Mobile

| | |
| --- | --- |
| **Âmbito** | Lacunas após validação na cópia `HCA-SQL` / `LillianaSerodioPhc` |
| **Código de referência** | Branch `wip/portal-mobile-qr-20261022`, HEAD `4ded0451582d10d8dda998e48df40175902b632c` |
| **Estado** | Actualizado pós **78** (P2-01 validado). Parte P1, P2-01 e P2-03 (fluxos reportados/ensaiados) validados na cópia; restantes pendentes |

Referências:

- [`validacao-pedidos-mobile-copia-hca-sql.md`](./validacao-pedidos-mobile-copia-hca-sql.md) — evidências e inventário de pedidos 10–17
- [`entrega-tecnica-pedidos-mobile-uat.md`](./entrega-tecnica-pedidos-mobile-uat.md) — UAT `portal-local` (pedidos 4 e 5)
- `sql/104_doc_estados_operacionais_pedidos_mobile.sql` — semântica actual dos estados

**Fora de âmbito:** produção, Etapa 4, alterações estruturais de BD/arquitectura.

---

## 0. Estado dos cenários (resumo 77)

Legenda de estado: **validado** | **parcialmente validado** | **pendente** | **bloqueado**.

### Validados nos ensaios observados (cópia HCA-SQL)

| ID | Cenário | Estado | Fase | Limitação residual |
| --- | --- | --- | --- | --- |
| PM-P1-01 | Edição de linhas `PUT /linhas` | **validado** | **70F-A** (pedido 12) | Não cobriu todos os estados de erro possíveis; cancelamento interno indisponível |
| — | Aprovação + repetição idempotente (sequencial) | **validado** | **69B** (pedido 11) | Sem COUNT SQL independente na 69B |
| PM-P1-02 | Concorrência (2 aprovações simultâneas) | **validado** | **70G** (pedido 13) | Uma corrida; não stress/carga |
| PM-P1-03 | Recuperação após falha parcial SP→mark | **validado** (ensaio) | **70I** (pedido 14) | Ensaio controlado com harness isolado; **não** todos os modos de falha |
| PM-P2-01 | Idempotência **repetida** de `pronto_levantamento` e `concluir` | **validado** | **78** (pedido 17) | Sequencial; não carga; timestamps com precisão de segundo |
| PM-P2-03 | Runtime API com conta `portal_app` | **parcialmente validado** → fluxos **74** + ops **78** | **74** / **78** | Só cópia; **não** produção |

Evidência anterior **preservada**: Fases **68B–71** e **70F-A–70I** (ver matriz em `validacao-…`). Fases **72–73** (estático/RO) e **75–76** (auth) alimentaram a 74; não as apagam.

### Ainda pendentes / parciais

| ID | Cenário | Estado | Prioridade | Nota |
| --- | --- | --- | --- | --- |
| PM-P2-02 | Criação com `PedidosInternosEnabled=false` | **pendente** | P2 | Flag activa nas criações desta cópia |
| PM-P2-03 | Runtime `portal_app` (além dos fluxos 74/78) | **parcialmente validado** | P2 | Residual = cenários não cobertos |
| PM-P2-04 | Várias linhas + IVA/totais nesta cópia | **parcialmente validado** → PHC **validado (82)** | P2 | **79** totais PM; **82** IVA/BO67 (taxa PT 6%, 2 linhas); residual: outras taxas/descontos |
| — | Compatibilidade estado legado `integrado` | **parcialmente validado** (estático) | P2 | Aceite no código / docs; sem ensaio dedicado pós-aprovação nesta cópia |
| PM-P3-01 | Cobertura completa de filtros / estados históricos | **parcialmente validado** | P3 | **81**: filtros estado/`top`/alias `integrados`; pesquisa texto continua só UI |
| PM-P3-02 | Matriz 401/403 | **parcialmente validado** | P3 | **81**: 401 sem sessão + isolamentoação cliente/staff; **403** role Admin não E2E |
| — | Carga / concorrência além de dois clientes | **pendente** | P3+ | 70G = 2 clientes |
| — | Produção / Etapa 4 | **bloqueado** | — | Autorização independente |

**Limitação transversal:** a recuperação (70I) foi validada num ensaio controlado, não em todos os cenários possíveis de falha. A ausência de falhas nos cenários testados **não** é garantia geral de ausência de defeitos.

---

## 1. Estados (contexto para os testes)

| Valor em `EstadoInterno` | Papel no código actual |
| --- | --- |
| `em_separacao` | Valor **escrito** após aprovação bem-sucedida (`TryMarcarIntegradoAsync`) |
| `integrado` | Valor **legado** ainda aceite (listagens, mapper UI); **não** é o valor gravado pelas aprovações actuais |
| `pronto_levantamento` / `concluido` | Transições via `POST …/operacao` (só `u_HcaPmPedido`) |

Não tratar `integrado` e `em_separacao` como sinónimos livres: strings distintas; equivalência de regras de negócio, não de identidade.

---

## 2. Casos — validados (referência)

### PM-P1-01 — Edição de linhas (`PUT /linhas`) E2E — **VALIDADO (70F-A)**

| | |
| --- | --- |
| **Pedido** | 12 / `PM-2026-000012` / `70FATEST` |
| **Resultado** | qtt, add, remove, qtt=0→400, restore; `PrecoSubmissao` preservado; sem PHC |
| **Resíduo** | Pedido permanece `recebido` (cancelar interno proibido) |
| **Contrato (código)** | Ver revisão 70E; sem SP / sem `bo`/`bi` |

### PM-P1-02 — Concorrência na aprovação — **VALIDADO (70G)**

| | |
| --- | --- |
| **Pedido** | 13 / `PM-2026-000013` / `70GATEST` |
| **Resultado** | 2× HTTP 200; RO: 1 idem + 1 `bo`; `em_separacao`; `obrano=15`, `boano=2026`, `ndos=67` |
| **Nota** | Flags `alreadyExistsBo` / `alreadyIntegrated` diferiram entre respostas; mesmo resultado persistido |
| **Não cobre** | >2 clientes / stress |

### PM-P1-03 — Falhas parciais e recuperação — **VALIDADO num ensaio (70I)**

| | |
| --- | --- |
| **Pedido** | 14 / `PM-2026-000014` / `70IATEST` |
| **Método** | Host TEMP isolado: gateway PHC real + store real; falha após SP, antes de `TryMarcarIntegradoAsync` |
| **Parcial** | `em_aprovacao` sem IDs no pedido; RO 1+1 |
| **Recuperação** | 1× aprovar → `em_separacao`; `obrano=16`, `boano=2026`, `ndos=67`; mesmo Bostamp; RO 1+1 |
| **70H** | Análise estática: execução bloqueada até existir injecção; sem escrita |
| **Limitação** | Não generalizar a timeouts de rede, falhas SQL no mark, ou outros modos |

---

## 3. Casos ainda pendentes ou parciais

### PM-P2-01 — Idempotência de `pronto_levantamento` e `concluir` — **VALIDADO (78)**

| | |
| --- | --- |
| **Pedido** | 17 / `PM-2026-000017` / `78OPTEST` |
| **Resultado** | 1.ª+2.ª `pronto_levantamento` HTTP 200; 1.ª+2.ª `concluir` HTTP 200 → `concluido`; repeats sem alterar `DecididoPor`/`DataDecisao`/`DataAlteracao`/IDs PHC |
| **SQL RO** | 1 idem `HCA-PM-APROV-17`; 1 `bo` (`obrano=18`); 1 `bi` |
| **Contrato (código)** | Early-return 200 sem regravar auditoria se já no destino — **observado** |
| **Não cobre** | Carga / concorrência nas operações |

### PM-P2-02 — Percurso legado (`PedidosInternosEnabled=false`) — **PENDENTE**

| | |
| --- | --- |
| **Prioridade** | P2 |
| **Objectivo** | Submissão cliente → `CriarLegadoAsync` / SP imediata |
| **Dependências** | Processo sem flag; auth PHC; restauro |

### PM-P2-03 — Execução com `portal_app` — **PARCIALMENTE VALIDADO (74)**

| | |
| --- | --- |
| **Prioridade** | P2 (residual) |
| **Estado** | Fluxos **reportados** na Fase **74** na cópia: `/health`; login staff/cliente; lista staff + detalhe **12**; criar+rejeitar **15** (`74TEST`, sem BO); criar+aprovar **16** (`74APPROVE` → `em_separacao`, `ndos=67`/`obrano=17`/`boano=2026`); SQL reportado: 1× `HCA-PM-APROV-16` + 1× `bo`; CS só processo; user-secrets inalterados |
| **Histórico** | 67D grants RO; 68–70I runtime usou **`sa`** via secrets; 72–73 estático/chaining; 76 auth candidata |
| **Não coberto pela 74** | Produção; IIS; repeat operação; flag desligada; multi-linha/IVA; filtros sistemáticos; 401/403; carga; demais modos de falha |
| **Segurança** | Password **fora** de docs/código/logs/repo; rotação futura deve considerar serviços dependentes; **não** rodar nesta documentação |
| **Dependências (residual)** | Credencial só em processo; sem gravar no repo |

### PM-P2-04 — Múltiplas linhas, totais e IVA — **PARCIALMENTE VALIDADO (79)**

| | |
| --- | --- |
| **Pedido** | 18 / `PM-2026-000018` / `79VATTEST` (sem aprovação) |
| **Validado** | ≥2 linhas; qtt/preços distintos; `TotalLinha`/`Etotaldeb` Round(6, AwayFromZero); `PrecoSubmissao` preservado; API↔SQL; sem PHC |
| **Não validado** | IVA / total com IVA — campos **ausentes** em `u_HcaPm*` e DTOs staff; IVA só na SP ao criar `bo`/`bi` |
| **Anomalia** | Investigada na **80** (estática): causa confirmada; correção **não** implementada |
| **Residual P2** | (a) patch mínimo `maxOrd` pós-delete **ou** renumeração 1..n; (b) IVA outras taxas/descontos (82 cobriu PT 6% / 2 linhas / sem desconto) |

### Compatibilidade com estado legado `integrado` — **PARCIAL (estático)**

| | |
| --- | --- |
| **Prioridade** | P2 |
| **Estado** | Documentado e aceite no código; aprovações actuais gravam `em_separacao` (11/13/14/16) |
| **Pendente** | Ensaio dedicado de listagem/operação sobre registo ainda em `integrado` nesta cópia |

### PM-P3-01 — Filtros e listagens — **PARCIALMENTE VALIDADO (81)**

| | |
| --- | --- |
| **Validado** | `GET /api/v1/staff/pedidos-mobile?filtro=&top=`; default=`pendentes`; alias `integrados`≡`em_separacao` (3 `integrado` + 6 `em_separacao`); `top` limita; detalhe RO coerente |
| **Não no API** | Pesquisa textual / datas — pesquisa na UI opera sobre a lista já carregada |
| **Residual** | Contagem exacta `em_aprovacao` (0 linhas na cópia no ensaio) |

### PM-P3-02 — Autenticação e autorização — **PARCIALMENTE VALIDADO (81)**

| | |
| --- | --- |
| **Validado** | Sem sessão → **401** (staff PM, cliente, admin); cliente autenticado → staff/admin **401**; staff → cliente **401**; staff Admin → admin GET **200** |
| **Não demonstrado** | **403** autenticado sem role Admin (existe utilizador não-Admin na lista; password não disponível; sem criar contas) |
| **Nota** | Staff PM usa só `[Authorize]` (sem role); 403 aplica-se a endpoints `[Authorize(Roles=Admin)]` |

### Carga / concorrência alargada — **PENDENTE**

Além da corrida com **dois** clientes (70G): **não testado**.

---

## 4. Estratégia de execução futura (grupos)

| Grupo | Casos | Salvaguardas |
| --- | --- | --- |
| **B — API só leitura** | P3-01, P3-02 | Auth; sem escrita |
| **C — Escrita portal** | P2-01 (se BO já ligado); ensaio `integrado` legado | Sintéticos; não reutilizar 10–16 sem plano |
| **D — Cria PHC** | P2-02, P2-04 | Backup/restauro; confirmar alvo |
| **E — Runtime menor privilégio** | Residual P2-03 (cenários não cobertos na 74) | Connection string só processo |

Antes de qualquer escrita: confirmar `HCA-SQL` / `LillianaSerodioPhc` (ou alvo **explicitamente** autorizado).

**Ordem sugerida restante:** P3-02 (401/403) → P3-01 (filtros) → residual `LinhaOrd` (implementação futura, fora desta análise) → residual P2-03 / `integrado` → IVA PHC (fase própria com aprovação) → P2-02.

**Etapa 4 / produção:** fora deste plano até autorização independente.

---

## 5. Revisão estática 70E (histórico)

A secção 70E classificou a *preparação* dos testes (não o resultado do sistema). Após 70F-A/70G/70I, P1-01/02/03 passaram a **validados nos ensaios** (secção 0), com as limitações aí indicadas. Após **74**, P2-03 passou a **parcialmente validado** para os fluxos reportados. A classificação 70E de P2/P3 restantes mantém-se como referência de preparação.

Ficheiros inspecionados na 70E: `StaffPmPedidosController` / `Service`, `ClientePmPedidoStore`, `StaffPmPedidoRules` / `PrecoRules`, `StaffPmBo67Gateway`, `ClientePedidosService`; unitários `StaffPmConcurrencyTests` (fakes).
