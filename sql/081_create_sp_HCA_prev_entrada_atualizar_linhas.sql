-- =============================================================================
-- Liliana & Seródio — Portal Logístico
-- Script: 081_create_sp_HCA_prev_entrada_atualizar_linhas.sql
-- Ambiente: UAT primeiro; Produção só no GO formal
-- Pré-requisito: 075 (Cor); 076 (obter); 079 (seed na criação)
-- =============================================================================
-- Actualiza previsão ABERTA: adiciona Ref+Cor novos das encomendas abertas
-- no período da previsão. Linhas já existentes NÃO são alteradas
-- (quantidade prevista / cor / ref mantêm-se).
-- =============================================================================

SET NOCOUNT ON;
GO

SET ANSI_NULLS ON;
SET QUOTED_IDENTIFIER ON;
GO

CREATE OR ALTER PROCEDURE dbo.sp_HCA_prev_entrada_atualizar_linhas
    @id       uniqueidentifier,
    @usrlogin nvarchar(100)
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    BEGIN TRAN;

    DECLARE
        @fechada bit,
        @dataInicio date,
        @dataFim date,
        @adicionadas int = 0;

    SELECT
        @fechada = Fechada,
        @dataInicio = DataInicio,
        @dataFim = DataFim
    FROM dbo.u_HcaPrevEntrada WITH (UPDLOCK, ROWLOCK)
    WHERE Id = @id;

    IF @fechada IS NULL
    BEGIN
        ROLLBACK;
        RAISERROR(N'Previsão não encontrada.', 16, 1);
        RETURN;
    END;

    IF @fechada = 1
    BEGIN
        ROLLBACK;
        RAISERROR(N'Previsão fechada: não pode ser actualizada.', 16, 1);
        RETURN;
    END;

    ;WITH candidatos AS (
        SELECT DISTINCT
            LEFT(LTRIM(RTRIM(bi.ref)), 18) AS Ref,
            ISNULL(bi.u_cor, '') AS Cor
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
          AND (ISNULL(NULLIF(bi2.u_qttorig, 0), bi.qtt) - bi.qtt2) > 0
    )
    INSERT INTO dbo.u_HcaPrevEntradaLin (PrevisaoId, Ref, Cor, QuantidadePrevista)
    SELECT
        @id,
        c.Ref,
        c.Cor,
        CAST(0 AS numeric(16, 2))
    FROM candidatos c
    WHERE NOT EXISTS (
        SELECT 1
        FROM dbo.u_HcaPrevEntradaLin l WITH (UPDLOCK, HOLDLOCK)
        WHERE l.PrevisaoId = @id
          AND LTRIM(RTRIM(l.Ref)) COLLATE DATABASE_DEFAULT
              = c.Ref COLLATE DATABASE_DEFAULT
          AND l.Cor COLLATE DATABASE_DEFAULT = c.Cor COLLATE DATABASE_DEFAULT
    );

    SET @adicionadas = @@ROWCOUNT;

    UPDATE dbo.u_HcaPrevEntrada
    SET AlteradoEm = SYSUTCDATETIME(),
        AlteradoPor = LEFT(LTRIM(RTRIM(ISNULL(@usrlogin, N''))), 100)
    WHERE Id = @id;

    COMMIT TRAN;

    /* 1º RS: número de linhas novas (para mensagem UI). */
    SELECT @adicionadas AS LinhasAdicionadas;

    EXEC dbo.sp_HCA_prev_entrada_obter @id = @id;
END;
GO

IF EXISTS (SELECT 1 FROM sys.database_principals WHERE name = N'portal_app')
    GRANT EXECUTE ON dbo.sp_HCA_prev_entrada_atualizar_linhas TO [portal_app];
GO
