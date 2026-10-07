-- =============================================================================
-- Liliana & SerÃ³dio â€” Portal LogÃ­stico
-- Script: 041_migrate_user_fields_bi2_bo3.sql
-- Ambiente: UAT / teste; ProduÃ§Ã£o sÃ³ no GO formal
-- =============================================================================
-- Campos de utilizador passam das tabelas base para extensÃµes PHC:
--   BI.*  â†’ BI2.*   (u_qtdaut, u_qtdautur, u_qtdautdt, u_qttorig, u_prcorig)
--   BO.*  â†’ BO3.*   (u_pickrdy, u_pickrdr, u_pickrdt)  [antes u_upickrdr / u_upickrdt]
-- PrÃ©-requisito: campos criados no Framework em BI2 / BO3 + Atualizar a Tabela.
-- =============================================================================

/* ---------- Views ---------- */

CREATE OR ALTER VIEW dbo.view_HCA_encomendas_abertas
AS
SELECT
    bo.bostamp,
    bo.obrano,
    bo.ndos,
    bo.nmdos,
    bo.dataobra,
    bo.ousrhora,
    bo.no AS cliente_no,
    bo.estab AS cliente_estab,
    LTRIM(RTRIM(bo.nome)) AS cliente_nome,

    COUNT(bi.bistamp) AS total_linhas,
    SUM(ISNULL(NULLIF(bi2.u_qttorig, 0), bi.qtt)) AS quantidade_original_total,
    SUM(bi.qtt) AS quantidade_atual_total,
    SUM(bi.qtt2) AS quantidade_fornecida_total,
    SUM(ISNULL(NULLIF(bi2.u_qttorig, 0), bi.qtt) - bi.qtt2) AS quantidade_restante_total,
    SUM(ISNULL(bi2.u_qtdaut, 0)) AS quantidade_autorizada_total,

    CAST(ISNULL(bo3.u_pickrdy, 0) AS bit) AS pronta_picking,
    LTRIM(RTRIM(ISNULL(bo3.u_pickrdr, ''))) AS pronta_picking_por,
    CASE
        WHEN bo3.u_pickrdt IS NULL OR YEAR(bo3.u_pickrdt) < 1950 THEN CAST(NULL AS datetime)
        ELSE bo3.u_pickrdt
    END AS pronta_picking_em,
    CAST(ISNULL(bo3.u_urgente, 0) AS bit) AS urgente
FROM dbo.bo bo WITH (NOLOCK)
INNER JOIN dbo.bi bi WITH (NOLOCK)
    ON bi.bostamp = bo.bostamp
LEFT JOIN dbo.bi2 bi2 WITH (NOLOCK)
    ON bi2.bi2stamp COLLATE DATABASE_DEFAULT = bi.bistamp COLLATE DATABASE_DEFAULT
LEFT JOIN dbo.bo3 bo3 WITH (NOLOCK)
    ON bo3.bo3stamp COLLATE DATABASE_DEFAULT = bo.bostamp COLLATE DATABASE_DEFAULT
WHERE bo.ndos = 1
  AND ISNULL(bo.fechada, 0) = 0
  AND (ISNULL(NULLIF(bi2.u_qttorig, 0), bi.qtt) - bi.qtt2) > 0
GROUP BY
    bo.bostamp,
    bo.obrano,
    bo.ndos,
    bo.nmdos,
    bo.dataobra,
    bo.ousrhora,
    bo.no,
    bo.estab,
    bo.nome,
    bo3.u_pickrdy,
    bo3.u_pickrdr,
    bo3.u_pickrdt,
    bo3.u_urgente;
GO

