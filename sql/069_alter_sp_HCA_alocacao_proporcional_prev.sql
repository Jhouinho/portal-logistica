-- =============================================================================
-- Liliana & Seródio — Portal Logístico
-- Script: 069_alter_sp_HCA_alocacao_proporcional_prev.sql
-- Ambiente: UAT primeiro; Produção só no GO formal
-- Pré-requisito: 068 (teto previsão + IX_bi2_u_prevId); BI2.u_prevId varchar(50) NULL
-- =============================================================================
-- PR2-A — Alocação proporcional consome a previsão aberta.
--   Ignora @disponivel do cliente e ST.stock.
--   disponivel_usado = Previsto − Alocado(outras linhas fora do conjunto).
--   simular=0 grava u_qtdaut* + u_prevId; simular=1 não grava.
-- =============================================================================

SET NOCOUNT ON;
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
                ELSE NULL
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
