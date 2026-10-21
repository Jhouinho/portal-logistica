-- =============================================================================
-- Liliana & Seródio — Pré-check READ-ONLY antes do script 100
-- Script: 103_precheck_sp_mobile_edebito_readonly.sql
--
-- Objetivo: avaliar se é seguro executar
--   sql/100_alter_sp_HCA_criar_pedido_mobile_edebito_opcional.sql
-- (DROP/recriação de dbo.HCA_PedidoMobileLinhaType + dbo.sp_HCA_criar_pedido_mobile)
--
-- READ-ONLY: SELECT, metadados (sys.*/dm_*), OBJECT_ID/TYPE_ID/COL_LENGTH,
-- PRINT, SET NOCOUNT ON.
-- PROIBIDO: CREATE/ALTER/DROP/TRUNCATE; GRANT/REVOKE/DENY;
-- INSERT/UPDATE/DELETE/MERGE; EXEC/EXECUTE de SPs de negócio.
--
-- Alinhado com verificações de:
--   102 (A1/A5/A7/A8), 091c / 093 / 100 (GRANT EXECUTE → portal_app).
-- Não substitui revisão humana nem janela de manutenção.
-- =============================================================================

SET NOCOUNT ON;
GO

PRINT N'=== 103 — Pré-check TYPE/SP mobile (antes do SQL 100) ===';
PRINT N'Só leitura. Não executa sp_HCA_criar_pedido_mobile.';
PRINT N'Esperado ANTES do 100 (pós-093): TVP com linha_ord, ref, qtt, cor — SEM edebito.';
PRINT N'Após 100: mesmas colunas + edebito numeric(19,6) NULL.';
GO

/*==============================================================================
  P1. Existência de objectos e principal portal_app
==============================================================================*/
PRINT N'=== P1. Existência TYPE / SP / portal_app ===';

SELECT
    CASE WHEN TYPE_ID(N'dbo.HCA_PedidoMobileLinhaType') IS NOT NULL
         THEN N'SIM' ELSE N'NÃO' END AS type_existe,
    CASE WHEN OBJECT_ID(N'dbo.sp_HCA_criar_pedido_mobile', N'P') IS NOT NULL
         THEN N'SIM' ELSE N'NÃO' END AS sp_existe,
    CASE WHEN EXISTS (
             SELECT 1 FROM sys.database_principals WHERE name = N'portal_app'
         ) THEN N'SIM' ELSE N'NÃO' END AS portal_app_existe;

PRINT N'Interpretação P1:';
PRINT N'  - TYPE ou SP ausentes: investigar baseline 091/093 antes do 100.';
PRINT N'  - portal_app ausente: o 100 salta GRANTs (PRINT aviso); app pode ficar sem EXECUTE.';
PRINT N'Impedimento: TYPE/SP em falta sem plano de recriar baseline.';
GO

/*==============================================================================
  P2. Estrutura atual do TYPE (ordem das colunas)
  Reutiliza o padrão 102 A5.
==============================================================================*/
PRINT N'=== P2. Colunas do TYPE HCA_PedidoMobileLinhaType (ordem column_id) ===';

IF TYPE_ID(N'dbo.HCA_PedidoMobileLinhaType') IS NULL
    PRINT N'TYPE inexistente — saltar P2.';
ELSE
BEGIN
    SELECT
        c.column_id,
        c.name AS coluna,
        ty.name AS tipo,
        c.max_length,
        c.precision,
        c.scale,
        c.is_nullable,
        OBJECT_DEFINITION(c.default_object_id) AS default_definition
    FROM sys.table_types tt
    JOIN sys.columns c ON c.object_id = tt.type_table_object_id
    JOIN sys.types ty ON c.user_type_id = ty.user_type_id
    WHERE tt.schema_id = SCHEMA_ID(N'dbo')
      AND tt.name = N'HCA_PedidoMobileLinhaType'
    ORDER BY c.column_id;

    SELECT
        CASE
            WHEN EXISTS (
                SELECT 1
                FROM sys.table_types tt
                JOIN sys.columns c ON c.object_id = tt.type_table_object_id
                WHERE tt.schema_id = SCHEMA_ID(N'dbo')
                  AND tt.name = N'HCA_PedidoMobileLinhaType'
                  AND c.name = N'edebito'
            ) THEN N'JA_TEM_EDEBITO — confirmar se 100 já foi aplicado; reexecutar 100 é DROP+CREATE de novo'
            WHEN EXISTS (
                SELECT 1
                FROM sys.table_types tt
                JOIN sys.columns c ON c.object_id = tt.type_table_object_id
                WHERE tt.schema_id = SCHEMA_ID(N'dbo')
                  AND tt.name = N'HCA_PedidoMobileLinhaType'
                  AND c.name = N'cor'
            ) THEN N'POS_093_SEM_EDEBITO — estado esperado antes do 100'
            ELSE N'SEM_COR — possível TYPE só 091; aplicar/confirmar 093 antes do 100'
        END AS diagnostico_estrutura_tvp;
