-- =============================================================================
-- Liliana & Seródio — Pedidos Mobile staff: estado intermédio em_aprovacao
-- Script: 101_doc_estado_em_aprovacao_pedidos_mobile.sql
-- NÃO altera schema. Documentação + verificação de leitura para UAT.
-- NÃO executar como pré-requisito de deploy — o código usa varchar(32) existente
-- (096_create_u_HcaPmPedido.EstadoInterno). Sem CHECK constraint a alterar.
--
-- Semântica:
--   recebido / em_analise → editável (preços) e rejeitável
--   em_aprovacao         → claim atómico antes de sp_HCA_criar_pedido_mobile;
--                          não rejeitável; preços bloqueados; aprovação idempotente
--   integrado            → dossier PHC ligado (Bostamp)
--   rejeitado            → terminal; sem dossier
-- =============================================================================

SET NOCOUNT ON;
GO

IF OBJECT_ID(N'dbo.u_HcaPmPedido', N'U') IS NULL
BEGIN
    RAISERROR(N'u_HcaPmPedido em falta — aplicar 096 primeiro.', 16, 1);
    RETURN;
END
GO

-- Verificação: coluna suporta o novo valor (comprimento).
IF COL_LENGTH(N'dbo.u_HcaPmPedido', N'EstadoInterno') IS NULL
BEGIN
    RAISERROR(N'Coluna EstadoInterno em falta.', 16, 1);
    RETURN;
END
GO

PRINT N'OK: 101 — documentação. Estado em_aprovacao é valor de aplicação (sem ALTER).';
PRINT N'Valores: recebido | em_analise | em_aprovacao | integrado | rejeitado | cancelado';
GO