CREATE OR ALTER VIEW dbo.view_HCA_encomenda_linhas
AS
SELECT
    bi.bostamp,
    bi.bistamp,
    bo.obrano,
    bo.ndos,
    bo.nmdos,
    bo.dataobra,
    bo.ousrhora,
    ISNULL(bo.fechada, 0) AS fecho,
    CAST(ISNULL(bo3.u_pickrdy, 0) AS bit) AS pronta_picking,
    CAST(ISNULL(bo3.u_urgente, 0) AS bit) AS urgente,
    bo.no AS cliente_no,
    bo.estab AS cliente_estab,
    LTRIM(RTRIM(bo.nome)) AS cliente_nome,

    LTRIM(RTRIM(bi.ref)) AS ref,
    LTRIM(RTRIM(bi.design)) AS design,
    -- Liliana: cor operacional em BI.u_cor (BI.cor nativo costuma vir vazio)
    LTRIM(RTRIM(COALESCE(
        NULLIF(LTRIM(RTRIM(ISNULL(bi.cor, ''))), ''),
        NULLIF(LTRIM(RTRIM(ISNULL(bi.u_cor, ''))), ''),
        ''
    ))) AS cor,
    LTRIM(RTRIM(ISNULL(bi.unidade, ''))) AS unidade,

    bi.qtt AS quantidade_atual,
    bi.qtt2 AS quantidade_fornecida,
    ISNULL(bi2.u_qttorig, 0) AS quantidade_original_campo,
    ISNULL(NULLIF(bi2.u_qttorig, 0), bi.qtt) AS quantidade_original_considerada,
    (ISNULL(NULLIF(bi2.u_qttorig, 0), bi.qtt) - bi.qtt2) AS quantidade_por_satisfazer,

    bi.edebito AS preco_unitario,
    ISNULL(bi2.u_prcorig, 0) AS preco_original_campo,

    ISNULL(bi2.u_qtdaut, 0) AS quantidade_autorizada,
    LTRIM(RTRIM(ISNULL(bi2.u_qtdautur, ''))) AS quantidade_autorizada_por,
    bi2.u_qtdautdt AS quantidade_autorizada_em,

    ISNULL(st.stock, 0) AS stock_disponivel,

    bi.usrinis,
    bi.usrdata,
    bi.usrhora
FROM dbo.bi bi WITH (NOLOCK)
INNER JOIN dbo.bo bo WITH (NOLOCK)
    ON bo.bostamp = bi.bostamp
LEFT JOIN dbo.bi2 bi2 WITH (NOLOCK)
    ON bi2.bi2stamp COLLATE DATABASE_DEFAULT = bi.bistamp COLLATE DATABASE_DEFAULT
LEFT JOIN dbo.bo3 bo3 WITH (NOLOCK)
    ON bo3.bo3stamp COLLATE DATABASE_DEFAULT = bo.bostamp COLLATE DATABASE_DEFAULT
LEFT JOIN dbo.st st WITH (NOLOCK)
    ON LTRIM(RTRIM(st.ref)) = LTRIM(RTRIM(bi.ref));
GO

CREATE OR ALTER VIEW dbo.view_HCA_rastreio_artigos
AS
SELECT
    agg.ref,
    agg.design,
    agg.total_linhas,
    agg.total_encomendas,
    agg.quantidade_encomendada_total,
    agg.quantidade_fornecida_total,
    agg.quantidade_por_satisfazer_total,
    agg.quantidade_autorizada_total,
    ISNULL(st.stock, 0) AS stock_disponivel,
    CASE WHEN ISNULL(st.stock, 0) <= 0 THEN 1 ELSE 0 END AS em_rutura
FROM (
    SELECT
        LTRIM(RTRIM(bi.ref)) AS ref,
        MAX(LTRIM(RTRIM(bi.design))) AS design,
        COUNT(bi.bistamp) AS total_linhas,
        COUNT(DISTINCT bi.bostamp) AS total_encomendas,
        SUM(ISNULL(NULLIF(bi2.u_qttorig, 0), bi.qtt)) AS quantidade_encomendada_total,
        SUM(bi.qtt2) AS quantidade_fornecida_total,
        SUM(ISNULL(NULLIF(bi2.u_qttorig, 0), bi.qtt) - bi.qtt2) AS quantidade_por_satisfazer_total,
        SUM(ISNULL(bi2.u_qtdaut, 0)) AS quantidade_autorizada_total
    FROM dbo.bi bi WITH (NOLOCK)
    INNER JOIN dbo.bo bo WITH (NOLOCK)
        ON bo.bostamp = bi.bostamp
    LEFT JOIN dbo.bi2 bi2 WITH (NOLOCK)
        ON bi2.bi2stamp COLLATE DATABASE_DEFAULT = bi.bistamp COLLATE DATABASE_DEFAULT
    LEFT JOIN dbo.bo3 bo3 WITH (NOLOCK)
        ON bo3.bo3stamp COLLATE DATABASE_DEFAULT = bo.bostamp COLLATE DATABASE_DEFAULT
    WHERE bo.ndos = 1
      AND ISNULL(bo.fechada, 0) = 0
      AND ISNULL(bo3.u_pickrdy, 0) = 0
      AND (ISNULL(NULLIF(bi2.u_qttorig, 0), bi.qtt) - bi.qtt2) > 0
    GROUP BY
        LTRIM(RTRIM(bi.ref))
) agg
LEFT JOIN dbo.st st WITH (NOLOCK)
    ON LTRIM(RTRIM(st.ref)) = agg.ref;
