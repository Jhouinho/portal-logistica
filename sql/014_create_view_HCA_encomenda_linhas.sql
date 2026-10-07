-- =============================================================================
-- Liliana & Seródio — Portal Logístico
-- Script: 014_create_view_HCA_encomenda_linhas.sql
-- Ambiente: UAT / teste primeiro; Produção só no fim da implementação (GO formal)
-- Pré-requisitos: campos BI u_qttorig, u_prcorig, u_qtdaut, u_qtdautur, u_qtdautdt
-- =============================================================================
-- Objetivo:
--   Uma linha por BI (detalhe da encomenda). Filtro API: WHERE bostamp = @boStamp.
--   Restante: ISNULL(NULLIF(BI.u_qttorig, 0), BI.qtt) - BI.qtt2
--   Stock disponível (RN-018): ST.stock
--   Representante / vendedor: fora de âmbito (sem filtro).
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

    LTRIM(RTRIM(bi.usrinis)) AS usrinis,
    bi.usrdata,
    bi.usrhora
FROM dbo.bi bi WITH (NOLOCK)
INNER JOIN dbo.bo bo WITH (NOLOCK)
    ON bo.bostamp = bi.bostamp
LEFT JOIN dbo.st st WITH (NOLOCK)
    ON LTRIM(RTRIM(st.ref)) = LTRIM(RTRIM(bi.ref))
WHERE bo.ndos = 1;
GO
