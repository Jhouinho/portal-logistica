-- =============================================================================
-- Liliana & Seródio — Portal Logístico
-- Script: 051_create_sp_HCA_picking_workflow.sql
-- Ambiente: UAT / teste; Produção só no GO formal
-- =============================================================================
-- Workflow picking (ndos=1):
--   start:           1 → 2
--   complete:        2 → 3
--   cancel:          1 → 0 (+ reverte qtt/autorizações; u_pickrdy=0)
--   back_to_ready:   2 → 1
--   reopen:          3 → 2
-- =============================================================================

CREATE OR ALTER PROCEDURE dbo.sp_HCA_picking_start
    @bostamp  varchar(25),
    @usrlogin varchar(100),
    @usrinis  varchar(3) = NULL
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    IF @bostamp IS NULL OR LTRIM(RTRIM(@bostamp)) = ''
    BEGIN RAISERROR(N'bostamp obrigatório.', 16, 1); RETURN; END;
    IF @usrlogin IS NULL OR LTRIM(RTRIM(@usrlogin)) = ''
    BEGIN RAISERROR(N'usrlogin obrigatório.', 16, 1); RETURN; END;

    DECLARE @agora datetime = GETDATE(), @stat int, @usrinis_n varchar(3);
    SET @usrinis_n = LEFT(LTRIM(RTRIM(ISNULL(NULLIF(@usrinis, ''), @usrlogin))), 3);

    BEGIN TRAN;

    IF NOT EXISTS (
        SELECT 1 FROM dbo.bo bo WITH (UPDLOCK, ROWLOCK)
        WHERE bo.bostamp COLLATE DATABASE_DEFAULT = @bostamp COLLATE DATABASE_DEFAULT
          AND bo.ndos = 1 AND ISNULL(bo.fechada, 0) = 0)
    BEGIN ROLLBACK; RAISERROR(N'Encomenda não encontrada ou documento fechado/série inválida.', 16, 1); RETURN; END;

    IF NOT EXISTS (SELECT 1 FROM dbo.bo3 WITH (UPDLOCK, ROWLOCK)
                   WHERE bo3stamp COLLATE DATABASE_DEFAULT = @bostamp COLLATE DATABASE_DEFAULT)
        INSERT INTO dbo.bo3 (bo3stamp) VALUES (@bostamp);

    SELECT @stat = CAST(ISNULL(u_pickstat, 0) AS int)
    FROM dbo.bo3 WITH (UPDLOCK, ROWLOCK)
    WHERE bo3stamp COLLATE DATABASE_DEFAULT = @bostamp COLLATE DATABASE_DEFAULT;

    IF @stat <> 1
    BEGIN ROLLBACK; RAISERROR(N'Transição inválida: Iniciar Picking só a partir de Preparado (u_pickstat=1).', 16, 1); RETURN; END;

    UPDATE dbo.bo3
    SET u_pickrdy = 1, u_pickstat = 2,
        u_pickrdr = LEFT(LTRIM(RTRIM(@usrlogin)), 100), u_pickrdt = @agora
    WHERE bo3stamp COLLATE DATABASE_DEFAULT = @bostamp COLLATE DATABASE_DEFAULT;

    UPDATE dbo.bo SET usrinis = @usrinis_n, usrdata = CAST(@agora AS date),
                      usrhora = CONVERT(varchar(8), @agora, 108)
    WHERE bostamp COLLATE DATABASE_DEFAULT = @bostamp COLLATE DATABASE_DEFAULT;

    COMMIT;

    SELECT bo.bostamp,
           CAST(ISNULL(bo3.u_pickrdy, 0) AS bit) AS pronta_picking,
           CAST(ISNULL(bo3.u_pickstat, 0) AS int) AS pick_status,
           LTRIM(RTRIM(ISNULL(bo3.u_pickrdr, ''))) AS pronta_picking_por,
           CASE WHEN bo3.u_pickrdt IS NULL OR YEAR(bo3.u_pickrdt) < 1950 THEN CAST(NULL AS datetime) ELSE bo3.u_pickrdt END AS pronta_picking_em
    FROM dbo.bo bo WITH (NOLOCK)
    LEFT JOIN dbo.bo3 bo3 WITH (NOLOCK) ON bo3.bo3stamp COLLATE DATABASE_DEFAULT = bo.bostamp COLLATE DATABASE_DEFAULT
    WHERE bo.bostamp COLLATE DATABASE_DEFAULT = @bostamp COLLATE DATABASE_DEFAULT;
