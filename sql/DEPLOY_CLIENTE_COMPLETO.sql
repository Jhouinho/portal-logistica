/* ============================================================
   DEPLOY CLIENTE — Portal Liliana & Seródio
   Gerado por tools/gen_sql_cliente_md.py
   Pré-requisito: campos U_* no Framework.
   NÃO inclui 090 seed de testes.
   ============================================================ */
SET NOCOUNT ON;
GO


/* ========== 01 / 010_create_view_HCA_utilizadores.sql ========== */
-- =============================================================================
-- Liliana & Seródio — Portal Logístico
-- Script: 010_create_view_HCA_utilizadores.sql
-- Ambiente: UAT primeiro; repetir o mesmo script em Produção
-- =============================================================================
-- Objetivo:
--   Vista de leitura com dados mínimos de US para o portal.
--   Acesso: utilizadores activos com u_usaPort = 1.
-- =============================================================================

CREATE OR ALTER VIEW dbo.view_HCA_utilizadores
AS
SELECT
    us.usstamp AS userstamp,
    LTRIM(RTRIM(us.usercode)) AS login,
    LTRIM(RTRIM(us.username)) AS nome,
    LTRIM(RTRIM(us.iniciais)) AS usrinis,
    LTRIM(RTRIM(us.email)) AS email,
    us.u_portalph AS portal_hash
FROM dbo.us us WITH (NOLOCK)
WHERE ISNULL(us.inactivo, 0) = 0
  AND us.u_usaPort = 1;
GO
GO


/* ========== 02 / 012_create_view_HCA_encomendas_abertas.sql ========== */
-- =============================================================================
-- Liliana & Seródio — Portal Logístico
-- Script: 037_alter_view_HCA_encomendas_abertas_picking.sql
-- Ambiente: UAT / teste; Produção só no GO formal
-- Pré-requisitos: BO.u_pickrdy, BO.u_upickrdr, BO.u_upickrdt
-- =============================================================================

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

    SUM(ISNULL(NULLIF(bi.u_qttorig, 0), bi.qtt)) AS quantidade_original_total,

    SUM(bi.qtt) AS quantidade_atual_total,

    SUM(bi.qtt2) AS quantidade_fornecida_total,

    SUM(ISNULL(NULLIF(bi.u_qttorig, 0), bi.qtt) - bi.qtt2) AS quantidade_restante_total,

    SUM(bi.u_qtdaut) AS quantidade_autorizada_total,

    CAST(ISNULL(bo.u_pickrdy, 0) AS bit) AS pronta_picking,
    LTRIM(RTRIM(bo.u_upickrdr)) AS pronta_picking_por,
    CASE
        WHEN bo.u_upickrdt IS NULL OR YEAR(bo.u_upickrdt) < 1950 THEN CAST(NULL AS datetime)
        ELSE bo.u_upickrdt
    END AS pronta_picking_em

FROM dbo.bo bo WITH (NOLOCK)
INNER JOIN dbo.bi bi WITH (NOLOCK)
    ON bi.bostamp = bo.bostamp
WHERE bo.ndos = 1
  AND ISNULL(bo.fechada, 0) = 0
  AND (ISNULL(NULLIF(bi.u_qttorig, 0), bi.qtt) - bi.qtt2) > 0
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
    bo.u_pickrdy,
    bo.u_upickrdr,
    bo.u_upickrdt;
GO
GO


/* ========== 03 / 014_create_view_HCA_encomenda_linhas.sql ========== */
-- =============================================================================
-- Liliana & Seródio — Portal Logístico
-- Script: 014_create_view_HCA_encomenda_linhas.sql
-- Ambiente: UAT / teste primeiro; Produção só no fim da implementação (GO formal)
-- Pré-requisitos: campos BI u_qttorig, u_prcorig, u_qtdaut, u_qtdautur, u_qtdautdt
-- =============================================================================
-- Objetivo:
--   Uma linha por BI (detalhe da encomenda). Filtro API: WHERE bostamp = @boStamp.
--   Restante: ISNULL(NULLIF(BI.u_qttorig, 0), BI.qtt) - BI.qtt2
--   Stock disponível (RN-018): ST.stock
--   Representante / vendedor: fora de âmbito (sem filtro).
-- =============================================================================

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
    bo.no AS cliente_no,
    bo.estab AS cliente_estab,
    LTRIM(RTRIM(bo.nome)) AS cliente_nome,

    LTRIM(RTRIM(bi.ref)) AS ref,
    LTRIM(RTRIM(bi.design)) AS design,
    LTRIM(RTRIM(bi.cor)) AS cor,
    LTRIM(RTRIM(ISNULL(bi.unidade, ''))) AS unidade,

    bi.qtt AS quantidade_atual,
    bi.qtt2 AS quantidade_fornecida,
    bi.u_qttorig AS quantidade_original_campo,
    ISNULL(NULLIF(bi.u_qttorig, 0), bi.qtt) AS quantidade_original_considerada,
    (ISNULL(NULLIF(bi.u_qttorig, 0), bi.qtt) - bi.qtt2) AS quantidade_por_satisfazer,

    bi.edebito AS preco_unitario,
    bi.u_prcorig AS preco_original_campo,

    bi.u_qtdaut AS quantidade_autorizada,
    LTRIM(RTRIM(bi.u_qtdautur)) AS quantidade_autorizada_por,
    bi.u_qtdautdt AS quantidade_autorizada_em,

    ISNULL(st.stock, 0) AS stock_disponivel,

    LTRIM(RTRIM(bi.usrinis)) AS usrinis,
    bi.usrdata,
    bi.usrhora
FROM dbo.bi bi WITH (NOLOCK)
INNER JOIN dbo.bo bo WITH (NOLOCK)
    ON bo.bostamp = bi.bostamp
LEFT JOIN dbo.st st WITH (NOLOCK)
    ON LTRIM(RTRIM(st.ref)) = LTRIM(RTRIM(bi.ref))
WHERE bo.ndos = 1;
GO
GO


/* ========== 04 / 016_create_view_HCA_rastreio_artigos.sql ========== */
-- =============================================================================
-- Liliana & Seródio — Portal Logístico
-- Script: 016_create_view_HCA_rastreio_artigos.sql
-- Ambiente: UAT / teste primeiro; Produção só no fim da implementação (GO formal)
-- Pré-requisitos: campos BI u_qttorig, u_qtdaut*; vistas 012/014 validadas em UAT
-- =============================================================================
-- Objetivo:
--   Agregação da procura aberta por artigo (ref) + ST.stock (RN-018).
--   API: GET /artigos/procura-aberta
-- Filtros (iguais a encomendas abertas):
--   BO.ndos = 1, documento aberto, restante > 0
-- Nota: campo físico de fecho em UAT = BO.fechada (alias lógico: fecho)
-- =============================================================================

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
        SUM(ISNULL(NULLIF(bi.u_qttorig, 0), bi.qtt)) AS quantidade_encomendada_total,
        SUM(bi.qtt2) AS quantidade_fornecida_total,
        SUM(ISNULL(NULLIF(bi.u_qttorig, 0), bi.qtt) - bi.qtt2) AS quantidade_por_satisfazer_total,
        SUM(bi.u_qtdaut) AS quantidade_autorizada_total
    FROM dbo.bi bi WITH (NOLOCK)
    INNER JOIN dbo.bo bo WITH (NOLOCK)
        ON bo.bostamp = bi.bostamp
    WHERE bo.ndos = 1
      AND ISNULL(bo.fechada, 0) = 0
      AND (ISNULL(NULLIF(bi.u_qttorig, 0), bi.qtt) - bi.qtt2) > 0
    GROUP BY
        LTRIM(RTRIM(bi.ref))
) agg
LEFT JOIN dbo.st st WITH (NOLOCK)
    ON LTRIM(RTRIM(st.ref)) = agg.ref;
GO
GO


/* ========== 05 / 018_create_view_HCA_artigo_encomendas.sql ========== */
-- =============================================================================
-- Liliana & Seródio — Portal Logístico
-- Script: 018_create_view_HCA_artigo_encomendas.sql
-- Ambiente: UAT / teste primeiro; Produção só no fim da implementação (GO formal)
-- Pré-requisitos: campos BI u_qttorig, u_qtdaut*; vistas 012/014/016
-- =============================================================================
-- Objetivo:
--   Linhas / encomendas abertas por artigo (ref).
--   API: GET /artigos/{ref}/encomendas-abertas → WHERE ref = @ref
-- Filtros: ndos = 1, documento aberto, restante > 0
-- Nota: campo físico de fecho em UAT = BO.fechada
-- =============================================================================

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
    bi.u_qttorig AS quantidade_original_campo,
    ISNULL(NULLIF(bi.u_qttorig, 0), bi.qtt) AS quantidade_pedida,
    (ISNULL(NULLIF(bi.u_qttorig, 0), bi.qtt) - bi.qtt2) AS quantidade_por_satisfazer,

    bi.u_qtdaut AS quantidade_autorizada,
    LTRIM(RTRIM(bi.u_qtdautur)) AS quantidade_autorizada_por,
    bi.u_qtdautdt AS quantidade_autorizada_em,

    ISNULL(st.stock, 0) AS stock_disponivel
FROM dbo.bi bi WITH (NOLOCK)
INNER JOIN dbo.bo bo WITH (NOLOCK)
    ON bo.bostamp = bi.bostamp
LEFT JOIN dbo.st st WITH (NOLOCK)
    ON LTRIM(RTRIM(st.ref)) = LTRIM(RTRIM(bi.ref))
WHERE bo.ndos = 1
  AND ISNULL(bo.fechada, 0) = 0
  AND (ISNULL(NULLIF(bi.u_qttorig, 0), bi.qtt) - bi.qtt2) > 0;
GO
GO


/* ========== 06 / 020_create_sp_HCA_validar_login.sql ========== */
-- =============================================================================
-- Liliana & Seródio — Portal Logístico
-- Script: 020_create_sp_HCA_validar_login.sql
-- Ambiente: UAT / teste; Produção só no GO formal
-- =============================================================================
-- Exceção técnica (não é escrita de negócio):
--   Devolve dados mínimos de US activo com u_usaPort = 1.
--   Login do portal = US.usercode; email serve para ligar ao Identity.
-- =============================================================================

CREATE OR ALTER PROCEDURE dbo.sp_HCA_validar_login
    @login varchar(20)
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    IF @login IS NULL OR LTRIM(RTRIM(@login)) = ''
    BEGIN
        RAISERROR(N'Login (usercode) obrigatório.', 16, 1);
        RETURN;
    END;

    SELECT
        us.usstamp AS userstamp,
        LTRIM(RTRIM(us.usercode)) AS login,
        LTRIM(RTRIM(us.username)) AS nome,
        LTRIM(RTRIM(us.iniciais)) AS usrinis,
        LTRIM(RTRIM(us.email)) AS email,
        us.u_portalph AS portal_hash
    FROM dbo.us us WITH (NOLOCK)
    WHERE LOWER(LTRIM(RTRIM(us.usercode))) = LOWER(LTRIM(RTRIM(@login)))
      AND ISNULL(us.inactivo, 0) = 0
      AND us.u_usaPort = 1
      AND LTRIM(RTRIM(ISNULL(us.email, ''))) <> '';
END;
GO
GO


/* ========== 07 / 022_create_sp_HCA_atualizar_linha_qtt_preco.sql ========== */
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
GO


/* ========== 08 / 024_create_sp_HCA_atualizar_qtd_autorizada.sql ========== */
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
GO


/* ========== 09 / 026_create_sp_HCA_alocacao_proporcional.sql ========== */
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
GO


/* ========== 10 / 028_add_us_u_usaPort.sql ========== */
-- =============================================================================
-- Liliana & Seródio — Portal Logístico
-- Script: 028_add_us_u_usaPort.sql
-- Ambiente: UAT primeiro; Produção só no GO formal
-- =============================================================================
-- Preferível criar via Supervisor → Framework PHC (campos de utilizador) e
-- «Atualizar a Tabela». Este script é fallback SQL directo.
-- =============================================================================

IF COL_LENGTH('dbo.us', 'u_usaPort') IS NULL
BEGIN
    ALTER TABLE dbo.us ADD u_usaPort bit NOT NULL
        CONSTRAINT DF_us_u_usaPort DEFAULT (0);
END;
GO

-- Exemplo piloto UAT (ajustar email):
-- UPDATE dbo.us SET u_usaPort = 1
-- WHERE LOWER(LTRIM(RTRIM(email))) = LOWER(N'joao.lopes@hcaraujo.pt');
GO
GO


/* ========== 11 / 029_create_u_HcaLogi_identity_tables.sql ========== */
-- =============================================================================
-- Liliana & Seródio — Portal Logístico
-- Script: 029_create_u_HcaLogi_identity_tables.sql
-- Ambiente: UAT primeiro; Produção só no GO formal
-- =============================================================================
-- ASP.NET Core Identity — tabelas físicas com prefixo u_HcaLogi*
-- Equivalente à migration EF: InitialIdentityHcaLogi (8.0.22)
-- Pré-requisito opcional: 028 (US.u_usaPort)
-- Idempotente: não recria tabelas já existentes.
-- =============================================================================

SET NOCOUNT ON;
SET XACT_ABORT ON;

-- Histórico EF (para a API não tentar recriar via Migrate)
IF OBJECT_ID(N'dbo.__EFMigrationsHistory', N'U') IS NULL
BEGIN
    CREATE TABLE dbo.__EFMigrationsHistory
    (
        MigrationId    nvarchar(150) NOT NULL,
        ProductVersion nvarchar(32)  NOT NULL,
        CONSTRAINT PK___EFMigrationsHistory PRIMARY KEY (MigrationId)
    );
END;
GO

IF OBJECT_ID(N'dbo.u_HcaLogiRoles', N'U') IS NULL
BEGIN
    CREATE TABLE dbo.u_HcaLogiRoles
    (
        Id               nvarchar(450)  NOT NULL,
        Name             nvarchar(256)  NULL,
        NormalizedName   nvarchar(256)  NULL,
        ConcurrencyStamp nvarchar(max)  NULL,
        CONSTRAINT PK_u_HcaLogiRoles PRIMARY KEY (Id)
    );
END;
GO

IF OBJECT_ID(N'dbo.u_HcaLogiUsers', N'U') IS NULL
BEGIN
    CREATE TABLE dbo.u_HcaLogiUsers
    (
        Id                   nvarchar(450)     NOT NULL,
        UsStamp              nvarchar(25)      NULL,
        Usercode             nvarchar(20)      NULL,
        UserName             nvarchar(256)     NULL,
        NormalizedUserName   nvarchar(256)     NULL,
        Email                nvarchar(256)     NULL,
        NormalizedEmail      nvarchar(256)     NULL,
        EmailConfirmed       bit               NOT NULL,
        PasswordHash         nvarchar(max)     NULL,
        SecurityStamp        nvarchar(max)     NULL,
        ConcurrencyStamp     nvarchar(max)     NULL,
        PhoneNumber          nvarchar(max)     NULL,
        PhoneNumberConfirmed bit               NOT NULL,
        TwoFactorEnabled     bit               NOT NULL,
        LockoutEnd           datetimeoffset(7) NULL,
        LockoutEnabled       bit               NOT NULL,
        AccessFailedCount    int               NOT NULL,
        CONSTRAINT PK_u_HcaLogiUsers PRIMARY KEY (Id)
    );
END;
GO

IF OBJECT_ID(N'dbo.u_HcaLogiRoleClaims', N'U') IS NULL
BEGIN
    CREATE TABLE dbo.u_HcaLogiRoleClaims
    (
        Id         int            NOT NULL IDENTITY(1, 1),
        RoleId     nvarchar(450)  NOT NULL,
        ClaimType  nvarchar(max)  NULL,
        ClaimValue nvarchar(max)  NULL,
        CONSTRAINT PK_u_HcaLogiRoleClaims PRIMARY KEY (Id),
        CONSTRAINT FK_u_HcaLogiRoleClaims_u_HcaLogiRoles_RoleId
            FOREIGN KEY (RoleId) REFERENCES dbo.u_HcaLogiRoles (Id) ON DELETE CASCADE
    );
END;
GO

IF OBJECT_ID(N'dbo.u_HcaLogiUserClaims', N'U') IS NULL
BEGIN
    CREATE TABLE dbo.u_HcaLogiUserClaims
    (
        Id         int            NOT NULL IDENTITY(1, 1),
        UserId     nvarchar(450)  NOT NULL,
        ClaimType  nvarchar(max)  NULL,
        ClaimValue nvarchar(max)  NULL,
        CONSTRAINT PK_u_HcaLogiUserClaims PRIMARY KEY (Id),
        CONSTRAINT FK_u_HcaLogiUserClaims_u_HcaLogiUsers_UserId
            FOREIGN KEY (UserId) REFERENCES dbo.u_HcaLogiUsers (Id) ON DELETE CASCADE
    );
END;
GO

IF OBJECT_ID(N'dbo.u_HcaLogiUserLogins', N'U') IS NULL
BEGIN
    CREATE TABLE dbo.u_HcaLogiUserLogins
    (
        LoginProvider       nvarchar(450) NOT NULL,
        ProviderKey         nvarchar(450) NOT NULL,
        ProviderDisplayName nvarchar(max) NULL,
        UserId              nvarchar(450) NOT NULL,
        CONSTRAINT PK_u_HcaLogiUserLogins PRIMARY KEY (LoginProvider, ProviderKey),
        CONSTRAINT FK_u_HcaLogiUserLogins_u_HcaLogiUsers_UserId
            FOREIGN KEY (UserId) REFERENCES dbo.u_HcaLogiUsers (Id) ON DELETE CASCADE
    );
END;
GO

IF OBJECT_ID(N'dbo.u_HcaLogiUserRoles', N'U') IS NULL
BEGIN
    CREATE TABLE dbo.u_HcaLogiUserRoles
    (
        UserId nvarchar(450) NOT NULL,
        RoleId nvarchar(450) NOT NULL,
        CONSTRAINT PK_u_HcaLogiUserRoles PRIMARY KEY (UserId, RoleId),
        CONSTRAINT FK_u_HcaLogiUserRoles_u_HcaLogiRoles_RoleId
            FOREIGN KEY (RoleId) REFERENCES dbo.u_HcaLogiRoles (Id) ON DELETE CASCADE,
        CONSTRAINT FK_u_HcaLogiUserRoles_u_HcaLogiUsers_UserId
            FOREIGN KEY (UserId) REFERENCES dbo.u_HcaLogiUsers (Id) ON DELETE CASCADE
    );
