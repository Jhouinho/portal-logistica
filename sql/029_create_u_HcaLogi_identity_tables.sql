-- =============================================================================
-- Liliana & Seródio — Portal Logístico
-- Script: 029_create_u_HcaLogi_identity_tables.sql
-- Ambiente: UAT primeiro; Produção só no GO formal
-- =============================================================================
-- ASP.NET Core Identity — tabelas físicas com prefixo u_HcaLogi*
-- Equivalente à migration EF: InitialIdentityHcaLogi (8.0.22)
-- Pré-requisito opcional: 028 (US.u_usaPort)
-- Idempotente: não recria tabelas já existentes.
-- =============================================================================

SET NOCOUNT ON;
SET XACT_ABORT ON;

-- Histórico EF (para a API não tentar recriar via Migrate)
IF OBJECT_ID(N'dbo.__EFMigrationsHistory', N'U') IS NULL
BEGIN
    CREATE TABLE dbo.__EFMigrationsHistory
    (
        MigrationId    nvarchar(150) NOT NULL,
        ProductVersion nvarchar(32)  NOT NULL,
        CONSTRAINT PK___EFMigrationsHistory PRIMARY KEY (MigrationId)
    );
END;
GO

IF OBJECT_ID(N'dbo.u_HcaLogiRoles', N'U') IS NULL
BEGIN
    CREATE TABLE dbo.u_HcaLogiRoles
    (
        Id               nvarchar(450)  NOT NULL,
        Name             nvarchar(256)  NULL,
        NormalizedName   nvarchar(256)  NULL,
        ConcurrencyStamp nvarchar(max)  NULL,
        CONSTRAINT PK_u_HcaLogiRoles PRIMARY KEY (Id)
    );
END;
GO

IF OBJECT_ID(N'dbo.u_HcaLogiUsers', N'U') IS NULL
BEGIN
    CREATE TABLE dbo.u_HcaLogiUsers
    (
        Id                   nvarchar(450)     NOT NULL,
        UsStamp              nvarchar(25)      NULL,
        Usercode             nvarchar(20)      NULL,
        UserName             nvarchar(256)     NULL,
        NormalizedUserName   nvarchar(256)     NULL,
        Email                nvarchar(256)     NULL,
        NormalizedEmail      nvarchar(256)     NULL,
        EmailConfirmed       bit               NOT NULL,
        PasswordHash         nvarchar(max)     NULL,
        SecurityStamp        nvarchar(max)     NULL,
        ConcurrencyStamp     nvarchar(max)     NULL,
        PhoneNumber          nvarchar(max)     NULL,
        PhoneNumberConfirmed bit               NOT NULL,
        TwoFactorEnabled     bit               NOT NULL,
        LockoutEnd           datetimeoffset(7) NULL,
        LockoutEnabled       bit               NOT NULL,
        AccessFailedCount    int               NOT NULL,
        CONSTRAINT PK_u_HcaLogiUsers PRIMARY KEY (Id)
    );
END;
GO

IF OBJECT_ID(N'dbo.u_HcaLogiRoleClaims', N'U') IS NULL
BEGIN
    CREATE TABLE dbo.u_HcaLogiRoleClaims
    (
        Id         int            NOT NULL IDENTITY(1, 1),
        RoleId     nvarchar(450)  NOT NULL,
        ClaimType  nvarchar(max)  NULL,
        ClaimValue nvarchar(max)  NULL,
        CONSTRAINT PK_u_HcaLogiRoleClaims PRIMARY KEY (Id),
        CONSTRAINT FK_u_HcaLogiRoleClaims_u_HcaLogiRoles_RoleId
            FOREIGN KEY (RoleId) REFERENCES dbo.u_HcaLogiRoles (Id) ON DELETE CASCADE
    );
END;
GO

IF OBJECT_ID(N'dbo.u_HcaLogiUserClaims', N'U') IS NULL
BEGIN
    CREATE TABLE dbo.u_HcaLogiUserClaims
    (
        Id         int            NOT NULL IDENTITY(1, 1),
        UserId     nvarchar(450)  NOT NULL,
        ClaimType  nvarchar(max)  NULL,
        ClaimValue nvarchar(max)  NULL,
        CONSTRAINT PK_u_HcaLogiUserClaims PRIMARY KEY (Id),
        CONSTRAINT FK_u_HcaLogiUserClaims_u_HcaLogiUsers_UserId
            FOREIGN KEY (UserId) REFERENCES dbo.u_HcaLogiUsers (Id) ON DELETE CASCADE
    );
END;
GO

