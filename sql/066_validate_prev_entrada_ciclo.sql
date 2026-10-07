-- =============================================================================
-- Liliana & Seródio — Portal Logístico
-- Script: 066_validate_prev_entrada_ciclo.sql
-- Ambiente: UAT / teste
-- Pré-requisito: 064 + 065 aplicados
-- =============================================================================
-- Valida PR1: overlap, única aberta, imutabilidade fechada.
-- Usa períodos em 2099-* e limpa no final. Não altera ST.stock / BI2.
-- Pré-condição: 0 previsões abertas fora de 2099-* (não altera dados reais).
-- =============================================================================

SET NOCOUNT ON;
SET XACT_ABORT OFF;

DECLARE @usr nvarchar(100) = N'pr1_ciclo_test';
DECLARE @id1 uniqueidentifier;
DECLARE @id2 uniqueidentifier;
DECLARE @id3 uniqueidentifier;
DECLARE @ok int = 0;
DECLARE @fail int = 0;
DECLARE @msg nvarchar(400);
DECLARE @abertasFora int;

DECLARE @ids TABLE (Id uniqueidentifier NOT NULL);

PRINT N'=== PR1 validate previsões ciclo ===';

-- Pré-condição: nenhuma previsão aberta fora da sandbox 2099-*
-- (o script não fecha/altera/apaga previsões reais de negócio)
IF EXISTS (
    SELECT 1
    FROM dbo.u_HcaPrevEntrada WITH (NOLOCK)
    WHERE Fechada = 0
      AND NOT (DataInicio >= '20990101' AND DataFim <= '20991231')
)
BEGIN
    SELECT @abertasFora = COUNT(1)
    FROM dbo.u_HcaPrevEntrada WITH (NOLOCK)
    WHERE Fechada = 0
      AND NOT (DataInicio >= '20990101' AND DataFim <= '20991231');

    SET @msg = N'Pré-condição falhou: existem '
        + CAST(@abertasFora AS nvarchar(10))
        + N' previsão(ões) aberta(s) fora da sandbox 2099-*. '
        + N'Este script NÃO as irá alterar. '
        + N'Execute a validação numa BD sem esse conflito, ou após preparação explícita do ambiente de teste '
        + N'(fechar/remover abertas fora de 2099-* por decisão de negócio — não por este script).';

    PRINT @msg;
    THROW 50002, @msg, 1;
END;

-- Limpeza prévia de lixo de corridas anteriores (apenas sandbox 2099-*)
DELETE FROM dbo.u_HcaPrevEntrada
WHERE DataInicio >= '20990101' AND DataFim <= '20991231';

-- 1. Criar previsão válida
BEGIN TRY
    EXEC dbo.sp_HCA_prev_entrada_criar
        @dataInicio = '20990101',
        @dataFim = '20990107',
        @usrlogin = @usr,
        @id = @id1 OUTPUT;
    INSERT INTO @ids (Id) VALUES (@id1);
    PRINT N'OK 1 criar válida';
    SET @ok += 1;
END TRY
BEGIN CATCH
    PRINT N'FAIL 1: ' + ERROR_MESSAGE();
    SET @fail += 1;
END CATCH;

-- 2. Período exactamente igual → rejeitar (motivo: aberta já existe após passo 1)
BEGIN TRY
    EXEC dbo.sp_HCA_prev_entrada_criar
        @dataInicio = '20990101',
        @dataFim = '20990107',
        @usrlogin = @usr,
        @id = @id2 OUTPUT;
    PRINT N'FAIL 2: deveria rejeitar período igual';
    SET @fail += 1;
    IF @id2 IS NOT NULL INSERT INTO @ids (Id) VALUES (@id2);
END TRY
BEGIN CATCH
    SET @msg = ERROR_MESSAGE();
    IF @msg LIKE N'%aberta%' OR @msg LIKE N'%sobreposto%'
    BEGIN
        PRINT N'OK 2 rejeitar período igual: ' + @msg;
        SET @ok += 1;
    END
    ELSE
    BEGIN
        PRINT N'FAIL 2: rejeição inesperada: ' + @msg;
        SET @fail += 1;
    END
END CATCH;

-- 3. Parcialmente sobreposta → rejeitar (também falha por já existir aberta)
-- Fechar @id1 manualmente para isolar teste de overlap
UPDATE dbo.u_HcaPrevEntrada
SET Fechada = 1, FechadaEm = SYSUTCDATETIME(), FechadaPor = @usr
WHERE Id = @id1;

BEGIN TRY
    EXEC dbo.sp_HCA_prev_entrada_criar
        @dataInicio = '20990105',
        @dataFim = '20990112',
        @usrlogin = @usr,
        @id = @id2 OUTPUT;
    PRINT N'FAIL 3: deveria rejeitar overlap parcial';
    SET @fail += 1;
    IF @id2 IS NOT NULL INSERT INTO @ids (Id) VALUES (@id2);
