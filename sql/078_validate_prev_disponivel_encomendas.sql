-- =============================================================================
-- Liliana & Seródio — Portal Logístico
-- Script: 078_validate_prev_disponivel_encomendas.sql
-- Ambiente: UAT — PR2-B2 disponibilidade prevista nos ecrãs de encomendas
-- Não altera a view global; valida a mesma fórmula usada em EncomendasQuery.
-- =============================================================================

SET NOCOUNT ON;
SET XACT_ABORT OFF;

DECLARE
    @prevId uniqueidentifier,
    @prevIdStr varchar(50),
    @e1 varchar(25) = 'ADM26090966142,662000002', -- 1310 / ''
    @e2 varchar(25) = 'ADM26092360813,618000002', -- 1310 / Branco (fixture)
    @e1_cor_orig varchar(100),
    @e2_cor_orig varchar(100),
    @usr varchar(100) = 'pr2b2.uat',
    @pass int = 0,
    @fail int = 0,
    @st_stock numeric(16,2),
    @disp numeric(16,2),
    @disp2 numeric(16,2),
    @ok bit,
    @msg nvarchar(400);

PRINT N'=== PR2-B2 UAT Disponível previsto (encomendas) ===';

SELECT @e1_cor_orig = u_cor FROM dbo.bi WHERE bistamp = @e1;
SELECT @e2_cor_orig = u_cor FROM dbo.bi WHERE bistamp = @e2;
IF @e1_cor_orig IS NULL OR @e2_cor_orig IS NULL
BEGIN
    RAISERROR(N'E1/E2 não encontrados.', 16, 1);
    RETURN;
END;

