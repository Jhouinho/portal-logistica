# Pacote operacional — recolha IT/DBA antes da Fase 1 (Pedidos Internos)

| | |
| --- | --- |
| Projecto | Liliana & Seródio — Portal Logística |
| Ambiente | **UAT** · servidor `HCA-SQL` · BD `LillianaSerodioPhc` |
| Âmbito | Recolha de evidências e decisões **antes** de executar scripts Fase 1 |
| Checklist de execução | [`uat-checklist-provisionamento-portal-app-pedidos-internos.md`](./uat-checklist-provisionamento-portal-app-pedidos-internos.md) |
| Feature flag | `Portal:Cliente:PedidosInternosEnabled` = **`false`** (versionado e a manter no host) |
| Actualizado | 2026-10-20 |

> **Este documento não autoriza execução.** Não executar SQL de escrita, não alterar IIS, não activar a feature, não testar a API com pedidos internos.  
> Não registar passwords, tokens nem connection strings completas nas respostas.

---

## 0. O que já está confirmado **documentalmente** (repositório)

| Item | Estado documental | Fonte |
| --- | --- | --- |
| Alvo UAT declarado | `HCA-SQL` / `LillianaSerodioPhc` | Checklist UAT |
| Flag versionada | `PedidosInternosEnabled: false` em `appsettings.json` | Código versionado — **não** prova valor no IIS |
| Principal previsto pelos scripts | `portal_app` | `sql/000_criar_login_portal_app.sql`, grants `030`/`091c`/`092b`/`093`/`094`/`095`/`096c` |
| Pack base vs mobile/`096*` | Mobile e `096*` **fora** de `DEPLOY_CLIENTE_BI2_BO3.sql` | Pack + `portal-mobile-deploy-uat.md` |
| Seed de teste | `090_seed_clone_encomendas_teste.sql` **excluído** da sequência normal | `SQL_APLICAR_CLIENTE.md` |
| Rollback oficial `096*` | **Inexistente** no repositório | Checklist F.3 |
| Histórico 0B | `portal_app` marcado **pendente execução UAT** (doc histórico) | `fase-0b-preparacao-ambiente.md` — **não** prova estado actual da BD |
| Relato operacional prévio | User `portal_app` ausente em `sys.database_principals` (nesta BD) | Entrada do checklist — **a revalidar pelo DBA** |

**Nada disto conclui os gates 1–3.** Tudo o que depende de IIS ou SQL Server actual permanece **por validar**.

---

## 1. O que só pode ser confirmado no IIS ou no SQL Server

| Domínio | Responsável | Gate bloqueado até resposta |
| --- | --- | --- |
| Identidade efectiva da API (connection string no host) | IT / IIS | 1 e 3 |
| Login/user `portal_app` e mapeamento | DBA | 1 e 2 |
| Existência/conformidade de objectos e grants | DBA | 1 (pré) e 2 (pós) |
| Backup + autorização escrita + restauro | IT / DBA / gestor | 1 |
| Flag efectiva no host | IT / operador app | 1–3 (deve ser `false`) |

Consultas de leitura recomendadas: secções **B.*** e **E.2** / **B.7** do [checklist](./uat-checklist-provisionamento-portal-app-pedidos-internos.md).  
Zero linhas em metadados ≠ prova automática de ausência — ver notas B.2–B.4 do checklist.

---

## 2. Perguntas e evidências pedidas ao IT/DBA

Preencher as colunas «Resposta / evidência» e «Quem / data». **Sem segredos.**

### A. Identidade efectiva da aplicação (IIS)

Não deduzir a partir de `appsettings.json`, conta SSMS ou Application Pool Identity sem cruzar com a **configuração efectiva** da connection string PHC no site da API.

