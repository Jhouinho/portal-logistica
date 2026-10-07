-- =============================================================================
-- Liliana & Seródio — Portal Logístico
-- Script: 052_grant_picking_workflow_sps.sql
-- Ambiente: UAT / teste; Produção só no GO formal
-- =============================================================================
-- GRANT portal_app (quando o login existir no ambiente):
-- GRANT EXECUTE ON dbo.sp_HCA_picking_start TO [portal_app];
-- GRANT EXECUTE ON dbo.sp_HCA_picking_complete TO [portal_app];
-- GRANT EXECUTE ON dbo.sp_HCA_picking_cancel TO [portal_app];
-- GRANT EXECUTE ON dbo.sp_HCA_picking_back_to_ready TO [portal_app];
-- GRANT EXECUTE ON dbo.sp_HCA_picking_reopen TO [portal_app];
-- =============================================================================
GRANT EXECUTE ON dbo.sp_HCA_picking_start TO [portal_app];
GRANT EXECUTE ON dbo.sp_HCA_picking_complete TO [portal_app];
GRANT EXECUTE ON dbo.sp_HCA_picking_cancel TO [portal_app];
GRANT EXECUTE ON dbo.sp_HCA_picking_back_to_ready TO [portal_app];
GRANT EXECUTE ON dbo.sp_HCA_picking_reopen TO [portal_app];
GO
