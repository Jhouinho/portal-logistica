-- =============================================================================
-- Liliana & Seródio — Portal Logístico
-- Script: 013_validate_view_HCA_encomendas_abertas.sql
-- Ambiente: UAT / teste (não Produção até GO formal)
-- Pré-requisito: sql/012_create_view_HCA_encomendas_abertas.sql já executado
-- =============================================================================

-- 1. Ver primeiras encomendas abertas
SELECT TOP 50 *
FROM dbo.view_HCA_encomendas_abertas
ORDER BY dataobra DESC, ousrhora DESC;

-- 2. Contar encomendas abertas
SELECT COUNT(*) AS total_encomendas_abertas
FROM dbo.view_HCA_encomendas_abertas;

-- 3. Validar que só existe ndos = 1
SELECT ndos, COUNT(*) AS total
FROM dbo.view_HCA_encomendas_abertas
GROUP BY ndos;

-- 4. Validar que todas têm quantidade restante positiva
-- Resultado esperado: 0 linhas
SELECT TOP 20 *
FROM dbo.view_HCA_encomendas_abertas
WHERE quantidade_restante_total <= 0;

-- 5. Validar detalhe de uma encomenda específica
-- Substituir @bostamp pelo valor real de uma encomenda devolvida pela view
DECLARE @bostamp varchar(25) = 'COLOCAR_BOSTAMP_AQUI';

SELECT *
FROM dbo.view_HCA_encomendas_abertas
WHERE bostamp = @bostamp;

SELECT
    bo.bostamp,
    bo.obrano,
    bi.bistamp,
    bi.ref,
    bi.design,
    bi.qtt,
    bi.qtt2,
    bi.u_qttorig,
    ISNULL(NULLIF(bi.u_qttorig, 0), bi.qtt) AS quantidade_original_considerada,
    ISNULL(NULLIF(bi.u_qttorig, 0), bi.qtt) - bi.qtt2 AS restante,
    bi.u_qtdaut
FROM dbo.bo bo WITH (NOLOCK)
INNER JOIN dbo.bi bi WITH (NOLOCK)
    ON bi.bostamp = bo.bostamp
WHERE bo.bostamp = @bostamp
ORDER BY bi.ref;
GO
