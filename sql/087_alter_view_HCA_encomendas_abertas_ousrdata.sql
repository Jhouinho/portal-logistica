-- =============================================================================
-- Liliana & Seródio — Portal Logístico
-- Script: 087_alter_view_HCA_encomendas_abertas_ousrdata.sql
-- Ambiente: UAT / teste; Produção só no GO formal
-- Pré-requisitos: view_HCA_encomendas_abertas (049+), coluna nativa BO.ousrdata
-- =============================================================================
-- Expõe BO.ousrdata (data de criação/entrada) para a futura regra «Fora de prazo».
-- Não altera filtros, agregados nem restantes colunas. Idempotente (CREATE OR ALTER).
-- =============================================================================

CREATE OR ALTER VIEW dbo.view_HCA_encomendas_abertas
AS
SELECT
    bo.bostamp,
    bo.obrano,
    bo.ndos,
    bo.nmdos,
    bo.dataobra,
    bo.ousrdata,
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
    CAST(ISNULL(bo3.u_pickstat, 0) AS int) AS pick_status,
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
    bo.ousrdata,
    bo.ousrhora,
    bo.no,
    bo.estab,
    bo.nome,
    bo3.u_pickrdy,
    bo3.u_pickrdr,
    bo3.u_pickrdt,
    bo3.u_pickstat,
    bo3.u_urgente;
GO
