-- =============================================================================
-- Liliana & Seródio — Portal Logístico
-- Script: 017_validate_view_HCA_rastreio_artigos.sql
-- Ambiente: UAT / teste (não Produção até GO formal)
-- Pré-requisito: sql/016_create_view_HCA_rastreio_artigos.sql já executado
-- =============================================================================

-- 1. Ver primeiros artigos com procura aberta
SELECT TOP 50 *
FROM dbo.view_HCA_rastreio_artigos
ORDER BY quantidade_por_satisfazer_total DESC, ref;

-- 2. Contar artigos
SELECT COUNT(*) AS total_artigos_com_procura
FROM dbo.view_HCA_rastreio_artigos;

-- 3. Artigos em rutura (KPI) — stock <= 0
SELECT TOP 50 *
FROM dbo.view_HCA_rastreio_artigos
WHERE em_rutura = 1
ORDER BY quantidade_por_satisfazer_total DESC;

-- 4. Validar restante sempre positivo
-- Resultado esperado: 0 linhas
SELECT TOP 20 *
FROM dbo.view_HCA_rastreio_artigos
WHERE quantidade_por_satisfazer_total <= 0;

-- 5. Coerência stock (RN-018) vs ST
-- Resultado esperado: 0 linhas com diferença
SELECT TOP 20
    ra.ref,
    ra.stock_disponivel,
    ISNULL(st.stock, 0) AS st_stock
FROM dbo.view_HCA_rastreio_artigos ra
LEFT JOIN dbo.st st WITH (NOLOCK)
    ON LTRIM(RTRIM(st.ref)) = ra.ref
WHERE ra.stock_disponivel <> ISNULL(st.stock, 0);

-- 6. Cruzar totais de um artigo com detalhe (artigo_encomendas / BI)
DECLARE @ref varchar(18);

SELECT TOP 1 @ref = ref
FROM dbo.view_HCA_rastreio_artigos
ORDER BY quantidade_por_satisfazer_total DESC;

SELECT @ref AS ref_teste;

SELECT *
FROM dbo.view_HCA_rastreio_artigos
WHERE ref = @ref;

SELECT
    LTRIM(RTRIM(bi.ref)) AS ref,
    COUNT(bi.bistamp) AS total_linhas,
    COUNT(DISTINCT bi.bostamp) AS total_encomendas,
    SUM(ISNULL(NULLIF(bi.u_qttorig, 0), bi.qtt)) AS quantidade_encomendada_total,
    SUM(bi.qtt2) AS quantidade_fornecida_total,
    SUM(ISNULL(NULLIF(bi.u_qttorig, 0), bi.qtt) - bi.qtt2) AS quantidade_por_satisfazer_total,
    SUM(bi.u_qtdaut) AS quantidade_autorizada_total
FROM dbo.bi bi WITH (NOLOCK)
INNER JOIN dbo.bo bo WITH (NOLOCK)
    ON bo.bostamp = bi.bostamp
WHERE bo.ndos = 1
  AND ISNULL(bo.fechada, 0) = 0
  AND (ISNULL(NULLIF(bi.u_qttorig, 0), bi.qtt) - bi.qtt2) > 0
  AND LTRIM(RTRIM(bi.ref)) = @ref
GROUP BY
    LTRIM(RTRIM(bi.ref));
GO
