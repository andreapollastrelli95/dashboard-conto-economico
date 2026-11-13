/* =============================================================================
   Script 05 - viste di reporting (schema rpt)
   Power BI legge SOLO da queste viste: se cambia il modello fisico basta
   aggiornare la vista e il report non si rompe.
   ============================================================================= */
USE FinancePL;
GO

CREATE OR ALTER VIEW rpt.Calendar AS
SELECT DateKey, [Date], [Year], [Quarter], QuarterLabel, [Month], MonthName, MonthShort,
       YearMonth, YearMonthLabel, WeekOfYear, DayOfWeek, DayName, IsWorkingDay
FROM dw.DimDate
WHERE [Year] BETWEEN 2023 AND 2025;   -- solo gli anni con dati, evita colonne vuote nei grafici
GO

CREATE OR ALTER VIEW rpt.Customer AS
SELECT CustomerKey, CustomerCode, CustomerName, CustomerSegment, City, Province, Region,
       SalesArea, Country, Market, PaymentTerms, CustomerSince
FROM dw.DimCustomer;
GO

CREATE OR ALTER VIEW rpt.Product AS
SELECT ProductKey, ProductCode, ProductName, ProductCategory, ProductSubcategory, LaunchDate
FROM dw.DimProduct;
GO

CREATE OR ALTER VIEW rpt.SalesRep AS
SELECT SalesRepKey, SalesRepName, SalesArea
FROM dw.DimSalesRep;
GO

CREATE OR ALTER VIEW rpt.Account AS
SELECT a.AccountKey, a.AccountCode, a.AccountCode + N' - ' + a.AccountName AS Account,
       a.PLSection, a.PLSubsection, a.PLSign, a.SortOrder,
       l.PLLineKey, l.PLLineName, l.SortOrder AS PLLineSort
FROM dw.DimAccount a
JOIN dw.DimPLLine  l ON l.PLLineKey = a.PLLineKey;
GO

-- tabella "layout" del conto economico, usata come righe della matrice in Power BI
CREATE OR ALTER VIEW rpt.PLLayout AS
SELECT PLLineKey, PLLineName, LineType, SortOrder, IsBold
FROM dw.DimPLLine;
GO

CREATE OR ALTER VIEW rpt.CostCenter AS
SELECT CostCenterKey, CostCenterCode, CostCenterName, CostCenterGroup
FROM dw.DimCostCenter;
GO

CREATE OR ALTER VIEW rpt.FactSales AS
SELECT DateKey, CustomerKey, ProductKey, SalesRepKey, DocumentNumber, DocumentType,
       Quantity, GrossAmount, DiscountAmount, NetAmount, COGSAmount
FROM dw.FactSales;
GO

CREATE OR ALTER VIEW rpt.FactPL AS
SELECT DateKey, AccountKey, CostCenterKey, SourceSystem, Amount, SignedAmount
FROM dw.FactPL;
GO

-- vista di controllo: conto economico mensile in formato tabellare (utile anche per export Excel)
CREATE OR ALTER VIEW rpt.vw_PL_Monthly AS
SELECT  d.[Year],
        d.[Month],
        SUM(CASE WHEN a.PLLineKey = 1  THEN f.SignedAmount ELSE 0 END)                    AS Revenue,
        -SUM(CASE WHEN a.PLLineKey = 2  THEN f.SignedAmount ELSE 0 END)                   AS COGS,
        SUM(CASE WHEN a.PLLineKey IN (1, 2) THEN f.SignedAmount ELSE 0 END)               AS GrossMargin,
        -SUM(CASE WHEN a.PLLineKey BETWEEN 4 AND 8 THEN f.SignedAmount ELSE 0 END)        AS OperatingExpenses,
        SUM(CASE WHEN a.PLLineKey <> 10 THEN f.SignedAmount ELSE 0 END)                   AS EBITDA,
        -SUM(CASE WHEN a.PLLineKey = 10 THEN f.SignedAmount ELSE 0 END)                   AS DepreciationAmortization,
        SUM(f.SignedAmount)                                                               AS EBIT
FROM dw.FactPL f
JOIN dw.DimAccount a ON a.AccountKey = f.AccountKey
JOIN dw.DimDate    d ON d.DateKey    = f.DateKey
GROUP BY d.[Year], d.[Month];
GO
