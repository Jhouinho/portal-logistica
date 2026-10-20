-- =============================================================================
-- Liliana & Seródio — Portal Mobile Fase 1
-- Script: 096c_grant_u_HcaPmPedido.sql
-- Pré-requisito: 096 + 096b
-- =============================================================================

SET NOCOUNT ON;
GO

IF NOT EXISTS (SELECT 1 FROM sys.database_principals WHERE name = N'portal_app')
    PRINT N'AVISO: user portal_app inexistente — saltar GRANTs 096c.';
ELSE
BEGIN
    IF OBJECT_ID(N'dbo.u_HcaPmPedido', N'U') IS NOT NULL
        GRANT SELECT, INSERT, UPDATE ON dbo.u_HcaPmPedido TO [portal_app];

    IF OBJECT_ID(N'dbo.u_HcaPmPedidoLin', N'U') IS NOT NULL
        GRANT SELECT, INSERT ON dbo.u_HcaPmPedidoLin TO [portal_app];

    PRINT N'OK: GRANTs 096c u_HcaPmPedido / Lin → portal_app (quando objectos existem).';
END
GO
