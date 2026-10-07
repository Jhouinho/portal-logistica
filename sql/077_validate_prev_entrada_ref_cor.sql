-- =============================================================================
-- Liliana & Seródio — Portal Logístico
-- Script: 077_validate_prev_entrada_ref_cor.sql
-- Ambiente: UAT — bateria PR2-A2 isolamento por cor
-- Pré-requisito: 075+076 aplicados; fixtures PR2-A limpos
-- =============================================================================
-- Usa 1310 com duas cores: '' e Branco.
-- Fixture controlado: define temporariamente BI.u_cor='Branco' em E2
-- (valor real já existente no PHC para 1310 em docs fechados).
-- =============================================================================

SET NOCOUNT ON;
-- XACT_ABORT OFF: nested SP RAISERROR caught by TRY/CATCH must not doom the outer UAT txn
SET XACT_ABORT OFF;

DECLARE
    @prevId uniqueidentifier,
    @prevIdStr varchar(50),
    @e1 varchar(25) = 'ADM26090966142,662000002', -- 1310 / ''
    @e2 varchar(25) = 'ADM26092360813,618000002', -- 1310 → Branco (fixture)
    @e1_cor_orig varchar(100),
    @e2_cor_orig varchar(100),
    @usr varchar(100) = 'pr2a2.uat',
    @pass int = 0,
    @fail int = 0,
    @msg nvarchar(400),
    @aloc_blank numeric(16,2),
    @disp_blank numeric(16,2),
    @aloc_branco numeric(16,2),
    @disp_branco numeric(16,2),
    @qtdaut numeric(16,2),
    @prevIdBi2 varchar(50), -- distinct from @prevId (SQL Server CI)
    @ok bit;

PRINT N'=== PR2-A2 UAT Ref+Cor ===';

/* Snapshot cores originais */
SELECT @e1_cor_orig = u_cor FROM dbo.bi WHERE bistamp = @e1;
SELECT @e2_cor_orig = u_cor FROM dbo.bi WHERE bistamp = @e2;

IF @e1_cor_orig IS NULL OR @e2_cor_orig IS NULL
BEGIN
    RAISERROR(N'E1/E2 bistamps não encontrados — abortar UAT.', 16, 1);
    RETURN;
END;

