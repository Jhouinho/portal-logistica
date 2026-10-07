-- =============================================================================
-- Liliana & Seródio — Portal Logístico
-- Script: 090_seed_clone_encomendas_teste.sql
-- Ambiente: UAT / teste APENAS — NÃO correr em produção sem GO explícito
-- =============================================================================
-- Objectivo:
--   Criar N cópias de uma encomenda ndos=1 aberta (BO + BI + BI2 + BO2 + BO3),
--   com obrano a incrementar no boano corrente e stamps novos.
--
-- Limitações:
--   - Só documentos ndos=1 (não clona 66/65/Kapps).
--   - Não passa pelo PHC Desktop (sem pós-processamento nativo).
--   - Suficiente para listas/autorização/previsão no Portal.
--   - Reseta: fechada=0, u_pickrdy=0, u_qtdaut=0, u_previd=''.
--
-- Uso:
--   1) Ajustar @FonteObrano / @Quantidade / @DryRun
--   2) Executar no SSMS / sqlcmd contra a BD de teste
-- =============================================================================

SET NOCOUNT ON;
SET XACT_ABORT ON;

DECLARE @FonteObrano   int          = 28;      -- encomenda origem (ndos=1, aberta, ano corrente)
DECLARE @Quantidade    int          = 100;     -- quantas cópias
DECLARE @DryRun        bit          = 1;       -- 1 = só mostra o plano; 0 = grava (voltar a 1 após seed)
DECLARE @PrefixoStamp  char(3)      = 'TST';  -- prefixo dos stamps (fácil de apagar depois)
DECLARE @Ano           int          = YEAR(GETDATE());
DECLARE @UserInis      varchar(3)   = 'TST';

IF @Quantidade < 1 OR @Quantidade > 200
BEGIN
    RAISERROR('[@Quantidade] deve estar entre 1 e 200.', 16, 1);
    RETURN;
END;

DECLARE @FonteBoStamp char(25);
DECLARE @FonteBoAno   numeric(4, 0);

SELECT TOP (1)
    @FonteBoStamp = bo.bostamp,
    @FonteBoAno   = bo.boano
FROM dbo.bo bo
WHERE bo.ndos = 1
  AND bo.obrano = @FonteObrano
  AND bo.boano = @Ano
  AND ISNULL(bo.fechada, 0) = 0
ORDER BY bo.bostamp;

IF @FonteBoStamp IS NULL
BEGIN
    RAISERROR('Encomenda fonte não encontrada (ndos=1, obrano=%d, boano=%d, aberta).', 16, 1, @FonteObrano, @Ano);
    RETURN;
END;

DECLARE @MaxObrano int =
(
    SELECT ISNULL(MAX(bo.obrano), 0)
    FROM dbo.bo bo
    WHERE bo.ndos = 1
      AND bo.boano = @Ano
);

DECLARE @LinhasFonte int =
(
    SELECT COUNT(1) FROM dbo.bi bi WHERE bi.bostamp = @FonteBoStamp
);

PRINT CONCAT('Fonte: obrano=', @FonteObrano, ' bostamp=', RTRIM(@FonteBoStamp), ' linhas=', @LinhasFonte);
PRINT CONCAT('Próximo obrano base=', @MaxObrano + 1, ' · cópias=', @Quantidade, ' · DryRun=', @DryRun);

IF @LinhasFonte = 0
BEGIN
    RAISERROR('A encomenda fonte não tem linhas BI.', 16, 1);
    RETURN;
END;

/* ---- helpers: lista de colunas excepto stamps ---- */
DECLARE @colsBo  nvarchar(max);
DECLARE @colsBo2 nvarchar(max);
DECLARE @colsBo3 nvarchar(max);
DECLARE @colsBi  nvarchar(max);
DECLARE @colsBi2 nvarchar(max);

SELECT @colsBo = STRING_AGG(QUOTENAME(c.name), ',') WITHIN GROUP (ORDER BY c.column_id)
FROM sys.columns c
WHERE c.object_id = OBJECT_ID(N'dbo.bo')
  AND c.is_computed = 0 AND c.is_identity = 0
  AND c.name NOT IN (N'bostamp', N'obrano', N'fechada', N'rowid',
                     N'ousrdata', N'ousrhora', N'usrdata', N'usrhora', N'usrinis', N'ousrinis');

SELECT @colsBo2 = STRING_AGG(QUOTENAME(c.name), ',') WITHIN GROUP (ORDER BY c.column_id)
FROM sys.columns c
WHERE c.object_id = OBJECT_ID(N'dbo.bo2')
  AND c.is_computed = 0 AND c.is_identity = 0
  AND c.name NOT IN (N'bo2stamp', N'rowid');