GO

CREATE OR ALTER VIEW dbo.view_HCA_artigo_encomendas
AS
SELECT
    bi.bistamp,
    bi.bostamp,
    LTRIM(RTRIM(bi.ref)) AS ref,
    LTRIM(RTRIM(bi.design)) AS design,

    bo.obrano,
    bo.ndos,
    bo.nmdos,
    bo.dataobra,
    bo.ousrhora,
    ISNULL(bo.fechada, 0) AS fecho,

    bo.no AS cliente_no,
    bo.estab AS cliente_estab,
    LTRIM(RTRIM(bo.nome)) AS cliente_nome,

    bi.qtt AS quantidade_atual,
    bi.qtt2 AS quantidade_fornecida,
    ISNULL(bi2.u_qttorig, 0) AS quantidade_original_campo,
    ISNULL(NULLIF(bi2.u_qttorig, 0), bi.qtt) AS quantidade_pedida,
    (ISNULL(NULLIF(bi2.u_qttorig, 0), bi.qtt) - bi.qtt2) AS quantidade_por_satisfazer,

    ISNULL(bi2.u_qtdaut, 0) AS quantidade_autorizada,
    LTRIM(RTRIM(ISNULL(bi2.u_qtdautur, ''))) AS quantidade_autorizada_por,
    bi2.u_qtdautdt AS quantidade_autorizada_em,

    ISNULL(st.stock, 0) AS stock_disponivel
FROM dbo.bi bi WITH (NOLOCK)
INNER JOIN dbo.bo bo WITH (NOLOCK)
    ON bo.bostamp = bi.bostamp
LEFT JOIN dbo.bi2 bi2 WITH (NOLOCK)
    ON bi2.bi2stamp COLLATE DATABASE_DEFAULT = bi.bistamp COLLATE DATABASE_DEFAULT
LEFT JOIN dbo.bo3 bo3 WITH (NOLOCK)
    ON bo3.bo3stamp COLLATE DATABASE_DEFAULT = bo.bostamp COLLATE DATABASE_DEFAULT
LEFT JOIN dbo.st st WITH (NOLOCK)
    ON LTRIM(RTRIM(st.ref)) = LTRIM(RTRIM(bi.ref))
WHERE bo.ndos = 1
  AND ISNULL(bo.fechada, 0) = 0
  AND ISNULL(bo3.u_pickrdy, 0) = 0
  AND (ISNULL(NULLIF(bi2.u_qttorig, 0), bi.qtt) - bi.qtt2) > 0;
GO

/* ---------- SP: quantidade autorizada ---------- */

