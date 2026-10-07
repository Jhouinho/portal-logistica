-- =============================================================================
-- Liliana & Seródio — Portal Logístico
-- Script: 035_alter_sp_HCA_alocacao_proporcional_disponivel_cor.sql
-- Ambiente: UAT / teste; Produção só no GO formal
-- =============================================================================
-- Se @disponivel NOT NULL → disponivel_usado = max(0, @disponivel) (valor operacional)
-- Se @disponivel IS NULL → disponivel_usado = ST.stock
-- Comparações texto: COLLATE DATABASE_DEFAULT
-- =============================================================================

CREATE OR ALTER PROCEDURE dbo.sp_HCA_alocacao_proporcional
    @ref          varchar(18),
    @usrlogin     varchar(100),
    @simular      bit = 0,
    @disponivel   numeric(16, 2) = NULL,
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

    DECLARE
        @ref_n varchar(18) = LTRIM(RTRIM(@ref)),
        @cor_n varchar(50) = LTRIM(RTRIM(ISNULL(@cor, ''))),
        @stock numeric(16, 2),
        @disponivel_usado numeric(16, 2),
        @R numeric(16, 4),
        @sobra int,
        @agora datetime = GETDATE();

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
        rn int NULL
    );

    BEGIN TRAN;

    SELECT @stock = ISNULL(st.stock, 0)
    FROM dbo.st st WITH (UPDLOCK, ROWLOCK)
    WHERE LTRIM(RTRIM(st.ref)) COLLATE DATABASE_DEFAULT
        = @ref_n COLLATE DATABASE_DEFAULT;

    SET @stock = ISNULL(@stock, 0);

    -- Valor indicado pelo portal prevalece; ST.stock só quando @disponivel é NULL.
    IF @disponivel IS NULL
        SET @disponivel_usado = @stock;
    ELSE IF @disponivel < 0
        SET @disponivel_usado = 0;
    ELSE
        SET @disponivel_usado = @disponivel;

    INSERT INTO #linhas (bistamp, bostamp, dataobra, obrano, restante)
    SELECT
        bi.bistamp,
        bi.bostamp,
        bo.dataobra,
        bo.obrano,
        (ISNULL(NULLIF(bi.u_qttorig, 0), bi.qtt) - bi.qtt2)
    FROM dbo.bi bi WITH (UPDLOCK, ROWLOCK)
    INNER JOIN dbo.bo bo WITH (UPDLOCK, ROWLOCK)
        ON bo.bostamp COLLATE DATABASE_DEFAULT = bi.bostamp COLLATE DATABASE_DEFAULT
    WHERE LTRIM(RTRIM(bi.ref)) COLLATE DATABASE_DEFAULT
          = @ref_n COLLATE DATABASE_DEFAULT
      AND bo.ndos = 1
      AND ISNULL(bo.fechada, 0) = 0
      AND (ISNULL(NULLIF(bi.u_qttorig, 0), bi.qtt) - bi.qtt2) > 0
      AND (
            @filtrar_cor = 0
         OR LTRIM(RTRIM(ISNULL(bi.cor, ''))) COLLATE DATABASE_DEFAULT
            = @cor_n COLLATE DATABASE_DEFAULT
          );

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
        -- 1.ª autorização (u_qtdautur vazio): u_qttorig = qtt; qtt = auth_final
        UPDATE bi
        SET
            u_qttorig = CASE
                WHEN LTRIM(RTRIM(ISNULL(bi.u_qtdautur, ''))) = '' THEN bi.qtt
                ELSE bi.u_qttorig
            END,
            qtt = CASE
                WHEN LTRIM(RTRIM(ISNULL(bi.u_qtdautur, ''))) = '' THEN l.auth_final
                ELSE bi.qtt
            END,
            ettdeb = CASE
                WHEN LTRIM(RTRIM(ISNULL(bi.u_qtdautur, ''))) = ''
                    THEN ROUND(l.auth_final * bi.edebito, 2)
                ELSE bi.ettdeb
            END,
            u_qtdaut = l.auth_final,
            u_qtdautur = LEFT(LTRIM(RTRIM(@usrlogin)), 100),
            u_qtdautdt = @agora,
            usrinis = CASE
                WHEN LTRIM(RTRIM(ISNULL(bi.u_qtdautur, ''))) = ''
                    THEN LEFT(LTRIM(RTRIM(@usrlogin)), 3)
                ELSE bi.usrinis
            END,
            usrdata = CASE
                WHEN LTRIM(RTRIM(ISNULL(bi.u_qtdautur, ''))) = ''
                    THEN CAST(@agora AS date)
                ELSE bi.usrdata
            END,
            usrhora = CASE
                WHEN LTRIM(RTRIM(ISNULL(bi.u_qtdautur, ''))) = ''
                    THEN CONVERT(varchar(8), @agora, 108)
                ELSE bi.usrhora
            END
        FROM dbo.bi bi
        INNER JOIN #linhas l
            ON l.bistamp COLLATE DATABASE_DEFAULT = bi.bistamp COLLATE DATABASE_DEFAULT;
    END;

    COMMIT;

    SELECT
        @ref_n AS ref,
        @stock AS stock_disponivel,
        @disponivel_usado AS disponivel_usado,
        @simular AS simular,
        ISNULL(SUM(auth_final), 0) AS soma_proposta
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