-- Portal: picking/check-in em BO3 (u_pickrdy, u_chkin, …)
SELECT @colsBo3 = STRING_AGG(QUOTENAME(c.name), ',') WITHIN GROUP (ORDER BY c.column_id)
FROM sys.columns c
WHERE c.object_id = OBJECT_ID(N'dbo.bo3')
  AND c.is_computed = 0 AND c.is_identity = 0
  AND c.name NOT IN (N'bo3stamp', N'rowid', N'u_chkin', N'u_chkinur', N'u_chkindt',
                     N'u_pickrdy', N'u_pickrdr', N'u_pickrdt', N'u_pickstat', N'u_pickcobs',
                     N'usrdata', N'usrhora', N'usrinis');

SELECT @colsBi = STRING_AGG(QUOTENAME(c.name), ',') WITHIN GROUP (ORDER BY c.column_id)
FROM sys.columns c
WHERE c.object_id = OBJECT_ID(N'dbo.bi')
  AND c.is_computed = 0 AND c.is_identity = 0
  AND c.name NOT IN (N'bistamp', N'bostamp', N'obistamp', N'qtt2', N'rowid',
                     N'usrdata', N'usrhora', N'usrinis');

-- Autorização / previsão em BI2
SELECT @colsBi2 = STRING_AGG(QUOTENAME(c.name), ',') WITHIN GROUP (ORDER BY c.column_id)
FROM sys.columns c
WHERE c.object_id = OBJECT_ID(N'dbo.bi2')
  AND c.is_computed = 0 AND c.is_identity = 0
  AND c.name NOT IN (N'bi2stamp', N'rowid', N'u_previd', N'u_qtdaut', N'u_qtdautur', N'u_qtdautdt',
                     N'usrdata', N'usrhora', N'usrinis');

IF @colsBo IS NULL OR @colsBi IS NULL OR @colsBi2 IS NULL
BEGIN
    RAISERROR('Falha a montar listas de colunas.', 16, 1);
    RETURN;
END;

DECLARE @i int = 1;
DECLARE @novoObrano int;
DECLARE @novoBo char(25);
DECLARE @sql nvarchar(max);
DECLARE @map TABLE (oldBi char(25) NOT NULL PRIMARY KEY, newBi char(25) NOT NULL);

IF @DryRun = 1
BEGIN
    ;WITH n AS (
        SELECT 1 AS i
        UNION ALL
        SELECT i + 1 FROM n WHERE i < @Quantidade
    )
    SELECT
        @FonteObrano AS fonte_obrano,
        RTRIM(@FonteBoStamp) AS fonte_bostamp,
        @MaxObrano + i AS novo_obrano,
        @Ano AS boano,
        @LinhasFonte AS linhas_a_clonar,
        'DRY-RUN — nada gravado' AS nota
    FROM n
    OPTION (MAXRECURSION 200);
    RETURN;
END;

BEGIN TRAN;

