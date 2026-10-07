-- =============================================================================
-- Liliana & Seródio — Portal Logístico
-- Script: 085_alter_sp_HCA_prev_entrada_obter_perf.sql
-- Ambiente: UAT / teste; Produção só no GO formal
-- Pré-requisito: 076 (obter Ref+Cor + consumo)
-- =============================================================================
-- Performance:
--   1) CTE/Alocado agregado uma vez (sem OUTER APPLY por linha)
--   2) Sem COLLATE em joins (colunas já SQL_Latin1_General_CP1_CI_AI)
--   3) #Alocado materializado — evita plano cacheado mau no JOIN bi/bi2
-- Semântica inalterada:
--   Alocado = SUM(BI2.u_qtdaut) WHERE u_previd=P AND BI.ref=Ref AND BI.u_cor=Cor
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

    -- Colunas com collation das tabelas PHC (tempdb pode ser CI_AS)
    CREATE TABLE #Alocado (
        Ref varchar(18) COLLATE SQL_Latin1_General_CP1_CI_AI NOT NULL,
        Cor varchar(50) COLLATE SQL_Latin1_General_CP1_CI_AI NOT NULL,
        QuantidadeAlocada decimal(18, 3) NOT NULL
    );

    INSERT INTO #Alocado (Ref, Cor, QuantidadeAlocada)
    SELECT
        LTRIM(RTRIM(bi.ref)),
        bi.u_cor,
        SUM(ISNULL(bi2.u_qtdaut, 0))
    FROM dbo.bi2 bi2 WITH (NOLOCK)
    INNER JOIN dbo.bi bi WITH (NOLOCK)
        ON bi.bistamp = bi2.bi2stamp
    WHERE bi2.u_previd = @prevIdStr
    GROUP BY
        LTRIM(RTRIM(bi.ref)),
        bi.u_cor;

    SELECT
        l.Id,
        l.PrevisaoId,
        LTRIM(RTRIM(l.Ref)) AS Ref,
        l.Cor AS Cor,
        LTRIM(RTRIM(ISNULL(st.design, ''))) AS Design,
        l.QuantidadePrevista,
        ISNULL(a.QuantidadeAlocada, 0) AS QuantidadeAlocada,
        (l.QuantidadePrevista - ISNULL(a.QuantidadeAlocada, 0)) AS QuantidadeDisponivel
    FROM dbo.u_HcaPrevEntradaLin l WITH (NOLOCK)
    LEFT JOIN dbo.st st WITH (NOLOCK)
        ON st.ref = l.Ref
    LEFT JOIN #Alocado a
        ON a.Ref = LTRIM(RTRIM(l.Ref))
       AND a.Cor = l.Cor
    WHERE l.PrevisaoId = @id
    ORDER BY LTRIM(RTRIM(l.Ref)), l.Cor;

    DROP TABLE #Alocado;
END;
GO
