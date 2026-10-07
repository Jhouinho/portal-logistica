-- =============================================================================
-- Liliana & Seródio — Portal Logístico
-- Script: 074_alter_sp_HCA_prev_entrada_obter_consumo.sql
-- Ambiente: UAT primeiro; Produção só no GO formal
-- Pré-requisito: 065 (sp_HCA_prev_entrada_obter); BI2.u_previd varchar(50) NOT NULL
-- =============================================================================
-- PR2-B1 — Visibilidade Previsto / Alocado / Disponível no detalhe Admin.
--   Só leitura. Não altera teto, BI2, Lin, autorização, picking, dados.
--   Alocado = SUM(u_qtdaut) WHERE u_previd = P AND bi.ref = Ref (sem filtro ndos).
-- =============================================================================

SET NOCOUNT ON;
GO

CREATE OR ALTER PROCEDURE dbo.sp_HCA_prev_entrada_obter
    @id uniqueidentifier
AS
BEGIN
    SET NOCOUNT ON;

    SELECT
        p.Id,
        p.DataInicio,
        p.DataFim,
        CAST(p.Fechada AS bit) AS Fechada,
        p.FechadaEm,
        LTRIM(RTRIM(ISNULL(p.FechadaPor, N''))) AS FechadaPor
    FROM dbo.u_HcaPrevEntrada p WITH (NOLOCK)
    WHERE p.Id = @id;

    DECLARE @prevIdStr varchar(50) = CONVERT(varchar(50), @id);

    SELECT
        l.Id,
        l.PrevisaoId,
        LTRIM(RTRIM(l.Ref)) AS Ref,
        LTRIM(RTRIM(ISNULL(st.design, ''))) AS Design,
        l.QuantidadePrevista,
        ISNULL(a.QuantidadeAlocada, 0) AS QuantidadeAlocada,
        (l.QuantidadePrevista - ISNULL(a.QuantidadeAlocada, 0)) AS QuantidadeDisponivel
    FROM dbo.u_HcaPrevEntradaLin l WITH (NOLOCK)
    LEFT JOIN dbo.st st WITH (NOLOCK)
        ON LTRIM(RTRIM(st.ref)) COLLATE DATABASE_DEFAULT
         = LTRIM(RTRIM(l.Ref)) COLLATE DATABASE_DEFAULT
    OUTER APPLY (
        SELECT SUM(ISNULL(bi2.u_qtdaut, 0)) AS QuantidadeAlocada
        FROM dbo.bi2 bi2 WITH (NOLOCK)
        INNER JOIN dbo.bi bi WITH (NOLOCK)
            ON bi.bistamp COLLATE DATABASE_DEFAULT = bi2.bi2stamp COLLATE DATABASE_DEFAULT
        WHERE LTRIM(RTRIM(ISNULL(bi2.u_previd, ''))) COLLATE DATABASE_DEFAULT
              = @prevIdStr COLLATE DATABASE_DEFAULT
          AND LTRIM(RTRIM(bi.ref)) COLLATE DATABASE_DEFAULT
              = LTRIM(RTRIM(l.Ref)) COLLATE DATABASE_DEFAULT
    ) a
    WHERE l.PrevisaoId = @id
    ORDER BY LTRIM(RTRIM(l.Ref));
END;
GO
