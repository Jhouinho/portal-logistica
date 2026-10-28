/*
  Grants Kapps para o login SQL portal_app.
  Necessário para GET /api/v1/painel/tv-kapps-resumo (Centro de Operações / Vista TV).

  Sintomas sem este grant:
  - Banner "Ocorreu um erro. Tente novamente." no Centro
  - HTTP 500 em /api/v1/painel/tv-kapps-resumo
  - SQL: SELECT permission denied on u_Kapps_DossierLin / u_Kapps_Terminals

  Executar como sysadmin / db_owner na BD PHC (ex. LillianaSerodioPhc).
*/
SET NOCOUNT ON;
SET XACT_ABORT ON;

IF DATABASE_PRINCIPAL_ID(N'portal_app') IS NULL
BEGIN
    RAISERROR(N'Utilizador de BD [portal_app] em falta. Crie o user mapeado ao login antes dos GRANTs.', 16, 1);
    RETURN;
END;

IF OBJECT_ID(N'dbo.u_Kapps_DossierLin', N'U') IS NULL
BEGIN
    RAISERROR(N'Objecto dbo.u_Kapps_DossierLin em falta.', 16, 1);
    RETURN;
END;

IF OBJECT_ID(N'dbo.u_Kapps_Terminals', N'U') IS NULL
BEGIN
    RAISERROR(N'Objecto dbo.u_Kapps_Terminals em falta.', 16, 1);
    RETURN;
END;

GRANT SELECT ON dbo.u_Kapps_DossierLin TO [portal_app];
GRANT SELECT ON dbo.u_Kapps_Terminals TO [portal_app];

-- Objectpcionais usados noutros fluxos Kapps (idempotente se já existirem)
IF OBJECT_ID(N'dbo.v_Kapps_Picking_Lines', N'V') IS NOT NULL
    GRANT SELECT ON dbo.v_Kapps_Picking_Lines TO [portal_app];
IF OBJECT_ID(N'dbo.v_Kapps_Picking_Documents', N'V') IS NOT NULL
    GRANT SELECT ON dbo.v_Kapps_Picking_Documents TO [portal_app];

PRINT N'OK: GRANTs Kapps aplicados a [portal_app].';

SELECT
    HAS_PERMS_BY_NAME(N'dbo.u_Kapps_DossierLin', N'OBJECT', N'SELECT') AS sel_dossierlin,
    HAS_PERMS_BY_NAME(N'dbo.u_Kapps_Terminals', N'OBJECT', N'SELECT') AS sel_terminals;
