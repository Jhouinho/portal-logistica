-- =============================================================================
-- Liliana & Seródio — Portal Logístico
-- Script: 054_alter_view_HCA_cortes_quantidade_fechada_picking_concluido.sql
-- Ambiente: UAT primeiro; Produção só no GO formal
-- =============================================================================
-- Quantidades não entregues: só encomendas (ndos=1) fechadas, com picking
-- concluído (BO3.u_pickstat = 3), em que u_qttorig > u_qtdaut.
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
    CAST(ISNULL(bo3.u_urgente, 0) AS bit) AS urgente,
    CAST(ISNULL(bo3.u_pickstat, 0) AS int) AS pick_status,
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
  AND ISNULL(bo.fechada, 0) = 1
  AND CAST(ISNULL(bo3.u_pickstat, 0) AS int) = 3
  AND bi2.u_qttorig > 0
  AND bi2.u_qtdaut >= 0
  AND bi2.u_qttorig > bi2.u_qtdaut;
GO
