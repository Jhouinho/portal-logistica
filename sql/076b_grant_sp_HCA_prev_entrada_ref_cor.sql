-- =============================================================================
-- Liliana & Seródio — Portal Logístico
-- Script: 076b_grant_sp_HCA_prev_entrada_ref_cor.sql
-- =============================================================================

SET NOCOUNT ON;

IF EXISTS (SELECT 1 FROM sys.database_principals WHERE name = N'portal_app')
BEGIN
    GRANT EXECUTE ON dbo.sp_HCA_prev_entrada_obter TO [portal_app];
    GRANT EXECUTE ON dbo.sp_HCA_prev_entrada_guardar TO [portal_app];
    GRANT EXECUTE ON dbo.sp_HCA_prev_entrada_sugerir_cores TO [portal_app];
    GRANT EXECUTE ON dbo.sp_HCA_atualizar_qtd_autorizada TO [portal_app];
    GRANT EXECUTE ON dbo.sp_HCA_alocacao_proporcional TO [portal_app];
END;
GO
