-- =============================================================================
-- Liliana & Seródio — Portal Logístico
-- Script: 015_validate_view_HCA_encomenda_linhas.sql
-- Ambiente: UAT / teste (não Produção até GO formal)
-- Pré-requisito: sql/014_create_view_HCA_encomenda_linhas.sql já executado
-- =============================================================================

-- 1. Ver primeiras linhas (série 1)
SELECT TOP 50 *
FROM dbo.view_HCA_encomenda_linhas
ORDER BY dataobra DESC, ousrhora DESC, ref;

-- 2. Contar linhas
SELECT COUNT(*) AS total_linhas
FROM dbo.view_HCA_encomenda_linhas;

-- 3. Validar que só existe ndos = 1
SELECT ndos, COUNT(*) AS total
FROM dbo.view_HCA_encomenda_linhas
GROUP BY ndos;

-- 4. Cruzar com uma encomenda aberta da vista de cabeçalho
--    (substituir @bostamp se necessário; senão usa a 1.ª encomenda aberta)
DECLARE @bostamp varchar(25);

SELECT TOP 1 @bostamp = bostamp
FROM dbo.view_HCA_encomendas_abertas
ORDER BY dataobra DESC, ousrhora DESC;

SELECT @bostamp AS bostamp_teste;

SELECT *
FROM dbo.view_HCA_encomenda_linhas
WHERE bostamp = @bostamp
ORDER BY ref;

-- 5. Coerência: total_linhas da vista agregada vs COUNT das linhas com restante > 0
SELECT
    ea.bostamp,
    ea.obrano,
    ea.total_linhas AS total_linhas_agregado,
    (
        SELECT COUNT(*)
        FROM dbo.view_HCA_encomenda_linhas el
        WHERE el.bostamp = ea.bostamp
          AND el.quantidade_por_satisfazer > 0
    ) AS total_linhas_detalhe_abertas,
    ea.quantidade_restante_total AS restante_agregado,
    (
        SELECT SUM(el.quantidade_por_satisfazer)
        FROM dbo.view_HCA_encomenda_linhas el
        WHERE el.bostamp = ea.bostamp
          AND el.quantidade_por_satisfazer > 0
    ) AS restante_soma_detalhe
FROM dbo.view_HCA_encomendas_abertas ea
WHERE ea.bostamp = @bostamp;

-- 6. Validar fórmula do restante face a BI (amostra)
SELECT TOP 20
    el.bistamp,
    el.ref,
    el.quantidade_atual,
    el.quantidade_fornecida,
    el.quantidade_original_campo,
    el.quantidade_original_considerada,
    el.quantidade_por_satisfazer,
    bi.qtt,
    bi.qtt2,
    bi.u_qttorig,
    ISNULL(NULLIF(bi.u_qttorig, 0), bi.qtt) - bi.qtt2 AS restante_bi
FROM dbo.view_HCA_encomenda_linhas el
INNER JOIN dbo.bi bi WITH (NOLOCK)
    ON bi.bistamp = el.bistamp
WHERE el.bostamp = @bostamp
  AND el.quantidade_por_satisfazer
      <> (ISNULL(NULLIF(bi.u_qttorig, 0), bi.qtt) - bi.qtt2);

-- Resultado esperado da query 6: 0 linhas

-- 7. Stock (RN-018) — amostra
SELECT TOP 20
    el.ref,
    el.design,
    el.stock_disponivel,
    ISNULL(st.stock, 0) AS st_stock
FROM dbo.view_HCA_encomenda_linhas el
LEFT JOIN dbo.st st WITH (NOLOCK)
    ON LTRIM(RTRIM(st.ref)) = el.ref
WHERE el.bostamp = @bostamp
ORDER BY el.ref;
GO