END;
GO

IF OBJECT_ID(N'dbo.u_HcaLogiUserTokens', N'U') IS NULL
BEGIN
    CREATE TABLE dbo.u_HcaLogiUserTokens
    (
        UserId        nvarchar(450) NOT NULL,
        LoginProvider nvarchar(450) NOT NULL,
        Name          nvarchar(450) NOT NULL,
        Value         nvarchar(max) NULL,
        CONSTRAINT PK_u_HcaLogiUserTokens PRIMARY KEY (UserId, LoginProvider, Name),
        CONSTRAINT FK_u_HcaLogiUserTokens_u_HcaLogiUsers_UserId
            FOREIGN KEY (UserId) REFERENCES dbo.u_HcaLogiUsers (Id) ON DELETE CASCADE
    );
END;
GO

-- Índices (criar só se em falta)
IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE name = N'IX_u_HcaLogiRoleClaims_RoleId' AND object_id = OBJECT_ID(N'dbo.u_HcaLogiRoleClaims'))
    CREATE INDEX IX_u_HcaLogiRoleClaims_RoleId ON dbo.u_HcaLogiRoleClaims (RoleId);
GO

IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE name = N'RoleNameIndex' AND object_id = OBJECT_ID(N'dbo.u_HcaLogiRoles'))
    CREATE UNIQUE INDEX RoleNameIndex ON dbo.u_HcaLogiRoles (NormalizedName)
        WHERE [NormalizedName] IS NOT NULL;
GO

IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE name = N'IX_u_HcaLogiUserClaims_UserId' AND object_id = OBJECT_ID(N'dbo.u_HcaLogiUserClaims'))
    CREATE INDEX IX_u_HcaLogiUserClaims_UserId ON dbo.u_HcaLogiUserClaims (UserId);
GO

IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE name = N'IX_u_HcaLogiUserLogins_UserId' AND object_id = OBJECT_ID(N'dbo.u_HcaLogiUserLogins'))
    CREATE INDEX IX_u_HcaLogiUserLogins_UserId ON dbo.u_HcaLogiUserLogins (UserId);
GO

IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE name = N'IX_u_HcaLogiUserRoles_RoleId' AND object_id = OBJECT_ID(N'dbo.u_HcaLogiUserRoles'))
    CREATE INDEX IX_u_HcaLogiUserRoles_RoleId ON dbo.u_HcaLogiUserRoles (RoleId);
GO

IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE name = N'EmailIndex' AND object_id = OBJECT_ID(N'dbo.u_HcaLogiUsers'))
    CREATE INDEX EmailIndex ON dbo.u_HcaLogiUsers (NormalizedEmail);
GO

IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE name = N'UserNameIndex' AND object_id = OBJECT_ID(N'dbo.u_HcaLogiUsers'))
    CREATE UNIQUE INDEX UserNameIndex ON dbo.u_HcaLogiUsers (NormalizedUserName)
        WHERE [NormalizedUserName] IS NOT NULL;
GO

IF NOT EXISTS (
    SELECT 1 FROM dbo.__EFMigrationsHistory
    WHERE MigrationId = N'20260811092935_InitialIdentityHcaLogi'
)
BEGIN
    INSERT INTO dbo.__EFMigrationsHistory (MigrationId, ProductVersion)
    VALUES (N'20260811092935_InitialIdentityHcaLogi', N'8.0.22');
END;
GO
GO


/* ========== 12 / 030_grant_portal_app.sql ========== */
-- =============================================================================
-- Liliana & Seródio — Portal Logístico
-- Script: 030_grant_portal_app.sql
-- Ambiente: UAT primeiro; Produção só no GO formal
-- =============================================================================
-- Substituir [portal_app] pelo nome do utilizador SQL da aplicação.
-- A aplicação NÃO deve ter SELECT/UPDATE directo em BO/BI/ST/CL/US.
-- =============================================================================

-- Exemplo de criação do login/user (ajustar servidor / password):
/*
USE [master];
CREATE LOGIN [portal_app] WITH PASSWORD = N'TROCAR_PASSWORD_FORTE', CHECK_POLICY = ON;

USE [NOME_BD_PHC_UAT];  -- substituir
CREATE USER [portal_app] FOR LOGIN [portal_app];
*/

-- Vistas (leitura)
GRANT SELECT ON dbo.view_HCA_utilizadores TO [portal_app];
GRANT SELECT ON dbo.view_HCA_encomendas_abertas TO [portal_app];
GRANT SELECT ON dbo.view_HCA_encomenda_linhas TO [portal_app];
GRANT SELECT ON dbo.view_HCA_rastreio_artigos TO [portal_app];
GRANT SELECT ON dbo.view_HCA_artigo_encomendas TO [portal_app];
GRANT SELECT ON dbo.view_HCA_cortes_quantidade TO [portal_app];

-- Procedimentos (execução)
GRANT EXECUTE ON dbo.sp_HCA_validar_login TO [portal_app];
GRANT EXECUTE ON dbo.sp_HCA_atualizar_linha_qtt_preco TO [portal_app];
GRANT EXECUTE ON dbo.sp_HCA_atualizar_qtd_autorizada TO [portal_app];
GRANT EXECUTE ON dbo.sp_HCA_alocacao_proporcional TO [portal_app];
GRANT EXECUTE ON dbo.sp_HCA_marcar_pronta_picking TO [portal_app];
GRANT EXECUTE ON dbo.sp_HCA_listar_utilizadores_admin TO [portal_app];
GRANT EXECUTE ON dbo.sp_HCA_actualizar_usa_port TO [portal_app];

-- Identity (EF) — mesma BD PHC
GRANT SELECT, INSERT, UPDATE, DELETE ON dbo.u_HcaLogiUsers TO [portal_app];
GRANT SELECT, INSERT, UPDATE, DELETE ON dbo.u_HcaLogiRoles TO [portal_app];
GRANT SELECT, INSERT, UPDATE, DELETE ON dbo.u_HcaLogiUserRoles TO [portal_app];
GRANT SELECT, INSERT, UPDATE, DELETE ON dbo.u_HcaLogiUserClaims TO [portal_app];
GRANT SELECT, INSERT, UPDATE, DELETE ON dbo.u_HcaLogiUserLogins TO [portal_app];
GRANT SELECT, INSERT, UPDATE, DELETE ON dbo.u_HcaLogiUserTokens TO [portal_app];
GRANT SELECT, INSERT, UPDATE, DELETE ON dbo.u_HcaLogiRoleClaims TO [portal_app];
GO
GO


/* ========== 13 / 031_create_sp_HCA_listar_utilizadores_admin.sql ========== */
-- =============================================================================
-- Liliana & Seródio — Portal Logístico
-- Script: 031_create_sp_HCA_listar_utilizadores_admin.sql
-- =============================================================================
-- Lista utilizadores US activos (com email) para Administração do portal.
-- =============================================================================

CREATE OR ALTER PROCEDURE dbo.sp_HCA_listar_utilizadores_admin
AS
BEGIN
    SET NOCOUNT ON;

    SELECT
        us.usstamp AS userstamp,
        LTRIM(RTRIM(us.usercode)) AS login,
        LTRIM(RTRIM(us.username)) AS nome,
        LTRIM(RTRIM(us.iniciais)) AS usrinis,
        LTRIM(RTRIM(us.email)) AS email,
        CAST(ISNULL(us.u_usaPort, 0) AS bit) AS usa_port
    FROM dbo.us us WITH (NOLOCK)
    WHERE ISNULL(us.inactivo, 0) = 0
      AND LTRIM(RTRIM(ISNULL(us.email, ''))) <> ''
    ORDER BY LTRIM(RTRIM(us.usercode));
END;
GO
GO


/* ========== 14 / 032_create_sp_HCA_actualizar_usa_port.sql ========== */
-- =============================================================================
-- Liliana & Seródio — Portal Logístico
-- Script: 032_create_sp_HCA_actualizar_usa_port.sql
-- =============================================================================
-- Actualiza US.u_usaPort por email (utilizador activo).
-- =============================================================================

CREATE OR ALTER PROCEDURE dbo.sp_HCA_actualizar_usa_port
    @email varchar(100),
    @usaPort bit
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    IF @email IS NULL OR LTRIM(RTRIM(@email)) = ''
    BEGIN
        RAISERROR(N'Email obrigatório.', 16, 1);
        RETURN;
    END;

    UPDATE dbo.us
    SET u_usaPort = @usaPort
    WHERE LOWER(LTRIM(RTRIM(email))) = LOWER(LTRIM(RTRIM(@email)))
      AND ISNULL(inactivo, 0) = 0;

    IF @@ROWCOUNT = 0
    BEGIN
        RAISERROR(N'Utilizador US activo com esse email não encontrado.', 16, 1);
        RETURN;
    END;

    SELECT
        us.usstamp AS userstamp,
        LTRIM(RTRIM(us.usercode)) AS login,
        LTRIM(RTRIM(us.username)) AS nome,
        LTRIM(RTRIM(us.iniciais)) AS usrinis,
        LTRIM(RTRIM(us.email)) AS email,
        CAST(ISNULL(us.u_usaPort, 0) AS bit) AS usa_port
    FROM dbo.us us WITH (NOLOCK)
    WHERE LOWER(LTRIM(RTRIM(us.email))) = LOWER(LTRIM(RTRIM(@email)));
END;
GO
GO


/* ========== 15 / 033_seed_role_Admin.sql ========== */
-- =============================================================================
-- Liliana & Seródio — Portal Logístico
-- Script: 033_seed_role_Admin.sql
-- Pré-requisitos: 029 (tabelas u_HcaLogi*), utilizador Identity do piloto `sa`
-- =============================================================================
-- Garante a role Identity `Admin` e atribui-a ao utilizador PHC usercode = sa
-- (conta em u_HcaLogiUsers com o mesmo email / Usercode), se existir.
-- Idempotente. Equivalente ao seed da API (PortalIdentitySeed).
-- =============================================================================

SET NOCOUNT ON;
SET XACT_ABORT ON;

IF OBJECT_ID(N'dbo.u_HcaLogiRoles', N'U') IS NULL
   OR OBJECT_ID(N'dbo.u_HcaLogiUsers', N'U') IS NULL
   OR OBJECT_ID(N'dbo.u_HcaLogiUserRoles', N'U') IS NULL
BEGIN
    RAISERROR(N'Pré-requisito em falta: executar sql/029_create_u_HcaLogi_identity_tables.sql', 16, 1);
    RETURN;
END;

IF NOT EXISTS (
    SELECT 1
    FROM dbo.u_HcaLogiRoles
    WHERE NormalizedName = N'ADMIN'
)
BEGIN
    INSERT INTO dbo.u_HcaLogiRoles (Id, Name, NormalizedName, ConcurrencyStamp)
    VALUES (
        CONVERT(nvarchar(450), LOWER(CONVERT(nvarchar(36), NEWID()))),
        N'Admin',
        N'ADMIN',
        CONVERT(nvarchar(max), LOWER(CONVERT(nvarchar(36), NEWID())))
    );
END;

DECLARE @roleId nvarchar(450) =
(
    SELECT TOP (1) Id
    FROM dbo.u_HcaLogiRoles
    WHERE NormalizedName = N'ADMIN'
);

DECLARE @userId nvarchar(450) =
(
    SELECT TOP (1) u.Id
    FROM dbo.u_HcaLogiUsers u
    WHERE LTRIM(RTRIM(ISNULL(u.Usercode, N''))) = N'sa'
       OR EXISTS (
            SELECT 1
            FROM dbo.us us WITH (NOLOCK)
            WHERE ISNULL(us.inactivo, 0) = 0
              AND LTRIM(RTRIM(us.usercode)) = N'sa'
              AND LOWER(LTRIM(RTRIM(us.email))) = LOWER(LTRIM(RTRIM(u.Email)))
        )
    ORDER BY CASE WHEN LTRIM(RTRIM(ISNULL(u.Usercode, N''))) = N'sa' THEN 0 ELSE 1 END
);

IF @roleId IS NULL
BEGIN
    RAISERROR(N'Role Admin não encontrada após insert.', 16, 1);
    RETURN;
END;

IF @userId IS NULL
BEGIN
    PRINT N'AVISO: Identity do usercode sa ainda não existe — role Admin criada; atribuir depois (API seed ou reexecutar este script).';
    RETURN;
END;

IF NOT EXISTS (
    SELECT 1
    FROM dbo.u_HcaLogiUserRoles
    WHERE UserId = @userId
      AND RoleId = @roleId
)
BEGIN
    INSERT INTO dbo.u_HcaLogiUserRoles (UserId, RoleId)
    VALUES (@userId, @roleId);
    PRINT N'Role Admin atribuída ao Identity do usercode sa.';
END
ELSE
    PRINT N'Role Admin já estava atribuída ao Identity do usercode sa.';
GO
GO


/* ========== 16 / 034_alter_view_HCA_encomenda_linhas_unidade.sql ========== */
-- =============================================================================
-- Liliana & Seródio — Portal Logístico
-- Script: 034_alter_view_HCA_encomenda_linhas_unidade.sql
-- Object-aplica 014 com coluna unidade (BI.unidade) — executar em UAT/Prod
-- =============================================================================

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
    bo.no AS cliente_no,
    bo.estab AS cliente_estab,
    LTRIM(RTRIM(bo.nome)) AS cliente_nome,

    LTRIM(RTRIM(bi.ref)) AS ref,
    LTRIM(RTRIM(bi.design)) AS design,
    LTRIM(RTRIM(bi.cor)) AS cor,
    LTRIM(RTRIM(ISNULL(bi.unidade, ''))) AS unidade,

    bi.qtt AS quantidade_atual,
    bi.qtt2 AS quantidade_fornecida,
    bi.u_qttorig AS quantidade_original_campo,
    ISNULL(NULLIF(bi.u_qttorig, 0), bi.qtt) AS quantidade_original_considerada,
    (ISNULL(NULLIF(bi.u_qttorig, 0), bi.qtt) - bi.qtt2) AS quantidade_por_satisfazer,

    bi.edebito AS preco_unitario,
    bi.u_prcorig AS preco_original_campo,

    bi.u_qtdaut AS quantidade_autorizada,
    LTRIM(RTRIM(bi.u_qtdautur)) AS quantidade_autorizada_por,
    bi.u_qtdautdt AS quantidade_autorizada_em,

    ISNULL(st.stock, 0) AS stock_disponivel,

    LTRIM(RTRIM(bi.usrinis)) AS usrinis,
    bi.usrdata,
    bi.usrhora
FROM dbo.bi bi WITH (NOLOCK)
INNER JOIN dbo.bo bo WITH (NOLOCK)
    ON bo.bostamp = bi.bostamp
LEFT JOIN dbo.st st WITH (NOLOCK)
    ON LTRIM(RTRIM(st.ref)) = LTRIM(RTRIM(bi.ref))
WHERE bo.ndos = 1;
GO
GO


/* ========== 17 / 035_alter_sp_HCA_alocacao_proporcional_disponivel_cor.sql ========== */
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
        -- Gravar qtt/orig primeiro; u_qtdaut* no fim (após qualquer trigger em qtt).
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
            ON l.bistamp COLLATE DATABASE_DEFAULT = bi.bistamp COLLATE DATABASE_DEFAULT
        WHERE LTRIM(RTRIM(ISNULL(bi.u_qtdautur, ''))) = '';

        UPDATE bi
        SET
            u_qtdaut = l.auth_final,
            u_qtdautur = LEFT(LTRIM(RTRIM(@usrlogin)), 100),
            u_qtdautdt = @agora
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
GO


/* ========== 18 / 036_alter_sp_HCA_atualizar_qtd_autorizada_permitir_stock.sql ========== */
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
GO


/* ========== 19 / 037_alter_view_HCA_encomendas_abertas_picking.sql ========== */
-- =============================================================================
-- Liliana & Seródio — Portal Logístico
-- Script: 037_alter_view_HCA_encomendas_abertas_picking.sql
-- Ambiente: UAT / teste; Produção só no GO formal
-- Pré-requisitos: BO.u_pickrdy, BO.u_upickrdr, BO.u_upickrdt
-- =============================================================================

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

    SUM(ISNULL(NULLIF(bi.u_qttorig, 0), bi.qtt)) AS quantidade_original_total,

    SUM(bi.qtt) AS quantidade_atual_total,

    SUM(bi.qtt2) AS quantidade_fornecida_total,

    SUM(ISNULL(NULLIF(bi.u_qttorig, 0), bi.qtt) - bi.qtt2) AS quantidade_restante_total,

    SUM(bi.u_qtdaut) AS quantidade_autorizada_total,

    CAST(ISNULL(bo.u_pickrdy, 0) AS bit) AS pronta_picking,
    LTRIM(RTRIM(bo.u_upickrdr)) AS pronta_picking_por,
    CASE
        WHEN bo.u_upickrdt IS NULL OR YEAR(bo.u_upickrdt) < 1950 THEN CAST(NULL AS datetime)
        ELSE bo.u_upickrdt
    END AS pronta_picking_em

FROM dbo.bo bo WITH (NOLOCK)
INNER JOIN dbo.bi bi WITH (NOLOCK)
    ON bi.bostamp = bo.bostamp
WHERE bo.ndos = 1
  AND ISNULL(bo.fechada, 0) = 0
  AND (ISNULL(NULLIF(bi.u_qttorig, 0), bi.qtt) - bi.qtt2) > 0
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
    bo.u_pickrdy,
    bo.u_upickrdr,
    bo.u_upickrdt;
GO
GO


/* ========== 20 / 037b_add_bo_u_upickrdt_if_missing.sql ========== */
-- =============================================================================
-- Liliana & Seródio — Portal Logístico
-- Script: 037b_add_bo_u_upickrdt_if_missing.sql
-- Fallback se o Framework não tiver criado u_upickrdt (nomes físicos oficiais).
-- Preferir criar via Supervisor → Framework PHC + Atualizar a Tabela.
-- =============================================================================

