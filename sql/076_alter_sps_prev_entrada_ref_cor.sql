-- =============================================================================
-- Liliana & Seródio — Portal Logístico
-- Script: 076_alter_sps_prev_entrada_ref_cor.sql
-- Ambiente: UAT primeiro; Produção só no GO formal
-- Pré-requisito: 075 (Cor + UQ Ref+Cor); 073 (u_prevId ''); 074 (obter consumo)
-- =============================================================================
-- PR2-A2 — Capacidade / autorizar / alocar / obter / guardar por Ref + Cor.
--   Alocado = SUM(BI2.u_qtdaut) WHERE u_previd=P AND BI.ref=Ref AND BI.u_cor=Cor
--   Relação: BI2.bi2stamp = BI.bistamp. Sem BI2.ref. Sem ST.stock. Sem filtro ndos
--   no consumo. Comparação de Cor exacta com BI.u_cor (NOT NULL, sem TRIM/UPPER).
-- =============================================================================

SET NOCOUNT ON;
GO

/* ---------- obter: devolve Cor + Alocado/Disponível por Ref+Cor ---------- */
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
        l.Cor AS Cor,
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
          AND bi.u_cor COLLATE DATABASE_DEFAULT = l.Cor COLLATE DATABASE_DEFAULT
    ) a
    WHERE l.PrevisaoId = @id
    ORDER BY LTRIM(RTRIM(l.Ref)), l.Cor;
END;
GO

/* ---------- guardar: JSON inclui cor; unicidade PrevisaoId+Ref+Cor ---------- */
CREATE OR ALTER PROCEDURE dbo.sp_HCA_prev_entrada_guardar
    @id         uniqueidentifier,
    @usrlogin   nvarchar(100),
    @linhas     nvarchar(max), -- JSON: [{"ref":"…","cor":"…","quantidadePrevista":0}]
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
                /* Cor: sem TRIM — mesma semântica de BI.u_cor (NOT NULL). */
                ISNULL(j.cor, '') AS Cor,
                CAST(j.quantidadePrevista AS numeric(16, 2)) AS QuantidadePrevista
            FROM OPENJSON(@linhas)
            WITH (
                ref nvarchar(40) '$.ref',
                cor nvarchar(100) '$.cor',
                quantidadePrevista float '$.quantidadePrevista'
            ) j
        ),
        dedup AS (
            SELECT
                Ref,
                Cor,
                QuantidadePrevista,
                ROW_NUMBER() OVER (
                    PARTITION BY Ref, Cor
                    ORDER BY (SELECT NULL)
                ) AS rn
            FROM src
            WHERE Ref <> N''
        )
        INSERT INTO dbo.u_HcaPrevEntradaLin (PrevisaoId, Ref, Cor, QuantidadePrevista)
        SELECT
            @id,
            LEFT(d.Ref, 18),
            LEFT(d.Cor, 100),
            CASE WHEN d.QuantidadePrevista < 0 THEN 0 ELSE d.QuantidadePrevista END
        FROM dedup d
        WHERE d.rn = 1
          AND EXISTS (
              SELECT 1
              FROM dbo.stobs o WITH (NOLOCK)
              WHERE LTRIM(RTRIM(o.ref)) = d.Ref
                AND CAST(ISNULL(o.u_dispPort, 0) AS bit) = 1
          );
    END;

    COMMIT TRAN;

    EXEC dbo.sp_HCA_prev_entrada_obter @id = @id;
END;
GO

/* ---------- sugestões de cor a partir de BI.u_cor (sem catálogo novo) ---------- */
CREATE OR ALTER PROCEDURE dbo.sp_HCA_prev_entrada_sugerir_cores
    @ref   varchar(18),
    @q     nvarchar(100) = NULL,
    @limit int = 30
