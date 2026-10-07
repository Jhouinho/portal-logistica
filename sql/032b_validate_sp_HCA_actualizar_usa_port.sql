-- =============================================================================
-- Liliana & Seródio — Portal Logístico
-- Script: 032b_validate_sp_HCA_actualizar_usa_port.sql
-- Pré-requisito: 032_create_sp_HCA_actualizar_usa_port.sql
-- =============================================================================
-- Validação segura: email inexistente deve falhar com RAISERROR (sem alterar dados).
-- =============================================================================

SELECT OBJECT_ID(N'dbo.sp_HCA_actualizar_usa_port', N'P') AS sp_object_id;

BEGIN TRY
    EXEC dbo.sp_HCA_actualizar_usa_port
        @email = N'__nao_existe__@example.com',
        @usaPort = 0;
    PRINT N'ERRO: esperava falha para email inexistente.';
END TRY
BEGIN CATCH
    SELECT ERROR_NUMBER() AS error_number, ERROR_MESSAGE() AS error_message;
END CATCH;
GO
