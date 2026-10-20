# Checklist operacional UAT — provisionamento `portal_app` e Pedidos Internos (Fase 1)

| | |
| --- | --- |
| Projecto | Liliana & Seródio — Portal Logística (`portal-logistica`) |
| Ambiente-alvo | **UAT** |
| Servidor SQL | `HCA-SQL` |
| Base de dados | `LillianaSerodioPhc` |
| Feature | Pedidos Internos Mobile — **Fase 1** (persistência interna) |
| Feature flag | `Portal:Cliente:PedidosInternosEnabled` deve permanecer **`false`** |
| Documento | Operacional autónomo para operador / IT / DBA |
| Actualizado | 2026-10-20 |
| Fontes | Scripts em `sql/`; `docs/SQL_APLICAR_CLIENTE.md`; `docs/SQL_RECUPERAR_DEPLOY_CLIENTE.md`; `docs/deployment-architecture.md`; `docs/portal-mobile-deploy-uat.md`; `docs/fase-0b-permissoes-sql-app.md`; `docs/PROJECT-STATE.md` |

> **Âmbito deste documento:** orientar verificação e execução controlada em UAT.  
> **Não** activa a funcionalidade. **Não** concede permissões a `sa`. **Não** altera isoladamente o `096c` para contornar ausência de `portal_app`.  
> Credenciais, passwords e connection strings completas **não** devem ser registadas neste ficheiro nem em tickets públicos.

> **Antes de executar scripts:** preencher o pacote de recolha IT/DBA  
> [`uat-recolha-it-dba-pedidos-internos-fase1.md`](./uat-recolha-it-dba-pedidos-internos-fase1.md)  
> (perguntas A–E, matriz de decisão, critérios de saída dos gates). Sem esse pacote respondido, os gates 1–3 permanecem **por validar**.

---

## A. Estado inicial e pré-condições

Marcar cada item antes de qualquer script de escrita (`CREATE` / `GRANT`).

### A.1 Identificação do alvo

| # | Pré-condição | Responsável | Estado |
| --- | --- | --- | --- |
| A1 | Confirmar sessão SQL no servidor **`HCA-SQL`** (não produção) | DBA / operador SQL | ☐ |
| A2 | Confirmar base de dados **`LillianaSerodioPhc`** (`DB_NAME()`) | DBA / operador SQL | ☐ |
| A3 | Confirmar que o ambiente é **UAT** e que existe **autorização escrita** para executar scripts nesta BD | Gestor / operador autorizado | ☐ |
| A4 | Confirmar **backup** da cópia de testes e procedimento de restauro acordado com IT (informação do operador: backup existente — **validar data/local**) | IT / DBA | ☐ |
| A5 | Confirmar procedimento de recuperação conhecido: ver secção F e `docs/SQL_RECUPERAR_DEPLOY_CLIENTE.md` (pack BI2/BO3). **Lacuna:** esse doc não cobre rollback de tabelas `096*` | Todos | ☐ |

### A.2 Identidade efectiva da API (IIS) — bloqueante

| # | Pré-condição | Responsável | Estado |
| --- | --- | --- | --- |
| A6 | No IIS / variáveis de ambiente do site da API, identificar o **modo de autenticação SQL** (SQL auth vs Integrated) e o **User Id** ou conta Windows usada pela connection string PHC (`Phc__ConnectionString` / `Phc:ConnectionString`) — **sem** copiar password nem connection string completa | IT / IIS | ☐ |
| A7 | Registar apenas: `AuthMode=…` · `Principal=…` (ex. `portal_app` / outro / Windows `DOMAIN\…`) | IT | ☐ |
| A8 | Confirmar em config da API (IIS ou ficheiro protegido no servidor) que `Portal:Cliente:PedidosInternosEnabled` é **`false`** (valor versionado em `appsettings.json` = `false`; o valor **efectivo** no IIS pode diferir — validar no host) | IT / operador app | ☐ |

**Regra:** enquanto A6–A7 não estiverem preenchidos **com o principal efectivo no host**, **não** executar `000_criar_login_portal_app.sql`, **não** reexecutar grants massivos, e **não** aplicar `096` / `096b` / `096c` com a expectativa de que a API use `portal_app`. Um plano de alinhamento IIS ainda por executar **não** satisfaz A6–A7 nem o GO de testes da aplicação (A.5).

### A.3 Login e utilizador `portal_app`

| # | Pré-condição | Responsável | Estado |
| --- | --- | --- | --- |
| A9 | Resultado das consultas B.2 / B.3 (login instância + user BD) documentado | DBA | ☐ |
| A10 | Resultado do mapeamento B.4 documentado | DBA | ☐ |

Estado conhecido à data deste checklist (entrada): user `portal_app` **não** encontrado em `sys.database_principals` nesta BD. Login em `sys.server_principals` e identidade IIS = **pendente de confirmação**.

### A.4 Objectos / grants já existentes

| # | Pré-condição | Responsável | Estado |
| --- | --- | --- | --- |
| A11 | Consultas B.5–B.7 executadas e resultados anexados (ticket / runbook) | DBA | ☐ |
| A12 | Se tabelas Fase 1 já existirem parcialmente → seguir cenário C.5 **antes** de reaplicar scripts | DBA | ☐ |

### A.5 Critério de GO / NO-GO — três decisões distintas

Não misturar estes gates (alinhados com C.1, E.1 e E.7):

| Gate | O que autoriza / declara | Condição |
| --- | --- | --- |
| **1 — Autorização para executar a suite Fase 1** (`096`→`096b`→`096c`) | Executar scripts de **schema** (`096`/`096b`) **e** grant (`096c`) | A1–A8 OK; `portal_app` existe como **database user** mapeado ao login previsto (B.2–B.4 confirmados por DBA se metadados ambíguos); A6–A7: identidade **efectiva** da API no IIS identificada e **já alinhada** com o principal adoptado (tipicamente `portal_app`); flag `false`. **Plano de cutover por executar ≠ alinhamento concluído** |
| **2 — Validação do provisionamento** | Declarar que schema + permissões estão correctos na BD (**não** é autorização de testes de API) | Após os scripts: **E.2 completo OK** + identidade SQL (B.2–B.4; DBA se ambíguo) + permissões (B.7.1 **e** B.7.2 ou DBA) → estado **“Fase 1 pronta”** (E.7). Só E.2 sem grants = **“Schema criado”**, ainda não “Fase 1 pronta”. Executar os scripts **não** prova sozinho o gate 2 |
| **3 — Autorização para testar a API** com a identidade efectiva do IIS | Smoke / uso da app contra o schema | Gate 2 (“Fase 1 pronta”) **e** A6–A7 confirmados no host (mesmo critério de alinhamento **já concluído** que no gate 1; E.1). **Plano pendente ≠ GO**. Gate 2 **não** autoriza automaticamente o gate 3. Activar `PedidosInternosEnabled` continua **fora** desta checklist |
| **NO-GO** (qualquer gate) | Parar | A1–A8 falha; user ausente (confirmado); IIS desconhecido / outro principal / alinhamento só planeado; backup não confirmado; ambiente duvidoso; estrutura ou permissões por validar quando se pretende declarar gate 2 ou 3 |

**Coerência:** o alinhamento IIS exigido no gate 1 e no gate 3 é o **mesmo** (efectivo e concluído). O gate 2 valida objectos/grants na BD; o gate 3 só acrescenta a autorização operacional de testar a API — não relaxa A6–A7.