AS
BEGIN
    SET NOCOUNT ON;

    IF @ref IS NULL OR LTRIM(RTRIM(@ref)) = ''
    BEGIN
        SELECT CAST(NULL AS varchar(100)) AS Cor WHERE 1 = 0;
        RETURN;
    END;

    IF @limit IS NULL OR @limit < 1 SET @limit = 30;
    IF @limit > 100 SET @limit = 100;

    DECLARE
        @ref_n varchar(18) = LTRIM(RTRIM(@ref)),
        @padrao nvarchar(110) = NULL;

    IF @q IS NOT NULL AND LTRIM(RTRIM(@q)) <> N''
        SET @padrao = N'%' + REPLACE(REPLACE(REPLACE(LTRIM(RTRIM(@q)), N'[', N'[[]'), N'%', N'[%]'), N'_', N'[_]') + N'%';

    SELECT TOP (@limit)
        c.Cor
    FROM (
        SELECT DISTINCT bi.u_cor AS Cor
        FROM dbo.bi bi WITH (NOLOCK)
        INNER JOIN dbo.stobs o WITH (NOLOCK)
            ON LTRIM(RTRIM(o.ref)) COLLATE DATABASE_DEFAULT
             = LTRIM(RTRIM(bi.ref)) COLLATE DATABASE_DEFAULT
        WHERE LTRIM(RTRIM(bi.ref)) COLLATE DATABASE_DEFAULT = @ref_n COLLATE DATABASE_DEFAULT
          AND CAST(ISNULL(o.u_dispPort, 0) AS bit) = 1
          AND (
                @padrao IS NULL
             OR bi.u_cor LIKE @padrao
          )
    ) c
    ORDER BY CASE WHEN c.Cor = '' THEN 0 ELSE 1 END, c.Cor;
END;
GO