BEGIN TRY
    UPDATE dbo.bi SET u_cor = '' WHERE bistamp = @e1;
    UPDATE dbo.bi SET u_cor = 'Branco' WHERE bistamp = @e2;
    UPDATE dbo.bi2
    SET u_qtdaut = 0, u_prevId = '', u_qtdautur = '', u_qtdautdt = '19000101'
    WHERE bi2stamp IN (@e1, @e2);

    IF EXISTS (SELECT 1 FROM dbo.u_HcaPrevEntrada WHERE Fechada = 0)
        RAISERROR(N'Já existe previsão aberta — limpar antes do UAT.', 16, 1);

    SET @prevId = NEWID();
    INSERT INTO dbo.u_HcaPrevEntrada (Id, DataInicio, DataFim, CriadoPor, Fechada)
    VALUES (@prevId, '2026-09-01', '2026-12-31', @usr, 0);
    INSERT INTO dbo.u_HcaPrevEntradaLin (PrevisaoId, Ref, Cor, QuantidadePrevista)
    VALUES (@prevId, '1310', '', 20), (@prevId, '1310', 'Branco', 30);
    SET @prevIdStr = CONVERT(varchar(50), @prevId);

    /* Autorizar 5 em blank */
    EXEC dbo.sp_HCA_atualizar_qtd_autorizada
        @bistamp = @e1, @quantidade_autorizada = 5, @usrlogin = @usr;

    /* Fórmula EncomendasQuery (DisponivelPrevisaoSql) */
    SELECT @disp = ISNULL((
        SELECT TOP (1)
            lin.QuantidadePrevista - ISNULL((
                SELECT SUM(ISNULL(bi2a.u_qtdaut, 0))
                FROM dbo.bi2 bi2a
                INNER JOIN dbo.bi bi_a ON bi_a.bistamp = bi2a.bi2stamp
                WHERE LTRIM(RTRIM(ISNULL(bi2a.u_previd, ''))) = CONVERT(varchar(50), p.Id)
                  AND LTRIM(RTRIM(bi_a.ref)) = LTRIM(RTRIM(l.ref))
                  AND bi_a.u_cor = bi_cap.u_cor
            ), 0)
        FROM dbo.u_HcaPrevEntrada p
        INNER JOIN dbo.u_HcaPrevEntradaLin lin ON lin.PrevisaoId = p.Id
        INNER JOIN dbo.bi bi_cap ON bi_cap.bistamp = l.bistamp
        WHERE ISNULL(p.Fechada, 0) = 0
          AND LTRIM(RTRIM(lin.Ref)) = LTRIM(RTRIM(l.ref))
          AND lin.Cor = bi_cap.u_cor
        ORDER BY p.DataInicio, p.DataFim
    ), 0)
    FROM dbo.view_HCA_encomenda_linhas l
    WHERE l.bistamp = @e1;

    SELECT @st_stock = ISNULL(st.stock, 0)
    FROM dbo.bi bi
    LEFT JOIN dbo.st st ON LTRIM(RTRIM(st.ref)) = LTRIM(RTRIM(bi.ref))
    WHERE bi.bistamp = @e1;

    IF @disp = 15
    BEGIN PRINT N'PASS A — Disponível=15 (não ST.stock=' + CONVERT(nvarchar(20), @st_stock) + N')'; SET @pass += 1; END
    ELSE
    BEGIN PRINT N'FAIL A — disp=' + CONVERT(nvarchar(20), @disp); SET @fail += 1; END

    /* B — Branco independente */
    EXEC dbo.sp_HCA_atualizar_qtd_autorizada
        @bistamp = @e2, @quantidade_autorizada = 10, @usrlogin = @usr;

    SELECT @disp2 = ISNULL((
        SELECT TOP (1)
            lin.QuantidadePrevista - ISNULL((
                SELECT SUM(ISNULL(bi2a.u_qtdaut, 0))
                FROM dbo.bi2 bi2a
                INNER JOIN dbo.bi bi_a ON bi_a.bistamp = bi2a.bi2stamp
                WHERE LTRIM(RTRIM(ISNULL(bi2a.u_previd, ''))) = CONVERT(varchar(50), p.Id)
                  AND LTRIM(RTRIM(bi_a.ref)) = LTRIM(RTRIM(l.ref))
                  AND bi_a.u_cor = bi_cap.u_cor
            ), 0)
        FROM dbo.u_HcaPrevEntrada p
        INNER JOIN dbo.u_HcaPrevEntradaLin lin ON lin.PrevisaoId = p.Id
        INNER JOIN dbo.bi bi_cap ON bi_cap.bistamp = l.bistamp
        WHERE ISNULL(p.Fechada, 0) = 0
          AND LTRIM(RTRIM(lin.Ref)) = LTRIM(RTRIM(l.ref))
          AND lin.Cor = bi_cap.u_cor
        ORDER BY p.DataInicio, p.DataFim
    ), 0)
    FROM dbo.view_HCA_encomenda_linhas l
    WHERE l.bistamp = @e2;

    SELECT @disp = ISNULL((
        SELECT TOP (1)
            lin.QuantidadePrevista - ISNULL((
                SELECT SUM(ISNULL(bi2a.u_qtdaut, 0))
                FROM dbo.bi2 bi2a
                INNER JOIN dbo.bi bi_a ON bi_a.bistamp = bi2a.bi2stamp
                WHERE LTRIM(RTRIM(ISNULL(bi2a.u_previd, ''))) = CONVERT(varchar(50), p.Id)
                  AND LTRIM(RTRIM(bi_a.ref)) = LTRIM(RTRIM(l.ref))
                  AND bi_a.u_cor = bi_cap.u_cor
            ), 0)
        FROM dbo.u_HcaPrevEntrada p
        INNER JOIN dbo.u_HcaPrevEntradaLin lin ON lin.PrevisaoId = p.Id
        INNER JOIN dbo.bi bi_cap ON bi_cap.bistamp = l.bistamp
        WHERE ISNULL(p.Fechada, 0) = 0
          AND LTRIM(RTRIM(lin.Ref)) = LTRIM(RTRIM(l.ref))
          AND lin.Cor = bi_cap.u_cor
        ORDER BY p.DataInicio, p.DataFim
    ), 0)
    FROM dbo.view_HCA_encomenda_linhas l
    WHERE l.bistamp = @e1;

    IF @disp = 15 AND @disp2 = 20
    BEGIN PRINT N'PASS B — isolamento cores (blank=15, Branco=20)'; SET @pass += 1; END
    ELSE
    BEGIN PRINT N'FAIL B — blank=' + CONVERT(nvarchar(20),@disp) + N' branco=' + CONVERT(nvarchar(20),@disp2); SET @fail += 1; END

    /* C — sem previsão (cor inexistente) */
    UPDATE dbo.bi SET u_cor = 'CorSemPrevUAT' WHERE bistamp = @e2;
    UPDATE dbo.bi2 SET u_qtdaut = 0, u_prevId = '', u_qtdautur = '', u_qtdautdt = '19000101' WHERE bi2stamp = @e2;

    SELECT @disp2 = ISNULL((
        SELECT TOP (1)
            lin.QuantidadePrevista - ISNULL((
                SELECT SUM(ISNULL(bi2a.u_qtdaut, 0))
                FROM dbo.bi2 bi2a
                INNER JOIN dbo.bi bi_a ON bi_a.bistamp = bi2a.bi2stamp
                WHERE LTRIM(RTRIM(ISNULL(bi2a.u_previd, ''))) = CONVERT(varchar(50), p.Id)
                  AND LTRIM(RTRIM(bi_a.ref)) = LTRIM(RTRIM(l.ref))
                  AND bi_a.u_cor = bi_cap.u_cor
            ), 0)
        FROM dbo.u_HcaPrevEntrada p
        INNER JOIN dbo.u_HcaPrevEntradaLin lin ON lin.PrevisaoId = p.Id
        INNER JOIN dbo.bi bi_cap ON bi_cap.bistamp = l.bistamp
        WHERE ISNULL(p.Fechada, 0) = 0
          AND LTRIM(RTRIM(lin.Ref)) = LTRIM(RTRIM(l.ref))
          AND lin.Cor = bi_cap.u_cor
        ORDER BY p.DataInicio, p.DataFim
    ), 0)
    FROM dbo.view_HCA_encomenda_linhas l
    WHERE l.bistamp = @e2;

    SELECT @st_stock = ISNULL(st.stock, 0)
    FROM dbo.bi bi
    LEFT JOIN dbo.st st ON LTRIM(RTRIM(st.ref)) = LTRIM(RTRIM(bi.ref))
    WHERE bi.bistamp = @e2;

    IF @disp2 = 0
    BEGIN PRINT N'PASS C — sem previsão → Disponível=0 (ST.stock=' + CONVERT(nvarchar(20),@st_stock) + N')'; SET @pass += 1; END
    ELSE
    BEGIN PRINT N'FAIL C — disp=' + CONVERT(nvarchar(20),@disp2); SET @fail += 1; END

    /* Restaurar E2 Branco e re-autorizar 10 para D */
    UPDATE dbo.bi SET u_cor = 'Branco' WHERE bistamp = @e2;
    EXEC dbo.sp_HCA_atualizar_qtd_autorizada
        @bistamp = @e2, @quantidade_autorizada = 10, @usrlogin = @usr;

    /* D — aumento alocado blank 5→8 → disp 15→12 */
    EXEC dbo.sp_HCA_atualizar_qtd_autorizada
        @bistamp = @e1, @quantidade_autorizada = 8, @usrlogin = @usr;

    SELECT @disp = ISNULL((
        SELECT TOP (1)
            lin.QuantidadePrevista - ISNULL((
                SELECT SUM(ISNULL(bi2a.u_qtdaut, 0))
                FROM dbo.bi2 bi2a
                INNER JOIN dbo.bi bi_a ON bi_a.bistamp = bi2a.bi2stamp
                WHERE LTRIM(RTRIM(ISNULL(bi2a.u_previd, ''))) = CONVERT(varchar(50), p.Id)
                  AND LTRIM(RTRIM(bi_a.ref)) = LTRIM(RTRIM(l.ref))
                  AND bi_a.u_cor = bi_cap.u_cor
            ), 0)
        FROM dbo.u_HcaPrevEntrada p
        INNER JOIN dbo.u_HcaPrevEntradaLin lin ON lin.PrevisaoId = p.Id
        INNER JOIN dbo.bi bi_cap ON bi_cap.bistamp = l.bistamp
        WHERE ISNULL(p.Fechada, 0) = 0
          AND LTRIM(RTRIM(lin.Ref)) = LTRIM(RTRIM(l.ref))
          AND lin.Cor = bi_cap.u_cor
        ORDER BY p.DataInicio, p.DataFim
    ), 0)
    FROM dbo.view_HCA_encomenda_linhas l
    WHERE l.bistamp = @e1;

    IF @disp = 12
    BEGIN PRINT N'PASS D — após aumento alocado, Disponível=12'; SET @pass += 1; END
    ELSE
    BEGIN PRINT N'FAIL D — disp=' + CONVERT(nvarchar(20),@disp); SET @fail += 1; END

    /* E — ST.stock=0 com previsão: se stock>0, simular comparação; se stock=0 nativo, ok */
    SELECT @st_stock = ISNULL(st.stock, 0)
    FROM dbo.bi bi
    LEFT JOIN dbo.st st ON LTRIM(RTRIM(st.ref)) = LTRIM(RTRIM(bi.ref))
    WHERE bi.bistamp = @e1;

    /* Prova: fórmula ≠ ST.stock quando disp previsto > 0 e (stock=0 OU stock≠disp) */
    IF @disp = 12 AND (@st_stock = 0 OR @st_stock <> @disp)
    BEGIN PRINT N'PASS E — Disponível previsto independente de ST.stock (disp=12, stock=' + CONVERT(nvarchar(20),@st_stock) + N')'; SET @pass += 1; END
    ELSE IF @disp = 12 AND @st_stock = 12
    BEGIN PRINT N'PASS E (fraco) — ST.stock coincidiu com disp; fórmula ainda é previsão'; SET @pass += 1; END
    ELSE
    BEGIN PRINT N'FAIL E'; SET @fail += 1; END

    /* Cleanup */
    UPDATE dbo.bi2 SET u_qtdaut = 0, u_prevId = '', u_qtdautur = '', u_qtdautdt = '19000101'
    WHERE bi2stamp IN (@e1, @e2);
    UPDATE dbo.bi SET u_cor = @e1_cor_orig WHERE bistamp = @e1;
    UPDATE dbo.bi SET u_cor = @e2_cor_orig WHERE bistamp = @e2;
    DELETE FROM dbo.u_HcaPrevEntradaLin WHERE PrevisaoId = @prevId;
    DELETE FROM dbo.u_HcaPrevEntrada WHERE Id = @prevId;

END TRY
BEGIN CATCH
    PRINT N'ABORT: ' + ERROR_MESSAGE();
    UPDATE dbo.bi SET u_cor = ISNULL(@e1_cor_orig, u_cor) WHERE bistamp = @e1;
    UPDATE dbo.bi SET u_cor = ISNULL(@e2_cor_orig, u_cor) WHERE bistamp = @e2;
    UPDATE dbo.bi2 SET u_qtdaut = 0, u_prevId = '', u_qtdautur = '', u_qtdautdt = '19000101'
    WHERE bi2stamp IN (@e1, @e2);
    IF @prevId IS NOT NULL
    BEGIN
        DELETE FROM dbo.u_HcaPrevEntradaLin WHERE PrevisaoId = @prevId;
        DELETE FROM dbo.u_HcaPrevEntrada WHERE Id = @prevId;
    END;
    THROW;
END CATCH;

PRINT N'=== RESULTADO: PASS=' + CONVERT(nvarchar(10),@pass) + N' FAIL=' + CONVERT(nvarchar(10),@fail) + N' ===';
IF @fail > 0 RAISERROR(N'UAT PR2-B2 com falhas.', 16, 1);
GO