**Estado documental (sem evidência UAT nesta auditoria):** gate 1 ☐ · gate 2 ☐ · gate 3 ☐ — nenhum marcado como concluído.

---

## B. Consultas SQL de diagnóstico (apenas leitura)

> Executar em SSMS / ferramenta equivalente com permissões de leitura de metadados.  
> **Proibido neste passo:** `CREATE`, `ALTER`, `DROP`, `GRANT`, `REVOKE`, `INSERT`, `UPDATE`, `DELETE`.

### B.1 Contexto — servidor e base de dados

| | |
| --- | --- |
| Nível | **Obrigatório:** sessão já ligada à BD `LillianaSerodioPhc` (ou `USE` explícito antes da consulta) |
| Esperado | `@@SERVERNAME` identifica `HCA-SQL` (ou alias conhecido); **`DB_NAME() = N'LillianaSerodioPhc'`** (comparação exacta; ver coluna `db_name_ok`) |
| Se diferente | **PARAR** — sessão no alvo errado. Não executar mais diagnósticos nem scripts até corrigir o contexto |
| Metadados | Normalmente visível a qualquer login autenticado |

```sql
USE [LillianaSerodioPhc];
GO

SELECT
    @@SERVERNAME AS server_name,
    SERVERPROPERTY(N'MachineName') AS machine_name,
    DB_NAME() AS database_name,
    CASE WHEN DB_NAME() = N'LillianaSerodioPhc' THEN 1 ELSE 0 END AS db_name_ok,
    SUSER_SNAME() AS connected_as,
    ORIGINAL_LOGIN() AS original_login,
    SYSDATETIMEOFFSET() AS checked_at;

-- Critério explícito: db_name_ok deve ser 1.
-- Equivalente: ASSERT mental / checklist — DB_NAME() = N'LillianaSerodioPhc'
```

---

### B.2 Login `portal_app` na instância

| | |
| --- | --- |
| Nível | Instância (`master` ou qualquer BD) |
| Esperado | 1 linha se o login existir e for visível; 0 linhas = **aparente** ausência |
| Se 0 linhas | **Não** concluir C.3 só com este resultado. Confirmar com **DBA** (metadados / VIEW SERVER STATE). Só então: se login realmente inexistente → C.3; **não** criar login sem autorização + confirmação IIS |
| Se 1 linha | Anotar `type_desc`, `is_disabled` |
| Metadados | Pode falhar ou devolver vazio se o login actual não puder ver `sys.server_principals` — **obrigatório** confirmar com DBA antes de decidir existência |

```sql
SELECT
    name,
    type_desc,
    is_disabled,
    create_date,
    modify_date
FROM sys.server_principals
WHERE name = N'portal_app';
```

---

### B.3 Utilizador `portal_app` na base de dados

| | |
| --- | --- |
| Nível | **Obrigatório:** BD `LillianaSerodioPhc` |
| Esperado | 1 linha (estado saudável para grants do projecto) se o user existir e for visível |
| Se 0 linhas | **Ausência aparente** — não prova sozinha que o user não existe. Confirmar com **DBA**. Depois: C.2 (login existe, falta user) ou C.3 (falta login), conforme B.2 validado |
| Metadados | Visibilidade de `sys.database_principals` pode ser limitada |

```sql
USE [LillianaSerodioPhc];
GO

SELECT
    dp.name AS database_user,
    dp.type_desc,
    dp.authentication_type_desc,
    dp.create_date,
    dp.modify_date,
    dp.sid
FROM sys.database_principals AS dp
WHERE dp.name = N'portal_app';
```

---

### B.4 Mapeamento utilizador ↔ login de servidor

| | |
| --- | --- |
| Nível | BD `LillianaSerodioPhc` (+ leitura de `sys.server_principals`) |
| Esperado (com metadados visíveis) | User `portal_app` com `server_principal` = `portal_app` (SQL auth) **ou** mapeamento explícito documentado |
| Se user existe e `server_principal` é NULL | Pode ser SID órfão **ou** falta de visibilidade sobre `sys.server_principals` — **não concluir sozinho**; **exigir validação por DBA** |
| Se resultado **vazio** (0 linhas) | **Não prova** por si só a ausência do login nem a ausência de mapeamento. Pode dever-se a: (1) user realmente inexistente nesta BD; (2) **visibilidade limitada** de `sys.database_principals` / `sys.server_principals`. Cruzar com B.2/B.3 executados por **DBA** com permissões adequadas antes de decidir C.2/C.3 |
| Se login confirmado pelo DBA e user não | Cenário C.2 |
| Metadados | JOIN e catálogos de servidor podem devolver vazio ou incompleto sem privilégios suficientes (ex. VIEW SERVER STATE / role adequada). Resultado ambíguo → **escalar DBA**; não avançar grants nem `000` com base só neste SELECT |

```sql
USE [LillianaSerodioPhc];
GO

SELECT
    dp.name AS database_user,
    dp.type_desc AS db_type,
    sp.name AS server_principal,
    sp.type_desc AS server_type,
    sp.is_disabled
FROM sys.database_principals AS dp
LEFT JOIN sys.server_principals AS sp
    ON dp.sid = sp.sid
WHERE dp.name = N'portal_app';

-- Interpretação:
-- · 1 linha + server_principal preenchido → mapeamento aparente OK (ainda assim DBA confirma se houver dúvida).
-- · 0 linhas OU server_principal NULL → resultado NÃO CONCLUSIVO sem validação DBA dos metadados.
```

---

### B.5 Tabelas Fase 1 (`u_HcaPmPedido` / `u_HcaPmPedidoLin`)

| | |
| --- | --- |
| Nível | BD `LillianaSerodioPhc` |
| Esperado **antes** de `096*` | Ambos `NULL` (objectos ainda não criados) |
| Esperado **depois** de `096`+`096b` | Ambos NOT NULL |
| Se um existe e o outro não | Cenário C.5 — **não** correr `096c` até cab+lin alinhados |
| Metadados | `OBJECT_ID` costuma ser fiável com permissão mínima na BD |

```sql
USE [LillianaSerodioPhc];
GO

SELECT
    OBJECT_ID(N'dbo.u_HcaPmPedido', N'U') AS id_u_HcaPmPedido,
    OBJECT_ID(N'dbo.u_HcaPmPedidoLin', N'U') AS id_u_HcaPmPedidoLin;
```

---

### B.6 Objectos operacionais e mobile relevantes

| | |
| --- | --- |
| Nível | BD `LillianaSerodioPhc` |
| Esperado | Objectos base do Portal tipicamente presentes se o ambiente UAT já serve o Portal; mobile (`091`/`094`/`095`) **podem** estar ou não — confirmar sem assumir |
| Se objectos base em falta | Avaliar pack `DEPLOY_CLIENTE_BI2_BO3.sql` (secção D) **antes** de Fase 1; não afirmar que o pack já correu |
| Se mobile em falta | Não bloqueia criação das tabelas `096*`, mas bloqueia validação do fluxo legado BO (`ndos=67`) |
| Metadados | Ausência = objecto inexistente **ou** (raro) falta de permissão — cruzar com DBA |

