-- =============================================================================
-- Liliana & Seródio — Portal Logístico
-- Script: 018_create_view_HCA_artigo_encomendas.sql
-- Ambiente: UAT / teste primeiro; Produção só no fim da implementação (GO formal)
-- Pré-requisitos: campos BI u_qttorig, u_qtdaut*; vistas 012/014/016
-- =============================================================================
-- Objetivo:
--   Linhas / encomendas abertas por artigo (ref).
--   API: GET /artigos/{ref}/encomendas-abertas → WHERE ref = @ref
-- Filtros: ndos = 1, documento aberto, restante > 0
-- Nota: campo físico de fecho em UAT = BO.fechada
-- =============================================================================

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
  AND (ISNULL(NULLIF(bi.u_qttorig, 0), bi.qtt) - bi.qtt2) > 0;
GO