| # | Pergunta | Evidência aceite (exemplos) | Resposta / evidência | Quem / data |
| --- | --- | --- | --- | --- |
| A1 | Qual o **AuthMode** efectivo da ligação PHC? (`SQL` / `Windows` / Integrated) | Print/redacção de config IIS/env **sem** password; nota do IT | | |
| A2 | Qual o **principal** efectivo (`User Id` SQL ou conta Windows) usado pela API para abrir a BD? | Mesmo, só o nome do principal | | |
| A3 | Qual o **database user** correspondente na BD `LillianaSerodioPhc`? | Resultado DBA de mapeamento SID / `sys.database_principals` | | |
| A4 | Onde está definida a connection string efectiva? (env `Phc__ConnectionString`, ficheiro protegido no servidor, outro) — **sem** colar a string completa | Nome da fonte (ex. «variável de ambiente do App Pool X») | | |
| A5 | `Portal:Cliente:PedidosInternosEnabled` no **host** UAT é `false`? | Confirmação IT/operador no IIS ou ficheiro de config do servidor | | |

### B. Login e utilizador `portal_app`

Servidor e BD correctos: `HCA-SQL` · `LillianaSerodioPhc`. Não criar/alterar/eliminar nesta fase de recolha.

| # | Pergunta | Evidência aceite | Resposta / evidência | Quem / data |
| --- | --- | --- | --- | --- |
| B1 | Existe login `portal_app` em `sys.server_principals`? `type_desc`? `is_disabled`? | Output B.2 do checklist (DBA) | | |
| B2 | Existe user `portal_app` em `sys.database_principals` nesta BD? | Output B.3 | | |
| B3 | O mapeamento login↔user (SID) está correcto? | Output B.4; nota se órfão | | |
| B4 | Há problemas de SID, login disabled, ou permissões de metadados que invalidem B1–B3? | Parecer DBA | | |
| B5 | Se não conforme: é necessária **criação** (`000`) ou **só** `CREATE USER` (C.2) ou outra correcção? | Decisão DBA **proposta** (ainda sem executar) | | |

### C. Estado actual dos objectos SQL

Classificar cada objecto: **inexistente** · **conforme** · **parcial** · **existe com diferenças**. Zero linhas ≠ ausência definitiva sem parecer DBA.

| Objecto | Script de referência | Classificação | Notas / evidência (B.5, B.6, E.2) | Quem / data |
| --- | --- | --- | --- | --- |
| `u_HcaPmPedido` | `096` | | | |
| `u_HcaPmPedidoLin` | `096b` | | | |
| `sp_HCA_criar_pedido_mobile` | `091` / `093` | | | |
| `HCA_PedidoMobileLinhaType` | `091` / `093` | | | |
| `u_HcaClienteAuth` | `092` | | | |
| `u_HcaPedidoMobileCancel` | `094` | | | |
| `sp_HCA_cancelar_pedido_mobile` | `095` | | | |
| Amostra pack base (`view_HCA_encomendas_abertas`, `sp_HCA_reabrir_expedicao_dossier`, …) | Pack BI2/BO3 | | | |

Para Fase 1, o bloqueio directo é o estado de `u_HcaPmPedido` / `Lin`. Objectos mobile influenciam a sequência se ainda forem necessários no mesmo GO UAT (ver secção 4).

### D. Permissões (separar os três níveis)

Direitos alvo Fase 1 (`096c`): cab `SELECT, INSERT, UPDATE`; lin `SELECT, INSERT` — para o principal **da aplicação**, tipicamente `portal_app`.

| # | Nível | Evidência pedida | Resposta | Quem / data |
| --- | --- | --- | --- | --- |
| D1 | **Explícitas** ao user | B.7.1 (`sys.database_permissions` grantee `portal_app`) | | |
| D2 | **Herdadas** (roles) | Membership + grants às roles — inventário DBA | | |
| D3 | **Efectivas** | B.7.2 (`EXECUTE AS` + `HAS_PERMS_BY_NAME`) **ou** verificação equivalente segura do DBA | | |

Não assumir que permissões de `sa` ou do login do SSMS = permissões da API.  
Se B.7.2 não for seguro/possível → DBA fornece equivalente; falha de impersonação ≠ ausência de grants (ver checklist).

### E. Backup e autorização

