-- =============================================================================
-- Liliana & Seródio — Portal Logístico
-- Script: 023_validate_sp_HCA_atualizar_linha_qtt_preco.sql
-- Pré-requisito: 022 executado (versão sem etiliquido; total linha = ettdeb)
-- ATENÇÃO: altera dados — só UAT
-- =============================================================================

-- Linha piloto UAT (encomenda aberta D0394583)
DECLARE @bistamp varchar(25) = N'ADM26081061713,242000001';
DECLARE @usrinis varchar(3) = N'ADM';

-- Estado ANTES
SELECT bistamp, qtt, u_qttorig, edebito, u_prcorig, ettdeb, usrinis, usrdata, usrhora
FROM dbo.bi WITH (NOLOCK)
WHERE bistamp = @bistamp;

-- ---------------------------------------------------------------------------
-- TESTE RN-020: 1.ª alteração de quantidade
-- Esperado:
--   u_qttorig = 1.00 (era 0 → grava qtt anterior)
--   qtt = 1.00 (mantém ou altera)
--   ettdeb = qtt * edebito
-- ---------------------------------------------------------------------------
EXEC dbo.sp_HCA_atualizar_linha_qtt_preco
    @bistamp = @bistamp,
    @quantidade = 1.00,
    @preco = NULL,
    @usrinis = @usrinis,
    @qtt_anterior_esperado = 1.00,
    @preco_anterior_esperado = NULL;

SELECT bistamp, qtt, u_qttorig, edebito, u_prcorig, ettdeb, usrinis, usrdata, usrhora
FROM dbo.bi WITH (NOLOCK)
WHERE bistamp = @bistamp;
-- Esperado: u_qttorig = 1.00

-- ---------------------------------------------------------------------------
-- TESTE RN-021: 1.ª alteração de preço
-- Esperado:
--   u_prcorig = 20.00 (era 0 → grava edebito anterior)
--   edebito = 19.50
--   ettdeb = 1.00 * 19.50 = 19.50
-- ---------------------------------------------------------------------------
EXEC dbo.sp_HCA_atualizar_linha_qtt_preco
    @bistamp = @bistamp,
    @quantidade = NULL,
    @preco = 19.50,
    @usrinis = @usrinis,
    @qtt_anterior_esperado = NULL,
    @preco_anterior_esperado = 20.00;

SELECT bistamp, qtt, u_qttorig, edebito, u_prcorig, ettdeb, usrinis, usrdata, usrhora
FROM dbo.bi WITH (NOLOCK)
WHERE bistamp = @bistamp;
-- Esperado: u_prcorig = 20.00, edebito = 19.50, ettdeb = 19.50

-- BO usr* actualizado
SELECT bostamp, usrinis, usrdata, usrhora
FROM dbo.bo WITH (NOLOCK)
WHERE bostamp = (SELECT bostamp FROM dbo.bi WITH (NOLOCK) WHERE bistamp = @bistamp);

-- ---------------------------------------------------------------------------
-- REPOR (opcional) — preço 20.00; u_prcorig NÃO deve mudar (já <> 0)
-- ---------------------------------------------------------------------------
/*
EXEC dbo.sp_HCA_atualizar_linha_qtt_preco
    @bistamp = @bistamp,
    @quantidade = NULL,
    @preco = 20.00,
    @usrinis = @usrinis;

SELECT bistamp, qtt, u_qttorig, edebito, u_prcorig, ettdeb
FROM dbo.bi WITH (NOLOCK)
WHERE bistamp = @bistamp;
-- Esperado: edebito = 20, u_prcorig continua 20, ettdeb = 20
*/
GO