```sql
USE [LillianaSerodioPhc];
GO

SELECT N'view_HCA_encomendas_abertas' AS obj,
       OBJECT_ID(N'dbo.view_HCA_encomendas_abertas', N'V') AS object_id
UNION ALL SELECT N'sp_HCA_reabrir_expedicao_dossier',
       OBJECT_ID(N'dbo.sp_HCA_reabrir_expedicao_dossier', N'P')
UNION ALL SELECT N'u_HcaLogiUsers',
       OBJECT_ID(N'dbo.u_HcaLogiUsers', N'U')
UNION ALL SELECT N'sp_HCA_criar_pedido_mobile',
       OBJECT_ID(N'dbo.sp_HCA_criar_pedido_mobile', N'P')
UNION ALL SELECT N'HCA_PedidoMobileLinhaType',
       TYPE_ID(N'dbo.HCA_PedidoMobileLinhaType')
UNION ALL SELECT N'u_HcaPedidoMobileCancel',
       OBJECT_ID(N'dbo.u_HcaPedidoMobileCancel', N'U')
UNION ALL SELECT N'sp_HCA_cancelar_pedido_mobile',
       OBJECT_ID(N'dbo.sp_HCA_cancelar_pedido_mobile', N'P')
UNION ALL SELECT N'u_HcaClienteAuth',
       OBJECT_ID(N'dbo.u_HcaClienteAuth', N'U');
```

Critério de sanidade do pack (documentado em `SQL_RECUPERAR_DEPLOY_CLIENTE.md`):  
`view_HCA_encomendas_abertas` e `sp_HCA_reabrir_expedicao_dossier` NOT NULL sugerem deploy base presente — **não** prova sozinho que `DEPLOY_CLIENTE_BI2_BO3.sql` correu na íntegra nem que os grants a `portal_app` foram aplicados.

---

### B.7 Permissões de `portal_app` (Fase 1) — explícitas vs efectivas

Distinguir dois níveis (não são equivalentes):

| Nível | O que mede | Limite |
| --- | --- | --- |
| **Explícitas (catálogo)** | Entradas em `sys.database_permissions` concedidas **directamente** ao principal `portal_app` | **Não** inclui grants herdados via **roles**, ownership chains, nem `DENY` efectivos via membership. **Não** é prova completa das permissões efectivas |
| **Efectivas** | O que o principal consegue fazer de facto (ex. `HAS_PERMS_BY_NAME` sob `EXECUTE AS USER`, ou teste DBA controlado) | Inclui efeito de roles (e tipicamente `DENY`); **não** substitui auditoria de segurança completa. Depende de impersonação / privilégios do operador |
| **Herdadas (roles)** | Permissões via `sys.database_role_members` + grants à role | B.7.1 **não** as lista como grantee `portal_app`; B.7.2 pode reflecti-las nos flags. Inventário de roles: **a confirmar pelo DBA** se B.7.1 vazio e B.7.2 = 1 |

#### B.7.1 Permissões explícitas (catálogo) — evidência parcial

| | |
| --- | --- |
| Nível | BD `LillianaSerodioPhc` |
| Quando | Preferencialmente **depois** de `096c`; também útil antes para baseline |
| Esperado após `096c` (com user + tabelas) | Linhas `GRANT` para `SELECT`/`INSERT`/`UPDATE` em `u_HcaPmPedido` e `SELECT`/`INSERT` em `u_HcaPmPedidoLin` (conforme script `096c`) |
| Interpretação | Presença das linhas **suporta** que o `GRANT` do `096c` correu; **ausência** pode ser “sem grant”, grant via role (não aparece aqui como grantee directo), ou metadados incompletos |
| Se user não existe | Não executar grants; esta consulta não se aplica |
| Metadados | Pode exigir privilégios elevados; resultado vazio ≠ prova definitiva de “sem permissão efectiva” |

```sql
USE [LillianaSerodioPhc];
GO

-- Só faz sentido se o database user existir (B.3).
-- Isto lista permissões EXPLÍCITAS ao user — NÃO prova sozinho as permissões EFECTIVAS.
SELECT
    OBJECT_SCHEMA_NAME(p.major_id) AS schema_name,
    OBJECT_NAME(p.major_id) AS object_name,
    p.permission_name,
    p.state_desc
FROM sys.database_permissions AS p
INNER JOIN sys.database_principals AS dp
    ON p.grantee_principal_id = dp.principal_id
WHERE dp.name = N'portal_app'
  AND p.class_desc = N'OBJECT_OR_COLUMN'
  AND OBJECT_NAME(p.major_id) IN (N'u_HcaPmPedido', N'u_HcaPmPedidoLin')
ORDER BY object_name, permission_name;
```

#### B.7.2 Permissões efectivas (verificação adicional)

| | |
| --- | --- |
| Quando | Após B.7.1 e existência das tabelas; obrigatório antes de declarar “grants Fase 1 OK” (A.5 gate 2 / E.7) |
| Esperado | Impersonação **bem-sucedida** e todos os flags = 1 para as acções previstas no `096c` |
| Se `EXECUTE AS` / impersonação falhar | **Não** interpretar como “portal_app sem permissões nas tabelas”. É falha de **capacidade de impersonar** (privilégio `IMPERSONATE`, user inexistente, etc.) — lacuna operacional; **pedir a DBA**. Não substituir por B.7.1 sozinho |
| Sessão | Usar **sessão SSMS descartável**. O `TRY/CATCH` tenta `REVERT` em erro, mas essa tentativa **não** é garantia absoluta de recuperação do contexto em todos os cenários. Se ocorrer **qualquer erro** ou houver **dúvida** sobre o contexto da sessão → **fechar a sessão** e abrir uma **nova** antes de continuar. **Não reutilizar** a sessão duvidosa |

```sql
-- Requer permissão IMPERSONATE no user portal_app.
-- Aproxima permissões EFECTIVAS; complementar a B.7.1.
-- TRY/CATCH tenta REVERT em erro; isto NÃO substitui fechar a sessão se houver dúvida (ver texto acima).
SET NOCOUNT ON;
BEGIN TRY
    EXECUTE AS USER = N'portal_app';
    SELECT
        HAS_PERMS_BY_NAME(N'dbo.u_HcaPmPedido', N'OBJECT', N'SELECT') AS cab_select,
        HAS_PERMS_BY_NAME(N'dbo.u_HcaPmPedido', N'OBJECT', N'INSERT') AS cab_insert,
        HAS_PERMS_BY_NAME(N'dbo.u_HcaPmPedido', N'OBJECT', N'UPDATE') AS cab_update,
        HAS_PERMS_BY_NAME(N'dbo.u_HcaPmPedidoLin', N'OBJECT', N'SELECT') AS lin_select,
        HAS_PERMS_BY_NAME(N'dbo.u_HcaPmPedidoLin', N'OBJECT', N'INSERT') AS lin_insert;
    REVERT;
END TRY
BEGIN CATCH
    -- Capturar a mensagem do erro que invocou este CATCH antes de qualquer REVERT aninhado.
    DECLARE @err nvarchar(4000) = ERROR_MESSAGE();

    -- Tentar repor o contexto de impersonação (melhor esforço; não garantia absoluta).
    BEGIN TRY
        REVERT;
    END TRY
    BEGIN CATCH
        -- Sem impersonação activa (ou REVERT já feito): ignorar.
    END CATCH;

    RAISERROR(
        N'B.7.2 falhou (impersonação ou verificação). NÃO concluir ausência de grants nas tabelas só por este erro. Detalhe: %s',
        16,
        1,
        @err
    );
    -- Impedir continuação do batch após o CATCH (RAISERROR sozinho não aborta o lote).
    RETURN;
END CATCH;
```

