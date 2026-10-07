-- =============================================================================
-- Liliana & Seródio — Portal Logístico
-- Script: 063_create_sp_HCA_previsoes_entrada.sql
-- Ambiente: UAT primeiro; Produção só no GO formal
-- Pré-requisito: 062_create_u_HcaPrevEntrada_tables.sql
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
        COUNT(l.Id) AS TotalLinhas,
        ISNULL(SUM(l.QuantidadePrevista), 0) AS QuantidadeTotal
    FROM dbo.u_HcaPrevEntrada p WITH (NOLOCK)
    LEFT JOIN dbo.u_HcaPrevEntradaLin l WITH (NOLOCK)
        ON l.PrevisaoId = p.Id
    GROUP BY p.Id, p.DataInicio, p.DataFim
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
        p.DataFim
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

    IF EXISTS (
        SELECT 1
        FROM dbo.u_HcaPrevEntrada WITH (UPDLOCK, HOLDLOCK)
        WHERE DataInicio = @dataInicio AND DataFim = @dataFim
    )
    BEGIN
        RAISERROR(N'Já existe uma previsão para este período (mesma data de início e fim).', 16, 1);
        RETURN;
    END;

    DECLARE @out TABLE (Id uniqueidentifier NOT NULL);

    INSERT INTO dbo.u_HcaPrevEntrada (DataInicio, DataFim, CriadoEm, CriadoPor)
    OUTPUT inserted.Id INTO @out
    VALUES (
        @dataInicio,
        @dataFim,
        SYSUTCDATETIME(),
        LEFT(LTRIM(RTRIM(ISNULL(@usrlogin, N''))), 100)
    );

    SELECT @id = Id FROM @out;

    SELECT @id AS Id, @dataInicio AS DataInicio, @dataFim AS DataFim;
END;
GO

CREATE OR ALTER PROCEDURE dbo.sp_HCA_prev_entrada_guardar
    @id       uniqueidentifier,
    @usrlogin nvarchar(100),
    @linhas   nvarchar(max) -- JSON: [{"ref":"…","quantidadePrevista":0}]
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    IF NOT EXISTS (SELECT 1 FROM dbo.u_HcaPrevEntrada WHERE Id = @id)
    BEGIN
        RAISERROR(N'Previsão não encontrada.', 16, 1);
        RETURN;
    END;

    BEGIN TRAN;

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
        -- Id via DEFAULT (NEWSEQUENTIALID) — não usar NEWSEQUENTIALID() no SELECT
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

    UPDATE dbo.u_HcaPrevEntrada
    SET AlteradoEm = SYSUTCDATETIME(),
        AlteradoPor = LEFT(LTRIM(RTRIM(ISNULL(@usrlogin, N''))), 100)
    WHERE Id = @id;

    COMMIT TRAN;

    EXEC dbo.sp_HCA_prev_entrada_obter @id = @id;
END;
GO

CREATE OR ALTER PROCEDURE dbo.sp_HCA_prev_entrada_sugerir_artigos
    @q     nvarchar(100),
    @limit int = 20
AS
BEGIN
    SET NOCOUNT ON;

    IF @q IS NULL OR LTRIM(RTRIM(@q)) = N''
    BEGIN
        SELECT CAST(NULL AS varchar(18)) AS Ref, CAST(NULL AS varchar(60)) AS Design
        WHERE 1 = 0;
        RETURN;
    END;

    IF @limit IS NULL OR @limit < 1 SET @limit = 20;
    IF @limit > 50 SET @limit = 50;

    DECLARE @padrao nvarchar(110) = N'%' + REPLACE(REPLACE(REPLACE(LTRIM(RTRIM(@q)), N'[', N'[[]'), N'%', N'[%]'), N'_', N'[_]') + N'%';

    SELECT TOP (@limit)
        LTRIM(RTRIM(st.ref)) AS Ref,
        LTRIM(RTRIM(ISNULL(st.design, ''))) AS Design
    FROM dbo.st st WITH (NOLOCK)
    INNER JOIN dbo.stobs o WITH (NOLOCK)
        ON LTRIM(RTRIM(o.ref)) = LTRIM(RTRIM(st.ref))
    WHERE CAST(ISNULL(o.u_dispPort, 0) AS bit) = 1
      AND (
           LTRIM(RTRIM(st.ref)) LIKE @padrao
        OR LTRIM(RTRIM(ISNULL(st.design, ''))) LIKE @padrao
      )
    ORDER BY LTRIM(RTRIM(st.ref));
END;
GO