IF OBJECT_ID(N'dbo.u_HcaLogiUserLogins', N'U') IS NULL
BEGIN
    CREATE TABLE dbo.u_HcaLogiUserLogins
    (
        LoginProvider       nvarchar(450) NOT NULL,
        ProviderKey         nvarchar(450) NOT NULL,
        ProviderDisplayName nvarchar(max) NULL,
        UserId              nvarchar(450) NOT NULL,
        CONSTRAINT PK_u_HcaLogiUserLogins PRIMARY KEY (LoginProvider, ProviderKey),
        CONSTRAINT FK_u_HcaLogiUserLogins_u_HcaLogiUsers_UserId
            FOREIGN KEY (UserId) REFERENCES dbo.u_HcaLogiUsers (Id) ON DELETE CASCADE
    );
END;
GO

IF OBJECT_ID(N'dbo.u_HcaLogiUserRoles', N'U') IS NULL
BEGIN
    CREATE TABLE dbo.u_HcaLogiUserRoles
    (
        UserId nvarchar(450) NOT NULL,
        RoleId nvarchar(450) NOT NULL,
        CONSTRAINT PK_u_HcaLogiUserRoles PRIMARY KEY (UserId, RoleId),
        CONSTRAINT FK_u_HcaLogiUserRoles_u_HcaLogiRoles_RoleId
            FOREIGN KEY (RoleId) REFERENCES dbo.u_HcaLogiRoles (Id) ON DELETE CASCADE,
        CONSTRAINT FK_u_HcaLogiUserRoles_u_HcaLogiUsers_UserId
            FOREIGN KEY (UserId) REFERENCES dbo.u_HcaLogiUsers (Id) ON DELETE CASCADE
    );
END;
GO

IF OBJECT_ID(N'dbo.u_HcaLogiUserTokens', N'U') IS NULL
BEGIN
    CREATE TABLE dbo.u_HcaLogiUserTokens
    (
        UserId        nvarchar(450) NOT NULL,
        LoginProvider nvarchar(450) NOT NULL,
        Name          nvarchar(450) NOT NULL,
        Value         nvarchar(max) NULL,
        CONSTRAINT PK_u_HcaLogiUserTokens PRIMARY KEY (UserId, LoginProvider, Name),
        CONSTRAINT FK_u_HcaLogiUserTokens_u_HcaLogiUsers_UserId
            FOREIGN KEY (UserId) REFERENCES dbo.u_HcaLogiUsers (Id) ON DELETE CASCADE
    );
END;
GO

-- Índices (criar só se em falta)
IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE name = N'IX_u_HcaLogiRoleClaims_RoleId' AND object_id = OBJECT_ID(N'dbo.u_HcaLogiRoleClaims'))
    CREATE INDEX IX_u_HcaLogiRoleClaims_RoleId ON dbo.u_HcaLogiRoleClaims (RoleId);
GO

IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE name = N'RoleNameIndex' AND object_id = OBJECT_ID(N'dbo.u_HcaLogiRoles'))
    CREATE UNIQUE INDEX RoleNameIndex ON dbo.u_HcaLogiRoles (NormalizedName)
        WHERE [NormalizedName] IS NOT NULL;
GO

IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE name = N'IX_u_HcaLogiUserClaims_UserId' AND object_id = OBJECT_ID(N'dbo.u_HcaLogiUserClaims'))
    CREATE INDEX IX_u_HcaLogiUserClaims_UserId ON dbo.u_HcaLogiUserClaims (UserId);
GO

IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE name = N'IX_u_HcaLogiUserLogins_UserId' AND object_id = OBJECT_ID(N'dbo.u_HcaLogiUserLogins'))
    CREATE INDEX IX_u_HcaLogiUserLogins_UserId ON dbo.u_HcaLogiUserLogins (UserId);
GO

IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE name = N'IX_u_HcaLogiUserRoles_RoleId' AND object_id = OBJECT_ID(N'dbo.u_HcaLogiUserRoles'))
    CREATE INDEX IX_u_HcaLogiUserRoles_RoleId ON dbo.u_HcaLogiUserRoles (RoleId);
GO

IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE name = N'EmailIndex' AND object_id = OBJECT_ID(N'dbo.u_HcaLogiUsers'))
    CREATE INDEX EmailIndex ON dbo.u_HcaLogiUsers (NormalizedEmail);
GO

IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE name = N'UserNameIndex' AND object_id = OBJECT_ID(N'dbo.u_HcaLogiUsers'))
    CREATE UNIQUE INDEX UserNameIndex ON dbo.u_HcaLogiUsers (NormalizedUserName)
        WHERE [NormalizedUserName] IS NOT NULL;
GO

IF NOT EXISTS (
    SELECT 1 FROM dbo.__EFMigrationsHistory
    WHERE MigrationId = N'20260811092935_InitialIdentityHcaLogi'
)
BEGIN
    INSERT INTO dbo.__EFMigrationsHistory (MigrationId, ProductVersion)
    VALUES (N'20260811092935_InitialIdentityHcaLogi', N'8.0.22');
END;
GO
