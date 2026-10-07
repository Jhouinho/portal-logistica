-- =============================================================================
-- Liliana & Seródio — Portal Logístico
-- Script: 025_validate_sp_HCA_atualizar_qtd_autorizada.sql
-- Pré-requisito: 024 executado
-- ATENÇÃO: altera u_qtdaut* — só UAT
-- Artigo piloto D0394583 tem stock_disponivel = 0
-- =============================================================================

DECLARE @bistamp varchar(25) = N'ADM26081061713,242000001';
DECLARE @usrlogin varchar(100) = N'sa';

-- Estado ANTES
SELECT bistamp, ref, u_qtdaut, u_qtdautur, u_qtdautdt
FROM dbo.bi WITH (NOLOCK)
WHERE bistamp = @bistamp;

-- ---------------------------------------------------------------------------
-- TESTE 1: autorizar 0 com stock 0 — deve PASSAR e gravar ur/dt
-- Esperado: u_qtdaut = 0, u_qtdautur = 'sa', u_qtdautdt ≈ agora
-- ---------------------------------------------------------------------------
EXEC dbo.sp_HCA_atualizar_qtd_autorizada
    @bistamp = @bistamp,
    @quantidade_autorizada = 0,
    @usrlogin = @usrlogin,
    @valor_anterior_esperado = 0;

SELECT bistamp, ref, u_qtdaut, u_qtdautur, u_qtdautdt
FROM dbo.bi WITH (NOLOCK)
WHERE bistamp = @bistamp;

-- ---------------------------------------------------------------------------
-- TESTE 2: autorizar 1 com stock 0 — deve FALHAR (RAISERROR stock)
-- ---------------------------------------------------------------------------
BEGIN TRY
    EXEC dbo.sp_HCA_atualizar_qtd_autorizada
        @bistamp = @bistamp,
        @quantidade_autorizada = 1,
        @usrlogin = @usrlogin,
        @valor_anterior_esperado = 0;
    SELECT N'ERRO: esperava falha por stock' AS resultado_teste2;
END TRY
BEGIN CATCH
    SELECT
        N'OK — rejeitado por stock' AS resultado_teste2,
        ERROR_MESSAGE() AS mensagem;
END CATCH;

-- Confirmar que valores do teste 1 se mantêm
SELECT bistamp, ref, u_qtdaut, u_qtdautur, u_qtdautdt
FROM dbo.bi WITH (NOLOCK)
WHERE bistamp = @bistamp;
GO
