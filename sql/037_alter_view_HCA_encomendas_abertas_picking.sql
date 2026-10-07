-- =============================================================================
-- Liliana & Seródio — Portal Logístico
-- Script: 037_alter_view_HCA_encomendas_abertas_picking.sql
-- Ambiente: UAT / teste; Produção só no GO formal
-- Pré-requisitos: BO.u_pickrdy, BO.u_upickrdr, BO.u_upickrdt
-- =============================================================================

CREATE OR ALTER VIEW dbo.view_HCA_encomendas_abertas
AS
SELECT
    bo.bostamp,
    bo.obrano,
    bo.ndos,
    bo.nmdos,
    bo.dataobra,
    bo.ousrhora,
    bo.no AS cliente_no,
    bo.estab AS cliente_estab,
    LTRIM(RTRIM(bo.nome)) AS cliente_nome,

    COUNT(bi.bistamp) AS total_linhas,

    SUM(ISNULL(NULLIF(bi.u_qttorig, 0), bi.qtt)) AS quantidade_original_total,

    SUM(bi.qtt) AS quantidade_atual_total,

    SUM(bi.qtt2) AS quantidade_fornecida_total,

    SUM(ISNULL(NULLIF(bi.u_qttorig, 0), bi.qtt) - bi.qtt2) AS quantidade_restante_total,

    SUM(bi.u_qtdaut) AS quantidade_autorizada_total,

    CAST(ISNULL(bo.u_pickrdy, 0) AS bit) AS pronta_picking,
    LTRIM(RTRIM(bo.u_upickrdr)) AS pronta_picking_por,
    CASE
        WHEN bo.u_upickrdt IS NULL OR YEAR(bo.u_upickrdt) < 1950 THEN CAST(NULL AS datetime)
        ELSE bo.u_upickrdt
    END AS pronta_picking_em

FROM dbo.bo bo WITH (NOLOCK)
INNER JOIN dbo.bi bi WITH (NOLOCK)
    ON bi.bostamp = bo.bostamp
WHERE bo.ndos = 1
  AND ISNULL(bo.fechada, 0) = 0
  AND (ISNULL(NULLIF(bi.u_qttorig, 0), bi.qtt) - bi.qtt2) > 0
GROUP BY
    bo.bostamp,
    bo.obrano,
    bo.ndos,
    bo.nmdos,
    bo.dataobra,
    bo.ousrhora,
    bo.no,
    bo.estab,
    bo.nome,
    bo.u_pickrdy,
    bo.u_upickrdr,
    bo.u_upickrdt;
GO