**Operacional:** após erro ou dúvida, fechar a janela SSMS descartável e abrir outra — mesmo que o `CATCH` tenha chamado `REVERT`. Falha neste bloco ≠ prova de ausência de permissões nas tabelas.

---

### B.8 Contagem de linhas Fase 1 (leitura; pós-criação)

| | |
| --- | --- |
| Nível | BD |
| Esperado após create sem testes de escrita | Contagens = 0 (ou valor conhecido prévio se reexecução) |
| Se linhas inesperadas | Investigar; **não** apagar automaticamente |

```sql
USE [LillianaSerodioPhc];
GO

IF OBJECT_ID(N'dbo.u_HcaPmPedido', N'U') IS NOT NULL
    SELECT N'u_HcaPmPedido' AS t, COUNT_BIG(*) AS n FROM dbo.u_HcaPmPedido;
IF OBJECT_ID(N'dbo.u_HcaPmPedidoLin', N'U') IS NOT NULL
    SELECT N'u_HcaPmPedidoLin' AS t, COUNT_BIG(*) AS n FROM dbo.u_HcaPmPedidoLin;
```

---

## C. Árvore de decisão do provisionamento

```
[A6–A7 IIS confirmado?]
        |
       NÃO ──► NO-GO scripts de identidade/grants/096* (só diagnósticos B.*)
        |
       SIM
        |
[B.2 login?]──não──► C.3
        |
       sim
        |
[B.3 user?]──não──► C.2
        |
       sim
        |
[IIS principal = portal_app JÁ confirmado no host?]
        |
       NÃO (outro principal OU só plano) ──► C.4
        |
       SIM (alinhamento concluído) ──► C.1 ──► (opcional grants em falta C.6) ──► C.5 se objectos parciais ──► 096*
```

### C.1 Login + user existem; identidade IIS já alinhada e confirmada

| | |
| --- | --- |
| Gate 1 (suite Fase 1) | Com A.5 gate 1 satisfeito: validar objectos (B.5–B.6) e, se OK, executar `096`→`096b`→`096c` (schema **e** grant) |
| Antes dos scripts | Flag `false` (A8); backup (A4); A6–A7 com principal **efectivo** no IIS **já alinhado** ao adoptado — **não** “plano a executar depois” |
| Gate 2 (validar provisionamento) | Após scripts: E.2 + B.7 (ver E.7). Correr os scripts **≠** gate 2. “Fase 1 pronta” **≠** autorização automática de smoke API |
| Gate 3 (testar API) | Só com “Fase 1 pronta” **e** o mesmo alinhamento IIS **já confirmado** (A.5 gate 3 / E.1). Plano pendente = **NO-GO** para testes com a identidade prevista |
| Grants | Se B.7.1/B.7.2 mostrarem grants Fase 1 em falta **após** tabelas → correr só `096c` (não reescrever script para outro user). B.7.1 sozinho não fecha a validação efectiva (gate 2) |

### C.2 Login existe na instância; falta user na BD

| | |
| --- | --- |
| Decisão | Criar **apenas** o database user mapeado ao login existente (equivalente à parte `CREATE USER` de `sql/000_criar_login_portal_app.sql`, com `USE [LillianaSerodioPhc]`) — **DBA**, após autorização |
| Não fazer | Recriar login com password nova sem necessidade; assumir password do login existente |
| Depois | Reexecutar grants que tenham saltado (`030`, mobile `091c`/`094`/`095` se objectos existirem, depois `096c` quando tabelas existirem) |
| Bloqueio IIS | Só útil à API se A6–A7 apontarem para este login |

### C.3 Login não existe na instância

| | |
| --- | --- |
| Decisão | Só criar login+user via processo de `sql/000_criar_login_portal_app.sql` **se** IT confirmar que a API **passará** a usar `portal_app` (ou já está configurada para o usar após criação) |
| Ajustes obrigatórios no script | Substituir `NOME_BD_PHC` por `LillianaSerodioPhc`; password forte **fora** do Git / deste doc |
| Não fazer | Criar login “por precaução” enquanto IIS usa outra identidade sem plano de cutover |

### C.4 A aplicação usa outra identidade (SQL user distinto ou Windows) — ou o alinhamento ainda é só um plano

| | |
| --- | --- |
| Decisão | **PARAR** testes da aplicação com a identidade prevista e **não** tratar `096c`→`portal_app` como suficiente para a API |
| Enquanto o cutover IIS não estiver **feito e confirmado** | **NO-GO** para smoke/app com `portal_app`; um plano documentado sem execução **não** desbloqueia A.5 “GO testes da aplicação” |
| Opções (escolha explícita IT/DBA; não automáticas) | (1) Concluir alinhamento IIS a `portal_app` após C.2/C.3 e **revalidar A6–A7**; (2) mapear o principal real para o mesmo modelo de grants em **todo** o conjunto de scripts do projecto (não apenas `096c`) |
| Proibido neste checklist | Grants a `sa`; editar só `096c` para outro nome sem decisão formal |

### C.5 Objectos já existem parcialmente

| | |
| --- | --- |
| Sintoma | Só cab **ou** só lin; ou cab/lin sem PK/FK/índices esperados (secção E) |
| Decisão | **PARAR** execução cega de `096`/`096b`. Comparar estrutura com scripts `096` / `096b` (secção E). Escalar DBA |
| Nota | Os scripts são idempotentes com `IF OBJECT_ID IS NULL` — **não** corrigem tabela já criada com definição errada |
| Lacuna | Não existe no repositório um script oficial de `DROP`/`ALTER` correctivo para `096*` |

### C.6 Grants saltados por ausência do utilizador

| | |
| --- | --- |
| Sintoma | Scripts de grant imprimem aviso `user portal_app inexistente — saltar GRANTs` (padrão em `030`, `091c`, `092b`, `093`, `094`, `095`, `096c`) |
| Decisão | Primeiro garantir C.1/C.2/C.3; **depois** reexecutar os grants na ordem D; **não** repetir creates desnecessários |
| Evidência histórica | `docs/fase-0b-preparacao-ambiente.md` regista provisionamento `portal_app` como pendente em UAT (doc histórico) — **não** prova o estado actual; usar B.* |

### C.7 Inconsistências / resultados inesperados

| Exemplos | Acção |
| --- | --- |
| `DB_NAME()` ≠ `LillianaSerodioPhc` | Parar |
| User `portal_app` com SID sem login | Parar — DBA |
| Consultas de metadados vazias por permissão (incl. B.4) | Repetir com conta DBA; **não** concluir “login/mapeamento inexistente” só com resultado vazio |
| Pack base incompleto (B.6) e Portal em uso | Investigar deploy; Fase 1 não substitui pack base |
| Qualquer erro não previsto a meio de script | Parar; ver secção F |

---

## D. Sequência oficial dos scripts

Fontes: `docs/SQL_APLICAR_CLIENTE.md`, cabeçalho de `sql/DEPLOY_CLIENTE_BI2_BO3.sql`, `docs/portal-mobile-deploy-uat.md`, scripts `096*`.

### D.1 Camadas (não misturar)