END;
GO

CREATE OR ALTER PROCEDURE dbo.sp_HCA_picking_complete
    @bostamp  varchar(25),
    @usrlogin varchar(100),
    @usrinis  varchar(3) = NULL
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    IF @bostamp IS NULL OR LTRIM(RTRIM(@bostamp)) = ''
    BEGIN RAISERROR(N'bostamp obrigatório.', 16, 1); RETURN; END;
    IF @usrlogin IS NULL OR LTRIM(RTRIM(@usrlogin)) = ''
    BEGIN RAISERROR(N'usrlogin obrigatório.', 16, 1); RETURN; END;

    DECLARE @agora datetime = GETDATE(), @stat int, @usrinis_n varchar(3);
    SET @usrinis_n = LEFT(LTRIM(RTRIM(ISNULL(NULLIF(@usrinis, ''), @usrlogin))), 3);

    BEGIN TRAN;

    IF NOT EXISTS (
        SELECT 1 FROM dbo.bo bo WITH (UPDLOCK, ROWLOCK)
        WHERE bo.bostamp COLLATE DATABASE_DEFAULT = @bostamp COLLATE DATABASE_DEFAULT
          AND bo.ndos = 1 AND ISNULL(bo.fechada, 0) = 0)
    BEGIN ROLLBACK; RAISERROR(N'Encomenda não encontrada ou documento fechado/série inválida.', 16, 1); RETURN; END;

    IF NOT EXISTS (SELECT 1 FROM dbo.bo3 WITH (UPDLOCK, ROWLOCK)
                   WHERE bo3stamp COLLATE DATABASE_DEFAULT = @bostamp COLLATE DATABASE_DEFAULT)
        INSERT INTO dbo.bo3 (bo3stamp) VALUES (@bostamp);

    SELECT @stat = CAST(ISNULL(u_pickstat, 0) AS int)
    FROM dbo.bo3 WITH (UPDLOCK, ROWLOCK)
    WHERE bo3stamp COLLATE DATABASE_DEFAULT = @bostamp COLLATE DATABASE_DEFAULT;

    IF @stat <> 2
    BEGIN ROLLBACK; RAISERROR(N'Transição inválida: Concluir Picking só a partir de Em Curso (u_pickstat=2).', 16, 1); RETURN; END;

    UPDATE dbo.bo3
    SET u_pickrdy = 1, u_pickstat = 3,
        u_pickrdr = LEFT(LTRIM(RTRIM(@usrlogin)), 100), u_pickrdt = @agora
    WHERE bo3stamp COLLATE DATABASE_DEFAULT = @bostamp COLLATE DATABASE_DEFAULT;

    UPDATE dbo.bo SET usrinis = @usrinis_n, usrdata = CAST(@agora AS date),
                      usrhora = CONVERT(varchar(8), @agora, 108)
    WHERE bostamp COLLATE DATABASE_DEFAULT = @bostamp COLLATE DATABASE_DEFAULT;

    COMMIT;

    SELECT bo.bostamp,
           CAST(ISNULL(bo3.u_pickrdy, 0) AS bit) AS pronta_picking,
           CAST(ISNULL(bo3.u_pickstat, 0) AS int) AS pick_status,
           LTRIM(RTRIM(ISNULL(bo3.u_pickrdr, ''))) AS pronta_picking_por,
           CASE WHEN bo3.u_pickrdt IS NULL OR YEAR(bo3.u_pickrdt) < 1950 THEN CAST(NULL AS datetime) ELSE bo3.u_pickrdt END AS pronta_picking_em
    FROM dbo.bo bo WITH (NOLOCK)
    LEFT JOIN dbo.bo3 bo3 WITH (NOLOCK) ON bo3.bo3stamp COLLATE DATABASE_DEFAULT = bo.bostamp COLLATE DATABASE_DEFAULT
    WHERE bo.bostamp COLLATE DATABASE_DEFAULT = @bostamp COLLATE DATABASE_DEFAULT;
END;
GO

