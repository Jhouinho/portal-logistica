-- =============================================================================
-- Liliana & Seródio — Portal Logístico
-- Script: 043_create_view_HCA_cortes_quantidade.sql
-- Ambiente: UAT primeiro; Produção só no GO formal
-- =============================================================================
-- Linhas em que, após pronta para picking OU documento fechado, a quantidade
-- original encomendada ficou acima da autorizada (corte = u_qttorig − u_qtdaut).
-- Cor efectiva: COALESCE(BI.cor, BI.u_cor) — ver 042.
-- =============================================================================

CREATE OR ALTER VIEW dbo.view_HCA_cortes_quantidade
AS
SELECT
    bi.bistamp,
    bi.bostamp,
    bo.obrano,
    bo.ndos,
    bo.dataobra,
    bo.ousrhora,
    ISNULL(bo.fechada, 0) AS fecho,
    CAST(ISNULL(bo3.u_pickrdy, 0) AS bit) AS pronta_picking,
    bo.no AS cliente_no,
    bo.estab AS cliente_estab,
    LTRIM(RTRIM(bo.nome)) AS cliente_nome,

    LTRIM(RTRIM(bi.ref)) AS ref,
    LTRIM(RTRIM(bi.design)) AS design,
    LTRIM(RTRIM(COALESCE(
        NULLIF(LTRIM(RTRIM(ISNULL(bi.cor, ''))), ''),
        NULLIF(LTRIM(RTRIM(ISNULL(bi.u_cor, ''))), ''),
        ''
    ))) AS cor,
    LTRIM(RTRIM(ISNULL(bi.unidade, ''))) AS unidade,

    bi2.u_qttorig AS quantidade_original,
    bi2.u_qtdaut AS quantidade_autorizada,
    (bi2.u_qttorig - bi2.u_qtdaut) AS quantidade_nao_autorizada,
    bi.qtt2 AS quantidade_fornecida
FROM dbo.bi bi WITH (NOLOCK)
INNER JOIN dbo.bo bo WITH (NOLOCK)
    ON bo.bostamp = bi.bostamp
INNER JOIN dbo.bi2 bi2 WITH (NOLOCK)
    ON bi2.bi2stamp COLLATE DATABASE_DEFAULT = bi.bistamp COLLATE DATABASE_DEFAULT
LEFT JOIN dbo.bo3 bo3 WITH (NOLOCK)
    ON bo3.bo3stamp COLLATE DATABASE_DEFAULT = bo.bostamp COLLATE DATABASE_DEFAULT
WHERE bo.ndos = 1
  AND (
        ISNULL(bo3.u_pickrdy, 0) = 1
     OR ISNULL(bo.fechada, 0) = 1
      )
  AND bi2.u_qttorig > 0
  AND bi2.u_qtdaut >= 0
  AND bi2.u_qttorig > bi2.u_qtdaut;
GO
