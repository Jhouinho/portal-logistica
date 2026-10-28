-- =============================================================================
-- Liliana & Seródio — Pedidos Mobile staff: editar linhas (qtt/add/remove)
-- Script: 105_grant_delete_u_HcaPmPedidoLin.sql
-- Pré-requisito: 096b + 096c (+ 099 recomendado)
-- NÃO executar automaticamente pelo deploy — aplicar em UAT/SSMS.
--
-- Motivo: PUT /api/v1/staff/pedidos-mobile/{id}/linhas substitui o conjunto de
-- linhas com DELETE + INSERT. 096c/099 só concederam SELECT/INSERT/UPDATE.
-- Sem DELETE, o gravar falha com erro genérico 500 (SqlException 229).
-- =============================================================================

SET NOCOUNT ON;
GO

IF NOT EXISTS (SELECT 1 FROM sys.database_principals WHERE name = N'portal_app')
BEGIN
    PRINT N'AVISO: user portal_app inexistente — saltar GRANT 105.';
END
ELSE IF OBJECT_ID(N'dbo.u_HcaPmPedidoLin', N'U') IS NULL
BEGIN
    RAISERROR(N'u_HcaPmPedidoLin em falta — aplicar 096b primeiro.', 16, 1);
END
ELSE
BEGIN
    GRANT SELECT, INSERT, UPDATE, DELETE ON dbo.u_HcaPmPedidoLin TO [portal_app];
    PRINT N'OK: 105 — GRANT DELETE (e reafirma SELECT/INSERT/UPDATE) em u_HcaPmPedidoLin → portal_app.';
END
GO