BEGIN TRY
    WHILE @i <= @Quantidade
    BEGIN
        SET @novoObrano = @MaxObrano + @i;
        -- Stamp único estilo PHC (24 chars): TSTyyMMddHHmm + , + ss + seq3 + i3
        SET @novoBo = LEFT(
            @PrefixoStamp
            + FORMAT(GETDATE(), 'yyMMddHHmm')
            + ','
            + FORMAT(GETDATE(), 'ss')
            + RIGHT('000' + CAST(@i AS varchar(3)), 3)
            + RIGHT(REPLACE(CONVERT(varchar(36), NEWID()), '-', ''), 6),
            24);

        IF EXISTS (SELECT 1 FROM dbo.bo WHERE bostamp = @novoBo)
            OR EXISTS (SELECT 1 FROM dbo.bo WHERE ndos = 1 AND boano = @Ano AND obrano = @novoObrano)
        BEGIN
            RAISERROR('Colisão de stamp/obrano na cópia %d.', 16, 1, @i);
        END;

        DELETE FROM @map;

        -- Mapa bistamp antigos → novos
        INSERT INTO @map (oldBi, newBi)
        SELECT
            bi.bistamp,
            LEFT(
                @PrefixoStamp
                + FORMAT(GETDATE(), 'yyMMddHHmm')
                + ','
                + RIGHT(REPLACE(CONVERT(varchar(36), NEWID()), '-', ''), 11),
                24)
        FROM dbo.bi bi
        WHERE bi.bostamp = @FonteBoStamp;

        IF (SELECT COUNT(*) FROM @map) <> @LinhasFonte
        BEGIN
            RAISERROR('Mapa BI incompleto na cópia %d.', 16, 1, @i);
        END;

        -- BO
        SET @sql = N'
            INSERT INTO dbo.bo (bostamp, obrano, fechada, rowid,
                                ousrdata, ousrhora, usrdata, usrhora, usrinis, ousrinis, '
            + @colsBo + N')
            SELECT
                @novoBo, @novoObrano, 0, NEWID(),
                GETDATE(), CONVERT(varchar(8), GETDATE(), 108),
                GETDATE(), CONVERT(varchar(8), GETDATE(), 108),
                @UserInis, @UserInis, '
            + @colsBo + N'
            FROM dbo.bo WHERE bostamp = @fonte;';
        EXEC sp_executesql @sql,
            N'@novoBo char(25), @novoObrano int, @UserInis varchar(3), @fonte char(25)',
            @novoBo, @novoObrano, @UserInis, @FonteBoStamp;

        -- BO2
        IF EXISTS (SELECT 1 FROM dbo.bo2 WHERE bo2stamp = @FonteBoStamp)
        BEGIN
            SET @sql = N'
                INSERT INTO dbo.bo2 (bo2stamp, ' + @colsBo2 + N')
                SELECT @novoBo, ' + @colsBo2 + N'
                FROM dbo.bo2 WHERE bo2stamp = @fonte;';
            EXEC sp_executesql @sql,
                N'@novoBo char(25), @fonte char(25)',
                @novoBo, @FonteBoStamp;
        END;

        -- BO3 (sem picking / check-in)
        IF @colsBo3 IS NOT NULL AND EXISTS (SELECT 1 FROM dbo.bo3 WHERE bo3stamp = @FonteBoStamp)
        BEGIN
            SET @sql = N'
                INSERT INTO dbo.bo3 (bo3stamp, u_chkin, u_chkinur, u_chkindt,
                                     u_pickrdy, u_pickrdr, u_pickrdt, u_pickstat, u_pickcobs,
                                     usrdata, usrhora, usrinis, '
                + @colsBo3 + N')
                SELECT @novoBo, 0, '''', CAST(''19000101'' AS datetime),
                       0, '''', CAST(''19000101'' AS datetime), 0, '''',
                       GETDATE(), CONVERT(varchar(8), GETDATE(), 108), @UserInis, '
                + @colsBo3 + N'
                FROM dbo.bo3 WHERE bo3stamp = @fonte;';
            EXEC sp_executesql @sql,
                N'@novoBo char(25), @fonte char(25), @UserInis varchar(3)',
                @novoBo, @FonteBoStamp, @UserInis;
        END;

        IF OBJECT_ID('tempdb..#mapBi') IS NOT NULL DROP TABLE #mapBi;
        SELECT oldBi, newBi INTO #mapBi FROM @map;

        -- BI (qtt2=0)
        SET @sql = N'
            INSERT INTO dbo.bi (bistamp, bostamp, obistamp, qtt2, rowid,
                                usrdata, usrhora, usrinis, '
            + @colsBi + N')
            SELECT
                m.newBi, @novoBo, '''', 0, NEWID(),
                GETDATE(), CONVERT(varchar(8), GETDATE(), 108), @UserInis, '
            + @colsBi + N'
            FROM dbo.bi bi
            INNER JOIN #mapBi m ON m.oldBi = bi.bistamp
            WHERE bi.bostamp = @fonte;';
        EXEC sp_executesql @sql,
            N'@novoBo char(25), @UserInis varchar(3), @fonte char(25)',
            @novoBo, @UserInis, @FonteBoStamp;

        -- BI2 (sem autorização / sem previsão)
        SET @sql = N'
            INSERT INTO dbo.bi2 (bi2stamp, rowid, u_previd, u_qtdaut, u_qtdautur, u_qtdautdt,
                                 usrdata, usrhora, usrinis, '
            + @colsBi2 + N')
            SELECT m.newBi, NEWID(), '''', 0, '''', CAST(''19000101'' AS datetime),
                   GETDATE(), CONVERT(varchar(8), GETDATE(), 108), @UserInis, '
            + @colsBi2 + N'
            FROM dbo.bi2 bi2
            INNER JOIN #mapBi m ON m.oldBi = bi2.bi2stamp;';
        EXEC sp_executesql @sql,
            N'@UserInis varchar(3)',
            @UserInis;

        PRINT CONCAT('OK cópia ', @i, '/', @Quantidade, ' → obrano=', @novoObrano, ' bostamp=', RTRIM(@novoBo));

        SET @i += 1;
    END;

    COMMIT TRAN;
    PRINT 'Concluído.';
END TRY
BEGIN CATCH
    IF @@TRANCOUNT > 0 ROLLBACK TRAN;
    DECLARE @msg nvarchar(4000) = ERROR_MESSAGE();
    RAISERROR('Clone falhou: %s', 16, 1, @msg);
END CATCH;

-- Apagar clones de teste (quando quiseres):
-- DELETE bi2 FROM bi2 INNER JOIN bi ON bi.bistamp=bi2.bi2stamp INNER JOIN bo ON bo.bostamp=bi.bostamp WHERE bo.ndos=1 AND bo.bostamp LIKE 'TST%';
-- DELETE bi FROM bi INNER JOIN bo ON bo.bostamp=bi.bostamp WHERE bo.ndos=1 AND bo.bostamp LIKE 'TST%';
-- DELETE bo2 FROM bo2 INNER JOIN bo ON bo.bostamp=bo2.bo2stamp WHERE bo.ndos=1 AND bo.bostamp LIKE 'TST%';
-- DELETE bo3 FROM bo3 INNER JOIN bo ON bo.bostamp=bo3.bo3stamp WHERE bo.ndos=1 AND bo.bostamp LIKE 'TST%';
-- DELETE FROM bo WHERE ndos=1 AND bostamp LIKE 'TST%';
GO