IF COL_LENGTH('dbo.bo', 'u_upickrdt') IS NULL
BEGIN
    ALTER TABLE dbo.bo ADD u_upickrdt datetime NOT NULL
        CONSTRAINT DF_bo_u_upickrdt DEFAULT ('19000101');
END
GO
GO


/* ========== 21 / 038_create_sp_HCA_marcar_pronta_picking.sql ========== */
-- =============================================================================
-- Liliana & Seródio — Portal Logístico
-- Script: 038_create_sp_HCA_marcar_pronta_picking.sql
-- Ambiente: UAT / teste; Produção só no GO formal
-- =============================================================================
-- Marca / desmarca encomenda como pronta para picking (BO.u_pickrdy*).
-- Ao marcar: linhas abertas com u_qtdaut = 0 exigem @confirmar_linhas_zero = 1
-- e aplicam u_qttorig←qtt (se orig=0) e qtt←u_qtdaut.
-- Alter posterior: 040_alter_sp_HCA_marcar_pronta_picking_linhas_zero.sql
-- =============================================================================

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

    IF ISNULL(@pronta, 0) = 1
    BEGIN
        SELECT @linhas_zero = COUNT(1)
        FROM dbo.bi bi WITH (UPDLOCK, ROWLOCK)
        WHERE bi.bostamp COLLATE DATABASE_DEFAULT = @bostamp COLLATE DATABASE_DEFAULT
          AND ISNULL(bi.u_qtdaut, 0) = 0
          AND (ISNULL(NULLIF(bi.u_qttorig, 0), bi.qtt) - bi.qtt2) > 0;

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
            UPDATE bi
            SET
                u_qttorig = CASE
                    WHEN ISNULL(bi.u_qttorig, 0) = 0 THEN bi.qtt
                    ELSE bi.u_qttorig
                END,
                qtt = bi.u_qtdaut,
                ettdeb = ROUND(bi.u_qtdaut * bi.edebito, 2),
                usrinis = @usrinis_n,
                usrdata = @usrdata,
                usrhora = @usrhora
            FROM dbo.bi bi
            WHERE bi.bostamp COLLATE DATABASE_DEFAULT = @bostamp COLLATE DATABASE_DEFAULT
              AND ISNULL(bi.u_qtdaut, 0) = 0
              AND (ISNULL(NULLIF(bi.u_qttorig, 0), bi.qtt) - bi.qtt2) > 0;
        END;
    END;

    UPDATE dbo.bo
    SET
        u_pickrdy = ISNULL(@pronta, 0),
        u_upickrdr = LEFT(LTRIM(RTRIM(@usrlogin)), 100),
        u_upickrdt = @agora,
        usrinis = @usrinis_n,
        usrdata = @usrdata,
        usrhora = @usrhora
    WHERE bostamp COLLATE DATABASE_DEFAULT = @bostamp COLLATE DATABASE_DEFAULT;

    COMMIT;

    SELECT
        bo.bostamp,
        CAST(ISNULL(bo.u_pickrdy, 0) AS bit) AS pronta_picking,
        LTRIM(RTRIM(bo.u_upickrdr)) AS pronta_picking_por,
        CASE
            WHEN YEAR(bo.u_upickrdt) < 1950 THEN CAST(NULL AS datetime)
            ELSE bo.u_upickrdt
        END AS pronta_picking_em
    FROM dbo.bo bo WITH (NOLOCK)
    WHERE bo.bostamp COLLATE DATABASE_DEFAULT = @bostamp COLLATE DATABASE_DEFAULT;
END;
GO
GO


/* ========== 22 / 039_alter_views_excluir_pronta_picking.sql ========== */
-- =============================================================================
-- Liliana & Seródio — Portal Logístico
-- Script: 039_alter_views_excluir_pronta_picking.sql
-- Ambiente: UAT / teste; Produção só no GO formal
-- Exclui BO.u_pickrdy = 1 da procura aberta / rastreio / linhas de trabalho.
-- (A lista de picking lê view_HCA_encomendas_abertas com filtro pronta_picking = 1.)
-- =============================================================================

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
    CAST(ISNULL(bo.u_pickrdy, 0) AS bit) AS pronta_picking,
    bo.no AS cliente_no,
    bo.estab AS cliente_estab,
    LTRIM(RTRIM(bo.nome)) AS cliente_nome,

    LTRIM(RTRIM(bi.ref)) AS ref,
    LTRIM(RTRIM(bi.design)) AS design,
    LTRIM(RTRIM(bi.cor)) AS cor,
    LTRIM(RTRIM(ISNULL(bi.unidade, ''))) AS unidade,

    bi.qtt AS quantidade_atual,
    bi.qtt2 AS quantidade_fornecida,
    bi.u_qttorig AS quantidade_original_campo,
    ISNULL(NULLIF(bi.u_qttorig, 0), bi.qtt) AS quantidade_original_considerada,
    (ISNULL(NULLIF(bi.u_qttorig, 0), bi.qtt) - bi.qtt2) AS quantidade_por_satisfazer,

    bi.edebito AS preco_unitario,
    bi.u_prcorig AS preco_original_campo,

    bi.u_qtdaut AS quantidade_autorizada,
    LTRIM(RTRIM(bi.u_qtdautur)) AS quantidade_autorizada_por,
    bi.u_qtdautdt AS quantidade_autorizada_em,

    ISNULL(st.stock, 0) AS stock_disponivel,

    bi.usrinis,
    bi.usrdata,
    bi.usrhora
FROM dbo.bi bi WITH (NOLOCK)
INNER JOIN dbo.bo bo WITH (NOLOCK)
    ON bo.bostamp = bi.bostamp
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
        SUM(ISNULL(NULLIF(bi.u_qttorig, 0), bi.qtt)) AS quantidade_encomendada_total,
        SUM(bi.qtt2) AS quantidade_fornecida_total,
        SUM(ISNULL(NULLIF(bi.u_qttorig, 0), bi.qtt) - bi.qtt2) AS quantidade_por_satisfazer_total,
        SUM(bi.u_qtdaut) AS quantidade_autorizada_total
    FROM dbo.bi bi WITH (NOLOCK)
    INNER JOIN dbo.bo bo WITH (NOLOCK)
        ON bo.bostamp = bi.bostamp
    WHERE bo.ndos = 1
      AND ISNULL(bo.fechada, 0) = 0
      AND ISNULL(bo.u_pickrdy, 0) = 0
      AND (ISNULL(NULLIF(bi.u_qttorig, 0), bi.qtt) - bi.qtt2) > 0
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
    bi.u_qttorig AS quantidade_original_campo,
    ISNULL(NULLIF(bi.u_qttorig, 0), bi.qtt) AS quantidade_pedida,
    (ISNULL(NULLIF(bi.u_qttorig, 0), bi.qtt) - bi.qtt2) AS quantidade_por_satisfazer,

    bi.u_qtdaut AS quantidade_autorizada,
    LTRIM(RTRIM(bi.u_qtdautur)) AS quantidade_autorizada_por,
    bi.u_qtdautdt AS quantidade_autorizada_em,

    ISNULL(st.stock, 0) AS stock_disponivel
FROM dbo.bi bi WITH (NOLOCK)
INNER JOIN dbo.bo bo WITH (NOLOCK)
    ON bo.bostamp = bi.bostamp
LEFT JOIN dbo.st st WITH (NOLOCK)
    ON LTRIM(RTRIM(st.ref)) = LTRIM(RTRIM(bi.ref))
WHERE bo.ndos = 1
  AND ISNULL(bo.fechada, 0) = 0
  AND ISNULL(bo.u_pickrdy, 0) = 0
  AND (ISNULL(NULLIF(bi.u_qttorig, 0), bi.qtt) - bi.qtt2) > 0;
GO
GO


/* ========== 23 / 040_alter_sp_HCA_marcar_pronta_picking_linhas_zero.sql ========== */
-- =============================================================================
-- Liliana & Seródio — Portal Logístico
-- Script: 040_alter_sp_HCA_marcar_pronta_picking_linhas_zero.sql
-- Ambiente: UAT / teste; Produção só no GO formal
-- =============================================================================
-- Ao marcar pronta (@pronta = 1):
--   - Se existirem linhas abertas com u_qtdaut = 0 e @confirmar_linhas_zero = 0
--     → erro LINHAS_SEM_AUTORIZACAO (UI pede confirmação).
--   - Se confirmado: nas linhas com u_qtdaut = 0,
--       u_qttorig ← qtt (só se u_qttorig ainda = 0, RN-020),
--       qtt ← u_qtdaut, ettdeb recalculado.
-- Depois marca BO.u_pickrdy*.
-- =============================================================================

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

    -- Só ao marcar como pronta: validar / aplicar linhas com autorizada = 0
    IF ISNULL(@pronta, 0) = 1
    BEGIN
        SELECT @linhas_zero = COUNT(1)
        FROM dbo.bi bi WITH (UPDLOCK, ROWLOCK)
        WHERE bi.bostamp COLLATE DATABASE_DEFAULT = @bostamp COLLATE DATABASE_DEFAULT
          AND ISNULL(bi.u_qtdaut, 0) = 0
          AND (ISNULL(NULLIF(bi.u_qttorig, 0), bi.qtt) - bi.qtt2) > 0;

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
            -- Mesma regra da 1.ª autorização: preservar qtt em u_qttorig (se ainda 0), depois qtt ← u_qtdaut
            UPDATE bi
            SET
                u_qttorig = CASE
                    WHEN ISNULL(bi.u_qttorig, 0) = 0 THEN bi.qtt
                    ELSE bi.u_qttorig
                END,
                qtt = bi.u_qtdaut,
                ettdeb = ROUND(bi.u_qtdaut * bi.edebito, 2),
                usrinis = @usrinis_n,
                usrdata = @usrdata,
                usrhora = @usrhora
            FROM dbo.bi bi
            WHERE bi.bostamp COLLATE DATABASE_DEFAULT = @bostamp COLLATE DATABASE_DEFAULT
              AND ISNULL(bi.u_qtdaut, 0) = 0
              AND (ISNULL(NULLIF(bi.u_qttorig, 0), bi.qtt) - bi.qtt2) > 0;
        END;
    END;

    UPDATE dbo.bo
    SET
        u_pickrdy = ISNULL(@pronta, 0),
        u_upickrdr = LEFT(LTRIM(RTRIM(@usrlogin)), 100),
        u_upickrdt = @agora,
        usrinis = @usrinis_n,
        usrdata = @usrdata,
        usrhora = @usrhora
    WHERE bostamp COLLATE DATABASE_DEFAULT = @bostamp COLLATE DATABASE_DEFAULT;

    COMMIT;

    SELECT
        bo.bostamp,
        CAST(ISNULL(bo.u_pickrdy, 0) AS bit) AS pronta_picking,
        LTRIM(RTRIM(bo.u_upickrdr)) AS pronta_picking_por,
        CASE
            WHEN YEAR(bo.u_upickrdt) < 1950 THEN CAST(NULL AS datetime)
            ELSE bo.u_upickrdt
        END AS pronta_picking_em
    FROM dbo.bo bo WITH (NOLOCK)
    WHERE bo.bostamp COLLATE DATABASE_DEFAULT = @bostamp COLLATE DATABASE_DEFAULT;
END;
GO
GO


/* ========== 24 / 041_migrate_user_fields_bi2_bo3.sql ========== */
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
GO


/* ========== 25 / 042_cor_efectiva_bi_u_cor.sql ========== */
-- =============================================================================
-- Liliana & Seródio — Portal Logístico
-- Script: 042_cor_efectiva_bi_u_cor.sql
-- Ambiente: UAT primeiro; Produção só no GO formal
-- =============================================================================
-- Nesta BD a cor das linhas está em BI.u_cor; BI.cor (nativo) vem vazio.
-- A vista e a SP passam a expor/filtrar a cor efectiva:
--   COALESCE(NULLIF(bi.cor,''), NULLIF(bi.u_cor,''), '')
-- =============================================================================

CREATE OR ALTER VIEW dbo.view_HCA_encomenda_linhas
AS
SELECT
    bi.bistamp,
    bi.bostamp,
    bo.obrano,
    bo.ndos,
    bo.nmdos,
    bo.dataobra,
    bo.ousrhora,
    ISNULL(bo.fechada, 0) AS fecho,
    CAST(ISNULL(bo3.u_pickrdy, 0) AS bit) AS pronta_picking,
    bo.no AS cliente_no,
    bo.estab AS cliente_estab,
    LTRIM(RTRIM(bo.nome)) AS cliente_nome,

    LTRIM(RTRIM(bi.ref)) AS ref,
    LTRIM(RTRIM(bi.design)) AS design,
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
GO


/* ========== 26 / 043_create_view_HCA_cortes_quantidade.sql ========== */
-- =============================================================================
-- Liliana & Seródio — Portal Logístico
-- Script: 043_create_view_HCA_cortes_quantidade.sql
-- Ambiente: UAT primeiro; Produção só no GO formal
-- =============================================================================
-- Linhas em que, após pronta para picking OU documento fechado, a quantidade
-- original encomendada ficou acima da autorizada (corte = u_qttorig − u_qtdaut).
-- Cor efectiva: COALESCE(BI.cor, BI.u_cor) — ver 042.
-- =============================================================================

CREATE OR ALTER VIEW dbo.view_HCA_cortes_quantidade
AS
SELECT
    bi.bistamp,
    bi.bostamp,
    bo.obrano,
    bo.ndos,
    bo.dataobra,
    bo.ousrhora,
    ISNULL(bo.fechada, 0) AS fecho,
    CAST(ISNULL(bo3.u_pickrdy, 0) AS bit) AS pronta_picking,
    bo.no AS cliente_no,
    bo.estab AS cliente_estab,
    LTRIM(RTRIM(bo.nome)) AS cliente_nome,

    LTRIM(RTRIM(bi.ref)) AS ref,
    LTRIM(RTRIM(bi.design)) AS design,
    LTRIM(RTRIM(COALESCE(
        NULLIF(LTRIM(RTRIM(ISNULL(bi.cor, ''))), ''),
        NULLIF(LTRIM(RTRIM(ISNULL(bi.u_cor, ''))), ''),
        ''
    ))) AS cor,
    LTRIM(RTRIM(ISNULL(bi.unidade, ''))) AS unidade,

    bi2.u_qttorig AS quantidade_original,
    bi2.u_qtdaut AS quantidade_autorizada,
    (bi2.u_qttorig - bi2.u_qtdaut) AS quantidade_nao_autorizada,
    bi.qtt2 AS quantidade_fornecida
FROM dbo.bi bi WITH (NOLOCK)
INNER JOIN dbo.bo bo WITH (NOLOCK)
    ON bo.bostamp = bi.bostamp
INNER JOIN dbo.bi2 bi2 WITH (NOLOCK)
    ON bi2.bi2stamp COLLATE DATABASE_DEFAULT = bi.bistamp COLLATE DATABASE_DEFAULT
LEFT JOIN dbo.bo3 bo3 WITH (NOLOCK)
    ON bo3.bo3stamp COLLATE DATABASE_DEFAULT = bo.bostamp COLLATE DATABASE_DEFAULT
WHERE bo.ndos = 1
  AND (
        ISNULL(bo3.u_pickrdy, 0) = 1
     OR ISNULL(bo.fechada, 0) = 1
      )
  AND bi2.u_qttorig > 0
  AND bi2.u_qtdaut >= 0
  AND bi2.u_qttorig > bi2.u_qtdaut;
GO
GO


/* ========== 27 / 044_add_bo3_u_urgente_views.sql ========== */
-- =============================================================================
-- Liliana & Seródio — Portal Logístico
-- Script: 044_add_bo3_u_urgente_views.sql
-- Ambiente: UAT primeiro; Produção só no GO formal
-- =============================================================================
-- Pré-requisito: BO3.u_urgente (Lógico) criado no Framework + Atualizar a Tabela.
-- =============================================================================

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
    bi.bistamp,
    bi.bostamp,
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

CREATE OR ALTER VIEW dbo.view_HCA_cortes_quantidade
AS
SELECT
    bi.bistamp,
    bi.bostamp,
    bo.obrano,
    bo.ndos,
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
    LTRIM(RTRIM(COALESCE(
        NULLIF(LTRIM(RTRIM(ISNULL(bi.cor, ''))), ''),
        NULLIF(LTRIM(RTRIM(ISNULL(bi.u_cor, ''))), ''),
        ''
    ))) AS cor,
    LTRIM(RTRIM(ISNULL(bi.unidade, ''))) AS unidade,

    bi2.u_qttorig AS quantidade_original,
    bi2.u_qtdaut AS quantidade_autorizada,
    (bi2.u_qttorig - bi2.u_qtdaut) AS quantidade_nao_autorizada,
    bi.qtt2 AS quantidade_fornecida
FROM dbo.bi bi WITH (NOLOCK)
INNER JOIN dbo.bo bo WITH (NOLOCK)
    ON bo.bostamp = bi.bostamp
INNER JOIN dbo.bi2 bi2 WITH (NOLOCK)
    ON bi2.bi2stamp COLLATE DATABASE_DEFAULT = bi.bistamp COLLATE DATABASE_DEFAULT
LEFT JOIN dbo.bo3 bo3 WITH (NOLOCK)
    ON bo3.bo3stamp COLLATE DATABASE_DEFAULT = bo.bostamp COLLATE DATABASE_DEFAULT
WHERE bo.ndos = 1
  AND (
        ISNULL(bo3.u_pickrdy, 0) = 1
     OR ISNULL(bo.fechada, 0) = 1
      )
  AND bi2.u_qttorig > 0
  AND bi2.u_qtdaut >= 0
  AND bi2.u_qttorig > bi2.u_qtdaut;
GO
GO


/* ========== 28 / 046_u_qttorig_original_inicial.sql ========== */
-- =============================================================================
-- Liliana & Seródio — Portal Logístico
-- Script: 046_u_qttorig_original_inicial.sql
-- Ambiente: UAT / teste; Produção só no GO formal
-- =============================================================================
-- 1) SP: na 1.ª autorização grava BI2.u_qttorig = qtt actual (só se ainda 0).
-- 2) Backfill: linhas abertas ainda sem autorização → u_qttorig = BI.qtt.
-- =============================================================================

