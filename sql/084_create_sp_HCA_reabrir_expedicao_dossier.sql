-- =============================================================================
-- Liliana & Seródio — Portal Logístico
-- Script: 084_create_sp_HCA_reabrir_expedicao_dossier.sql
-- Ambiente: UAT / teste; Produção só no GO formal
-- =============================================================================
-- Reabertura operacional de expedição (ndos=@serie_separacao, default 65):
--   BO.fechada = 0 e BI.fechada = 0 (todas as linhas do bostamp).
-- Mantém BO e BI consistentes após fecho operacional (083).
-- Não altera qtt/qtt2, não fatura, não cria documentos.
-- Exige documento fechado; se já aberto → erro (conflito).
-- NÃO altera sp_HCA_marcar_fecho_picking_dossier (048).
-- =============================================================================

CREATE OR ALTER PROCEDURE dbo.sp_HCA_reabrir_expedicao_dossier
    @bostamp           varchar(25),
    @serie_separacao   int = 65,
    @usrlogin          varchar(100) = NULL
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    IF @bostamp IS NULL OR LTRIM(RTRIM(@bostamp)) = ''
    BEGIN
        RAISERROR(N'bostamp obrigatório.', 16, 1);
        RETURN;
    END;

    IF @serie_separacao IS NULL OR @serie_separacao <= 0
    BEGIN
        RAISERROR(N'serie_separacao inválida.', 16, 1);
        RETURN;
    END;

    DECLARE @agora datetime = GETDATE(),
            @usrdata date,
            @usrhora varchar(8),
            @usrinis_n varchar(3),
            @ja_fechada bit;

    SET @usrdata = CAST(@agora AS date);
    SET @usrhora = CONVERT(varchar(8), @agora, 108);
    SET @usrinis_n = LEFT(LTRIM(RTRIM(ISNULL(NULLIF(@usrlogin, ''), 'PRT'))), 3);

    BEGIN TRAN;

    IF NOT EXISTS (
        SELECT 1
        FROM dbo.bo bo WITH (UPDLOCK, ROWLOCK)
        WHERE bo.bostamp COLLATE DATABASE_DEFAULT = @bostamp COLLATE DATABASE_DEFAULT
          AND bo.ndos = @serie_separacao
    )
    BEGIN
        ROLLBACK;
        RAISERROR(N'Dossier de expedição não encontrado ou série inválida.', 16, 1);
        RETURN;
    END;

    SELECT @ja_fechada = CAST(ISNULL(bo.fechada, 0) AS bit)
    FROM dbo.bo bo WITH (UPDLOCK, ROWLOCK)
    WHERE bo.bostamp COLLATE DATABASE_DEFAULT = @bostamp COLLATE DATABASE_DEFAULT
      AND bo.ndos = @serie_separacao;

    IF ISNULL(@ja_fechada, 0) = 0
    BEGIN
        ROLLBACK;
        RAISERROR(N'Expedição já aberta.', 16, 1);
        RETURN;
    END;

    UPDATE dbo.bo
    SET
        fechada = 0,
        usrinis = @usrinis_n,
        usrdata = @usrdata,
        usrhora = @usrhora
    WHERE bostamp COLLATE DATABASE_DEFAULT = @bostamp COLLATE DATABASE_DEFAULT
      AND ndos = @serie_separacao
      AND ISNULL(fechada, 0) = 1;

    IF @@ROWCOUNT <> 1
    BEGIN
        ROLLBACK;
        RAISERROR(N'Expedição já aberta.', 16, 1);
        RETURN;
    END;

    UPDATE dbo.bi
    SET
        fechada = 0,
        usrinis = @usrinis_n,
        usrdata = @usrdata,
        usrhora = @usrhora
    WHERE bostamp COLLATE DATABASE_DEFAULT = @bostamp COLLATE DATABASE_DEFAULT;

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
