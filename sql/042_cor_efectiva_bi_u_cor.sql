-- =============================================================================
-- Liliana & Seródio — Portal Logístico
-- Script: 042_cor_efectiva_bi_u_cor.sql
-- Ambiente: UAT primeiro; Produção só no GO formal
-- =============================================================================
-- Nesta BD a cor das linhas está em BI.u_cor; BI.cor (nativo) vem vazio.
-- A vista e a SP passam a expor/filtrar a cor efectiva:
--   COALESCE(NULLIF(bi.cor,''), NULLIF(bi.u_cor,''), '')
-- =============================================================================

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
