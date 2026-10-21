-- =============================================================================
-- Liliana & Seródio — Diagnóstico READ-ONLY Pedidos Mobile (UAT)
-- Script: 102_diagnose_pedidos_mobile_uat_readonly.sql
--
-- READ-ONLY permitido: SELECT; metadados (sys.*, OBJECT_ID, COL_LENGTH, TYPE_ID);
-- DECLARE/SET de variáveis; PRINT; SET NOCOUNT ON.
-- PROIBIDO: INSERT/UPDATE/DELETE/MERGE; CREATE/ALTER/DROP/TRUNCATE;
-- EXEC/EXECUTE/sp_executesql; SQL dinâmico; alteração de permissões/config.
--
-- ---------------------------------------------------------------------------
-- CONTRATO DE COMPILAÇÃO vs. AUSÊNCIA DE OBJECTOS (sem SQL dinâmico)
-- ---------------------------------------------------------------------------
-- Em SQL Server, IF OBJECT_ID(...) / IF COL_LENGTH(...) NÃO impedem a validação
-- em tempo de compilação de nomes de colunas referenciados em SELECT estáticos
-- no mesmo batch. Uma coluna inexistente pode falhar a compilação mesmo dentro
-- de um ramo IF que em runtime seria falso.
--
-- Este script NÃO usa SQL dinâmico. Por isso:
--   1) Secção A usa só metadados (compatível com esquemas incompletos).
--   2) Colunas opcionais 098/099 (MotivoRejeicao, DecididoPor, DataDecisao,
--      PrecoSubmissao) NUNCA aparecem em SELECT executável — só em A via COL_LENGTH.
--   3) Secções B–F pressupõem o baseline aplicado:
--        091  → u_HcaPedidoMobileIdem (IdempotencyKey varchar(64), bostamp char(25),
--               obrano, boano, no, estab, CreatedAt) + SP/TVP
--        096  → u_HcaPmPedido (PedidoId, NumeroInterno, ClNo, ClEstab, EstadoInterno,
--               DataSubmissao, DataAlteracao, Etotaldeb, Bostamp varchar(25),
--               Obrano, Boano, Ndos, …)
--        096b → u_HcaPmPedidoLin (PedidoId, LinhaOrd, Ref, Qtt, PrecoUnitario, TotalLinha, …)
--        PHC  → dbo.bo / dbo.bi com colunas usadas pela SP 091/100
--               (bostamp, obrano, boano, ndos, no, estab, etotaldeb, dataobra, nmdos,
--                ref, qtt, edebito, ettdeb, iva, tabiva, ivaincl, lordem, bistamp)
--   4) Se o baseline divergir, o batch afetado pode falhar na compilação/execução;
--      A identifica a divergência; esses diagnósticos B–F não são portáveis sem
--      alinhar o esquema ou reescrever com dinâmico (proibido aqui).
--
-- Prefixo staff: 'HCA-PM-APROV-' (13 chars) → sufixo na posição 14.
-- Conclusões: só o que a consulta prova; ndos=67 ≠ inventário “só mobile”.
--
-- Parâmetros manuais de Bostamp: variáveis de ENTRADA varchar(100) para preservar
-- o valor digitado antes da validação; só após validação se copia para varchar(25).
-- Se o cliente colar o parâmetro diretamente numa variável varchar(25), o motor
-- pode truncar antes deste script ver o original — use as variáveis *_Input.
-- =============================================================================

SET NOCOUNT ON;
GO

/*==============================================================================
  A) ESQUEMA E PERMISSÕES (INDICATIVAS)
==============================================================================*/
PRINT N'=== A0. Contrato (ler antes de interpretar B–F) ===';
PRINT N'IF/COL_LENGTH não protegem compilação de colunas estáticas ausentes.';
PRINT N'Sem SQL dinâmico: B–F exigem baseline 091/096/096b + bo/bi da SP.';
PRINT N'098/099: só metadados A2b; nunca SELECT executável neste script.';
PRINT N'Bostamp manual: editar *_Input (varchar(100)), não a variável de pesquisa 25.';

PRINT N'=== A1. Existência de objectos ===';
SELECT v.objeto,
       CASE WHEN v.existe = 1 THEN N'SIM' ELSE N'NÃO' END AS existe
FROM (
    SELECT N'dbo.u_HcaPmPedido' AS objeto,
           CASE WHEN OBJECT_ID(N'dbo.u_HcaPmPedido', N'U') IS NOT NULL THEN 1 ELSE 0 END AS existe
    UNION ALL SELECT N'dbo.u_HcaPmPedidoLin',
           CASE WHEN OBJECT_ID(N'dbo.u_HcaPmPedidoLin', N'U') IS NOT NULL THEN 1 ELSE 0 END
    UNION ALL SELECT N'dbo.u_HcaPedidoMobileIdem',
           CASE WHEN OBJECT_ID(N'dbo.u_HcaPedidoMobileIdem', N'U') IS NOT NULL THEN 1 ELSE 0 END
    UNION ALL SELECT N'dbo.HCA_PedidoMobileLinhaType (TVP)',
           CASE WHEN TYPE_ID(N'dbo.HCA_PedidoMobileLinhaType') IS NOT NULL THEN 1 ELSE 0 END
    UNION ALL SELECT N'dbo.sp_HCA_criar_pedido_mobile',
           CASE WHEN OBJECT_ID(N'dbo.sp_HCA_criar_pedido_mobile', N'P') IS NOT NULL THEN 1 ELSE 0 END
    UNION ALL SELECT N'dbo.bo',
           CASE WHEN OBJECT_ID(N'dbo.bo', N'U') IS NOT NULL THEN 1 ELSE 0 END
    UNION ALL SELECT N'dbo.bi',
           CASE WHEN OBJECT_ID(N'dbo.bi', N'U') IS NOT NULL THEN 1 ELSE 0 END
) v;

PRINT N'=== A2. Colunas u_HcaPmPedido ===';
IF OBJECT_ID(N'dbo.u_HcaPmPedido', N'U') IS NOT NULL
    SELECT c.column_id, c.name AS coluna, ty.name AS tipo,
           c.max_length, c.precision, c.scale, c.is_nullable
    FROM sys.columns c
    JOIN sys.types ty ON c.user_type_id = ty.user_type_id
    WHERE c.object_id = OBJECT_ID(N'dbo.u_HcaPmPedido')
    ORDER BY c.column_id;
ELSE
    PRINT N'u_HcaPmPedido inexistente — batches B/C/E que o referenciam podem falhar.';

PRINT N'=== A2b. COL_LENGTH (NULL = em falta; 098/099 só aqui) ===';
SELECT
    COL_LENGTH(N'dbo.u_HcaPmPedido', N'PedidoId') AS PedidoId,
    COL_LENGTH(N'dbo.u_HcaPmPedido', N'NumeroInterno') AS NumeroInterno,
    COL_LENGTH(N'dbo.u_HcaPmPedido', N'EstadoInterno') AS EstadoInterno,
    COL_LENGTH(N'dbo.u_HcaPmPedido', N'Bostamp') AS Bostamp,
    COL_LENGTH(N'dbo.u_HcaPmPedido', N'Obrano') AS Obrano,
    COL_LENGTH(N'dbo.u_HcaPmPedido', N'Boano') AS Boano,
    COL_LENGTH(N'dbo.u_HcaPmPedido', N'Ndos') AS Ndos,
    COL_LENGTH(N'dbo.u_HcaPmPedido', N'Etotaldeb') AS Etotaldeb,
    COL_LENGTH(N'dbo.u_HcaPmPedido', N'DataSubmissao') AS DataSubmissao,
    COL_LENGTH(N'dbo.u_HcaPmPedido', N'DataAlteracao') AS DataAlteracao,
    COL_LENGTH(N'dbo.u_HcaPmPedido', N'ClNo') AS ClNo,
    COL_LENGTH(N'dbo.u_HcaPmPedido', N'ClEstab') AS ClEstab,
    COL_LENGTH(N'dbo.u_HcaPmPedido', N'MotivoRejeicao') AS MotivoRejeicao_req098,
    COL_LENGTH(N'dbo.u_HcaPmPedido', N'DecididoPor') AS DecididoPor_req098,
    COL_LENGTH(N'dbo.u_HcaPmPedido', N'DataDecisao') AS DataDecisao_req098,
    COL_LENGTH(N'dbo.u_HcaPmPedidoLin', N'LinhaOrd') AS Lin_LinhaOrd,
    COL_LENGTH(N'dbo.u_HcaPmPedidoLin', N'Ref') AS Lin_Ref,
    COL_LENGTH(N'dbo.u_HcaPmPedidoLin', N'Qtt') AS Lin_Qtt,
    COL_LENGTH(N'dbo.u_HcaPmPedidoLin', N'PrecoUnitario') AS PrecoUnitario,
    COL_LENGTH(N'dbo.u_HcaPmPedidoLin', N'TotalLinha') AS TotalLinha,
    COL_LENGTH(N'dbo.u_HcaPmPedidoLin', N'PrecoSubmissao') AS PrecoSubmissao_req099,
    COL_LENGTH(N'dbo.u_HcaPedidoMobileIdem', N'IdempotencyKey') AS Idem_Key,
    COL_LENGTH(N'dbo.u_HcaPedidoMobileIdem', N'bostamp') AS Idem_bostamp,
    COL_LENGTH(N'dbo.u_HcaPedidoMobileIdem', N'obrano') AS Idem_obrano,
    COL_LENGTH(N'dbo.u_HcaPedidoMobileIdem', N'boano') AS Idem_boano,
    COL_LENGTH(N'dbo.u_HcaPedidoMobileIdem', N'no') AS Idem_no,
    COL_LENGTH(N'dbo.u_HcaPedidoMobileIdem', N'estab') AS Idem_estab,
    COL_LENGTH(N'dbo.u_HcaPedidoMobileIdem', N'CreatedAt') AS Idem_CreatedAt,
    COL_LENGTH(N'dbo.bo', N'bostamp') AS bo_bostamp,
    COL_LENGTH(N'dbo.bo', N'obrano') AS bo_obrano,
    COL_LENGTH(N'dbo.bo', N'boano') AS bo_boano,
    COL_LENGTH(N'dbo.bo', N'ndos') AS bo_ndos,
    COL_LENGTH(N'dbo.bo', N'etotaldeb') AS bo_etotaldeb,
    COL_LENGTH(N'dbo.bo', N'dataobra') AS bo_dataobra,
    COL_LENGTH(N'dbo.bo', N'nmdos') AS bo_nmdos,
    COL_LENGTH(N'dbo.bo', N'no') AS bo_no,
    COL_LENGTH(N'dbo.bo', N'estab') AS bo_estab,
    COL_LENGTH(N'dbo.bi', N'bostamp') AS bi_bostamp,
    COL_LENGTH(N'dbo.bi', N'bistamp') AS bi_bistamp,
    COL_LENGTH(N'dbo.bi', N'ref') AS bi_ref,
    COL_LENGTH(N'dbo.bi', N'qtt') AS bi_qtt,
    COL_LENGTH(N'dbo.bi', N'edebito') AS bi_edebito,
    COL_LENGTH(N'dbo.bi', N'ettdeb') AS bi_ettdeb,
    COL_LENGTH(N'dbo.bi', N'iva') AS bi_iva,
    COL_LENGTH(N'dbo.bi', N'tabiva') AS bi_tabiva,
    COL_LENGTH(N'dbo.bi', N'ivaincl') AS bi_ivaincl,
    COL_LENGTH(N'dbo.bi', N'lordem') AS bi_lordem;

