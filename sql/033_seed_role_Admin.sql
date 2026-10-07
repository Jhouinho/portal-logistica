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