/* ---------- Backfill seguro (só nunca autorizadas) ---------- */

UPDATE bi2
SET u_qttorig = bi.qtt
FROM dbo.bi2 bi2
INNER JOIN dbo.bi bi
    ON bi.bistamp COLLATE DATABASE_DEFAULT = bi2.bi2stamp COLLATE DATABASE_DEFAULT
INNER JOIN dbo.bo bo
    ON bo.bostamp COLLATE DATABASE_DEFAULT = bi.bostamp COLLATE DATABASE_DEFAULT
WHERE bo.ndos = 1
  AND ISNULL(bo.fechada, 0) = 0
  AND ISNULL(bi2.u_qttorig, 0) = 0
  AND LTRIM(RTRIM(ISNULL(bi2.u_qtdautur, ''))) = '';
GO

/* ---------- SP quantidade autorizada (extracto alinhado a 041) ---------- */

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

    IF ISNULL(@permitir_acima_stock, 0) = 0
       AND (@soma_outras + @quantidade_autorizada) > @stock
    BEGIN
        ROLLBACK;
        RAISERROR(N'Stock insuficiente: quantidades autorizadas excede o stock existente.', 16, 1);
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
GO


/* ========== 29 / 047_alter_sp_HCA_marcar_pronta_picking_reverter_quantidades.sql ========== */
﻿-- =============================================================================
-- Liliana & Serodio - Portal Logistico
-- Script: 047_alter_sp_HCA_marcar_pronta_picking_reverter_quantidades.sql
-- Ambiente: UAT / teste; Producao so no GO formal
-- =============================================================================
-- Ao cancelar picking (@pronta = 0):
--   BI.qtt <- BI2.u_qttorig (se > 0), ettdeb recalculado
--   BI2.u_qtdaut* limpos (autorizacao a 0 / utilizador vazio)
-- =============================================================================
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
GO


/* ========== 30 / 048_create_sp_HCA_marcar_fecho_picking_dossier.sql ========== */
-- =============================================================================
-- Liliana & Seródio — Portal Logístico
-- Script: 048_create_sp_HCA_marcar_fecho_picking_dossier.sql
-- Ambiente: UAT / teste; Produção só no GO formal
-- =============================================================================
-- Fecha / reabre dossier de picking (ndos = @serie_picking): só actualiza BO.fechada.
-- =============================================================================

CREATE OR ALTER PROCEDURE dbo.sp_HCA_marcar_fecho_picking_dossier
    @bostamp         varchar(25),
    @fechada         bit,
    @serie_picking   int = 66,
    @usrlogin        varchar(100) = NULL
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    IF @bostamp IS NULL OR LTRIM(RTRIM(@bostamp)) = ''
    BEGIN
        RAISERROR(N'bostamp obrigatório.', 16, 1);
        RETURN;
    END;

    IF @serie_picking IS NULL OR @serie_picking <= 0
    BEGIN
        RAISERROR(N'serie_picking inválida.', 16, 1);
        RETURN;
    END;

    BEGIN TRAN;

    IF NOT EXISTS (
        SELECT 1
        FROM dbo.bo bo WITH (UPDLOCK, ROWLOCK)
        WHERE bo.bostamp COLLATE DATABASE_DEFAULT = @bostamp COLLATE DATABASE_DEFAULT
          AND bo.ndos = @serie_picking
    )
    BEGIN
        ROLLBACK;
        RAISERROR(N'Dossier de picking não encontrado ou série inválida.', 16, 1);
        RETURN;
    END;

    UPDATE dbo.bo
    SET
        fechada = ISNULL(@fechada, 0),
        usrinis = LEFT(LTRIM(RTRIM(ISNULL(NULLIF(@usrlogin, ''), usrinis))), 3),
        usrdata = CAST(GETDATE() AS date),
        usrhora = CONVERT(varchar(8), GETDATE(), 108)
    WHERE bostamp COLLATE DATABASE_DEFAULT = @bostamp COLLATE DATABASE_DEFAULT
      AND ndos = @serie_picking;

    COMMIT;

    SELECT
        bo.bostamp,
        CAST(ISNULL(bo.fechada, 0) AS bit) AS fechada,
        bo.obrano,
        bo.ndos
    FROM dbo.bo bo WITH (NOLOCK)
    WHERE bo.bostamp COLLATE DATABASE_DEFAULT = @bostamp COLLATE DATABASE_DEFAULT;
END;
GO
GO


/* ========== 31 / 049_alter_views_bo3_u_pickstat.sql ========== */
-- =============================================================================
-- Liliana & Seródio — Portal Logístico
-- Script: 049_alter_views_bo3_u_pickstat.sql
-- Ambiente: UAT / teste; Produção só no GO formal
-- Pré-requisito: BO3.u_pickstat (numérico) criado no Framework + Atualizar a Tabela.
-- =============================================================================
-- 0 = Em Aberto | 1 = Preparado | 2 = Em Curso | 3 = Concluído
-- Não altera filtros de ndos=66 / Expedição / Concluídas.
-- =============================================================================

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
    CAST(ISNULL(bo3.u_pickstat, 0) AS int) AS pick_status,
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
    bo3.u_pickstat,
    bo3.u_urgente;
GO

CREATE OR ALTER VIEW dbo.view_HCA_encomenda_linhas
AS
SELECT
    bi.bistamp,
    bi.bostamp,
    bo.obrano,
    bo.ndos,
    bo.nmdos,
    bo.dataobra,
    bo.ousrhora,
    ISNULL(bo.fechada, 0) AS fecho,
    CAST(ISNULL(bo3.u_pickrdy, 0) AS bit) AS pronta_picking,
    CAST(ISNULL(bo3.u_pickstat, 0) AS int) AS pick_status,
    CAST(ISNULL(bo3.u_urgente, 0) AS bit) AS urgente,
    bo.no AS cliente_no,
    bo.estab AS cliente_estab,
    LTRIM(RTRIM(bo.nome)) AS cliente_nome,

    LTRIM(RTRIM(bi.ref)) AS ref,
    LTRIM(RTRIM(bi.design)) AS design,
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
GO


/* ========== 32 / 050_alter_sp_HCA_marcar_pronta_picking_u_pickstat.sql ========== */
-- =============================================================================
-- Liliana & Seródio — Portal Logístico
-- Script: 050_alter_sp_HCA_marcar_pronta_picking_u_pickstat.sql
-- Ambiente: UAT / teste; Produção só no GO formal
-- =============================================================================
-- Mantém u_pickrdy e passa a sincronizar u_pickstat:
--   @pronta = 1 → u_pickstat = 1 (Preparado)
--   @pronta = 0 → u_pickstat = 0 (Em Aberto) + reverte quantidades (como 047)
-- =============================================================================

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
        @linhas_zero int = 0,
        @stat_atual int;

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
            u_qtdautdt = CAST('19000101' AS datetime)
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
        END AS pronta_picking_em,
        CAST(ISNULL(bo3.u_pickstat, 0) AS int) AS pick_status
    FROM dbo.bo bo WITH (NOLOCK)
    LEFT JOIN dbo.bo3 bo3 WITH (NOLOCK)
        ON bo3.bo3stamp COLLATE DATABASE_DEFAULT = bo.bostamp COLLATE DATABASE_DEFAULT
    WHERE bo.bostamp COLLATE DATABASE_DEFAULT = @bostamp COLLATE DATABASE_DEFAULT;
END;
GO
GO


/* ========== 33 / 051_create_sp_HCA_picking_workflow.sql ========== */
-- =============================================================================
-- Liliana & Seródio — Portal Logístico
-- Script: 051_create_sp_HCA_picking_workflow.sql
-- Ambiente: UAT / teste; Produção só no GO formal
-- =============================================================================
-- Workflow picking (ndos=1):
--   start:           1 → 2
--   complete:        2 → 3
--   cancel:          1 → 0 (+ reverte qtt/autorizações; u_pickrdy=0)
--   back_to_ready:   2 → 1
--   reopen:          3 → 2
-- =============================================================================

CREATE OR ALTER PROCEDURE dbo.sp_HCA_picking_start
    @bostamp  varchar(25),
    @usrlogin varchar(100),
    @usrinis  varchar(3) = NULL
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    IF @bostamp IS NULL OR LTRIM(RTRIM(@bostamp)) = ''
    BEGIN RAISERROR(N'bostamp obrigatório.', 16, 1); RETURN; END;
    IF @usrlogin IS NULL OR LTRIM(RTRIM(@usrlogin)) = ''
    BEGIN RAISERROR(N'usrlogin obrigatório.', 16, 1); RETURN; END;

    DECLARE @agora datetime = GETDATE(), @stat int, @usrinis_n varchar(3);
    SET @usrinis_n = LEFT(LTRIM(RTRIM(ISNULL(NULLIF(@usrinis, ''), @usrlogin))), 3);

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
    BEGIN ROLLBACK; RAISERROR(N'Transição inválida: Iniciar Picking só a partir de Preparado (u_pickstat=1).', 16, 1); RETURN; END;

    UPDATE dbo.bo3
    SET u_pickrdy = 1, u_pickstat = 2,
        u_pickrdr = LEFT(LTRIM(RTRIM(@usrlogin)), 100), u_pickrdt = @agora
    WHERE bo3stamp COLLATE DATABASE_DEFAULT = @bostamp COLLATE DATABASE_DEFAULT;

    UPDATE dbo.bo SET usrinis = @usrinis_n, usrdata = CAST(@agora AS date),
                      usrhora = CONVERT(varchar(8), @agora, 108)
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

CREATE OR ALTER PROCEDURE dbo.sp_HCA_picking_complete
    @bostamp  varchar(25),
    @usrlogin varchar(100),
    @usrinis  varchar(3) = NULL
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    IF @bostamp IS NULL OR LTRIM(RTRIM(@bostamp)) = ''
    BEGIN RAISERROR(N'bostamp obrigatório.', 16, 1); RETURN; END;
    IF @usrlogin IS NULL OR LTRIM(RTRIM(@usrlogin)) = ''
    BEGIN RAISERROR(N'usrlogin obrigatório.', 16, 1); RETURN; END;

    DECLARE @agora datetime = GETDATE(), @stat int, @usrinis_n varchar(3);
    SET @usrinis_n = LEFT(LTRIM(RTRIM(ISNULL(NULLIF(@usrinis, ''), @usrlogin))), 3);

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

    IF @stat <> 2
    BEGIN ROLLBACK; RAISERROR(N'Transição inválida: Concluir Picking só a partir de Em Curso (u_pickstat=2).', 16, 1); RETURN; END;

    UPDATE dbo.bo3
    SET u_pickrdy = 1, u_pickstat = 3,
        u_pickrdr = LEFT(LTRIM(RTRIM(@usrlogin)), 100), u_pickrdt = @agora
    WHERE bo3stamp COLLATE DATABASE_DEFAULT = @bostamp COLLATE DATABASE_DEFAULT;

    UPDATE dbo.bo SET usrinis = @usrinis_n, usrdata = CAST(@agora AS date),
                      usrhora = CONVERT(varchar(8), @agora, 108)
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

CREATE OR ALTER PROCEDURE dbo.sp_HCA_picking_cancel
    @bostamp  varchar(25),
    @usrlogin varchar(100),
    @usrinis  varchar(3) = NULL
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    IF @bostamp IS NULL OR LTRIM(RTRIM(@bostamp)) = ''
    BEGIN RAISERROR(N'bostamp obrigatório.', 16, 1); RETURN; END;
    IF @usrlogin IS NULL OR LTRIM(RTRIM(@usrlogin)) = ''
    BEGIN RAISERROR(N'usrlogin obrigatório.', 16, 1); RETURN; END;

    DECLARE @agora datetime = GETDATE(), @stat int, @usrinis_n varchar(3),
            @usrdata datetime, @usrhora varchar(8);
    SET @usrinis_n = LEFT(LTRIM(RTRIM(ISNULL(NULLIF(@usrinis, ''), @usrlogin))), 3);
    SET @usrdata = CAST(@agora AS date);
    SET @usrhora = CONVERT(varchar(8), @agora, 108);

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

    -- Reverter quantidades (mesmo comportamento do cancel legado).
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

    UPDATE bi2 SET u_qtdaut = 0, u_qtdautur = '', u_qtdautdt = CAST('19000101' AS datetime)
    FROM dbo.bi2 bi2
    INNER JOIN dbo.bi bi ON bi.bistamp COLLATE DATABASE_DEFAULT = bi2.bi2stamp COLLATE DATABASE_DEFAULT
    WHERE bi.bostamp COLLATE DATABASE_DEFAULT = @bostamp COLLATE DATABASE_DEFAULT;

    UPDATE dbo.bo3
    SET u_pickrdy = 0, u_pickstat = 0,
        u_pickrdr = LEFT(LTRIM(RTRIM(@usrlogin)), 100), u_pickrdt = @agora
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

CREATE OR ALTER PROCEDURE dbo.sp_HCA_picking_back_to_ready
    @bostamp  varchar(25),
    @usrlogin varchar(100),
    @usrinis  varchar(3) = NULL
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    IF @bostamp IS NULL OR LTRIM(RTRIM(@bostamp)) = ''
    BEGIN RAISERROR(N'bostamp obrigatório.', 16, 1); RETURN; END;
    IF @usrlogin IS NULL OR LTRIM(RTRIM(@usrlogin)) = ''
    BEGIN RAISERROR(N'usrlogin obrigatório.', 16, 1); RETURN; END;

    DECLARE @agora datetime = GETDATE(), @stat int, @usrinis_n varchar(3);
    SET @usrinis_n = LEFT(LTRIM(RTRIM(ISNULL(NULLIF(@usrinis, ''), @usrlogin))), 3);

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

    IF @stat <> 2
    BEGIN ROLLBACK; RAISERROR(N'Transição inválida: Voltar a Preparado só a partir de Em Curso (u_pickstat=2).', 16, 1); RETURN; END;

    UPDATE dbo.bo3
    SET u_pickrdy = 1, u_pickstat = 1,
        u_pickrdr = LEFT(LTRIM(RTRIM(@usrlogin)), 100), u_pickrdt = @agora
    WHERE bo3stamp COLLATE DATABASE_DEFAULT = @bostamp COLLATE DATABASE_DEFAULT;

    UPDATE dbo.bo SET usrinis = @usrinis_n, usrdata = CAST(@agora AS date),
                      usrhora = CONVERT(varchar(8), @agora, 108)
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

CREATE OR ALTER PROCEDURE dbo.sp_HCA_picking_reopen
    @bostamp  varchar(25),
    @usrlogin varchar(100),
    @usrinis  varchar(3) = NULL
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    IF @bostamp IS NULL OR LTRIM(RTRIM(@bostamp)) = ''
    BEGIN RAISERROR(N'bostamp obrigatório.', 16, 1); RETURN; END;
    IF @usrlogin IS NULL OR LTRIM(RTRIM(@usrlogin)) = ''
    BEGIN RAISERROR(N'usrlogin obrigatório.', 16, 1); RETURN; END;

    DECLARE @agora datetime = GETDATE(), @stat int, @usrinis_n varchar(3);
    SET @usrinis_n = LEFT(LTRIM(RTRIM(ISNULL(NULLIF(@usrinis, ''), @usrlogin))), 3);

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

    IF @stat <> 3
    BEGIN ROLLBACK; RAISERROR(N'Transição inválida: Reabrir Picking só a partir de Concluído (u_pickstat=3).', 16, 1); RETURN; END;

    UPDATE dbo.bo3
    SET u_pickrdy = 1, u_pickstat = 2,
        u_pickrdr = LEFT(LTRIM(RTRIM(@usrlogin)), 100), u_pickrdt = @agora
    WHERE bo3stamp COLLATE DATABASE_DEFAULT = @bostamp COLLATE DATABASE_DEFAULT;

    UPDATE dbo.bo SET usrinis = @usrinis_n, usrdata = CAST(@agora AS date),
                      usrhora = CONVERT(varchar(8), @agora, 108)
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
GO


/* ========== 34 / 052_grant_picking_workflow_sps.sql ========== */
-- =============================================================================
-- Liliana & Seródio — Portal Logístico
-- Script: 052_grant_picking_workflow_sps.sql
-- Ambiente: UAT / teste; Produção só no GO formal
-- =============================================================================
-- GRANT portal_app (quando o login existir no ambiente):
-- GRANT EXECUTE ON dbo.sp_HCA_picking_start TO [portal_app];
-- GRANT EXECUTE ON dbo.sp_HCA_picking_complete TO [portal_app];
-- GRANT EXECUTE ON dbo.sp_HCA_picking_cancel TO [portal_app];
-- GRANT EXECUTE ON dbo.sp_HCA_picking_back_to_ready TO [portal_app];
-- GRANT EXECUTE ON dbo.sp_HCA_picking_reopen TO [portal_app];
-- =============================================================================
GRANT EXECUTE ON dbo.sp_HCA_picking_start TO [portal_app];
GRANT EXECUTE ON dbo.sp_HCA_picking_complete TO [portal_app];
GRANT EXECUTE ON dbo.sp_HCA_picking_cancel TO [portal_app];
GRANT EXECUTE ON dbo.sp_HCA_picking_back_to_ready TO [portal_app];
GRANT EXECUTE ON dbo.sp_HCA_picking_reopen TO [portal_app];
GO
GO


/* ========== 35 / 053_backfill_bo3_u_pickstat_ready.sql ========== */
-- =============================================================================
-- Liliana & Seródio — Portal Logístico
-- Script: 053_backfill_bo3_u_pickstat_ready.sql
-- Ambiente: UAT / teste; Produção só no GO formal
-- =============================================================================
-- Encomendas já marcadas pronta (u_pickrdy=1) sem estado → Preparado (1).
-- Não altera ndos=66.
-- =============================================================================

UPDATE bo3
SET u_pickstat = 1
FROM dbo.bo3 bo3
INNER JOIN dbo.bo bo
    ON bo.bostamp COLLATE DATABASE_DEFAULT = bo3.bo3stamp COLLATE DATABASE_DEFAULT
