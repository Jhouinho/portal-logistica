-- =============================================================================
-- Liliana & Seródio — Portal Logístico
-- Script: 070_alter_picking_clear_u_prevId.sql
-- Ambiente: UAT primeiro; Produção só no GO formal
-- Pré-requisito: 056 (versão activa); BI2.u_prevId varchar(50) NULL
-- =============================================================================
-- PR2-A — Ao cancelar autorização no picking, limpar também u_prevId.
--   sp_HCA_picking_cancel
--   sp_HCA_marcar_pronta_picking (@pronta=0)
-- Não altera 1→66→65 (sem libertação nessas transições).
-- =============================================================================

SET NOCOUNT ON;
GO

CREATE OR ALTER PROCEDURE dbo.sp_HCA_picking_cancel
    @bostamp  varchar(25),
    @usrlogin varchar(100),
    @usrinis  varchar(3) = NULL,
    @motivo   varchar(254)
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    IF @bostamp IS NULL OR LTRIM(RTRIM(@bostamp)) = ''
    BEGIN RAISERROR(N'bostamp obrigatório.', 16, 1); RETURN; END;
    IF @usrlogin IS NULL OR LTRIM(RTRIM(@usrlogin)) = ''
    BEGIN RAISERROR(N'usrlogin obrigatório.', 16, 1); RETURN; END;
    IF @motivo IS NULL OR LTRIM(RTRIM(@motivo)) = ''
    BEGIN RAISERROR(N'Motivo de cancelamento obrigatório.', 16, 1); RETURN; END;

    DECLARE @agora datetime = GETDATE(), @stat int, @usrinis_n varchar(3),
            @usrdata datetime, @usrhora varchar(8),
            @motivo_n varchar(254);
    SET @usrinis_n = LEFT(LTRIM(RTRIM(ISNULL(NULLIF(@usrinis, ''), @usrlogin))), 3);
    SET @usrdata = CAST(@agora AS date);
    SET @usrhora = CONVERT(varchar(8), @agora, 108);
    SET @motivo_n = LEFT(LTRIM(RTRIM(@motivo)), 254);

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

    UPDATE bi2
    SET
        u_qtdaut = 0,
        u_qtdautur = '',
        u_qtdautdt = CAST('19000101' AS datetime),
        u_prevId = NULL
    FROM dbo.bi2 bi2
    INNER JOIN dbo.bi bi ON bi.bistamp COLLATE DATABASE_DEFAULT = bi2.bi2stamp COLLATE DATABASE_DEFAULT
    WHERE bi.bostamp COLLATE DATABASE_DEFAULT = @bostamp COLLATE DATABASE_DEFAULT;

    UPDATE dbo.bo3
    SET u_pickrdy = 0, u_pickstat = 0,
        u_pickrdr = LEFT(LTRIM(RTRIM(@usrlogin)), 100), u_pickrdt = @agora,
        u_pickcobs = @motivo_n
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