/* ---------- autorizar por Ref + Cor ---------- */
CREATE OR ALTER PROCEDURE dbo.sp_HCA_atualizar_qtd_autorizada
    @bistamp                   varchar(25),
    @quantidade_autorizada     numeric(16, 2),
    @usrlogin                  varchar(100),
    @valor_anterior_esperado   numeric(16, 2) = NULL,
    @permitir_acima_stock      bit = 0,  -- legado API; ignorado (sem bypass da previsão)
    @usrinis                   varchar(3) = NULL
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    IF @bistamp IS NULL OR LTRIM(RTRIM(@bistamp)) = ''
    BEGIN
        RAISERROR(N'bistamp obrigatório.', 16, 1);
        RETURN;
    END;

    IF @quantidade_autorizada IS NULL OR @quantidade_autorizada < 0
    BEGIN
        RAISERROR(N'quantidade_autorizada inválida.', 16, 1);
        RETURN;
    END;

    IF @usrlogin IS NULL OR LTRIM(RTRIM(@usrlogin)) = ''
    BEGIN
        RAISERROR(N'usrlogin obrigatório.', 16, 1);
        RETURN;
    END;

    SET @permitir_acima_stock = ISNULL(@permitir_acima_stock, 0);

    DECLARE
        @ref varchar(18),
        @cor varchar(100),
        @bostamp varchar(25),
        @u_qtdaut_atual numeric(16, 2),
        @u_qtdautur_atual varchar(100),
        @qtt_atual numeric(16, 2),
        @edebito_atual numeric(16, 2),
        @primeira_autorizacao bit,
        @pickstat int,
        @prevIdAtual varchar(50),
        @prevIdGuid uniqueidentifier,
        @prevIdStr varchar(50),
        @fechada bit,
        @previsto numeric(16, 2),
        @alocado_outros numeric(16, 2),
        @disponivel numeric(16, 2),
        @tem_linha_prev bit,
        @agora datetime = GETDATE(),
        @usrdata datetime,
        @usrhora varchar(8),
        @usrinis_n varchar(3),
        @msg nvarchar(400);

    SET @usrdata = CAST(@agora AS date);
    SET @usrhora = CONVERT(varchar(8), @agora, 108);
    SET @usrinis_n = LEFT(LTRIM(RTRIM(ISNULL(NULLIF(@usrinis, ''), @usrlogin))), 3);

    BEGIN TRAN;

    SELECT
        @ref = LTRIM(RTRIM(bi.ref)),
        @cor = bi.u_cor, /* exacto; sem TRIM */
        @bostamp = bi.bostamp,
        @u_qtdaut_atual = ISNULL(bi2.u_qtdaut, 0),
        @u_qtdautur_atual = ISNULL(bi2.u_qtdautur, ''),
        @qtt_atual = bi.qtt,
        @edebito_atual = bi.edebito,
        @prevIdAtual = LTRIM(RTRIM(ISNULL(bi2.u_prevId, ''))),
        @pickstat = CAST(ISNULL(bo3.u_pickstat, 0) AS int)
    FROM dbo.bi bi WITH (UPDLOCK, ROWLOCK)
    INNER JOIN dbo.bo bo WITH (UPDLOCK, ROWLOCK)
        ON bo.bostamp COLLATE DATABASE_DEFAULT = bi.bostamp COLLATE DATABASE_DEFAULT
    LEFT JOIN dbo.bi2 bi2 WITH (UPDLOCK, ROWLOCK)
        ON bi2.bi2stamp COLLATE DATABASE_DEFAULT = bi.bistamp COLLATE DATABASE_DEFAULT
    LEFT JOIN dbo.bo3 bo3 WITH (UPDLOCK, ROWLOCK)
        ON bo3.bo3stamp COLLATE DATABASE_DEFAULT = bo.bostamp COLLATE DATABASE_DEFAULT
    WHERE bi.bistamp COLLATE DATABASE_DEFAULT = @bistamp COLLATE DATABASE_DEFAULT
      AND bo.ndos = 1
      AND ISNULL(bo.fechada, 0) = 0;

    IF @ref IS NULL
    BEGIN
        ROLLBACK;
        RAISERROR(N'Linha não encontrada ou documento fechado/série inválida.', 16, 1);
        RETURN;
    END;

    SET @cor = ISNULL(@cor, '');

    IF NOT EXISTS (
        SELECT 1 FROM dbo.bi2 WITH (UPDLOCK, ROWLOCK)
        WHERE bi2stamp COLLATE DATABASE_DEFAULT = @bistamp COLLATE DATABASE_DEFAULT
    )
    BEGIN
        INSERT INTO dbo.bi2 (bi2stamp)
        VALUES (@bistamp);
        SET @prevIdAtual = '';
        SET @u_qtdaut_atual = 0;
        SET @u_qtdautur_atual = '';
    END;

    IF @valor_anterior_esperado IS NOT NULL AND @u_qtdaut_atual <> @valor_anterior_esperado
    BEGIN
        ROLLBACK;
        RAISERROR(N'Conflito de concorrência na quantidade autorizada.', 16, 1);
        RETURN;
    END;

    IF ISNULL(@pickstat, 0) >= 1
    BEGIN
        ROLLBACK;
        RAISERROR(N'Quantidade autorizada congelada (pronta para picking).', 16, 1);
        RETURN;
    END;

    SET @primeira_autorizacao = CASE
        WHEN LTRIM(RTRIM(ISNULL(@u_qtdautur_atual, ''))) = '' THEN 1
        ELSE 0
    END;

    /* ---------- Zero: libertar consumo; limpar u_prevId ---------- */
    IF @quantidade_autorizada = 0
    BEGIN
        IF @primeira_autorizacao = 1
        BEGIN
            UPDATE dbo.bi2
            SET u_qttorig = CASE
                WHEN ISNULL(u_qttorig, 0) = 0 THEN @qtt_atual
                ELSE u_qttorig
            END
            WHERE bi2stamp COLLATE DATABASE_DEFAULT = @bistamp COLLATE DATABASE_DEFAULT;

            UPDATE dbo.bi
            SET
                qtt = 0,
                ettdeb = 0,
                usrinis = @usrinis_n,
                usrdata = @usrdata,
                usrhora = @usrhora
            WHERE bistamp COLLATE DATABASE_DEFAULT = @bistamp COLLATE DATABASE_DEFAULT;

            UPDATE dbo.bo
            SET
                usrinis = @usrinis_n,
                usrdata = @usrdata,
                usrhora = @usrhora
            WHERE bostamp COLLATE DATABASE_DEFAULT = @bostamp COLLATE DATABASE_DEFAULT;
        END;

        UPDATE dbo.bi2
        SET
            u_qtdaut = 0,
            u_qtdautur = LEFT(LTRIM(RTRIM(@usrlogin)), 100),
            u_qtdautdt = @agora,
            u_prevId = ''
        WHERE bi2stamp COLLATE DATABASE_DEFAULT = @bistamp COLLATE DATABASE_DEFAULT;

        COMMIT;

        SELECT
            bi.bistamp,
            bi.bostamp,
            LTRIM(RTRIM(bi.ref)) AS ref,
            bi.u_cor AS cor,
            ISNULL(bi2.u_qtdaut, 0) AS quantidade_autorizada,
            LTRIM(RTRIM(ISNULL(bi2.u_qtdautur, ''))) AS quantidade_autorizada_por,
            bi2.u_qtdautdt AS quantidade_autorizada_em,
            bi.qtt AS quantidade_atual,
            ISNULL(bi2.u_qttorig, 0) AS quantidade_original_campo,
            ISNULL(NULLIF(bi2.u_qttorig, 0), bi.qtt) AS quantidade_original_considerada,
            bi.qtt2 AS quantidade_fornecida,
            CAST(0 AS numeric(16, 2)) AS stock_disponivel,
            CAST(0 AS numeric(16, 2)) AS soma_autorizada_artigo,
            @primeira_autorizacao AS primeira_autorizacao,
            CAST('' AS varchar(50)) AS u_prevId,
            CAST(0 AS numeric(16, 2)) AS previsto,
            CAST(0 AS numeric(16, 2)) AS alocado,
            CAST(0 AS numeric(16, 2)) AS disponivel_previsao
        FROM dbo.bi bi WITH (NOLOCK)
        LEFT JOIN dbo.bi2 bi2 WITH (NOLOCK)
            ON bi2.bi2stamp COLLATE DATABASE_DEFAULT = bi.bistamp COLLATE DATABASE_DEFAULT
        WHERE bi.bistamp COLLATE DATABASE_DEFAULT = @bistamp COLLATE DATABASE_DEFAULT;

        RETURN;
    END;

    /* ---------- qty > 0: associar / manter previsão e validar capacidade ---------- */
    SET @prevIdGuid = NULL;
    SET @prevIdStr = NULL;
    SET @fechada = NULL;

    IF @prevIdAtual <> ''
    BEGIN
        SET @prevIdGuid = TRY_CONVERT(uniqueidentifier, @prevIdAtual);
        IF @prevIdGuid IS NULL
        BEGIN
            ROLLBACK;
            RAISERROR(N'A autorização está associada a uma previsão fechada.', 16, 1);
            RETURN;
        END;

        SELECT
            @fechada = CAST(ISNULL(p.Fechada, 0) AS bit),
            @prevIdStr = CONVERT(varchar(36), p.Id)
        FROM dbo.u_HcaPrevEntrada p WITH (UPDLOCK, ROWLOCK)
        WHERE p.Id = @prevIdGuid;

        IF @prevIdStr IS NULL
        BEGIN
            ROLLBACK;
            RAISERROR(N'A autorização está associada a uma previsão fechada.', 16, 1);
            RETURN;
        END;

        IF ISNULL(@fechada, 1) = 1
        BEGIN
            ROLLBACK;
            RAISERROR(N'A autorização está associada a uma previsão fechada.', 16, 1);
            RETURN;
        END;
    END
    ELSE
    BEGIN
        SELECT TOP (1)
            @prevIdGuid = p.Id,
            @prevIdStr = CONVERT(varchar(36), p.Id)
        FROM dbo.u_HcaPrevEntrada p WITH (UPDLOCK, ROWLOCK)
        WHERE ISNULL(p.Fechada, 0) = 0
        ORDER BY p.DataInicio ASC, p.DataFim ASC;

        IF @prevIdGuid IS NULL
        BEGIN
            ROLLBACK;
            RAISERROR(N'Não existe uma previsão de entrada aberta.', 16, 1);
            RETURN;
        END;
    END;

    SET @tem_linha_prev = 0;
    SET @previsto = NULL;

    SELECT
        @tem_linha_prev = 1,
        @previsto = ISNULL(l.QuantidadePrevista, 0)
    FROM dbo.u_HcaPrevEntradaLin l WITH (UPDLOCK, ROWLOCK)
    WHERE l.PrevisaoId = @prevIdGuid
      AND LTRIM(RTRIM(l.Ref)) COLLATE DATABASE_DEFAULT = @ref COLLATE DATABASE_DEFAULT
      AND l.Cor COLLATE DATABASE_DEFAULT = @cor COLLATE DATABASE_DEFAULT;

    IF ISNULL(@tem_linha_prev, 0) = 0
    BEGIN
        ROLLBACK;
        SET @msg = N'A referência ' + @ref + N' não tem quantidade prevista registada.';
        RAISERROR(@msg, 16, 1);
        RETURN;
    END;

    SET @previsto = ISNULL(@previsto, 0);

    -- Alocado noutras linhas do mesmo ciclo+ref+cor (sem filtro ndos/fechada).
    SELECT @alocado_outros = ISNULL(SUM(ISNULL(bi2.u_qtdaut, 0)), 0)
    FROM dbo.bi2 bi2 WITH (UPDLOCK, ROWLOCK)
    INNER JOIN dbo.bi bi WITH (UPDLOCK, ROWLOCK)
        ON bi.bistamp COLLATE DATABASE_DEFAULT = bi2.bi2stamp COLLATE DATABASE_DEFAULT
    WHERE LTRIM(RTRIM(ISNULL(bi2.u_prevId, ''))) COLLATE DATABASE_DEFAULT
          = @prevIdStr COLLATE DATABASE_DEFAULT
      AND LTRIM(RTRIM(bi.ref)) COLLATE DATABASE_DEFAULT = @ref COLLATE DATABASE_DEFAULT
      AND bi.u_cor COLLATE DATABASE_DEFAULT = @cor COLLATE DATABASE_DEFAULT
      AND bi.bistamp COLLATE DATABASE_DEFAULT <> @bistamp COLLATE DATABASE_DEFAULT;

    SET @alocado_outros = ISNULL(@alocado_outros, 0);
    SET @disponivel = @previsto - @alocado_outros;

    IF (@alocado_outros + @quantidade_autorizada) > @previsto
    BEGIN
        ROLLBACK;
        SET @msg = N'Quantidade prevista insuficiente. Disponível: '
            + CONVERT(nvarchar(40), CAST(@disponivel AS numeric(16, 2))) + N'.';
        RAISERROR(@msg, 16, 1);
        RETURN;
    END;

    IF @primeira_autorizacao = 1
    BEGIN
        UPDATE dbo.bi2
        SET u_qttorig = CASE
            WHEN ISNULL(u_qttorig, 0) = 0 THEN @qtt_atual
            ELSE u_qttorig
        END
        WHERE bi2stamp COLLATE DATABASE_DEFAULT = @bistamp COLLATE DATABASE_DEFAULT;

        UPDATE dbo.bi
        SET
            qtt = @quantidade_autorizada,
            ettdeb = ROUND(@quantidade_autorizada * @edebito_atual, 2),
            usrinis = @usrinis_n,
            usrdata = @usrdata,
            usrhora = @usrhora
        WHERE bistamp COLLATE DATABASE_DEFAULT = @bistamp COLLATE DATABASE_DEFAULT;

        UPDATE dbo.bo
        SET
            usrinis = @usrinis_n,
            usrdata = @usrdata,
            usrhora = @usrhora
        WHERE bostamp COLLATE DATABASE_DEFAULT = @bostamp COLLATE DATABASE_DEFAULT;
    END;

    UPDATE dbo.bi2
    SET
        u_qtdaut = @quantidade_autorizada,
        u_qtdautur = LEFT(LTRIM(RTRIM(@usrlogin)), 100),
        u_qtdautdt = @agora,
        u_prevId = @prevIdStr
    WHERE bi2stamp COLLATE DATABASE_DEFAULT = @bistamp COLLATE DATABASE_DEFAULT;

    COMMIT;

    SELECT
        bi.bistamp,
        bi.bostamp,
        LTRIM(RTRIM(bi.ref)) AS ref,
        bi.u_cor AS cor,
        ISNULL(bi2.u_qtdaut, 0) AS quantidade_autorizada,
        LTRIM(RTRIM(ISNULL(bi2.u_qtdautur, ''))) AS quantidade_autorizada_por,
        bi2.u_qtdautdt AS quantidade_autorizada_em,
        bi.qtt AS quantidade_atual,
        ISNULL(bi2.u_qttorig, 0) AS quantidade_original_campo,
        ISNULL(NULLIF(bi2.u_qttorig, 0), bi.qtt) AS quantidade_original_considerada,
        bi.qtt2 AS quantidade_fornecida,
        (@previsto - (@alocado_outros + @quantidade_autorizada)) AS stock_disponivel,
        (@alocado_outros + @quantidade_autorizada) AS soma_autorizada_artigo,
        @primeira_autorizacao AS primeira_autorizacao,
        LTRIM(RTRIM(ISNULL(bi2.u_prevId, ''))) AS u_prevId,
        @previsto AS previsto,
        (@alocado_outros + @quantidade_autorizada) AS alocado,
        (@previsto - (@alocado_outros + @quantidade_autorizada)) AS disponivel_previsao
    FROM dbo.bi bi WITH (NOLOCK)
    LEFT JOIN dbo.bi2 bi2 WITH (NOLOCK)
        ON bi2.bi2stamp COLLATE DATABASE_DEFAULT = bi.bistamp COLLATE DATABASE_DEFAULT
    WHERE bi.bistamp COLLATE DATABASE_DEFAULT = @bistamp COLLATE DATABASE_DEFAULT;