PRINT N'=== A3. Colunas u_HcaPmPedidoLin ===';
IF OBJECT_ID(N'dbo.u_HcaPmPedidoLin', N'U') IS NOT NULL
    SELECT c.column_id, c.name AS coluna, ty.name AS tipo,
           c.max_length, c.precision, c.scale, c.is_nullable
    FROM sys.columns c
    JOIN sys.types ty ON c.user_type_id = ty.user_type_id
    WHERE c.object_id = OBJECT_ID(N'dbo.u_HcaPmPedidoLin')
    ORDER BY c.column_id;
ELSE
    PRINT N'u_HcaPmPedidoLin inexistente.';

PRINT N'=== A4. u_HcaPedidoMobileIdem + tipo IdempotencyKey (091: varchar(64)) ===';
IF OBJECT_ID(N'dbo.u_HcaPedidoMobileIdem', N'U') IS NULL
    PRINT N'u_HcaPedidoMobileIdem inexistente.';
ELSE
BEGIN
    SELECT c.column_id, c.name AS coluna, ty.name AS tipo,
           c.max_length, c.precision, c.scale, c.is_nullable
    FROM sys.columns c
    JOIN sys.types ty ON c.user_type_id = ty.user_type_id
    WHERE c.object_id = OBJECT_ID(N'dbo.u_HcaPedidoMobileIdem')
    ORDER BY c.column_id;

    SELECT
        c.name AS coluna,
        ty.name AS tipo,
        c.max_length,
        CASE
            WHEN ty.name = N'varchar' AND c.max_length = 64 THEN N'OK_VARCHAR_64'
            ELSE N'DIVERGENCIA_TIPO_OU_COMPRIMENTO'
        END AS check_vs_091,
        CASE
            WHEN ty.name = N'varchar' AND c.max_length = 64
                THEN N'C3: DATALENGTH/LEN aplicável a trailing spaces em varchar (bytes=chars em code page single-byte para ASCII)'
            WHEN ty.name = N'nvarchar'
                THEN N'C3 saltado: DATALENGTH em nvarchar é em bytes (≠ LEN); validação deste script não se aplica'
            ELSE N'C3 saltado: tipo/comprimento ≠ varchar(64) confirmado em 091'
        END AS nota_c3
    FROM sys.columns c
    JOIN sys.types ty ON c.user_type_id = ty.user_type_id
    WHERE c.object_id = OBJECT_ID(N'dbo.u_HcaPedidoMobileIdem')
      AND c.name = N'IdempotencyKey';
END

PRINT N'=== A5. TVP HCA_PedidoMobileLinhaType ===';
IF TYPE_ID(N'dbo.HCA_PedidoMobileLinhaType') IS NOT NULL
    SELECT c.column_id, c.name AS coluna, ty.name AS tipo,
           c.max_length, c.precision, c.scale, c.is_nullable
    FROM sys.table_types tt
    JOIN sys.columns c ON c.object_id = tt.type_table_object_id
    JOIN sys.types ty ON c.user_type_id = ty.user_type_id
    WHERE tt.schema_id = SCHEMA_ID(N'dbo')
      AND tt.name = N'HCA_PedidoMobileLinhaType'
    ORDER BY c.column_id;
ELSE
    PRINT N'TVP inexistente.';

PRINT N'=== A6. Índices/PK u_HcaPedidoMobileIdem ===';
IF OBJECT_ID(N'dbo.u_HcaPedidoMobileIdem', N'U') IS NOT NULL
    SELECT i.name AS indice, i.is_primary_key, i.is_unique, i.type_desc,
           c.name AS coluna, ic.key_ordinal
    FROM sys.indexes i
    JOIN sys.index_columns ic
      ON ic.object_id = i.object_id AND ic.index_id = i.index_id
    JOIN sys.columns c
      ON c.object_id = ic.object_id AND c.column_id = ic.column_id
    WHERE i.object_id = OBJECT_ID(N'dbo.u_HcaPedidoMobileIdem')
    ORDER BY i.index_id, ic.key_ordinal;
ELSE
    PRINT N'Tabela idem inexistente.';

PRINT N'=== A6b. Índices em bo.bostamp (evidência; não assume unicidade) ===';
IF OBJECT_ID(N'dbo.bo', N'U') IS NOT NULL
   AND COL_LENGTH(N'dbo.bo', N'bostamp') IS NOT NULL
    SELECT i.name AS indice, i.is_primary_key, i.is_unique, i.type_desc,
           c.name AS coluna, ic.key_ordinal
    FROM sys.indexes i
    JOIN sys.index_columns ic
      ON ic.object_id = i.object_id AND ic.index_id = i.index_id
    JOIN sys.columns c
      ON c.object_id = ic.object_id AND c.column_id = ic.column_id
    WHERE i.object_id = OBJECT_ID(N'dbo.bo')
      AND c.name = N'bostamp'
    ORDER BY i.index_id, ic.key_ordinal;
ELSE
    PRINT N'bo.bostamp indisponível para listar índices.';

PRINT N'=== A7. Parâmetros sp_HCA_criar_pedido_mobile (metadados; SP NÃO executada) ===';
IF OBJECT_ID(N'dbo.sp_HCA_criar_pedido_mobile', N'P') IS NOT NULL
    SELECT p.parameter_id, p.name, ty.name AS tipo,
           p.max_length, p.precision, p.scale
    FROM sys.parameters p
    JOIN sys.types ty ON p.user_type_id = ty.user_type_id
    WHERE p.object_id = OBJECT_ID(N'dbo.sp_HCA_criar_pedido_mobile')
    ORDER BY p.parameter_id;
ELSE
    PRINT N'SP inexistente.';

PRINT N'=== A8. Grants EXPLÍCITOS portal_app (INDICATIVO — NÃO prova permissões efetivas) ===';
PRINT N'Roles/ownership chaining/impersonation/DENY/runtime não são avaliados.';
IF EXISTS (SELECT 1 FROM sys.database_principals WHERE name = N'portal_app')
BEGIN
    SELECT dp.name AS grantee, o.type_desc,
           OBJECT_SCHEMA_NAME(o.object_id) + N'.' + o.name AS objeto,
           perm.permission_name, perm.state_desc
    FROM sys.database_permissions perm
    JOIN sys.database_principals dp ON perm.grantee_principal_id = dp.principal_id
    JOIN sys.objects o ON perm.major_id = o.object_id AND perm.class = 1
    WHERE dp.name = N'portal_app'
      AND o.name IN (
          N'u_HcaPmPedido', N'u_HcaPmPedidoLin',
          N'u_HcaPedidoMobileIdem', N'sp_HCA_criar_pedido_mobile')
    ORDER BY o.name, perm.permission_name;

    SELECT dp.name AS grantee,
           SCHEMA_NAME(tt.schema_id) + N'.' + tt.name AS tipo_tvp,
           perm.permission_name, perm.state_desc
    FROM sys.database_permissions perm
    JOIN sys.database_principals dp ON perm.grantee_principal_id = dp.principal_id
    JOIN sys.types tt ON perm.major_id = tt.user_type_id AND perm.class = 6
    WHERE dp.name = N'portal_app'
      AND tt.name = N'HCA_PedidoMobileLinhaType';

    PRINT N'=== A8b. Membership de roles (contexto; não prova effective permissions) ===';
    SELECT r.name AS role_name, m.name AS member_name
    FROM sys.database_role_members drm
    JOIN sys.database_principals r ON drm.role_principal_id = r.principal_id
    JOIN sys.database_principals m ON drm.member_principal_id = m.principal_id
    WHERE m.name = N'portal_app';
END
ELSE
    PRINT N'Principal portal_app inexistente.';
GO

/*==============================================================================
  B) PEDIDOS INTERNOS — baseline 096 (sem colunas 098 em SELECT)
  Se u_HcaPmPedido ou colunas baseline faltarem: este batch pode falhar.
==============================================================================*/
PRINT N'=== B1. Contagem por EstadoInterno ===';
IF OBJECT_ID(N'dbo.u_HcaPmPedido', N'U') IS NULL
    PRINT N'u_HcaPmPedido inexistente — saltar B (runtime). Se o batch falhou antes, ver A.';
ELSE
BEGIN
    SELECT EstadoInterno, COUNT(*) AS qtd
    FROM dbo.u_HcaPmPedido WITH (READCOMMITTED)
    WHERE NumeroInterno IS NOT NULL
    GROUP BY EstadoInterno
    ORDER BY EstadoInterno;

    PRINT N'=== B2. Amostra recente (TOP 50; não inventário) ===';
    SELECT TOP (50)
        PedidoId, NumeroInterno, EstadoInterno, ClNo, ClEstab,
        NULLIF(LTRIM(RTRIM(Bostamp)), N'') AS Bostamp,
        Obrano, Boano, Ndos, Etotaldeb,
        DataSubmissao, DataAlteracao
    FROM dbo.u_HcaPmPedido WITH (READCOMMITTED)
    WHERE NumeroInterno IS NOT NULL
    ORDER BY DataAlteracao DESC;

    /* 098: MotivoRejeicao/DecididoPor/DataDecisao — NÃO referenciados (compilação). */

    PRINT N'=== B3. em_aprovacao sem Bostamp (diagnóstico; sem UPDATE) ===';
    SELECT PedidoId, NumeroInterno, EstadoInterno,
           NULLIF(LTRIM(RTRIM(Bostamp)), N'') AS Bostamp, DataAlteracao
    FROM dbo.u_HcaPmPedido WITH (READCOMMITTED)
    WHERE NumeroInterno IS NOT NULL
      AND EstadoInterno = N'em_aprovacao'
      AND NULLIF(LTRIM(RTRIM(Bostamp)), N'') IS NULL
    ORDER BY DataAlteracao DESC;

    PRINT N'=== B4. em_aprovacao COM Bostamp (possível inconsistência de estado) ===';
    SELECT PedidoId, NumeroInterno, EstadoInterno,
           NULLIF(LTRIM(RTRIM(Bostamp)), N'') AS Bostamp,
           Obrano, Boano, Ndos, DataAlteracao
    FROM dbo.u_HcaPmPedido WITH (READCOMMITTED)
    WHERE NumeroInterno IS NOT NULL
      AND EstadoInterno = N'em_aprovacao'
      AND NULLIF(LTRIM(RTRIM(Bostamp)), N'') IS NOT NULL;

    PRINT N'=== B5. integrado sem Bostamp ou Ndos IS NULL ou Ndos<>67 ===';
    SELECT PedidoId, NumeroInterno, EstadoInterno,
           NULLIF(LTRIM(RTRIM(Bostamp)), N'') AS Bostamp,
           Obrano, Boano, Ndos
    FROM dbo.u_HcaPmPedido WITH (READCOMMITTED)
    WHERE NumeroInterno IS NOT NULL
      AND EstadoInterno = N'integrado'
      AND (
            NULLIF(LTRIM(RTRIM(Bostamp)), N'') IS NULL
         OR Ndos IS NULL
         OR Ndos <> 67
      );

    PRINT N'=== B6. rejeitado com Bostamp (só observação) ===';
    SELECT PedidoId, NumeroInterno, EstadoInterno,
           NULLIF(LTRIM(RTRIM(Bostamp)), N'') AS Bostamp
    FROM dbo.u_HcaPmPedido WITH (READCOMMITTED)
    WHERE NumeroInterno IS NOT NULL
      AND EstadoInterno = N'rejeitado'
      AND NULLIF(LTRIM(RTRIM(Bostamp)), N'') IS NOT NULL;
