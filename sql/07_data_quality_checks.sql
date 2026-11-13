/* =============================================================================
   Script 07 - controlli di qualita' dati e quadrature
   Da lanciare dopo ogni caricamento. Ogni controllo restituisce 0 righe
   (o differenza = 0) se tutto e' ok.
   ============================================================================= */
USE FinancePL;
GO

/* 1. Quadratura ricavi: staging vs FactSales vs FactPL */
SELECT
    (SELECT SUM(TRY_CONVERT(DECIMAL(18,2), NetAmount)) FROM stg.SalesInvoiceLines)          AS Stg_NetSales,
    (SELECT SUM(NetAmount) FROM dw.FactSales)                                                AS Fact_NetSales,
    (SELECT SUM(f.Amount) FROM dw.FactPL f JOIN dw.DimAccount a ON a.AccountKey = f.AccountKey
      WHERE a.AccountCode = '410000')                                                       AS PL_Revenue;

/* 2. Quadratura costi contabilita' generale */
SELECT
    (SELECT SUM(TRY_CONVERT(DECIMAL(18,2), Amount)) FROM stg.GLEntries) AS Stg_GL,
    (SELECT SUM(Amount) FROM dw.FactPL WHERE SourceSystem = 'GL')      AS Fact_GL;

/* 3. Righe con chiavi non risolte (membro -1) */
SELECT 'Cliente non trovato' AS Issue, COUNT(*) AS RowCnt FROM dw.FactSales WHERE CustomerKey = -1
UNION ALL
SELECT 'Articolo non trovato', COUNT(*) FROM dw.FactSales WHERE ProductKey = -1;

/* 4. Conversioni fallite in staging */
SELECT COUNT(*) AS BadRows
FROM stg.SalesInvoiceLines
WHERE TRY_CONVERT(DATE, DocumentDate) IS NULL
   OR TRY_CONVERT(DECIMAL(18,2), NetAmount) IS NULL
   OR TRY_CONVERT(INT, Quantity) IS NULL;

/* 5. Coerenza importi riga: lordo - sconto = netto (tolleranza arrotondamento) */
SELECT TOP (50) DocumentNumber, DocumentLine, GrossAmount, DiscountAmount, NetAmount
FROM dw.FactSales
WHERE ABS(GrossAmount - DiscountAmount - NetAmount) > 0.02;

/* 6. Righe fattura duplicate */
SELECT DocumentNumber, DocumentLine, COUNT(*) AS Cnt
FROM dw.FactSales
GROUP BY DocumentNumber, DocumentLine
HAVING COUNT(*) > 1;

/* 7. Vendite sottocosto (margine negativo su fatture, non note di credito) */
SELECT TOP (50) f.DocumentNumber, p.ProductCode, f.NetAmount, f.COGSAmount
FROM dw.FactSales f
JOIN dw.DimProduct p ON p.ProductKey = f.ProductKey
WHERE f.DocumentType = 'FT' AND f.NetAmount < f.COGSAmount
ORDER BY f.COGSAmount - f.NetAmount DESC;

/* 8. Mesi senza registrazioni di costo per conti ricorrenti (personale, ammortamenti) */
SELECT a.AccountCode, d.YearMonth
FROM (SELECT DISTINCT YearMonth FROM dw.DimDate WHERE [Year] BETWEEN 2023 AND 2025) d
CROSS JOIN dw.DimAccount a
WHERE a.AccountCode IN ('610000', '710000')
  AND NOT EXISTS (SELECT 1 FROM dw.FactPL f JOIN dw.DimDate dd ON dd.DateKey = f.DateKey
                  WHERE f.AccountKey = a.AccountKey AND dd.YearMonth = d.YearMonth);
GO