CREATE OR ALTER PROCEDURE dbo.sp_HCA_atualizar_qtd_autorizada
    @bistamp                   varchar(25),
    @quantidade_autorizada     numeric(16, 2),
    @usrlogin                  varchar(100),
    @valor_anterior_esperado   numeric(16, 2) = NULL,
    @permitir_acima_stock      bit = 0,
    @usrinis                   varchar(3) = NULL
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    IF @bistamp IS NULL OR LTRIM(RTRIM(@bistamp)) = ''
    BEGIN
        RAISERROR(N'bistamp obrigatÃ³rio.', 16, 1);
        RETURN;
    END;

    IF @quantidade_autorizada IS NULL OR @quantidade_autorizada < 0
    BEGIN
        RAISERROR(N'quantidade_autorizada invÃ¡lida.', 16, 1);
        RETURN;
    END;

    IF @usrlogin IS NULL OR LTRIM(RTRIM(@usrlogin)) = ''
    BEGIN
        RAISERROR(N'usrlogin obrigatÃ³rio.', 16, 1);
        RETURN;
    END;

    DECLARE
        @ref varchar(18),
        @bostamp varchar(25),
        @u_qtdaut_atual numeric(16, 2),
        @u_qtdautur_atual varchar(100),
        @u_qttorig_atual numeric(16, 2),
        @qtt_atual numeric(16, 2),
        @edebito_atual numeric(16, 2),
        @primeira_autorizacao bit,
        @stock numeric(16, 2),
        @soma_outras numeric(16, 2),
        @agora datetime = GETDATE(),
        @usrdata datetime,
        @usrhora varchar(8),
        @usrinis_n varchar(3);

    SET @usrdata = CAST(@agora AS date);
    SET @usrhora = CONVERT(varchar(8), @agora, 108);
    SET @usrinis_n = LEFT(LTRIM(RTRIM(ISNULL(NULLIF(@usrinis, ''), @usrlogin))), 3);

    BEGIN TRAN;

    SELECT
        @ref = LTRIM(RTRIM(bi.ref)),
        @bostamp = bi.bostamp,
        @u_qtdaut_atual = ISNULL(bi2.u_qtdaut, 0),
        @u_qtdautur_atual = ISNULL(bi2.u_qtdautur, ''),
        @u_qttorig_atual = ISNULL(bi2.u_qttorig, 0),
        @qtt_atual = bi.qtt,
        @edebito_atual = bi.edebito
    FROM dbo.bi bi WITH (UPDLOCK, ROWLOCK)
    INNER JOIN dbo.bo bo WITH (UPDLOCK, ROWLOCK)
        ON bo.bostamp COLLATE DATABASE_DEFAULT = bi.bostamp COLLATE DATABASE_DEFAULT
    LEFT JOIN dbo.bi2 bi2 WITH (UPDLOCK, ROWLOCK)
        ON bi2.bi2stamp COLLATE DATABASE_DEFAULT = bi.bistamp COLLATE DATABASE_DEFAULT
    WHERE bi.bistamp COLLATE DATABASE_DEFAULT = @bistamp COLLATE DATABASE_DEFAULT
      AND bo.ndos = 1
      AND ISNULL(bo.fechada, 0) = 0;

    IF @ref IS NULL
    BEGIN
        ROLLBACK;
        RAISERROR(N'Linha nÃ£o encontrada ou documento fechado/sÃ©rie invÃ¡lida.', 16, 1);
        RETURN;
    END;

    IF NOT EXISTS (
        SELECT 1 FROM dbo.bi2 WITH (UPDLOCK, ROWLOCK)
        WHERE bi2stamp COLLATE DATABASE_DEFAULT = @bistamp COLLATE DATABASE_DEFAULT
    )
    BEGIN
        INSERT INTO dbo.bi2 (bi2stamp)
        VALUES (@bistamp);
    END;

    IF @valor_anterior_esperado IS NOT NULL AND @u_qtdaut_atual <> @valor_anterior_esperado
    BEGIN
        ROLLBACK;
        RAISERROR(N'Conflito de concorrÃªncia na quantidade autorizada.', 16, 1);
        RETURN;
    END;

    SET @primeira_autorizacao = CASE
        WHEN LTRIM(RTRIM(ISNULL(@u_qtdautur_atual, ''))) = '' THEN 1
        ELSE 0
    END;

    SELECT @stock = ISNULL(st.stock, 0)
    FROM dbo.st st WITH (UPDLOCK, ROWLOCK)
    WHERE LTRIM(RTRIM(st.ref)) COLLATE DATABASE_DEFAULT = @ref COLLATE DATABASE_DEFAULT;

    SET @stock = ISNULL(@stock, 0);

    SELECT @soma_outras = ISNULL(SUM(ISNULL(bi2.u_qtdaut, 0)), 0)
    FROM dbo.bi bi WITH (UPDLOCK, ROWLOCK)
    INNER JOIN dbo.bo bo WITH (NOLOCK)
        ON bo.bostamp COLLATE DATABASE_DEFAULT = bi.bostamp COLLATE DATABASE_DEFAULT
    LEFT JOIN dbo.bi2 bi2 WITH (NOLOCK)
        ON bi2.bi2stamp COLLATE DATABASE_DEFAULT = bi.bistamp COLLATE DATABASE_DEFAULT
    WHERE LTRIM(RTRIM(bi.ref)) COLLATE DATABASE_DEFAULT = @ref COLLATE DATABASE_DEFAULT
      AND bi.bistamp COLLATE DATABASE_DEFAULT <> @bistamp COLLATE DATABASE_DEFAULT
      AND bo.ndos = 1
      AND ISNULL(bo.fechada, 0) = 0
      AND (ISNULL(NULLIF(bi2.u_qttorig, 0), bi.qtt) - bi.qtt2) > 0;

    -- Soma > ST.stock → erro, salvo @permitir_acima_stock = 1
    IF ISNULL(@permitir_acima_stock, 0) = 0
       AND (@soma_outras + @quantidade_autorizada) > @stock
    BEGIN
        ROLLBACK;
        RAISERROR(N'Stock insuficiente: quantidades autorizadas excede o stock existente.', 16, 1);
        RETURN;
    END;

    IF @primeira_autorizacao = 1
    BEGIN
        -- Original = quantidade inicial encomendada; grava uma vez e nunca sobrescreve.
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
        u_qtdautdt = @agora
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
        @stock AS stock_disponivel,
        (@soma_outras + @quantidade_autorizada) AS soma_autorizada_artigo,
        @primeira_autorizacao AS primeira_autorizacao
    FROM dbo.bi bi WITH (NOLOCK)
    LEFT JOIN dbo.bi2 bi2 WITH (NOLOCK)
        ON bi2.bi2stamp COLLATE DATABASE_DEFAULT = bi.bistamp COLLATE DATABASE_DEFAULT
    WHERE bi.bistamp COLLATE DATABASE_DEFAULT = @bistamp COLLATE DATABASE_DEFAULT;