END
GO

/*==============================================================================
  C) IDEMPOTÊNCIA / ASSOCIAÇÃO / DOSSIER — EDITAR PARÂMETROS
==============================================================================*/
DECLARE @PedidoId bigint = 4;                    -- <<< EDITAR
DECLARE @BostampManualInput varchar(100) = NULL; -- <<< EDITAR opcional (entrada; até 100)
DECLARE @BostampManual varchar(25) = NULL;       -- pesquisa; só preenchida após validação

DECLARE @PrefixoAprovacao varchar(13) = 'HCA-PM-APROV-';
DECLARE @PrefixoLen int = 13;
DECLARE @IdemKey varchar(64) = NULL;
DECLARE @BostampResolvido varchar(25) = NULL;
DECLARE @BostampOrigem varchar(40) = N'NAO_RESOLVIDO';
DECLARE @IdemKeyTipoOk bit = 0;
DECLARE @ManualOk bit = 0;
DECLARE @CntFonte int = 0;
DECLARE @CntBo int = 0;
DECLARE @CntPedido int = 0;

IF @PedidoId IS NOT NULL
    SET @IdemKey = @PrefixoAprovacao + CONVERT(varchar(20), @PedidoId);

IF OBJECT_ID(N'dbo.u_HcaPedidoMobileIdem', N'U') IS NOT NULL
   AND EXISTS (
        SELECT 1
        FROM sys.columns c
        JOIN sys.types ty ON c.user_type_id = ty.user_type_id
        WHERE c.object_id = OBJECT_ID(N'dbo.u_HcaPedidoMobileIdem')
          AND c.name = N'IdempotencyKey'
          AND ty.name = N'varchar'
          AND c.max_length = 64
   )
    SET @IdemKeyTipoOk = 1;

PRINT N'=== C0. Parâmetros ===';
SELECT @PedidoId AS PedidoId,
       @IdemKey AS IdemKey,
       @PrefixoAprovacao AS Prefixo,
       @PrefixoLen AS PrefixoLen,
       14 AS SufixoPosicao_1based,
       @BostampManualInput AS BostampManualInput,
       CASE WHEN @BostampManualInput IS NULL THEN NULL ELSE LEN(@BostampManualInput) END AS BostampManualInput_LEN,
       CASE WHEN @BostampManualInput IS NULL THEN NULL ELSE DATALENGTH(@BostampManualInput) END AS BostampManualInput_DATALENGTH,
       @IdemKeyTipoOk AS IdempotencyKey_varchar64_ok;

IF OBJECT_ID(N'dbo.u_HcaPedidoMobileIdem', N'U') IS NOT NULL AND @IdemKeyTipoOk = 0
    PRINT N'AVISO: IdempotencyKey ≠ varchar(64) — C3/C3b saltados (ver A4).';

PRINT N'=== C1. Registo idem pela chave esperada ===';
IF @IdemKey IS NULL
    PRINT N'Saltar C1 — defina @PedidoId.';
ELSE IF OBJECT_ID(N'dbo.u_HcaPedidoMobileIdem', N'U') IS NULL
    PRINT N'u_HcaPedidoMobileIdem inexistente.';
ELSE
BEGIN
    SELECT @CntFonte = COUNT(*)
    FROM dbo.u_HcaPedidoMobileIdem WITH (READCOMMITTED)
    WHERE IdempotencyKey = @IdemKey;

    SELECT @CntFonte AS qtd_linhas_idem_para_chave,
           CASE WHEN @CntFonte > 1 THEN N'AMBIGUO_PK_PARTIDA_OU_DADOS' ELSE N'OK_OU_ZERO' END AS nota_contagem;

    SELECT IdempotencyKey,
           NULLIF(LTRIM(RTRIM(bostamp)), N'') AS bostamp,
           obrano, boano, no AS cl_no, estab AS cl_estab, CreatedAt
    FROM dbo.u_HcaPedidoMobileIdem WITH (READCOMMITTED)
    WHERE IdempotencyKey = @IdemKey;
END

