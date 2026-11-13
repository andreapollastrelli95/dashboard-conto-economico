/* =============================================================================
   Script 06 - query di analisi
   Le uso per validare i numeri della dashboard e come base per i commenti
   al management. Ogni query e' indipendente.
   ============================================================================= */
USE FinancePL;
GO

/* 1. Conto economico riclassificato per anno, con incidenze % sui ricavi */
SELECT  [Year],
        Revenue,
        COGS,
        GrossMargin,
        CAST(GrossMargin * 100.0 / NULLIF(Revenue, 0) AS DECIMAL(5,1))   AS GrossMarginPct,
        OperatingExpenses,
        EBITDA,
        CAST(EBITDA * 100.0 / NULLIF(Revenue, 0) AS DECIMAL(5,1))        AS EBITDAPct,
        DepreciationAmortization,
        EBIT,
        CAST(EBIT * 100.0 / NULLIF(Revenue, 0) AS DECIMAL(5,1))          AS EBITPct
FROM (
    SELECT [Year], SUM(Revenue) AS Revenue, SUM(COGS) AS COGS, SUM(GrossMargin) AS GrossMargin,
           SUM(OperatingExpenses) AS OperatingExpenses, SUM(EBITDA) AS EBITDA,
           SUM(DepreciationAmortization) AS DepreciationAmortization, SUM(EBIT) AS EBIT
    FROM rpt.vw_PL_Monthly
    GROUP BY [Year]
) y
ORDER BY [Year];

/* 2. Trend mensile ricavi con crescita YoY (LAG su 12 mesi) e media mobile 3 mesi */
WITH m AS (
    SELECT [Year], [Month], SUM(Revenue) AS Revenue, SUM(EBITDA) AS EBITDA
    FROM rpt.vw_PL_Monthly
    GROUP BY [Year], [Month]
)
SELECT  [Year], [Month], Revenue,
        LAG(Revenue, 12) OVER (ORDER BY [Year], [Month])                                  AS RevenuePY,
        CAST((Revenue / NULLIF(LAG(Revenue, 12) OVER (ORDER BY [Year], [Month]), 0) - 1) * 100
             AS DECIMAL(6,1))                                                             AS YoYPct,
        AVG(Revenue) OVER (ORDER BY [Year], [Month] ROWS BETWEEN 2 PRECEDING AND CURRENT ROW) AS Revenue3MAvg,
        CAST(EBITDA * 100.0 / NULLIF(Revenue, 0) AS DECIMAL(5,1))                         AS EBITDAPct
FROM m
ORDER BY [Year], [Month];

/* 3. Marginalita' per categoria prodotto e anno (margine industriale a costo standard) */
SELECT  d.[Year],
        p.ProductCategory,
        SUM(f.NetAmount)                                                   AS NetSales,
        SUM(f.NetAmount - f.COGSAmount)                                    AS StdGrossMargin,
        CAST(SUM(f.NetAmount - f.COGSAmount) * 100.0 / NULLIF(SUM(f.NetAmount), 0) AS DECIMAL(5,1)) AS StdGMPct,
        CAST(SUM(f.NetAmount) * 100.0 / SUM(SUM(f.NetAmount)) OVER (PARTITION BY d.[Year]) AS DECIMAL(5,1)) AS MixPct
FROM dw.FactSales f
JOIN dw.DimProduct p ON p.ProductKey = f.ProductKey
JOIN dw.DimDate    d ON d.DateKey    = f.DateKey
GROUP BY d.[Year], p.ProductCategory
ORDER BY d.[Year], NetSales DESC;

/* 4. Concentrazione clienti (analisi di Pareto) - ultimo anno */
WITH c AS (
    SELECT  cu.CustomerName, cu.CustomerSegment, SUM(f.NetAmount) AS NetSales
    FROM dw.FactSales f
    JOIN dw.DimCustomer cu ON cu.CustomerKey = f.CustomerKey
    JOIN dw.DimDate d      ON d.DateKey      = f.DateKey
    WHERE d.[Year] = 2025
    GROUP BY cu.CustomerName, cu.CustomerSegment
)
SELECT  ROW_NUMBER() OVER (ORDER BY NetSales DESC)                                AS Rnk,
        CustomerName, CustomerSegment, NetSales,
        CAST(SUM(NetSales) OVER (ORDER BY NetSales DESC ROWS UNBOUNDED PRECEDING) * 100.0
             / SUM(NetSales) OVER () AS DECIMAL(5,1))                              AS CumulativePct,
        CASE WHEN SUM(NetSales) OVER (ORDER BY NetSales DESC ROWS UNBOUNDED PRECEDING)
                  <= 0.8 * SUM(NetSales) OVER () THEN 'A'
             WHEN SUM(NetSales) OVER (ORDER BY NetSales DESC ROWS UNBOUNDED PRECEDING)
                  <= 0.95 * SUM(NetSales) OVER () THEN 'B'
             ELSE 'C' END                                                         AS ABCClass