END

PRINT N'Interpretação P2:';
PRINT N'  - Ordem esperada pós-093: 1 linha_ord, 2 ref, 3 qtt, 4 cor.';
PRINT N'  - 100 acrescenta 5 edebito NULL; não deve haver outras colunas inesperadas.';
PRINT N'Investigar: falta cor; colunas extra; edebito já presente (100 já corrido?).';
PRINT N'Impedimento: TYPE sem cor se o pré-requisito 093 não estiver aplicado.';
GO

/*==============================================================================
  P3. Dependências catalogadas do TYPE
==============================================================================*/
PRINT N'=== P3a. Referenciadores do TYPE (dm_sql_referencing_entities) ===';

IF TYPE_ID(N'dbo.HCA_PedidoMobileLinhaType') IS NULL
    PRINT N'TYPE inexistente — saltar P3a.';
ELSE
BEGIN
    SELECT
        referencing_schema_name,
        referencing_entity_name,
        referencing_id,
        referencing_class_desc,
        is_caller_dependent
    FROM sys.dm_sql_referencing_entities(
        N'dbo.HCA_PedidoMobileLinhaType',
        N'TYPE'
    )
    ORDER BY referencing_schema_name, referencing_entity_name;

    SELECT COUNT(*) AS qtd_referenciadores_type
    FROM sys.dm_sql_referencing_entities(
        N'dbo.HCA_PedidoMobileLinhaType',
        N'TYPE'
    );
END

PRINT N'=== P3b. sql_expression_dependencies → TYPE (quando disponível) ===';

IF TYPE_ID(N'dbo.HCA_PedidoMobileLinhaType') IS NULL
    PRINT N'TYPE inexistente — saltar P3b.';
ELSE
    SELECT
        OBJECT_SCHEMA_NAME(d.referencing_id) AS referencing_schema,
        OBJECT_NAME(d.referencing_id) AS referencing_entity,
        o.type_desc AS referencing_type,
        d.referenced_entity_name,
        d.referenced_class_desc
    FROM sys.sql_expression_dependencies d
    LEFT JOIN sys.objects o ON o.object_id = d.referencing_id
    WHERE d.referenced_entity_name = N'HCA_PedidoMobileLinhaType'
    ORDER BY referencing_schema, referencing_entity;

PRINT N'Interpretação P3:';
PRINT N'  - Esperado: apenas sp_HCA_criar_pedido_mobile (o 100 faz DROP da SP antes do TYPE).';
PRINT N'  - Qualquer OUTRO objeto (outra SP, função, trigger, etc.): IMPEDIMENTO até analisar.';
PRINT N'Limitação: DMVs não listam clientes .NET, jobs externos, nem SQL dinâmico ad-hoc.';
GO

/*==============================================================================
  P4. Dependências catalogadas da SP
==============================================================================*/
PRINT N'=== P4a. Quem referencia a SP ===';

IF OBJECT_ID(N'dbo.sp_HCA_criar_pedido_mobile', N'P') IS NULL
    PRINT N'SP inexistente — saltar P4a.';
ELSE
    SELECT
        referencing_schema_name,
        referencing_entity_name,
        referencing_class_desc,
        is_caller_dependent
    FROM sys.dm_sql_referencing_entities(
        N'dbo.sp_HCA_criar_pedido_mobile',
        N'OBJECT'
    )
    ORDER BY referencing_schema_name, referencing_entity_name;

PRINT N'=== P4b. O que a SP referencia (amostra de dependências) ===';

