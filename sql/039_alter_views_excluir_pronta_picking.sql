-- =============================================================================
-- Liliana & Seródio — Portal Logístico
-- Script: 039_alter_views_excluir_pronta_picking.sql
-- Ambiente: UAT / teste; Produção só no GO formal
-- Exclui BO.u_pickrdy = 1 da procura aberta / rastreio / linhas de trabalho.
-- (A lista de picking lê view_HCA_encomendas_abertas com filtro pronta_picking = 1.)
-- =============================================================================

CREATE OR ALTER VIEW dbo.view_HCA_encomenda_linhas
AS
SELECT
    bi.bostamp,
    bi.bistamp,
    bo.obrano,
    bo.ndos,
    bo.nmdos,
    bo.dataobra,
    bo.ousrhora,
    ISNULL(bo.fechada, 0) AS fecho,
    CAST(ISNULL(bo.u_pickrdy, 0) AS bit) AS pronta_picking,
    bo.no AS cliente_no,
    bo.estab AS cliente_estab,
    LTRIM(RTRIM(bo.nome)) AS cliente_nome,

    LTRIM(RTRIM(bi.ref)) AS ref,
    LTRIM(RTRIM(bi.design)) AS design,
    LTRIM(RTRIM(bi.cor)) AS cor,
    LTRIM(RTRIM(ISNULL(bi.unidade, ''))) AS unidade,

    bi.qtt AS quantidade_atual,
    bi.qtt2 AS quantidade_fornecida,
    bi.u_qttorig AS quantidade_original_campo,
    ISNULL(NULLIF(bi.u_qttorig, 0), bi.qtt) AS quantidade_original_considerada,
    (ISNULL(NULLIF(bi.u_qttorig, 0), bi.qtt) - bi.qtt2) AS quantidade_por_satisfazer,

    bi.edebito AS preco_unitario,
    bi.u_prcorig AS preco_original_campo,

    bi.u_qtdaut AS quantidade_autorizada,
    LTRIM(RTRIM(bi.u_qtdautur)) AS quantidade_autorizada_por,
    bi.u_qtdautdt AS quantidade_autorizada_em,

    ISNULL(st.stock, 0) AS stock_disponivel,

    bi.usrinis,
    bi.usrdata,
    bi.usrhora
FROM dbo.bi bi WITH (NOLOCK)
INNER JOIN dbo.bo bo WITH (NOLOCK)
    ON bo.bostamp = bi.bostamp
LEFT JOIN dbo.st st WITH (NOLOCK)
    ON LTRIM(RTRIM(st.ref)) = LTRIM(RTRIM(bi.ref));
GO

CREATE OR ALTER VIEW dbo.view_HCA_rastreio_artigos
AS
SELECT
    agg.ref,
    agg.design,
    agg.total_linhas,
    agg.total_encomendas,
    agg.quantidade_encomendada_total,
    agg.quantidade_fornecida_total,
    agg.quantidade_por_satisfazer_total,
    agg.quantidade_autorizada_total,
    ISNULL(st.stock, 0) AS stock_disponivel,
    CASE WHEN ISNULL(st.stock, 0) <= 0 THEN 1 ELSE 0 END AS em_rutura
FROM (
    SELECT
        LTRIM(RTRIM(bi.ref)) AS ref,
        MAX(LTRIM(RTRIM(bi.design))) AS design,
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
      AND ISNULL(bo.u_pickrdy, 0) = 0
      AND (ISNULL(NULLIF(bi.u_qttorig, 0), bi.qtt) - bi.qtt2) > 0
    GROUP BY
        LTRIM(RTRIM(bi.ref))
) agg
LEFT JOIN dbo.st st WITH (NOLOCK)
    ON LTRIM(RTRIM(st.ref)) = agg.ref;
GO

CREATE OR ALTER VIEW dbo.view_HCA_artigo_encomendas
AS
SELECT
    bi.bistamp,
    bi.bostamp,
    LTRIM(RTRIM(bi.ref)) AS ref,
    LTRIM(RTRIM(bi.design)) AS design,

    bo.obrano,
    bo.ndos,
    bo.nmdos,
    bo.dataobra,
    bo.ousrhora,
    ISNULL(bo.fechada, 0) AS fecho,

    bo.no AS cliente_no,
    bo.estab AS cliente_estab,
    LTRIM(RTRIM(bo.nome)) AS cliente_nome,

    bi.qtt AS quantidade_atual,
    bi.qtt2 AS quantidade_fornecida,
    bi.u_qttorig AS quantidade_original_campo,
    ISNULL(NULLIF(bi.u_qttorig, 0), bi.qtt) AS quantidade_pedida,
    (ISNULL(NULLIF(bi.u_qttorig, 0), bi.qtt) - bi.qtt2) AS quantidade_por_satisfazer,

    bi.u_qtdaut AS quantidade_autorizada,
    LTRIM(RTRIM(bi.u_qtdautur)) AS quantidade_autorizada_por,
    bi.u_qtdautdt AS quantidade_autorizada_em,

    ISNULL(st.stock, 0) AS stock_disponivel
FROM dbo.bi bi WITH (NOLOCK)
INNER JOIN dbo.bo bo WITH (NOLOCK)
    ON bo.bostamp = bi.bostamp
LEFT JOIN dbo.st st WITH (NOLOCK)
    ON LTRIM(RTRIM(st.ref)) = LTRIM(RTRIM(bi.ref))
WHERE bo.ndos = 1
  AND ISNULL(bo.fechada, 0) = 0
  AND ISNULL(bo.u_pickrdy, 0) = 0
  AND (ISNULL(NULLIF(bi.u_qttorig, 0), bi.qtt) - bi.qtt2) > 0;
GO