PRINT N'=== C2. Associação pedido / idem / bo (sem JOIN que multiplique linhas) ===';
PRINT N'SEM_REGISTO_IDEM ≠ prova de ausência de dossier PHC.';
PRINT N'OK_ASSOCIACAO exige: 1 pedido, 1 idem, 1 bo via pedido, 1 bo via idem,';
PRINT N'1 pedido com esse Bostamp, e Bostamp/Obrano/Boano/Ndos preenchidos e coerentes.';
PRINT N'Com qtd>1, campos agregados ficam NULL — MAX() não prova coerência.';
PRINT N'DIVERGENCIA_* = ambos preenchidos e diferentes; INCOMPLETO_*_CAMPO_AUSENTE = um lado vazio;';
PRINT N'INCOMPLETO_*_AMBOS_AUSENTES = ambos vazios na comparação.';
PRINT N'Bostamp: NULLIF(LTRIM(RTRIM(...)), N'''') nas três origens (NULL/vazio/só espaços = ausência).';
PRINT N'Nota: u_HcaPedidoMobileIdem não tem Ndos — Ndos do lado idem só via bo.';

IF @PedidoId IS NULL
    PRINT N'Saltar C2 — defina @PedidoId.';
ELSE IF OBJECT_ID(N'dbo.u_HcaPmPedido', N'U') IS NULL
    OR OBJECT_ID(N'dbo.u_HcaPedidoMobileIdem', N'U') IS NULL
    OR OBJECT_ID(N'dbo.bo', N'U') IS NULL
    PRINT N'AVISO C2: objecto baseline em falta — saltar (runtime).';
ELSE
BEGIN
    SELECT @CntPedido = COUNT(*)
    FROM dbo.u_HcaPmPedido WITH (READCOMMITTED)
    WHERE PedidoId = @PedidoId;

    IF @CntPedido = 0
        PRINT N'C2: PedidoId sem registo em u_HcaPmPedido.';
    ELSE IF @CntPedido > 1
        PRINT N'AVISO C2: múltiplos registos para PedidoId — associação ambígua; sem OK_ASSOCIACAO.';
    ELSE
    BEGIN
        ;WITH p AS (
            SELECT
                PedidoId,
                NumeroInterno,
                EstadoInterno,
                NULLIF(LTRIM(RTRIM(Bostamp)), N'') AS Pedido_Bostamp,
                Obrano AS Pedido_Obrano,
                Boano AS Pedido_Boano,
                Ndos AS Pedido_Ndos
            FROM dbo.u_HcaPmPedido WITH (READCOMMITTED)
            WHERE PedidoId = @PedidoId
        ),
        idem_agg AS (
            SELECT
                COUNT(*) AS qtd_idem,
                CASE WHEN COUNT(*) = 1 THEN MAX(IdempotencyKey) END AS IdempotencyKey,
                CASE WHEN COUNT(*) = 1 THEN MAX(NULLIF(LTRIM(RTRIM(bostamp)), N'')) END AS Idem_bostamp,
                CASE WHEN COUNT(*) = 1 THEN MAX(obrano) END AS Idem_obrano,
                CASE WHEN COUNT(*) = 1 THEN MAX(boano) END AS Idem_boano
            FROM dbo.u_HcaPedidoMobileIdem WITH (READCOMMITTED)
            WHERE IdempotencyKey = @IdemKey
        ),
        bo_p_agg AS (
            SELECT
                COUNT(*) AS qtd_bo_pedido,
                CASE WHEN COUNT(*) = 1 THEN MAX(NULLIF(LTRIM(RTRIM(b.bostamp)), N'')) END AS Bo_via_pedido_bostamp,
                CASE WHEN COUNT(*) = 1 THEN MAX(b.obrano) END AS Bo_via_pedido_obrano,
                CASE WHEN COUNT(*) = 1 THEN MAX(b.boano) END AS Bo_via_pedido_boano,
                CASE WHEN COUNT(*) = 1 THEN MAX(b.ndos) END AS Bo_via_pedido_ndos
            FROM dbo.bo b WITH (READCOMMITTED)
            INNER JOIN p
                ON p.Pedido_Bostamp IS NOT NULL
               AND NULLIF(LTRIM(RTRIM(b.bostamp)), N'') = p.Pedido_Bostamp
        ),
        bo_i_agg AS (
            SELECT
                COUNT(*) AS qtd_bo_idem,
                CASE WHEN COUNT(*) = 1 THEN MAX(NULLIF(LTRIM(RTRIM(b.bostamp)), N'')) END AS Bo_via_idem_bostamp,
                CASE WHEN COUNT(*) = 1 THEN MAX(b.obrano) END AS Bo_via_idem_obrano,
                CASE WHEN COUNT(*) = 1 THEN MAX(b.boano) END AS Bo_via_idem_boano,
                CASE WHEN COUNT(*) = 1 THEN MAX(b.ndos) END AS Bo_via_idem_ndos
            FROM dbo.bo b WITH (READCOMMITTED)
            INNER JOIN idem_agg i
                ON i.qtd_idem = 1
               AND i.Idem_bostamp IS NOT NULL
               AND NULLIF(LTRIM(RTRIM(b.bostamp)), N'') = i.Idem_bostamp
        ),
        ped_mesmo_bs AS (
            SELECT COUNT(*) AS qtd_pedidos_mesmo_bostamp
            FROM dbo.u_HcaPmPedido px WITH (READCOMMITTED)
            INNER JOIN p
                ON p.Pedido_Bostamp IS NOT NULL
               AND NULLIF(LTRIM(RTRIM(px.Bostamp)), N'') = p.Pedido_Bostamp
        )
        SELECT
            p.PedidoId,
            p.NumeroInterno,
            p.EstadoInterno,
            p.Pedido_Bostamp,
            p.Pedido_Obrano,
            p.Pedido_Boano,
            p.Pedido_Ndos,
            @IdemKey AS IdemKey_esperada,
            CASE WHEN i.qtd_idem = 0 THEN 0 ELSE 1 END AS tem_registo_idem,
            i.qtd_idem,
            i.Idem_bostamp,
            i.Idem_obrano,
            i.Idem_boano,
            bi.qtd_bo_idem,
            bi.Bo_via_idem_bostamp,
            bi.Bo_via_idem_obrano,
            bi.Bo_via_idem_boano,
            bi.Bo_via_idem_ndos,
            bp.qtd_bo_pedido,
            bp.Bo_via_pedido_bostamp,
            bp.Bo_via_pedido_obrano,
            bp.Bo_via_pedido_boano,
            bp.Bo_via_pedido_ndos,
            pm.qtd_pedidos_mesmo_bostamp,
            CASE
                /* ---- 1) Ambiguidade prevalece ---- */
                WHEN i.qtd_idem > 1
                    THEN N'AMBIGUO_MULTIPLAS_LINHAS_IDEM'
                WHEN bp.qtd_bo_pedido > 1
                    THEN N'AMBIGUO_MULTIPLOS_BO_MESMO_PEDIDO_BOSTAMP'
                WHEN bi.qtd_bo_idem > 1
                    THEN N'AMBIGUO_MULTIPLOS_BO_MESMO_IDEM_BOSTAMP'
                WHEN pm.qtd_pedidos_mesmo_bostamp > 1
                    THEN N'AMBIGUO_MULTIPLOS_PEDIDOS_MESMO_BOSTAMP'

                /* ---- 2) Pedido vs Idem (só com qtd_idem = 1) ---- */
                WHEN i.qtd_idem = 1
                 AND p.Pedido_Bostamp IS NOT NULL AND i.Idem_bostamp IS NOT NULL
                 AND p.Pedido_Bostamp <> i.Idem_bostamp
                    THEN N'DIVERGENCIA_BOSTAMP_PEDIDO_VS_IDEM'
                WHEN i.qtd_idem = 1
                 AND (
                        (p.Pedido_Bostamp IS NOT NULL AND i.Idem_bostamp IS NULL)
                     OR (p.Pedido_Bostamp IS NULL AND i.Idem_bostamp IS NOT NULL)
                 )
                    THEN N'INCOMPLETO_BOSTAMP_PEDIDO_VS_IDEM_CAMPO_AUSENTE'
                WHEN i.qtd_idem = 1
                 AND p.Pedido_Bostamp IS NULL AND i.Idem_bostamp IS NULL
                    THEN N'INCOMPLETO_BOSTAMP_PEDIDO_VS_IDEM_AMBOS_AUSENTES'

                WHEN i.qtd_idem = 1
                 AND p.Pedido_Obrano IS NOT NULL AND i.Idem_obrano IS NOT NULL
                 AND p.Pedido_Obrano <> i.Idem_obrano
                    THEN N'DIVERGENCIA_OBRANO_PEDIDO_VS_IDEM'
                WHEN i.qtd_idem = 1
                 AND (
                        (p.Pedido_Obrano IS NOT NULL AND i.Idem_obrano IS NULL)
                     OR (p.Pedido_Obrano IS NULL AND i.Idem_obrano IS NOT NULL)
                 )
                    THEN N'INCOMPLETO_OBRANO_PEDIDO_VS_IDEM_CAMPO_AUSENTE'
                WHEN i.qtd_idem = 1
                 AND p.Pedido_Obrano IS NULL AND i.Idem_obrano IS NULL
                    THEN N'INCOMPLETO_OBRANO_PEDIDO_VS_IDEM_AMBOS_AUSENTES'

                WHEN i.qtd_idem = 1
                 AND p.Pedido_Boano IS NOT NULL AND i.Idem_boano IS NOT NULL
                 AND p.Pedido_Boano <> i.Idem_boano
                    THEN N'DIVERGENCIA_BOANO_PEDIDO_VS_IDEM'
                WHEN i.qtd_idem = 1
                 AND (
                        (p.Pedido_Boano IS NOT NULL AND i.Idem_boano IS NULL)
                     OR (p.Pedido_Boano IS NULL AND i.Idem_boano IS NOT NULL)
                 )
                    THEN N'INCOMPLETO_BOANO_PEDIDO_VS_IDEM_CAMPO_AUSENTE'
                WHEN i.qtd_idem = 1
                 AND p.Pedido_Boano IS NULL AND i.Idem_boano IS NULL
                    THEN N'INCOMPLETO_BOANO_PEDIDO_VS_IDEM_AMBOS_AUSENTES'

                /* ---- 3) Pedido vs Bo (só com qtd_bo_pedido = 1) ---- */
                WHEN bp.qtd_bo_pedido = 1
                 AND p.Pedido_Obrano IS NOT NULL AND bp.Bo_via_pedido_obrano IS NOT NULL
                 AND p.Pedido_Obrano <> bp.Bo_via_pedido_obrano
                    THEN N'DIVERGENCIA_OBRANO_PEDIDO_VS_BO'
                WHEN bp.qtd_bo_pedido = 1
                 AND (
                        (p.Pedido_Obrano IS NOT NULL AND bp.Bo_via_pedido_obrano IS NULL)
                     OR (p.Pedido_Obrano IS NULL AND bp.Bo_via_pedido_obrano IS NOT NULL)
                 )
                    THEN N'INCOMPLETO_OBRANO_PEDIDO_VS_BO_CAMPO_AUSENTE'
                WHEN bp.qtd_bo_pedido = 1
                 AND p.Pedido_Obrano IS NULL AND bp.Bo_via_pedido_obrano IS NULL
                    THEN N'INCOMPLETO_OBRANO_PEDIDO_VS_BO_AMBOS_AUSENTES'

                WHEN bp.qtd_bo_pedido = 1
                 AND p.Pedido_Boano IS NOT NULL AND bp.Bo_via_pedido_boano IS NOT NULL
                 AND p.Pedido_Boano <> bp.Bo_via_pedido_boano
                    THEN N'DIVERGENCIA_BOANO_PEDIDO_VS_BO'
                WHEN bp.qtd_bo_pedido = 1
                 AND (
                        (p.Pedido_Boano IS NOT NULL AND bp.Bo_via_pedido_boano IS NULL)
                     OR (p.Pedido_Boano IS NULL AND bp.Bo_via_pedido_boano IS NOT NULL)
                 )
                    THEN N'INCOMPLETO_BOANO_PEDIDO_VS_BO_CAMPO_AUSENTE'
                WHEN bp.qtd_bo_pedido = 1
                 AND p.Pedido_Boano IS NULL AND bp.Bo_via_pedido_boano IS NULL
                    THEN N'INCOMPLETO_BOANO_PEDIDO_VS_BO_AMBOS_AUSENTES'

                WHEN bp.qtd_bo_pedido = 1
                 AND p.Pedido_Ndos IS NOT NULL AND bp.Bo_via_pedido_ndos IS NOT NULL
                 AND p.Pedido_Ndos <> bp.Bo_via_pedido_ndos
                    THEN N'DIVERGENCIA_NDOS_PEDIDO_VS_BO'
                WHEN bp.qtd_bo_pedido = 1
                 AND (
                        (p.Pedido_Ndos IS NOT NULL AND bp.Bo_via_pedido_ndos IS NULL)
                     OR (p.Pedido_Ndos IS NULL AND bp.Bo_via_pedido_ndos IS NOT NULL)
                 )
                    THEN N'INCOMPLETO_NDOS_PEDIDO_VS_BO_CAMPO_AUSENTE'
                WHEN bp.qtd_bo_pedido = 1
                 AND p.Pedido_Ndos IS NULL AND bp.Bo_via_pedido_ndos IS NULL
                    THEN N'INCOMPLETO_NDOS_PEDIDO_VS_BO_AMBOS_AUSENTES'

                WHEN bp.qtd_bo_pedido = 1
                 AND bp.Bo_via_pedido_ndos IS NOT NULL
                 AND bp.Bo_via_pedido_ndos <> 67
                    THEN N'DIVERGENCIA_NDOS_BO_VIA_PEDIDO_NAO_67'
                WHEN p.Pedido_Ndos IS NOT NULL
                 AND p.Pedido_Ndos <> 67
                    THEN N'DIVERGENCIA_NDOS_PEDIDO_NAO_67'

                /* ---- 4) Idem vs Bo (só com qtd_idem = 1 e qtd_bo_idem = 1) ---- */
                WHEN i.qtd_idem = 1 AND bi.qtd_bo_idem = 1
                 AND i.Idem_obrano IS NOT NULL AND bi.Bo_via_idem_obrano IS NOT NULL
                 AND i.Idem_obrano <> bi.Bo_via_idem_obrano
                    THEN N'DIVERGENCIA_OBRANO_IDEM_VS_BO'
                WHEN i.qtd_idem = 1 AND bi.qtd_bo_idem = 1
                 AND (
                        (i.Idem_obrano IS NOT NULL AND bi.Bo_via_idem_obrano IS NULL)
                     OR (i.Idem_obrano IS NULL AND bi.Bo_via_idem_obrano IS NOT NULL)
                 )
                    THEN N'INCOMPLETO_OBRANO_IDEM_VS_BO_CAMPO_AUSENTE'
                WHEN i.qtd_idem = 1 AND bi.qtd_bo_idem = 1
                 AND i.Idem_obrano IS NULL AND bi.Bo_via_idem_obrano IS NULL
                    THEN N'INCOMPLETO_OBRANO_IDEM_VS_BO_AMBOS_AUSENTES'

                WHEN i.qtd_idem = 1 AND bi.qtd_bo_idem = 1
                 AND i.Idem_boano IS NOT NULL AND bi.Bo_via_idem_boano IS NOT NULL
                 AND i.Idem_boano <> bi.Bo_via_idem_boano
                    THEN N'DIVERGENCIA_BOANO_IDEM_VS_BO'
                WHEN i.qtd_idem = 1 AND bi.qtd_bo_idem = 1
                 AND (
                        (i.Idem_boano IS NOT NULL AND bi.Bo_via_idem_boano IS NULL)
                     OR (i.Idem_boano IS NULL AND bi.Bo_via_idem_boano IS NOT NULL)
                 )
                    THEN N'INCOMPLETO_BOANO_IDEM_VS_BO_CAMPO_AUSENTE'
                WHEN i.qtd_idem = 1 AND bi.qtd_bo_idem = 1
                 AND i.Idem_boano IS NULL AND bi.Bo_via_idem_boano IS NULL
                    THEN N'INCOMPLETO_BOANO_IDEM_VS_BO_AMBOS_AUSENTES'

                WHEN bi.qtd_bo_idem = 1
                 AND bi.Bo_via_idem_ndos IS NOT NULL
                 AND bi.Bo_via_idem_ndos <> 67
                    THEN N'DIVERGENCIA_NDOS_BO_VIA_IDEM_NAO_67'
                WHEN bi.qtd_bo_idem = 1
                 AND bi.Bo_via_idem_ndos IS NULL
                    THEN N'INCOMPLETO_NDOS_BO_VIA_IDEM_CAMPO_AUSENTE'
                    /* Sem Ndos na tabela idem — só se avalia Ndos do bo via idem. */

                /* ---- 5) Bo via pedido vs Bo via idem (ambos únicos) ---- */
                WHEN bp.qtd_bo_pedido = 1 AND bi.qtd_bo_idem = 1
                 AND bp.Bo_via_pedido_bostamp IS NOT NULL AND bi.Bo_via_idem_bostamp IS NOT NULL
                 AND bp.Bo_via_pedido_bostamp <> bi.Bo_via_idem_bostamp
                    THEN N'DIVERGENCIA_BOSTAMP_BO_VIA_PEDIDO_VS_BO_VIA_IDEM'
                WHEN bp.qtd_bo_pedido = 1 AND bi.qtd_bo_idem = 1
                 AND (
                        (bp.Bo_via_pedido_bostamp IS NOT NULL AND bi.Bo_via_idem_bostamp IS NULL)
                     OR (bp.Bo_via_pedido_bostamp IS NULL AND bi.Bo_via_idem_bostamp IS NOT NULL)
                 )
                    THEN N'INCOMPLETO_BOSTAMP_BO_VIA_PEDIDO_VS_BO_VIA_IDEM_CAMPO_AUSENTE'
                WHEN bp.qtd_bo_pedido = 1 AND bi.qtd_bo_idem = 1
                 AND bp.Bo_via_pedido_bostamp IS NULL AND bi.Bo_via_idem_bostamp IS NULL
                    THEN N'INCOMPLETO_BOSTAMP_BO_VIA_PEDIDO_VS_BO_VIA_IDEM_AMBOS_AUSENTES'

                WHEN bp.qtd_bo_pedido = 1 AND bi.qtd_bo_idem = 1
                 AND bp.Bo_via_pedido_obrano IS NOT NULL AND bi.Bo_via_idem_obrano IS NOT NULL
                 AND bp.Bo_via_pedido_obrano <> bi.Bo_via_idem_obrano
                    THEN N'DIVERGENCIA_OBRANO_BO_VIA_PEDIDO_VS_BO_VIA_IDEM'
                WHEN bp.qtd_bo_pedido = 1 AND bi.qtd_bo_idem = 1
                 AND (
                        (bp.Bo_via_pedido_obrano IS NOT NULL AND bi.Bo_via_idem_obrano IS NULL)
                     OR (bp.Bo_via_pedido_obrano IS NULL AND bi.Bo_via_idem_obrano IS NOT NULL)
                 )
                    THEN N'INCOMPLETO_OBRANO_BO_VIA_PEDIDO_VS_BO_VIA_IDEM_CAMPO_AUSENTE'
                WHEN bp.qtd_bo_pedido = 1 AND bi.qtd_bo_idem = 1
                 AND bp.Bo_via_pedido_obrano IS NULL AND bi.Bo_via_idem_obrano IS NULL
                    THEN N'INCOMPLETO_OBRANO_BO_VIA_PEDIDO_VS_BO_VIA_IDEM_AMBOS_AUSENTES'

                WHEN bp.qtd_bo_pedido = 1 AND bi.qtd_bo_idem = 1
                 AND bp.Bo_via_pedido_boano IS NOT NULL AND bi.Bo_via_idem_boano IS NOT NULL
                 AND bp.Bo_via_pedido_boano <> bi.Bo_via_idem_boano
                    THEN N'DIVERGENCIA_BOANO_BO_VIA_PEDIDO_VS_BO_VIA_IDEM'
                WHEN bp.qtd_bo_pedido = 1 AND bi.qtd_bo_idem = 1
                 AND (
                        (bp.Bo_via_pedido_boano IS NOT NULL AND bi.Bo_via_idem_boano IS NULL)
                     OR (bp.Bo_via_pedido_boano IS NULL AND bi.Bo_via_idem_boano IS NOT NULL)
                 )
                    THEN N'INCOMPLETO_BOANO_BO_VIA_PEDIDO_VS_BO_VIA_IDEM_CAMPO_AUSENTE'
                WHEN bp.qtd_bo_pedido = 1 AND bi.qtd_bo_idem = 1
                 AND bp.Bo_via_pedido_boano IS NULL AND bi.Bo_via_idem_boano IS NULL
                    THEN N'INCOMPLETO_BOANO_BO_VIA_PEDIDO_VS_BO_VIA_IDEM_AMBOS_AUSENTES'

                WHEN bp.qtd_bo_pedido = 1 AND bi.qtd_bo_idem = 1
                 AND bp.Bo_via_pedido_ndos IS NOT NULL AND bi.Bo_via_idem_ndos IS NOT NULL
                 AND bp.Bo_via_pedido_ndos <> bi.Bo_via_idem_ndos
                    THEN N'DIVERGENCIA_NDOS_BO_VIA_PEDIDO_VS_BO_VIA_IDEM'
                WHEN bp.qtd_bo_pedido = 1 AND bi.qtd_bo_idem = 1
                 AND (
                        (bp.Bo_via_pedido_ndos IS NOT NULL AND bi.Bo_via_idem_ndos IS NULL)
                     OR (bp.Bo_via_pedido_ndos IS NULL AND bi.Bo_via_idem_ndos IS NOT NULL)
                 )
                    THEN N'INCOMPLETO_NDOS_BO_VIA_PEDIDO_VS_BO_VIA_IDEM_CAMPO_AUSENTE'
                WHEN bp.qtd_bo_pedido = 1 AND bi.qtd_bo_idem = 1
                 AND bp.Bo_via_pedido_ndos IS NULL AND bi.Bo_via_idem_ndos IS NULL
                    THEN N'INCOMPLETO_NDOS_BO_VIA_PEDIDO_VS_BO_VIA_IDEM_AMBOS_AUSENTES'

                /* ---- 6) Ausência de idem / claim / bo ---- */
                WHEN p.Pedido_Bostamp IS NULL
                 AND p.EstadoInterno = N'em_aprovacao'
                    THEN N'CLAIM_SEM_BOSTAMP_NO_PEDIDO'

                WHEN i.qtd_idem = 0 AND p.Pedido_Bostamp IS NULL
                    THEN N'SEM_REGISTO_IDEM'

                WHEN i.qtd_idem = 0
                 AND p.Pedido_Bostamp IS NOT NULL
                 AND bp.qtd_bo_pedido = 0
                    THEN N'SEM_REGISTO_IDEM_E_BO_NAO_ENCONTRADO_POR_PEDIDO_BOSTAMP'

                WHEN i.qtd_idem = 0
                 AND p.Pedido_Bostamp IS NOT NULL
                 AND bp.qtd_bo_pedido = 1
                 AND p.Pedido_Obrano IS NOT NULL
                 AND p.Pedido_Boano IS NOT NULL
                 AND p.Pedido_Ndos = 67
                 AND bp.Bo_via_pedido_obrano = p.Pedido_Obrano
                 AND bp.Bo_via_pedido_boano = p.Pedido_Boano
                 AND bp.Bo_via_pedido_ndos = 67
                    THEN N'SEM_REGISTO_IDEM_MAS_PEDIDO_E_BO_COERENTES'
                    /* Pedido↔bo coerentes; idem ausente — NÃO é OK_ASSOCIACAO. */

                WHEN i.qtd_idem = 0
                 AND p.Pedido_Bostamp IS NOT NULL
                 AND bp.qtd_bo_pedido = 1
                    THEN N'SEM_REGISTO_IDEM_PEDIDO_BO_INCOMPLETO'

                WHEN i.qtd_idem = 1
                 AND (bp.qtd_bo_pedido = 0 OR bi.qtd_bo_idem = 0)
                    THEN N'INCOMPLETO_ASSOCIACAO'

                /* ---- 7) Única, completa e coerente ---- */
                WHEN i.qtd_idem = 1
                 AND bp.qtd_bo_pedido = 1
                 AND bi.qtd_bo_idem = 1
                 AND pm.qtd_pedidos_mesmo_bostamp = 1
                 AND p.Pedido_Bostamp IS NOT NULL
                 AND i.Idem_bostamp IS NOT NULL
                 AND bi.Bo_via_idem_bostamp IS NOT NULL
                 AND bp.Bo_via_pedido_bostamp IS NOT NULL
                 AND p.Pedido_Obrano IS NOT NULL
                 AND p.Pedido_Boano IS NOT NULL
                 AND p.Pedido_Ndos IS NOT NULL
                 AND i.Idem_obrano IS NOT NULL
                 AND i.Idem_boano IS NOT NULL
                 AND bi.Bo_via_idem_obrano IS NOT NULL
                 AND bi.Bo_via_idem_boano IS NOT NULL
                 AND bi.Bo_via_idem_ndos IS NOT NULL
                 AND bp.Bo_via_pedido_obrano IS NOT NULL
                 AND bp.Bo_via_pedido_boano IS NOT NULL
                 AND bp.Bo_via_pedido_ndos IS NOT NULL
                 AND i.Idem_bostamp = p.Pedido_Bostamp
                 AND bi.Bo_via_idem_bostamp = p.Pedido_Bostamp
                 AND bp.Bo_via_pedido_bostamp = p.Pedido_Bostamp
                 AND i.Idem_obrano = p.Pedido_Obrano
                 AND bi.Bo_via_idem_obrano = p.Pedido_Obrano
                 AND bp.Bo_via_pedido_obrano = p.Pedido_Obrano
                 AND i.Idem_boano = p.Pedido_Boano
                 AND bi.Bo_via_idem_boano = p.Pedido_Boano
                 AND bp.Bo_via_pedido_boano = p.Pedido_Boano
                 AND p.Pedido_Ndos = 67
                 AND bi.Bo_via_idem_ndos = 67
                 AND bp.Bo_via_pedido_ndos = 67
                    THEN N'OK_ASSOCIACAO'

                ELSE N'REVER_MANUAL_NAO_CLASSIFICADO'
            END AS diagnostico
        FROM p
        CROSS JOIN idem_agg i
        CROSS JOIN bo_p_agg bp
        CROSS JOIN bo_i_agg bi
        CROSS JOIN ped_mesmo_bs pm;
    END
END

PRINT N'=== C3. ÂMBITO: só chaves LIKE ''HCA-PM-APROV-%'' (prefixo esperado) ===';
PRINT N'C3/C3b NÃO inventariam todas as chaves inválidas da tabela idem.';
PRINT N'Chaves fora deste LIKE não são classificadas (nem OK nem inválidas) por C3/C3b.';
PRINT N'Sem LTRIM/RTRIM/normalização da chave. TRY_CONVERT só após formato OK.';
PRINT N'DATALENGTH/LEN trailing spaces: só com IdempotencyKey varchar(64); ASCII single-byte.';
IF OBJECT_ID(N'dbo.u_HcaPedidoMobileIdem', N'U') IS NULL
   OR OBJECT_ID(N'dbo.u_HcaPmPedido', N'U') IS NULL
    PRINT N'Tabelas em falta — saltar C3.';
ELSE IF @IdemKeyTipoOk = 0
    PRINT N'AVISO C3: IdempotencyKey ≠ varchar(64) — saltar (ver A4). Validação DATALENGTH/LEN não é universal.';
ELSE
BEGIN
    ;WITH raw AS (
        SELECT
            idem.IdempotencyKey,
            idem.bostamp,
            idem.obrano,
            idem.boano,
            idem.CreatedAt,
            SUBSTRING(idem.IdempotencyKey, @PrefixoLen + 1, 64) AS sufixo
        FROM dbo.u_HcaPedidoMobileIdem idem WITH (READCOMMITTED)
        WHERE idem.IdempotencyKey LIKE @PrefixoAprovacao + '%'
    ),
    classificado AS (
        SELECT
            r.*,
            DATALENGTH(r.IdempotencyKey) AS key_datalength,
            LEN(r.IdempotencyKey) AS key_len,
            DATALENGTH(r.sufixo) AS sufixo_datalength,
            LEN(r.sufixo) AS sufixo_len,
            CASE
                WHEN LEFT(r.IdempotencyKey, @PrefixoLen) <> @PrefixoAprovacao
                    THEN N'PREFIXO_INVALIDO'
                WHEN DATALENGTH(r.IdempotencyKey) <> LEN(r.IdempotencyKey)
                    THEN N'CHAVE_ESPACOS_FINAIS'
                WHEN DATALENGTH(r.IdempotencyKey) < (@PrefixoLen + 1)
                    THEN N'SEM_SUFIXO'
                WHEN DATALENGTH(r.sufixo) = 0
                    THEN N'SUFIXO_VAZIO'
                WHEN DATALENGTH(r.sufixo) <> LEN(r.sufixo)
                    THEN N'SUFIXO_ESPACOS_FINAIS'
                WHEN r.sufixo LIKE '%[^0-9]%'
                    THEN N'SUFIXO_NAO_NUMERICO'
                WHEN TRY_CONVERT(bigint, r.sufixo) IS NULL
                    THEN N'CONVERT_FALHOU'
                ELSE N'OK'
            END AS parse_status,
            CASE
                WHEN LEFT(r.IdempotencyKey, @PrefixoLen) = @PrefixoAprovacao
                 AND DATALENGTH(r.IdempotencyKey) = LEN(r.IdempotencyKey)
                 AND DATALENGTH(r.sufixo) > 0
                 AND DATALENGTH(r.sufixo) = LEN(r.sufixo)
                 AND r.sufixo NOT LIKE '%[^0-9]%'
                THEN TRY_CONVERT(bigint, r.sufixo)
                ELSE CAST(NULL AS bigint)
            END AS PedidoId_parseado
        FROM raw r
    )
    SELECT
        c.IdempotencyKey,
        c.PedidoId_parseado,
        c.parse_status,
        c.sufixo AS sufixo_bruto,
        c.sufixo_datalength,
        c.sufixo_len,
        NULLIF(LTRIM(RTRIM(c.bostamp)), N'') AS bostamp,
        c.obrano,
        c.boano,
        c.CreatedAt
    FROM classificado c
    WHERE c.parse_status = N'OK'
      AND c.PedidoId_parseado IS NOT NULL
      AND NOT EXISTS (
            SELECT 1
            FROM dbo.u_HcaPmPedido p WITH (READCOMMITTED)
            WHERE p.PedidoId = c.PedidoId_parseado
        )
    ORDER BY c.CreatedAt DESC;

    PRINT N'--- C3b. Dentro do âmbito LIKE prefixo: formatos inválidos / CONVERT_FALHOU ---';
    PRINT N'Não inclui chaves da tabela que não entram no LIKE do prefixo esperado.';
    ;WITH raw AS (
        SELECT
            IdempotencyKey,
            bostamp,
            CreatedAt,
            SUBSTRING(IdempotencyKey, @PrefixoLen + 1, 64) AS sufixo
        FROM dbo.u_HcaPedidoMobileIdem WITH (READCOMMITTED)
        WHERE IdempotencyKey LIKE @PrefixoAprovacao + '%'
    ),
    classificado AS (
        SELECT
            *,
            DATALENGTH(sufixo) AS sufixo_datalength,
            LEN(sufixo) AS sufixo_len,
            CASE
                WHEN LEFT(IdempotencyKey, @PrefixoLen) <> @PrefixoAprovacao THEN N'PREFIXO_INVALIDO'
                WHEN DATALENGTH(IdempotencyKey) <> LEN(IdempotencyKey) THEN N'CHAVE_ESPACOS_FINAIS'
                WHEN DATALENGTH(IdempotencyKey) < (@PrefixoLen + 1) THEN N'SEM_SUFIXO'
                WHEN DATALENGTH(sufixo) = 0 THEN N'SUFIXO_VAZIO'
                WHEN DATALENGTH(sufixo) <> LEN(sufixo) THEN N'SUFIXO_ESPACOS_FINAIS'
                WHEN sufixo LIKE '%[^0-9]%' THEN N'SUFIXO_NAO_NUMERICO'
                WHEN TRY_CONVERT(bigint, sufixo) IS NULL THEN N'CONVERT_FALHOU'
                ELSE N'OK'
            END AS parse_status
        FROM raw
    )
    SELECT
        IdempotencyKey,
        sufixo AS sufixo_bruto,
        sufixo_datalength,
        sufixo_len,
        NULLIF(LTRIM(RTRIM(bostamp)), N'') AS bostamp,
        CreatedAt,
        parse_status
    FROM classificado
    WHERE parse_status <> N'OK'
    ORDER BY CreatedAt DESC;
END

PRINT N'=== C4. em_aprovacao/integrado vs presença da chave (observacional) ===';
IF OBJECT_ID(N'dbo.u_HcaPmPedido', N'U') IS NULL
   OR OBJECT_ID(N'dbo.u_HcaPedidoMobileIdem', N'U') IS NULL
    PRINT N'Tabelas em falta — saltar C4.';
ELSE
    SELECT
        p.PedidoId, p.NumeroInterno, p.EstadoInterno,
        NULLIF(LTRIM(RTRIM(p.Bostamp)), N'') AS Pedido_Bostamp,
        @PrefixoAprovacao + CONVERT(varchar(20), p.PedidoId) AS IdemKey,
        CASE WHEN idem.IdempotencyKey IS NULL THEN 0 ELSE 1 END AS tem_idem,
        NULLIF(LTRIM(RTRIM(idem.bostamp)), N'') AS Idem_bostamp
    FROM dbo.u_HcaPmPedido p WITH (READCOMMITTED)
    LEFT JOIN dbo.u_HcaPedidoMobileIdem idem WITH (READCOMMITTED)
        ON idem.IdempotencyKey = @PrefixoAprovacao + CONVERT(varchar(20), p.PedidoId)
    WHERE p.NumeroInterno IS NOT NULL
      AND p.EstadoInterno IN (N'em_aprovacao', N'integrado')
    ORDER BY p.DataAlteracao DESC;

PRINT N'=== C5. Resolver Bostamp (manual → pedido → idem); input 100 → pesquisa 25 ===';
SET @ManualOk = 0;
SET @BostampManual = NULL;
SET @BostampResolvido = NULL;
SET @BostampOrigem = N'NAO_RESOLVIDO';
SET @CntFonte = 0;

IF @BostampManualInput IS NOT NULL
BEGIN
    IF DATALENGTH(@BostampManualInput) = 0 OR LEN(@BostampManualInput) = 0
        PRINT N'AVISO C5: @BostampManualInput vazio — ignorado.';
    ELSE IF DATALENGTH(@BostampManualInput) <> LEN(@BostampManualInput)
        PRINT N'AVISO C5: @BostampManualInput com espaços finais — não pesquisar.';
    ELSE IF @BostampManualInput LIKE ' %'
        PRINT N'AVISO C5: @BostampManualInput com espaço inicial — não pesquisar.';
    ELSE IF LEN(@BostampManualInput) > 25 OR DATALENGTH(@BostampManualInput) > 25
        PRINT N'AVISO C5: @BostampManualInput comprimento >25 — não truncar nem pesquisar.';
    ELSE
    BEGIN
        SET @BostampManual = CONVERT(varchar(25), @BostampManualInput);
        SET @BostampResolvido = @BostampManual;
        SET @BostampOrigem = N'PARAMETRO_MANUAL';
        SET @ManualOk = 1;
    END
END

IF @ManualOk = 0 AND @BostampResolvido IS NULL AND @PedidoId IS NOT NULL
BEGIN
    IF OBJECT_ID(N'dbo.u_HcaPmPedido', N'U') IS NULL
        PRINT N'AVISO C5: u_HcaPmPedido inexistente.';
    ELSE
    BEGIN
        SELECT @CntFonte = COUNT(*)
        FROM dbo.u_HcaPmPedido WITH (READCOMMITTED)
        WHERE PedidoId = @PedidoId;

        IF @CntFonte = 0
            PRINT N'C5: PedidoId sem registo — sem Bostamp via pedido.';
        ELSE IF @CntFonte > 1
            PRINT N'AVISO C5: múltiplos registos para PedidoId — não atribuir Bostamp.';
        ELSE
        BEGIN
            SELECT @BostampResolvido = NULLIF(LTRIM(RTRIM(Bostamp)), N'')
            FROM dbo.u_HcaPmPedido WITH (READCOMMITTED)
            WHERE PedidoId = @PedidoId;

            IF @BostampResolvido IS NOT NULL
                SET @BostampOrigem = N'PEDIDO_INTERNO';
        END
    END
END

IF @BostampResolvido IS NULL AND @IdemKey IS NOT NULL
BEGIN
    IF OBJECT_ID(N'dbo.u_HcaPedidoMobileIdem', N'U') IS NULL
        PRINT N'AVISO C5: tabela idem inexistente.';
    ELSE
    BEGIN
        SELECT @CntFonte = COUNT(*)
        FROM dbo.u_HcaPedidoMobileIdem WITH (READCOMMITTED)
        WHERE IdempotencyKey = @IdemKey;

        IF @CntFonte = 0
            PRINT N'C5: sem registo idem para a chave.';
        ELSE IF @CntFonte > 1
            PRINT N'AVISO C5: múltiplas linhas idem para a chave — não atribuir Bostamp arbitrário.';
        ELSE
        BEGIN
            SELECT @BostampResolvido = NULLIF(LTRIM(RTRIM(bostamp)), N'')
            FROM dbo.u_HcaPedidoMobileIdem WITH (READCOMMITTED)
            WHERE IdempotencyKey = @IdemKey;

            IF @BostampResolvido IS NOT NULL
                SET @BostampOrigem = N'TABELA_IDEMPOTENCIA';
        END
    END
END

IF @BostampResolvido IS NULL
    SET @BostampOrigem = N'NAO_RESOLVIDO';

SELECT @PedidoId AS PedidoId, @IdemKey AS IdemKey,
       @BostampManualInput AS BostampManualInput,
       @BostampManual AS BostampManual_validado,
       @BostampResolvido AS Bostamp_utilizado,
       @BostampOrigem AS Bostamp_origem;

IF @BostampResolvido IS NULL
    PRINT N'C5: Bostamp não resolvido — sem SELECT bo singular.';
ELSE IF OBJECT_ID(N'dbo.bo', N'U') IS NULL
    PRINT N'dbo.bo inexistente.';
ELSE
BEGIN
    SELECT @CntBo = COUNT(*)
    FROM dbo.bo WITH (READCOMMITTED)
    WHERE NULLIF(LTRIM(RTRIM(bostamp)), N'') = @BostampResolvido;

    SELECT @CntBo AS qtd_bo_para_bostamp_resolvido,
           CASE
               WHEN @CntBo = 0 THEN N'SEM_BO'
               WHEN @CntBo = 1 THEN N'UM_BO'
               ELSE N'AMBIGUO_MULTIPLOS_BO'
           END AS resolucao_bo;

    IF @CntBo > 1
        PRINT N'AVISO C5: vários bo com o mesmo Bostamp normalizado — listar todos; não há “o” dossier único.';

    SELECT @BostampOrigem AS Bostamp_origem,
           NULLIF(LTRIM(RTRIM(bo.bostamp)), N'') AS bostamp,
           bo.obrano, bo.boano, bo.ndos,
           bo.no AS cl_no, bo.estab AS cl_estab,
           bo.etotaldeb, bo.dataobra, RTRIM(bo.nmdos) AS nmdos
    FROM dbo.bo bo WITH (READCOMMITTED)
    WHERE NULLIF(LTRIM(RTRIM(bo.bostamp)), N'') = @BostampResolvido;
END

PRINT N'=== C6. Contagem linhas idem pela chave (não prova unicidade sozinha; ver A6 PK) ===';
IF @IdemKey IS NULL
    PRINT N'Saltar C6.';
ELSE IF OBJECT_ID(N'dbo.u_HcaPedidoMobileIdem', N'U') IS NULL
    PRINT N'AVISO C6: saltar.';
ELSE
    SELECT IdempotencyKey, COUNT(*) AS qtd_linhas_idem
    FROM dbo.u_HcaPedidoMobileIdem WITH (READCOMMITTED)
    WHERE IdempotencyKey = @IdemKey
    GROUP BY IdempotencyKey;
GO

/*==============================================================================
  E) PREÇOS — EDITAR PARÂMETROS (sem PrecoSubmissao em SELECT)
==============================================================================*/
DECLARE @PedidoId bigint = 4;                    -- <<< EDITAR
DECLARE @BostampManualInput varchar(100) = NULL; -- <<< EDITAR opcional (entrada)
DECLARE @BostampManual varchar(25) = NULL;       -- só após validação
DECLARE @PrefixoAprovacao varchar(13) = 'HCA-PM-APROV-';
DECLARE @IdemKey varchar(64) = NULL;
DECLARE @BostampResolvido varchar(25) = NULL;
DECLARE @BostampOrigem varchar(40) = N'NAO_RESOLVIDO';
DECLARE @ManualOk bit = 0;
DECLARE @CntFonte int = 0;
DECLARE @CntBo67 int = 0;

IF @PedidoId IS NOT NULL
    SET @IdemKey = @PrefixoAprovacao + CONVERT(varchar(20), @PedidoId);

SET @BostampResolvido = NULL;
SET @BostampOrigem = N'NAO_RESOLVIDO';
SET @ManualOk = 0;
SET @BostampManual = NULL;

IF @BostampManualInput IS NOT NULL
BEGIN
    IF DATALENGTH(@BostampManualInput) = 0 OR LEN(@BostampManualInput) = 0
        PRINT N'AVISO E: @BostampManualInput vazio — ignorado.';
    ELSE IF DATALENGTH(@BostampManualInput) <> LEN(@BostampManualInput)
        PRINT N'AVISO E: @BostampManualInput com espaços finais — não pesquisar.';
    ELSE IF @BostampManualInput LIKE ' %'
        PRINT N'AVISO E: @BostampManualInput com espaço inicial — não pesquisar.';
    ELSE IF LEN(@BostampManualInput) > 25 OR DATALENGTH(@BostampManualInput) > 25
        PRINT N'AVISO E: @BostampManualInput comprimento >25 — não truncar nem pesquisar.';
    ELSE
    BEGIN
        SET @BostampManual = CONVERT(varchar(25), @BostampManualInput);
        SET @BostampResolvido = @BostampManual;
        SET @BostampOrigem = N'PARAMETRO_MANUAL';
        SET @ManualOk = 1;
    END
END

IF @ManualOk = 0 AND @BostampResolvido IS NULL AND @PedidoId IS NOT NULL
   AND OBJECT_ID(N'dbo.u_HcaPmPedido', N'U') IS NOT NULL
BEGIN
    SELECT @CntFonte = COUNT(*)
    FROM dbo.u_HcaPmPedido WITH (READCOMMITTED)
    WHERE PedidoId = @PedidoId;

    IF @CntFonte > 1
        PRINT N'AVISO E: múltiplos pedidos para PedidoId — não atribuir Bostamp.';
    ELSE IF @CntFonte = 1
    BEGIN
        SELECT @BostampResolvido = NULLIF(LTRIM(RTRIM(Bostamp)), N'')
        FROM dbo.u_HcaPmPedido WITH (READCOMMITTED)
        WHERE PedidoId = @PedidoId;

        IF @BostampResolvido IS NOT NULL
            SET @BostampOrigem = N'PEDIDO_INTERNO';
    END
END

IF @BostampResolvido IS NULL AND @IdemKey IS NOT NULL
   AND OBJECT_ID(N'dbo.u_HcaPedidoMobileIdem', N'U') IS NOT NULL
BEGIN
    SELECT @CntFonte = COUNT(*)
    FROM dbo.u_HcaPedidoMobileIdem WITH (READCOMMITTED)
    WHERE IdempotencyKey = @IdemKey;

    IF @CntFonte > 1
        PRINT N'AVISO E: múltiplas linhas idem — não atribuir Bostamp arbitrário.';
    ELSE IF @CntFonte = 1
    BEGIN
        SELECT @BostampResolvido = NULLIF(LTRIM(RTRIM(bostamp)), N'')
        FROM dbo.u_HcaPedidoMobileIdem WITH (READCOMMITTED)
        WHERE IdempotencyKey = @IdemKey;

        IF @BostampResolvido IS NOT NULL
            SET @BostampOrigem = N'TABELA_IDEMPOTENCIA';
    END
END

IF @BostampResolvido IS NULL
    SET @BostampOrigem = N'NAO_RESOLVIDO';

PRINT N'=== E0. Contexto ===';
SELECT @PedidoId AS PedidoId, @IdemKey AS IdemKey,
       @BostampManualInput AS BostampManualInput,
       @BostampResolvido AS Bostamp_utilizado, @BostampOrigem AS Bostamp_origem;

PRINT N'=== E1. Linhas pedido (PrecoUnitario = preço no pedido interno; sem PrecoSubmissao) ===';
IF @PedidoId IS NULL
    PRINT N'Defina @PedidoId.';
ELSE IF OBJECT_ID(N'dbo.u_HcaPmPedidoLin', N'U') IS NULL
    PRINT N'u_HcaPmPedidoLin inexistente.';
ELSE
    SELECT LinhaOrd, LTRIM(RTRIM(Ref)) AS Ref, Qtt, PrecoUnitario, TotalLinha
    FROM dbo.u_HcaPmPedidoLin WITH (READCOMMITTED)
    WHERE PedidoId = @PedidoId
    ORDER BY LinhaOrd;

PRINT N'=== E2. Linhas BI só se existir exactamente UM bo com bostamp e ndos=67 ===';
IF @BostampResolvido IS NULL
    PRINT N'Sem Bostamp resolvido.';
ELSE IF OBJECT_ID(N'dbo.bi', N'U') IS NULL OR OBJECT_ID(N'dbo.bo', N'U') IS NULL
    PRINT N'bo/bi inexistente.';
ELSE
BEGIN
    SELECT @CntBo67 = COUNT(*)
    FROM dbo.bo WITH (READCOMMITTED)
    WHERE NULLIF(LTRIM(RTRIM(bostamp)), N'') = @BostampResolvido
      AND ndos = 67;

    SELECT @CntBo67 AS qtd_bo67_para_bostamp,
           CASE
               WHEN @CntBo67 = 0 THEN N'SEM_BO67'
               WHEN @CntBo67 = 1 THEN N'UM_BO67'
               ELSE N'AMBIGUO_MULTIPLOS_BO67'
           END AS nota;

    IF @CntBo67 = 0
        PRINT N'E2: nenhum bo com este bostamp e ndos=67 — BI não listado.';
    ELSE IF @CntBo67 > 1
    BEGIN
        PRINT N'AVISO E2: AMBIGUO_MULTIPLOS_BO67 — BI NÃO apresentado como dossier único.';
        PRINT N'Listar apenas os cabeçalhos bo ambíguos para revisão manual:';
        SELECT
            NULLIF(LTRIM(RTRIM(bo.bostamp)), N'') AS bostamp,
            bo.obrano, bo.boano, bo.ndos,
            bo.etotaldeb, bo.dataobra, RTRIM(bo.nmdos) AS nmdos
        FROM dbo.bo bo WITH (READCOMMITTED)
        WHERE NULLIF(LTRIM(RTRIM(bo.bostamp)), N'') = @BostampResolvido
          AND bo.ndos = 67;
    END
    ELSE
    BEGIN
        SELECT
            @BostampOrigem AS Bostamp_origem,
            bi.lordem,
            LTRIM(RTRIM(bi.ref)) AS ref,
            bi.qtt,
            bi.edebito,
            bi.ettdeb,
            bi.iva,
            bi.tabiva,
            bi.ivaincl AS ivaincl_bruto,
            TRY_CONVERT(int, bi.ivaincl) AS ivaincl_try_int,
            CASE
                WHEN bi.ivaincl IS NULL THEN N'IVAINCL_NULL'
                WHEN TRY_CONVERT(int, bi.ivaincl) IS NULL THEN N'IVAINCL_NAO_CONVERTIVEL_INT'
                ELSE N'IVAINCL_CONVERTIVEL'
            END AS ivaincl_nota
        FROM dbo.bi bi WITH (READCOMMITTED)
        INNER JOIN dbo.bo bo WITH (READCOMMITTED)
            ON NULLIF(LTRIM(RTRIM(bo.bostamp)), N'') = NULLIF(LTRIM(RTRIM(bi.bostamp)), N'')
           AND bo.ndos = 67
        WHERE NULLIF(LTRIM(RTRIM(bi.bostamp)), N'') = @BostampResolvido
        ORDER BY bi.lordem;
    END
END

PRINT N'=== E3. Cruzamento indiciário Ref + lordem=LinhaOrd*10000 (NÃO é FK) ===';
PRINT N'Coincide Ref/lordem ≠ prova de mesma linha de negócio.';
PRINT N'E3 só corre se existir exactamente UM bo ndos=67 para o Bostamp resolvido.';
IF @PedidoId IS NULL OR @BostampResolvido IS NULL
    PRINT N'E3 saltado — faltam PedidoId/Bostamp.';
ELSE IF OBJECT_ID(N'dbo.u_HcaPmPedidoLin', N'U') IS NULL
    OR OBJECT_ID(N'dbo.bi', N'U') IS NULL
    OR OBJECT_ID(N'dbo.bo', N'U') IS NULL
    PRINT N'E3 saltado — objectos em falta.';
ELSE
BEGIN
    SELECT @CntBo67 = COUNT(*)
    FROM dbo.bo WITH (READCOMMITTED)
    WHERE NULLIF(LTRIM(RTRIM(bostamp)), N'') = @BostampResolvido
      AND ndos = 67;

    IF @CntBo67 <> 1
        PRINT N'E3 saltado — qtd_bo67 <> 1 (sem dossier único confirmado).';
    ELSE
    BEGIN
        /* Agregação em CTE separada — evita Msg 130 (agregado sobre subquery/APPLY).
           bi_agg: só por LinhaOrd; campos da linha interna vêm do SELECT final. */
        ;WITH bi_match AS (
            SELECT
                l.LinhaOrd,
                bi.edebito,
                bi.qtt AS bi_qtt,
                bi.ettdeb,
                bi.lordem
            FROM dbo.u_HcaPmPedidoLin l WITH (READCOMMITTED)
            INNER JOIN dbo.bi bi WITH (READCOMMITTED)
                ON NULLIF(LTRIM(RTRIM(bi.bostamp)), N'') = @BostampResolvido
               AND RTRIM(bi.ref) = RTRIM(l.Ref)
               AND bi.lordem = (l.LinhaOrd * 10000)
            INNER JOIN dbo.bo bo WITH (READCOMMITTED)
                ON NULLIF(LTRIM(RTRIM(bo.bostamp)), N'') = NULLIF(LTRIM(RTRIM(bi.bostamp)), N'')
               AND bo.ndos = 67
            WHERE l.PedidoId = @PedidoId
        ),
        bi_agg AS (
            SELECT
                LinhaOrd,
                COUNT(*) AS qtd_bi_matches,
                MIN(edebito) AS edebito,
                MIN(bi_qtt) AS qtt,
                MIN(ettdeb) AS ettdeb,
                MIN(lordem) AS lordem
            FROM bi_match
            GROUP BY LinhaOrd
        )
        SELECT
            l.LinhaOrd,
            LTRIM(RTRIM(l.Ref)) AS Ref_interno,
            l.PrecoUnitario,
            l.Qtt,
            l.TotalLinha,
            ISNULL(a.qtd_bi_matches, 0) AS qtd_bi_matches,
            a.edebito AS BI_edebito_exemplo,
            a.qtt AS BI_qtt_exemplo,
            a.ettdeb AS BI_ettdeb_exemplo,
            a.lordem AS BI_lordem_exemplo,
            CASE
                WHEN ISNULL(a.qtd_bi_matches, 0) = 0 THEN N'SEM_LINHA_BI_CORRESPONDENTE'
                WHEN a.qtd_bi_matches > 1 THEN N'AMBIGUO_MULTIPLAS_LINHAS_BI'
                WHEN a.edebito = l.PrecoUnitario THEN N'EDEBITO_IGUAL_PRECO_UNITARIO_PEDIDO'
                ELSE N'EDEBITO_DIFERE_REVER_MANUAL'
            END AS comparacao_indiciaria
        FROM dbo.u_HcaPmPedidoLin l WITH (READCOMMITTED)
        LEFT JOIN bi_agg a
            ON a.LinhaOrd = l.LinhaOrd
        WHERE l.PedidoId = @PedidoId
        ORDER BY l.LinhaOrd;
    END
END

PRINT N'Nota E3: com AMBIGUO_MULTIPLAS_LINHAS_BI, edebito/qtt/ettdeb são MIN() só para amostra.';
GO

/*==============================================================================
  F) LEGADO / AMOSTRA ndos=67 — EDITAR @LegacyBostampInput
==============================================================================*/
DECLARE @LegacyBostampInput varchar(100) = NULL; -- <<< EDITAR (entrada; até 100)
DECLARE @LegacyBostamp varchar(25) = NULL;       -- pesquisa; só após validação
DECLARE @PrefixoAprovacao varchar(13) = 'HCA-PM-APROV-';
DECLARE @LegacyOk bit = 0;
DECLARE @CntBo67 int = 0;

PRINT N'=== F1. Amostra idem NÃO staff (origem_provavel = heurística de prefixo) ===';
IF OBJECT_ID(N'dbo.u_HcaPedidoMobileIdem', N'U') IS NULL
    PRINT N'AVISO F1: tabela inexistente.';
ELSE
    SELECT TOP (30)
        IdempotencyKey,
        NULLIF(LTRIM(RTRIM(bostamp)), N'') AS bostamp,
        obrano, boano, no AS cl_no, estab AS cl_estab, CreatedAt,
        CASE
            WHEN IdempotencyKey LIKE @PrefixoAprovacao + '%' THEN N'STAFF_APROVACAO'
            WHEN IdempotencyKey LIKE 'UAT-MOB-%' THEN N'TESTE_091b'
            ELSE N'LEGADO_OU_OUTRA'
        END AS origem_provavel
    FROM dbo.u_HcaPedidoMobileIdem WITH (READCOMMITTED)
    WHERE IdempotencyKey NOT LIKE @PrefixoAprovacao + '%'
    ORDER BY CreatedAt DESC;

PRINT N'=== F2. Dossier com ndos=67 confirmado; BI só se UM bo67 ===';
SET @LegacyOk = 0;
SET @LegacyBostamp = NULL;

IF @LegacyBostampInput IS NULL
    OR DATALENGTH(@LegacyBostampInput) = 0
    OR LEN(@LegacyBostampInput) = 0
    PRINT N'Defina @LegacyBostampInput.';
ELSE IF DATALENGTH(@LegacyBostampInput) <> LEN(@LegacyBostampInput)
    PRINT N'AVISO F2: espaços finais no input — não pesquisar.';
ELSE IF @LegacyBostampInput LIKE ' %'
    PRINT N'AVISO F2: espaço inicial no input — não pesquisar.';
ELSE IF LEN(@LegacyBostampInput) > 25 OR DATALENGTH(@LegacyBostampInput) > 25
    PRINT N'AVISO F2: comprimento >25 — não truncar nem pesquisar.';
ELSE IF OBJECT_ID(N'dbo.bo', N'U') IS NULL
    PRINT N'bo inexistente.';
ELSE
BEGIN
    SET @LegacyBostamp = CONVERT(varchar(25), @LegacyBostampInput);
    SET @LegacyOk = 1;
END

IF @LegacyOk = 1
BEGIN
    SELECT @CntBo67 = COUNT(*)
    FROM dbo.bo WITH (READCOMMITTED)
    WHERE NULLIF(LTRIM(RTRIM(bostamp)), N'') = @LegacyBostamp
      AND ndos = 67;

    SELECT
        @LegacyBostampInput AS LegacyBostampInput,
        @LegacyBostamp AS LegacyBostamp_validado,
        @CntBo67 AS qtd_bo67,
        CASE
            WHEN @CntBo67 = 0 THEN N'SEM_BO67'
            WHEN @CntBo67 = 1 THEN N'UM_BO67'
            ELSE N'AMBIGUO_MULTIPLOS_BO67'
        END AS nota;

    SELECT
        NULLIF(LTRIM(RTRIM(bo.bostamp)), N'') AS bostamp,
        bo.obrano, bo.boano, bo.ndos, bo.etotaldeb
    FROM dbo.bo bo WITH (READCOMMITTED)
    WHERE NULLIF(LTRIM(RTRIM(bo.bostamp)), N'') = @LegacyBostamp
      AND bo.ndos = 67;

    IF @CntBo67 = 0
        PRINT N'F2: sem bo ndos=67 — BI não apresentado.';
    ELSE IF @CntBo67 > 1
    BEGIN
        PRINT N'AVISO F2: AMBIGUO_MULTIPLOS_BO67 — BI NÃO apresentado como dossier único.';
    END
    ELSE IF OBJECT_ID(N'dbo.bi', N'U') IS NULL
        PRINT N'bi inexistente.';
    ELSE
    BEGIN
        SELECT
            LTRIM(RTRIM(bi.ref)) AS ref,
            bi.qtt,
            bi.edebito,
            bi.ettdeb,
            bi.iva,
            bi.lordem,
            NULLIF(LTRIM(RTRIM(bo.bostamp)), N'') AS bo_bostamp,
            bo.ndos AS bo_ndos_confirmado
        FROM dbo.bi bi WITH (READCOMMITTED)
        INNER JOIN dbo.bo bo WITH (READCOMMITTED)
            ON NULLIF(LTRIM(RTRIM(bo.bostamp)), N'') = NULLIF(LTRIM(RTRIM(bi.bostamp)), N'')
           AND bo.ndos = 67
        WHERE NULLIF(LTRIM(RTRIM(bi.bostamp)), N'') = @LegacyBostamp
        ORDER BY bi.lordem;

        PRINT N'Comparar bi.edebito com ST.epvN via CL.preco — MANUAL (este script não calcula).';
        PRINT N'ndos=67 confirmado no JOIN; não prova origem portal mobile.';
    END
END

PRINT N'=== F3. Amostra TOP 200 dossiers ndos=67 (1 linha por Bostamp normalizado) ===';
PRINT N'Dedupe: PARTITION BY NULLIF(LTRIM(RTRIM(bostamp)), N'''');';
PRINT N'ORDER BY dataobra DESC, obrano DESC, bostamp DESC.';
PRINT N'Se linhas 100% idênticas nesses campos, ROW_NUMBER pode ser não determinístico (ver A6b).';
PRINT N'Bostamp NULL/vazio/só espaços excluídos. Não é inventário completo.';
PRINT N'Esperado: com_pedido_interno + sem_pedido_interno = amostra_bo67 (zeros se amostra vazia).';

