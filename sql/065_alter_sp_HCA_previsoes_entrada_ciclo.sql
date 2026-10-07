-- =============================================================================
-- Liliana & Seródio — Portal Logístico
-- Script: 065_alter_sp_HCA_previsoes_entrada_ciclo.sql
-- Ambiente: UAT primeiro; Produção só no GO formal
-- Pré-requisito: 064_alter_u_HcaPrevEntrada_ciclo.sql
-- =============================================================================
-- PR1 — Estado Aberta/Fechada, anti-overlap inclusivo, no máximo 1 aberta.
-- Não implementa fecho/transferência, u_prevId nem tecto por previsão.
-- =============================================================================

SET NOCOUNT ON;
GO

CREATE OR ALTER PROCEDURE dbo.sp_HCA_prev_entrada_listar
AS
BEGIN
    SET NOCOUNT ON;

    SELECT
        p.Id,
        p.DataInicio,
        p.DataFim,
        CAST(p.Fechada AS bit) AS Fechada,
        p.FechadaEm,
        LTRIM(RTRIM(ISNULL(p.FechadaPor, N''))) AS FechadaPor,
        COUNT(l.Id) AS TotalLinhas,
        ISNULL(SUM(l.QuantidadePrevista), 0) AS QuantidadeTotal
    FROM dbo.u_HcaPrevEntrada p WITH (NOLOCK)
    LEFT JOIN dbo.u_HcaPrevEntradaLin l WITH (NOLOCK)
        ON l.PrevisaoId = p.Id
    GROUP BY
        p.Id,
        p.DataInicio,
        p.DataFim,
        p.Fechada,
        p.FechadaEm,
        p.FechadaPor
    ORDER BY p.DataInicio DESC, p.DataFim DESC;
END;
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

    SELECT
        l.Id,
        l.PrevisaoId,
        LTRIM(RTRIM(l.Ref)) AS Ref,
        LTRIM(RTRIM(ISNULL(st.design, ''))) AS Design,
        l.QuantidadePrevista
    FROM dbo.u_HcaPrevEntradaLin l WITH (NOLOCK)
    LEFT JOIN dbo.st st WITH (NOLOCK)
        ON LTRIM(RTRIM(st.ref)) = LTRIM(RTRIM(l.Ref))
    WHERE l.PrevisaoId = @id
    ORDER BY LTRIM(RTRIM(l.Ref));
END;
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

CREATE OR ALTER PROCEDURE dbo.sp_HCA_prev_entrada_guardar
    @id         uniqueidentifier,
    @usrlogin   nvarchar(100),
    @linhas     nvarchar(max), -- JSON: [{"ref":"…","quantidadePrevista":0}]
    @dataInicio date = NULL,
    @dataFim    date = NULL
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    BEGIN TRAN;

    DECLARE
        @fechada bit,
        @diAtual date,
        @dfAtual date;

    SELECT
        @fechada = Fechada,
        @diAtual = DataInicio,
        @dfAtual = DataFim
    FROM dbo.u_HcaPrevEntrada WITH (UPDLOCK, HOLDLOCK)
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
        RAISERROR(N'Previsão fechada: não pode ser alterada.', 16, 1);
        RETURN;
    END;

    IF @dataInicio IS NULL
        SET @dataInicio = @diAtual;
    IF @dataFim IS NULL
        SET @dataFim = @dfAtual;

    IF @dataInicio > @dataFim
    BEGIN
        ROLLBACK;
        RAISERROR(N'A data de início não pode ser posterior à data de fim.', 16, 1);
        RETURN;
    END;

    IF EXISTS (
        SELECT 1
        FROM dbo.u_HcaPrevEntrada WITH (UPDLOCK, HOLDLOCK)
        WHERE Id <> @id
          AND DataInicio <= @dataFim
          AND DataFim >= @dataInicio
    )
    BEGIN
        ROLLBACK;
        RAISERROR(N'Já existe uma previsão com período sobreposto a estas datas.', 16, 1);
        RETURN;
    END;

    UPDATE dbo.u_HcaPrevEntrada
    SET DataInicio = @dataInicio,
        DataFim = @dataFim,
        AlteradoEm = SYSUTCDATETIME(),
        AlteradoPor = LEFT(LTRIM(RTRIM(ISNULL(@usrlogin, N''))), 100)
    WHERE Id = @id;

    DELETE FROM dbo.u_HcaPrevEntradaLin WHERE PrevisaoId = @id;

    IF @linhas IS NOT NULL AND LTRIM(RTRIM(@linhas)) <> N'' AND LTRIM(RTRIM(@linhas)) <> N'[]'
    BEGIN
        ;WITH src AS (
            SELECT
                LTRIM(RTRIM(j.ref)) AS Ref,
                CAST(j.quantidadePrevista AS numeric(16, 2)) AS QuantidadePrevista
            FROM OPENJSON(@linhas)
            WITH (
                ref nvarchar(40) '$.ref',
                quantidadePrevista float '$.quantidadePrevista'
            ) j
        )
        INSERT INTO dbo.u_HcaPrevEntradaLin (PrevisaoId, Ref, QuantidadePrevista)
        SELECT
            @id,
            LEFT(s.Ref, 18),
            CASE WHEN s.QuantidadePrevista < 0 THEN 0 ELSE s.QuantidadePrevista END
        FROM src s
        WHERE s.Ref <> N''
          AND EXISTS (
              SELECT 1
              FROM dbo.stobs o WITH (NOLOCK)
              WHERE LTRIM(RTRIM(o.ref)) = s.Ref
                AND CAST(ISNULL(o.u_dispPort, 0) AS bit) = 1
          );
    END;

    COMMIT TRAN;

    EXEC dbo.sp_HCA_prev_entrada_obter @id = @id;
END;
GO