WHERE bo.ndos = 1
  AND ISNULL(bo.fechada, 0) = 0
  AND CAST(ISNULL(bo3.u_pickrdy, 0) AS int) = 1
  AND CAST(ISNULL(bo3.u_pickstat, 0) AS int) = 0;
GO
GO


/* ========== 36 / 054_alter_view_HCA_cortes_quantidade_fechada_picking_concluido.sql ========== */
-- =============================================================================
-- Liliana & Seródio — Portal Logístico
-- Script: 054_alter_view_HCA_cortes_quantidade_fechada_picking_concluido.sql
-- Ambiente: UAT primeiro; Produção só no GO formal
-- =============================================================================
-- Quantidades não entregues: só encomendas (ndos=1) fechadas, com picking
-- concluído (BO3.u_pickstat = 3), em que u_qttorig > u_qtdaut.
-- =============================================================================

CREATE OR ALTER VIEW dbo.view_HCA_cortes_quantidade
AS
SELECT
    bi.bistamp,
    bi.bostamp,
    bo.obrano,
    bo.ndos,
    bo.dataobra,
    bo.ousrhora,
    ISNULL(bo.fechada, 0) AS fecho,
    CAST(ISNULL(bo3.u_pickrdy, 0) AS bit) AS pronta_picking,
    CAST(ISNULL(bo3.u_urgente, 0) AS bit) AS urgente,
    CAST(ISNULL(bo3.u_pickstat, 0) AS int) AS pick_status,
    bo.no AS cliente_no,
    bo.estab AS cliente_estab,
    LTRIM(RTRIM(bo.nome)) AS cliente_nome,

    LTRIM(RTRIM(bi.ref)) AS ref,
    LTRIM(RTRIM(bi.design)) AS design,
    LTRIM(RTRIM(COALESCE(
        NULLIF(LTRIM(RTRIM(ISNULL(bi.cor, ''))), ''),
        NULLIF(LTRIM(RTRIM(ISNULL(bi.u_cor, ''))), ''),
        ''
    ))) AS cor,
    LTRIM(RTRIM(ISNULL(bi.unidade, ''))) AS unidade,

    bi2.u_qttorig AS quantidade_original,
    bi2.u_qtdaut AS quantidade_autorizada,
    (bi2.u_qttorig - bi2.u_qtdaut) AS quantidade_nao_autorizada,
    bi.qtt2 AS quantidade_fornecida
FROM dbo.bi bi WITH (NOLOCK)
INNER JOIN dbo.bo bo WITH (NOLOCK)
    ON bo.bostamp = bi.bostamp
INNER JOIN dbo.bi2 bi2 WITH (NOLOCK)
    ON bi2.bi2stamp COLLATE DATABASE_DEFAULT = bi.bistamp COLLATE DATABASE_DEFAULT
LEFT JOIN dbo.bo3 bo3 WITH (NOLOCK)
    ON bo3.bo3stamp COLLATE DATABASE_DEFAULT = bo.bostamp COLLATE DATABASE_DEFAULT
WHERE bo.ndos = 1
  AND ISNULL(bo.fechada, 0) = 1
  AND CAST(ISNULL(bo3.u_pickstat, 0) AS int) = 3
  AND bi2.u_qttorig > 0
  AND bi2.u_qtdaut >= 0
  AND bi2.u_qttorig > bi2.u_qtdaut;
GO
GO


/* ========== 37 / 055_alter_view_HCA_cortes_quantidade_so_fechadas.sql ========== */
-- =============================================================================
-- Liliana & Seródio — Portal Logístico
-- Script: 055_alter_view_HCA_cortes_quantidade_so_fechadas.sql
-- Ambiente: UAT primeiro; Produção só no GO formal
-- =============================================================================
-- Quantidades não entregues: só encomendas (ndos=1) fechadas em que
-- u_qttorig > u_qtdaut (pedido inicial não totalmente aprovado para picking).
-- Nota: em UAT o fecho operacional não deixa u_pickstat=3 nas encomendas;
-- o critério de «picking/processo concluído» é BO.fechada = 1.
-- =============================================================================

CREATE OR ALTER VIEW dbo.view_HCA_cortes_quantidade
AS
SELECT
    bi.bistamp,
    bi.bostamp,
    bo.obrano,
    bo.ndos,
    bo.dataobra,
    bo.ousrhora,
    ISNULL(bo.fechada, 0) AS fecho,
    CAST(ISNULL(bo3.u_pickrdy, 0) AS bit) AS pronta_picking,
    CAST(ISNULL(bo3.u_urgente, 0) AS bit) AS urgente,
    CAST(ISNULL(bo3.u_pickstat, 0) AS int) AS pick_status,
    bo.no AS cliente_no,
    bo.estab AS cliente_estab,
    LTRIM(RTRIM(bo.nome)) AS cliente_nome,

    LTRIM(RTRIM(bi.ref)) AS ref,
    LTRIM(RTRIM(bi.design)) AS design,
    LTRIM(RTRIM(COALESCE(
        NULLIF(LTRIM(RTRIM(ISNULL(bi.cor, ''))), ''),
        NULLIF(LTRIM(RTRIM(ISNULL(bi.u_cor, ''))), ''),
        ''
    ))) AS cor,
    LTRIM(RTRIM(ISNULL(bi.unidade, ''))) AS unidade,

    bi2.u_qttorig AS quantidade_original,
    bi2.u_qtdaut AS quantidade_autorizada,
    (bi2.u_qttorig - bi2.u_qtdaut) AS quantidade_nao_autorizada,
    bi.qtt2 AS quantidade_fornecida
FROM dbo.bi bi WITH (NOLOCK)
INNER JOIN dbo.bo bo WITH (NOLOCK)
    ON bo.bostamp = bi.bostamp
INNER JOIN dbo.bi2 bi2 WITH (NOLOCK)
    ON bi2.bi2stamp COLLATE DATABASE_DEFAULT = bi.bistamp COLLATE DATABASE_DEFAULT
LEFT JOIN dbo.bo3 bo3 WITH (NOLOCK)
    ON bo3.bo3stamp COLLATE DATABASE_DEFAULT = bo.bostamp COLLATE DATABASE_DEFAULT
WHERE bo.ndos = 1
  AND ISNULL(bo.fechada, 0) = 1
  AND bi2.u_qttorig > 0
  AND bi2.u_qtdaut >= 0
  AND bi2.u_qttorig > bi2.u_qtdaut;
GO
GO


/* ========== 38 / 056_alter_sp_picking_cancel_motivo_u_pickcobs.sql ========== */
-- =============================================================================
-- Liliana & Seródio — Portal Logístico
-- Script: 056_alter_sp_picking_cancel_motivo_u_pickcobs.sql
-- Pré-requisito: BO3.u_pickcobs (Carácter / varchar(254)) no Framework + Atualizar a Tabela
-- =============================================================================
-- Grava motivo de cancelamento em BO3.u_pickcobs:
--   sp_HCA_picking_cancel          → @motivo obrigatório
--   sp_HCA_marcar_pronta_picking   → @motivo obrigatório quando @pronta=0;
--                                    limpa u_pickcobs quando @pronta=1
-- =============================================================================

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

    UPDATE bi2 SET u_qtdaut = 0, u_qtdautur = '', u_qtdautdt = CAST('19000101' AS datetime)
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
            u_qtdautdt = CAST('19000101' AS datetime)
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
GO


/* ========== 39 / 057_create_sp_HCA_marcar_urgente_encomenda.sql ========== */
-- =============================================================================
-- Liliana & Seródio — Portal Logístico
-- Script: 057_create_sp_HCA_marcar_urgente_encomenda.sql
-- Pré-requisito: BO3.u_urgente (Lógico) no Framework + Atualizar a Tabela
-- =============================================================================

CREATE OR ALTER PROCEDURE dbo.sp_HCA_marcar_urgente_encomenda
    @bostamp  varchar(25),
    @urgente  bit,
    @usrlogin varchar(100),
    @usrinis  varchar(3) = NULL
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    IF @bostamp IS NULL OR LTRIM(RTRIM(@bostamp)) = ''
    BEGIN RAISERROR(N'bostamp obrigatório.', 16, 1); RETURN; END;
    IF @usrlogin IS NULL OR LTRIM(RTRIM(@usrlogin)) = ''
    BEGIN RAISERROR(N'usrlogin obrigatório.', 16, 1); RETURN; END;

    DECLARE @agora datetime = GETDATE(),
            @usrdata datetime,
            @usrhora varchar(8),
            @usrinis_n varchar(3);

    SET @usrdata = CAST(@agora AS date);
    SET @usrhora = CONVERT(varchar(8), @agora, 108);
    SET @usrinis_n = LEFT(LTRIM(RTRIM(ISNULL(NULLIF(@usrinis, ''), @usrlogin))), 3);

    BEGIN TRAN;

    IF NOT EXISTS (
        SELECT 1 FROM dbo.bo bo WITH (UPDLOCK, ROWLOCK)
        WHERE bo.bostamp COLLATE DATABASE_DEFAULT = @bostamp COLLATE DATABASE_DEFAULT
          AND bo.ndos = 1
          AND ISNULL(bo.fechada, 0) = 0)
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

    UPDATE dbo.bo3
    SET u_urgente = ISNULL(@urgente, 0)
    WHERE bo3stamp COLLATE DATABASE_DEFAULT = @bostamp COLLATE DATABASE_DEFAULT;

    UPDATE dbo.bo
    SET usrinis = @usrinis_n, usrdata = @usrdata, usrhora = @usrhora
    WHERE bostamp COLLATE DATABASE_DEFAULT = @bostamp COLLATE DATABASE_DEFAULT;

    COMMIT;

    SELECT
        bo.bostamp,
        CAST(ISNULL(bo3.u_urgente, 0) AS bit) AS urgente
    FROM dbo.bo bo WITH (NOLOCK)
    LEFT JOIN dbo.bo3 bo3 WITH (NOLOCK)
        ON bo3.bo3stamp COLLATE DATABASE_DEFAULT = bo.bostamp COLLATE DATABASE_DEFAULT
    WHERE bo.bostamp COLLATE DATABASE_DEFAULT = @bostamp COLLATE DATABASE_DEFAULT;
END;
GO
GO


/* ========== 40 / 058_create_sp_HCA_cancelar_encomenda.sql ========== */
-- =============================================================================
-- Liliana & Seródio — Portal Logístico
-- Script: 058_create_sp_HCA_cancelar_encomenda.sql
-- Pré-requisito: BO3.u_pickcobs (varchar 254) no Framework + Atualizar a Tabela
-- =============================================================================
-- Cancela / fecha encomenda (ndos=1) ainda não enviada a picking:
--   BO.fechada = 1
--   BO3.u_pickcobs = motivo (obrigatório)
-- =============================================================================

CREATE OR ALTER PROCEDURE dbo.sp_HCA_cancelar_encomenda
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

    DECLARE @agora datetime = GETDATE(),
            @usrdata datetime,
            @usrhora varchar(8),
            @usrinis_n varchar(3),
            @motivo_n varchar(254),
            @pickrdy bit;

    SET @usrdata = CAST(@agora AS date);
    SET @usrhora = CONVERT(varchar(8), @agora, 108);
    SET @usrinis_n = LEFT(LTRIM(RTRIM(ISNULL(NULLIF(@usrinis, ''), @usrlogin))), 3);
    SET @motivo_n = LEFT(LTRIM(RTRIM(@motivo)), 254);

    BEGIN TRAN;

    IF NOT EXISTS (
        SELECT 1 FROM dbo.bo bo WITH (UPDLOCK, ROWLOCK)
        WHERE bo.bostamp COLLATE DATABASE_DEFAULT = @bostamp COLLATE DATABASE_DEFAULT
          AND bo.ndos = 1
          AND ISNULL(bo.fechada, 0) = 0)
    BEGIN
        ROLLBACK;
        RAISERROR(N'Encomenda não encontrada ou já fechada/série inválida.', 16, 1);
        RETURN;
    END;

    IF NOT EXISTS (
        SELECT 1 FROM dbo.bo3 WITH (UPDLOCK, ROWLOCK)
        WHERE bo3stamp COLLATE DATABASE_DEFAULT = @bostamp COLLATE DATABASE_DEFAULT
    )
        INSERT INTO dbo.bo3 (bo3stamp) VALUES (@bostamp);

    SELECT @pickrdy = CAST(ISNULL(u_pickrdy, 0) AS bit)
    FROM dbo.bo3 WITH (UPDLOCK, ROWLOCK)
    WHERE bo3stamp COLLATE DATABASE_DEFAULT = @bostamp COLLATE DATABASE_DEFAULT;

    IF ISNULL(@pickrdy, 0) = 1
    BEGIN
        ROLLBACK;
        RAISERROR(N'Não é possível cancelar: a encomenda já está em picking. Cancele o picking primeiro.', 16, 1);
        RETURN;
    END;

    UPDATE dbo.bo3
    SET u_pickcobs = @motivo_n
    WHERE bo3stamp COLLATE DATABASE_DEFAULT = @bostamp COLLATE DATABASE_DEFAULT;

    UPDATE dbo.bo
    SET
        fechada = 1,
        usrinis = @usrinis_n,
        usrdata = @usrdata,
        usrhora = @usrhora
    WHERE bostamp COLLATE DATABASE_DEFAULT = @bostamp COLLATE DATABASE_DEFAULT
      AND ndos = 1;

    COMMIT;

    SELECT
        bo.bostamp,
        CAST(ISNULL(bo.fechada, 0) AS bit) AS fechada,
        bo.obrano,
        LTRIM(RTRIM(ISNULL(bo3.u_pickcobs, ''))) AS motivo
    FROM dbo.bo bo WITH (NOLOCK)
    LEFT JOIN dbo.bo3 bo3 WITH (NOLOCK)
        ON bo3.bo3stamp COLLATE DATABASE_DEFAULT = bo.bostamp COLLATE DATABASE_DEFAULT
    WHERE bo.bostamp COLLATE DATABASE_DEFAULT = @bostamp COLLATE DATABASE_DEFAULT;
END;
GO
GO


/* ========== 41 / 059_create_sp_HCA_marcar_checkin_dossier.sql ========== */
-- =============================================================================
-- Liliana & Seródio — Portal Logístico
-- Script: 059_create_sp_HCA_marcar_checkin_dossier.sql
-- Ambiente: UAT / teste; Produção só no GO formal
-- =============================================================================
-- Pré-requisito (Framework PHC → Atualizar a Tabela):
--   BO3.u_chkin   (Lógico / bit)     — Check-in realizado
--   BO3.u_chkinur (Carácter 100)     — Quem fez o Check-in
--   BO3.u_chkindt (Data / datetime)  — Quando
--
-- Marca Check-in em dossier ndos=@serie_picking (default 66):
--   @checkin = 1 → u_chkin=1, ur, dt  (só se ainda u_chkin=0)
--   @checkin = 0 → limpa check-in (desfazer)
-- Não altera u_pickstat nem BO.fechada.
-- =============================================================================

CREATE OR ALTER PROCEDURE dbo.sp_HCA_marcar_checkin_dossier
    @bostamp         varchar(25),
    @checkin         bit,
    @serie_picking   int = 66,
    @usrlogin        varchar(100),
    @usrinis         varchar(3) = NULL
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    IF @bostamp IS NULL OR LTRIM(RTRIM(@bostamp)) = ''
    BEGIN RAISERROR(N'bostamp obrigatório.', 16, 1); RETURN; END;
    IF @usrlogin IS NULL OR LTRIM(RTRIM(@usrlogin)) = ''
    BEGIN RAISERROR(N'usrlogin obrigatório.', 16, 1); RETURN; END;
    IF @serie_picking IS NULL OR @serie_picking <= 0
    BEGIN RAISERROR(N'serie_picking inválida.', 16, 1); RETURN; END;

    DECLARE @agora datetime = GETDATE(),
            @usrdata datetime,
            @usrhora varchar(8),
            @usrinis_n varchar(3),
            @ja_checkin bit;

    SET @usrdata = CAST(@agora AS date);
    SET @usrhora = CONVERT(varchar(8), @agora, 108);
    SET @usrinis_n = LEFT(LTRIM(RTRIM(ISNULL(NULLIF(@usrinis, ''), @usrlogin))), 3);

    BEGIN TRAN;

    IF NOT EXISTS (
        SELECT 1 FROM dbo.bo bo WITH (UPDLOCK, ROWLOCK)
        WHERE bo.bostamp COLLATE DATABASE_DEFAULT = @bostamp COLLATE DATABASE_DEFAULT
          AND bo.ndos = @serie_picking
          AND ISNULL(bo.fechada, 0) = 0)
    BEGIN
        ROLLBACK;
        RAISERROR(N'Dossier não encontrado, fechado ou fora da série configurada.', 16, 1);
        RETURN;
    END;

    IF NOT EXISTS (
        SELECT 1 FROM dbo.bo3 WITH (UPDLOCK, ROWLOCK)
        WHERE bo3stamp COLLATE DATABASE_DEFAULT = @bostamp COLLATE DATABASE_DEFAULT)
        INSERT INTO dbo.bo3 (bo3stamp) VALUES (@bostamp);

    SELECT @ja_checkin = CAST(ISNULL(u_chkin, 0) AS bit)
    FROM dbo.bo3 WITH (UPDLOCK, ROWLOCK)
    WHERE bo3stamp COLLATE DATABASE_DEFAULT = @bostamp COLLATE DATABASE_DEFAULT;

    IF ISNULL(@checkin, 0) = 1
    BEGIN
        IF ISNULL(@ja_checkin, 0) = 1
        BEGIN
            ROLLBACK;
            RAISERROR(N'Check-in já realizado neste dossier.', 16, 1);
            RETURN;
        END;

        UPDATE dbo.bo3
        SET u_chkin = 1,
            u_chkinur = LEFT(LTRIM(RTRIM(@usrlogin)), 100),
            u_chkindt = @agora
        WHERE bo3stamp COLLATE DATABASE_DEFAULT = @bostamp COLLATE DATABASE_DEFAULT;
    END
    ELSE
    BEGIN
        UPDATE dbo.bo3
        SET u_chkin = 0,
            u_chkinur = '',
            u_chkindt = CAST('19000101' AS datetime)
        WHERE bo3stamp COLLATE DATABASE_DEFAULT = @bostamp COLLATE DATABASE_DEFAULT;
    END;

    UPDATE dbo.bo
    SET usrinis = @usrinis_n, usrdata = @usrdata, usrhora = @usrhora
    WHERE bostamp COLLATE DATABASE_DEFAULT = @bostamp COLLATE DATABASE_DEFAULT;

    COMMIT;

    SELECT
        bo.bostamp,
        CAST(ISNULL(bo3.u_chkin, 0) AS bit) AS check_in,
        LTRIM(RTRIM(ISNULL(bo3.u_chkinur, ''))) AS check_in_por,
        CASE
            WHEN bo3.u_chkindt IS NULL OR YEAR(bo3.u_chkindt) < 1950 THEN CAST(NULL AS datetime)
            ELSE bo3.u_chkindt
        END AS check_in_em,
        CAST(bo.obrano AS int) AS obrano,
        bo.ndos
    FROM dbo.bo bo WITH (NOLOCK)
    LEFT JOIN dbo.bo3 bo3 WITH (NOLOCK)
        ON bo3.bo3stamp COLLATE DATABASE_DEFAULT = bo.bostamp COLLATE DATABASE_DEFAULT
    WHERE bo.bostamp COLLATE DATABASE_DEFAULT = @bostamp COLLATE DATABASE_DEFAULT;
