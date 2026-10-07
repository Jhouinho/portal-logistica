-- =============================================================================
-- Liliana & Seródio — Portal Logístico
-- Script: 031_create_sp_HCA_listar_utilizadores_admin.sql
-- =============================================================================
-- Lista utilizadores US activos (com email) para Administração do portal.
-- =============================================================================

CREATE OR ALTER PROCEDURE dbo.sp_HCA_listar_utilizadores_admin
AS
BEGIN
    SET NOCOUNT ON;

    SELECT
        us.usstamp AS userstamp,
        LTRIM(RTRIM(us.usercode)) AS login,
        LTRIM(RTRIM(us.username)) AS nome,
        LTRIM(RTRIM(us.iniciais)) AS usrinis,
        LTRIM(RTRIM(us.email)) AS email,
        CAST(ISNULL(us.u_usaPort, 0) AS bit) AS usa_port
    FROM dbo.us us WITH (NOLOCK)
    WHERE ISNULL(us.inactivo, 0) = 0
      AND LTRIM(RTRIM(ISNULL(us.email, ''))) <> ''
    ORDER BY LTRIM(RTRIM(us.usercode));
END;
GO
