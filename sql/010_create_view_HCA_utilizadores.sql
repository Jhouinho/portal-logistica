-- =============================================================================
-- Liliana & Seródio — Portal Logístico
-- Script: 010_create_view_HCA_utilizadores.sql
-- Ambiente: UAT primeiro; repetir o mesmo script em Produção
-- =============================================================================
-- Objetivo:
--   Vista de leitura com dados mínimos de US para o portal.
--   Acesso: utilizadores activos com u_usaPort = 1.
-- =============================================================================

CREATE OR ALTER VIEW dbo.view_HCA_utilizadores
AS
SELECT
    us.usstamp AS userstamp,
    LTRIM(RTRIM(us.usercode)) AS login,
    LTRIM(RTRIM(us.username)) AS nome,
    LTRIM(RTRIM(us.iniciais)) AS usrinis,
    LTRIM(RTRIM(us.email)) AS email,
    us.u_portalph AS portal_hash
FROM dbo.us us WITH (NOLOCK)
WHERE ISNULL(us.inactivo, 0) = 0
  AND us.u_usaPort = 1;
GO
