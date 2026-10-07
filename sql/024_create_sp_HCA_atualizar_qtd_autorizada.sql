-- =============================================================================
-- Liliana & Seródio — Portal Logístico
-- Script: 024_create_sp_HCA_atualizar_qtd_autorizada.sql
-- Ambiente: UAT / teste; Produção só no GO formal
-- =============================================================================
-- Atualiza BI.u_qtdaut / u_qtdautur / u_qtdautdt
-- 1.ª alteração de u_qtdaut (u_qtdautur vazio):
--   1) u_qttorig = qtt actual
--   2) qtt = quantidade autorizada (+ ettdeb)
-- Alterações seguintes: só u_qtdaut*
-- Soma > ST.stock → erro, salvo @permitir_acima_stock = 1
-- =============================================================================

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

    DECLARE
        @ref varchar(18),
        @bostamp varchar(25),
        @u_qtdaut_atual numeric(16, 2),
        @u_qtdautur_atual varchar(100),
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
        @u_qtdaut_atual = bi.u_qtdaut,
        @u_qtdautur_atual = bi.u_qtdautur,
        @qtt_atual = bi.qtt,
        @edebito_atual = bi.edebito
    FROM dbo.bi bi WITH (UPDLOCK, ROWLOCK)
    INNER JOIN dbo.bo bo WITH (UPDLOCK, ROWLOCK)
        ON bo.bostamp COLLATE DATABASE_DEFAULT = bi.bostamp COLLATE DATABASE_DEFAULT
    WHERE bi.bistamp COLLATE DATABASE_DEFAULT = @bistamp COLLATE DATABASE_DEFAULT
      AND bo.ndos = 1
      AND ISNULL(bo.fechada, 0) = 0;

    IF @ref IS NULL
    BEGIN
        ROLLBACK;
        RAISERROR(N'Linha não encontrada ou documento fechado/série inválida.', 16, 1);
        RETURN;
    END;

    IF @valor_anterior_esperado IS NOT NULL AND @u_qtdaut_atual <> @valor_anterior_esperado
    BEGIN
        ROLLBACK;
        RAISERROR(N'Conflito de concorrência na quantidade autorizada.', 16, 1);
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

    SELECT @soma_outras = ISNULL(SUM(bi.u_qtdaut), 0)
    FROM dbo.bi bi WITH (UPDLOCK, ROWLOCK)
    INNER JOIN dbo.bo bo WITH (NOLOCK)
        ON bo.bostamp COLLATE DATABASE_DEFAULT = bi.bostamp COLLATE DATABASE_DEFAULT
    WHERE LTRIM(RTRIM(bi.ref)) COLLATE DATABASE_DEFAULT = @ref COLLATE DATABASE_DEFAULT
      AND bi.bistamp COLLATE DATABASE_DEFAULT <> @bistamp COLLATE DATABASE_DEFAULT
      AND bo.ndos = 1
      AND ISNULL(bo.fechada, 0) = 0
      AND (ISNULL(NULLIF(bi.u_qttorig, 0), bi.qtt) - bi.qtt2) > 0;

    IF ISNULL(@permitir_acima_stock, 0) = 0
       AND (@soma_outras + @quantidade_autorizada) > @stock
    BEGIN
        ROLLBACK;
        RAISERROR(N'Stock insuficiente: quantidades autorizadas excede o stock existente.', 16, 1);
        RETURN;
    END;

    IF @primeira_autorizacao = 1
    BEGIN
        -- 1) preservar qtt actual em u_qttorig e actualizar qtt
        UPDATE dbo.bi
        SET
            u_qttorig = @qtt_atual,
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

    -- Sempre por último: u_qtdaut* (evita side-effects de triggers ao alterar qtt)
    UPDATE dbo.bi
    SET
        u_qtdaut = @quantidade_autorizada,
        u_qtdautur = LEFT(LTRIM(RTRIM(@usrlogin)), 100),
        u_qtdautdt = @agora
    WHERE bistamp COLLATE DATABASE_DEFAULT = @bistamp COLLATE DATABASE_DEFAULT;

    COMMIT;

    SELECT
        bi.bistamp,
        bi.bostamp,
        LTRIM(RTRIM(bi.ref)) AS ref,
        bi.u_qtdaut AS quantidade_autorizada,
        LTRIM(RTRIM(bi.u_qtdautur)) AS quantidade_autorizada_por,
        bi.u_qtdautdt AS quantidade_autorizada_em,
        bi.qtt AS quantidade_atual,
        bi.u_qttorig AS quantidade_original_campo,
        ISNULL(NULLIF(bi.u_qttorig, 0), bi.qtt) AS quantidade_original_considerada,
        bi.qtt2 AS quantidade_fornecida,
        @stock AS stock_disponivel,
        (@soma_outras + @quantidade_autorizada) AS soma_autorizada_artigo,
        @primeira_autorizacao AS primeira_autorizacao
    FROM dbo.bi bi WITH (NOLOCK)
    WHERE bi.bistamp COLLATE DATABASE_DEFAULT = @bistamp COLLATE DATABASE_DEFAULT;
END;
GO
