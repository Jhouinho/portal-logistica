-- =============================================================================
-- Liliana & Seródio — Portal Logístico
-- Script: 079_alter_sp_HCA_prev_entrada_criar_seed_linhas.sql
-- Ambiente: UAT primeiro; Produção só no GO formal
-- Pré-requisito: 075 (Cor); 076 (obter/guardar Ref+Cor)
-- =============================================================================
-- Ao criar previsão: pré-preenche linhas (Ref + Cor) a partir de encomendas
-- abertas no período (ndos=1, fechada=0, dataobra no intervalo),
-- apenas artigos com STOBS.u_dispPort=1 e restante > 0.
-- QuantidadePrevista = 0 (operador preenche depois).
-- Semântica de Cor = BI.u_cor (exacta, sem TRIM).
-- =============================================================================

SET NOCOUNT ON;
GO

/* Filtered index IX_u_HcaPrevEntrada_Fechada requires these ON at CREATE time. */
SET ANSI_NULLS ON;
SET QUOTED_IDENTIFIER ON;
GO

CREATE OR ALTER PROCEDURE dbo.sp_HCA_prev_entrada_criar
    @dataInicio date,
    @dataFim    date,
    @usrlogin   nvarchar(100),
    @id         uniqueidentifier OUTPUT
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    IF @dataInicio IS NULL OR @dataFim IS NULL
    BEGIN
        RAISERROR(N'Data início e data fim são obrigatórias.', 16, 1);
        RETURN;
    END;

    IF @dataInicio > @dataFim
    BEGIN
        RAISERROR(N'A data de início não pode ser posterior à data de fim.', 16, 1);
        RETURN;
    END;

    BEGIN TRAN;

    IF EXISTS (
        SELECT 1
        FROM dbo.u_HcaPrevEntrada WITH (UPDLOCK, HOLDLOCK)
        WHERE Fechada = 0
    )
    BEGIN
        ROLLBACK;
        RAISERROR(N'Já existe uma previsão aberta. Feche-a antes de criar outra.', 16, 1);
        RETURN;
    END;

    IF EXISTS (
        SELECT 1
        FROM dbo.u_HcaPrevEntrada WITH (UPDLOCK, HOLDLOCK)
        WHERE DataInicio <= @dataFim
          AND DataFim >= @dataInicio
    )
    BEGIN
        ROLLBACK;
        RAISERROR(N'Já existe uma previsão com período sobreposto a estas datas.', 16, 1);
        RETURN;
    END;

    DECLARE @out TABLE (Id uniqueidentifier NOT NULL);

    INSERT INTO dbo.u_HcaPrevEntrada (
        DataInicio,
        DataFim,
        CriadoEm,
        CriadoPor,
        Fechada,
        FechadaEm,
        FechadaPor
    )
    OUTPUT inserted.Id INTO @out
    VALUES (
        @dataInicio,
        @dataFim,
        SYSUTCDATETIME(),
        LEFT(LTRIM(RTRIM(ISNULL(@usrlogin, N''))), 100),
        0,
        NULL,
        NULL
    );

    SELECT @id = Id FROM @out;

    /* Seed: Ref + Cor distintos das encomendas abertas no período. */
    INSERT INTO dbo.u_HcaPrevEntradaLin (PrevisaoId, Ref, Cor, QuantidadePrevista)
    SELECT DISTINCT
        @id,
        LEFT(LTRIM(RTRIM(bi.ref)), 18),
        bi.u_cor,
        CAST(0 AS numeric(16, 2))
    FROM dbo.bi bi WITH (NOLOCK)
    INNER JOIN dbo.bo bo WITH (NOLOCK)
        ON bo.bostamp COLLATE DATABASE_DEFAULT = bi.bostamp COLLATE DATABASE_DEFAULT
    LEFT JOIN dbo.bi2 bi2 WITH (NOLOCK)
        ON bi2.bi2stamp COLLATE DATABASE_DEFAULT = bi.bistamp COLLATE DATABASE_DEFAULT
    INNER JOIN dbo.stobs o WITH (NOLOCK)
        ON LTRIM(RTRIM(o.ref)) COLLATE DATABASE_DEFAULT
         = LTRIM(RTRIM(bi.ref)) COLLATE DATABASE_DEFAULT
    WHERE bo.ndos = 1
      AND ISNULL(bo.fechada, 0) = 0
      AND CAST(bo.dataobra AS date) >= @dataInicio
      AND CAST(bo.dataobra AS date) <= @dataFim
      AND CAST(ISNULL(o.u_dispPort, 0) AS bit) = 1
      AND LTRIM(RTRIM(ISNULL(bi.ref, ''))) <> ''
      AND (ISNULL(NULLIF(bi2.u_qttorig, 0), bi.qtt) - bi.qtt2) > 0;

    COMMIT TRAN;

    SELECT
        @id AS Id,
        @dataInicio AS DataInicio,
        @dataFim AS DataFim,
        CAST(0 AS bit) AS Fechada,
        CAST(NULL AS datetime2(0)) AS FechadaEm,
        CAST(N'' AS nvarchar(100)) AS FechadaPor;
END;
GO
