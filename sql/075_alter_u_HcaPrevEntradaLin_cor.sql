-- =============================================================================
-- Liliana & Seródio — Portal Logístico
-- Script: 075_alter_u_HcaPrevEntradaLin_cor.sql
-- Ambiente: UAT primeiro; Produção só no GO formal
-- Pré-requisito: 062 (u_HcaPrevEntradaLin); limpeza fixtures PR2-A
-- =============================================================================
-- PR2-A2 — Previsão por Referência + Cor.
--   Cor varchar(100) NOT NULL DEFAULT '' (mesmo tipo/semântica de BI.u_cor).
--   Unicidade: (PrevisaoId, Ref, Cor). Remove UQ apenas (PrevisaoId, Ref).
-- =============================================================================

SET NOCOUNT ON;
SET XACT_ABORT ON;
GO

IF COL_LENGTH(N'dbo.u_HcaPrevEntradaLin', N'Cor') IS NULL
BEGIN
    ALTER TABLE dbo.u_HcaPrevEntradaLin
        ADD Cor varchar(100) NOT NULL
            CONSTRAINT DF_u_HcaPrevEntradaLin_Cor DEFAULT ('');
END;
GO

IF EXISTS (
    SELECT 1
    FROM sys.key_constraints
    WHERE name = N'UQ_u_HcaPrevEntradaLin_Ref'
      AND parent_object_id = OBJECT_ID(N'dbo.u_HcaPrevEntradaLin')
)
BEGIN
    ALTER TABLE dbo.u_HcaPrevEntradaLin
        DROP CONSTRAINT UQ_u_HcaPrevEntradaLin_Ref;
END;
GO

IF NOT EXISTS (
    SELECT 1
    FROM sys.key_constraints
    WHERE name = N'UQ_u_HcaPrevEntradaLin_RefCor'
      AND parent_object_id = OBJECT_ID(N'dbo.u_HcaPrevEntradaLin')
)
BEGIN
    ALTER TABLE dbo.u_HcaPrevEntradaLin
        ADD CONSTRAINT UQ_u_HcaPrevEntradaLin_RefCor UNIQUE (PrevisaoId, Ref, Cor);
END;
GO
