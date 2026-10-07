-- =============================================================================
-- Liliana & Seródio — Portal Logístico
-- Script: 061_alter_view_HCA_encomenda_linhas_disponivel_portal.sql
-- Ambiente: UAT primeiro; Produção só no GO formal
-- =============================================================================
-- Expõe STOBS.u_dispPort como disponivel_no_portal (linhas de encomenda).
-- Não filtra linhas: documentos existentes mantêm todas as referências.
-- Pré-requisito: STOBS.u_dispPort (bit NOT NULL DEFAULT 0); relação por ref.
-- Base: definição actual (049) + JOIN STOBS.
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
    CAST(ISNULL(bo3.u_pickstat, 0) AS int) AS pick_status,
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

    CAST(ISNULL(stobs.u_dispPort, 0) AS bit) AS disponivel_no_portal,

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
    ON LTRIM(RTRIM(st.ref)) = LTRIM(RTRIM(bi.ref))
LEFT JOIN dbo.stobs stobs WITH (NOLOCK)
    ON LTRIM(RTRIM(stobs.ref)) = LTRIM(RTRIM(bi.ref));
GO