CREATE OR ALTER PROCEDURE dbo.sp_HCA_picking_cancel
    @bostamp  varchar(25),
    @usrlogin varchar(100),
    @usrinis  varchar(3) = NULL
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    IF @bostamp IS NULL OR LTRIM(RTRIM(@bostamp)) = ''
    BEGIN RAISERROR(N'bostamp obrigatório.', 16, 1); RETURN; END;
    IF @usrlogin IS NULL OR LTRIM(RTRIM(@usrlogin)) = ''
    BEGIN RAISERROR(N'usrlogin obrigatório.', 16, 1); RETURN; END;

    DECLARE @agora datetime = GETDATE(), @stat int, @usrinis_n varchar(3),
            @usrdata datetime, @usrhora varchar(8);
    SET @usrinis_n = LEFT(LTRIM(RTRIM(ISNULL(NULLIF(@usrinis, ''), @usrlogin))), 3);
    SET @usrdata = CAST(@agora AS date);
    SET @usrhora = CONVERT(varchar(8), @agora, 108);

    BEGIN TRAN;

    IF NOT EXISTS (
        SELECT 1 FROM dbo.bo bo WITH (UPDLOCK, ROWLOCK)
        WHERE bo.bostamp COLLATE DATABASE_DEFAULT = @bostamp COLLATE DATABASE_DEFAULT
          AND bo.ndos = 1 AND ISNULL(bo.fechada, 0) = 0)
    BEGIN ROLLBACK; RAISERROR(N'Encomenda não encontrada ou documento fechado/série inválida.', 16, 1); RETURN; END;

    IF NOT EXISTS (SELECT 1 FROM dbo.bo3 WITH (UPDLOCK, ROWLOCK)
                   WHERE bo3stamp COLLATE DATABASE_DEFAULT = @bostamp COLLATE DATABASE_DEFAULT)
        INSERT INTO dbo.bo3 (bo3stamp) VALUES (@bostamp);

    SELECT @stat = CAST(ISNULL(u_pickstat, 0) AS int)
    FROM dbo.bo3 WITH (UPDLOCK, ROWLOCK)
    WHERE bo3stamp COLLATE DATABASE_DEFAULT = @bostamp COLLATE DATABASE_DEFAULT;

    IF @stat <> 1
    BEGIN ROLLBACK; RAISERROR(N'Transição inválida: Cancelar Picking só a partir de Preparado (u_pickstat=1).', 16, 1); RETURN; END;

    -- Reverter quantidades (mesmo comportamento do cancel legado).
    INSERT INTO dbo.bi2 (bi2stamp)
    SELECT bi.bistamp FROM dbo.bi bi
    WHERE bi.bostamp COLLATE DATABASE_DEFAULT = @bostamp COLLATE DATABASE_DEFAULT
      AND NOT EXISTS (SELECT 1 FROM dbo.bi2 bi2
                      WHERE bi2.bi2stamp COLLATE DATABASE_DEFAULT = bi.bistamp COLLATE DATABASE_DEFAULT);

    UPDATE bi SET qtt = bi2.u_qttorig, ettdeb = ROUND(bi2.u_qttorig * bi.edebito, 2),
                  usrinis = @usrinis_n, usrdata = @usrdata, usrhora = @usrhora
    FROM dbo.bi bi
    INNER JOIN dbo.bi2 bi2 ON bi2.bi2stamp COLLATE DATABASE_DEFAULT = bi.bistamp COLLATE DATABASE_DEFAULT
    WHERE bi.bostamp COLLATE DATABASE_DEFAULT = @bostamp COLLATE DATABASE_DEFAULT
      AND ISNULL(bi2.u_qttorig, 0) > 0;

    UPDATE bi2 SET u_qtdaut = 0, u_qtdautur = '', u_qtdautdt = CAST('19000101' AS datetime)
    FROM dbo.bi2 bi2
    INNER JOIN dbo.bi bi ON bi.bistamp COLLATE DATABASE_DEFAULT = bi2.bi2stamp COLLATE DATABASE_DEFAULT
    WHERE bi.bostamp COLLATE DATABASE_DEFAULT = @bostamp COLLATE DATABASE_DEFAULT;

    UPDATE dbo.bo3
    SET u_pickrdy = 0, u_pickstat = 0,
        u_pickrdr = LEFT(LTRIM(RTRIM(@usrlogin)), 100), u_pickrdt = @agora
    WHERE bo3stamp COLLATE DATABASE_DEFAULT = @bostamp COLLATE DATABASE_DEFAULT;

    UPDATE dbo.bo SET usrinis = @usrinis_n, usrdata = @usrdata, usrhora = @usrhora
    WHERE bostamp COLLATE DATABASE_DEFAULT = @bostamp COLLATE DATABASE_DEFAULT;

    COMMIT;

    SELECT bo.bostamp,
           CAST(ISNULL(bo3.u_pickrdy, 0) AS bit) AS pronta_picking,
           CAST(ISNULL(bo3.u_pickstat, 0) AS int) AS pick_status,
           LTRIM(RTRIM(ISNULL(bo3.u_pickrdr, ''))) AS pronta_picking_por,
           CASE WHEN bo3.u_pickrdt IS NULL OR YEAR(bo3.u_pickrdt) < 1950 THEN CAST(NULL AS datetime) ELSE bo3.u_pickrdt END AS pronta_picking_em
    FROM dbo.bo bo WITH (NOLOCK)
    LEFT JOIN dbo.bo3 bo3 WITH (NOLOCK) ON bo3.bo3stamp COLLATE DATABASE_DEFAULT = bo.bostamp COLLATE DATABASE_DEFAULT
    WHERE bo.bostamp COLLATE DATABASE_DEFAULT = @bostamp COLLATE DATABASE_DEFAULT;
