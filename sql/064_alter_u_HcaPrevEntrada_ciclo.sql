-- =============================================================================
-- Liliana & Seródio — Portal Logístico
-- Script: 064_alter_u_HcaPrevEntrada_ciclo.sql
-- Ambiente: UAT primeiro; Produção só no GO formal
-- Pré-requisito: 062_create_u_HcaPrevEntrada_tables.sql
-- =============================================================================
-- PR1 — Infraestrutura do ciclo:
--   Fechada / FechadaEm / FechadaPor
--   Remove unique exacto (DataInicio, DataFim); overlap validado nas SPs
-- Não altera u_HcaPrevEntradaLin, BI2, ST.stock nem SPs de autorização.
--
-- Cutover: após este script, todas as previsões existentes ficam Fechada=0.
-- Se existirem várias, a criação de novas falha até restar no máximo uma aberta
-- (fechar as restantes manualmente em SQL com Fechada=1 — o fecho assistido é PR3).
-- =============================================================================

SET NOCOUNT ON;
SET XACT_ABORT ON;

IF COL_LENGTH(N'dbo.u_HcaPrevEntrada', N'Fechada') IS NULL
BEGIN
    ALTER TABLE dbo.u_HcaPrevEntrada
        ADD Fechada bit NOT NULL
            CONSTRAINT DF_u_HcaPrevEntrada_Fechada DEFAULT (0);
END;
GO

IF COL_LENGTH(N'dbo.u_HcaPrevEntrada', N'FechadaEm') IS NULL
BEGIN
    ALTER TABLE dbo.u_HcaPrevEntrada
        ADD FechadaEm datetime2(0) NULL;
END;
GO

IF COL_LENGTH(N'dbo.u_HcaPrevEntrada', N'FechadaPor') IS NULL
BEGIN
    ALTER TABLE dbo.u_HcaPrevEntrada
        ADD FechadaPor nvarchar(100) NULL;
END;
GO

IF EXISTS (
    SELECT 1
    FROM sys.indexes
    WHERE name = N'UQ_u_HcaPrevEntrada_Periodo'
      AND object_id = OBJECT_ID(N'dbo.u_HcaPrevEntrada')
)
BEGIN
    ALTER TABLE dbo.u_HcaPrevEntrada
        DROP CONSTRAINT UQ_u_HcaPrevEntrada_Periodo;
END;
GO

IF NOT EXISTS (
    SELECT 1
    FROM sys.indexes
    WHERE name = N'IX_u_HcaPrevEntrada_Periodo'
      AND object_id = OBJECT_ID(N'dbo.u_HcaPrevEntrada')
)
BEGIN
    CREATE INDEX IX_u_HcaPrevEntrada_Periodo
        ON dbo.u_HcaPrevEntrada (DataInicio, DataFim);
END;
GO

IF NOT EXISTS (
    SELECT 1
    FROM sys.indexes
    WHERE name = N'IX_u_HcaPrevEntrada_Fechada'
      AND object_id = OBJECT_ID(N'dbo.u_HcaPrevEntrada')
)
BEGIN
    CREATE INDEX IX_u_HcaPrevEntrada_Fechada
        ON dbo.u_HcaPrevEntrada (Fechada)
        WHERE Fechada = 0;
END;
GO