| Camada | Scripts / acção | Notas |
| --- | --- | --- |
| 0. Identidade SQL app | `sql/000_criar_login_portal_app.sql` | Login + user; ajustar BD/password; **fora** do ficheiro pack |
| 1. Deploy base Portal | `sql/DEPLOY_CLIENTE_BI2_BO3.sql` | Inclui verificação campos, vistas/SPs/tabelas Identity/previsão/picking, e **no fim** grants incl. `030_grant_portal_app.sql` |
| 1b. Grant base (se reexecução pontual) | `sql/030_grant_portal_app.sql` | Pré-requisito: user `portal_app` na BD |
| 2. Mobile (legado BO `ndos=67`) | Ver D.3 | **Fora** do pack `DEPLOY_CLIENTE_BI2_BO3.sql` |
| 3. Fase 1 pedidos internos | `096` → `096b` → `096c` | **Fora** do pack; só com pré-condições A/C |

**Não incluir** na sequência normal: `090_seed_clone_encomendas_teste.sql` (proibido em cliente/produção; `SQL_APLICAR_CLIENTE.md`).

**Não afirmar** neste checklist que o pack ou os scripts mobile já foram executados em `LillianaSerodioPhc` — validar com B.6.

### D.2 Ordem recomendada quando a identidade e o pack base estão OK

1. Diagnósticos B.* + GO em A.5 / C.1  
2. Se user em falta → C.2 ou C.3 (`000` conforme caso) — **DBA**  
3. Se grants base saltados e objectos base existem → reexecutar `030` (e restantes grants do pack se necessário; ver `SQL_APLICAR_CLIENTE.md`)  
4. Mobile (se objectos em falta e se o âmbito UAT incluir mobile legado): ordem em D.3  
5. **Fase 1:**  
   - `sql/096_create_u_HcaPmPedido.sql`  
   - `sql/096b_create_u_HcaPmPedidoLin.sql`  
   - `sql/096c_grant_u_HcaPmPedido.sql`  
6. Validação E.*  
7. Manter `PedidosInternosEnabled = false`

### D.3 Scripts mobile (fora do pack) — nomes reais no repositório

Ordem documentada em `docs/portal-mobile-deploy-uat.md`:

| Ordem | Ficheiro real |
| --- | --- |
| 1 | `sql/091_create_sp_HCA_criar_pedido_mobile.sql` *(não existe `sql/091.sql`)* |
| 2 | `sql/091c_grant_sp_HCA_criar_pedido_mobile.sql` |
| 3 | `sql/092_create_u_HcaClienteAuth.sql` + `sql/092b_grant_u_HcaClienteAuth.sql` |
| 4 | `sql/093_alter_sp_HCA_criar_pedido_mobile_cor.sql` |
| 5 | `sql/094_create_u_HcaPedidoMobileCancel.sql` (inclui GRANT se user existir) |
| 6 | `sql/095_create_sp_HCA_cancelar_pedido_mobile.sql` (inclui GRANT se user existir) |

Opcional de validação (não é deploy): `sql/091b_validate_sp_HCA_criar_pedido_mobile.sql`.

### D.4 Dependências Fase 1

| Script | Depende de |
| --- | --- |
| `096` | Nada de mobile; recomenda-se BD UAT correcta + autorização |
| `096b` | Tabela `u_HcaPmPedido` (`096`) |
| `096c` | `096` + `096b` **e** database user `portal_app` |

Se `096c` correr sem user: imprime aviso e **não** aplica grants (comportamento do script).

### D.5 Relação com `DEPLOY_CLIENTE_BI2_BO3.sql`

- Pré-requisito declarado no pack: correr `000_criar_login_portal_app.sql` **antes**.  
- O pack **não** inclui `091*`–`096*`.  
- Recuperação de falhas do pack legado / Msg 207: `docs/SQL_RECUPERAR_DEPLOY_CLIENTE.md`.  
- Reexecução do pack é descrita como idempotente (`CREATE OR ALTER`) — **avaliar impacto** com DBA antes de reexecutar em BD já em uso.

---

## E. Validação posterior

### E.1 Identidade

| Teste | Tipo | Critério de sucesso |
| --- | --- | --- |
| B.2 + B.3 + B.4 | Leitura | Login e user `portal_app` mapeados; login não disabled; ambiguidade de metadados resolvida por **DBA** |
| IIS A6–A7 | Config | Principal **efectivo** da API no host = `portal_app` (ou o principal formalmente adoptado). Cutover **já executado e confirmado** — plano futuro **não** cumpre o critério |

### E.2 Estrutura Fase 1 (leitura) — comparar com `096` e `096b`

Pré-requisito: `DB_NAME() = N'LillianaSerodioPhc'` (B.1) e `OBJECT_ID` das duas tabelas NOT NULL.

As consultas **listam** metadados; a validação só fica **concluída** após **comparação manual** (ou checklist DBA) com as tabelas de expectativa abaixo (scripts `sql/096_create_u_HcaPmPedido.sql` e `sql/096b_create_u_HcaPmPedidoLin.sql`). Qualquer desvio → cenário C.5 / DBA; os scripts idempotentes **não** corrigem definição já criada.

Distinguir: objecto **ausente** (0 linhas / `OBJECT_ID` NULL) ≠ objecto **presente mas incorrecto** (desactivado, `is_not_trusted`, colunas/tipos diferentes, índice filtrado, etc.).

#### E.2.1 Colunas — `u_HcaPmPedido` (script `096`)

```sql
USE [LillianaSerodioPhc];
GO

SELECT
    c.column_id,
    c.name AS column_name,
    ty.name AS type_name,
    c.max_length,
    c.precision,
    c.scale,
    c.is_nullable,
    c.is_identity
FROM sys.columns AS c
INNER JOIN sys.types AS ty
    ON c.user_type_id = ty.user_type_id
WHERE c.object_id = OBJECT_ID(N'dbo.u_HcaPmPedido', N'U')
ORDER BY c.column_id;

-- Seed/increment IDENTITY — a consulta de colunas NÃO valida (1,1); usar:
SELECT
    COL_NAME(object_id, column_id) AS column_name,
    seed_value,
    increment_value,
    last_value,
    is_not_for_replication
FROM sys.identity_columns
WHERE object_id = OBJECT_ID(N'dbo.u_HcaPmPedido', N'U');
```

| Coluna | Tipo esperado | max_length / precision,scale | Nullable | Identity |
| --- | --- | --- | --- | --- |
| `PedidoId` | `bigint` | — (ignorar `max_length` do catálogo) | NOT NULL | `is_identity=1`; seed/increment **(1,1)** via `sys.identity_columns` |
| `NumeroInterno` | `varchar` | 24 | NULL | não |
| `ClNo` | `numeric` | 10,0 | NOT NULL | não |
| `ClEstab` | `numeric` | 3,0 | NOT NULL | não |
| `EstadoInterno` | `varchar` | 32 | NOT NULL | não |
| `DataSubmissao` | `datetime2` | **scale = 0** (`precision` do catálogo tipicamente ≠ 0 — não exigir precision=0) | NOT NULL | não |
| `DataAlteracao` | `datetime2` | **scale = 0** (idem) | NOT NULL | não |
| `Etotaldeb` | `numeric` | 19,6 | NOT NULL | não |
| `SubmissaoIdempotencyKey` | `varchar` | 64 | NOT NULL | não |
| `SubmissaoPayloadHash` | `char` | 64 | NOT NULL | não |
| `CriadoPor` | `varchar` | 16 | NOT NULL | não |
| `Bostamp` | `varchar` | 25 | NULL | não |
| `Obrano` | `numeric` | 10,0 | NULL | não |
| `Boano` | `numeric` | 4,0 | NULL | não |
| `Ndos` | `numeric` | 5,0 | NULL | não |

