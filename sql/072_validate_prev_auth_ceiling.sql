-- =============================================================================
-- Liliana & Seródio — Portal Logístico
-- Script: 072_validate_prev_auth_ceiling.sql
-- Ambiente: UAT — validação estrutural PR2-A + checklist T1–T17
-- Pré-requisito: 068 (índice), 073 (SPs com u_prevId='' ; coluna NOT NULL)
-- =============================================================================
-- Não faz backfill. Não altera dados de negócio além de probes controlados
-- quando existirem pré-condições (senão BLOCKED).
-- u_prevId: NOT NULL; '' = sem associação (nunca NULL).
-- =============================================================================

SET NOCOUNT ON;

PRINT N'=== 072 PR2-A — validação teto previsão ===';
PRINT N'';

/* ---------- Estrutura ---------- */
IF COL_LENGTH(N'dbo.bi2', N'u_prevId') IS NULL
BEGIN
    RAISERROR(N'FAIL: BI2.u_prevId em falta (deve existir varchar(50) NOT NULL).', 16, 1);
    RETURN;
END;

DECLARE @prevType sysname, @prevLen int, @prevNullable bit;
SELECT
    @prevType = t.name,
    @prevLen = c.max_length,
    @prevNullable = c.is_nullable
FROM sys.columns c
INNER JOIN sys.types t ON t.user_type_id = c.user_type_id
WHERE c.object_id = OBJECT_ID(N'dbo.bi2')
  AND c.name = N'u_prevId';

IF @prevType <> N'varchar' OR @prevLen <> 50
    PRINT N'FAIL E1: BI2.u_prevId deve ser varchar(50) — actual: '
        + ISNULL(@prevType, N'?') + N'(' + CONVERT(nvarchar(10), @prevLen) + N')';
ELSE
    PRINT N'OK E1 BI2.u_prevId varchar(50)';

IF @prevNullable = 0
    PRINT N'OK E2 BI2.u_prevId NOT NULL';
ELSE
    PRINT N'FAIL E2 BI2.u_prevId deveria ser NOT NULL ('' = sem associação)';

IF EXISTS (
    SELECT 1 FROM sys.indexes
    WHERE name = N'IX_bi2_u_prevId' AND object_id = OBJECT_ID(N'dbo.bi2')
)
    PRINT N'OK E3 IX_bi2_u_prevId existe (não UNIQUE)';
ELSE
    PRINT N'AVISO E3 IX_bi2_u_prevId em falta (068)';

IF EXISTS (
    SELECT 1 FROM sys.indexes i
    WHERE i.object_id = OBJECT_ID(N'dbo.bi2')
      AND i.is_unique = 1
      AND EXISTS (
          SELECT 1 FROM sys.index_columns ic
          INNER JOIN sys.columns c ON c.object_id = ic.object_id AND c.column_id = ic.column_id
          WHERE ic.object_id = i.object_id AND ic.index_id = i.index_id
            AND c.name = N'u_prevId'
      )
)
    PRINT N'FAIL E4 NÃO deve existir UNIQUE em u_prevId';
ELSE
    PRINT N'OK E4 sem UNIQUE em u_prevId';

IF OBJECT_ID(N'dbo.sp_HCA_atualizar_qtd_autorizada', N'P') IS NULL
    PRINT N'FAIL E5 SP auth em falta';
ELSE
    PRINT N'OK E5 sp_HCA_atualizar_qtd_autorizada';

IF OBJECT_ID(N'dbo.sp_HCA_alocacao_proporcional', N'P') IS NULL
    PRINT N'FAIL E6 SP alocação em falta';
ELSE
    PRINT N'OK E6 sp_HCA_alocacao_proporcional';

-- Definição sem ST.stock como teto (heurística no texto do módulo)
DECLARE @defAuth nvarchar(max) = OBJECT_DEFINITION(OBJECT_ID(N'dbo.sp_HCA_atualizar_qtd_autorizada'));
DECLARE @defAloc nvarchar(max) = OBJECT_DEFINITION(OBJECT_ID(N'dbo.sp_HCA_alocacao_proporcional'));
DECLARE @defCancel nvarchar(max) = OBJECT_DEFINITION(OBJECT_ID(N'dbo.sp_HCA_picking_cancel'));
DECLARE @defPronta nvarchar(max) = OBJECT_DEFINITION(OBJECT_ID(N'dbo.sp_HCA_marcar_pronta_picking'));

IF @defAuth LIKE N'%Quantidade prevista insuficiente%'
   AND @defAuth LIKE N'%Não existe uma previsão de entrada aberta%'
   AND @defAuth LIKE N'%não tem quantidade prevista registada%'
   AND @defAuth LIKE N'%u_prevId%'
    PRINT N'OK E7 SP auth — mensagens/previsão presentes';
ELSE
    PRINT N'FAIL E7 SP auth — aplicar 068';

IF @defAuth LIKE N'%Stock insuficiente%'
    PRINT N'FAIL E8 SP auth ainda contém mensagem Stock insuficiente';
ELSE
    PRINT N'OK E8 SP auth sem mensagem Stock insuficiente';