CREATE OR ALTER PROCEDURE dbo.sp_HCA_marcar_pronta_picking
    @bostamp                varchar(25),
    @pronta                 bit,
    @usrlogin               varchar(100),
    @usrinis                varchar(3) = NULL,
    @confirmar_linhas_zero  bit = 0,
    @motivo                 varchar(254) = NULL
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    IF @bostamp IS NULL OR LTRIM(RTRIM(@bostamp)) = ''
    BEGIN
        RAISERROR(N'bostamp obrigatório.', 16, 1);
        RETURN;
    END;

    IF @usrlogin IS NULL OR LTRIM(RTRIM(@usrlogin)) = ''
    BEGIN
        RAISERROR(N'usrlogin obrigatório.', 16, 1);
        RETURN;
    END;

    IF ISNULL(@pronta, 0) = 0 AND (@motivo IS NULL OR LTRIM(RTRIM(@motivo)) = '')
    BEGIN
        RAISERROR(N'Motivo de cancelamento obrigatório.', 16, 1);
        RETURN;
    END;

    DECLARE
        @agora datetime = GETDATE(),
        @usrdata datetime,
        @usrhora varchar(8),
        @usrinis_n varchar(3),
        @linhas_zero int = 0,
        @stat_atual int,
        @motivo_n varchar(254);

    SET @usrdata = CAST(@agora AS date);
    SET @usrhora = CONVERT(varchar(8), @agora, 108);
    SET @usrinis_n = LEFT(LTRIM(RTRIM(ISNULL(NULLIF(@usrinis, ''), @usrlogin))), 3);
    SET @motivo_n = LEFT(LTRIM(RTRIM(ISNULL(@motivo, ''))), 254);

    BEGIN TRAN;

    IF NOT EXISTS (
        SELECT 1
        FROM dbo.bo bo WITH (UPDLOCK, ROWLOCK)
        WHERE bo.bostamp COLLATE DATABASE_DEFAULT = @bostamp COLLATE DATABASE_DEFAULT
          AND bo.ndos = 1
          AND ISNULL(bo.fechada, 0) = 0
    )
    BEGIN
        ROLLBACK;
        RAISERROR(N'Encomenda não encontrada ou documento fechado/série inválida.', 16, 1);
        RETURN;
    END;

    IF NOT EXISTS (
        SELECT 1 FROM dbo.bo3 WITH (UPDLOCK, ROWLOCK)
        WHERE bo3stamp COLLATE DATABASE_DEFAULT = @bostamp COLLATE DATABASE_DEFAULT
    )
        INSERT INTO dbo.bo3 (bo3stamp) VALUES (@bostamp);

    SELECT @stat_atual = CAST(ISNULL(u_pickstat, 0) AS int)
    FROM dbo.bo3 WITH (UPDLOCK, ROWLOCK)
    WHERE bo3stamp COLLATE DATABASE_DEFAULT = @bostamp COLLATE DATABASE_DEFAULT;

    IF ISNULL(@pronta, 0) = 1
    BEGIN
        IF @stat_atual NOT IN (0)
        BEGIN
            ROLLBACK;
            RAISERROR(N'Transição inválida: só é possível marcar para picking a partir de Em Aberto (u_pickstat=0).', 16, 1);
            RETURN;
        END;

        SELECT @linhas_zero = COUNT(1)
        FROM dbo.bi bi WITH (UPDLOCK, ROWLOCK)
        LEFT JOIN dbo.bi2 bi2 WITH (UPDLOCK, ROWLOCK)
            ON bi2.bi2stamp COLLATE DATABASE_DEFAULT = bi.bistamp COLLATE DATABASE_DEFAULT
        WHERE bi.bostamp COLLATE DATABASE_DEFAULT = @bostamp COLLATE DATABASE_DEFAULT
          AND ISNULL(bi2.u_qtdaut, 0) = 0
          AND (ISNULL(NULLIF(bi2.u_qttorig, 0), bi.qtt) - bi.qtt2) > 0;

        IF @linhas_zero > 0 AND ISNULL(@confirmar_linhas_zero, 0) = 0
        BEGIN
            ROLLBACK;
            RAISERROR(
                N'LINHAS_SEM_AUTORIZACAO: Existem linhas com quantidade autorizada a 0. Confirme para avançar.',
                16,
                1);
            RETURN;
        END;

        IF @linhas_zero > 0 AND ISNULL(@confirmar_linhas_zero, 0) = 1
        BEGIN
            INSERT INTO dbo.bi2 (bi2stamp)
            SELECT bi.bistamp
            FROM dbo.bi bi
            WHERE bi.bostamp COLLATE DATABASE_DEFAULT = @bostamp COLLATE DATABASE_DEFAULT
              AND NOT EXISTS (
                  SELECT 1 FROM dbo.bi2 bi2
                  WHERE bi2.bi2stamp COLLATE DATABASE_DEFAULT = bi.bistamp COLLATE DATABASE_DEFAULT
              );

            UPDATE bi2
            SET
                u_qttorig = CASE WHEN ISNULL(bi2.u_qttorig, 0) = 0 THEN bi.qtt ELSE bi2.u_qttorig END,
                u_prcorig = CASE WHEN ISNULL(bi2.u_prcorig, 0) = 0 THEN bi.edebito ELSE bi2.u_prcorig END
            FROM dbo.bi2 bi2
            INNER JOIN dbo.bi bi
                ON bi.bistamp COLLATE DATABASE_DEFAULT = bi2.bi2stamp COLLATE DATABASE_DEFAULT
            WHERE bi.bostamp COLLATE DATABASE_DEFAULT = @bostamp COLLATE DATABASE_DEFAULT
              AND ISNULL(bi2.u_qtdaut, 0) = 0
              AND (ISNULL(NULLIF(bi2.u_qttorig, 0), bi.qtt) - bi.qtt2) > 0;

            UPDATE bi
            SET
                qtt = ISNULL(bi2.u_qtdaut, 0),
                ettdeb = ROUND(ISNULL(bi2.u_qtdaut, 0) * bi.edebito, 2),
                usrinis = @usrinis_n,
                usrdata = @usrdata,
                usrhora = @usrhora
            FROM dbo.bi bi
            INNER JOIN dbo.bi2 bi2
                ON bi2.bi2stamp COLLATE DATABASE_DEFAULT = bi.bistamp COLLATE DATABASE_DEFAULT
            WHERE bi.bostamp COLLATE DATABASE_DEFAULT = @bostamp COLLATE DATABASE_DEFAULT
              AND ISNULL(bi2.u_qtdaut, 0) = 0
              AND (ISNULL(NULLIF(bi2.u_qttorig, 0), bi.qtt) - bi.qtt2) > 0;
        END;
    END
    ELSE
    BEGIN
        IF @stat_atual NOT IN (1)
        BEGIN
            ROLLBACK;
            RAISERROR(N'Transição inválida: só é possível cancelar picking a partir de Preparado (u_pickstat=1).', 16, 1);
            RETURN;
        END;

        INSERT INTO dbo.bi2 (bi2stamp)
        SELECT bi.bistamp
        FROM dbo.bi bi
        WHERE bi.bostamp COLLATE DATABASE_DEFAULT = @bostamp COLLATE DATABASE_DEFAULT
          AND NOT EXISTS (
              SELECT 1 FROM dbo.bi2 bi2
              WHERE bi2.bi2stamp COLLATE DATABASE_DEFAULT = bi.bistamp COLLATE DATABASE_DEFAULT
          );

        UPDATE bi
        SET
            qtt = bi2.u_qttorig,
            ettdeb = ROUND(bi2.u_qttorig * bi.edebito, 2),
            usrinis = @usrinis_n,
            usrdata = @usrdata,
            usrhora = @usrhora
        FROM dbo.bi bi
        INNER JOIN dbo.bi2 bi2
            ON bi2.bi2stamp COLLATE DATABASE_DEFAULT = bi.bistamp COLLATE DATABASE_DEFAULT
        WHERE bi.bostamp COLLATE DATABASE_DEFAULT = @bostamp COLLATE DATABASE_DEFAULT
          AND ISNULL(bi2.u_qttorig, 0) > 0;

        UPDATE bi2
        SET
            u_qtdaut = 0,
            u_qtdautur = '',
            u_qtdautdt = CAST('19000101' AS datetime),
            u_prevId = NULL
        FROM dbo.bi2 bi2
        INNER JOIN dbo.bi bi
            ON bi.bistamp COLLATE DATABASE_DEFAULT = bi2.bi2stamp COLLATE DATABASE_DEFAULT
        WHERE bi.bostamp COLLATE DATABASE_DEFAULT = @bostamp COLLATE DATABASE_DEFAULT;
    END;

    UPDATE dbo.bo3
    SET
        u_pickrdy = ISNULL(@pronta, 0),
        u_pickstat = CASE WHEN ISNULL(@pronta, 0) = 1 THEN 1 ELSE 0 END,
        u_pickrdr = LEFT(LTRIM(RTRIM(@usrlogin)), 100),
        u_pickrdt = @agora,
        u_pickcobs = CASE WHEN ISNULL(@pronta, 0) = 1 THEN '' ELSE @motivo_n END
    WHERE bo3stamp COLLATE DATABASE_DEFAULT = @bostamp COLLATE DATABASE_DEFAULT;

    UPDATE dbo.bo
    SET
        usrinis = @usrinis_n,
        usrdata = @usrdata,
        usrhora = @usrhora
    WHERE bostamp COLLATE DATABASE_DEFAULT = @bostamp COLLATE DATABASE_DEFAULT;

    COMMIT;

    SELECT
        bo.bostamp,
        CAST(ISNULL(bo3.u_pickrdy, 0) AS bit) AS pronta_picking,
        LTRIM(RTRIM(ISNULL(bo3.u_pickrdr, ''))) AS pronta_picking_por,
        CASE
            WHEN bo3.u_pickrdt IS NULL OR YEAR(bo3.u_pickrdt) < 1950 THEN CAST(NULL AS datetime)
            ELSE bo3.u_pickrdt
        END AS pronta_picking_em,
        CAST(ISNULL(bo3.u_pickstat, 0) AS int) AS pick_status
    FROM dbo.bo bo WITH (NOLOCK)
    LEFT JOIN dbo.bo3 bo3 WITH (NOLOCK)
        ON bo3.bo3stamp COLLATE DATABASE_DEFAULT = bo.bostamp COLLATE DATABASE_DEFAULT
    WHERE bo.bostamp COLLATE DATABASE_DEFAULT = @bostamp COLLATE DATABASE_DEFAULT;
END;
GO
