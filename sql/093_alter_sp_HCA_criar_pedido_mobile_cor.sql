-- =============================================================================
-- Liliana & Seródio — Portal Mobile
-- Script: 093_alter_sp_HCA_criar_pedido_mobile_cor.sql
-- Ambiente: UAT; Produção só com autorização explícita
-- =============================================================================
-- Acrescenta cor (→ BI.u_cor) ao TVP e à SP sp_HCA_criar_pedido_mobile.
-- Recria TYPE (exige DROP da SP primeiro).
-- =============================================================================

SET NOCOUNT ON;
SET XACT_ABORT ON;
GO

IF OBJECT_ID(N'dbo.sp_HCA_criar_pedido_mobile', N'P') IS NOT NULL
    DROP PROCEDURE dbo.sp_HCA_criar_pedido_mobile;
GO

IF TYPE_ID(N'dbo.HCA_PedidoMobileLinhaType') IS NOT NULL
    DROP TYPE dbo.HCA_PedidoMobileLinhaType;
GO

CREATE TYPE dbo.HCA_PedidoMobileLinhaType AS TABLE
(
    linha_ord int            NOT NULL,
    ref       varchar(18)    NOT NULL,
    qtt       numeric(16, 4) NOT NULL,
    cor       varchar(100)   NOT NULL DEFAULT (N''),
    PRIMARY KEY (linha_ord)
);
GO

