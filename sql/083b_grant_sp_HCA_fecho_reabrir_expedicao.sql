-- =============================================================================
-- Liliana & Seródio — Portal Logístico
-- Script: 083b_grant_sp_HCA_fecho_reabrir_expedicao.sql
-- =============================================================================
IF NOT EXISTS (SELECT 1 FROM sys.database_principals WHERE name = N'portal_app')
    PRINT N'AVISO: user portal_app inexistente — saltar GRANTs 083b.';
ELSE
BEGIN
    IF OBJECT_ID(N'dbo.sp_HCA_fechar_expedicao_dossier', N'P') IS NOT NULL
        GRANT EXECUTE ON dbo.sp_HCA_fechar_expedicao_dossier TO [portal_app];
    ELSE
        PRINT N'AVISO: sp_HCA_fechar_expedicao_dossier inexistente.';

    IF OBJECT_ID(N'dbo.sp_HCA_reabrir_expedicao_dossier', N'P') IS NOT NULL
        GRANT EXECUTE ON dbo.sp_HCA_reabrir_expedicao_dossier TO [portal_app];
    ELSE
        PRINT N'AVISO: sp_HCA_reabrir_expedicao_dossier inexistente.';

    PRINT N'OK: GRANTs 083b (quando objectos existem).';
END
GO