END;
GO
GO


/* ========== 42 / 059b_grant_sp_HCA_marcar_checkin_dossier.sql ========== */
-- =============================================================================
-- Liliana & Seródio — Portal Logístico
-- Script: 059b_grant_sp_HCA_marcar_checkin_dossier.sql
-- =============================================================================
GRANT EXECUTE ON dbo.sp_HCA_marcar_checkin_dossier TO [portal_app];
GO
GO


/* ========== 43 / 060_create_sp_HCA_reverter_checkin_dossier.sql ========== */
-- =============================================================================
-- Liliana & Seródio — Portal Logístico
-- Script: 060_create_sp_HCA_reverter_checkin_dossier.sql
-- Ambiente: UAT / teste; Produção só no GO formal
-- =============================================================================
-- Pré-requisito (Framework PHC → Atualizar a Tabela):
--   BO3.u_chkin   (Lógico / bit)
--   BO3.u_chkinur (Carácter 100)
--   BO3.u_chkindt (Data / datetime NOT NULL — limpeza = data base PHC 1900-01-01)
--
-- Reverte Check-in em dossier ndos=@serie_picking (default 66):
--   exige fechada=0 e u_chkin=1
--   limpa u_chkin / u_chkinur / u_chkindt
-- Não altera u_pickstat nem BO.fechada.
-- =============================================================================

CREATE OR ALTER PROCEDURE dbo.sp_HCA_reverter_checkin_dossier
    @bostamp         varchar(25),
    @serie_picking   int = 66,
    @usrlogin        varchar(100),
    @usrinis         varchar(3) = NULL
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    IF @bostamp IS NULL OR LTRIM(RTRIM(@bostamp)) = ''
    BEGIN RAISERROR(N'bostamp obrigatório.', 16, 1); RETURN; END;
    IF @usrlogin IS NULL OR LTRIM(RTRIM(@usrlogin)) = ''
    BEGIN RAISERROR(N'usrlogin obrigatório.', 16, 1); RETURN; END;
    IF @serie_picking IS NULL OR @serie_picking <= 0
    BEGIN RAISERROR(N'serie_picking inválida.', 16, 1); RETURN; END;

    DECLARE @agora datetime = GETDATE(),
            @usrdata datetime,
            @usrhora varchar(8),
            @usrinis_n varchar(3),
            @ja_checkin bit;

    SET @usrdata = CAST(@agora AS date);
    SET @usrhora = CONVERT(varchar(8), @agora, 108);
    SET @usrinis_n = LEFT(LTRIM(RTRIM(ISNULL(NULLIF(@usrinis, ''), @usrlogin))), 3);

    BEGIN TRAN;

    IF NOT EXISTS (
        SELECT 1 FROM dbo.bo bo WITH (UPDLOCK, ROWLOCK)
        WHERE bo.bostamp COLLATE DATABASE_DEFAULT = @bostamp COLLATE DATABASE_DEFAULT
          AND bo.ndos = @serie_picking
          AND ISNULL(bo.fechada, 0) = 0)
    BEGIN
        ROLLBACK;
        RAISERROR(N'Dossier não encontrado, fechado ou fora da série configurada.', 16, 1);
        RETURN;
    END;

    IF NOT EXISTS (
        SELECT 1 FROM dbo.bo3 WITH (UPDLOCK, ROWLOCK)
        WHERE bo3stamp COLLATE DATABASE_DEFAULT = @bostamp COLLATE DATABASE_DEFAULT)
    BEGIN
        ROLLBACK;
        RAISERROR(N'Dossier sem Check-in activo.', 16, 1);
        RETURN;
    END;

    SELECT @ja_checkin = CAST(ISNULL(u_chkin, 0) AS bit)
    FROM dbo.bo3 WITH (UPDLOCK, ROWLOCK)
    WHERE bo3stamp COLLATE DATABASE_DEFAULT = @bostamp COLLATE DATABASE_DEFAULT;

    IF ISNULL(@ja_checkin, 0) = 0
    BEGIN
        ROLLBACK;
        RAISERROR(N'Dossier sem Check-in activo.', 16, 1);
        RETURN;
    END;

    UPDATE dbo.bo3
    SET u_chkin = 0,
        u_chkinur = '',
        u_chkindt = CAST('19000101' AS datetime)
    WHERE bo3stamp COLLATE DATABASE_DEFAULT = @bostamp COLLATE DATABASE_DEFAULT;

    UPDATE dbo.bo
    SET usrinis = @usrinis_n, usrdata = @usrdata, usrhora = @usrhora
    WHERE bostamp COLLATE DATABASE_DEFAULT = @bostamp COLLATE DATABASE_DEFAULT;

    COMMIT;

    SELECT
        bo.bostamp,
        CAST(ISNULL(bo3.u_chkin, 0) AS bit) AS check_in,
        LTRIM(RTRIM(ISNULL(bo3.u_chkinur, ''))) AS check_in_por,
        CASE
            WHEN bo3.u_chkindt IS NULL OR YEAR(bo3.u_chkindt) < 1950 THEN CAST(NULL AS datetime)
            ELSE bo3.u_chkindt
        END AS check_in_em,
        CAST(bo.obrano AS int) AS obrano,
        bo.ndos
    FROM dbo.bo bo WITH (NOLOCK)
    LEFT JOIN dbo.bo3 bo3 WITH (NOLOCK)
        ON bo3.bo3stamp COLLATE DATABASE_DEFAULT = bo.bostamp COLLATE DATABASE_DEFAULT
    WHERE bo.bostamp COLLATE DATABASE_DEFAULT = @bostamp COLLATE DATABASE_DEFAULT;
END;
GO
GO


/* ========== 44 / 060b_grant_sp_HCA_reverter_checkin_dossier.sql ========== */
-- =============================================================================
-- Liliana & Seródio — Portal Logístico
-- Script: 060b_grant_sp_HCA_reverter_checkin_dossier.sql
-- =============================================================================
GRANT EXECUTE ON dbo.sp_HCA_reverter_checkin_dossier TO [portal_app];
GO
GO


/* ========== 45 / 061_alter_view_HCA_encomenda_linhas_disponivel_portal.sql ========== */
-- =============================================================================
-- Liliana & Seródio — Portal Logístico
-- Script: 061_alter_view_HCA_encomenda_linhas_disponivel_portal.sql
-- Ambiente: UAT primeiro; Produção só no GO formal
-- =============================================================================
-- Expõe STOBS.u_dispPort como disponivel_no_portal (linhas de encomenda).
-- Não filtra linhas: documentos existentes mantêm todas as referências.
-- Pré-requisito: STOBS.u_dispPort (bit NOT NULL DEFAULT 0); relação por ref.
-- Base: definição actual (049) + JOIN STOBS.
-- =============================================================================

CREATE OR ALTER VIEW dbo.view_HCA_encomenda_linhas
AS
SELECT
    bi.bistamp,
    bi.bostamp,
    bo.obrano,
    bo.ndos,
    bo.nmdos,
    bo.dataobra,
    bo.ousrhora,
    ISNULL(bo.fechada, 0) AS fecho,
    CAST(ISNULL(bo3.u_pickrdy, 0) AS bit) AS pronta_picking,
    CAST(ISNULL(bo3.u_pickstat, 0) AS int) AS pick_status,
    CAST(ISNULL(bo3.u_urgente, 0) AS bit) AS urgente,
    bo.no AS cliente_no,
    bo.estab AS cliente_estab,
    LTRIM(RTRIM(bo.nome)) AS cliente_nome,

    LTRIM(RTRIM(bi.ref)) AS ref,
    LTRIM(RTRIM(bi.design)) AS design,
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

    CAST(ISNULL(stobs.u_dispPort, 0) AS bit) AS disponivel_no_portal,

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
    ON LTRIM(RTRIM(st.ref)) = LTRIM(RTRIM(bi.ref))
LEFT JOIN dbo.stobs stobs WITH (NOLOCK)
    ON LTRIM(RTRIM(stobs.ref)) = LTRIM(RTRIM(bi.ref));
GO
GO


/* ========== 46 / 062_create_u_HcaPrevEntrada_tables.sql ========== */
-- =============================================================================
-- Liliana & Seródio — Portal Logístico
-- Script: 062_create_u_HcaPrevEntrada_tables.sql
-- Ambiente: UAT primeiro; Produção só no GO formal
-- =============================================================================
-- Tabelas próprias do Portal (previsões de entrada). Prefixo u_Hca*.
-- Idempotente. Não altera STOBS.u_dispPort nem ST.stock.
-- =============================================================================

SET NOCOUNT ON;
SET XACT_ABORT ON;

IF OBJECT_ID(N'dbo.u_HcaPrevEntrada', N'U') IS NULL
BEGIN
    CREATE TABLE dbo.u_HcaPrevEntrada
    (
        Id          uniqueidentifier NOT NULL
            CONSTRAINT DF_u_HcaPrevEntrada_Id DEFAULT (NEWSEQUENTIALID()),
        DataInicio  date             NOT NULL,
        DataFim     date             NOT NULL,
        CriadoEm    datetime2(0)     NOT NULL
            CONSTRAINT DF_u_HcaPrevEntrada_CriadoEm DEFAULT (SYSUTCDATETIME()),
        CriadoPor   nvarchar(100)    NOT NULL
            CONSTRAINT DF_u_HcaPrevEntrada_CriadoPor DEFAULT (N''),
        AlteradoEm  datetime2(0)     NULL,
        AlteradoPor nvarchar(100)    NULL,
        CONSTRAINT PK_u_HcaPrevEntrada PRIMARY KEY (Id),
        CONSTRAINT UQ_u_HcaPrevEntrada_Periodo UNIQUE (DataInicio, DataFim),
        CONSTRAINT CK_u_HcaPrevEntrada_Datas CHECK (DataInicio <= DataFim)
    );
END;
GO

IF OBJECT_ID(N'dbo.u_HcaPrevEntradaLin', N'U') IS NULL
BEGIN
    CREATE TABLE dbo.u_HcaPrevEntradaLin
    (
        Id                  uniqueidentifier NOT NULL
            CONSTRAINT DF_u_HcaPrevEntradaLin_Id DEFAULT (NEWSEQUENTIALID()),
        PrevisaoId          uniqueidentifier NOT NULL,
        Ref                 varchar(18)      NOT NULL,
        QuantidadePrevista  numeric(16, 2)   NOT NULL
            CONSTRAINT DF_u_HcaPrevEntradaLin_Qty DEFAULT (0),
        CONSTRAINT PK_u_HcaPrevEntradaLin PRIMARY KEY (Id),
        CONSTRAINT FK_u_HcaPrevEntradaLin_Cab
            FOREIGN KEY (PrevisaoId) REFERENCES dbo.u_HcaPrevEntrada (Id) ON DELETE CASCADE,
        CONSTRAINT UQ_u_HcaPrevEntradaLin_Ref UNIQUE (PrevisaoId, Ref),
        CONSTRAINT CK_u_HcaPrevEntradaLin_Qty CHECK (QuantidadePrevista >= 0)
    );
END;
GO

IF NOT EXISTS (
    SELECT 1 FROM sys.indexes
    WHERE name = N'IX_u_HcaPrevEntradaLin_PrevisaoId'
      AND object_id = OBJECT_ID(N'dbo.u_HcaPrevEntradaLin')
)
BEGIN
    CREATE INDEX IX_u_HcaPrevEntradaLin_PrevisaoId
        ON dbo.u_HcaPrevEntradaLin (PrevisaoId);
END;
GO
GO


/* ========== 47 / 063_create_sp_HCA_previsoes_entrada.sql ========== */
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
GO


/* ========== 48 / 063b_grant_sp_HCA_previsoes_entrada.sql ========== */
-- =============================================================================
-- Liliana & Seródio — Portal Logístico
-- Script: 063b_grant_sp_HCA_previsoes_entrada.sql
-- =============================================================================
-- Substituir [portal_app] se o login da app tiver outro nome.
-- Em UAT com sa, este script pode falhar se portal_app não existir — é opcional.
-- =============================================================================

IF EXISTS (SELECT 1 FROM sys.database_principals WHERE name = N'portal_app')
BEGIN
    GRANT SELECT, INSERT, UPDATE, DELETE ON dbo.u_HcaPrevEntrada TO [portal_app];
    GRANT SELECT, INSERT, UPDATE, DELETE ON dbo.u_HcaPrevEntradaLin TO [portal_app];
    GRANT EXECUTE ON dbo.sp_HCA_prev_entrada_listar TO [portal_app];
    GRANT EXECUTE ON dbo.sp_HCA_prev_entrada_obter TO [portal_app];
    GRANT EXECUTE ON dbo.sp_HCA_prev_entrada_criar TO [portal_app];
    GRANT EXECUTE ON dbo.sp_HCA_prev_entrada_guardar TO [portal_app];
    GRANT EXECUTE ON dbo.sp_HCA_prev_entrada_sugerir_artigos TO [portal_app];
END;
GO
GO


/* ========== 49 / 064_alter_u_HcaPrevEntrada_ciclo.sql ========== */
-- =============================================================================
-- Liliana & Seródio — Portal Logístico
-- Script: 064_alter_u_HcaPrevEntrada_ciclo.sql
-- Ambiente: UAT primeiro; Produção só no GO formal
-- Pré-requisito: 062_create_u_HcaPrevEntrada_tables.sql
-- =============================================================================
-- PR1 — Infraestrutura do ciclo:
--   Fechada / FechadaEm / FechadaPor
--   Remove unique exacto (DataInicio, DataFim); overlap validado nas SPs
-- Não altera u_HcaPrevEntradaLin, BI2, ST.stock nem SPs de autorização.
--
-- Cutover: após este script, todas as previsões existentes ficam Fechada=0.
-- Se existirem várias, a criação de novas falha até restar no máximo uma aberta
-- (fechar as restantes manualmente em SQL com Fechada=1 — o fecho assistido é PR3).
-- =============================================================================

SET NOCOUNT ON;
SET XACT_ABORT ON;

IF COL_LENGTH(N'dbo.u_HcaPrevEntrada', N'Fechada') IS NULL
BEGIN
    ALTER TABLE dbo.u_HcaPrevEntrada
        ADD Fechada bit NOT NULL
            CONSTRAINT DF_u_HcaPrevEntrada_Fechada DEFAULT (0);
END;
GO

IF COL_LENGTH(N'dbo.u_HcaPrevEntrada', N'FechadaEm') IS NULL
BEGIN
    ALTER TABLE dbo.u_HcaPrevEntrada
        ADD FechadaEm datetime2(0) NULL;
END;
GO

IF COL_LENGTH(N'dbo.u_HcaPrevEntrada', N'FechadaPor') IS NULL
BEGIN
    ALTER TABLE dbo.u_HcaPrevEntrada
        ADD FechadaPor nvarchar(100) NULL;
END;
GO

IF EXISTS (
    SELECT 1
    FROM sys.indexes
    WHERE name = N'UQ_u_HcaPrevEntrada_Periodo'
      AND object_id = OBJECT_ID(N'dbo.u_HcaPrevEntrada')
)
BEGIN
    ALTER TABLE dbo.u_HcaPrevEntrada
        DROP CONSTRAINT UQ_u_HcaPrevEntrada_Periodo;
END;
GO

IF NOT EXISTS (
    SELECT 1
    FROM sys.indexes
    WHERE name = N'IX_u_HcaPrevEntrada_Periodo'
      AND object_id = OBJECT_ID(N'dbo.u_HcaPrevEntrada')
)
BEGIN
    CREATE INDEX IX_u_HcaPrevEntrada_Periodo
        ON dbo.u_HcaPrevEntrada (DataInicio, DataFim);
END;
GO

IF NOT EXISTS (
    SELECT 1
    FROM sys.indexes
    WHERE name = N'IX_u_HcaPrevEntrada_Fechada'
      AND object_id = OBJECT_ID(N'dbo.u_HcaPrevEntrada')
)
BEGIN
    CREATE INDEX IX_u_HcaPrevEntrada_Fechada
        ON dbo.u_HcaPrevEntrada (Fechada)
        WHERE Fechada = 0;
END;
GO
GO