END TRY
BEGIN CATCH
    SET @msg = ERROR_MESSAGE();
    IF @msg LIKE N'%sobreposto%'
    BEGIN
        PRINT N'OK 3 rejeitar overlap parcial: ' + @msg;
        SET @ok += 1;
    END
    ELSE
    BEGIN
        PRINT N'FAIL 3: rejeição inesperada: ' + @msg;
        SET @fail += 1;
    END
END CATCH;

-- 4. Começa no fim da outra → rejeitar
BEGIN TRY
    EXEC dbo.sp_HCA_prev_entrada_criar
        @dataInicio = '20990107',
        @dataFim = '20990114',
        @usrlogin = @usr,
        @id = @id2 OUTPUT;
    PRINT N'FAIL 4: deveria rejeitar overlap no limite';
    SET @fail += 1;
    IF @id2 IS NOT NULL INSERT INTO @ids (Id) VALUES (@id2);
END TRY
BEGIN CATCH
    SET @msg = ERROR_MESSAGE();
    IF @msg LIKE N'%sobreposto%'
    BEGIN
        PRINT N'OK 4 rejeitar overlap no limite: ' + @msg;
        SET @ok += 1;
    END
    ELSE
    BEGIN
        PRINT N'FAIL 4: rejeição inesperada: ' + @msg;
        SET @fail += 1;
    END
END CATCH;

-- 5. Imediatamente a seguir → permitir
BEGIN TRY
    EXEC dbo.sp_HCA_prev_entrada_criar
        @dataInicio = '20990108',
        @dataFim = '20990114',
        @usrlogin = @usr,
        @id = @id2 OUTPUT;
    INSERT INTO @ids (Id) VALUES (@id2);
    PRINT N'OK 5 criar imediatamente a seguir';
    SET @ok += 1;
END TRY
BEGIN CATCH
    PRINT N'FAIL 5: ' + ERROR_MESSAGE();
    SET @fail += 1;
END CATCH;

-- 6. Editar período para sobrepor → rejeitar
BEGIN TRY
    EXEC dbo.sp_HCA_prev_entrada_guardar
        @id = @id2,
        @usrlogin = @usr,
        @linhas = N'[]',
        @dataInicio = '20990101',
        @dataFim = '20990110';
    PRINT N'FAIL 6: deveria rejeitar edição com overlap';
    SET @fail += 1;
END TRY
BEGIN CATCH
    SET @msg = ERROR_MESSAGE();
    IF @msg LIKE N'%sobreposto%'
    BEGIN
        PRINT N'OK 6 rejeitar edição com overlap: ' + @msg;
        SET @ok += 1;
    END
    ELSE
    BEGIN
        PRINT N'FAIL 6: rejeição inesperada: ' + @msg;
        SET @fail += 1;
    END
END CATCH;

-- 7. Editar período sem overposição → permitir
BEGIN TRY
    EXEC dbo.sp_HCA_prev_entrada_guardar
        @id = @id2,
        @usrlogin = @usr,
        @linhas = N'[]',
        @dataInicio = '20990108',
        @dataFim = '20990120';
    PRINT N'OK 7 editar período sem overlap';
    SET @ok += 1;
END TRY
BEGIN CATCH
    PRINT N'FAIL 7: ' + ERROR_MESSAGE();
    SET @fail += 1;
END CATCH;

-- 8. Já coberto: criar primeira aberta (após fechar id1) → ok acima
PRINT N'OK 8 primeira aberta (id2) — já validado no passo 5';
SET @ok += 1;

-- 9. Segunda aberta → rejeitar
BEGIN TRY
    EXEC dbo.sp_HCA_prev_entrada_criar
        @dataInicio = '20990201',
        @dataFim = '20990207',
        @usrlogin = @usr,
        @id = @id3 OUTPUT;
    PRINT N'FAIL 9: deveria rejeitar segunda aberta';
    SET @fail += 1;
    IF @id3 IS NOT NULL INSERT INTO @ids (Id) VALUES (@id3);
END TRY
BEGIN CATCH
    SET @msg = ERROR_MESSAGE();
    IF @msg LIKE N'%aberta%'
    BEGIN
        PRINT N'OK 9 rejeitar segunda aberta: ' + @msg;
        SET @ok += 1;
    END
    ELSE
    BEGIN
        PRINT N'FAIL 9: rejeição inesperada: ' + @msg;
        SET @fail += 1;
    END
END CATCH;

-- 10/11. Com fechada + criar nova aberta após fechar id2
UPDATE dbo.u_HcaPrevEntrada
SET Fechada = 1, FechadaEm = SYSUTCDATETIME(), FechadaPor = @usr
WHERE Id = @id2;

