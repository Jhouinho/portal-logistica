-- =============================================================================
-- Liliana & Seródio — Portal Logístico
-- Script: 035b_validate_sp_HCA_alocacao_proporcional.sql
-- Pré-requisito: 035 (ou 026 actualizado) executado
-- =============================================================================

DECLARE @ref varchar(18);

SELECT TOP 1 @ref = ref
FROM dbo.view_HCA_rastreio_artigos
ORDER BY quantidade_por_satisfazer_total DESC;

-- 1. Pré-visualização com disponivel=0 → propostas 0
EXEC dbo.sp_HCA_alocacao_proporcional
    @ref = @ref,
    @usrlogin = N'teste.portal',
    @simular = 1,
    @disponivel = 0,
    @filtrar_cor = 0;

-- 2. Pré-visualização sem @disponivel (usa ST.stock)
EXEC dbo.sp_HCA_alocacao_proporcional
    @ref = @ref,
    @usrlogin = N'teste.portal',
    @simular = 1;
GO