Esperado: **exactamente 15** colunas com estes nomes (nem mais nem menos).  
Nota: em `sys.columns`, `varchar`/`char` reportam `max_length` em bytes (1 byte/char para estes tipos nas definições do script).

#### E.2.2 Colunas — `u_HcaPmPedidoLin` (script `096b`)

```sql
SELECT
    c.column_id,
    c.name AS column_name,
    ty.name AS type_name,
    c.max_length,
    c.precision,
    c.scale,
    c.is_nullable,
    c.is_identity
FROM sys.columns AS c
INNER JOIN sys.types AS ty
    ON c.user_type_id = ty.user_type_id
WHERE c.object_id = OBJECT_ID(N'dbo.u_HcaPmPedidoLin', N'U')
ORDER BY c.column_id;

SELECT
    COL_NAME(object_id, column_id) AS column_name,
    seed_value,
    increment_value,
    last_value,
    is_not_for_replication
FROM sys.identity_columns
WHERE object_id = OBJECT_ID(N'dbo.u_HcaPmPedidoLin', N'U');
```

| Coluna | Tipo esperado | max_length / precision,scale | Nullable | Identity |
| --- | --- | --- | --- | --- |
| `LinhaId` | `bigint` | — | NOT NULL | `is_identity=1`; seed/increment **(1,1)** via `sys.identity_columns` |
| `PedidoId` | `bigint` | — | NOT NULL | não |
| `LinhaOrd` | `int` | — | NOT NULL | não |
| `Ref` | `varchar` | 18 | NOT NULL | não |
| `Design` | `varchar` | 60 | NOT NULL | não |
| `Cor` | `varchar` | 100 | NOT NULL | não |
| `Qtt` | `numeric` | 16,4 | NOT NULL | não |
| `PrecoUnitario` | `numeric` | 19,6 | NOT NULL | não |
| `TotalLinha` | `numeric` | 19,6 | NOT NULL | não |

Esperado: **exactamente 9** colunas com estes nomes.

#### E.2.3 Defaults (DF)

```sql
SELECT
    OBJECT_NAME(dc.parent_object_id) AS table_name,
    dc.name AS constraint_name,
    COL_NAME(dc.parent_object_id, dc.parent_column_id) AS column_name,
    dc.definition
FROM sys.default_constraints AS dc
WHERE dc.parent_object_id IN (
    OBJECT_ID(N'dbo.u_HcaPmPedido', N'U'),
    OBJECT_ID(N'dbo.u_HcaPmPedidoLin', N'U')
)
ORDER BY table_name, constraint_name;
```

| Constraint | Tabela | Coluna | Definição esperada (script) |
| --- | --- | --- | --- |
| `DF_u_HcaPmPedido_Estado` | cab | `EstadoInterno` | `N'recebido'` |
| `DF_u_HcaPmPedido_Sub` | cab | `DataSubmissao` | `SYSUTCDATETIME()` |
| `DF_u_HcaPmPedido_Alt` | cab | `DataAlteracao` | `SYSUTCDATETIME()` |
| `DF_u_HcaPmPedido_Usr` | cab | `CriadoPor` | `N'MOB'` |
| `DF_u_HcaPmPedidoLin_Cor` | lin | `Cor` | `N''` |

Comparar `definition` **semanticamente**: o catálogo costuma devolver parênteses extra (ex. `(N'recebido')`, `(sysutcdatetime())`). Ausência de qualquer DF esperado = divergência. Exactamente estes **5** defaults esperados (extras → DBA).

#### E.2.4 PK, UNIQUE, CHECK

**Método de validação:** as consultas abaixo **listam** o que existe; a aceitação exige **cruzar linha a linha** com a tabela de expectativa. Não basta “a query correu sem erro” nem “apareceram algumas constraints”.

Para **cada** PK, UQ e CHECK da tabela de expectativa, confirmar que:

1. **Existe** (nome presente no resultado);  
2. **Nome e definição** coincidem (colunas / `key_ordinal` / expressão CHECK);  
3. Está **activa** (`is_disabled = 0` no CHECK; índice de suporte `supporting_index_disabled = 0` na PK/UQ);  
4. CHECK tem **`is_not_trusted = 0`** quando aplicável;  
5. PK/UQ têm **índice de suporte activo**.

**Ausência** de qualquer constraint esperada = **divergência** → **PARAR** e análise pelo DBA (C.5). Não inventar constraints nem alterar scripts oficiais nesta checklist.

```sql
SELECT
    OBJECT_NAME(kc.parent_object_id) AS table_name,
    kc.name AS constraint_name,
    kc.type_desc,
    COL_NAME(ic.object_id, ic.column_id) AS column_name,
    ic.key_ordinal,
    i.is_disabled AS supporting_index_disabled,
    i.type_desc AS supporting_index_type_desc
FROM sys.key_constraints AS kc
INNER JOIN sys.index_columns AS ic
    ON ic.object_id = kc.parent_object_id
   AND ic.index_id = kc.unique_index_id
INNER JOIN sys.indexes AS i
    ON i.object_id = kc.parent_object_id
   AND i.index_id = kc.unique_index_id
WHERE kc.parent_object_id IN (
    OBJECT_ID(N'dbo.u_HcaPmPedido', N'U'),
    OBJECT_ID(N'dbo.u_HcaPmPedidoLin', N'U')
)
ORDER BY table_name, constraint_name, ic.key_ordinal;

SELECT
    OBJECT_NAME(cc.parent_object_id) AS table_name,
    cc.name AS constraint_name,
    cc.definition,
    cc.is_disabled,
    cc.is_not_trusted
FROM sys.check_constraints AS cc
WHERE cc.parent_object_id = OBJECT_ID(N'dbo.u_HcaPmPedidoLin', N'U')
ORDER BY constraint_name;
```

| Constraint | Tabela | Tipo | Colunas / expressão | Estado esperado |
| --- | --- | --- | --- | --- |
| `PK_u_HcaPmPedido` | cab | PRIMARY KEY | `PedidoId` | índice suporte `is_disabled = 0`; tipo índice tipicamente **CLUSTERED** (default do `PRIMARY KEY` no script, sem `NONCLUSTERED`) |
| `UQ_u_HcaPmPedido_NumeroInterno` | cab | UNIQUE | `NumeroInterno` | índice suporte `is_disabled = 0`; tipicamente **NONCLUSTERED** |
| `UQ_u_HcaPmPedido_IdemKey` | cab | UNIQUE | `SubmissaoIdempotencyKey` | índice suporte `is_disabled = 0`; tipicamente **NONCLUSTERED** |
| `PK_u_HcaPmPedidoLin` | lin | PRIMARY KEY | `LinhaId` | índice suporte `is_disabled = 0`; tipicamente **CLUSTERED** |
| `UQ_u_HcaPmPedidoLin_Ord` | lin | UNIQUE | `PedidoId`, `LinhaOrd` | índice suporte `is_disabled = 0`; tipicamente **NONCLUSTERED** |
| `CK_u_HcaPmPedidoLin_Ord` | lin | CHECK | `LinhaOrd > 0` | `is_disabled = 0`, `is_not_trusted = 0` |
| `CK_u_HcaPmPedidoLin_Qtt` | lin | CHECK | `Qtt > 0` | `is_disabled = 0`, `is_not_trusted = 0` |

