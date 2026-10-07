-- =============================================================================
-- Liliana & Seródio — Portal Logístico
-- Script: 031b_validate_sp_HCA_listar_utilizadores_admin.sql
-- Pré-requisito: 031_create_sp_HCA_listar_utilizadores_admin.sql
-- =============================================================================

SELECT OBJECT_ID(N'dbo.sp_HCA_listar_utilizadores_admin', N'P') AS sp_object_id;

EXEC dbo.sp_HCA_listar_utilizadores_admin;
GO