END;
GO

/* ---------- SP: linha qtt / preÃ§o ---------- */

CREATE OR ALTER PROCEDURE dbo.sp_HCA_atualizar_linha_qtt_preco
    @bistamp              varchar(25),
    @quantidade           numeric(16, 2) = NULL,
    @preco                numeric(16, 2) = NULL,
    @usrinis              varchar(3),
    @qtt_anterior_esperado   numeric(16, 2) = NULL,
    @preco_anterior_esperado numeric(16, 2) = NULL
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    IF @bistamp IS NULL OR LTRIM(RTRIM(@bistamp)) = ''
    BEGIN
        RAISERROR(N'bistamp obrigatÃ³rio.', 16, 1);
        RETURN;
    END;

    IF @quantidade IS NULL AND @preco IS NULL
    BEGIN
        RAISERROR(N'Indicar quantidade e/ou preÃ§o.', 16, 1);
        RETURN;
    END;

    IF @usrinis IS NULL OR LTRIM(RTRIM(@usrinis)) = ''
    BEGIN
        RAISERROR(N'usrinis obrigatÃ³rio.', 16, 1);
        RETURN;
    END;

    DECLARE
        @bostamp varchar(25),
        @qtt_atual numeric(16, 2),
        @edebito_atual numeric(16, 2),
        @u_qttorig numeric(16, 2),
        @u_prcorig numeric(16, 2),
        @qtt_nova numeric(16, 2),
        @edebito_novo numeric(16, 2),
        @ettdeb_novo numeric(16, 2),
        @agora datetime = GETDATE(),
        @usrdata datetime,
        @usrhora varchar(8);

    SET @usrdata = CAST(@agora AS date);
    SET @usrhora = CONVERT(varchar(8), @agora, 108);

    BEGIN TRAN;

    SELECT
        @bostamp = bi.bostamp,
        @qtt_atual = bi.qtt,
        @edebito_atual = bi.edebito,
        @u_qttorig = ISNULL(bi2.u_qttorig, 0),
        @u_prcorig = ISNULL(bi2.u_prcorig, 0)
    FROM dbo.bi bi WITH (UPDLOCK, ROWLOCK)
    INNER JOIN dbo.bo bo WITH (UPDLOCK, ROWLOCK)
        ON bo.bostamp = bi.bostamp
    LEFT JOIN dbo.bi2 bi2 WITH (UPDLOCK, ROWLOCK)
        ON bi2.bi2stamp COLLATE DATABASE_DEFAULT = bi.bistamp COLLATE DATABASE_DEFAULT
    WHERE bi.bistamp = @bistamp
      AND bo.ndos = 1
      AND ISNULL(bo.fechada, 0) = 0;

    IF @bostamp IS NULL
    BEGIN
        ROLLBACK;
        RAISERROR(N'Linha de encomenda nÃ£o encontrada ou documento fechado/sÃ©rie invÃ¡lida.', 16, 1);
        RETURN;
    END;

    IF NOT EXISTS (
        SELECT 1 FROM dbo.bi2 WITH (UPDLOCK, ROWLOCK)
        WHERE bi2stamp COLLATE DATABASE_DEFAULT = @bistamp COLLATE DATABASE_DEFAULT
    )
        INSERT INTO dbo.bi2 (bi2stamp) VALUES (@bistamp);

    IF @qtt_anterior_esperado IS NOT NULL AND @qtt_atual <> @qtt_anterior_esperado
    BEGIN
        ROLLBACK;
        RAISERROR(N'Conflito de concorrÃªncia na quantidade (valor anterior diferente).', 16, 1);
        RETURN;
    END;

    IF @preco_anterior_esperado IS NOT NULL AND @edebito_atual <> @preco_anterior_esperado
    BEGIN
        ROLLBACK;
        RAISERROR(N'Conflito de concorrÃªncia no preÃ§o (valor anterior diferente).', 16, 1);
        RETURN;
    END;

    SET @qtt_nova = ISNULL(@quantidade, @qtt_atual);
    SET @edebito_novo = ISNULL(@preco, @edebito_atual);

    IF @quantidade IS NOT NULL AND ISNULL(@u_qttorig, 0) = 0
        SET @u_qttorig = @qtt_atual;

    IF @preco IS NOT NULL AND ISNULL(@u_prcorig, 0) = 0
        SET @u_prcorig = @edebito_atual;

    SET @ettdeb_novo = ROUND(@qtt_nova * @edebito_novo, 2);

    UPDATE dbo.bi
    SET
        qtt = @qtt_nova,
        edebito = @edebito_novo,
        ettdeb = @ettdeb_novo,
        usrinis = LEFT(LTRIM(RTRIM(@usrinis)), 3),
        usrdata = @usrdata,
        usrhora = @usrhora
    WHERE bistamp = @bistamp;

    UPDATE dbo.bi2
    SET
        u_qttorig = @u_qttorig,
        u_prcorig = @u_prcorig
    WHERE bi2stamp COLLATE DATABASE_DEFAULT = @bistamp COLLATE DATABASE_DEFAULT;

    UPDATE dbo.bo
    SET
        usrinis = LEFT(LTRIM(RTRIM(@usrinis)), 3),
        usrdata = @usrdata,
        usrhora = @usrhora
    WHERE bostamp = @bostamp;

    COMMIT;

    SELECT
        bi.bistamp,
        bi.bostamp,
        bi.qtt AS quantidade_atual,
        ISNULL(bi2.u_qttorig, 0) AS quantidade_original_campo,
        bi.edebito AS preco_unitario,
        ISNULL(bi2.u_prcorig, 0) AS preco_original_campo,
        bi.ettdeb,
        bi.usrinis,
        bi.usrdata,
        bi.usrhora
    FROM dbo.bi bi WITH (NOLOCK)
    LEFT JOIN dbo.bi2 bi2 WITH (NOLOCK)
        ON bi2.bi2stamp COLLATE DATABASE_DEFAULT = bi.bistamp COLLATE DATABASE_DEFAULT
    WHERE bi.bistamp = @bistamp;
