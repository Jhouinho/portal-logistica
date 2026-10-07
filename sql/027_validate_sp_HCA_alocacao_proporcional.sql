-- =============================================================================
-- Liliana & Seródio — Portal Logístico
-- Script: 027_validate_sp_HCA_alocacao_proporcional.sql
-- Pré-requisito: 026 executado
-- =============================================================================

DECLARE @ref varchar(18);

SELECT TOP 1 @ref = ref
FROM dbo.view_HCA_rastreio_artigos
ORDER BY quantidade_por_satisfazer_total DESC;

SELECT @ref AS ref_teste, *
FROM dbo.view_HCA_rastreio_artigos
WHERE ref = @ref;

-- 1. Pré-visualização (não grava)
EXEC dbo.sp_HCA_alocacao_proporcional
    @ref = @ref,
    @usrlogin = N'teste.portal',
    @simular = 1;

-- 2. Gravação — só se stock > 0 e quiseres alterar UAT
/*
EXEC dbo.sp_HCA_alocacao_proporcional
    @ref = @ref,
    @usrlogin = N'teste.portal',
    @simular = 0;
*/

SELECT bistamp, ref, u_qtdaut, u_qtdautur, u_qtdautdt
FROM dbo.bi WITH (NOLOCK)
WHERE LTRIM(RTRIM(ref)) = @ref;
GO
