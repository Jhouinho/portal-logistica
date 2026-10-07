-- =============================================================================
-- Liliana & Seródio — Portal Logístico
-- Script: 038_create_sp_HCA_marcar_pronta_picking.sql
-- Ambiente: UAT / teste; Produção só no GO formal
-- =============================================================================
-- Marca / desmarca encomenda como pronta para picking (BO.u_pickrdy*).
-- Ao marcar: linhas abertas com u_qtdaut = 0 exigem @confirmar_linhas_zero = 1
-- e aplicam u_qttorig←qtt (se orig=0) e qtt←u_qtdaut.
-- Alter posterior: 040_alter_sp_HCA_marcar_pronta_picking_linhas_zero.sql
-- =============================================================================

CREATE OR ALTER PROCEDURE dbo.sp_HCA_marcar_pronta_picking
    @bostamp                varchar(25),
    @pronta                 bit,
    @usrlogin               varchar(100),
    @usrinis                varchar(3) = NULL,
    @confirmar_linhas_zero  bit = 0
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

    DECLARE
        @agora datetime = GETDATE(),
        @usrdata datetime,
        @usrhora varchar(8),
        @usrinis_n varchar(3),
        @linhas_zero int = 0;

    SET @usrdata = CAST(@agora AS date);
    SET @usrhora = CONVERT(varchar(8), @agora, 108);
    SET @usrinis_n = LEFT(LTRIM(RTRIM(ISNULL(NULLIF(@usrinis, ''), @usrlogin))), 3);

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

    IF ISNULL(@pronta, 0) = 1
    BEGIN
        SELECT @linhas_zero = COUNT(1)
        FROM dbo.bi bi WITH (UPDLOCK, ROWLOCK)
        WHERE bi.bostamp COLLATE DATABASE_DEFAULT = @bostamp COLLATE DATABASE_DEFAULT
          AND ISNULL(bi.u_qtdaut, 0) = 0
          AND (ISNULL(NULLIF(bi.u_qttorig, 0), bi.qtt) - bi.qtt2) > 0;

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
            UPDATE bi
            SET
                u_qttorig = CASE
                    WHEN ISNULL(bi.u_qttorig, 0) = 0 THEN bi.qtt
                    ELSE bi.u_qttorig
                END,
                qtt = bi.u_qtdaut,
                ettdeb = ROUND(bi.u_qtdaut * bi.edebito, 2),
                usrinis = @usrinis_n,
                usrdata = @usrdata,
                usrhora = @usrhora
            FROM dbo.bi bi
            WHERE bi.bostamp COLLATE DATABASE_DEFAULT = @bostamp COLLATE DATABASE_DEFAULT
              AND ISNULL(bi.u_qtdaut, 0) = 0
              AND (ISNULL(NULLIF(bi.u_qttorig, 0), bi.qtt) - bi.qtt2) > 0;
        END;
    END;

    UPDATE dbo.bo
    SET
        u_pickrdy = ISNULL(@pronta, 0),
        u_upickrdr = LEFT(LTRIM(RTRIM(@usrlogin)), 100),
        u_upickrdt = @agora,
        usrinis = @usrinis_n,
        usrdata = @usrdata,
        usrhora = @usrhora
    WHERE bostamp COLLATE DATABASE_DEFAULT = @bostamp COLLATE DATABASE_DEFAULT;

    COMMIT;

    SELECT
        bo.bostamp,
        CAST(ISNULL(bo.u_pickrdy, 0) AS bit) AS pronta_picking,
        LTRIM(RTRIM(bo.u_upickrdr)) AS pronta_picking_por,
        CASE
            WHEN YEAR(bo.u_upickrdt) < 1950 THEN CAST(NULL AS datetime)
            ELSE bo.u_upickrdt
        END AS pronta_picking_em
    FROM dbo.bo bo WITH (NOLOCK)
    WHERE bo.bostamp COLLATE DATABASE_DEFAULT = @bostamp COLLATE DATABASE_DEFAULT;
END;
GO
