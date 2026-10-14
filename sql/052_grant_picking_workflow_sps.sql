-- =============================================================================
-- Liliana & Seródio — Portal Logístico
-- Script: 052_grant_picking_workflow_sps.sql
-- =============================================================================
IF NOT EXISTS (SELECT 1 FROM sys.database_principals WHERE name = N'portal_app')
    PRINT N'AVISO: user portal_app inexistente — saltar GRANTs 052.';
ELSE
BEGIN
    IF OBJECT_ID(N'dbo.sp_HCA_picking_start', N'P') IS NOT NULL
        GRANT EXECUTE ON dbo.sp_HCA_picking_start TO [portal_app];
    IF OBJECT_ID(N'dbo.sp_HCA_picking_complete', N'P') IS NOT NULL
        GRANT EXECUTE ON dbo.sp_HCA_picking_complete TO [portal_app];
    IF OBJECT_ID(N'dbo.sp_HCA_picking_cancel', N'P') IS NOT NULL
        GRANT EXECUTE ON dbo.sp_HCA_picking_cancel TO [portal_app];
    IF OBJECT_ID(N'dbo.sp_HCA_picking_back_to_ready', N'P') IS NOT NULL
        GRANT EXECUTE ON dbo.sp_HCA_picking_back_to_ready TO [portal_app];
    IF OBJECT_ID(N'dbo.sp_HCA_picking_reopen', N'P') IS NOT NULL
        GRANT EXECUTE ON dbo.sp_HCA_picking_reopen TO [portal_app];
    PRINT N'OK: GRANTs picking workflow (052).';
END
GO
