-- =============================================================================
-- Liliana & Seródio — Portal Logístico
-- Script: 019_validate_view_HCA_artigo_encomendas.sql
-- Ambiente: UAT / teste (não Produção até GO formal)
-- Pré-requisito: sql/018_create_view_HCA_artigo_encomendas.sql já executado
-- Preferível: view_HCA_rastreio_artigos já criada (016)
-- =============================================================================

-- 1. Ver primeiras linhas
SELECT TOP 50 *
FROM dbo.view_HCA_artigo_encomendas
ORDER BY dataobra DESC, ousrhora DESC, ref;

-- 2. Contar linhas abertas por artigo
SELECT COUNT(*) AS total_linhas_abertas
FROM dbo.view_HCA_artigo_encomendas;

-- 3. Só ndos = 1
SELECT ndos, COUNT(*) AS total
FROM dbo.view_HCA_artigo_encomendas
GROUP BY ndos;

-- 4. Restante sempre positivo — esperado: 0 linhas
SELECT TOP 20 *
FROM dbo.view_HCA_artigo_encomendas
WHERE quantidade_por_satisfazer <= 0;

-- 5. Documento sempre aberto (fecho = 0) — esperado: 0 linhas
SELECT TOP 20 *
FROM dbo.view_HCA_artigo_encomendas
WHERE fecho <> 0;

-- 6. Cruzar com rastreio para um artigo
DECLARE @ref varchar(18);

SELECT TOP 1 @ref = ref
FROM dbo.view_HCA_rastreio_artigos
ORDER BY quantidade_por_satisfazer_total DESC;

SELECT @ref AS ref_teste;

SELECT *
FROM dbo.view_HCA_artigo_encomendas
WHERE ref = @ref
ORDER BY obrano, bistamp;

-- Soma do detalhe vs agregado do rastreio
SELECT
    ra.ref,
    ra.total_linhas AS linhas_rastreio,
    ra.quantidade_por_satisfazer_total AS restante_rastreio,
    ra.quantidade_autorizada_total AS aut_rastreio,
    ra.stock_disponivel AS stock_rastreio,
    det.linhas_detalhe,
    det.restante_detalhe,
    det.aut_detalhe,
    det.stock_detalhe
FROM dbo.view_HCA_rastreio_artigos ra
INNER JOIN (
    SELECT
        ref,
        COUNT(*) AS linhas_detalhe,
        SUM(quantidade_por_satisfazer) AS restante_detalhe,
        SUM(quantidade_autorizada) AS aut_detalhe,
        MAX(stock_disponivel) AS stock_detalhe
    FROM dbo.view_HCA_artigo_encomendas
    WHERE ref = @ref
    GROUP BY ref
) det ON det.ref = ra.ref
WHERE ra.ref = @ref;

-- Diferenças — esperado: totais iguais (query abaixo = 0 linhas se OK)
SELECT
    ra.ref,
    ra.total_linhas,
    det.linhas_detalhe,
    ra.quantidade_por_satisfazer_total,
    det.restante_detalhe
FROM dbo.view_HCA_rastreio_artigos ra
INNER JOIN (
    SELECT
        ref,
        COUNT(*) AS linhas_detalhe,
        SUM(quantidade_por_satisfazer) AS restante_detalhe
    FROM dbo.view_HCA_artigo_encomendas
    WHERE ref = @ref
    GROUP BY ref
) det ON det.ref = ra.ref
WHERE ra.ref = @ref
  AND (
        ra.total_linhas <> det.linhas_detalhe
     OR ra.quantidade_por_satisfazer_total <> det.restante_detalhe
  );
GO
