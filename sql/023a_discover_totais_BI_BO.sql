-- =============================================================================
-- Discovery: colunas de valor/totais em BI e BO (UAT)
-- Correr e colar o resultado — ajustamos o SP 022 aos nomes reais
-- =============================================================================

-- 1) BI — candidatos a preço / totais de linha
SELECT COLUMN_NAME, DATA_TYPE, NUMERIC_PRECISION, NUMERIC_SCALE
FROM INFORMATION_SCHEMA.COLUMNS
WHERE TABLE_SCHEMA = 'dbo'
  AND TABLE_NAME = 'bi'
  AND (
        COLUMN_NAME LIKE '%deb%'
     OR COLUMN_NAME LIKE '%liq%'
     OR COLUMN_NAME LIKE '%iva%'
     OR COLUMN_NAME LIKE '%total%'
     OR COLUMN_NAME IN ('edebito', 'debito', 'ettdeb', 'ttdeb', 'etiliquido', 'tiliquido', 'iva', 'ivaincl')
  )
ORDER BY COLUMN_NAME;

-- 2) BO — candidatos a totais de cabeçalho
SELECT COLUMN_NAME, DATA_TYPE, NUMERIC_PRECISION, NUMERIC_SCALE
FROM INFORMATION_SCHEMA.COLUMNS
WHERE TABLE_SCHEMA = 'dbo'
  AND TABLE_NAME = 'bo'
  AND (
        COLUMN_NAME LIKE '%deb%'
     OR COLUMN_NAME LIKE '%liq%'
     OR COLUMN_NAME LIKE '%iva%'
     OR COLUMN_NAME LIKE '%total%'
     OR COLUMN_NAME IN ('etotal', 'total', 'eboiva', 'boiva', 'etotaldeb', 'totaldeb')
  )
ORDER BY COLUMN_NAME;

-- 3) Amostra de uma linha aberta (valores reais)
SELECT TOP 1
    bi.bistamp,
    bi.qtt,
    bi.edebito,
    bi.ettdeb
    -- acrescentar aqui colunas que aparecerem no resultado 1 (ex.: tiliquido)
FROM dbo.bi bi WITH (NOLOCK)
INNER JOIN dbo.bo bo WITH (NOLOCK) ON bo.bostamp = bi.bostamp
WHERE bo.ndos = 1
  AND ISNULL(bo.fechada, 0) = 0
ORDER BY bo.dataobra DESC;
GO
