-- =============================================================================
-- Liliana & Seródio — Pedidos Mobile staff: preço submetido vs operador
-- Script: 099_alter_u_HcaPmPedidoLin_preco_submissao.sql
-- Pré-requisito: 096b_create_u_HcaPmPedidoLin.sql
-- NÃO executar automaticamente pelo deploy — aplicar em UAT/SSMS.
--
-- Semântica:
--   PrecoSubmissao = preço calculado no servidor na submissão (imutável)
--   PrecoUnitario  = preço de trabalho do operador staff (editável se pendente)
--   TotalLinha     = Qtt * PrecoUnitario
-- =============================================================================

SET NOCOUNT ON;
SET XACT_ABORT ON;
GO

IF OBJECT_ID(N'dbo.u_HcaPmPedidoLin', N'U') IS NULL
BEGIN
    RAISERROR(N'u_HcaPmPedidoLin em falta — aplicar 096b primeiro.', 16, 1);
    RETURN;
END
GO

IF COL_LENGTH(N'dbo.u_HcaPmPedidoLin', N'PrecoSubmissao') IS NULL
BEGIN
    ALTER TABLE dbo.u_HcaPmPedidoLin
        ADD PrecoSubmissao numeric(19, 6) NULL;
END
GO

UPDATE dbo.u_HcaPmPedidoLin
SET PrecoSubmissao = PrecoUnitario
WHERE PrecoSubmissao IS NULL;
GO

IF EXISTS (SELECT 1 FROM sys.database_principals WHERE name = N'portal_app')
   AND OBJECT_ID(N'dbo.u_HcaPmPedidoLin', N'U') IS NOT NULL
BEGIN
    GRANT SELECT, INSERT, UPDATE ON dbo.u_HcaPmPedidoLin TO [portal_app];
END
GO

PRINT N'OK: 099 — PrecoSubmissao em u_HcaPmPedidoLin (+ GRANT UPDATE portal_app).';
GO
