-- =============================================================================
-- Liliana & Seródio — Portal Mobile Fase 1
-- Script: 096b_create_u_HcaPmPedidoLin.sql
-- Pré-requisito: 096_create_u_HcaPmPedido.sql
-- FK sem ON DELETE CASCADE (integridade operacional).
-- =============================================================================

SET NOCOUNT ON;
SET XACT_ABORT ON;
GO

IF OBJECT_ID(N'dbo.u_HcaPmPedidoLin', N'U') IS NULL
BEGIN
    CREATE TABLE dbo.u_HcaPmPedidoLin
    (
        LinhaId        bigint         NOT NULL IDENTITY(1, 1),
        PedidoId       bigint         NOT NULL,
        LinhaOrd       int            NOT NULL,
        Ref            varchar(18)    NOT NULL,
        Design         varchar(60)    NOT NULL,
        Cor            varchar(100)   NOT NULL
            CONSTRAINT DF_u_HcaPmPedidoLin_Cor DEFAULT (N''),
        Qtt            numeric(16, 4) NOT NULL,
        PrecoUnitario  numeric(19, 6) NOT NULL,
        TotalLinha     numeric(19, 6) NOT NULL,
        CONSTRAINT PK_u_HcaPmPedidoLin PRIMARY KEY (LinhaId),
        CONSTRAINT FK_u_HcaPmPedidoLin_Cab
            FOREIGN KEY (PedidoId) REFERENCES dbo.u_HcaPmPedido (PedidoId),
        CONSTRAINT UQ_u_HcaPmPedidoLin_Ord UNIQUE (PedidoId, LinhaOrd),
        CONSTRAINT CK_u_HcaPmPedidoLin_Ord CHECK (LinhaOrd > 0),
        CONSTRAINT CK_u_HcaPmPedidoLin_Qtt CHECK (Qtt > 0)
    );

    CREATE INDEX IX_u_HcaPmPedidoLin_Pedido
        ON dbo.u_HcaPmPedidoLin (PedidoId, LinhaOrd);
END
GO
