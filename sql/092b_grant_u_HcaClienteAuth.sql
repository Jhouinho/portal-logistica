-- =============================================================================
-- Script: 092b_grant_u_HcaClienteAuth.sql
-- =============================================================================
IF NOT EXISTS (SELECT 1 FROM sys.database_principals WHERE name = N'portal_app')
    PRINT N'AVISO: user portal_app inexistente — saltar GRANTs 092b.';
ELSE IF OBJECT_ID(N'dbo.u_HcaClienteAuth', N'U') IS NOT NULL
BEGIN
    GRANT SELECT, INSERT, UPDATE, DELETE ON dbo.u_HcaClienteAuth TO [portal_app];
    PRINT N'OK: GRANT u_HcaClienteAuth → portal_app.';
END
ELSE
    PRINT N'AVISO: u_HcaClienteAuth inexistente.';
GO