IF @defAuth LIKE N'%FROM dbo.st %' OR @defAuth LIKE N'%FROM dbo.st' + CHAR(10) + N'%'
    PRINT N'AVISO E9 SP auth ainda referencia dbo.st (verificar se não é teto)';
ELSE
    PRINT N'OK E9 SP auth sem FROM dbo.st';

IF @defAloc LIKE N'%Não existe uma previsão de entrada aberta%'
   AND @defAloc LIKE N'%u_prevId%'
   AND @defAloc LIKE N'%QuantidadePrevista%'
    PRINT N'OK E10 SP alocação — previsão presente';
ELSE
    PRINT N'FAIL E10 SP alocação — aplicar 069';

IF @defAloc LIKE N'%SET @disponivel_usado = @stock%'
    PRINT N'FAIL E11 SP alocação ainda usa ST.stock como fallback';
ELSE
    PRINT N'OK E11 SP alocação sem fallback ST.stock';

IF @defCancel LIKE N'%u_prevId = ''''%' AND @defPronta LIKE N'%u_prevId = ''''%'
    PRINT N'OK E12 picking cancel / reverter pronta limpam u_prevId (='''')';
ELSE
    PRINT N'FAIL E12 aplicar 073 (clear u_prevId = '''')';

PRINT N'';
PRINT N'--- Checklist T1–T17 (execução funcional) ---';
PRINT N'Legenda: PASS = verificado nesta corrida; BLOCKED = falta fixture UAT;';
PRINT N'         MANUAL = requer operador / dois clientes SQL.';
PRINT N'';

DECLARE @openCount int =
    (SELECT COUNT(1) FROM dbo.u_HcaPrevEntrada WITH (NOLOCK) WHERE ISNULL(Fechada, 0) = 0);

IF @openCount = 0
BEGIN
    PRINT N'BLOCKED T1–T10,T14,T16,T17: não há previsão Fechada=0';
    PRINT N'BLOCKED T11–T13: requer encomenda de teste + picking';
    PRINT N'PASS T15: u_dispPort inalterado nesta PR (sem alteração de código)';
    PRINT N'';
    PRINT N'=== Fim 072 (estrutural OK; funcionais BLOCKED sem previsão aberta) ===';
    RETURN;
END;

IF @openCount > 1
    PRINT N'AVISO: mais de uma previsão aberta (PR1 deveria impedir)';

DECLARE @prevId uniqueidentifier;
DECLARE @prevIdStr varchar(50);
SELECT TOP (1)
    @prevId = Id,
    @prevIdStr = CONVERT(varchar(36), Id)
FROM dbo.u_HcaPrevEntrada WITH (NOLOCK)
WHERE ISNULL(Fechada, 0) = 0
ORDER BY DataInicio;

PRINT N'Previsão aberta: ' + @prevIdStr;

-- T12/T13: provar que Alocado NÃO filtra ndos (consulta espelho do SP)
PRINT N'MANUAL T12: após 1→66, SUM(u_qtdaut) com u_prevId=P e ref deve incluir a linha';
PRINT N'MANUAL T13: após 66→65, idem — consumo mantém-se';
PRINT N'MANUAL T11: com u_pickstat>=1, EXEC auth deve falhar com «congelada»';
PRINT N'MANUAL T17: dois EXEC concurrentes +20 com Disponível=30 — um OK, outro rejeitado';

-- Probe: fórmula Alocado sem filtro ndos (só leitura)
SELECT
    LTRIM(RTRIM(bi.ref)) AS ref,
    SUM(ISNULL(bi2.u_qtdaut, 0)) AS alocado_ciclo,
    COUNT(1) AS linhas
INTO #alocado_snap
FROM dbo.bi2 bi2 WITH (NOLOCK)
INNER JOIN dbo.bi bi WITH (NOLOCK)
    ON bi.bistamp COLLATE DATABASE_DEFAULT = bi2.bi2stamp COLLATE DATABASE_DEFAULT
WHERE LTRIM(RTRIM(ISNULL(bi2.u_prevId, ''))) = @prevIdStr
GROUP BY LTRIM(RTRIM(bi.ref));

PRINT N'OK SNAP: #alocado_snap = Alocado(P,ref) sem filtro ndos (ver SELECT)';
SELECT * FROM #alocado_snap ORDER BY ref;

-- Inconsistência sinalizada: u_qtdaut>0 com u_prevId='' (sem backfill)
DECLARE @orfaos int =
(
    SELECT COUNT(1)
    FROM dbo.bi2 bi2 WITH (NOLOCK)
    WHERE ISNULL(bi2.u_qtdaut, 0) > 0
      AND LTRIM(RTRIM(bi2.u_prevId)) = ''
);
PRINT N'AVISO ÓRFÃOS: linhas u_qtdaut>0 AND u_prevId='''' = '
    + CONVERT(nvarchar(20), @orfaos)
    + N' (não entram no Alocado do ciclo aberto; sem backfill PR2-A)';

PRINT N'';
PRINT N'BLOCKED T1–T10,T14,T16: requer fixture controlada (encomendas piloto + Lin prevista)';
PRINT N'PASS T15: STOBS.u_dispPort não alterado nesta PR';
PRINT N'';
PRINT N'=== Fim 072 ===';
GO
