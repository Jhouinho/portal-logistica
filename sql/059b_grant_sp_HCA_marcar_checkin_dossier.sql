-- =============================================================================
-- Liliana & Seródio — Portal Logístico
-- Script: 059b_grant_sp_HCA_marcar_checkin_dossier.sql
-- =============================================================================
IF NOT EXISTS (SELECT 1 FROM sys.database_principals WHERE name = N'portal_app')
    PRINT N'AVISO: user portal_app inexistente — saltar GRANT 059b.';
ELSE IF OBJECT_ID(N'dbo.sp_HCA_marcar_checkin_dossier', N'P') IS NULL
    PRINT N'AVISO: sp_HCA_marcar_checkin_dossier inexistente — saltar GRANT 059b.';
ELSE
BEGIN
    GRANT EXECUTE ON dbo.sp_HCA_marcar_checkin_dossier TO [portal_app];
    PRINT N'OK: GRANT 059b.';
END
GO