Nota: `is_not_trusted` aplica-se a CHECK (e FK em E.2.6). PK/UQ não expõem `is_not_trusted` no catálogo da mesma forma — validar via índice suporte não desactivado. A consulta **não** marca sozinha “OK”: cruzar com esta tabela; **ausência** de qualquer linha esperada = divergência. Constraints **extra** → DBA. Se o tipo CLUSTERED/NONCLUSTERED diferir do tipicamente esperado → **a confirmar pelo DBA** (pode haver clustered pré-existente noutra coluna). `definition` de CHECK no catálogo pode diferir na forma (ex. `([LinhaOrd]>(0))`) — comparar **semanticamente** com o script.

#### E.2.5 Índices não-constraint

Os scripts `096` / `096b` definem apenas índices **não filtrados**, **sem** colunas `INCLUDE`, **não unique**, tipo rowstore não-clustered típico.

**Método de validação:** as consultas **não falham** se um índice esperado estiver ausente — devolvem simplesmente menos linhas. Por isso, a **ausência** de `IX_u_HcaPmPedido_Cl_Data` ou `IX_u_HcaPmPedidoLin_Pedido` (0 linhas para esse nome) é **divergência**, mesmo sem erro SQL.

Confirmar **presença** de ambos os índices e, para cada um, as propriedades e colunas da tabela de expectativa. Se algum índice estiver **ausente**, **desactivado**, **filtrado**, tiver colunas `INCLUDE` inesperadas (`is_included_column = 1`) ou diferir das definições documentadas → **PARAR** e escalar DBA (C.5). **Não** criar índices automaticamente nem propor `CREATE INDEX` correctivo nesta checklist.

```sql
-- Propriedades do índice
SELECT
    OBJECT_NAME(i.object_id) AS table_name,
    i.name AS index_name,
    i.is_unique,
    i.type_desc,
    i.has_filter,
    i.filter_definition,
    i.is_disabled,
    i.is_hypothetical,
    i.ignore_dup_key,
    i.fill_factor,
    i.is_padded
FROM sys.indexes AS i
WHERE i.object_id IN (
    OBJECT_ID(N'dbo.u_HcaPmPedido', N'U'),
    OBJECT_ID(N'dbo.u_HcaPmPedidoLin', N'U')
)
  AND i.name IN (N'IX_u_HcaPmPedido_Cl_Data', N'IX_u_HcaPmPedidoLin_Pedido');

-- Colunas chave e incluídas
SELECT
    OBJECT_NAME(i.object_id) AS table_name,
    i.name AS index_name,
    COL_NAME(ic.object_id, ic.column_id) AS column_name,
    ic.key_ordinal,
    ic.is_descending_key,
    ic.is_included_column,
    ic.partition_ordinal
FROM sys.indexes AS i
INNER JOIN sys.index_columns AS ic
    ON ic.object_id = i.object_id
   AND ic.index_id = i.index_id
WHERE i.object_id IN (
    OBJECT_ID(N'dbo.u_HcaPmPedido', N'U'),
    OBJECT_ID(N'dbo.u_HcaPmPedidoLin', N'U')
)
  AND i.is_hypothetical = 0
  AND i.name IN (N'IX_u_HcaPmPedido_Cl_Data', N'IX_u_HcaPmPedidoLin_Pedido')
ORDER BY table_name, index_name, ic.is_included_column, ic.key_ordinal, ic.index_column_id;
```

| Índice | Tabela | Colunas chave (ordem) | `is_included_column` | `has_filter` / `filter_definition` | Outros |
| --- | --- | --- | --- | --- | --- |
| `IX_u_HcaPmPedido_Cl_Data` | cab | `ClNo`, `ClEstab`, `DataSubmissao` (`is_descending_key=1` só nesta) | todas as linhas = 0 (sem INCLUDE) | `has_filter = 0`, `filter_definition` NULL | `is_unique = 0`, `is_disabled = 0`, `type_desc` tipicamente `NONCLUSTERED` |
| `IX_u_HcaPmPedidoLin_Pedido` | lin | `PedidoId`, `LinhaOrd` (ASC) | todas = 0 | `has_filter = 0`, `filter_definition` NULL | `is_unique = 0`, `is_disabled = 0`, `type_desc` tipicamente `NONCLUSTERED` |

Checklist rápido: (1) **dois nomes presentes** (0 linhas para um nome = ausente = falha); (2) propriedades OK; (3) colunas chave na ordem certa; (4) zero INCLUDE; (5) sem filtro; (6) não disabled.  
`fill_factor` / `is_padded` / `ignore_dup_key`: o script **não** os define — não tratar desvio do default do servidor como falha automática sem política DBA.

#### E.2.6 Foreign key

```sql
SELECT
    fk.name AS fk_name,
    OBJECT_NAME(fk.parent_object_id) AS child_table,
    COL_NAME(fkc.parent_object_id, fkc.parent_column_id) AS child_column,
    OBJECT_NAME(fk.referenced_object_id) AS parent_table,
    COL_NAME(fkc.referenced_object_id, fkc.referenced_column_id) AS parent_column,
    fk.delete_referential_action_desc,
    fk.update_referential_action_desc,
    fk.is_disabled,
    fk.is_not_trusted
FROM sys.foreign_keys AS fk
INNER JOIN sys.foreign_key_columns AS fkc
    ON fkc.constraint_object_id = fk.object_id
WHERE fk.parent_object_id = OBJECT_ID(N'dbo.u_HcaPmPedidoLin', N'U');
```

| FK | Filho | Pai | DELETE | Estado esperado |
| --- | --- | --- | --- | --- |
| `FK_u_HcaPmPedidoLin_Cab` | `u_HcaPmPedidoLin.PedidoId` | `u_HcaPmPedido.PedidoId` | `NO_ACTION` (script: **sem** `ON DELETE CASCADE`) | `is_disabled = 0`, `is_not_trusted = 0` |

**Critério E.2 OK:** todas as colunas, nulabilidade, tipos/comprimentos, DF/PK/UQ/CK **esperados** (presentes, activos e trusted quando aplicável), índices **esperados** (presentes; chave, INCLUDE, filtro, disabled) e FK coincidem com as tabelas acima. Ausência de constraint ou índice esperado = falha. Caso contrário → **PARAR** e escalar DBA (C.5).

### E.3 Grants Fase 1

- **B.7.1** (explícitas): linhas de `GRANT` alinhadas com `096c` (`SELECT, INSERT, UPDATE` cab; `SELECT, INSERT` lin) — evidência **parcial**.  
- **B.7.2** (efectivas): impersonação OK **e** flags `HAS_PERMS_BY_NAME` = 1 (ou validação DBA equivalente). Falha de impersonação ≠ ausência de grants.  
- Declarar “grants Fase 1 OK” só com **B.7.2** bem-sucedido (ou DBA) além de B.7.1 quando este estiver disponível.

### E.4 Aplicação

| Teste | Tipo | Critério |
| --- | --- | --- |
| `GET /health` | Leitura / liveness | Resposta OK (`deployment-architecture.md`); **não** prova identidade SQL |
| Smoke login staff/cliente | Funcional existente | Só se A6–A7 confirmarem identidade alinhada **já no host**; sem erros novos de permissão SQL óbvios |
| Submeter pedido interno | Funcional **com flag true** | **Fora de âmbito** enquanto flag = `false` — não activar nesta checklist |
| Contagens B.8 | Leitura | Sem linhas criadas por esta operação de provisionamento |

