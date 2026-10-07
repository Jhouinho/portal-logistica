-- =============================================================================
-- Liliana & Seródio — Portal Logístico
-- Script: 073_fix_prev_entrada_empty_string.sql
-- Ambiente: UAT primeiro; Produção só no GO formal
-- Pré-requisito: BI2.u_prevId varchar(50) NOT NULL DEFAULT '' (Framework / alter coluna)
--                068 índice IX_bi2_u_prevId; tabelas previsão 062+064
-- NÃO executar contra a BD a partir deste agente — deploy manual.
-- =============================================================================
-- PR2-A fix — u_prevId NEVER NULL: '' = sem associação.
--   Substitui clears/assigns NULL das SPs 068/069/070 por string vazia.
--   Lógica de negócio inalterada; só semântica NULL → ''.
--   Fontes: 068 (SP only), 069, 070 (ambas as SPs). Scripts históricos 068–070 mantidos.
-- =============================================================================

SET NOCOUNT ON;
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
            u_prevId = ''
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

CREATE OR ALTER PROCEDURE dbo.sp_HCA_alocacao_proporcional
    @ref          varchar(18),
    @usrlogin     varchar(100),
    @simular      bit = 0,
    @disponivel   numeric(16, 2) = NULL,  -- legado; ignorado (fonte = previsão)
    @cor          varchar(50) = NULL,
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

    -- Compatibilidade de assinatura: não usar @disponivel como teto.
    SET @disponivel = NULL;

    DECLARE
        @ref_n varchar(18) = LTRIM(RTRIM(@ref)),
        @cor_n varchar(50) = LTRIM(RTRIM(ISNULL(@cor, ''))),
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
      AND LTRIM(RTRIM(l.Ref)) COLLATE DATABASE_DEFAULT = @ref_n COLLATE DATABASE_DEFAULT;

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
      AND bo.ndos = 1
      AND ISNULL(bo.fechada, 0) = 0
      AND ISNULL(bo3.u_pickrdy, 0) = 0
      AND ISNULL(bo3.u_pickstat, 0) = 0
      AND (ISNULL(NULLIF(bi2.u_qttorig, 0), bi.qtt) - bi.qtt2) > 0
      AND (
            @filtrar_cor = 0
         OR LTRIM(RTRIM(COALESCE(
                NULLIF(LTRIM(RTRIM(ISNULL(bi.cor, ''))), ''),
                NULLIF(LTRIM(RTRIM(ISNULL(bi.u_cor, ''))), ''),
                ''
            ))) COLLATE DATABASE_DEFAULT
            = @cor_n COLLATE DATABASE_DEFAULT
          );

    -- Anomalia: linha do conjunto com u_prevId de previsão fechada.
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

    -- Capacidade = Previsto − Alocado fora do conjunto a redistribuir (qualquer ndos).
    SELECT @alocado_outros = ISNULL(SUM(ISNULL(bi2.u_qtdaut, 0)), 0)
    FROM dbo.bi2 bi2 WITH (UPDLOCK, ROWLOCK)
    INNER JOIN dbo.bi bi WITH (UPDLOCK, ROWLOCK)
        ON bi.bistamp COLLATE DATABASE_DEFAULT = bi2.bi2stamp COLLATE DATABASE_DEFAULT
    WHERE LTRIM(RTRIM(ISNULL(bi2.u_prevId, ''))) COLLATE DATABASE_DEFAULT
          = @prevIdStr COLLATE DATABASE_DEFAULT
      AND LTRIM(RTRIM(bi.ref)) COLLATE DATABASE_DEFAULT = @ref_n COLLATE DATABASE_DEFAULT
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