/* ========== 50 / 065_alter_sp_HCA_previsoes_entrada_ciclo.sql ========== */
-- =============================================================================
-- Liliana & Seródio — Portal Logístico
-- Script: 065_alter_sp_HCA_previsoes_entrada_ciclo.sql
-- Ambiente: UAT primeiro; Produção só no GO formal
-- Pré-requisito: 064_alter_u_HcaPrevEntrada_ciclo.sql
-- =============================================================================
-- PR1 — Estado Aberta/Fechada, anti-overlap inclusivo, no máximo 1 aberta.
-- Não implementa fecho/transferência, u_prevId nem tecto por previsão.
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
        CAST(p.Fechada AS bit) AS Fechada,
        p.FechadaEm,
        LTRIM(RTRIM(ISNULL(p.FechadaPor, N''))) AS FechadaPor,
        COUNT(l.Id) AS TotalLinhas,
        ISNULL(SUM(l.QuantidadePrevista), 0) AS QuantidadeTotal
    FROM dbo.u_HcaPrevEntrada p WITH (NOLOCK)
    LEFT JOIN dbo.u_HcaPrevEntradaLin l WITH (NOLOCK)
        ON l.PrevisaoId = p.Id
    GROUP BY
        p.Id,
        p.DataInicio,
        p.DataFim,
        p.Fechada,
        p.FechadaEm,
        p.FechadaPor
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
        p.DataFim,
        CAST(p.Fechada AS bit) AS Fechada,
        p.FechadaEm,
        LTRIM(RTRIM(ISNULL(p.FechadaPor, N''))) AS FechadaPor
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

    BEGIN TRAN;

    IF EXISTS (
        SELECT 1
        FROM dbo.u_HcaPrevEntrada WITH (UPDLOCK, HOLDLOCK)
        WHERE Fechada = 0
    )
    BEGIN
        ROLLBACK;
        RAISERROR(N'Já existe uma previsão aberta. Feche-a antes de criar outra.', 16, 1);
        RETURN;
    END;

    IF EXISTS (
        SELECT 1
        FROM dbo.u_HcaPrevEntrada WITH (UPDLOCK, HOLDLOCK)
        WHERE DataInicio <= @dataFim
          AND DataFim >= @dataInicio
    )
    BEGIN
        ROLLBACK;
        RAISERROR(N'Já existe uma previsão com período sobreposto a estas datas.', 16, 1);
        RETURN;
    END;

    DECLARE @out TABLE (Id uniqueidentifier NOT NULL);

    INSERT INTO dbo.u_HcaPrevEntrada (
        DataInicio,
        DataFim,
        CriadoEm,
        CriadoPor,
        Fechada,
        FechadaEm,
        FechadaPor
    )
    OUTPUT inserted.Id INTO @out
    VALUES (
        @dataInicio,
        @dataFim,
        SYSUTCDATETIME(),
        LEFT(LTRIM(RTRIM(ISNULL(@usrlogin, N''))), 100),
        0,
        NULL,
        NULL
    );

    SELECT @id = Id FROM @out;

    COMMIT TRAN;

    SELECT
        @id AS Id,
        @dataInicio AS DataInicio,
        @dataFim AS DataFim,
        CAST(0 AS bit) AS Fechada,
        CAST(NULL AS datetime2(0)) AS FechadaEm,
        CAST(N'' AS nvarchar(100)) AS FechadaPor;
END;
GO

CREATE OR ALTER PROCEDURE dbo.sp_HCA_prev_entrada_guardar
    @id         uniqueidentifier,
    @usrlogin   nvarchar(100),
    @linhas     nvarchar(max), -- JSON: [{"ref":"…","quantidadePrevista":0}]
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
                CAST(j.quantidadePrevista AS numeric(16, 2)) AS QuantidadePrevista
            FROM OPENJSON(@linhas)
            WITH (
                ref nvarchar(40) '$.ref',
                quantidadePrevista float '$.quantidadePrevista'
            ) j
        )
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

    COMMIT TRAN;

    EXEC dbo.sp_HCA_prev_entrada_obter @id = @id;
END;
GO
GO


/* ========== 51 / 065b_grant_sp_HCA_previsoes_entrada_ciclo.sql ========== */
-- =============================================================================
-- Liliana & Seródio — Portal Logístico
-- Script: 065b_grant_sp_HCA_previsoes_entrada_ciclo.sql
-- =============================================================================
-- Substituir [portal_app] se o login da app tiver outro nome.
-- Em UAT com sa, este script pode falhar se portal_app não existir — é opcional.
-- Pré-requisito: 064 + 065.
-- =============================================================================

IF EXISTS (SELECT 1 FROM sys.database_principals WHERE name = N'portal_app')
BEGIN
    GRANT SELECT, INSERT, UPDATE, DELETE ON dbo.u_HcaPrevEntrada TO [portal_app];
    GRANT SELECT, INSERT, UPDATE, DELETE ON dbo.u_HcaPrevEntradaLin TO [portal_app];
    GRANT EXECUTE ON dbo.sp_HCA_prev_entrada_listar TO [portal_app];
    GRANT EXECUTE ON dbo.sp_HCA_prev_entrada_obter TO [portal_app];
    GRANT EXECUTE ON dbo.sp_HCA_prev_entrada_criar TO [portal_app];
    GRANT EXECUTE ON dbo.sp_HCA_prev_entrada_guardar TO [portal_app];
    GRANT EXECUTE ON dbo.sp_HCA_prev_entrada_sugerir_artigos TO [portal_app];
END;
GO
GO


/* ========== 52 / 068_alter_sp_HCA_atualizar_qtd_autorizada_prev.sql ========== */
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
GO


/* ========== 53 / 069_alter_sp_HCA_alocacao_proporcional_prev.sql ========== */
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
GO


/* ========== 54 / 070_alter_picking_clear_u_prevId.sql ========== */
-- =============================================================================
-- Liliana & Seródio — Portal Logístico
-- Script: 070_alter_picking_clear_u_prevId.sql
-- Ambiente: UAT primeiro; Produção só no GO formal
-- Pré-requisito: 056 (versão activa); BI2.u_prevId varchar(50) NULL
-- =============================================================================
-- PR2-A — Ao cancelar autorização no picking, limpar também u_prevId.
--   sp_HCA_picking_cancel
--   sp_HCA_marcar_pronta_picking (@pronta=0)
-- Não altera 1→66→65 (sem libertação nessas transições).
-- =============================================================================

SET NOCOUNT ON;
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
        u_prevId = NULL
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
            u_prevId = NULL
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
GO


/* ========== 55 / 074_alter_sp_HCA_prev_entrada_obter_consumo.sql ========== */
-- =============================================================================
-- Liliana & Seródio — Portal Logístico
-- Script: 074_alter_sp_HCA_prev_entrada_obter_consumo.sql
-- Ambiente: UAT primeiro; Produção só no GO formal
-- Pré-requisito: 065 (sp_HCA_prev_entrada_obter); BI2.u_previd varchar(50) NOT NULL
-- =============================================================================
-- PR2-B1 — Visibilidade Previsto / Alocado / Disponível no detalhe Admin.
--   Só leitura. Não altera teto, BI2, Lin, autorização, picking, dados.
--   Alocado = SUM(u_qtdaut) WHERE u_previd = P AND bi.ref = Ref (sem filtro ndos).
-- =============================================================================

SET NOCOUNT ON;
GO

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
    ) a
    WHERE l.PrevisaoId = @id
    ORDER BY LTRIM(RTRIM(l.Ref));
END;
GO
GO


/* ========== 56 / 075_alter_u_HcaPrevEntradaLin_cor.sql ========== */
-- =============================================================================
-- Liliana & Seródio — Portal Logístico
-- Script: 075_alter_u_HcaPrevEntradaLin_cor.sql
-- Ambiente: UAT primeiro; Produção só no GO formal
-- Pré-requisito: 062 (u_HcaPrevEntradaLin); limpeza fixtures PR2-A
-- =============================================================================
-- PR2-A2 — Previsão por Referência + Cor.
--   Cor varchar(100) NOT NULL DEFAULT '' (mesmo tipo/semântica de BI.u_cor).
--   Unicidade: (PrevisaoId, Ref, Cor). Remove UQ apenas (PrevisaoId, Ref).
-- =============================================================================

SET NOCOUNT ON;
SET XACT_ABORT ON;
GO

IF COL_LENGTH(N'dbo.u_HcaPrevEntradaLin', N'Cor') IS NULL
BEGIN
    ALTER TABLE dbo.u_HcaPrevEntradaLin
        ADD Cor varchar(100) NOT NULL
            CONSTRAINT DF_u_HcaPrevEntradaLin_Cor DEFAULT ('');
END;
GO

IF EXISTS (
    SELECT 1
    FROM sys.key_constraints
    WHERE name = N'UQ_u_HcaPrevEntradaLin_Ref'
      AND parent_object_id = OBJECT_ID(N'dbo.u_HcaPrevEntradaLin')
)
BEGIN
    ALTER TABLE dbo.u_HcaPrevEntradaLin
        DROP CONSTRAINT UQ_u_HcaPrevEntradaLin_Ref;
END;
GO

IF NOT EXISTS (
    SELECT 1
    FROM sys.key_constraints
    WHERE name = N'UQ_u_HcaPrevEntradaLin_RefCor'
      AND parent_object_id = OBJECT_ID(N'dbo.u_HcaPrevEntradaLin')
)
BEGIN
    ALTER TABLE dbo.u_HcaPrevEntradaLin
        ADD CONSTRAINT UQ_u_HcaPrevEntradaLin_RefCor UNIQUE (PrevisaoId, Ref, Cor);
END;
GO
GO


/* ========== 57 / 076_alter_sps_prev_entrada_ref_cor.sql ========== */
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
GO


/* ========== 58 / 076b_grant_sp_HCA_prev_entrada_ref_cor.sql ========== */
-- =============================================================================
-- Liliana & Seródio — Portal Logístico
-- Script: 076b_grant_sp_HCA_prev_entrada_ref_cor.sql
-- =============================================================================

SET NOCOUNT ON;

IF EXISTS (SELECT 1 FROM sys.database_principals WHERE name = N'portal_app')
BEGIN
    GRANT EXECUTE ON dbo.sp_HCA_prev_entrada_obter TO [portal_app];
    GRANT EXECUTE ON dbo.sp_HCA_prev_entrada_guardar TO [portal_app];
    GRANT EXECUTE ON dbo.sp_HCA_prev_entrada_sugerir_cores TO [portal_app];
    GRANT EXECUTE ON dbo.sp_HCA_atualizar_qtd_autorizada TO [portal_app];
    GRANT EXECUTE ON dbo.sp_HCA_alocacao_proporcional TO [portal_app];
END;
GO
GO


/* ========== 59 / 079_alter_sp_HCA_prev_entrada_criar_seed_linhas.sql ========== */
-- =============================================================================
-- Liliana & Seródio — Portal Logístico
-- Script: 079_alter_sp_HCA_prev_entrada_criar_seed_linhas.sql
-- Ambiente: UAT primeiro; Produção só no GO formal
-- Pré-requisito: 075 (Cor); 076 (obter/guardar Ref+Cor)
-- =============================================================================
-- Ao criar previsão: pré-preenche linhas (Ref + Cor) a partir de encomendas
-- abertas no período (ndos=1, fechada=0, dataobra no intervalo),
-- apenas artigos com STOBS.u_dispPort=1 e restante > 0.
-- QuantidadePrevista = 0 (operador preenche depois).
-- Semântica de Cor = BI.u_cor (exacta, sem TRIM).
-- =============================================================================

SET NOCOUNT ON;
GO

/* Filtered index IX_u_HcaPrevEntrada_Fechada requires these ON at CREATE time. */
SET ANSI_NULLS ON;
SET QUOTED_IDENTIFIER ON;
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

    BEGIN TRAN;

    IF EXISTS (
        SELECT 1
        FROM dbo.u_HcaPrevEntrada WITH (UPDLOCK, HOLDLOCK)
        WHERE Fechada = 0
    )
    BEGIN
        ROLLBACK;
        RAISERROR(N'Já existe uma previsão aberta. Feche-a antes de criar outra.', 16, 1);
        RETURN;
    END;

    IF EXISTS (
        SELECT 1
        FROM dbo.u_HcaPrevEntrada WITH (UPDLOCK, HOLDLOCK)
        WHERE DataInicio <= @dataFim
          AND DataFim >= @dataInicio
    )
    BEGIN
        ROLLBACK;
        RAISERROR(N'Já existe uma previsão com período sobreposto a estas datas.', 16, 1);
        RETURN;
    END;

    DECLARE @out TABLE (Id uniqueidentifier NOT NULL);

    INSERT INTO dbo.u_HcaPrevEntrada (
        DataInicio,
        DataFim,
        CriadoEm,
        CriadoPor,
        Fechada,
        FechadaEm,
        FechadaPor
    )
    OUTPUT inserted.Id INTO @out
    VALUES (
        @dataInicio,
        @dataFim,
        SYSUTCDATETIME(),
        LEFT(LTRIM(RTRIM(ISNULL(@usrlogin, N''))), 100),
        0,
        NULL,
        NULL
    );

    SELECT @id = Id FROM @out;

    /* Seed: Ref + Cor distintos das encomendas abertas no período. */
    INSERT INTO dbo.u_HcaPrevEntradaLin (PrevisaoId, Ref, Cor, QuantidadePrevista)
    SELECT DISTINCT
        @id,
        LEFT(LTRIM(RTRIM(bi.ref)), 18),
        bi.u_cor,
        CAST(0 AS numeric(16, 2))
    FROM dbo.bi bi WITH (NOLOCK)
    INNER JOIN dbo.bo bo WITH (NOLOCK)
        ON bo.bostamp COLLATE DATABASE_DEFAULT = bi.bostamp COLLATE DATABASE_DEFAULT
    LEFT JOIN dbo.bi2 bi2 WITH (NOLOCK)
        ON bi2.bi2stamp COLLATE DATABASE_DEFAULT = bi.bistamp COLLATE DATABASE_DEFAULT
    INNER JOIN dbo.stobs o WITH (NOLOCK)
        ON LTRIM(RTRIM(o.ref)) COLLATE DATABASE_DEFAULT
         = LTRIM(RTRIM(bi.ref)) COLLATE DATABASE_DEFAULT
    WHERE bo.ndos = 1
      AND ISNULL(bo.fechada, 0) = 0
      AND CAST(bo.dataobra AS date) >= @dataInicio
      AND CAST(bo.dataobra AS date) <= @dataFim
      AND CAST(ISNULL(o.u_dispPort, 0) AS bit) = 1
      AND LTRIM(RTRIM(ISNULL(bi.ref, ''))) <> ''
      AND (ISNULL(NULLIF(bi2.u_qttorig, 0), bi.qtt) - bi.qtt2) > 0;

    COMMIT TRAN;

    SELECT
        @id AS Id,
        @dataInicio AS DataInicio,
        @dataFim AS DataFim,
        CAST(0 AS bit) AS Fechada,
        CAST(NULL AS datetime2(0)) AS FechadaEm,
        CAST(N'' AS nvarchar(100)) AS FechadaPor;
END;
GO
GO


/* ========== 60 / 080_create_sp_HCA_prev_entrada_fechar.sql ========== */
-- =============================================================================
-- Liliana & Seródio — Portal Logístico
-- Script: 080_create_sp_HCA_prev_entrada_fechar.sql
-- Ambiente: UAT primeiro; Produção só no GO formal
-- Pré-requisito: 064 (Fechada); 076 (obter)
-- =============================================================================
-- Fecho simples da previsão aberta (sem transferência de u_prevId).
-- Autorizações já associadas mantêm u_prevId; novas autorizações passam
-- a exigir outra previsão aberta.
-- =============================================================================

SET NOCOUNT ON;
GO

SET ANSI_NULLS ON;
SET QUOTED_IDENTIFIER ON;
GO

CREATE OR ALTER PROCEDURE dbo.sp_HCA_prev_entrada_fechar
    @id       uniqueidentifier,
    @usrlogin nvarchar(100)
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    BEGIN TRAN;

    DECLARE @fechada bit;

    SELECT @fechada = Fechada
    FROM dbo.u_HcaPrevEntrada WITH (UPDLOCK, ROWLOCK)
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
        RAISERROR(N'A previsão já está fechada.', 16, 1);
        RETURN;
    END;

    UPDATE dbo.u_HcaPrevEntrada
    SET Fechada = 1,
        FechadaEm = SYSUTCDATETIME(),
        FechadaPor = LEFT(LTRIM(RTRIM(ISNULL(@usrlogin, N''))), 100),
        AlteradoEm = SYSUTCDATETIME(),
        AlteradoPor = LEFT(LTRIM(RTRIM(ISNULL(@usrlogin, N''))), 100)
    WHERE Id = @id;

    COMMIT TRAN;

    EXEC dbo.sp_HCA_prev_entrada_obter @id = @id;
END;
GO

IF EXISTS (SELECT 1 FROM sys.database_principals WHERE name = N'portal_app')
    GRANT EXECUTE ON dbo.sp_HCA_prev_entrada_fechar TO [portal_app];
GO
GO


/* ========== 61 / 081_create_sp_HCA_prev_entrada_atualizar_linhas.sql ========== */
-- =============================================================================
-- Liliana & Seródio — Portal Logístico
-- Script: 081_create_sp_HCA_prev_entrada_atualizar_linhas.sql
-- Ambiente: UAT primeiro; Produção só no GO formal
-- Pré-requisito: 075 (Cor); 076 (obter); 079 (seed na criação)
-- =============================================================================
-- Actualiza previsão ABERTA: adiciona Ref+Cor novos das encomendas abertas
-- no período da previsão. Linhas já existentes NÃO são alteradas
-- (quantidade prevista / cor / ref mantêm-se).
-- =============================================================================

SET NOCOUNT ON;
GO

SET ANSI_NULLS ON;
SET QUOTED_IDENTIFIER ON;
GO

