-- =============================================================================
-- Liliana & Seródio — Portal Mobile
-- Script: 091b_validate_sp_HCA_criar_pedido_mobile.sql
-- Ambiente: UAT APENAS — cria e (opcionalmente) remove documentos de teste ndos=67
-- NÃO altera o dossier Desktop de referência ADM26101553304,036000001
-- =============================================================================

SET NOCOUNT ON;
SET XACT_ABORT ON;

DECLARE @LimparTestes bit = 1;
DECLARE @RefBo varchar(25) = 'ADM26101553304,036000001';

IF OBJECT_ID(N'dbo.sp_HCA_criar_pedido_mobile', N'P') IS NULL
BEGIN
    RAISERROR(N'sp_HCA_criar_pedido_mobile inexistente — correr 091 primeiro.', 16, 1);
    RETURN;
END;

DECLARE @lin dbo.HCA_PedidoMobileLinhaType;
DECLARE @key varchar(64);
DECLARE @res TABLE
(
    alreadyExists bit,
    bostamp varchar(25),
    obrano numeric(10, 0),
    boano numeric(4, 0),
    ndos numeric(3, 0),
    nmdos varchar(24),
    etotaldeb numeric(19, 6),
    totaldeb numeric(18, 5),
    linhas int
);

PRINT N'==== A) uma linha (1911 / 1310) ====';
DELETE FROM @lin;
INSERT INTO @lin (linha_ord, ref, qtt, cor) VALUES (1, N'1310', 1, N'');
SET @key = CONCAT(N'UAT-MOB-A-', CONVERT(varchar(36), NEWID()));
DELETE FROM @res;
INSERT INTO @res EXEC dbo.sp_HCA_criar_pedido_mobile
    @no = 1911, @estab = 0, @Linhas = @lin, @IdempotencyKey = @key, @usrinis = N'TST';
SELECT N'A' AS caso, * FROM @res;

PRINT N'---- Comparação REF Desktop vs NOVO (preços) ----';
SELECT N'REF' AS origem, RTRIM(bo.bostamp) bostamp, bi.edebito, bi.debito, bi.ettdeb, bi.ttdeb,
       bi.iva, bi.tabiva, CAST(bi.ivaincl AS int) ivaincl, bo.etotaldeb, bo.totaldeb
FROM dbo.bo bo
JOIN dbo.bi bi ON bi.bostamp = bo.bostamp
WHERE RTRIM(bo.bostamp) = @RefBo
UNION ALL
SELECT N'NOVO', RTRIM(bo.bostamp), bi.edebito, bi.debito, bi.ettdeb, bi.ttdeb,
       bi.iva, bi.tabiva, CAST(bi.ivaincl AS int), bo.etotaldeb, bo.totaldeb
FROM dbo.bo bo
JOIN dbo.bi bi ON bi.bostamp = bo.bostamp
JOIN @res r ON RTRIM(r.bostamp) = RTRIM(bo.bostamp);

SELECT
    RTRIM(bo.bostamp) bostamp,
    CASE WHEN EXISTS (SELECT 1 FROM dbo.bo2 WHERE bo2stamp = bo.bostamp) THEN 1 ELSE 0 END AS has_bo2,
    CASE WHEN EXISTS (SELECT 1 FROM dbo.bo3 WHERE bo3stamp = bo.bostamp) THEN 1 ELSE 0 END AS has_bo3,
    (SELECT COUNT(*) FROM dbo.bi2 x JOIN dbo.bi y ON y.bistamp = x.bi2stamp WHERE y.bostamp = bo.bostamp) AS bi2_cnt,
    (SELECT COUNT(*) FROM dbo.sl s JOIN dbo.bi y ON y.bistamp = s.bistamp WHERE y.bostamp = bo.bostamp) AS sl_cnt,
    RTRIM(bi.obistamp) obistamp,
    RTRIM(bi.oobistamp) oobistamp
