-- =============================================================================
-- Liliana & Seródio — Portal Logístico
-- Script: 058_create_sp_HCA_cancelar_encomenda.sql
-- Pré-requisito: BO3.u_pickcobs (varchar 254) no Framework + Atualizar a Tabela
-- =============================================================================
-- Cancela / fecha encomenda (ndos=1) ainda não enviada a picking:
--   BO.fechada = 1
--   BO3.u_pickcobs = motivo (obrigatório)
-- =============================================================================

CREATE OR ALTER PROCEDURE dbo.sp_HCA_cancelar_encomenda
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

    DECLARE @agora datetime = GETDATE(),
            @usrdata datetime,
            @usrhora varchar(8),
            @usrinis_n varchar(3),
            @motivo_n varchar(254),
            @pickrdy bit;

    SET @usrdata = CAST(@agora AS date);
    SET @usrhora = CONVERT(varchar(8), @agora, 108);
    SET @usrinis_n = LEFT(LTRIM(RTRIM(ISNULL(NULLIF(@usrinis, ''), @usrlogin))), 3);
    SET @motivo_n = LEFT(LTRIM(RTRIM(@motivo)), 254);

    BEGIN TRAN;

    IF NOT EXISTS (
        SELECT 1 FROM dbo.bo bo WITH (UPDLOCK, ROWLOCK)
        WHERE bo.bostamp COLLATE DATABASE_DEFAULT = @bostamp COLLATE DATABASE_DEFAULT
          AND bo.ndos = 1
          AND ISNULL(bo.fechada, 0) = 0)
    BEGIN
        ROLLBACK;
        RAISERROR(N'Encomenda não encontrada ou já fechada/série inválida.', 16, 1);
        RETURN;
    END;

    IF NOT EXISTS (
        SELECT 1 FROM dbo.bo3 WITH (UPDLOCK, ROWLOCK)
        WHERE bo3stamp COLLATE DATABASE_DEFAULT = @bostamp COLLATE DATABASE_DEFAULT
    )
        INSERT INTO dbo.bo3 (bo3stamp) VALUES (@bostamp);

    SELECT @pickrdy = CAST(ISNULL(u_pickrdy, 0) AS bit)
    FROM dbo.bo3 WITH (UPDLOCK, ROWLOCK)
    WHERE bo3stamp COLLATE DATABASE_DEFAULT = @bostamp COLLATE DATABASE_DEFAULT;

    IF ISNULL(@pickrdy, 0) = 1
    BEGIN
        ROLLBACK;
        RAISERROR(N'Não é possível cancelar: a encomenda já está em picking. Cancele o picking primeiro.', 16, 1);
        RETURN;
    END;

    UPDATE dbo.bo3
    SET u_pickcobs = @motivo_n
    WHERE bo3stamp COLLATE DATABASE_DEFAULT = @bostamp COLLATE DATABASE_DEFAULT;

    UPDATE dbo.bo
    SET
        fechada = 1,
        usrinis = @usrinis_n,
        usrdata = @usrdata,
        usrhora = @usrhora
    WHERE bostamp COLLATE DATABASE_DEFAULT = @bostamp COLLATE DATABASE_DEFAULT
      AND ndos = 1;

    COMMIT;

    SELECT
        bo.bostamp,
        CAST(ISNULL(bo.fechada, 0) AS bit) AS fechada,
        bo.obrano,
        LTRIM(RTRIM(ISNULL(bo3.u_pickcobs, ''))) AS motivo
    FROM dbo.bo bo WITH (NOLOCK)
    LEFT JOIN dbo.bo3 bo3 WITH (NOLOCK)
        ON bo3.bo3stamp COLLATE DATABASE_DEFAULT = bo.bostamp COLLATE DATABASE_DEFAULT
    WHERE bo.bostamp COLLATE DATABASE_DEFAULT = @bostamp COLLATE DATABASE_DEFAULT;
END;
GO
