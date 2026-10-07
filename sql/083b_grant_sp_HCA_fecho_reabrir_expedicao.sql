-- =============================================================================
-- Liliana & Seródio — Portal Logístico
-- Script: 083b_grant_sp_HCA_fecho_reabrir_expedicao.sql
-- =============================================================================
GRANT EXECUTE ON dbo.sp_HCA_fechar_expedicao_dossier TO [portal_app];
GO
GRANT EXECUTE ON dbo.sp_HCA_reabrir_expedicao_dossier TO [portal_app];
GO
