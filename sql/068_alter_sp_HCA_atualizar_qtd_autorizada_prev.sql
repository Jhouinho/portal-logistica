-- =============================================================================
-- Liliana & Seródio — Portal Logístico
-- Script: 068_alter_sp_HCA_atualizar_qtd_autorizada_prev.sql
-- Ambiente: UAT primeiro; Produção só no GO formal
-- Pré-requisito: BI2.u_prevId varchar(50) NOT NULL DEFAULT '' ('' = sem associação; nunca NULL)
--                u_HcaPrevEntrada / Lin (062+064); SP base 046
-- Nota: script histórico mantido; deploy actual das SPs (NULL→'') = 073.
-- =============================================================================
-- PR2-A — Teto operacional = disponibilidade da previsão aberta.
--   Disponível(P,Ref) = Previsto − SUM(BI2.u_qtdaut WHERE u_prevId=P AND ref)
--   Alocado SEM filtro ndos (1→66→65 continua a consumir).
--   Sem fallback ST.stock. @permitir_acima_stock ignorado.
--   Índice de suporte (não UNIQUE).
-- =============================================================================

SET NOCOUNT ON;
SET XACT_ABORT ON;
GO

/* ---------- Índice (várias linhas → mesma previsão; sem UNIQUE) ---------- */
-- bi2 no PHC costuma ter ANSI_NULLS OFF → índice filtrado (WHERE …) falha.
-- Usar índice normal (não filtrado).
IF NOT EXISTS (
    SELECT 1
    FROM sys.indexes
    WHERE name = N'IX_bi2_u_prevId'
      AND object_id = OBJECT_ID(N'dbo.bi2')
)
BEGIN
    CREATE NONCLUSTERED INDEX IX_bi2_u_prevId
        ON dbo.bi2 (u_prevId);
END;
GO

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

    -- Evitar warning de parâmetro não usado (compatibilidade de assinatura).
    SET @permitir_acima_stock = ISNULL(@permitir_acima_stock, 0);

    DECLARE
        @ref varchar(18),
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
            u_prevId = NULL
        WHERE bi2stamp COLLATE DATABASE_DEFAULT = @bistamp COLLATE DATABASE_DEFAULT;

        COMMIT;

        SELECT
            bi.bistamp,
            bi.bostamp,
            LTRIM(RTRIM(bi.ref)) AS ref,
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
            CAST(NULL AS varchar(50)) AS u_prevId,
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
      AND LTRIM(RTRIM(l.Ref)) COLLATE DATABASE_DEFAULT = @ref COLLATE DATABASE_DEFAULT;

    IF ISNULL(@tem_linha_prev, 0) = 0
    BEGIN
        ROLLBACK;
        SET @msg = N'A referência ' + @ref + N' não tem quantidade prevista registada.';
        RAISERROR(@msg, 16, 1);
        RETURN;
    END;

    SET @previsto = ISNULL(@previsto, 0);

    -- Alocado noutras linhas do mesmo ciclo+ref (sem filtro ndos/fechada).
    SELECT @alocado_outros = ISNULL(SUM(ISNULL(bi2.u_qtdaut, 0)), 0)
    FROM dbo.bi2 bi2 WITH (UPDLOCK, ROWLOCK)
    INNER JOIN dbo.bi bi WITH (UPDLOCK, ROWLOCK)
        ON bi.bistamp COLLATE DATABASE_DEFAULT = bi2.bi2stamp COLLATE DATABASE_DEFAULT
    WHERE LTRIM(RTRIM(ISNULL(bi2.u_prevId, ''))) COLLATE DATABASE_DEFAULT
          = @prevIdStr COLLATE DATABASE_DEFAULT
      AND LTRIM(RTRIM(bi.ref)) COLLATE DATABASE_DEFAULT = @ref COLLATE DATABASE_DEFAULT
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
        ISNULL(bi2.u_qtdaut, 0) AS quantidade_autorizada,
        LTRIM(RTRIM(ISNULL(bi2.u_qtdautur, ''))) AS quantidade_autorizada_por,
        bi2.u_qtdautdt AS quantidade_autorizada_em,
        bi.qtt AS quantidade_atual,
        ISNULL(bi2.u_qttorig, 0) AS quantidade_original_campo,
        ISNULL(NULLIF(bi2.u_qttorig, 0), bi.qtt) AS quantidade_original_considerada,
        bi.qtt2 AS quantidade_fornecida,
        -- legado: coluna mantida; valor = disponível da previsão após esta linha
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
