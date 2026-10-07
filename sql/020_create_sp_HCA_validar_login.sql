-- =============================================================================
-- Liliana & Seródio — Portal Logístico
-- Script: 020_create_sp_HCA_validar_login.sql
-- Ambiente: UAT / teste; Produção só no GO formal
-- =============================================================================
-- Exceção técnica (não é escrita de negócio):
--   Devolve dados mínimos de US activo com u_usaPort = 1.
--   Login do portal = US.usercode; email serve para ligar ao Identity.
-- =============================================================================

CREATE OR ALTER PROCEDURE dbo.sp_HCA_validar_login
    @login varchar(20)
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    IF @login IS NULL OR LTRIM(RTRIM(@login)) = ''
    BEGIN
        RAISERROR(N'Login (usercode) obrigatório.', 16, 1);
        RETURN;
    END;

    SELECT
        us.usstamp AS userstamp,
        LTRIM(RTRIM(us.usercode)) AS login,
        LTRIM(RTRIM(us.username)) AS nome,
        LTRIM(RTRIM(us.iniciais)) AS usrinis,
        LTRIM(RTRIM(us.email)) AS email,
        us.u_portalph AS portal_hash
    FROM dbo.us us WITH (NOLOCK)
    WHERE LOWER(LTRIM(RTRIM(us.usercode))) = LOWER(LTRIM(RTRIM(@login)))
      AND ISNULL(us.inactivo, 0) = 0
      AND us.u_usaPort = 1
      AND LTRIM(RTRIM(ISNULL(us.email, ''))) <> '';
END;
GO
