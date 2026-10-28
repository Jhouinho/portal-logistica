-- =============================================================================
-- Liliana & Seródio — Pedidos Mobile: estados operacionais pós-aprovação
-- Script: 104_doc_estados_operacionais_pedidos_mobile.sql
-- NÃO altera schema. Documentação + verificação de leitura.
--
-- Semântica (EstadoInterno varchar existente — sem CHECK):
--   recebido / em_analise     → pendente (preços / rejeição)
--   em_aprovacao              → claim antes da SP BO67
--   em_separacao              → dossier PHC ligado; em separação (preferido pós-aprovação)
--   integrado                 → legado equivalente a em_separacao (ainda listado)
--   pronto_levantamento       → separado; aguarda levantamento do cliente
--   concluido                 → processo terminado
--   rejeitado / cancelado     → terminais
-- =============================================================================

SET NOCOUNT ON;
GO

IF OBJECT_ID(N'dbo.u_HcaPmPedido', N'U') IS NULL
BEGIN
    RAISERROR(N'u_HcaPmPedido em falta — aplicar 096 primeiro.', 16, 1);
    RETURN;
END
GO

PRINT N'OK: 104 — documentação estados operacionais.';
PRINT N'Valores: recebido | em_analise | em_aprovacao | em_separacao | integrado | pronto_levantamento | concluido | rejeitado | cancelado';
GO