END;
GO

/* ---------- SP: alocaÃ§Ã£o proporcional ---------- */

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
        RAISERROR(N'ref obrigatÃ³ria.', 16, 1);
        RETURN;
    END;

    IF @simular = 0 AND (@usrlogin IS NULL OR LTRIM(RTRIM(@usrlogin)) = '')
    BEGIN
        RAISERROR(N'usrlogin obrigatÃ³rio para gravar.', 16, 1);
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
        rn int NULL,
        primeira bit NOT NULL DEFAULT 0
    );

    BEGIN TRAN;

    SELECT @stock = ISNULL(st.stock, 0)
    FROM dbo.st st WITH (UPDLOCK, ROWLOCK)
    WHERE LTRIM(RTRIM(st.ref)) COLLATE DATABASE_DEFAULT
        = @ref_n COLLATE DATABASE_DEFAULT;

    SET @stock = ISNULL(@stock, 0);

    IF @disponivel IS NULL
        SET @disponivel_usado = @stock;
    ELSE IF @disponivel < 0
        SET @disponivel_usado = 0;
    ELSE
        SET @disponivel_usado = @disponivel;

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

        -- 1) preservar qtt em bi2.u_qttorig (antes de alterar qtt)
        UPDATE bi2
        SET u_qttorig = bi.qtt
        FROM dbo.bi2 bi2
        INNER JOIN #linhas l
            ON l.bistamp COLLATE DATABASE_DEFAULT = bi2.bi2stamp COLLATE DATABASE_DEFAULT
        INNER JOIN dbo.bi bi
            ON bi.bistamp COLLATE DATABASE_DEFAULT = bi2.bi2stamp COLLATE DATABASE_DEFAULT
        WHERE l.primeira = 1
          AND ISNULL(bi2.u_qttorig, 0) = 0;

        -- 2) qtt <- auth_final
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

        -- 3) u_qtdaut*
        UPDATE bi2
        SET
            u_qtdaut = l.auth_final,
            u_qtdautur = LEFT(LTRIM(RTRIM(@usrlogin)), 100),
            u_qtdautdt = @agora
        FROM dbo.bi2 bi2
        INNER JOIN #linhas l
            ON l.bistamp COLLATE DATABASE_DEFAULT = bi2.bi2stamp COLLATE DATABASE_DEFAULT;
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