CREATE OR ALTER PROCEDURE dbo.sp_HCA_prev_entrada_atualizar_linhas
    @id       uniqueidentifier,
    @usrlogin nvarchar(100)
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    BEGIN TRAN;

    DECLARE
        @fechada bit,
        @dataInicio date,
        @dataFim date,
        @adicionadas int = 0;

    SELECT
        @fechada = Fechada,
        @dataInicio = DataInicio,
        @dataFim = DataFim
    FROM dbo.u_HcaPrevEntrada WITH (UPDLOCK, ROWLOCK)
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
        RAISERROR(N'Previsão fechada: não pode ser actualizada.', 16, 1);
        RETURN;
    END;

    ;WITH candidatos AS (
        SELECT DISTINCT
            LEFT(LTRIM(RTRIM(bi.ref)), 18) AS Ref,
            ISNULL(bi.u_cor, '') AS Cor
        FROM dbo.bi bi WITH (NOLOCK)
        INNER JOIN dbo.bo bo WITH (NOLOCK)
            ON bo.bostamp COLLATE DATABASE_DEFAULT = bi.bostamp COLLATE DATABASE_DEFAULT
        LEFT JOIN dbo.bi2 bi2 WITH (NOLOCK)
            ON bi2.bi2stamp COLLATE DATABASE_DEFAULT = bi.bistamp COLLATE DATABASE_DEFAULT
        INNER JOIN dbo.stobs o WITH (NOLOCK)
            ON LTRIM(RTRIM(o.ref)) COLLATE DATABASE_DEFAULT
             = LTRIM(RTRIM(bi.ref)) COLLATE DATABASE_DEFAULT
        WHERE bo.ndos = 1
          AND ISNULL(bo.fechada, 0) = 0
          AND CAST(bo.dataobra AS date) >= @dataInicio
          AND CAST(bo.dataobra AS date) <= @dataFim
          AND CAST(ISNULL(o.u_dispPort, 0) AS bit) = 1
          AND LTRIM(RTRIM(ISNULL(bi.ref, ''))) <> ''
          AND (ISNULL(NULLIF(bi2.u_qttorig, 0), bi.qtt) - bi.qtt2) > 0
    )
    INSERT INTO dbo.u_HcaPrevEntradaLin (PrevisaoId, Ref, Cor, QuantidadePrevista)
    SELECT
        @id,
        c.Ref,
        c.Cor,
        CAST(0 AS numeric(16, 2))
    FROM candidatos c
    WHERE NOT EXISTS (
        SELECT 1
        FROM dbo.u_HcaPrevEntradaLin l WITH (UPDLOCK, HOLDLOCK)
        WHERE l.PrevisaoId = @id
          AND LTRIM(RTRIM(l.Ref)) COLLATE DATABASE_DEFAULT
              = c.Ref COLLATE DATABASE_DEFAULT
          AND l.Cor COLLATE DATABASE_DEFAULT = c.Cor COLLATE DATABASE_DEFAULT
    );

    SET @adicionadas = @@ROWCOUNT;

    UPDATE dbo.u_HcaPrevEntrada
    SET AlteradoEm = SYSUTCDATETIME(),
        AlteradoPor = LEFT(LTRIM(RTRIM(ISNULL(@usrlogin, N''))), 100)
    WHERE Id = @id;

    COMMIT TRAN;

    /* 1º RS: número de linhas novas (para mensagem UI). */
    SELECT @adicionadas AS LinhasAdicionadas;

    EXEC dbo.sp_HCA_prev_entrada_obter @id = @id;
END;
GO

IF EXISTS (SELECT 1 FROM sys.database_principals WHERE name = N'portal_app')
    GRANT EXECUTE ON dbo.sp_HCA_prev_entrada_atualizar_linhas TO [portal_app];
GO
GO


/* ========== 62 / 082_alter_sp_HCA_atualizar_qtd_autorizada_sem_teto_prev.sql ========== */
-- =============================================================================
-- Liliana & Seródio — Portal Logístico
-- Script: 082_alter_sp_HCA_atualizar_qtd_autorizada_sem_teto_prev.sql
-- Ambiente: UAT primeiro; Produção só no GO formal
-- Pré-requisito: 076 (Ref+Cor); 073 (u_prevId ''); previsão aberta
-- =============================================================================
-- PR3-C — Remover teto de previsão em sp_HCA_atualizar_qtd_autorizada.
--   Autorização pode exceder Previsto; Disponível = Previsto − Alocado pode ser < 0.
--   Mantém: previsão aberta, u_previd, Ref+Cor, limpeza u_previd='' se u_qtdaut=0,
--   bloqueio u_pickstat >= 1, auditoria. Sem MAX(0). Sem ST.stock.
--   Inclui também (inalterados face a 076) obter/guardar/cores/alocação proporcional.
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
    @permitir_acima_stock      bit = 0,  -- legado API; ignorado (PR3-C: sem teto de previsão)
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

    /* ---------- qty > 0: associar / manter previsão (PR3-C: sem teto de capacidade) ---------- */
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
    /* PR3-C: sem teto — (@alocado_outros + @quantidade_autorizada) pode exceder @previsto;
       stock_disponivel / disponivel_previsao no SELECT podem ser negativos. */

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
GO


/* ========== 63 / 083_create_sp_HCA_fechar_expedicao_dossier.sql ========== */
-- =============================================================================
-- Liliana & Seródio — Portal Logístico
-- Script: 083_create_sp_HCA_fechar_expedicao_dossier.sql
-- Ambiente: UAT / teste; Produção só no GO formal
-- =============================================================================
-- Fecho operacional de expedição (ndos=@serie_separacao, default 65):
--   BO.fechada = 1 e BI.fechada = 1 (todas as linhas do bostamp).
-- Não altera qtt/qtt2, não fatura, não cria documentos, não toca 66/1.
-- Exige documento aberto; se já fechado → erro (conflito).
-- NÃO altera sp_HCA_marcar_fecho_picking_dossier (048).
-- =============================================================================

CREATE OR ALTER PROCEDURE dbo.sp_HCA_fechar_expedicao_dossier
    @bostamp           varchar(25),
    @serie_separacao   int = 65,
    @usrlogin          varchar(100) = NULL
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    IF @bostamp IS NULL OR LTRIM(RTRIM(@bostamp)) = ''
    BEGIN
        RAISERROR(N'bostamp obrigatório.', 16, 1);
        RETURN;
    END;

    IF @serie_separacao IS NULL OR @serie_separacao <= 0
    BEGIN
        RAISERROR(N'serie_separacao inválida.', 16, 1);
        RETURN;
    END;

    DECLARE @agora datetime = GETDATE(),
            @usrdata date,
            @usrhora varchar(8),
            @usrinis_n varchar(3),
            @ja_fechada bit;

    SET @usrdata = CAST(@agora AS date);
    SET @usrhora = CONVERT(varchar(8), @agora, 108);
    SET @usrinis_n = LEFT(LTRIM(RTRIM(ISNULL(NULLIF(@usrlogin, ''), 'PRT'))), 3);

    BEGIN TRAN;

    IF NOT EXISTS (
        SELECT 1
        FROM dbo.bo bo WITH (UPDLOCK, ROWLOCK)
        WHERE bo.bostamp COLLATE DATABASE_DEFAULT = @bostamp COLLATE DATABASE_DEFAULT
          AND bo.ndos = @serie_separacao
    )
    BEGIN
        ROLLBACK;
        RAISERROR(N'Dossier de expedição não encontrado ou série inválida.', 16, 1);
        RETURN;
    END;

    SELECT @ja_fechada = CAST(ISNULL(bo.fechada, 0) AS bit)
    FROM dbo.bo bo WITH (UPDLOCK, ROWLOCK)
    WHERE bo.bostamp COLLATE DATABASE_DEFAULT = @bostamp COLLATE DATABASE_DEFAULT
      AND bo.ndos = @serie_separacao;

    IF ISNULL(@ja_fechada, 0) = 1
    BEGIN
        ROLLBACK;
        RAISERROR(N'Expedição já fechada.', 16, 1);
        RETURN;
    END;

    UPDATE dbo.bo
    SET
        fechada = 1,
        usrinis = @usrinis_n,
        usrdata = @usrdata,
        usrhora = @usrhora
    WHERE bostamp COLLATE DATABASE_DEFAULT = @bostamp COLLATE DATABASE_DEFAULT
      AND ndos = @serie_separacao
      AND ISNULL(fechada, 0) = 0;

    IF @@ROWCOUNT <> 1
    BEGIN
        ROLLBACK;
        RAISERROR(N'Expedição já fechada.', 16, 1);
        RETURN;
    END;

    UPDATE dbo.bi
    SET
        fechada = 1,
        usrinis = @usrinis_n,
        usrdata = @usrdata,
        usrhora = @usrhora
    WHERE bostamp COLLATE DATABASE_DEFAULT = @bostamp COLLATE DATABASE_DEFAULT;

    COMMIT;

    SELECT
        bo.bostamp,
        CAST(ISNULL(bo.fechada, 0) AS bit) AS fechada,
        bo.obrano,
        bo.ndos
    FROM dbo.bo bo WITH (NOLOCK)
    WHERE bo.bostamp COLLATE DATABASE_DEFAULT = @bostamp COLLATE DATABASE_DEFAULT;
END;
GO
GO


/* ========== 64 / 083b_grant_sp_HCA_fecho_reabrir_expedicao.sql ========== */
-- =============================================================================
-- Liliana & Seródio — Portal Logístico
-- Script: 083b_grant_sp_HCA_fecho_reabrir_expedicao.sql
-- =============================================================================
GRANT EXECUTE ON dbo.sp_HCA_fechar_expedicao_dossier TO [portal_app];
GO
GRANT EXECUTE ON dbo.sp_HCA_reabrir_expedicao_dossier TO [portal_app];
GO
GO


/* ========== 65 / 084_create_sp_HCA_reabrir_expedicao_dossier.sql ========== */
-- =============================================================================
-- Liliana & Seródio — Portal Logístico
-- Script: 084_create_sp_HCA_reabrir_expedicao_dossier.sql
-- Ambiente: UAT / teste; Produção só no GO formal
-- =============================================================================
-- Reabertura operacional de expedição (ndos=@serie_separacao, default 65):
--   BO.fechada = 0 e BI.fechada = 0 (todas as linhas do bostamp).
-- Mantém BO e BI consistentes após fecho operacional (083).
-- Não altera qtt/qtt2, não fatura, não cria documentos.
-- Exige documento fechado; se já aberto → erro (conflito).
-- NÃO altera sp_HCA_marcar_fecho_picking_dossier (048).
-- =============================================================================

CREATE OR ALTER PROCEDURE dbo.sp_HCA_reabrir_expedicao_dossier
    @bostamp           varchar(25),
    @serie_separacao   int = 65,
    @usrlogin          varchar(100) = NULL
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    IF @bostamp IS NULL OR LTRIM(RTRIM(@bostamp)) = ''
    BEGIN
        RAISERROR(N'bostamp obrigatório.', 16, 1);
        RETURN;
    END;

    IF @serie_separacao IS NULL OR @serie_separacao <= 0
    BEGIN
        RAISERROR(N'serie_separacao inválida.', 16, 1);
        RETURN;
    END;

    DECLARE @agora datetime = GETDATE(),
            @usrdata date,
            @usrhora varchar(8),
            @usrinis_n varchar(3),
            @ja_fechada bit;

    SET @usrdata = CAST(@agora AS date);
    SET @usrhora = CONVERT(varchar(8), @agora, 108);
    SET @usrinis_n = LEFT(LTRIM(RTRIM(ISNULL(NULLIF(@usrlogin, ''), 'PRT'))), 3);

    BEGIN TRAN;

    IF NOT EXISTS (
        SELECT 1
        FROM dbo.bo bo WITH (UPDLOCK, ROWLOCK)
        WHERE bo.bostamp COLLATE DATABASE_DEFAULT = @bostamp COLLATE DATABASE_DEFAULT
          AND bo.ndos = @serie_separacao
    )
    BEGIN
        ROLLBACK;
        RAISERROR(N'Dossier de expedição não encontrado ou série inválida.', 16, 1);
        RETURN;
    END;

    SELECT @ja_fechada = CAST(ISNULL(bo.fechada, 0) AS bit)
    FROM dbo.bo bo WITH (UPDLOCK, ROWLOCK)
    WHERE bo.bostamp COLLATE DATABASE_DEFAULT = @bostamp COLLATE DATABASE_DEFAULT
      AND bo.ndos = @serie_separacao;

    IF ISNULL(@ja_fechada, 0) = 0
    BEGIN
        ROLLBACK;
        RAISERROR(N'Expedição já aberta.', 16, 1);
        RETURN;
    END;

    UPDATE dbo.bo
    SET
        fechada = 0,
        usrinis = @usrinis_n,
        usrdata = @usrdata,
        usrhora = @usrhora
    WHERE bostamp COLLATE DATABASE_DEFAULT = @bostamp COLLATE DATABASE_DEFAULT
      AND ndos = @serie_separacao
      AND ISNULL(fechada, 0) = 1;

    IF @@ROWCOUNT <> 1
    BEGIN
        ROLLBACK;
        RAISERROR(N'Expedição já aberta.', 16, 1);
        RETURN;
    END;

    UPDATE dbo.bi
    SET
        fechada = 0,
        usrinis = @usrinis_n,
        usrdata = @usrdata,
        usrhora = @usrhora
    WHERE bostamp COLLATE DATABASE_DEFAULT = @bostamp COLLATE DATABASE_DEFAULT;

    COMMIT;

    SELECT
        bo.bostamp,
        CAST(ISNULL(bo.fechada, 0) AS bit) AS fechada,
        bo.obrano,
        bo.ndos
    FROM dbo.bo bo WITH (NOLOCK)
    WHERE bo.bostamp COLLATE DATABASE_DEFAULT = @bostamp COLLATE DATABASE_DEFAULT;
END;
GO
GO


/* ========== 66 / 085_alter_sp_HCA_prev_entrada_obter_perf.sql ========== */
-- =============================================================================
-- Liliana & Seródio — Portal Logístico
-- Script: 085_alter_sp_HCA_prev_entrada_obter_perf.sql
-- Ambiente: UAT / teste; Produção só no GO formal
-- Pré-requisito: 076 (obter Ref+Cor + consumo)
-- =============================================================================
-- Performance:
--   1) CTE/Alocado agregado uma vez (sem OUTER APPLY por linha)
--   2) Sem COLLATE em joins (colunas já SQL_Latin1_General_CP1_CI_AI)
--   3) #Alocado materializado — evita plano cacheado mau no JOIN bi/bi2
-- Semântica inalterada:
--   Alocado = SUM(BI2.u_qtdaut) WHERE u_previd=P AND BI.ref=Ref AND BI.u_cor=Cor
-- =============================================================================

SET NOCOUNT ON;
GO

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

    -- Colunas com collation das tabelas PHC (tempdb pode ser CI_AS)
    CREATE TABLE #Alocado (
        Ref varchar(18) COLLATE SQL_Latin1_General_CP1_CI_AI NOT NULL,
        Cor varchar(50) COLLATE SQL_Latin1_General_CP1_CI_AI NOT NULL,
        QuantidadeAlocada decimal(18, 3) NOT NULL
    );

    INSERT INTO #Alocado (Ref, Cor, QuantidadeAlocada)
    SELECT
        LTRIM(RTRIM(bi.ref)),
        bi.u_cor,
        SUM(ISNULL(bi2.u_qtdaut, 0))
    FROM dbo.bi2 bi2 WITH (NOLOCK)
    INNER JOIN dbo.bi bi WITH (NOLOCK)
        ON bi.bistamp = bi2.bi2stamp
    WHERE bi2.u_previd = @prevIdStr
    GROUP BY
        LTRIM(RTRIM(bi.ref)),
        bi.u_cor;

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
        ON st.ref = l.Ref
    LEFT JOIN #Alocado a
        ON a.Ref = LTRIM(RTRIM(l.Ref))
       AND a.Cor = l.Cor
    WHERE l.PrevisaoId = @id
    ORDER BY LTRIM(RTRIM(l.Ref)), l.Cor;

    DROP TABLE #Alocado;
END;
GO
GO


/* ========== 67 / 086_alter_picking_cancel_block_when_qtt66.sql ========== */
-- =============================================================================
-- Liliana & Seródio — Portal Logístico
-- Script: 086_alter_picking_cancel_block_when_qtt66.sql
-- Ambiente: UAT / teste; Produção só no GO formal
-- =============================================================================
-- REGRA B: se EXISTS linha com SUM(66.BI.qtt) > 0 (obistamp = bistamp; ndos=66;
-- sem filtro fechada/u_chkin), impedir:
--   sp_HCA_picking_cancel
--   sp_HCA_marcar_pronta_picking (@pronta=0)
-- =============================================================================

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

    -- REGRA B: quantidade já materializada em ndos=66.
    IF EXISTS (
        SELECT 1
        FROM dbo.bi bi1 WITH (UPDLOCK, ROWLOCK)
        WHERE bi1.bostamp COLLATE DATABASE_DEFAULT = @bostamp COLLATE DATABASE_DEFAULT
          AND ISNULL((
                SELECT SUM(ISNULL(bi66.qtt, 0))
                FROM dbo.bi bi66 WITH (NOLOCK)
                INNER JOIN dbo.bo bo66 WITH (NOLOCK)
                    ON bo66.bostamp COLLATE DATABASE_DEFAULT = bi66.bostamp COLLATE DATABASE_DEFAULT
                WHERE bo66.ndos = 66
                  AND bi66.obistamp COLLATE DATABASE_DEFAULT = bi1.bistamp COLLATE DATABASE_DEFAULT
            ), 0) > 0
    )
    BEGIN
        ROLLBACK;
        RAISERROR(N'Cancelar Picking bloqueado: já existe quantidade materializada em dossier de picking (ndos=66).', 16, 1);
        RETURN;
    END;

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

        -- REGRA B: quantidade já materializada em ndos=66.
        IF EXISTS (
            SELECT 1
            FROM dbo.bi bi1 WITH (UPDLOCK, ROWLOCK)
            WHERE bi1.bostamp COLLATE DATABASE_DEFAULT = @bostamp COLLATE DATABASE_DEFAULT
              AND ISNULL((
                    SELECT SUM(ISNULL(bi66.qtt, 0))
                    FROM dbo.bi bi66 WITH (NOLOCK)
                    INNER JOIN dbo.bo bo66 WITH (NOLOCK)
                        ON bo66.bostamp COLLATE DATABASE_DEFAULT = bi66.bostamp COLLATE DATABASE_DEFAULT
                    WHERE bo66.ndos = 66
                      AND bi66.obistamp COLLATE DATABASE_DEFAULT = bi1.bistamp COLLATE DATABASE_DEFAULT
                ), 0) > 0
        )
        BEGIN
            ROLLBACK;
            RAISERROR(N'Cancelar Picking bloqueado: já existe quantidade materializada em dossier de picking (ndos=66).', 16, 1);
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
GO
