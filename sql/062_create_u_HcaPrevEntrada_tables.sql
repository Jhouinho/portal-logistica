-- =============================================================================
-- Liliana & Seródio — Portal Logístico
-- Script: 062_create_u_HcaPrevEntrada_tables.sql
-- Ambiente: UAT primeiro; Produção só no GO formal
-- =============================================================================
-- Tabelas próprias do Portal (previsões de entrada). Prefixo u_Hca*.
-- Idempotente. Não altera STOBS.u_dispPort nem ST.stock.
-- =============================================================================

SET NOCOUNT ON;
SET XACT_ABORT ON;

IF OBJECT_ID(N'dbo.u_HcaPrevEntrada', N'U') IS NULL
BEGIN
    CREATE TABLE dbo.u_HcaPrevEntrada
    (
        Id          uniqueidentifier NOT NULL
            CONSTRAINT DF_u_HcaPrevEntrada_Id DEFAULT (NEWSEQUENTIALID()),
        DataInicio  date             NOT NULL,
        DataFim     date             NOT NULL,
        CriadoEm    datetime2(0)     NOT NULL
            CONSTRAINT DF_u_HcaPrevEntrada_CriadoEm DEFAULT (SYSUTCDATETIME()),
        CriadoPor   nvarchar(100)    NOT NULL
            CONSTRAINT DF_u_HcaPrevEntrada_CriadoPor DEFAULT (N''),
        AlteradoEm  datetime2(0)     NULL,
        AlteradoPor nvarchar(100)    NULL,
        CONSTRAINT PK_u_HcaPrevEntrada PRIMARY KEY (Id),
        CONSTRAINT UQ_u_HcaPrevEntrada_Periodo UNIQUE (DataInicio, DataFim),
        CONSTRAINT CK_u_HcaPrevEntrada_Datas CHECK (DataInicio <= DataFim)
    );
END;
GO

IF OBJECT_ID(N'dbo.u_HcaPrevEntradaLin', N'U') IS NULL
BEGIN
    CREATE TABLE dbo.u_HcaPrevEntradaLin
    (
        Id                  uniqueidentifier NOT NULL
            CONSTRAINT DF_u_HcaPrevEntradaLin_Id DEFAULT (NEWSEQUENTIALID()),
        PrevisaoId          uniqueidentifier NOT NULL,
        Ref                 varchar(18)      NOT NULL,
        QuantidadePrevista  numeric(16, 2)   NOT NULL
            CONSTRAINT DF_u_HcaPrevEntradaLin_Qty DEFAULT (0),
        CONSTRAINT PK_u_HcaPrevEntradaLin PRIMARY KEY (Id),
        CONSTRAINT FK_u_HcaPrevEntradaLin_Cab
            FOREIGN KEY (PrevisaoId) REFERENCES dbo.u_HcaPrevEntrada (Id) ON DELETE CASCADE,
        CONSTRAINT UQ_u_HcaPrevEntradaLin_Ref UNIQUE (PrevisaoId, Ref),
        CONSTRAINT CK_u_HcaPrevEntradaLin_Qty CHECK (QuantidadePrevista >= 0)
    );
END;
GO

IF NOT EXISTS (
    SELECT 1 FROM sys.indexes
    WHERE name = N'IX_u_HcaPrevEntradaLin_PrevisaoId'
      AND object_id = OBJECT_ID(N'dbo.u_HcaPrevEntradaLin')
)
BEGIN
    CREATE INDEX IX_u_HcaPrevEntradaLin_PrevisaoId
        ON dbo.u_HcaPrevEntradaLin (PrevisaoId);
END;
GO