Cópia de teste + menção a backup **≠** autorização para alterar a BD.

| # | Pergunta | Evidência aceite | Resposta | Quem / data |
| --- | --- | --- | --- | --- |
| E1 | Confirma-se que o alvo é a cópia UAT `LillianaSerodioPhc` em `HCA-SQL` (não produção)? | Confirmação escrita | | |
| E2 | Existe backup **antes** da intervenção? Data, local, responsável | Registo IT (sem paths sensíveis desnecessários) | | |
| E3 | Existe procedimento de **restauro** conhecido e, se aplicável, já testado? | Confirmação IT/DBA | | |
| E4 | Há **autorização explícita** por escrito para executar os scripts listados na secção 4 (quando as pré-condições estiverem OK)? | Ref. ticket / email / acta | | |
| E5 | Quem é o **responsável técnico** pela execução SQL e pela validação posterior (gate 2)? | Nome / função | | |

---

## 3. Matriz de decisão (cenário → evidência → responsável → decisão)

| Cenário | Evidência necessária | Responsável | Decisão permitida |
| --- | --- | --- | --- |
| Identidade IIS **desconhecida** | A1–A4 | IT | **PARAR** — sem gate 1 nem gate 3 |
| Identidade IIS conhecida mas **≠** `portal_app` (ou cutover só planeado) | A1–A4 + plano formal | IT + DBA | **PARAR** testes/app com `portal_app`; não editar só `096c`; alinhar IIS **ou** decisão formal de principal (todo o modelo de grants) |
| Login `portal_app` **inexistente** (confirmado DBA) | B1 | DBA | Propor `000` (login+user) **após** A* e E*; **não executar** nesta recolha |
| User `portal_app` **inexistente** / SID incorrecto | B2–B4 | DBA | Propor C.2 (`CREATE USER`) ou correcção SID; **não executar** nesta recolha |
| Login disabled / metadados ambíguos | B1–B4 | DBA | **PARAR** até parecer DBA |
| Objectos Fase 1 **inexistentes** (confirmado) | C + B.5 | DBA | Candidato a gate 1 **depois** de A/B/E OK |
| Objectos **parciais** (só cab ou só lin) | C + E.2 | DBA | **PARAR** execução cega; análise DBA (C.5 checklist) |
| Objectos com **diferenças** de estrutura | E.2 completo | DBA | **PARAR**; sem DROP/ALTER automático; sem rollback inventado |
| Diferenças em índices/constraints (ausentes, disabled, not trusted, INCLUDE/filtro) | E.2.4–E.2.6 | DBA | **PARAR** / intervenção DBA |
| Grants **ausentes** ou efectivas insuficientes | D1–D3 | DBA | Após user+tabelas: propor `096c` (e outros grants se mobile); **não** grants a `sa` |
| B.7.1 vazio mas B.7.2 = 1 | D1–D2 | DBA | Inventariar roles; não assumir falha de `096c` |
| Backup ou autorização **não** confirmados | E1–E5 | IT / gestor | **PARAR** — sem gate 1 |
| Flag no host ≠ `false` | A5 | IT | **PARAR** até `false`; sem activar feature nesta fase |
| Tudo A/B/C/E OK, objectos ausentes, user OK | Pacote preenchido | Gestor + DBA | **Pode** autorizar gate 1 (execução suite) — acto separado |
| Após `096*`, E.2+B.7 OK | Gate 2 evidência | DBA / operador | Declarar «Fase 1 pronta» — **não** implica gate 3 |
| Fase 1 pronta + IIS alinhado + flag `false` | Gate 2+3 pré-reqs | Gestor | Gate 3 = autorização **independente** para testes API (activar flag = decisão futura explícita, fora deste pacote) |

**Não inventar solução automática** para estados inesperados: escalar DBA/IT e registar na folha H do checklist.

---

## 4. Sequência de deployment prevista (plano — sujeito a autorização)

Ordem de referência (não executar nesta tarefa):