CREATE OR ALTER PROCEDURE dbo.sp_HCA_criar_pedido_mobile
    @no               numeric(10, 0),
    @estab            numeric(3, 0) = 0,
    @Linhas           dbo.HCA_PedidoMobileLinhaType READONLY,
    @IdempotencyKey   varchar(64),
    @usrinis          varchar(3) = N'MOB',
    @armazem          numeric(5, 0) = 1,
    @dataobra         date = NULL
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    DECLARE
        @ndos           numeric(3, 0) = 67,
        @nmdos          varchar(24),
        @EuroEscudo     numeric(18, 6) = 200.482,
        @agora          datetime = GETDATE(),
        @usrdata        datetime,
        @usrhora        varchar(8),
        @usr            varchar(3),
        @boano          numeric(4, 0),
        @obrano         numeric(10, 0),
        @bostamp        char(25),
        @lockRes        int,
        @cl_nome        varchar(55),
        @cl_morada      varchar(55),
        @cl_local       varchar(43),
        @cl_codpost     varchar(45),
        @cl_ncont       varchar(20),
        @cl_zona        varchar(20),
        @cl_vendedor    numeric(4, 0),
        @cl_moeda       varchar(11),
        @cl_preco       numeric(5, 0),
        @cl_inactivo    bit,
        @etotaldeb      numeric(19, 6) = 0,
        @totaldeb       numeric(18, 5) = 0,
        @linhaCount     int,
        @stampAttempts  int;

    SET @usrdata = CAST(@agora AS date);
    SET @usrhora = CONVERT(varchar(8), @agora, 108);
    SET @usr = LEFT(LTRIM(RTRIM(ISNULL(NULLIF(@usrinis, N''), N'MOB'))), 3);
    SET @boano = YEAR(ISNULL(@dataobra, @usrdata));
    SET @dataobra = ISNULL(@dataobra, CAST(@usrdata AS date));

    IF @IdempotencyKey IS NULL OR LTRIM(RTRIM(@IdempotencyKey)) = N''
    BEGIN
        RAISERROR(N'IdempotencyKey obrigatória.', 16, 1);
        RETURN;
    END;

    SET @IdempotencyKey = LEFT(LTRIM(RTRIM(@IdempotencyKey)), 64);

    IF @no IS NULL OR @no <= 0
    BEGIN
        RAISERROR(N'Cliente (no) inválido.', 16, 1);
        RETURN;
    END;

    IF @estab IS NULL OR @estab < 0
    BEGIN
        RAISERROR(N'estab inválido.', 16, 1);
        RETURN;
    END;

    IF @armazem IS NULL OR @armazem <= 0
    BEGIN
        RAISERROR(N'armazem inválido.', 16, 1);
        RETURN;
    END;

    SELECT @linhaCount = COUNT(*) FROM @Linhas;
    IF @linhaCount IS NULL OR @linhaCount < 1
    BEGIN
        RAISERROR(N'É obrigatória pelo menos uma linha.', 16, 1);
        RETURN;
    END;

    IF EXISTS (SELECT 1 FROM @Linhas WHERE qtt IS NULL OR qtt <= 0)
    BEGIN
        RAISERROR(N'Quantidades devem ser > 0.', 16, 1);
        RETURN;
    END;

    IF EXISTS (
        SELECT 1 FROM @Linhas
        WHERE ref IS NULL OR LTRIM(RTRIM(ref)) = N''
    )
    BEGIN
        RAISERROR(N'Referência de artigo obrigatória em todas as linhas.', 16, 1);
        RETURN;
    END;

    IF EXISTS (
        SELECT linha_ord FROM @Linhas GROUP BY linha_ord HAVING COUNT(*) > 1
    )
    BEGIN
        RAISERROR(N'linha_ord duplicada no pedido.', 16, 1);
        RETURN;
    END;

    SELECT @nmdos = RTRIM(ts.nmdos)
    FROM dbo.ts ts WITH (NOLOCK)
    WHERE ts.ndos = @ndos;

    IF @nmdos IS NULL OR @nmdos = N''
    BEGIN
        RAISERROR(N'Tipo de dossier ndos=67 (Pedido Mobile) não encontrado em TS.', 16, 1);
        RETURN;
    END;

    SELECT
        @cl_nome     = LEFT(RTRIM(cl.nome), 55),
        @cl_morada   = LEFT(RTRIM(cl.morada), 55),
        @cl_local    = LEFT(RTRIM(cl.[local]), 43),
        @cl_codpost  = LEFT(RTRIM(cl.codpost), 45),
        @cl_ncont    = LEFT(RTRIM(cl.ncont), 20),
        @cl_zona     = LEFT(RTRIM(cl.zona), 20),
        @cl_vendedor = CAST(ISNULL(cl.vendedor, 0) AS numeric(4, 0)),
        @cl_moeda    = LEFT(NULLIF(RTRIM(cl.moeda), N''), 11),
        @cl_preco    = cl.preco,
        @cl_inactivo = CAST(ISNULL(cl.inactivo, 0) AS bit)
    FROM dbo.cl cl WITH (NOLOCK)
    WHERE cl.no = @no
      AND cl.estab = @estab;

    IF @cl_nome IS NULL
    BEGIN
        RAISERROR(N'Cliente inexistente.', 16, 1);
        RETURN;
    END;

    IF ISNULL(@cl_inactivo, 0) = 1
    BEGIN
        RAISERROR(N'Cliente inactivo.', 16, 1);
        RETURN;
    END;

    IF @cl_moeda IS NULL OR @cl_moeda = N''
        SET @cl_moeda = N'EURO';

    IF @cl_preco IS NULL OR @cl_preco < 1 OR @cl_preco > 5
    BEGIN
        RAISERROR(N'CL.preco inválido (esperado 1..5).', 16, 1);
        RETURN;
    END;

    IF OBJECT_ID(N'tempdb..#lin') IS NOT NULL
        DROP TABLE #lin;

    CREATE TABLE #lin
    (
        linha_ord int            NOT NULL PRIMARY KEY,
        ref       varchar(18)    NOT NULL,
        design    varchar(60)    NOT NULL,
        qtt       numeric(16, 4) NOT NULL,
        cor       varchar(100)   NOT NULL,
        unidade   varchar(4)     NOT NULL,
        tabiva    numeric(1, 0)  NOT NULL,
        iva       numeric(5, 2)  NOT NULL,
        edebito   numeric(19, 6) NOT NULL,
        debito    numeric(18, 5) NOT NULL,
        ettdeb    numeric(19, 6) NOT NULL,
        ttdeb     numeric(18, 5) NOT NULL,
        ettdeb_liq numeric(19, 6) NOT NULL,
        bistamp   char(25)       NULL
    );

    INSERT INTO #lin (linha_ord, ref, design, qtt, cor, unidade, tabiva, iva, edebito, debito, ettdeb, ttdeb, ettdeb_liq)
    SELECT
        l.linha_ord,
        LEFT(RTRIM(st.ref), 18),
        LEFT(RTRIM(st.design), 60),
        l.qtt,
        LEFT(LTRIM(RTRIM(ISNULL(l.cor, N''))), 100),
        LEFT(NULLIF(RTRIM(st.unidade), N''), 4),
        ISNULL(st.tabiva, 0),
        ISNULL(ri.taxa, 0),
        CAST(ROUND(
            CASE @cl_preco
                WHEN 1 THEN st.epv1
                WHEN 2 THEN st.epv2
                WHEN 3 THEN st.epv3
                WHEN 4 THEN st.epv4
                WHEN 5 THEN st.epv5
                ELSE st.epv1
            END
        , 6) AS numeric(19, 6)),
        CAST(0 AS numeric(18, 5)),
        CAST(0 AS numeric(19, 6)),
        CAST(0 AS numeric(18, 5)),
        CAST(0 AS numeric(19, 6))
    FROM @Linhas l
    INNER JOIN dbo.st st WITH (NOLOCK)
        ON RTRIM(st.ref) = RTRIM(l.ref)
    LEFT JOIN dbo.regiva ri WITH (NOLOCK)
        ON ri.tabiva = st.tabiva
       AND RTRIM(ri.descricao) = N'PT';

    IF (SELECT COUNT(*) FROM #lin) <> @linhaCount
    BEGIN
        RAISERROR(N'Uma ou mais referências não existem em ST.', 16, 1);
        RETURN;
    END;

    IF EXISTS (
        SELECT 1
        FROM @Linhas l
        INNER JOIN dbo.st st WITH (NOLOCK) ON RTRIM(st.ref) = RTRIM(l.ref)
        WHERE ISNULL(st.inactivo, 0) = 1
    )
    BEGIN
        RAISERROR(N'Um ou mais artigos estão inactivos.', 16, 1);
        RETURN;
    END;

    IF EXISTS (SELECT 1 FROM #lin WHERE unidade IS NULL OR unidade = N'')
        UPDATE #lin SET unidade = N'UN' WHERE unidade IS NULL OR unidade = N'';

    IF EXISTS (SELECT 1 FROM #lin WHERE edebito IS NULL OR edebito < 0)
    BEGIN
        RAISERROR(N'Preço inválido para um ou mais artigos.', 16, 1);
        RETURN;
    END;

    UPDATE #lin
    SET
        debito = CAST(ROUND(edebito * @EuroEscudo, 5) AS numeric(18, 5)),
        ettdeb = CAST(ROUND(qtt * edebito, 6) AS numeric(19, 6)),
        ttdeb  = CAST(ROUND(qtt * ROUND(edebito * @EuroEscudo, 5), 0) AS numeric(18, 5)),
        ettdeb_liq = CAST(
            ROUND(
                CASE
                    WHEN iva IS NULL OR iva = 0 THEN ROUND(qtt * edebito, 6)
                    ELSE ROUND(qtt * edebito, 6) / (1.0 + (iva / 100.0))
                END
            , 2) AS numeric(19, 6)
        );

    SELECT
        @etotaldeb = CAST(SUM(ettdeb_liq) AS numeric(19, 6))
    FROM #lin;

    SET @etotaldeb = ISNULL(@etotaldeb, 0);
    SET @totaldeb = CAST(ROUND(@etotaldeb * @EuroEscudo, 5) AS numeric(18, 5));

    BEGIN TRY
        BEGIN TRAN;

        SELECT
            @bostamp = bostamp,
            @obrano  = obrano,
            @boano   = boano
        FROM dbo.u_HcaPedidoMobileIdem WITH (UPDLOCK, HOLDLOCK)
        WHERE IdempotencyKey = @IdempotencyKey;

        IF @bostamp IS NOT NULL
        BEGIN
            COMMIT;
            SELECT
                CAST(1 AS bit) AS alreadyExists,
                RTRIM(@bostamp) AS bostamp,
                @obrano AS obrano,
                @boano AS boano,
                @ndos AS ndos,
                @nmdos AS nmdos,
                @etotaldeb AS etotaldeb,
                @totaldeb AS totaldeb,
                @linhaCount AS linhas;
            RETURN;
        END;

        EXEC @lockRes = sp_getapplock
            @Resource = N'HCA_PedidoMobile_obrano',
            @LockMode = N'Exclusive',
            @LockOwner = N'Transaction',
            @LockTimeout = 15000;

        IF @lockRes < 0
        BEGIN
            RAISERROR(N'Não foi possível obter lock de numeração.', 16, 1);
        END;

        SELECT @obrano = ISNULL(MAX(bo.obrano), 0) + 1
        FROM dbo.bo bo WITH (UPDLOCK, HOLDLOCK)
        WHERE bo.ndos = @ndos
          AND bo.boano = @boano;

        SET @stampAttempts = 0;
        WHILE @stampAttempts < 20
        BEGIN
            SET @bostamp = LEFT(CONVERT(varchar(36), NEWID()), 23);
            IF NOT EXISTS (SELECT 1 FROM dbo.bo WITH (NOLOCK) WHERE bostamp = @bostamp)
                BREAK;
            SET @stampAttempts += 1;
            SET @bostamp = NULL;
        END

        IF @bostamp IS NULL
        BEGIN
            RAISERROR(N'Falha a gerar bostamp único.', 16, 1);
        END;

        DECLARE @ord int, @cand char(25), @ok bit;
        DECLARE c_lin CURSOR LOCAL FAST_FORWARD FOR
            SELECT linha_ord FROM #lin ORDER BY linha_ord;
        OPEN c_lin;
        FETCH NEXT FROM c_lin INTO @ord;
        WHILE @@FETCH_STATUS = 0
        BEGIN
            SET @ok = 0;
            SET @stampAttempts = 0;
            WHILE @stampAttempts < 20 AND @ok = 0
            BEGIN
                SET @cand = LEFT(CONVERT(varchar(36), NEWID()), 23);
                SET @stampAttempts += 1;
                IF NOT EXISTS (SELECT 1 FROM dbo.bi WITH (NOLOCK) WHERE bistamp = @cand)
                   AND NOT EXISTS (SELECT 1 FROM #lin WHERE bistamp = @cand)
                BEGIN
                    UPDATE #lin SET bistamp = @cand WHERE linha_ord = @ord;
                    SET @ok = 1;
                END
            END
            IF @ok = 0
            BEGIN
                CLOSE c_lin; DEALLOCATE c_lin;
                RAISERROR(N'Falha a gerar bistamp único para a linha %d.', 16, 1, @ord);
            END
            FETCH NEXT FROM c_lin INTO @ord;
        END
        CLOSE c_lin;
        DEALLOCATE c_lin;

        INSERT INTO dbo.bo
        (
            bostamp, nmdos, obrano, dataobra, no, boano, fechada, ndos,
            moeda, estab, memissao, nome, morada, [local], codpost, ncont,
            zona, vendedor, origem,
            etotaldeb, totaldeb, etotal, total,
            ousrinis, ousrdata, ousrhora, usrinis, usrdata, usrhora
        )
        VALUES
        (
            @bostamp, @nmdos, @obrano, @dataobra, @no, @boano, 0, @ndos,
            @cl_moeda, @estab, @cl_moeda, @cl_nome, @cl_morada, @cl_local, @cl_codpost, @cl_ncont,
            @cl_zona, @cl_vendedor, N'BO',
            @etotaldeb, @totaldeb, @etotaldeb, @totaldeb,
            @usr, @usrdata, @usrhora, @usr, @usrdata, @usrhora
        );

        INSERT INTO dbo.bo2 (bo2stamp) VALUES (@bostamp);
        INSERT INTO dbo.bo3 (bo3stamp) VALUES (@bostamp);

        INSERT INTO dbo.bi
        (
            bistamp, bostamp, ndos, obrano, no, estab,
            ref, design, qtt, qtt2, unidade, armazem,
            edebito, debito, ettdeb, ttdeb,
            iva, tabiva, ivaincl, stipo, lordem, fechada, rdata,
            obistamp, oobistamp,
            u_cor,
            ousrinis, ousrdata, ousrhora, usrinis, usrdata, usrhora
        )
        SELECT
            l.bistamp, @bostamp, @ndos, @obrano, @no, @estab,
            l.ref, l.design, l.qtt, 0, l.unidade, @armazem,
            l.edebito, l.debito, l.ettdeb, l.ttdeb,
            l.iva, l.tabiva, 1, 4, (l.linha_ord * 10000), 0, @dataobra,
            N'', N'',
            l.cor,
            @usr, @usrdata, @usrhora, @usr, @usrdata, @usrhora
        FROM #lin l
        ORDER BY l.linha_ord;

        INSERT INTO dbo.bi2 (bi2stamp)
        SELECT l.bistamp FROM #lin l;

        INSERT INTO dbo.u_HcaPedidoMobileIdem
        (
            IdempotencyKey, bostamp, obrano, boano, no, estab
        )
        VALUES
        (
            @IdempotencyKey, @bostamp, @obrano, @boano, @no, @estab
        );

        COMMIT;

        SELECT
            CAST(0 AS bit) AS alreadyExists,
            RTRIM(@bostamp) AS bostamp,
            @obrano AS obrano,
            @boano AS boano,
            @ndos AS ndos,
            @nmdos AS nmdos,
            @etotaldeb AS etotaldeb,
            @totaldeb AS totaldeb,
            @linhaCount AS linhas;
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0
            ROLLBACK;
        THROW;
    END CATCH
END
GO

IF NOT EXISTS (SELECT 1 FROM sys.database_principals WHERE name = N'portal_app')
    PRINT N'AVISO: portal_app inexistente — saltar GRANTs 093.';
ELSE
BEGIN
    GRANT EXECUTE ON TYPE::dbo.HCA_PedidoMobileLinhaType TO [portal_app];
    GRANT EXECUTE ON dbo.sp_HCA_criar_pedido_mobile TO [portal_app];
END
GO

PRINT N'OK: SP mobile com suporte a cor (BI.u_cor).';
GO