CREATE OR ALTER PROCEDURE dbo.sp_HCA_picking_cancel
    @bostamp  varchar(25),
    @usrlogin varchar(100),
    @usrinis  varchar(3) = NULL,
    @motivo   varchar(254)
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    IF @bostamp IS NULL OR LTRIM(RTRIM(@bostamp)) = ''
    BEGIN RAISERROR(N'bostamp obrigatório.', 16, 1); RETURN; END;
    IF @usrlogin IS NULL OR LTRIM(RTRIM(@usrlogin)) = ''
    BEGIN RAISERROR(N'usrlogin obrigatório.', 16, 1); RETURN; END;
    IF @motivo IS NULL OR LTRIM(RTRIM(@motivo)) = ''
    BEGIN RAISERROR(N'Motivo de cancelamento obrigatório.', 16, 1); RETURN; END;

    DECLARE @agora datetime = GETDATE(), @stat int, @usrinis_n varchar(3),
            @usrdata datetime, @usrhora varchar(8),
            @motivo_n varchar(254);
    SET @usrinis_n = LEFT(LTRIM(RTRIM(ISNULL(NULLIF(@usrinis, ''), @usrlogin))), 3);
    SET @usrdata = CAST(@agora AS date);
    SET @usrhora = CONVERT(varchar(8), @agora, 108);
    SET @motivo_n = LEFT(LTRIM(RTRIM(@motivo)), 254);

    BEGIN TRAN;

    IF NOT EXISTS (
        SELECT 1 FROM dbo.bo bo WITH (UPDLOCK, ROWLOCK)
        WHERE bo.bostamp COLLATE DATABASE_DEFAULT = @bostamp COLLATE DATABASE_DEFAULT
          AND bo.ndos = 1 AND ISNULL(bo.fechada, 0) = 0)
    BEGIN ROLLBACK; RAISERROR(N'Encomenda não encontrada ou documento fechado/série inválida.', 16, 1); RETURN; END;

    IF NOT EXISTS (SELECT 1 FROM dbo.bo3 WITH (UPDLOCK, ROWLOCK)
                   WHERE bo3stamp COLLATE DATABASE_DEFAULT = @bostamp COLLATE DATABASE_DEFAULT)
        INSERT INTO dbo.bo3 (bo3stamp) VALUES (@bostamp);

    SELECT @stat = CAST(ISNULL(u_pickstat, 0) AS int)
    FROM dbo.bo3 WITH (UPDLOCK, ROWLOCK)
    WHERE bo3stamp COLLATE DATABASE_DEFAULT = @bostamp COLLATE DATABASE_DEFAULT;

    IF @stat <> 1
    BEGIN ROLLBACK; RAISERROR(N'Transição inválida: Cancelar Picking só a partir de Preparado (u_pickstat=1).', 16, 1); RETURN; END;

    INSERT INTO dbo.bi2 (bi2stamp)
    SELECT bi.bistamp FROM dbo.bi bi
    WHERE bi.bostamp COLLATE DATABASE_DEFAULT = @bostamp COLLATE DATABASE_DEFAULT
      AND NOT EXISTS (SELECT 1 FROM dbo.bi2 bi2
                      WHERE bi2.bi2stamp COLLATE DATABASE_DEFAULT = bi.bistamp COLLATE DATABASE_DEFAULT);

    UPDATE bi SET qtt = bi2.u_qttorig, ettdeb = ROUND(bi2.u_qttorig * bi.edebito, 2),
                  usrinis = @usrinis_n, usrdata = @usrdata, usrhora = @usrhora
    FROM dbo.bi bi
    INNER JOIN dbo.bi2 bi2 ON bi2.bi2stamp COLLATE DATABASE_DEFAULT = bi.bistamp COLLATE DATABASE_DEFAULT
    WHERE bi.bostamp COLLATE DATABASE_DEFAULT = @bostamp COLLATE DATABASE_DEFAULT
      AND ISNULL(bi2.u_qttorig, 0) > 0;

    UPDATE bi2
    SET
        u_qtdaut = 0,
        u_qtdautur = '',
        u_qtdautdt = CAST('19000101' AS datetime),
        u_prevId = ''
    FROM dbo.bi2 bi2
    INNER JOIN dbo.bi bi ON bi.bistamp COLLATE DATABASE_DEFAULT = bi2.bi2stamp COLLATE DATABASE_DEFAULT
    WHERE bi.bostamp COLLATE DATABASE_DEFAULT = @bostamp COLLATE DATABASE_DEFAULT;

    UPDATE dbo.bo3
    SET u_pickrdy = 0, u_pickstat = 0,
        u_pickrdr = LEFT(LTRIM(RTRIM(@usrlogin)), 100), u_pickrdt = @agora,
        u_pickcobs = @motivo_n
    WHERE bo3stamp COLLATE DATABASE_DEFAULT = @bostamp COLLATE DATABASE_DEFAULT;

    UPDATE dbo.bo SET usrinis = @usrinis_n, usrdata = @usrdata, usrhora = @usrhora
    WHERE bostamp COLLATE DATABASE_DEFAULT = @bostamp COLLATE DATABASE_DEFAULT;

    COMMIT;

    SELECT bo.bostamp,
           CAST(ISNULL(bo3.u_pickrdy, 0) AS bit) AS pronta_picking,
           CAST(ISNULL(bo3.u_pickstat, 0) AS int) AS pick_status,
           LTRIM(RTRIM(ISNULL(bo3.u_pickrdr, ''))) AS pronta_picking_por,
           CASE WHEN bo3.u_pickrdt IS NULL OR YEAR(bo3.u_pickrdt) < 1950 THEN CAST(NULL AS datetime) ELSE bo3.u_pickrdt END AS pronta_picking_em
    FROM dbo.bo bo WITH (NOLOCK)
    LEFT JOIN dbo.bo3 bo3 WITH (NOLOCK) ON bo3.bo3stamp COLLATE DATABASE_DEFAULT = bo.bostamp COLLATE DATABASE_DEFAULT
    WHERE bo.bostamp COLLATE DATABASE_DEFAULT = @bostamp COLLATE DATABASE_DEFAULT;
