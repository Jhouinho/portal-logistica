-- =============================================================================
-- Criar login/user SQL da aplicação (correr ANTES dos grants).
-- Ajustar: nome da BD, password, e o nome do user se não for portal_app.
-- =============================================================================

USE [master];
GO

IF NOT EXISTS (SELECT 1 FROM sys.server_principals WHERE name = N'portal_app')
BEGIN
    CREATE LOGIN [portal_app] WITH PASSWORD = N'TROCAR_PASSWORD_FORTE', CHECK_POLICY = ON;
END
GO

-- >>> SUBSTITUIR pelo nome real da BD PHC do cliente <<<
USE [NOME_BD_PHC];
GO

IF NOT EXISTS (SELECT 1 FROM sys.database_principals WHERE name = N'portal_app')
BEGIN
    CREATE USER [portal_app] FOR LOGIN [portal_app];
END
GO

PRINT N'OK: login/user portal_app (confirma password e nome da BD).';
GO
