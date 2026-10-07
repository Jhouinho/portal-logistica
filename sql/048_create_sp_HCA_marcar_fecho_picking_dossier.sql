-- =============================================================================
-- Liliana & Seródio — Portal Logístico
-- Script: 048_create_sp_HCA_marcar_fecho_picking_dossier.sql
-- Ambiente: UAT / teste; Produção só no GO formal
-- =============================================================================
-- Fecha / reabre dossier de picking (ndos = @serie_picking): só actualiza BO.fechada.
-- =============================================================================

CREATE OR ALTER PROCEDURE dbo.sp_HCA_marcar_fecho_picking_dossier
    @bostamp         varchar(25),
    @fechada         bit,
    @serie_picking   int = 66,
    @usrlogin        varchar(100) = NULL
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    IF @bostamp IS NULL OR LTRIM(RTRIM(@bostamp)) = ''
    BEGIN
        RAISERROR(N'bostamp obrigatório.', 16, 1);
        RETURN;
    END;

    IF @serie_picking IS NULL OR @serie_picking <= 0
    BEGIN
        RAISERROR(N'serie_picking inválida.', 16, 1);
        RETURN;
    END;

    BEGIN TRAN;

    IF NOT EXISTS (
        SELECT 1
        FROM dbo.bo bo WITH (UPDLOCK, ROWLOCK)
        WHERE bo.bostamp COLLATE DATABASE_DEFAULT = @bostamp COLLATE DATABASE_DEFAULT
          AND bo.ndos = @serie_picking
    )
    BEGIN
        ROLLBACK;
        RAISERROR(N'Dossier de picking não encontrado ou série inválida.', 16, 1);
        RETURN;
    END;

    UPDATE dbo.bo
    SET
        fechada = ISNULL(@fechada, 0),
        usrinis = LEFT(LTRIM(RTRIM(ISNULL(NULLIF(@usrlogin, ''), usrinis))), 3),
        usrdata = CAST(GETDATE() AS date),
        usrhora = CONVERT(varchar(8), GETDATE(), 108)
    WHERE bostamp COLLATE DATABASE_DEFAULT = @bostamp COLLATE DATABASE_DEFAULT
      AND ndos = @serie_picking;

    COMMIT;

    SELECT
        bo.bostamp,
        CAST(ISNULL(bo.fechada, 0) AS bit) AS fechada,
        bo.obrano,
        bo.ndos
    FROM dbo.bo bo WITH (NOLOCK)
    WHERE bo.bostamp COLLATE DATABASE_DEFAULT = @bostamp COLLATE DATABASE_DEFAULT;
END;
GO