FROM dbo.bo bo
JOIN dbo.bi bi ON bi.bostamp = bo.bostamp
JOIN @res r ON RTRIM(r.bostamp) = RTRIM(bo.bostamp);

PRINT N'==== B) várias linhas ====';
DELETE FROM @lin;
INSERT INTO @lin (linha_ord, ref, qtt, cor) VALUES (1, N'1310', 2, N'Azul'), (2, N'1310', 1, N'Vermelha');
SET @key = CONCAT(N'UAT-MOB-B-', CONVERT(varchar(36), NEWID()));
DELETE FROM @res;
INSERT INTO @res EXEC dbo.sp_HCA_criar_pedido_mobile
    @no = 1911, @estab = 0, @Linhas = @lin, @IdempotencyKey = @key, @usrinis = N'TST';
SELECT N'B' AS caso, * FROM @res;
SELECT COUNT(*) AS linhas_gravadas FROM dbo.bi bi JOIN @res r ON bi.bostamp = r.bostamp;

PRINT N'==== C) cliente inválido (esperado ERRO) ====';
DELETE FROM @lin; INSERT INTO @lin (linha_ord, ref, qtt, cor) VALUES (1, N'1310', 1, N'');
SET @key = CONCAT(N'UAT-MOB-C-', CONVERT(varchar(36), NEWID()));
BEGIN TRY
    EXEC dbo.sp_HCA_criar_pedido_mobile @no = -999, @estab = 0, @Linhas = @lin, @IdempotencyKey = @key, @usrinis = N'TST';
    PRINT N'FALHA C: deveria ter falhado';
END TRY
BEGIN CATCH
    PRINT N'OK C: ' + ERROR_MESSAGE();
END CATCH

PRINT N'==== D) artigo inexistente (esperado ERRO) ====';
DELETE FROM @lin; INSERT INTO @lin (linha_ord, ref, qtt, cor) VALUES (1, N'@@@NOEXIST@@@', 1, N'');
SET @key = CONCAT(N'UAT-MOB-D-', CONVERT(varchar(36), NEWID()));
BEGIN TRY
    EXEC dbo.sp_HCA_criar_pedido_mobile @no = 1911, @estab = 0, @Linhas = @lin, @IdempotencyKey = @key, @usrinis = N'TST';
    PRINT N'FALHA D: deveria ter falhado';
END TRY
BEGIN CATCH
    PRINT N'OK D: ' + ERROR_MESSAGE();
END CATCH

PRINT N'==== E) quantidade inválida (esperado ERRO) ====';
DELETE FROM @lin; INSERT INTO @lin (linha_ord, ref, qtt, cor) VALUES (1, N'1310', 0, N'');
SET @key = CONCAT(N'UAT-MOB-E-', CONVERT(varchar(36), NEWID()));
BEGIN TRY
    EXEC dbo.sp_HCA_criar_pedido_mobile @no = 1911, @estab = 0, @Linhas = @lin, @IdempotencyKey = @key, @usrinis = N'TST';
    PRINT N'FALHA E: deveria ter falhado';
END TRY
BEGIN CATCH
    PRINT N'OK E: ' + ERROR_MESSAGE();
END CATCH

PRINT N'==== F) idempotência ====';
DELETE FROM @lin; INSERT INTO @lin (linha_ord, ref, qtt, cor) VALUES (1, N'1310', 1, N'');
SET @key = CONCAT(N'UAT-MOB-F-', CONVERT(varchar(36), NEWID()));
DECLARE @f1 TABLE (alreadyExists bit, bostamp varchar(25), obrano numeric(10,0), boano numeric(4,0), ndos numeric(3,0), nmdos varchar(24), etotaldeb numeric(19,6), totaldeb numeric(18,5), linhas int);
DECLARE @f2 TABLE (alreadyExists bit, bostamp varchar(25), obrano numeric(10,0), boano numeric(4,0), ndos numeric(3,0), nmdos varchar(24), etotaldeb numeric(19,6), totaldeb numeric(18,5), linhas int);
INSERT INTO @f1 EXEC dbo.sp_HCA_criar_pedido_mobile @no=1911,@estab=0,@Linhas=@lin,@IdempotencyKey=@key,@usrinis=N'TST';
INSERT INTO @f2 EXEC dbo.sp_HCA_criar_pedido_mobile @no=1911,@estab=0,@Linhas=@lin,@IdempotencyKey=@key,@usrinis=N'TST';
SELECT N'F1' passo, * FROM @f1
UNION ALL
SELECT N'F2', * FROM @f2;
IF (SELECT alreadyExists FROM @f1) = 0
   AND (SELECT alreadyExists FROM @f2) = 1
   AND (SELECT bostamp FROM @f1) = (SELECT bostamp FROM @f2)
    PRINT N'OK F';
