-- =============================================================================
-- Liliana & Seródio — Portal Logístico
-- Script: 030_grant_portal_app.sql
-- Ambiente: UAT primeiro; Produção só no GO formal
-- =============================================================================
-- Pré-requisito: sql/000_criar_login_portal_app.sql (login/user portal_app).
-- No pack BI2/BO3 este script corre no FIM (depois de criar vistas/SPs).
-- =============================================================================

IF NOT EXISTS (SELECT 1 FROM sys.database_principals WHERE name = N'portal_app')
BEGIN
    PRINT N'AVISO: user portal_app inexistente — saltar GRANTs. Correr 000_criar_login_portal_app.sql e reexecutar este script.';
END
ELSE
BEGIN
    IF OBJECT_ID(N'dbo.view_HCA_utilizadores', N'V') IS NOT NULL
        GRANT SELECT ON dbo.view_HCA_utilizadores TO [portal_app];
    IF OBJECT_ID(N'dbo.view_HCA_encomendas_abertas', N'V') IS NOT NULL
        GRANT SELECT ON dbo.view_HCA_encomendas_abertas TO [portal_app];
    IF OBJECT_ID(N'dbo.view_HCA_encomenda_linhas', N'V') IS NOT NULL
        GRANT SELECT ON dbo.view_HCA_encomenda_linhas TO [portal_app];
    IF OBJECT_ID(N'dbo.view_HCA_rastreio_artigos', N'V') IS NOT NULL
        GRANT SELECT ON dbo.view_HCA_rastreio_artigos TO [portal_app];
    IF OBJECT_ID(N'dbo.view_HCA_artigo_encomendas', N'V') IS NOT NULL
        GRANT SELECT ON dbo.view_HCA_artigo_encomendas TO [portal_app];
    IF OBJECT_ID(N'dbo.view_HCA_cortes_quantidade', N'V') IS NOT NULL
        GRANT SELECT ON dbo.view_HCA_cortes_quantidade TO [portal_app];

    IF OBJECT_ID(N'dbo.sp_HCA_validar_login', N'P') IS NOT NULL
        GRANT EXECUTE ON dbo.sp_HCA_validar_login TO [portal_app];
    IF OBJECT_ID(N'dbo.sp_HCA_atualizar_linha_qtt_preco', N'P') IS NOT NULL
        GRANT EXECUTE ON dbo.sp_HCA_atualizar_linha_qtt_preco TO [portal_app];
    IF OBJECT_ID(N'dbo.sp_HCA_atualizar_qtd_autorizada', N'P') IS NOT NULL
        GRANT EXECUTE ON dbo.sp_HCA_atualizar_qtd_autorizada TO [portal_app];
    IF OBJECT_ID(N'dbo.sp_HCA_alocacao_proporcional', N'P') IS NOT NULL
        GRANT EXECUTE ON dbo.sp_HCA_alocacao_proporcional TO [portal_app];
    IF OBJECT_ID(N'dbo.sp_HCA_marcar_pronta_picking', N'P') IS NOT NULL
        GRANT EXECUTE ON dbo.sp_HCA_marcar_pronta_picking TO [portal_app];
    IF OBJECT_ID(N'dbo.sp_HCA_listar_utilizadores_admin', N'P') IS NOT NULL
        GRANT EXECUTE ON dbo.sp_HCA_listar_utilizadores_admin TO [portal_app];
    IF OBJECT_ID(N'dbo.sp_HCA_actualizar_usa_port', N'P') IS NOT NULL
        GRANT EXECUTE ON dbo.sp_HCA_actualizar_usa_port TO [portal_app];

    IF OBJECT_ID(N'dbo.u_HcaLogiUsers', N'U') IS NOT NULL
    BEGIN
        GRANT SELECT, INSERT, UPDATE, DELETE ON dbo.u_HcaLogiUsers TO [portal_app];
        GRANT SELECT, INSERT, UPDATE, DELETE ON dbo.u_HcaLogiRoles TO [portal_app];
        GRANT SELECT, INSERT, UPDATE, DELETE ON dbo.u_HcaLogiUserRoles TO [portal_app];
        GRANT SELECT, INSERT, UPDATE, DELETE ON dbo.u_HcaLogiUserClaims TO [portal_app];
        GRANT SELECT, INSERT, UPDATE, DELETE ON dbo.u_HcaLogiUserLogins TO [portal_app];
        GRANT SELECT, INSERT, UPDATE, DELETE ON dbo.u_HcaLogiUserTokens TO [portal_app];
        GRANT SELECT, INSERT, UPDATE, DELETE ON dbo.u_HcaLogiRoleClaims TO [portal_app];
    END

    PRINT N'OK: GRANTs portal_app (030).';
END
GO
