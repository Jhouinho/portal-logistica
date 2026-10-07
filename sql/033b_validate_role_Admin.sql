-- =============================================================================
-- Liliana & Seródio — Portal Logístico
-- Script: 033b_validate_role_Admin.sql
-- Pré-requisito: 033_seed_role_Admin.sql (ou seed da API)
-- =============================================================================

SELECT Id, Name, NormalizedName
FROM dbo.u_HcaLogiRoles
WHERE NormalizedName = N'ADMIN';

SELECT
    u.Email,
    u.Usercode,
    r.Name AS role_name
FROM dbo.u_HcaLogiUserRoles ur
INNER JOIN dbo.u_HcaLogiUsers u ON u.Id = ur.UserId
INNER JOIN dbo.u_HcaLogiRoles r ON r.Id = ur.RoleId
WHERE r.NormalizedName = N'ADMIN'
ORDER BY u.Email;
GO