IF OBJECT_ID(N'dbo.sp_HCA_criar_pedido_mobile', N'P') IS NULL
    PRINT N'SP inexistente — saltar P4b.';
ELSE
    SELECT
        referenced_schema_name,
        referenced_entity_name,
        referenced_class_desc,
        is_caller_dependent,
        is_ambiguous
    FROM sys.dm_sql_referenced_entities(
        N'dbo.sp_HCA_criar_pedido_mobile',
        N'OBJECT'
    )
    ORDER BY referenced_class_desc, referenced_schema_name, referenced_entity_name;

PRINT N'Interpretação P4:';
PRINT N'  - P4a com outras SPs/jobs a chamar esta SP: coordenar janela (não bloqueia DROP por si).';
PRINT N'  - P4b: contexto (bo/bi/st/cl/idem); falhas aqui são informativas, não impedem o 100.';
PRINT N'Limitação: chamadas só via app/.NET não aparecem nestas DMVs.';
GO

/*==============================================================================
  P5. Permissões explícitas TYPE + SP (GRANT e DENY)
  Padrão semelhante ao 102 A8, alargado a todos os grantees.
==============================================================================*/
PRINT N'=== P5a. Permissões na SP (class = 1 OBJECT) ===';

IF OBJECT_ID(N'dbo.sp_HCA_criar_pedido_mobile', N'P') IS NULL
    PRINT N'SP inexistente — saltar P5a.';
ELSE
    SELECT
        dp.name AS grantee,
        dp.type_desc AS grantee_type,
        perm.permission_name,
        perm.state_desc,  -- GRANT / DENY / GRANT_WITH_GRANT_OPTION
        OBJECT_SCHEMA_NAME(o.object_id) + N'.' + o.name AS objeto
    FROM sys.database_permissions perm
    JOIN sys.database_principals dp ON perm.grantee_principal_id = dp.principal_id
    JOIN sys.objects o ON perm.major_id = o.object_id AND perm.class = 1
    WHERE o.object_id = OBJECT_ID(N'dbo.sp_HCA_criar_pedido_mobile')
    ORDER BY dp.name, perm.permission_name, perm.state_desc;

PRINT N'=== P5b. Permissões no TYPE (class = 6 TYPE) ===';

IF TYPE_ID(N'dbo.HCA_PedidoMobileLinhaType') IS NULL
    PRINT N'TYPE inexistente — saltar P5b.';
ELSE
    SELECT
        dp.name AS grantee,
        dp.type_desc AS grantee_type,
        perm.permission_name,
        perm.state_desc,
        SCHEMA_NAME(tt.schema_id) + N'.' + tt.name AS tipo_tvp
    FROM sys.database_permissions perm
    JOIN sys.database_principals dp ON perm.grantee_principal_id = dp.principal_id
    JOIN sys.types tt ON perm.major_id = tt.user_type_id AND perm.class = 6
    WHERE tt.user_type_id = TYPE_ID(N'dbo.HCA_PedidoMobileLinhaType')
    ORDER BY dp.name, perm.permission_name, perm.state_desc;

PRINT N'=== P5c. Snapshot: grantees ≠ portal_app (a repor manualmente após 100) ===';

SELECT
    N'SP' AS alvo,
    dp.name AS grantee,
    perm.permission_name,
    perm.state_desc
FROM sys.database_permissions perm
JOIN sys.database_principals dp ON perm.grantee_principal_id = dp.principal_id
JOIN sys.objects o ON perm.major_id = o.object_id AND perm.class = 1
WHERE o.object_id = OBJECT_ID(N'dbo.sp_HCA_criar_pedido_mobile')
  AND dp.name <> N'portal_app'
UNION ALL
SELECT
    N'TYPE' AS alvo,
    dp.name AS grantee,
    perm.permission_name,
    perm.state_desc
FROM sys.database_permissions perm
JOIN sys.database_principals dp ON perm.grantee_principal_id = dp.principal_id
JOIN sys.types tt ON perm.major_id = tt.user_type_id AND perm.class = 6
WHERE tt.user_type_id = TYPE_ID(N'dbo.HCA_PedidoMobileLinhaType')
  AND dp.name <> N'portal_app'
ORDER BY alvo, grantee;