IF OBJECT_ID(N'dbo.bo', N'U') IS NULL
   OR OBJECT_ID(N'dbo.u_HcaPmPedido', N'U') IS NULL
    PRINT N'F3 saltado — objectos em falta.';
ELSE
BEGIN
    SELECT COUNT(*) AS bo67_com_bostamp_nulo_ou_vazio_excluidos_da_amostra
    FROM dbo.bo WITH (READCOMMITTED)
    WHERE ndos = 67
      AND NULLIF(LTRIM(RTRIM(bostamp)), N'') IS NULL;

    ;WITH ordered AS (
        SELECT
            NULLIF(LTRIM(RTRIM(bostamp)), N'') AS bs,
            dataobra,
            obrano,
            bostamp AS bostamp_bruto,
            ROW_NUMBER() OVER (
                PARTITION BY NULLIF(LTRIM(RTRIM(bostamp)), N'')
                ORDER BY dataobra DESC, obrano DESC, bostamp DESC
            ) AS rn_dup
        FROM dbo.bo WITH (READCOMMITTED)
        WHERE ndos = 67
          AND NULLIF(LTRIM(RTRIM(bostamp)), N'') IS NOT NULL
    ),
    dedup AS (
        SELECT bs, dataobra, obrano
        FROM ordered
        WHERE rn_dup = 1
    ),
    bo_sample AS (
        SELECT TOP (200) bs
        FROM dedup
        ORDER BY dataobra DESC, obrano DESC, bs DESC
    ),
    /* EXISTS no SELECT (não dentro de SUM) — evita Msg 130 */
    marcado AS (
        SELECT
            s.bs,
            CASE
                WHEN EXISTS (
                    SELECT 1
                    FROM dbo.u_HcaPmPedido p WITH (READCOMMITTED)
                    WHERE NULLIF(LTRIM(RTRIM(p.Bostamp)), N'') = s.bs
                ) THEN 1
                ELSE 0
            END AS tem_pedido_interno
        FROM bo_sample s
    )
    SELECT
        COUNT(*) AS amostra_bo67,
        ISNULL(SUM(tem_pedido_interno), 0) AS com_pedido_interno,
        ISNULL(SUM(1 - tem_pedido_interno), 0) AS sem_pedido_interno
    FROM marcado;
END

PRINT N'=== FIM diagnóstico read-only ===';
GO