| Ordem | Camada | Scripts / acção | Notas |
| --- | --- | --- | --- |
| 0 | Identidade | `sql/000_criar_login_portal_app.sql` (se B5 o exigir) | Ajustar BD `LillianaSerodioPhc`; password fora do Git |
| 1 | Pack base (se objectos base em falta) | `sql/DEPLOY_CLIENTE_BI2_BO3.sql` (+ `030` no fim do pack) | **Não** inclui mobile nem `096*` |
| 1b | Grant base pontual | `sql/030_grant_portal_app.sql` | Se grants saltados |
| 2 | Mobile legado (se no mesmo GO e objectos em falta) | `091` → `091c` → `092`+`092b` → `093` → `094` → `095` | Ver `portal-mobile-deploy-uat.md`; **fora** do pack |
| 3 | Fase 1 | `096` → `096b` → `096c` | Só com gate 1 autorizado |
| — | Excluído | `090_seed_clone_encomendas_teste.sql` | Não executar |
| — | Rollback `096*` | *(não existe oficial)* | Restauro via backup IT; sem DROP automático |

Pré-condições oficiais gerais: `docs/SQL_APLICAR_CLIENTE.md`, recuperação pack: `docs/SQL_RECUPERAR_DEPLOY_CLIENTE.md`.

---

## 5. Critérios de saída e próximo passo por gate

| Gate | Significado | Pode marcar «validado com evidência operacional» quando… | Próximo passo permitido |
| --- | --- | --- | --- |
| **1** | Autorização para executar suite `096*` | A1–A5, B1–B5, E1–E5 OK; C classifica Fase 1 como inexistente ou GO DBA para create; gestor autoriza por escrito | DBA executa `096`→`096b`→`096c` (e pré-requisitos acordados) |
| **2** | Fase 1 pronta na BD | Após execução: E.2 completo + D1–D3 OK (checklist) | Documentar «Fase 1 pronta»; **ainda sem** testes API / sem activar flag |
| **3** | Autorização para testar a API | Gate 2 + identidade IIS alinhada (A*) + autorização **nova** e explícita; flag só sob decisão futura | Smoke/API — **fora** deste pacote de recolha |

| Estado deste pacote (2026-10-20) | |
| --- | --- |
| Gate 1 | **Por validar** (sem evidência operacional IIS/SQL) |
| Gate 2 | **Por validar** (scripts Fase 1 não executados nesta tarefa) |
| Gate 3 | **Por validar** (sem autorização de testes; flag permanece `false`) |

Validado **documentalmente** apenas o conteúdo da secção 0 (intenção do projecto e restrições).  
**Não** confundir com validação operacional.

---

## 6. Folha-resumo para devolver ao projecto

| Campo | Valor |
| --- | --- |
| Data da recolha | |
| IT (IIS) | |
| DBA | |
| Gestor / autorização | |
| Principal IIS (sem segredo) | |
| `portal_app` login / user / mapeamento | |
| Classificação `u_HcaPmPedido` / `Lin` | |
| Permissões D1/D2/D3 | |
| Backup + autorização (refs.) | |
| Decisão: pode pedir gate 1? (sim/não) | |
| Bloqueios remanescentes | |

---

## Referências

| Doc / script | Caminho |
| --- | --- |
| Checklist execução | `docs/uat-checklist-provisionamento-portal-app-pedidos-internos.md` |
| SQL aplicar cliente | `docs/SQL_APLICAR_CLIENTE.md` |
| Mobile deploy UAT | `docs/portal-mobile-deploy-uat.md` |
| Prep. ambiente 0B (histórico) | `docs/fase-0b-preparacao-ambiente.md` |
| Estado projecto | `docs/PROJECT-STATE.md` |
| Login/user | `sql/000_criar_login_portal_app.sql` |
| Grant base | `sql/030_grant_portal_app.sql` |
| Mobile | `sql/091*`, `092*`, `093*`, `094*`, `095*` |
| Fase 1 | `sql/096*.sql` |

*Fim do pacote de recolha. Devolver preenchido antes de qualquer execução da suite Fase 1.*
