-- =============================================================================
-- Liliana & Seródio — Pedidos Mobile staff (aprovação / rejeição)
-- Script: 098_alter_u_HcaPmPedido_decisao_staff.sql
-- Pré-requisito: 096_create_u_HcaPmPedido.sql
-- Idempotente. Não DROP. Não executar automaticamente pelo deploy — aplicar em UAT/SSMS.
--
-- Finalidade:
--   - MotivoRejeicao / DecididoPor / DataDecisao para rejeição e auditoria de decisão
--   - Índice de suporte à lista staff de pendentes
-- =============================================================================

SET NOCOUNT ON;
SET XACT_ABORT ON;
GO

IF OBJECT_ID(N'dbo.u_HcaPmPedido', N'U') IS NULL
BEGIN
    RAISERROR(N'u_HcaPmPedido em falta — aplicar 096 primeiro.', 16, 1);
    RETURN;
END
GO

IF COL_LENGTH(N'dbo.u_HcaPmPedido', N'MotivoRejeicao') IS NULL
BEGIN
    ALTER TABLE dbo.u_HcaPmPedido
        ADD MotivoRejeicao nvarchar(500) NULL;
END
GO

IF COL_LENGTH(N'dbo.u_HcaPmPedido', N'DecididoPor') IS NULL
BEGIN
    ALTER TABLE dbo.u_HcaPmPedido
        ADD DecididoPor varchar(16) NULL;
END
GO

IF COL_LENGTH(N'dbo.u_HcaPmPedido', N'DataDecisao') IS NULL
BEGIN
    ALTER TABLE dbo.u_HcaPmPedido
        ADD DataDecisao datetime2(0) NULL;
END
GO

IF NOT EXISTS (
    SELECT 1 FROM sys.indexes
    WHERE name = N'IX_u_HcaPmPedido_Estado_Data'
      AND object_id = OBJECT_ID(N'dbo.u_HcaPmPedido')
)
BEGIN
    CREATE INDEX IX_u_HcaPmPedido_Estado_Data
        ON dbo.u_HcaPmPedido (EstadoInterno, DataSubmissao DESC)
        INCLUDE (NumeroInterno, ClNo, ClEstab, Bostamp, Etotaldeb);
END
GO

PRINT N'OK: 098 — colunas de decisão staff em u_HcaPmPedido.';
GO
