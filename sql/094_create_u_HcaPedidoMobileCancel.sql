-- =============================================================================
-- Liliana & Seródio — Portal Mobile
-- Script: 094_create_u_HcaPedidoMobileCancel.sql
-- Cancelamento de pedidos mobile sem DELETE em BO/BI.
-- =============================================================================

SET NOCOUNT ON;
SET XACT_ABORT ON;
GO

IF OBJECT_ID(N'dbo.u_HcaPedidoMobileCancel', N'U') IS NULL
BEGIN
    CREATE TABLE dbo.u_HcaPedidoMobileCancel
    (
        bostamp     char(25)       NOT NULL,
        ClNo        numeric(10, 0) NOT NULL,
        ClEstab     numeric(3, 0)  NOT NULL,
        CancelledAt datetime2(0)   NOT NULL
            CONSTRAINT DF_u_HcaPedidoMobileCancel_At DEFAULT (SYSUTCDATETIME()),
        Motivo      nvarchar(200)  NULL,
        CONSTRAINT PK_u_HcaPedidoMobileCancel PRIMARY KEY (bostamp)
    );

    CREATE INDEX IX_u_HcaPedidoMobileCancel_Cl
        ON dbo.u_HcaPedidoMobileCancel (ClNo, ClEstab, CancelledAt DESC);
END
GO

IF NOT EXISTS (SELECT 1 FROM sys.database_principals WHERE name = N'portal_app')
    PRINT N'AVISO: user portal_app inexistente — saltar GRANT 094.';
ELSE IF OBJECT_ID(N'dbo.u_HcaPedidoMobileCancel', N'U') IS NOT NULL
BEGIN
    GRANT SELECT, INSERT ON dbo.u_HcaPedidoMobileCancel TO [portal_app];
    PRINT N'OK: GRANT u_HcaPedidoMobileCancel → portal_app.';
END
GO