/* ---------- SP: marcar pronta picking ---------- */

CREATE OR ALTER PROCEDURE dbo.sp_HCA_marcar_pronta_picking
    @bostamp                varchar(25),
    @pronta                 bit,
    @usrlogin               varchar(100),
    @usrinis                varchar(3) = NULL,
    @confirmar_linhas_zero  bit = 0
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

    DECLARE
        @agora datetime = GETDATE(),
        @usrdata datetime,
        @usrhora varchar(8),
        @usrinis_n varchar(3),
        @linhas_zero int = 0;

    SET @usrdata = CAST(@agora AS date);
    SET @usrhora = CONVERT(varchar(8), @agora, 108);
    SET @usrinis_n = LEFT(LTRIM(RTRIM(ISNULL(NULLIF(@usrinis, ''), @usrlogin))), 3);

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

    IF ISNULL(@pronta, 0) = 1
    BEGIN
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
            SET u_qttorig = CASE
                WHEN ISNULL(bi2.u_qttorig, 0) = 0 THEN bi.qtt
                ELSE bi2.u_qttorig
            END
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
    END;
    ELSE
    BEGIN
        -- Cancelar picking: restaurar quantidades ao estado antes das autorizações.
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
            u_qtdautdt = CAST('19000101' AS datetime)
        FROM dbo.bi2 bi2
        INNER JOIN dbo.bi bi
            ON bi.bistamp COLLATE DATABASE_DEFAULT = bi2.bi2stamp COLLATE DATABASE_DEFAULT
        WHERE bi.bostamp COLLATE DATABASE_DEFAULT = @bostamp COLLATE DATABASE_DEFAULT;
    END;

    UPDATE dbo.bo3
    SET
        u_pickrdy = ISNULL(@pronta, 0),
        u_pickrdr = LEFT(LTRIM(RTRIM(@usrlogin)), 100),
        u_pickrdt = @agora
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
        END AS pronta_picking_em
    FROM dbo.bo bo WITH (NOLOCK)
    LEFT JOIN dbo.bo3 bo3 WITH (NOLOCK)
        ON bo3.bo3stamp COLLATE DATABASE_DEFAULT = bo.bostamp COLLATE DATABASE_DEFAULT
    WHERE bo.bostamp COLLATE DATABASE_DEFAULT = @bostamp COLLATE DATABASE_DEFAULT;
END;
GO
