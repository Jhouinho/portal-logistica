-- =============================================================================
-- Liliana & Seródio — Portal Mobile
-- Script: 091c_grant_sp_HCA_criar_pedido_mobile.sql
-- =============================================================================
IF NOT EXISTS (SELECT 1 FROM sys.database_principals WHERE name = N'portal_app')
    PRINT N'AVISO: user portal_app inexistente — saltar GRANTs 091c.';
ELSE
BEGIN
    IF TYPE_ID(N'dbo.HCA_PedidoMobileLinhaType') IS NOT NULL
        GRANT EXECUTE ON TYPE::dbo.HCA_PedidoMobileLinhaType TO [portal_app];

    IF OBJECT_ID(N'dbo.sp_HCA_criar_pedido_mobile', N'P') IS NOT NULL
        GRANT EXECUTE ON dbo.sp_HCA_criar_pedido_mobile TO [portal_app];
    ELSE
        PRINT N'AVISO: sp_HCA_criar_pedido_mobile inexistente.';

    -- INSERT nas tabelas PHC exige permissões de tabela (já tipicamente via role);
    -- a SP corre como caller — confirmar em UAT se portal_app tem INSERT em bo/bi/bo2/bo3/bi2
    -- ou usar EXECUTE AS OWNER (não activado neste script).

    PRINT N'OK: GRANTs 091c (quando objectos existem).';
END
GO
