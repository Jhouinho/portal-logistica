-- =============================================================================
-- Liliana & Seródio — Portal Logístico
-- Script: 028_add_us_u_usaPort.sql
-- Ambiente: UAT primeiro; Produção só no GO formal
-- =============================================================================
-- Preferível criar via Supervisor → Framework PHC (campos de utilizador) e
-- «Atualizar a Tabela». Este script é fallback SQL directo.
-- =============================================================================

IF COL_LENGTH('dbo.us', 'u_usaPort') IS NULL
BEGIN
    ALTER TABLE dbo.us ADD u_usaPort bit NOT NULL
        CONSTRAINT DF_us_u_usaPort DEFAULT (0);
END;
GO

-- Exemplo piloto UAT (ajustar email):
-- UPDATE dbo.us SET u_usaPort = 1
-- WHERE LOWER(LTRIM(RTRIM(email))) = LOWER(N'joao.lopes@hcaraujo.pt');
GO
