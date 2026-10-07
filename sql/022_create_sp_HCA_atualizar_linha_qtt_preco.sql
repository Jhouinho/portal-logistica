-- =============================================================================
-- Liliana & Seródio — Portal Logístico
-- Script: 022_create_sp_HCA_atualizar_linha_qtt_preco.sql
-- Ambiente: UAT / teste; Produção só no GO formal
-- =============================================================================
-- RN-020 / RN-021:
--   - Se u_qttorig = 0 → gravar BI.qtt atual; atualizar qtt
--   - Se u_prcorig = 0 → gravar BI.edebito atual; atualizar edebito
--   - usr* em BI + BO; nunca ousr*
-- Totais linha (MVP UAT):
--   - Recalcula BI.ettdeb = qtt * edebito (campo confirmado Enciclopédia / u_bodebito)
--   - NÃO usa BI.etiliquido (inexistente nesta BD UAT)
--   - Cabeçalho BO: só usr* até discovery dos nomes de totais (ver 023a)
-- =============================================================================

CREATE OR ALTER PROCEDURE dbo.sp_HCA_atualizar_linha_qtt_preco
    @bistamp              varchar(25),
    @quantidade           numeric(16, 2) = NULL,  -- RN-020 (opcional)
    @preco                numeric(16, 2) = NULL,  -- RN-021 edebito (opcional)
    @usrinis              varchar(3),
    @qtt_anterior_esperado   numeric(16, 2) = NULL,  -- concorrência opcional
    @preco_anterior_esperado numeric(16, 2) = NULL   -- concorrência opcional
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    IF @bistamp IS NULL OR LTRIM(RTRIM(@bistamp)) = ''
    BEGIN
        RAISERROR(N'bistamp obrigatório.', 16, 1);
        RETURN;
    END;

    IF @quantidade IS NULL AND @preco IS NULL
    BEGIN
        RAISERROR(N'Indicar quantidade e/ou preço.', 16, 1);
        RETURN;
    END;

    IF @usrinis IS NULL OR LTRIM(RTRIM(@usrinis)) = ''
    BEGIN
        RAISERROR(N'usrinis obrigatório.', 16, 1);
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
        @u_qttorig = bi.u_qttorig,
        @u_prcorig = bi.u_prcorig
    FROM dbo.bi bi WITH (UPDLOCK, ROWLOCK)
    INNER JOIN dbo.bo bo WITH (UPDLOCK, ROWLOCK)
        ON bo.bostamp = bi.bostamp
    WHERE bi.bistamp = @bistamp
      AND bo.ndos = 1
      AND ISNULL(bo.fechada, 0) = 0;

    IF @bostamp IS NULL
    BEGIN
        ROLLBACK;
        RAISERROR(N'Linha de encomenda não encontrada ou documento fechado/série inválida.', 16, 1);
        RETURN;
    END;

    IF @qtt_anterior_esperado IS NOT NULL AND @qtt_atual <> @qtt_anterior_esperado
    BEGIN
        ROLLBACK;
        RAISERROR(N'Conflito de concorrência na quantidade (valor anterior diferente).', 16, 1);
        RETURN;
    END;

    IF @preco_anterior_esperado IS NOT NULL AND @edebito_atual <> @preco_anterior_esperado
    BEGIN
        ROLLBACK;
        RAISERROR(N'Conflito de concorrência no preço (valor anterior diferente).', 16, 1);
        RETURN;
    END;

    SET @qtt_nova = ISNULL(@quantidade, @qtt_atual);
    SET @edebito_novo = ISNULL(@preco, @edebito_atual);

    -- RN-020: preservar original na 1.ª alteração
    IF @quantidade IS NOT NULL AND ISNULL(@u_qttorig, 0) = 0
        SET @u_qttorig = @qtt_atual;

    -- RN-021: preservar original na 1.ª alteração
    IF @preco IS NOT NULL AND ISNULL(@u_prcorig, 0) = 0
        SET @u_prcorig = @edebito_atual;

    -- Total linha (ilíquido): qtt * preço unitário
    SET @ettdeb_novo = ROUND(@qtt_nova * @edebito_novo, 2);

    UPDATE dbo.bi
    SET
        qtt = @qtt_nova,
        edebito = @edebito_novo,
        u_qttorig = @u_qttorig,
        u_prcorig = @u_prcorig,
        ettdeb = @ettdeb_novo,
        usrinis = LEFT(LTRIM(RTRIM(@usrinis)), 3),
        usrdata = @usrdata,
        usrhora = @usrhora
    WHERE bistamp = @bistamp;

    -- Cabeçalho: auditoria nativa (totais BO ficam para após discovery 023a)
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
        bi.u_qttorig AS quantidade_original_campo,
        bi.edebito AS preco_unitario,
        bi.u_prcorig AS preco_original_campo,
        bi.ettdeb,
        bi.usrinis,
        bi.usrdata,
        bi.usrhora
    FROM dbo.bi bi WITH (NOLOCK)
    WHERE bi.bistamp = @bistamp;
END;
GO
