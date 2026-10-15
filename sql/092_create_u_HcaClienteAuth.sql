-- =============================================================================
-- Liliana & Seródio — Portal Mobile
-- Script: 092_create_u_HcaClienteAuth.sql
-- Ambiente: UAT primeiro; Produção só com autorização explícita
-- =============================================================================
-- Credenciais de clientes do Portal Mobile (hash ASP.NET Identity).
-- NÃO usa CL2.u_passp. Chave lógica = (ClNo, ClEstab) = CL.no + CL.estab.
-- Idempotente.
-- =============================================================================

SET NOCOUNT ON;
SET XACT_ABORT ON;
GO

IF OBJECT_ID(N'dbo.u_HcaClienteAuth', N'U') IS NULL
BEGIN
    CREATE TABLE dbo.u_HcaClienteAuth
    (
        ClNo                 numeric(10, 0)  NOT NULL,
        ClEstab              numeric(3, 0)   NOT NULL,
        PasswordHash         nvarchar(max)   NULL,
        FailedPhoneAttempts  int             NOT NULL
            CONSTRAINT DF_u_HcaClienteAuth_FailedPhone DEFAULT (0),
        PhoneLockoutEnd      datetime2(0)    NULL,
        FailedLoginAttempts  int             NOT NULL
            CONSTRAINT DF_u_HcaClienteAuth_FailedLogin DEFAULT (0),
        LoginLockoutEnd      datetime2(0)    NULL,
        PasswordSetAt        datetime2(0)    NULL,
        UpdatedAt            datetime2(0)    NOT NULL
            CONSTRAINT DF_u_HcaClienteAuth_UpdatedAt DEFAULT (SYSUTCDATETIME()),
        CONSTRAINT PK_u_HcaClienteAuth PRIMARY KEY (ClNo, ClEstab)
    );
END
GO

PRINT N'OK: u_HcaClienteAuth pronta.';
GO