END;
GO

CREATE OR ALTER PROCEDURE dbo.sp_HCA_picking_back_to_ready
    @bostamp  varchar(25),
    @usrlogin varchar(100),
    @usrinis  varchar(3) = NULL
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    IF @bostamp IS NULL OR LTRIM(RTRIM(@bostamp)) = ''
    BEGIN RAISERROR(N'bostamp obrigatório.', 16, 1); RETURN; END;
    IF @usrlogin IS NULL OR LTRIM(RTRIM(@usrlogin)) = ''
    BEGIN RAISERROR(N'usrlogin obrigatório.', 16, 1); RETURN; END;

    DECLARE @agora datetime = GETDATE(), @stat int, @usrinis_n varchar(3);
    SET @usrinis_n = LEFT(LTRIM(RTRIM(ISNULL(NULLIF(@usrinis, ''), @usrlogin))), 3);

    BEGIN TRAN;

    IF NOT EXISTS (
        SELECT 1 FROM dbo.bo bo WITH (UPDLOCK, ROWLOCK)
        WHERE bo.bostamp COLLATE DATABASE_DEFAULT = @bostamp COLLATE DATABASE_DEFAULT
          AND bo.ndos = 1 AND ISNULL(bo.fechada, 0) = 0)
    BEGIN ROLLBACK; RAISERROR(N'Encomenda não encontrada ou documento fechado/série inválida.', 16, 1); RETURN; END;

    IF NOT EXISTS (SELECT 1 FROM dbo.bo3 WITH (UPDLOCK, ROWLOCK)
                   WHERE bo3stamp COLLATE DATABASE_DEFAULT = @bostamp COLLATE DATABASE_DEFAULT)
        INSERT INTO dbo.bo3 (bo3stamp) VALUES (@bostamp);

    SELECT @stat = CAST(ISNULL(u_pickstat, 0) AS int)
    FROM dbo.bo3 WITH (UPDLOCK, ROWLOCK)
    WHERE bo3stamp COLLATE DATABASE_DEFAULT = @bostamp COLLATE DATABASE_DEFAULT;

    IF @stat <> 2
    BEGIN ROLLBACK; RAISERROR(N'Transição inválida: Voltar a Preparado só a partir de Em Curso (u_pickstat=2).', 16, 1); RETURN; END;

    UPDATE dbo.bo3
    SET u_pickrdy = 1, u_pickstat = 1,
        u_pickrdr = LEFT(LTRIM(RTRIM(@usrlogin)), 100), u_pickrdt = @agora
    WHERE bo3stamp COLLATE DATABASE_DEFAULT = @bostamp COLLATE DATABASE_DEFAULT;

    UPDATE dbo.bo SET usrinis = @usrinis_n, usrdata = CAST(@agora AS date),
                      usrhora = CONVERT(varchar(8), @agora, 108)
    WHERE bostamp COLLATE DATABASE_DEFAULT = @bostamp COLLATE DATABASE_DEFAULT;

    COMMIT;

    SELECT bo.bostamp,
           CAST(ISNULL(bo3.u_pickrdy, 0) AS bit) AS pronta_picking,
           CAST(ISNULL(bo3.u_pickstat, 0) AS int) AS pick_status,
           LTRIM(RTRIM(ISNULL(bo3.u_pickrdr, ''))) AS pronta_picking_por,
           CASE WHEN bo3.u_pickrdt IS NULL OR YEAR(bo3.u_pickrdt) < 1950 THEN CAST(NULL AS datetime) ELSE bo3.u_pickrdt END AS pronta_picking_em
    FROM dbo.bo bo WITH (NOLOCK)
    LEFT JOIN dbo.bo3 bo3 WITH (NOLOCK) ON bo3.bo3stamp COLLATE DATABASE_DEFAULT = bo.bostamp COLLATE DATABASE_DEFAULT
    WHERE bo.bostamp COLLATE DATABASE_DEFAULT = @bostamp COLLATE DATABASE_DEFAULT;