END;
GO

CREATE OR ALTER PROCEDURE dbo.sp_HCA_marcar_pronta_picking
    @bostamp                varchar(25),
    @pronta                 bit,
    @usrlogin               varchar(100),
    @usrinis                varchar(3) = NULL,
    @confirmar_linhas_zero  bit = 0,
    @motivo                 varchar(254) = NULL
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    IF @bostamp IS NULL OR LTRIM(RTRIM(@bostamp)) = ''
    BEGIN
        RAISERROR(N'bostamp obrigatório.', 16, 1);
        RETURN;
    END;

    IF @usrlogin IS NULL OR LTRIM(RTRIM(@usrlogin)) = ''
    BEGIN
        RAISERROR(N'usrlogin obrigatório.', 16, 1);
        RETURN;
    END;

    IF ISNULL(@pronta, 0) = 0 AND (@motivo IS NULL OR LTRIM(RTRIM(@motivo)) = '')
    BEGIN
        RAISERROR(N'Motivo de cancelamento obrigatório.', 16, 1);
        RETURN;
    END;

    DECLARE
        @agora datetime = GETDATE(),
        @usrdata datetime,
        @usrhora varchar(8),
        @usrinis_n varchar(3),
        @linhas_zero int = 0,
        @stat_atual int,
        @motivo_n varchar(254);

    SET @usrdata = CAST(@agora AS date);
    SET @usrhora = CONVERT(varchar(8), @agora, 108);
    SET @usrinis_n = LEFT(LTRIM(RTRIM(ISNULL(NULLIF(@usrinis, ''), @usrlogin))), 3);
    SET @motivo_n = LEFT(LTRIM(RTRIM(ISNULL(@motivo, ''))), 254);

    BEGIN TRAN;

    IF NOT EXISTS (
        SELECT 1
        FROM dbo.bo bo WITH (UPDLOCK, ROWLOCK)
        WHERE bo.bostamp COLLATE DATABASE_DEFAULT = @bostamp COLLATE DATABASE_DEFAULT
          AND bo.ndos = 1
          AND ISNULL(bo.fechada, 0) = 0
    )
    BEGIN
        ROLLBACK;
        RAISERROR(N'Encomenda não encontrada ou documento fechado/série inválida.', 16, 1);
        RETURN;
    END;

    IF NOT EXISTS (
        SELECT 1 FROM dbo.bo3 WITH (UPDLOCK, ROWLOCK)
        WHERE bo3stamp COLLATE DATABASE_DEFAULT = @bostamp COLLATE DATABASE_DEFAULT
    )
        INSERT INTO dbo.bo3 (bo3stamp) VALUES (@bostamp);

    SELECT @stat_atual = CAST(ISNULL(u_pickstat, 0) AS int)
    FROM dbo.bo3 WITH (UPDLOCK, ROWLOCK)
    WHERE bo3stamp COLLATE DATABASE_DEFAULT = @bostamp COLLATE DATABASE_DEFAULT;

    IF ISNULL(@pronta, 0) = 1
    BEGIN
        IF @stat_atual NOT IN (0)
        BEGIN
            ROLLBACK;
            RAISERROR(N'Transição inválida: só é possível marcar para picking a partir de Em Aberto (u_pickstat=0).', 16, 1);
            RETURN;
        END;

        SELECT @linhas_zero = COUNT(1)
        FROM dbo.bi bi WITH (UPDLOCK, ROWLOCK)
        LEFT JOIN dbo.bi2 bi2 WITH (UPDLOCK, ROWLOCK)
            ON bi2.bi2stamp COLLATE DATABASE_DEFAULT = bi.bistamp COLLATE DATABASE_DEFAULT
        WHERE bi.bostamp COLLATE DATABASE_DEFAULT = @bostamp COLLATE DATABASE_DEFAULT
          AND ISNULL(bi2.u_qtdaut, 0) = 0
          AND (ISNULL(NULLIF(bi2.u_qttorig, 0), bi.qtt) - bi.qtt2) > 0;

        IF @linhas_zero > 0 AND ISNULL(@confirmar_linhas_zero, 0) = 0
        BEGIN
            ROLLBACK;
            RAISERROR(
                N'LINHAS_SEM_AUTORIZACAO: Existem linhas com quantidade autorizada a 0. Confirme para avançar.',
                16,
                1);
            RETURN;
        END;

        IF @linhas_zero > 0 AND ISNULL(@confirmar_linhas_zero, 0) = 1
        BEGIN
            INSERT INTO dbo.bi2 (bi2stamp)
            SELECT bi.bistamp
            FROM dbo.bi bi
            WHERE bi.bostamp COLLATE DATABASE_DEFAULT = @bostamp COLLATE DATABASE_DEFAULT
              AND NOT EXISTS (
                  SELECT 1 FROM dbo.bi2 bi2
                  WHERE bi2.bi2stamp COLLATE DATABASE_DEFAULT = bi.bistamp COLLATE DATABASE_DEFAULT
              );

            UPDATE bi2
            SET
                u_qttorig = CASE WHEN ISNULL(bi2.u_qttorig, 0) = 0 THEN bi.qtt ELSE bi2.u_qttorig END,
                u_prcorig = CASE WHEN ISNULL(bi2.u_prcorig, 0) = 0 THEN bi.edebito ELSE bi2.u_prcorig END
            FROM dbo.bi2 bi2
            INNER JOIN dbo.bi bi
                ON bi.bistamp COLLATE DATABASE_DEFAULT = bi2.bi2stamp COLLATE DATABASE_DEFAULT
            WHERE bi.bostamp COLLATE DATABASE_DEFAULT = @bostamp COLLATE DATABASE_DEFAULT
              AND ISNULL(bi2.u_qtdaut, 0) = 0
              AND (ISNULL(NULLIF(bi2.u_qttorig, 0), bi.qtt) - bi.qtt2) > 0;

            UPDATE bi
            SET
                qtt = ISNULL(bi2.u_qtdaut, 0),
                ettdeb = ROUND(ISNULL(bi2.u_qtdaut, 0) * bi.edebito, 2),
                usrinis = @usrinis_n,
                usrdata = @usrdata,
                usrhora = @usrhora
            FROM dbo.bi bi
            INNER JOIN dbo.bi2 bi2
                ON bi2.bi2stamp COLLATE DATABASE_DEFAULT = bi.bistamp COLLATE DATABASE_DEFAULT
            WHERE bi.bostamp COLLATE DATABASE_DEFAULT = @bostamp COLLATE DATABASE_DEFAULT
              AND ISNULL(bi2.u_qtdaut, 0) = 0
              AND (ISNULL(NULLIF(bi2.u_qttorig, 0), bi.qtt) - bi.qtt2) > 0;
        END;
    END
    ELSE
    BEGIN
        IF @stat_atual NOT IN (1)
        BEGIN
            ROLLBACK;
            RAISERROR(N'Transição inválida: só é possível cancelar picking a partir de Preparado (u_pickstat=1).', 16, 1);
            RETURN;
        END;

        INSERT INTO dbo.bi2 (bi2stamp)
        SELECT bi.bistamp
        FROM dbo.bi bi
        WHERE bi.bostamp COLLATE DATABASE_DEFAULT = @bostamp COLLATE DATABASE_DEFAULT
          AND NOT EXISTS (
              SELECT 1 FROM dbo.bi2 bi2
              WHERE bi2.bi2stamp COLLATE DATABASE_DEFAULT = bi.bistamp COLLATE DATABASE_DEFAULT
          );

        UPDATE bi
        SET
            qtt = bi2.u_qttorig,
            ettdeb = ROUND(bi2.u_qttorig * bi.edebito, 2),
            usrinis = @usrinis_n,
            usrdata = @usrdata,
            usrhora = @usrhora
        FROM dbo.bi bi
        INNER JOIN dbo.bi2 bi2
            ON bi2.bi2stamp COLLATE DATABASE_DEFAULT = bi.bistamp COLLATE DATABASE_DEFAULT
        WHERE bi.bostamp COLLATE DATABASE_DEFAULT = @bostamp COLLATE DATABASE_DEFAULT
          AND ISNULL(bi2.u_qttorig, 0) > 0;

        UPDATE bi2
        SET
            u_qtdaut = 0,
            u_qtdautur = '',
            u_qtdautdt = CAST('19000101' AS datetime),
            u_prevId = ''
        FROM dbo.bi2 bi2
        INNER JOIN dbo.bi bi
            ON bi.bistamp COLLATE DATABASE_DEFAULT = bi2.bi2stamp COLLATE DATABASE_DEFAULT
        WHERE bi.bostamp COLLATE DATABASE_DEFAULT = @bostamp COLLATE DATABASE_DEFAULT;
    END;

    UPDATE dbo.bo3
    SET
        u_pickrdy = ISNULL(@pronta, 0),
        u_pickstat = CASE WHEN ISNULL(@pronta, 0) = 1 THEN 1 ELSE 0 END,
        u_pickrdr = LEFT(LTRIM(RTRIM(@usrlogin)), 100),
        u_pickrdt = @agora,
        u_pickcobs = CASE WHEN ISNULL(@pronta, 0) = 1 THEN '' ELSE @motivo_n END
    WHERE bo3stamp COLLATE DATABASE_DEFAULT = @bostamp COLLATE DATABASE_DEFAULT;

    UPDATE dbo.bo
    SET
        usrinis = @usrinis_n,
        usrdata = @usrdata,
        usrhora = @usrhora
    WHERE bostamp COLLATE DATABASE_DEFAULT = @bostamp COLLATE DATABASE_DEFAULT;

    COMMIT;

    SELECT
        bo.bostamp,
        CAST(ISNULL(bo3.u_pickrdy, 0) AS bit) AS pronta_picking,
        LTRIM(RTRIM(ISNULL(bo3.u_pickrdr, ''))) AS pronta_picking_por,
        CASE
            WHEN bo3.u_pickrdt IS NULL OR YEAR(bo3.u_pickrdt) < 1950 THEN CAST(NULL AS datetime)
            ELSE bo3.u_pickrdt
        END AS pronta_picking_em,
        CAST(ISNULL(bo3.u_pickstat, 0) AS int) AS pick_status
    FROM dbo.bo bo WITH (NOLOCK)
    LEFT JOIN dbo.bo3 bo3 WITH (NOLOCK)
        ON bo3.bo3stamp COLLATE DATABASE_DEFAULT = bo.bostamp COLLATE DATABASE_DEFAULT
    WHERE bo.bostamp COLLATE DATABASE_DEFAULT = @bostamp COLLATE DATABASE_DEFAULT;
END;
GO