### E.5 Dados PHC

| Teste | Tipo | Critério |
| --- | --- | --- |
| Scripts `096*` | — | Apenas `CREATE TABLE` / `GRANT` condicionais; **não** devem modificar `BO`/`BI` |
| Se houver dúvida de alteração PHC | Leitura / DBA | Investigar; **não** “corrigir” com deletes manuais sem procedimento |

### E.6 Feature flag

| Teste | Critério |
| --- | --- |
| Config efectiva IIS / appsettings no host | `PedidosInternosEnabled` = `false` |

### E.7 Critério final — “schema criado” vs “Fase 1 pronta” vs “API pronta”

Não misturar estes estados (espelham A.5 gates 1–3 e C.1):

| Estado | Gate A.5 | O que significa | Condições mínimas |
| --- | --- | --- | --- |
| **Autorização para suite Fase 1** | Gate 1 | Pode executar `096`/`096b`/`096c` | Pré-condições A + user `portal_app` + A6–A7 alinhamento IIS **já concluído** (E.1). Plano ≠ execução |
| **Schema Fase 1 criado** | Resultado parcial do gate 2 | Objectos existem e estrutura OK | B.5 NOT NULL; **E.2 completo OK** (incl. todas as constraints/índices **esperados** presentes; comparação manual feita). **Ainda não** implica grants nem API |
| **Fase 1 pronta (UAT schema + permissões)** | Gate 2 completo | Provisionamento SQL validado | Schema OK **+** B.2/B.3/B.4 (DBA se ambíguo) **+** B.7.1 e **B.7.2** (ou DBA) OK **+** flag `false`. Declaração de provisionamento — **não** autoriza sozinha smoke API |
| **API pronta para usar o schema** | Gate 3 | Autorização para testar a API com a identidade efectiva do IIS | “Fase 1 pronta” **e** A6–A7 alinhamento **já confirmado** no host (mesmo critério E.1); smoke sem erro de permissão óbvio. **Plano pendente ≠ API pronta**. `PedidosInternosEnabled` permanece `false` nesta checklist |

**Regra:** só declarar a Fase 1 **pronta** quando **identidade**, **estrutura completa (E.2)** e **permissões (E.3 / B.7)** estiverem validadas. “Correram os scripts 096*” ou “OBJECT_ID já não é NULL” **não** bastam.

**Estado nesta auditoria documental (sem execução UAT):** nenhum dos gates 1–3 está concluído.

---

## F. Recuperação e interrupção

### F.1 Critérios para interromper de imediato

- Servidor ou BD incorrectos (B.1).  
- Falta de autorização ou de backup confirmado.  
- Identidade IIS desconhecida **ou** alinhamento apenas planeado (A6–A7 / A.5).  
- Erro inesperado a meio de um script.  
- Estrutura parcial / SID órfão (C.5 / C.7).  
- Tentativa de “atalho” (grants a `sa`, editar só `096c` para outro principal) — **rejeitar**.

### F.2 Procedimento oficial de recuperação (pack base)

Seguir **`docs/SQL_RECUPERAR_DEPLOY_CLIENTE.md`** para erros do tipo colunas BI/BO vs BI2/BO3, ausência de `portal_app` no momento do grant, BOM, cascata de SPs em falta:

1. Backup  
2. `000_verificar_campos_bi2_bo3.sql`  
3. `000_criar_login_portal_app.sql`  
4. `DEPLOY_CLIENTE_BI2_BO3.sql` (não o pack “COMPLETO”)  
5. Confirmar `OBJECT_ID` de vista/SP indicados nesse doc  

### F.3 Lacunas (não inventar rollback)

| Situação | Estado no repositório |
| --- | --- |
| Desfazer `CREATE TABLE` `096` / `096b` | **Sem** script oficial de DROP/rollback — **não** eliminar tabelas automaticamente |
| Reverter `GRANT` `096c` | **Sem** script oficial de `REVOKE` — não revogar em massa sem DBA |
| Alterar/remover login `portal_app` | **Fora** deste checklist — risco para outras apps; só IT/DBA com procedimento próprio |
| Restaurar BD a partir do backup | Procedimento **IT** (local/data do backup) — não documentado passo-a-passo neste repo para `HCA-SQL` |

Qualquer recuperação destrutiva exige autorização explícita e plano DBA — **não** fazer “limpeza” improvisada.

---

## G. Separação de responsabilidades

| Passo | IT / IIS | DBA / admin SQL | Operador app autorizado | Validação funcional (após GO feature) |
| --- | --- | --- | --- | --- |
| Confirmar UAT + autorização | | | ✅ | |
| Backup / restauro | ✅ | ✅ | | |
| Ler User Id connection string (sem password) | ✅ | | | |
| Consultas B.* | | ✅ | (se tiver acesso leitura) | |
| `000` criar login/user | | ✅ | | |
| Pack / `030` / mobile SQL | | ✅ | | |
| `096` / `096b` / `096c` | | ✅ | | |
| Confirmar flag `false` no host | ✅ | | ✅ | |
| Smoke `/health` e login | | | ✅ | |
| Activar `PedidosInternosEnabled` + testes de submissão interna | | | ✅ (só com autorização futura) | ✅ |
| Cutover identidade IIS → `portal_app` | ✅ | ✅ (validar permissões) | | |

---

## H. Folha de registo (preencher em UAT)

| Campo | Valor |
| --- | --- |
| Data / hora | |
| Operador | |
| Autorização (ref.) | |
| `@@SERVERNAME` / `DB_NAME()` | |
| Login `portal_app` (sim/não / disabled) | |
| User BD (sim/não) | |
| IIS AuthMode / Principal (sem segredos) | |
| `PedidosInternosEnabled` efectivo | |
| B.6 objectos base (ok/falha) | |
| B.5 antes `096*` | |
| Scripts executados (lista) | |
| B.5 / E.2 / B.7 depois | |
| Incidentes / paragens | |
| Decisão final | Schema criado / Fase 1 pronta / API pronta para usar o schema / NO-GO (ver E.7) |

---

## Referências rápidas de caminhos

| Recurso | Caminho |
| --- | --- |
| Criar login/user | `sql/000_criar_login_portal_app.sql` |
| Pack base | `sql/DEPLOY_CLIENTE_BI2_BO3.sql` |
| Grant base | `sql/030_grant_portal_app.sql` |
| Mobile deploy UAT | `docs/portal-mobile-deploy-uat.md` |
| Ordem SQL cliente | `docs/SQL_APLICAR_CLIENTE.md` |
| Recuperação pack | `docs/SQL_RECUPERAR_DEPLOY_CLIENTE.md` |
| IIS / segredos fora do Git | `docs/deployment-architecture.md` |
| Permissões (histórico 0B) | `docs/fase-0b-permissoes-sql-app.md` |
| Fase 1 cab | `sql/096_create_u_HcaPmPedido.sql` |
| Fase 1 lin | `sql/096b_create_u_HcaPmPedidoLin.sql` |
| Fase 1 grant | `sql/096c_grant_u_HcaPmPedido.sql` |
| Recolha IT/DBA (pré-execução) | `docs/uat-recolha-it-dba-pedidos-internos-fase1.md` |

---

*Fim do checklist. Qualquer desvio deve ser registado na secção H e escalado antes de continuar.*
