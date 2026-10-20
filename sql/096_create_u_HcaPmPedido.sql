-- =============================================================================
-- Liliana & Seródio — Portal Mobile Fase 1
-- Script: 096_create_u_HcaPmPedido.sql
-- Pedido interno (antes da integração PHC ndos=67).
-- Idempotente: IF OBJECT_ID IS NULL. Não DROP. Não migra BO existentes.
-- =============================================================================

SET NOCOUNT ON;
SET XACT_ABORT ON;
GO

IF OBJECT_ID(N'dbo.u_HcaPmPedido', N'U') IS NULL
BEGIN
    CREATE TABLE dbo.u_HcaPmPedido
    (
        PedidoId                 bigint         NOT NULL IDENTITY(1, 1),
        NumeroInterno            varchar(24)    NULL,
        ClNo                     numeric(10, 0) NOT NULL,
        ClEstab                  numeric(3, 0)  NOT NULL,
        EstadoInterno            varchar(32)    NOT NULL
            CONSTRAINT DF_u_HcaPmPedido_Estado DEFAULT (N'recebido'),
        DataSubmissao            datetime2(0)   NOT NULL
            CONSTRAINT DF_u_HcaPmPedido_Sub DEFAULT (SYSUTCDATETIME()),
        DataAlteracao            datetime2(0)   NOT NULL
            CONSTRAINT DF_u_HcaPmPedido_Alt DEFAULT (SYSUTCDATETIME()),
        Etotaldeb                numeric(19, 6) NOT NULL,
        SubmissaoIdempotencyKey  varchar(64)    NOT NULL,
        SubmissaoPayloadHash     char(64)       NOT NULL,
        CriadoPor                varchar(16)    NOT NULL
            CONSTRAINT DF_u_HcaPmPedido_Usr DEFAULT (N'MOB'),
        Bostamp                  varchar(25)    NULL,
        Obrano                   numeric(10, 0) NULL,
        Boano                    numeric(4, 0)  NULL,
        Ndos                     numeric(5, 0)  NULL,
        CONSTRAINT PK_u_HcaPmPedido PRIMARY KEY (PedidoId),
        CONSTRAINT UQ_u_HcaPmPedido_NumeroInterno UNIQUE (NumeroInterno),
        CONSTRAINT UQ_u_HcaPmPedido_IdemKey UNIQUE (SubmissaoIdempotencyKey)
    );

    CREATE INDEX IX_u_HcaPmPedido_Cl_Data
        ON dbo.u_HcaPmPedido (ClNo, ClEstab, DataSubmissao DESC);
END
GO
