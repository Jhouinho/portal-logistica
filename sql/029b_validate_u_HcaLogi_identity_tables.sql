-- =============================================================================
-- Liliana & Seródio — Portal Logístico
-- Script: 029b_validate_u_HcaLogi_identity_tables.sql
-- Pré-requisito: 029_create_u_HcaLogi_identity_tables.sql
-- =============================================================================

SELECT name
FROM sys.tables
WHERE name LIKE N'u_HcaLogi%'
ORDER BY name;

SELECT MigrationId, ProductVersion
FROM dbo.__EFMigrationsHistory
WHERE MigrationId = N'20260811092935_InitialIdentityHcaLogi';
GO