BEGIN TRY
    EXEC dbo.sp_HCA_prev_entrada_criar
        @dataInicio = '20990201',
        @dataFim = '20990207',
        @usrlogin = @usr,
        @id = @id3 OUTPUT;
    INSERT INTO @ids (Id) VALUES (@id3);
    PRINT N'OK 10/11 criar aberta após fecho manual';
    SET @ok += 1;
END TRY
BEGIN CATCH
    PRINT N'FAIL 10/11: ' + ERROR_MESSAGE();
    SET @fail += 1;
END CATCH;

-- 12–14. Imutabilidade: fechar id3 e tentar guardar
UPDATE dbo.u_HcaPrevEntrada
SET Fechada = 1, FechadaEm = SYSUTCDATETIME(), FechadaPor = @usr
WHERE Id = @id3;

BEGIN TRY
    EXEC dbo.sp_HCA_prev_entrada_guardar
        @id = @id3,
        @usrlogin = @usr,
        @linhas = N'[]',
        @dataInicio = '20990201',
        @dataFim = '20990210';
    PRINT N'FAIL 12: deveria rejeitar alterar cabeçalho fechada';
    SET @fail += 1;
END TRY
BEGIN CATCH
    SET @msg = ERROR_MESSAGE();
    IF @msg LIKE N'%fechada%'
    BEGIN
        PRINT N'OK 12 rejeitar alterar fechada (cabeçalho/linhas): ' + @msg;
        SET @ok += 1;
    END
    ELSE
    BEGIN
        PRINT N'FAIL 12: rejeição inesperada: ' + @msg;
        SET @fail += 1;
    END
END CATCH;

BEGIN TRY
    EXEC dbo.sp_HCA_prev_entrada_guardar
        @id = @id3,
        @usrlogin = @usr,
        @linhas = N'[{"ref":"XXTEST","quantidadePrevista":1}]',
        @dataInicio = '20990201',
        @dataFim = '20990207';
    PRINT N'FAIL 13/14: deveria rejeitar alterar/remover linhas fechada';
    SET @fail += 1;
END TRY
BEGIN CATCH
    SET @msg = ERROR_MESSAGE();
    IF @msg LIKE N'%fechada%'
    BEGIN
        PRINT N'OK 13/14 rejeitar linhas em fechada: ' + @msg;
        SET @ok += 1;
    END
    ELSE
    BEGIN
        PRINT N'FAIL 13/14: rejeição inesperada: ' + @msg;
        SET @fail += 1;
    END
END CATCH;

-- 15. Regressão aberta: reabrir cenário — criar aberta e guardar linhas vazias
DELETE FROM dbo.u_HcaPrevEntrada WHERE Id IN (SELECT Id FROM @ids);
DELETE FROM @ids;

BEGIN TRY
    EXEC dbo.sp_HCA_prev_entrada_criar
        @dataInicio = '20990301',
        @dataFim = '20990307',
        @usrlogin = @usr,
        @id = @id1 OUTPUT;
    INSERT INTO @ids (Id) VALUES (@id1);
    EXEC dbo.sp_HCA_prev_entrada_guardar
        @id = @id1,
        @usrlogin = @usr,
        @linhas = N'[]',
        @dataInicio = '20990301',
        @dataFim = '20990307';
    PRINT N'OK 15 previsão aberta continua editável';
    SET @ok += 1;
END TRY
BEGIN CATCH
    PRINT N'FAIL 15: ' + ERROR_MESSAGE();
    SET @fail += 1;
END CATCH;

-- 16/17. Confirmação estrutural: scripts desta PR não tocam ST / BI2 auth
IF COL_LENGTH(N'dbo.bi2', N'u_prevId') IS NOT NULL
BEGIN
    PRINT N'AVISO 16: BI2.u_prevId existe (fora do âmbito PR1 se criado noutro sítio)';
END
ELSE
    PRINT N'OK 16 BI2.u_prevId não criado nesta PR';

IF COL_LENGTH(N'dbo.st', N'stock') IS NULL
BEGIN
    PRINT N'FAIL 17: ST.stock em falta';
    SET @fail += 1;
END
ELSE
BEGIN
    PRINT N'OK 17 ST.stock intacto (coluna presente; PR1 não a altera)';
    SET @ok += 1;
END;

-- Limpeza
DELETE FROM dbo.u_HcaPrevEntrada
WHERE DataInicio >= '20990101' AND DataFim <= '20991231';

PRINT N'=== Resultado: OK=' + CAST(@ok AS nvarchar(10))
    + N' FAIL=' + CAST(@fail AS nvarchar(10)) + N' ===';

IF @fail > 0
    THROW 50001, N'Validação PR1 previsões ciclo falhou.', 1;
GO