FROM c
ORDER BY NetSales DESC;

/* 5. Analisi prezzo / volume / mix 2025 vs 2024 sul margine industriale per categoria
      - effetto volume : variazione quantita' a margine unitario dell'anno precedente
      - effetto prezzo : variazione prezzo netto unitario x quantita' anno corrente
      - effetto costo  : variazione costo standard unitario x quantita' anno corrente (segno -)
      Calcolato a livello di articolo, poi sommato per categoria (il mix resta dentro il volume). */
WITH a AS (
    SELECT  p.ProductCategory, p.ProductCode, d.[Year],
            SUM(f.Quantity)   AS Qty,
            SUM(f.NetAmount)  AS NetSales,
            SUM(f.COGSAmount) AS COGS
    FROM dw.FactSales f
    JOIN dw.DimProduct p ON p.ProductKey = f.ProductKey
    JOIN dw.DimDate    d ON d.DateKey    = f.DateKey
    WHERE d.[Year] IN (2024, 2025)
    GROUP BY p.ProductCategory, p.ProductCode, d.[Year]
),
b AS (
    SELECT  cy.ProductCategory,
            cy.Qty AS QtyCY, py.Qty AS QtyPY,
            cy.NetSales / NULLIF(cy.Qty, 0) AS PriceCY, py.NetSales / NULLIF(py.Qty, 0) AS PricePY,
            cy.COGS / NULLIF(cy.Qty, 0)     AS CostCY,  py.COGS / NULLIF(py.Qty, 0)     AS CostPY
    FROM a cy
    JOIN a py ON py.ProductCode = cy.ProductCode AND py.[Year] = 2024
    WHERE cy.[Year] = 2025
)
SELECT  ProductCategory,
        CAST(SUM((QtyCY - QtyPY) * (PricePY - CostPY)) AS DECIMAL(18,0)) AS VolumeEffect,
        CAST(SUM(QtyCY * (PriceCY - PricePY))          AS DECIMAL(18,0)) AS PriceEffect,
        CAST(SUM(-QtyCY * (CostCY - CostPY))           AS DECIMAL(18,0)) AS CostEffect,
        CAST(SUM(QtyCY * (PriceCY - CostCY) - QtyPY * (PricePY - CostPY)) AS DECIMAL(18,0)) AS TotalMarginChange
FROM b
GROUP BY ProductCategory
ORDER BY TotalMarginChange DESC;

/* 6. Ricavo medio per cliente attivo e numero clienti per anno e mercato */
SELECT  d.[Year], cu.Market,
        COUNT(DISTINCT f.CustomerKey)                                  AS ActiveCustomers,
        SUM(f.NetAmount)                                               AS NetSales,
        CAST(SUM(f.NetAmount) / COUNT(DISTINCT f.CustomerKey) AS DECIMAL(18,0)) AS RevenuePerCustomer
FROM dw.FactSales f
JOIN dw.DimCustomer cu ON cu.CustomerKey = f.CustomerKey
JOIN dw.DimDate d      ON d.DateKey      = f.DateKey
GROUP BY d.[Year], cu.Market
ORDER BY d.[Year], cu.Market;

/* 7. Costi operativi per centro di costo: incidenza sui ricavi e variazione vs anno precedente */
WITH oc AS (
    SELECT  d.[Year], cc.CostCenterName, SUM(f.Amount) AS Opex
    FROM dw.FactPL f
    JOIN dw.DimAccount    a  ON a.AccountKey    = f.AccountKey
    JOIN dw.DimCostCenter cc ON cc.CostCenterKey = f.CostCenterKey
    JOIN dw.DimDate       d  ON d.DateKey       = f.DateKey
    WHERE a.PLLineKey BETWEEN 4 AND 8
    GROUP BY d.[Year], cc.CostCenterName
)
SELECT  [Year], CostCenterName, Opex,
        LAG(Opex) OVER (PARTITION BY CostCenterName ORDER BY [Year])  AS OpexPY,
        CAST((Opex / NULLIF(LAG(Opex) OVER (PARTITION BY CostCenterName ORDER BY [Year]), 0) - 1) * 100
             AS DECIMAL(6,1))                                         AS DeltaPct
FROM oc
ORDER BY CostCenterName, [Year];

/* 8. Sconto medio concesso per segmento cliente (leva per il margine) */
SELECT  d.[Year], cu.CustomerSegment,
        CAST(SUM(f.DiscountAmount) * 100.0 / NULLIF(SUM(f.GrossAmount), 0) AS DECIMAL(5,1)) AS AvgDiscountPct
FROM dw.FactSales f
JOIN dw.DimCustomer cu ON cu.CustomerKey = f.CustomerKey
JOIN dw.DimDate d      ON d.DateKey      = f.DateKey
WHERE f.DocumentType = 'FT'
GROUP BY d.[Year], cu.CustomerSegment
ORDER BY cu.CustomerSegment, d.[Year];
GO