END;
GO

CREATE OR ALTER PROCEDURE dbo.sp_HCA_picking_reopen
    @bostamp  varchar(25),
    @usrlogin varchar(100),
    @usrinis  varchar(3) = NULL
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    IF @bostamp IS NULL OR LTRIM(RTRIM(@bostamp)) = ''
    BEGIN RAISERROR(N'bostamp obrigatório.', 16, 1); RETURN; END;
    IF @usrlogin IS NULL OR LTRIM(RTRIM(@usrlogin)) = ''
    BEGIN RAISERROR(N'usrlogin obrigatório.', 16, 1); RETURN; END;

    DECLARE @agora datetime = GETDATE(), @stat int, @usrinis_n varchar(3);
    SET @usrinis_n = LEFT(LTRIM(RTRIM(ISNULL(NULLIF(@usrinis, ''), @usrlogin))), 3);

    BEGIN TRAN;

    IF NOT EXISTS (
        SELECT 1 FROM dbo.bo bo WITH (UPDLOCK, ROWLOCK)
        WHERE bo.bostamp COLLATE DATABASE_DEFAULT = @bostamp COLLATE DATABASE_DEFAULT
          AND bo.ndos = 1 AND ISNULL(bo.fechada, 0) = 0)
    BEGIN ROLLBACK; RAISERROR(N'Encomenda não encontrada ou documento fechado/série inválida.', 16, 1); RETURN; END;

    IF NOT EXISTS (SELECT 1 FROM dbo.bo3 WITH (UPDLOCK, ROWLOCK)
                   WHERE bo3stamp COLLATE DATABASE_DEFAULT = @bostamp COLLATE DATABASE_DEFAULT)
        INSERT INTO dbo.bo3 (bo3stamp) VALUES (@bostamp);

    SELECT @stat = CAST(ISNULL(u_pickstat, 0) AS int)
    FROM dbo.bo3 WITH (UPDLOCK, ROWLOCK)
    WHERE bo3stamp COLLATE DATABASE_DEFAULT = @bostamp COLLATE DATABASE_DEFAULT;

    IF @stat <> 3
    BEGIN ROLLBACK; RAISERROR(N'Transição inválida: Reabrir Picking só a partir de Concluído (u_pickstat=3).', 16, 1); RETURN; END;

    UPDATE dbo.bo3
    SET u_pickrdy = 1, u_pickstat = 2,
        u_pickrdr = LEFT(LTRIM(RTRIM(@usrlogin)), 100), u_pickrdt = @agora
    WHERE bo3stamp COLLATE DATABASE_DEFAULT = @bostamp COLLATE DATABASE_DEFAULT;

    UPDATE dbo.bo SET usrinis = @usrinis_n, usrdata = CAST(@agora AS date),
                      usrhora = CONVERT(varchar(8), @agora, 108)
    WHERE bostamp COLLATE DATABASE_DEFAULT = @bostamp COLLATE DATABASE_DEFAULT;

    COMMIT;

    SELECT bo.bostamp,
           CAST(ISNULL(bo3.u_pickrdy, 0) AS bit) AS pronta_picking,
           CAST(ISNULL(bo3.u_pickstat, 0) AS int) AS pick_status,
           LTRIM(RTRIM(ISNULL(bo3.u_pickrdr, ''))) AS pronta_picking_por,
           CASE WHEN bo3.u_pickrdt IS NULL OR YEAR(bo3.u_pickrdt) < 1950 THEN CAST(NULL AS datetime) ELSE bo3.u_pickrdt END AS pronta_picking_em
    FROM dbo.bo bo WITH (NOLOCK)
    LEFT JOIN dbo.bo3 bo3 WITH (NOLOCK) ON bo3.bo3stamp COLLATE DATABASE_DEFAULT = bo.bostamp COLLATE DATABASE_DEFAULT
    WHERE bo.bostamp COLLATE DATABASE_DEFAULT = @bostamp COLLATE DATABASE_DEFAULT;
END;
GO
