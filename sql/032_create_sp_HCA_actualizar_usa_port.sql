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