ELSE
    PRINT N'FALHA F';

PRINT N'==== G) dois pedidos / obranos distintos ====';
DELETE FROM @lin; INSERT INTO @lin (linha_ord, ref, qtt, cor) VALUES (1, N'1310', 1, N'');
DECLARE @g TABLE (alreadyExists bit, bostamp varchar(25), obrano numeric(10,0), boano numeric(4,0), ndos numeric(3,0), nmdos varchar(24), etotaldeb numeric(19,6), totaldeb numeric(18,5), linhas int);
DECLARE @kg1 varchar(64) = CONCAT(N'UAT-MOB-G1-', CONVERT(varchar(36), NEWID()));
DECLARE @kg2 varchar(64) = CONCAT(N'UAT-MOB-G2-', CONVERT(varchar(36), NEWID()));
INSERT INTO @g EXEC dbo.sp_HCA_criar_pedido_mobile @no=1911,@estab=0,@Linhas=@lin,@IdempotencyKey=@kg1,@usrinis=N'TST';
INSERT INTO @g EXEC dbo.sp_HCA_criar_pedido_mobile @no=1911,@estab=0,@Linhas=@lin,@IdempotencyKey=@kg2,@usrinis=N'TST';
SELECT * FROM @g ORDER BY obrano;
IF (SELECT COUNT(DISTINCT obrano) FROM @g) = 2 AND (SELECT COUNT(DISTINCT bostamp) FROM @g) = 2
    PRINT N'OK G';
ELSE
    PRINT N'FALHA G';

IF @LimparTestes = 1
BEGIN
    PRINT N'==== Cleanup UAT-MOB-* (preserva ref Desktop) ====';
    DECLARE @bs char(25);
    DECLARE c CURSOR LOCAL FAST_FORWARD FOR
        SELECT bostamp
        FROM dbo.u_HcaPedidoMobileIdem
        WHERE IdempotencyKey LIKE N'UAT-MOB-%'
          AND RTRIM(bostamp) <> @RefBo;
    OPEN c;
    FETCH NEXT FROM c INTO @bs;
    WHILE @@FETCH_STATUS = 0
    BEGIN
        BEGIN TRY
            BEGIN TRAN;
            DELETE bi2 FROM dbo.bi2 bi2 INNER JOIN dbo.bi bi ON bi.bistamp = bi2.bi2stamp WHERE bi.bostamp = @bs;
            DELETE FROM dbo.bi  WHERE bostamp = @bs;
            DELETE FROM dbo.bo3 WHERE bo3stamp = @bs;
            DELETE FROM dbo.bo2 WHERE bo2stamp = @bs;
            DELETE FROM dbo.bo  WHERE bostamp = @bs;
            DELETE FROM dbo.u_HcaPedidoMobileIdem WHERE bostamp = @bs;
            COMMIT;
            PRINT N'Removido ' + RTRIM(@bs);
        END TRY
        BEGIN CATCH
            IF @@TRANCOUNT > 0 ROLLBACK;
            PRINT N'Cleanup falhou ' + RTRIM(@bs) + N': ' + ERROR_MESSAGE();
        END CATCH
        FETCH NEXT FROM c INTO @bs;
    END
    CLOSE c; DEALLOCATE c;
END

PRINT N'==== FIM 091b ====';
GO
