-- =============================================================================
-- Liliana & Seródio — Portal Logístico
-- Script: 044_add_bo3_u_urgente_views.sql
-- Ambiente: UAT primeiro; Produção só no GO formal
-- =============================================================================
-- Pré-requisito: BO3.u_urgente (Lógico) criado no Framework + Atualizar a Tabela.
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
    SUM(ISNULL(NULLIF(bi2.u_qttorig, 0), bi.qtt)) AS quantidade_original_total,
    SUM(bi.qtt) AS quantidade_atual_total,
    SUM(bi.qtt2) AS quantidade_fornecida_total,
    SUM(ISNULL(NULLIF(bi2.u_qttorig, 0), bi.qtt) - bi.qtt2) AS quantidade_restante_total,
    SUM(ISNULL(bi2.u_qtdaut, 0)) AS quantidade_autorizada_total,

    CAST(ISNULL(bo3.u_pickrdy, 0) AS bit) AS pronta_picking,
    LTRIM(RTRIM(ISNULL(bo3.u_pickrdr, ''))) AS pronta_picking_por,
    CASE
        WHEN bo3.u_pickrdt IS NULL OR YEAR(bo3.u_pickrdt) < 1950 THEN CAST(NULL AS datetime)
        ELSE bo3.u_pickrdt
    END AS pronta_picking_em,
    CAST(ISNULL(bo3.u_urgente, 0) AS bit) AS urgente
FROM dbo.bo bo WITH (NOLOCK)
INNER JOIN dbo.bi bi WITH (NOLOCK)
    ON bi.bostamp = bo.bostamp
LEFT JOIN dbo.bi2 bi2 WITH (NOLOCK)
    ON bi2.bi2stamp COLLATE DATABASE_DEFAULT = bi.bistamp COLLATE DATABASE_DEFAULT
LEFT JOIN dbo.bo3 bo3 WITH (NOLOCK)
    ON bo3.bo3stamp COLLATE DATABASE_DEFAULT = bo.bostamp COLLATE DATABASE_DEFAULT
WHERE bo.ndos = 1
  AND ISNULL(bo.fechada, 0) = 0
  AND (ISNULL(NULLIF(bi2.u_qttorig, 0), bi.qtt) - bi.qtt2) > 0
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
    bo3.u_pickrdy,
    bo3.u_pickrdr,
    bo3.u_pickrdt,
    bo3.u_urgente;
GO

CREATE OR ALTER VIEW dbo.view_HCA_encomenda_linhas
AS
SELECT
    bi.bistamp,
    bi.bostamp,
    bo.obrano,
    bo.ndos,
    bo.nmdos,
    bo.dataobra,
    bo.ousrhora,
    ISNULL(bo.fechada, 0) AS fecho,
    CAST(ISNULL(bo3.u_pickrdy, 0) AS bit) AS pronta_picking,
    CAST(ISNULL(bo3.u_urgente, 0) AS bit) AS urgente,
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

    bi.qtt AS quantidade_atual,
    bi.qtt2 AS quantidade_fornecida,
    ISNULL(bi2.u_qttorig, 0) AS quantidade_original_campo,
    ISNULL(NULLIF(bi2.u_qttorig, 0), bi.qtt) AS quantidade_original_considerada,
    (ISNULL(NULLIF(bi2.u_qttorig, 0), bi.qtt) - bi.qtt2) AS quantidade_por_satisfazer,

    bi.edebito AS preco_unitario,
    ISNULL(bi2.u_prcorig, 0) AS preco_original_campo,

    ISNULL(bi2.u_qtdaut, 0) AS quantidade_autorizada,
    LTRIM(RTRIM(ISNULL(bi2.u_qtdautur, ''))) AS quantidade_autorizada_por,
    bi2.u_qtdautdt AS quantidade_autorizada_em,

    ISNULL(st.stock, 0) AS stock_disponivel,

    bi.usrinis,
    bi.usrdata,
    bi.usrhora
FROM dbo.bi bi WITH (NOLOCK)
INNER JOIN dbo.bo bo WITH (NOLOCK)
    ON bo.bostamp = bi.bostamp
LEFT JOIN dbo.bi2 bi2 WITH (NOLOCK)
    ON bi2.bi2stamp COLLATE DATABASE_DEFAULT = bi.bistamp COLLATE DATABASE_DEFAULT
LEFT JOIN dbo.bo3 bo3 WITH (NOLOCK)
    ON bo3.bo3stamp COLLATE DATABASE_DEFAULT = bo.bostamp COLLATE DATABASE_DEFAULT
LEFT JOIN dbo.st st WITH (NOLOCK)
    ON LTRIM(RTRIM(st.ref)) = LTRIM(RTRIM(bi.ref));
GO

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
