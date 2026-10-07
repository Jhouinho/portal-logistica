-- =============================================================================
-- Liliana & Seródio — Portal Logístico
-- Script: 021_validate_sp_HCA_validar_login.sql
-- Pré-requisito: 028 (u_usaPort) + 020 executados
-- =============================================================================

EXEC dbo.sp_HCA_validar_login @login = N'__nao_existe__';

DECLARE @login_piloto varchar(20) = N'sa';

EXEC dbo.sp_HCA_validar_login @login = @login_piloto;

SELECT *
FROM dbo.view_HCA_utilizadores
WHERE LOWER(login) = LOWER(LTRIM(RTRIM(@login_piloto)));
GO
