-- =============================================================================
-- Liliana & Seródio — Portal Logístico
-- Script: 063b_grant_sp_HCA_previsoes_entrada.sql
-- =============================================================================
-- Substituir [portal_app] se o login da app tiver outro nome.
-- Em UAT com sa, este script pode falhar se portal_app não existir — é opcional.
-- =============================================================================

IF EXISTS (SELECT 1 FROM sys.database_principals WHERE name = N'portal_app')
BEGIN
    GRANT SELECT, INSERT, UPDATE, DELETE ON dbo.u_HcaPrevEntrada TO [portal_app];
    GRANT SELECT, INSERT, UPDATE, DELETE ON dbo.u_HcaPrevEntradaLin TO [portal_app];
    GRANT EXECUTE ON dbo.sp_HCA_prev_entrada_listar TO [portal_app];
    GRANT EXECUTE ON dbo.sp_HCA_prev_entrada_obter TO [portal_app];
    GRANT EXECUTE ON dbo.sp_HCA_prev_entrada_criar TO [portal_app];
    GRANT EXECUTE ON dbo.sp_HCA_prev_entrada_guardar TO [portal_app];
    GRANT EXECUTE ON dbo.sp_HCA_prev_entrada_sugerir_artigos TO [portal_app];
END;
GO