PRINT N'Interpretação P5:';
PRINT N'  - Repo (091c/093/100) só documenta GRANT EXECUTE a portal_app.';
PRINT N'  - 100 reaplica EXECUTE TYPE+SP a portal_app; NÃO restaura outros grantees.';
PRINT N'  - DENY presente: investigar antes (pode bloquear a app mesmo com GRANT).';
PRINT N'  - P5c com linhas: COPIAR e planear re-GRANT após 100.';
PRINT N'Impedimento: DENY inesperado em portal_app; grantees críticos em P5c sem plano de reposição.';
PRINT N'Limitação: permissões via role membership indireta podem não aparecer como GRANT no objeto.';
GO

/*==============================================================================
  P6. Membership portal_app (contexto; não prova effective permissions)
==============================================================================*/
PRINT N'=== P6. portal_app — existência e roles ===';

IF NOT EXISTS (SELECT 1 FROM sys.database_principals WHERE name = N'portal_app')
    PRINT N'Principal portal_app inexistente.';
ELSE
BEGIN
    SELECT
        dp.name,
        dp.type_desc,
        dp.authentication_type_desc,
        dp.default_schema_name
    FROM sys.database_principals dp
    WHERE dp.name = N'portal_app';

    SELECT r.name AS role_name, m.name AS member_name
    FROM sys.database_role_members drm
    JOIN sys.database_principals r ON drm.role_principal_id = r.principal_id
    JOIN sys.database_principals m ON drm.member_principal_id = m.principal_id
    WHERE m.name = N'portal_app';
END

PRINT N'Interpretação P6: roles vazias são possíveis; EXECUTE explícito (P5) é o que o 100 restaura.';
GO

/*==============================================================================
  P7. Execuções atualmente visíveis da SP (dm_exec_requests)
  Pode falhar ou devolver vazio sem VIEW SERVER STATE / permissões adequadas.
==============================================================================*/
PRINT N'=== P7. Pedidos em execução que referem a SP (melhor esforço) ===';

BEGIN TRY
    SELECT
        r.session_id,
        r.status,
        r.command,
        r.cpu_time,
        r.total_elapsed_time,
        r.blocking_session_id,
        DB_NAME(r.database_id) AS database_name,
        SUBSTRING(t.text, 1, 400) AS sql_text_prefix
    FROM sys.dm_exec_requests r
    CROSS APPLY sys.dm_exec_sql_text(r.sql_handle) t
    WHERE t.text LIKE N'%sp_HCA_criar_pedido_mobile%'
      AND t.text NOT LIKE N'%103_precheck%'
    ORDER BY r.total_elapsed_time DESC;

    PRINT N'Interpretação P7: qualquer linha = SP/batch relacionado ativo — ADIAR 100 até terminar.';
END TRY
BEGIN CATCH
    PRINT N'AVISO P7: não foi possível consultar dm_exec_requests/sql_text.';
    PRINT N'Erro: ' + ERROR_MESSAGE();
    PRINT N'Limitação: sem VIEW SERVER STATE (ou equivalente) esta verificação não é fiável.';
    PRINT N'Nesse caso: confirmar janela de manutenção / ausência de tráfego portal por outro meio.';
END CATCH
GO

/*==============================================================================
  P8. Síntese orientadora (mensagens; não substitui análise das grelhas)
==============================================================================*/
PRINT N'=== P8. Critérios antes de executar o SQL 100 ===';
PRINT N'PROSSEGUIR tipicamente se:';
PRINT N'  - TYPE pós-093 (tem cor, sem edebito) OU já tem edebito e se aceita re-DROP;';
PRINT N'  - P3: só sp_HCA_criar_pedido_mobile referencia o TYPE (ou zero após DROP SP);';
PRINT N'  - P5c vazio OU lista de grants extra documentada para repor;';
PRINT N'  - P7 sem sessões ativas;';
PRINT N'  - portal_app existe (senão planear GRANT manual).';
PRINT N'NÃO PROSSEGUIR / INVESTIGAR se:';
PRINT N'  - Outro objeto além da SP referencia o TYPE;';
PRINT N'  - DENY em portal_app;';
PRINT N'  - TYPE sem cor (093 em falta);';
PRINT N'  - Execuções ativas da SP.';
PRINT N'=== FIM 103 pré-check read-only ===';
GO
