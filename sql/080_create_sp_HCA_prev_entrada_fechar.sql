-- =============================================================================
-- Liliana & Seródio — Portal Logístico
-- Script: 080_create_sp_HCA_prev_entrada_fechar.sql
-- Ambiente: UAT primeiro; Produção só no GO formal
-- Pré-requisito: 064 (Fechada); 076 (obter)
-- =============================================================================
-- Fecho simples da previsão aberta (sem transferência de u_prevId).
-- Autorizações já associadas mantêm u_prevId; novas autorizações passam
-- a exigir outra previsão aberta.
-- =============================================================================

SET NOCOUNT ON;
GO

SET ANSI_NULLS ON;
SET QUOTED_IDENTIFIER ON;
GO

CREATE OR ALTER PROCEDURE dbo.sp_HCA_prev_entrada_fechar
    @id       uniqueidentifier,
    @usrlogin nvarchar(100)
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    BEGIN TRAN;

    DECLARE @fechada bit;

    SELECT @fechada = Fechada
    FROM dbo.u_HcaPrevEntrada WITH (UPDLOCK, ROWLOCK)
    WHERE Id = @id;

    IF @fechada IS NULL
    BEGIN
        ROLLBACK;
        RAISERROR(N'Previsão não encontrada.', 16, 1);
        RETURN;
    END;

    IF @fechada = 1
    BEGIN
        ROLLBACK;
        RAISERROR(N'A previsão já está fechada.', 16, 1);
        RETURN;
    END;

    UPDATE dbo.u_HcaPrevEntrada
    SET Fechada = 1,
        FechadaEm = SYSUTCDATETIME(),
        FechadaPor = LEFT(LTRIM(RTRIM(ISNULL(@usrlogin, N''))), 100),
        AlteradoEm = SYSUTCDATETIME(),
        AlteradoPor = LEFT(LTRIM(RTRIM(ISNULL(@usrlogin, N''))), 100)
    WHERE Id = @id;

    COMMIT TRAN;

    EXEC dbo.sp_HCA_prev_entrada_obter @id = @id;
END;
GO

IF EXISTS (SELECT 1 FROM sys.database_principals WHERE name = N'portal_app')
    GRANT EXECUTE ON dbo.sp_HCA_prev_entrada_fechar TO [portal_app];
GO
