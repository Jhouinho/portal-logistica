-- =============================================================================
-- Liliana & Seródio — Portal Logístico
-- Script: 037b_add_bo_u_upickrdt_if_missing.sql
-- Fallback se o Framework não tiver criado u_upickrdt (nomes físicos oficiais).
-- Preferir criar via Supervisor → Framework PHC + Atualizar a Tabela.
-- =============================================================================

IF COL_LENGTH('dbo.bo', 'u_upickrdt') IS NULL
BEGIN
    ALTER TABLE dbo.bo ADD u_upickrdt datetime NOT NULL
        CONSTRAINT DF_bo_u_upickrdt DEFAULT ('19000101');
END
GO