END;
GO

/* ---------- alocação proporcional por Ref + Cor ---------- */
CREATE OR ALTER PROCEDURE dbo.sp_HCA_alocacao_proporcional
    @ref          varchar(18),
    @usrlogin     varchar(100),
    @simular      bit = 0,
    @disponivel   numeric(16, 2) = NULL,  -- legado; ignorado (fonte = previsão)
    @cor          varchar(100) = NULL,
    @filtrar_cor  bit = 0
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    IF @ref IS NULL OR LTRIM(RTRIM(@ref)) = ''
    BEGIN
        RAISERROR(N'ref obrigatória.', 16, 1);
        RETURN;
    END;

    IF @simular = 0 AND (@usrlogin IS NULL OR LTRIM(RTRIM(@usrlogin)) = '')
    BEGIN
        RAISERROR(N'usrlogin obrigatório para gravar.', 16, 1);
        RETURN;
    END;

    SET @disponivel = NULL;

    DECLARE
        @ref_n varchar(18) = LTRIM(RTRIM(@ref)),
        /* Capacidade sempre por uma combinação Ref+Cor; não misturar cores. */
        @cor_cap varchar(100) = CASE
            WHEN ISNULL(@filtrar_cor, 0) = 1 THEN ISNULL(@cor, '')
            ELSE ''
        END,
        @prevIdGuid uniqueidentifier,
        @prevIdStr varchar(50),
        @previsto numeric(16, 2),
        @alocado_outros numeric(16, 2),
        @disponivel_usado numeric(16, 2),
        @tem_linha_prev bit,
        @R numeric(16, 4),
        @sobra int,
        @agora datetime = GETDATE(),
        @msg nvarchar(400);

    IF OBJECT_ID('tempdb..#linhas') IS NOT NULL
        DROP TABLE #linhas;

    CREATE TABLE #linhas (
        bistamp varchar(25) COLLATE DATABASE_DEFAULT NOT NULL PRIMARY KEY,
        bostamp varchar(25) COLLATE DATABASE_DEFAULT NOT NULL,
        dataobra datetime NULL,
        obrano int NULL,
        restante numeric(16, 4) NOT NULL,
        bruto numeric(16, 8) NOT NULL DEFAULT 0,
        auth_floor int NOT NULL DEFAULT 0,
        frac numeric(16, 8) NOT NULL DEFAULT 0,
        auth_final int NOT NULL DEFAULT 0,
        rn int NULL,
        primeira bit NOT NULL DEFAULT 0
    );

    BEGIN TRAN;

    SELECT TOP (1)
        @prevIdGuid = p.Id,
        @prevIdStr = CONVERT(varchar(36), p.Id)
    FROM dbo.u_HcaPrevEntrada p WITH (UPDLOCK, ROWLOCK)
    WHERE ISNULL(p.Fechada, 0) = 0
    ORDER BY p.DataInicio ASC, p.DataFim ASC;

    IF @prevIdGuid IS NULL
    BEGIN
        ROLLBACK;
        RAISERROR(N'Não existe uma previsão de entrada aberta.', 16, 1);
        RETURN;
    END;

    SET @tem_linha_prev = 0;
    SET @previsto = NULL;

    SELECT
        @tem_linha_prev = 1,
        @previsto = ISNULL(l.QuantidadePrevista, 0)
    FROM dbo.u_HcaPrevEntradaLin l WITH (UPDLOCK, ROWLOCK)
    WHERE l.PrevisaoId = @prevIdGuid
      AND LTRIM(RTRIM(l.Ref)) COLLATE DATABASE_DEFAULT = @ref_n COLLATE DATABASE_DEFAULT
      AND l.Cor COLLATE DATABASE_DEFAULT = @cor_cap COLLATE DATABASE_DEFAULT;

    IF ISNULL(@tem_linha_prev, 0) = 0
    BEGIN
        ROLLBACK;
        SET @msg = N'A referência ' + @ref_n + N' não tem quantidade prevista registada.';
        RAISERROR(@msg, 16, 1);
        RETURN;
    END;

    SET @previsto = ISNULL(@previsto, 0);

    INSERT INTO #linhas (bistamp, bostamp, dataobra, obrano, restante, primeira)
    SELECT
        bi.bistamp,
        bi.bostamp,
        bo.dataobra,
        bo.obrano,
        (ISNULL(NULLIF(bi2.u_qttorig, 0), bi.qtt) - bi.qtt2),
        CASE WHEN LTRIM(RTRIM(ISNULL(bi2.u_qtdautur, ''))) = '' THEN 1 ELSE 0 END
    FROM dbo.bi bi WITH (UPDLOCK, ROWLOCK)
    INNER JOIN dbo.bo bo WITH (UPDLOCK, ROWLOCK)
        ON bo.bostamp COLLATE DATABASE_DEFAULT = bi.bostamp COLLATE DATABASE_DEFAULT
    LEFT JOIN dbo.bi2 bi2 WITH (UPDLOCK, ROWLOCK)
        ON bi2.bi2stamp COLLATE DATABASE_DEFAULT = bi.bistamp COLLATE DATABASE_DEFAULT
    LEFT JOIN dbo.bo3 bo3 WITH (NOLOCK)
        ON bo3.bo3stamp COLLATE DATABASE_DEFAULT = bo.bostamp COLLATE DATABASE_DEFAULT
    WHERE LTRIM(RTRIM(bi.ref)) COLLATE DATABASE_DEFAULT
          = @ref_n COLLATE DATABASE_DEFAULT
      AND bi.u_cor COLLATE DATABASE_DEFAULT = @cor_cap COLLATE DATABASE_DEFAULT
      AND bo.ndos = 1
      AND ISNULL(bo.fechada, 0) = 0
      AND ISNULL(bo3.u_pickrdy, 0) = 0
      AND ISNULL(bo3.u_pickstat, 0) = 0
      AND (ISNULL(NULLIF(bi2.u_qttorig, 0), bi.qtt) - bi.qtt2) > 0;

    IF EXISTS (
        SELECT 1
        FROM #linhas l
        INNER JOIN dbo.bi2 bi2 WITH (UPDLOCK, ROWLOCK)
            ON bi2.bi2stamp COLLATE DATABASE_DEFAULT = l.bistamp COLLATE DATABASE_DEFAULT
        INNER JOIN dbo.u_HcaPrevEntrada p WITH (UPDLOCK, ROWLOCK)
            ON p.Id = TRY_CONVERT(uniqueidentifier, LTRIM(RTRIM(ISNULL(bi2.u_prevId, ''))))
        WHERE LTRIM(RTRIM(ISNULL(bi2.u_prevId, ''))) <> ''
          AND ISNULL(p.Fechada, 0) = 1
          AND ISNULL(bi2.u_qtdaut, 0) > 0
    )
    BEGIN
        ROLLBACK;
        RAISERROR(N'A autorização está associada a uma previsão fechada.', 16, 1);
        RETURN;
    END;

    SELECT @alocado_outros = ISNULL(SUM(ISNULL(bi2.u_qtdaut, 0)), 0)
    FROM dbo.bi2 bi2 WITH (UPDLOCK, ROWLOCK)
    INNER JOIN dbo.bi bi WITH (UPDLOCK, ROWLOCK)
        ON bi.bistamp COLLATE DATABASE_DEFAULT = bi2.bi2stamp COLLATE DATABASE_DEFAULT
    WHERE LTRIM(RTRIM(ISNULL(bi2.u_prevId, ''))) COLLATE DATABASE_DEFAULT
          = @prevIdStr COLLATE DATABASE_DEFAULT
      AND LTRIM(RTRIM(bi.ref)) COLLATE DATABASE_DEFAULT = @ref_n COLLATE DATABASE_DEFAULT
      AND bi.u_cor COLLATE DATABASE_DEFAULT = @cor_cap COLLATE DATABASE_DEFAULT
      AND NOT EXISTS (
            SELECT 1 FROM #linhas l
            WHERE l.bistamp COLLATE DATABASE_DEFAULT = bi.bistamp COLLATE DATABASE_DEFAULT
        );

    SET @alocado_outros = ISNULL(@alocado_outros, 0);
    SET @disponivel_usado = @previsto - @alocado_outros;
    IF @disponivel_usado < 0
        SET @disponivel_usado = 0;

    SELECT @R = ISNULL(SUM(restante), 0) FROM #linhas;

    IF @R = 0 OR @disponivel_usado <= 0
    BEGIN
        UPDATE #linhas SET auth_final = 0, bruto = 0, auth_floor = 0, frac = 0;
    END
    ELSE
    BEGIN
        UPDATE #linhas
        SET
            bruto = CAST(@disponivel_usado AS numeric(16, 8)) * (restante / @R),
            auth_floor = FLOOR(CAST(@disponivel_usado AS numeric(16, 8)) * (restante / @R)),
            frac = (CAST(@disponivel_usado AS numeric(16, 8)) * (restante / @R))
                   - FLOOR(CAST(@disponivel_usado AS numeric(16, 8)) * (restante / @R));

        UPDATE #linhas SET auth_final = auth_floor;

        SELECT @sobra = CAST(FLOOR(@disponivel_usado) AS int) - ISNULL(SUM(auth_floor), 0)
        FROM #linhas;

        ;WITH ranked AS (
            SELECT
                bistamp,
                ROW_NUMBER() OVER (
                    ORDER BY frac DESC, dataobra ASC, obrano ASC, bistamp ASC
                ) AS rn
            FROM #linhas
        )
        UPDATE l
        SET
            l.rn = r.rn,
            l.auth_final = CASE
                WHEN r.rn <= @sobra THEN l.auth_floor + 1
                ELSE l.auth_floor
            END
        FROM #linhas l
        INNER JOIN ranked r ON r.bistamp = l.bistamp;

        UPDATE #linhas
        SET auth_final = CASE
            WHEN auth_final > FLOOR(restante) THEN FLOOR(restante)
            ELSE auth_final
        END;
    END;

    IF @simular = 0
    BEGIN
        INSERT INTO dbo.bi2 (bi2stamp)
        SELECT l.bistamp
        FROM #linhas l
        WHERE NOT EXISTS (
            SELECT 1 FROM dbo.bi2 bi2
            WHERE bi2.bi2stamp COLLATE DATABASE_DEFAULT = l.bistamp COLLATE DATABASE_DEFAULT
        );

        UPDATE bi2
        SET u_qttorig = bi.qtt
        FROM dbo.bi2 bi2
        INNER JOIN #linhas l
            ON l.bistamp COLLATE DATABASE_DEFAULT = bi2.bi2stamp COLLATE DATABASE_DEFAULT
        INNER JOIN dbo.bi bi
            ON bi.bistamp COLLATE DATABASE_DEFAULT = bi2.bi2stamp COLLATE DATABASE_DEFAULT
        WHERE l.primeira = 1
          AND ISNULL(bi2.u_qttorig, 0) = 0;

        UPDATE bi
        SET
            qtt = l.auth_final,
            ettdeb = ROUND(l.auth_final * bi.edebito, 2),
            usrinis = LEFT(LTRIM(RTRIM(@usrlogin)), 3),
            usrdata = CAST(@agora AS date),
            usrhora = CONVERT(varchar(8), @agora, 108)
        FROM dbo.bi bi
        INNER JOIN #linhas l
            ON l.bistamp COLLATE DATABASE_DEFAULT = bi.bistamp COLLATE DATABASE_DEFAULT
        WHERE l.primeira = 1;

        UPDATE bi2
        SET
            u_qtdaut = l.auth_final,
            u_qtdautur = LEFT(LTRIM(RTRIM(@usrlogin)), 100),
            u_qtdautdt = @agora,
            u_prevId = CASE
                WHEN l.auth_final > 0 THEN @prevIdStr
                ELSE ''
            END
        FROM dbo.bi2 bi2
        INNER JOIN #linhas l
            ON l.bistamp COLLATE DATABASE_DEFAULT = bi2.bi2stamp COLLATE DATABASE_DEFAULT;
    END;

    COMMIT;

    SELECT
        @ref_n AS ref,
        @cor_cap AS cor,
        CAST(0 AS numeric(16, 2)) AS stock_disponivel,
        @disponivel_usado AS disponivel_usado,
        @simular AS simular,
        ISNULL(SUM(auth_final), 0) AS soma_proposta,
        @previsto AS previsto,
        @alocado_outros AS alocado_outros,
        @prevIdStr AS u_prevId
    FROM #linhas;

    SELECT
        l.bistamp,
        l.bostamp,
        l.obrano,
        l.dataobra,
        l.restante AS quantidade_por_satisfazer,
        l.bruto,
        l.auth_final AS quantidade_proposta
    FROM #linhas l
    ORDER BY l.dataobra ASC, l.obrano ASC, l.bistamp ASC;
END;
GO
