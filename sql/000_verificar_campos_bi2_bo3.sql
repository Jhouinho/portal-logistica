-- =============================================================================
-- Verificar se os campos de utilizador existem nas tabelas correctas (BI2/BO3).
-- Esperado: COL_LENGTH NOT NULL para todos.
-- =============================================================================

SELECT
    N'BI2.u_qtdaut'   AS campo, COL_LENGTH(N'dbo.bi2', N'u_qtdaut')   AS bytes
UNION ALL SELECT N'BI2.u_qtdautur', COL_LENGTH(N'dbo.bi2', N'u_qtdautur')
UNION ALL SELECT N'BI2.u_qtdautdt', COL_LENGTH(N'dbo.bi2', N'u_qtdautdt')
UNION ALL SELECT N'BI2.u_qttorig',  COL_LENGTH(N'dbo.bi2', N'u_qttorig')
UNION ALL SELECT N'BI2.u_prcorig',  COL_LENGTH(N'dbo.bi2', N'u_prcorig')
UNION ALL SELECT N'BI2.u_prevId',   COL_LENGTH(N'dbo.bi2', N'u_prevId')
UNION ALL SELECT N'BI.u_cor',       COL_LENGTH(N'dbo.bi',  N'u_cor')
UNION ALL SELECT N'BO3.u_pickrdy',  COL_LENGTH(N'dbo.bo3', N'u_pickrdy')
UNION ALL SELECT N'BO3.u_pickrdr',  COL_LENGTH(N'dbo.bo3', N'u_pickrdr')
UNION ALL SELECT N'BO3.u_pickrdt',  COL_LENGTH(N'dbo.bo3', N'u_pickrdt')
UNION ALL SELECT N'BO3.u_pickstat', COL_LENGTH(N'dbo.bo3', N'u_pickstat')
UNION ALL SELECT N'BO3.u_pickcobs', COL_LENGTH(N'dbo.bo3', N'u_pickcobs')
UNION ALL SELECT N'BO3.u_urgente',  COL_LENGTH(N'dbo.bo3', N'u_urgente')
UNION ALL SELECT N'BO3.u_chkin',    COL_LENGTH(N'dbo.bo3', N'u_chkin')
UNION ALL SELECT N'BO3.u_chkinur',  COL_LENGTH(N'dbo.bo3', N'u_chkinur')
UNION ALL SELECT N'BO3.u_chkindt',  COL_LENGTH(N'dbo.bo3', N'u_chkindt')
UNION ALL SELECT N'BO3.u_modExp',   COL_LENGTH(N'dbo.bo3', N'u_modExp')
UNION ALL SELECT N'BO2.u_mEntrega', COL_LENGTH(N'dbo.bo2', N'u_mEntrega')
UNION ALL SELECT N'US.u_usaPort',   COL_LENGTH(N'dbo.us',  N'u_usaPort')
UNION ALL SELECT N'STOBS.u_dispPort', COL_LENGTH(N'dbo.stobs', N'u_dispPort');
GO

-- Se algum bytes IS NULL → campo em falta ou na tabela errada (ex. criado em BI em vez de BI2).
