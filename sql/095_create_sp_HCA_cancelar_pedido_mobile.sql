-- =============================================================================
-- Liliana & Seródio — Portal Mobile
-- Script: 095_create_sp_HCA_cancelar_pedido_mobile.sql
-- Pré-requisito: 094_create_u_HcaPedidoMobileCancel.sql
-- =============================================================================
-- Cancela pedido mobile (ndos configurável, tipicamente 67):
--   1) INSERT u_HcaPedidoMobileCancel (histórico portal)
--   2) BO.fechada = 1  (+ BI.fechada = 1 nas linhas)
-- Não apaga BO/BI. Idempotente se já cancelado/fechado → erro controlado.
-- =============================================================================

SET NOCOUNT ON;
SET XACT_ABORT ON;
GO

CREATE OR ALTER PROCEDURE dbo.sp_HCA_cancelar_pedido_mobile
    @bostamp  varchar(25),
    @no       numeric(10, 0),
    @estab    numeric(3, 0),
    @ndos     numeric(5, 0) = 67,
    @motivo   nvarchar(200) = N'Cancelado pelo cliente no Portal Mobile',
    @usrinis  varchar(3) = N'MOB'
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    IF @bostamp IS NULL OR LTRIM(RTRIM(@bostamp)) = ''
    BEGIN RAISERROR(N'bostamp obrigatório.', 16, 1); RETURN; END;

    DECLARE @bs varchar(25) = LTRIM(RTRIM(@bostamp));
    DECLARE @agora datetime = GETDATE();
    DECLARE @usrdata datetime = CAST(@agora AS date);
    DECLARE @usrhora varchar(8) = CONVERT(varchar(8), @agora, 108);
    DECLARE @usr varchar(3) = LEFT(LTRIM(RTRIM(ISNULL(NULLIF(@usrinis, ''), N'MOB'))), 3);
    DECLARE @mot nvarchar(200) = LEFT(LTRIM(RTRIM(ISNULL(@motivo, N''))), 200);
    IF @mot = N'' SET @mot = N'Cancelado pelo cliente no Portal Mobile';

    BEGIN TRAN;

    IF NOT EXISTS (
        SELECT 1
        FROM dbo.bo bo WITH (UPDLOCK, ROWLOCK)
        WHERE RTRIM(bo.bostamp) = @bs
          AND bo.ndos = @ndos
          AND bo.no = @no
          AND bo.estab = @estab
    )
    BEGIN
        ROLLBACK;
        RAISERROR(N'Pedido mobile não encontrado.', 16, 1);
        RETURN;
    END;

    IF EXISTS (
        SELECT 1 FROM dbo.u_HcaPedidoMobileCancel WITH (UPDLOCK, ROWLOCK)
        WHERE RTRIM(bostamp) = @bs
    )
    BEGIN
        ROLLBACK;
        RAISERROR(N'Pedido já cancelado.', 16, 1);
        RETURN;
    END;

    IF EXISTS (
        SELECT 1 FROM dbo.bo WITH (UPDLOCK, ROWLOCK)
        WHERE RTRIM(bostamp) = @bs
          AND ISNULL(fechada, 0) = 1
    )
    BEGIN
        ROLLBACK;
        RAISERROR(N'Pedido já fechado no PHC.', 16, 1);
        RETURN;
    END;

    INSERT INTO dbo.u_HcaPedidoMobileCancel (bostamp, ClNo, ClEstab, Motivo)
    VALUES (@bs, @no, @estab, @mot);

    UPDATE dbo.bo
    SET
        fechada = 1,
        usrinis = @usr,
        usrdata = @usrdata,
        usrhora = @usrhora
    WHERE RTRIM(bostamp) = @bs
      AND ndos = @ndos
      AND no = @no
      AND estab = @estab
      AND ISNULL(fechada, 0) = 0;

    UPDATE dbo.bi
    SET
        fechada = 1,
        usrinis = @usr,
        usrdata = @usrdata,
        usrhora = @usrhora
    WHERE RTRIM(bostamp) = @bs
      AND ISNULL(fechada, 0) = 0;

    COMMIT;

    SELECT
        RTRIM(bo.bostamp) AS bostamp,
        CAST(ISNULL(bo.fechada, 0) AS bit) AS fechada,
        bo.obrano,
        @mot AS motivo
    FROM dbo.bo bo WITH (NOLOCK)
    WHERE RTRIM(bo.bostamp) = @bs;
END;
GO

IF NOT EXISTS (SELECT 1 FROM sys.database_principals WHERE name = N'portal_app')
    PRINT N'AVISO: user portal_app inexistente — saltar GRANT 095.';
ELSE
BEGIN
    GRANT EXECUTE ON dbo.sp_HCA_cancelar_pedido_mobile TO [portal_app];
    PRINT N'OK: GRANT sp_HCA_cancelar_pedido_mobile → portal_app.';
END
GO
