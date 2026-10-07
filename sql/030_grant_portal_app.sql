-- =============================================================================
-- Liliana & Seródio — Portal Logístico
-- Script: 030_grant_portal_app.sql
-- Ambiente: UAT primeiro; Produção só no GO formal
-- =============================================================================
-- Substituir [portal_app] pelo nome do utilizador SQL da aplicação.
-- A aplicação NÃO deve ter SELECT/UPDATE directo em BO/BI/ST/CL/US.
-- =============================================================================

-- Exemplo de criação do login/user (ajustar servidor / password):
/*
USE [master];
CREATE LOGIN [portal_app] WITH PASSWORD = N'TROCAR_PASSWORD_FORTE', CHECK_POLICY = ON;

USE [NOME_BD_PHC_UAT];  -- substituir
CREATE USER [portal_app] FOR LOGIN [portal_app];
*/

-- Vistas (leitura)
GRANT SELECT ON dbo.view_HCA_utilizadores TO [portal_app];
GRANT SELECT ON dbo.view_HCA_encomendas_abertas TO [portal_app];
GRANT SELECT ON dbo.view_HCA_encomenda_linhas TO [portal_app];
GRANT SELECT ON dbo.view_HCA_rastreio_artigos TO [portal_app];
GRANT SELECT ON dbo.view_HCA_artigo_encomendas TO [portal_app];
GRANT SELECT ON dbo.view_HCA_cortes_quantidade TO [portal_app];

-- Procedimentos (execução)
GRANT EXECUTE ON dbo.sp_HCA_validar_login TO [portal_app];
GRANT EXECUTE ON dbo.sp_HCA_atualizar_linha_qtt_preco TO [portal_app];
GRANT EXECUTE ON dbo.sp_HCA_atualizar_qtd_autorizada TO [portal_app];
GRANT EXECUTE ON dbo.sp_HCA_alocacao_proporcional TO [portal_app];
GRANT EXECUTE ON dbo.sp_HCA_marcar_pronta_picking TO [portal_app];
GRANT EXECUTE ON dbo.sp_HCA_listar_utilizadores_admin TO [portal_app];
GRANT EXECUTE ON dbo.sp_HCA_actualizar_usa_port TO [portal_app];

-- Identity (EF) — mesma BD PHC
GRANT SELECT, INSERT, UPDATE, DELETE ON dbo.u_HcaLogiUsers TO [portal_app];
GRANT SELECT, INSERT, UPDATE, DELETE ON dbo.u_HcaLogiRoles TO [portal_app];
GRANT SELECT, INSERT, UPDATE, DELETE ON dbo.u_HcaLogiUserRoles TO [portal_app];
GRANT SELECT, INSERT, UPDATE, DELETE ON dbo.u_HcaLogiUserClaims TO [portal_app];
GRANT SELECT, INSERT, UPDATE, DELETE ON dbo.u_HcaLogiUserLogins TO [portal_app];
GRANT SELECT, INSERT, UPDATE, DELETE ON dbo.u_HcaLogiUserTokens TO [portal_app];
GRANT SELECT, INSERT, UPDATE, DELETE ON dbo.u_HcaLogiRoleClaims TO [portal_app];
GO
