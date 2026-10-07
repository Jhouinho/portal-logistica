-- =============================================================================
-- Liliana & Seródio — Portal Logístico
-- Script: 053_backfill_bo3_u_pickstat_ready.sql
-- Ambiente: UAT / teste; Produção só no GO formal
-- =============================================================================
-- Encomendas já marcadas pronta (u_pickrdy=1) sem estado → Preparado (1).
-- Não altera ndos=66.
-- =============================================================================

UPDATE bo3
SET u_pickstat = 1
FROM dbo.bo3 bo3
INNER JOIN dbo.bo bo
    ON bo.bostamp COLLATE DATABASE_DEFAULT = bo3.bo3stamp COLLATE DATABASE_DEFAULT
WHERE bo.ndos = 1
  AND ISNULL(bo.fechada, 0) = 0
  AND CAST(ISNULL(bo3.u_pickrdy, 0) AS int) = 1
  AND CAST(ISNULL(bo3.u_pickstat, 0) AS int) = 0;
GO
