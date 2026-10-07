-- =============================================================================
-- Liliana & Seródio — Portal Logístico
-- Script: 016_create_view_HCA_rastreio_artigos.sql
-- Ambiente: UAT / teste primeiro; Produção só no fim da implementação (GO formal)
-- Pré-requisitos: campos BI u_qttorig, u_qtdaut*; vistas 012/014 validadas em UAT
-- =============================================================================
-- Objetivo:
--   Agregação da procura aberta por artigo (ref) + ST.stock (RN-018).
--   API: GET /artigos/procura-aberta
-- Filtros (iguais a encomendas abertas):
--   BO.ndos = 1, documento aberto, restante > 0
-- Nota: campo físico de fecho em UAT = BO.fechada (alias lógico: fecho)
-- =============================================================================

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
      AND (ISNULL(NULLIF(bi.u_qttorig, 0), bi.qtt) - bi.qtt2) > 0
    GROUP BY
        LTRIM(RTRIM(bi.ref))
) agg
LEFT JOIN dbo.st st WITH (NOLOCK)
    ON LTRIM(RTRIM(st.ref)) = agg.ref;
GO
