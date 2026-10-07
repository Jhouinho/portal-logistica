-- =============================================================================
-- Liliana & Seródio — Portal Logístico
-- Script: 059_create_sp_HCA_marcar_checkin_dossier.sql
-- Ambiente: UAT / teste; Produção só no GO formal
-- =============================================================================
-- Pré-requisito (Framework PHC → Atualizar a Tabela):
--   BO3.u_chkin   (Lógico / bit)     — Check-in realizado
--   BO3.u_chkinur (Carácter 100)     — Quem fez o Check-in
--   BO3.u_chkindt (Data / datetime)  — Quando
--
-- Marca Check-in em dossier ndos=@serie_picking (default 66):
--   @checkin = 1 → u_chkin=1, ur, dt  (só se ainda u_chkin=0)
--   @checkin = 0 → limpa check-in (desfazer)
-- Não altera u_pickstat nem BO.fechada.
-- =============================================================================

CREATE OR ALTER PROCEDURE dbo.sp_HCA_marcar_checkin_dossier
    @bostamp         varchar(25),
    @checkin         bit,
    @serie_picking   int = 66,
    @usrlogin        varchar(100),
    @usrinis         varchar(3) = NULL
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    IF @bostamp IS NULL OR LTRIM(RTRIM(@bostamp)) = ''
    BEGIN RAISERROR(N'bostamp obrigatório.', 16, 1); RETURN; END;
    IF @usrlogin IS NULL OR LTRIM(RTRIM(@usrlogin)) = ''
    BEGIN RAISERROR(N'usrlogin obrigatório.', 16, 1); RETURN; END;
    IF @serie_picking IS NULL OR @serie_picking <= 0
    BEGIN RAISERROR(N'serie_picking inválida.', 16, 1); RETURN; END;

    DECLARE @agora datetime = GETDATE(),
            @usrdata datetime,
            @usrhora varchar(8),
            @usrinis_n varchar(3),
            @ja_checkin bit;

    SET @usrdata = CAST(@agora AS date);
    SET @usrhora = CONVERT(varchar(8), @agora, 108);
    SET @usrinis_n = LEFT(LTRIM(RTRIM(ISNULL(NULLIF(@usrinis, ''), @usrlogin))), 3);

    BEGIN TRAN;

    IF NOT EXISTS (
        SELECT 1 FROM dbo.bo bo WITH (UPDLOCK, ROWLOCK)
        WHERE bo.bostamp COLLATE DATABASE_DEFAULT = @bostamp COLLATE DATABASE_DEFAULT
          AND bo.ndos = @serie_picking
          AND ISNULL(bo.fechada, 0) = 0)
    BEGIN
        ROLLBACK;
        RAISERROR(N'Dossier não encontrado, fechado ou fora da série configurada.', 16, 1);
        RETURN;
    END;

    IF NOT EXISTS (
        SELECT 1 FROM dbo.bo3 WITH (UPDLOCK, ROWLOCK)
        WHERE bo3stamp COLLATE DATABASE_DEFAULT = @bostamp COLLATE DATABASE_DEFAULT)
        INSERT INTO dbo.bo3 (bo3stamp) VALUES (@bostamp);

    SELECT @ja_checkin = CAST(ISNULL(u_chkin, 0) AS bit)
    FROM dbo.bo3 WITH (UPDLOCK, ROWLOCK)
    WHERE bo3stamp COLLATE DATABASE_DEFAULT = @bostamp COLLATE DATABASE_DEFAULT;

    IF ISNULL(@checkin, 0) = 1
    BEGIN
        IF ISNULL(@ja_checkin, 0) = 1
        BEGIN
            ROLLBACK;
            RAISERROR(N'Check-in já realizado neste dossier.', 16, 1);
            RETURN;
        END;

        UPDATE dbo.bo3
        SET u_chkin = 1,
            u_chkinur = LEFT(LTRIM(RTRIM(@usrlogin)), 100),
            u_chkindt = @agora
        WHERE bo3stamp COLLATE DATABASE_DEFAULT = @bostamp COLLATE DATABASE_DEFAULT;
    END
    ELSE
    BEGIN
        UPDATE dbo.bo3
        SET u_chkin = 0,
            u_chkinur = '',
            u_chkindt = CAST('19000101' AS datetime)
        WHERE bo3stamp COLLATE DATABASE_DEFAULT = @bostamp COLLATE DATABASE_DEFAULT;
    END;

    UPDATE dbo.bo
    SET usrinis = @usrinis_n, usrdata = @usrdata, usrhora = @usrhora
    WHERE bostamp COLLATE DATABASE_DEFAULT = @bostamp COLLATE DATABASE_DEFAULT;

    COMMIT;

    SELECT
        bo.bostamp,
        CAST(ISNULL(bo3.u_chkin, 0) AS bit) AS check_in,
        LTRIM(RTRIM(ISNULL(bo3.u_chkinur, ''))) AS check_in_por,
        CASE
            WHEN bo3.u_chkindt IS NULL OR YEAR(bo3.u_chkindt) < 1950 THEN CAST(NULL AS datetime)
            ELSE bo3.u_chkindt
        END AS check_in_em,
        CAST(bo.obrano AS int) AS obrano,
        bo.ndos
    FROM dbo.bo bo WITH (NOLOCK)
    LEFT JOIN dbo.bo3 bo3 WITH (NOLOCK)
        ON bo3.bo3stamp COLLATE DATABASE_DEFAULT = bo.bostamp COLLATE DATABASE_DEFAULT
    WHERE bo.bostamp COLLATE DATABASE_DEFAULT = @bostamp COLLATE DATABASE_DEFAULT;
END;
GO