BEGIN TRY
    /* Sem TRAN externa: sp_HCA_* faz ROLLBACK próprio e anularia fixtures UAT. */

    /* Fixture: E2 = Branco (valor real PHC); E1 permanece '' */
    UPDATE dbo.bi SET u_cor = '' WHERE bistamp = @e1;
    UPDATE dbo.bi SET u_cor = 'Branco' WHERE bistamp = @e2;

    /* Limpar auth residual */
    UPDATE dbo.bi2
    SET u_qtdaut = 0, u_prevId = '', u_qtdautur = '', u_qtdautdt = '19000101'
    WHERE bi2stamp IN (@e1, @e2);

    /* Criar previsão aberta com 1310/''=20 e 1310/Branco=30 */
    IF EXISTS (SELECT 1 FROM dbo.u_HcaPrevEntrada WHERE Fechada = 0)
    BEGIN
        RAISERROR(N'Já existe previsão aberta — limpar antes do UAT.', 16, 1);
    END;

    SET @prevId = NEWID();
    INSERT INTO dbo.u_HcaPrevEntrada (Id, DataInicio, DataFim, CriadoPor, Fechada)
    VALUES (@prevId, '2026-09-01', '2026-12-31', @usr, 0);

    INSERT INTO dbo.u_HcaPrevEntradaLin (PrevisaoId, Ref, Cor, QuantidadePrevista)
    VALUES
        (@prevId, '1310', '', 20),
        (@prevId, '1310', 'Branco', 30);

    SET @prevIdStr = CONVERT(varchar(50), @prevId);
    PRINT N'Previsão fixture: ' + @prevIdStr;

    /* ---- Teste A: autorizar 1310/'' → 5 ---- */
    BEGIN TRY
        EXEC dbo.sp_HCA_atualizar_qtd_autorizada
            @bistamp = @e1,
            @quantidade_autorizada = 5,
            @usrlogin = @usr;
        SET @ok = 1;
    END TRY
    BEGIN CATCH
        SET @ok = 0;
        SET @msg = ERROR_MESSAGE();
    END CATCH;

    SELECT
        @aloc_blank = SUM(CASE WHEN l.Cor = '' THEN ISNULL(a.q,0) ELSE 0 END),
        @disp_blank = SUM(CASE WHEN l.Cor = '' THEN l.QuantidadePrevista - ISNULL(a.q,0) ELSE 0 END),
        @aloc_branco = SUM(CASE WHEN l.Cor = 'Branco' THEN ISNULL(a.q,0) ELSE 0 END),
        @disp_branco = SUM(CASE WHEN l.Cor = 'Branco' THEN l.QuantidadePrevista - ISNULL(a.q,0) ELSE 0 END)
    FROM dbo.u_HcaPrevEntradaLin l
    OUTER APPLY (
        SELECT SUM(ISNULL(bi2.u_qtdaut,0)) AS q
        FROM dbo.bi2 bi2
        INNER JOIN dbo.bi bi ON bi.bistamp = bi2.bi2stamp
        WHERE bi2.u_prevId = @prevIdStr
          AND bi.ref = l.Ref AND bi.u_cor = l.Cor
    ) a
    WHERE l.PrevisaoId = @prevId;

    IF @ok = 1 AND @aloc_blank = 5 AND @disp_blank = 15 AND @aloc_branco = 0 AND @disp_branco = 30
    BEGIN PRINT N'PASS A — isolamento blank'; SET @pass += 1; END
    ELSE
    BEGIN PRINT N'FAIL A — blank aloc=' + CONVERT(nvarchar(20),@aloc_blank)
        + N' disp=' + CONVERT(nvarchar(20),@disp_blank)
        + N' branco aloc=' + CONVERT(nvarchar(20),@aloc_branco)
        + N' disp=' + CONVERT(nvarchar(20),@disp_branco)
        + ISNULL(N' err=' + @msg, N''); SET @fail += 1; END

    /* ---- Teste B: autorizar 1310/Branco → 10 ---- */
    BEGIN TRY
        EXEC dbo.sp_HCA_atualizar_qtd_autorizada
            @bistamp = @e2,
            @quantidade_autorizada = 10,
            @usrlogin = @usr;
        SET @ok = 1; SET @msg = NULL;
    END TRY
    BEGIN CATCH
        SET @ok = 0; SET @msg = ERROR_MESSAGE();
    END CATCH;

    SELECT
        @disp_blank = SUM(CASE WHEN l.Cor = '' THEN l.QuantidadePrevista - ISNULL(a.q,0) ELSE 0 END),
        @disp_branco = SUM(CASE WHEN l.Cor = 'Branco' THEN l.QuantidadePrevista - ISNULL(a.q,0) ELSE 0 END)
    FROM dbo.u_HcaPrevEntradaLin l
    OUTER APPLY (
        SELECT SUM(ISNULL(bi2.u_qtdaut,0)) AS q
        FROM dbo.bi2 bi2
        INNER JOIN dbo.bi bi ON bi.bistamp = bi2.bi2stamp
        WHERE bi2.u_prevId = @prevIdStr AND bi.ref = l.Ref AND bi.u_cor = l.Cor
    ) a
    WHERE l.PrevisaoId = @prevId;

    IF @ok = 1 AND @disp_blank = 15 AND @disp_branco = 20
    BEGIN PRINT N'PASS B — outra cor'; SET @pass += 1; END
    ELSE
    BEGIN PRINT N'FAIL B — disp blank=' + CONVERT(nvarchar(20),@disp_blank)
        + N' branco=' + CONVERT(nvarchar(20),@disp_branco)
        + ISNULL(N' err=' + @msg, N''); SET @fail += 1; END

    /* ---- Teste C: aumentar blank 5→8 ---- */
    BEGIN TRY
        EXEC dbo.sp_HCA_atualizar_qtd_autorizada
            @bistamp = @e1,
            @quantidade_autorizada = 8,
            @usrlogin = @usr;
        SET @ok = 1; SET @msg = NULL;
    END TRY
    BEGIN CATCH
        SET @ok = 0; SET @msg = ERROR_MESSAGE();
    END CATCH;

    SELECT
        @aloc_blank = SUM(CASE WHEN l.Cor = '' THEN ISNULL(a.q,0) ELSE 0 END),
        @disp_blank = SUM(CASE WHEN l.Cor = '' THEN l.QuantidadePrevista - ISNULL(a.q,0) ELSE 0 END),
        @aloc_branco = SUM(CASE WHEN l.Cor = 'Branco' THEN ISNULL(a.q,0) ELSE 0 END),
        @disp_branco = SUM(CASE WHEN l.Cor = 'Branco' THEN l.QuantidadePrevista - ISNULL(a.q,0) ELSE 0 END)
    FROM dbo.u_HcaPrevEntradaLin l
    OUTER APPLY (
        SELECT SUM(ISNULL(bi2.u_qtdaut,0)) AS q
        FROM dbo.bi2 bi2
        INNER JOIN dbo.bi bi ON bi.bistamp = bi2.bi2stamp
        WHERE bi2.u_prevId = @prevIdStr AND bi.ref = l.Ref AND bi.u_cor = l.Cor
    ) a
    WHERE l.PrevisaoId = @prevId;

    IF @ok = 1 AND @aloc_blank = 8 AND @disp_blank = 12 AND @aloc_branco = 10 AND @disp_branco = 20
    BEGIN PRINT N'PASS C — aumento'; SET @pass += 1; END
    ELSE
    BEGIN PRINT N'FAIL C'; SET @fail += 1; END

    /* ---- Teste D: reduzir Branco 10→6 ---- */
    BEGIN TRY
        EXEC dbo.sp_HCA_atualizar_qtd_autorizada
            @bistamp = @e2,
            @quantidade_autorizada = 6,
            @usrlogin = @usr;
        SET @ok = 1; SET @msg = NULL;
    END TRY
    BEGIN CATCH
        SET @ok = 0; SET @msg = ERROR_MESSAGE();
    END CATCH;

    SELECT
        @disp_blank = SUM(CASE WHEN l.Cor = '' THEN l.QuantidadePrevista - ISNULL(a.q,0) ELSE 0 END),
        @aloc_branco = SUM(CASE WHEN l.Cor = 'Branco' THEN ISNULL(a.q,0) ELSE 0 END),
        @disp_branco = SUM(CASE WHEN l.Cor = 'Branco' THEN l.QuantidadePrevista - ISNULL(a.q,0) ELSE 0 END)
    FROM dbo.u_HcaPrevEntradaLin l
    OUTER APPLY (
        SELECT SUM(ISNULL(bi2.u_qtdaut,0)) AS q
        FROM dbo.bi2 bi2
        INNER JOIN dbo.bi bi ON bi.bistamp = bi2.bi2stamp
        WHERE bi2.u_prevId = @prevIdStr AND bi.ref = l.Ref AND bi.u_cor = l.Cor
    ) a
    WHERE l.PrevisaoId = @prevId;

    IF @ok = 1 AND @aloc_branco = 6 AND @disp_branco = 24 AND @disp_blank = 12
    BEGIN PRINT N'PASS D — redução (blank inalterado)'; SET @pass += 1; END
    ELSE
    BEGIN PRINT N'FAIL D — branco aloc=' + CONVERT(nvarchar(20),@aloc_branco)
        + N' disp=' + CONVERT(nvarchar(20),@disp_branco)
        + N' blank disp=' + CONVERT(nvarchar(20),@disp_blank); SET @fail += 1; END

    /* ---- Teste E: zero em E2 ---- */
    BEGIN TRY
        EXEC dbo.sp_HCA_atualizar_qtd_autorizada
            @bistamp = @e2,
            @quantidade_autorizada = 0,
            @usrlogin = @usr;
        SET @ok = 1; SET @msg = NULL;
    END TRY
    BEGIN CATCH
        SET @ok = 0; SET @msg = ERROR_MESSAGE();
    END CATCH;

    SELECT @qtdaut = u_qtdaut, @prevIdBi2 = u_prevId FROM dbo.bi2 WHERE bi2stamp = @e2;
    SELECT @disp_branco = 30 - ISNULL(SUM(ISNULL(bi2.u_qtdaut,0)),0)
    FROM dbo.bi2 bi2
    INNER JOIN dbo.bi bi ON bi.bistamp = bi2.bi2stamp
    WHERE bi2.u_prevId = @prevIdStr AND bi.ref = '1310' AND bi.u_cor = 'Branco';

    IF @ok = 1 AND @qtdaut = 0 AND @prevIdBi2 = '' AND @disp_branco = 30
    BEGIN PRINT N'PASS E — zero limpa u_prevId'; SET @pass += 1; END
    ELSE
    BEGIN PRINT N'FAIL E — qtdaut=' + CONVERT(nvarchar(20),@qtdaut)
        + N' previd=[' + ISNULL(@prevIdBi2,N'NULL') + N'] dispBranco='
        + CONVERT(nvarchar(20),@disp_branco); SET @fail += 1; END

    /* ---- Teste F: insuficiência blank (previsto=20, auth actual=8 → pedir 21 > ceiling) ---- */
    BEGIN TRY
        EXEC dbo.sp_HCA_atualizar_qtd_autorizada
            @bistamp = @e1,
            @quantidade_autorizada = 21,
            @usrlogin = @usr;
        SET @ok = 0; -- deveria falhar
        SET @msg = N'aceitou indevidamente';
    END TRY
    BEGIN CATCH
        SET @ok = CASE WHEN ERROR_MESSAGE() LIKE N'%prevista insuficiente%' THEN 1 ELSE 0 END;
        SET @msg = ERROR_MESSAGE();
    END CATCH;

    IF @ok = 1
    BEGIN PRINT N'PASS F — insuficiência rejeitada'; SET @pass += 1; END
    ELSE
    BEGIN PRINT N'FAIL F — ' + ISNULL(@msg,N''); SET @fail += 1; END

    /* ---- Teste G: sem linha de previsão para Ref+Cor (usar cor inexistente) ---- */
    UPDATE dbo.bi SET u_cor = 'CorInexistenteUAT' WHERE bistamp = @e2;
    UPDATE dbo.bi2 SET u_qtdaut = 0, u_prevId = '', u_qtdautur = '', u_qtdautdt = '19000101'
    WHERE bi2stamp = @e2;

    BEGIN TRY
        EXEC dbo.sp_HCA_atualizar_qtd_autorizada
            @bistamp = @e2,
            @quantidade_autorizada = 1,
            @usrlogin = @usr;
        SET @ok = 0;
        SET @msg = N'aceitou indevidamente';
    END TRY
    BEGIN CATCH
        SET @ok = CASE WHEN ERROR_MESSAGE() LIKE N'%não tem quantidade prevista%' THEN 1 ELSE 0 END;
        SET @msg = ERROR_MESSAGE();
    END CATCH;

    IF @ok = 1
    BEGIN PRINT N'PASS G — sem previsão Ref+Cor'; SET @pass += 1; END
    ELSE
    BEGIN PRINT N'FAIL G — ' + ISNULL(@msg,N''); SET @fail += 1; END

    /* Cleanup fixtures UAT */
    UPDATE dbo.bi2
    SET u_qtdaut = 0, u_prevId = '', u_qtdautur = '', u_qtdautdt = '19000101'
    WHERE bi2stamp IN (@e1, @e2);

    UPDATE dbo.bi SET u_cor = @e1_cor_orig WHERE bistamp = @e1;
    UPDATE dbo.bi SET u_cor = @e2_cor_orig WHERE bistamp = @e2;

    DELETE FROM dbo.u_HcaPrevEntradaLin WHERE PrevisaoId = @prevId;
    DELETE FROM dbo.u_HcaPrevEntrada WHERE Id = @prevId;

END TRY
BEGIN CATCH
    PRINT N'ABORT UAT: ' + ERROR_MESSAGE();
    /* restauro + limpeza fora de txn */
    UPDATE dbo.bi2
    SET u_qtdaut = 0, u_prevId = '', u_qtdautur = '', u_qtdautdt = '19000101'
    WHERE bi2stamp IN (@e1, @e2);
    UPDATE dbo.bi SET u_cor = ISNULL(@e1_cor_orig, u_cor) WHERE bistamp = @e1;
    UPDATE dbo.bi SET u_cor = ISNULL(@e2_cor_orig, u_cor) WHERE bistamp = @e2;
    IF @prevId IS NOT NULL
    BEGIN
        DELETE FROM dbo.u_HcaPrevEntradaLin WHERE PrevisaoId = @prevId;
        DELETE FROM dbo.u_HcaPrevEntrada WHERE Id = @prevId;
    END;
    THROW;
END CATCH;

PRINT N'=== RESULTADO: PASS=' + CONVERT(nvarchar(10),@pass)
    + N' FAIL=' + CONVERT(nvarchar(10),@fail) + N' ===';

IF @fail > 0
    RAISERROR(N'UAT PR2-A2 com falhas.', 16, 1);
GO
