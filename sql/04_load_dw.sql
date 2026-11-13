/* =============================================================================
   Script 04 - caricamento modello a stella (stg -> dw)
   Procedura dw.usp_LoadPL: full reload, idempotente, in un'unica transazione.
   ============================================================================= */
USE FinancePL;
GO

CREATE OR ALTER PROCEDURE dw.usp_LoadPL
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    BEGIN TRY
        BEGIN TRANSACTION;

        /* svuoto i fatti prima delle dimensioni (FK) */
        TRUNCATE TABLE dw.FactSales;
        TRUNCATE TABLE dw.FactPL;
        DELETE FROM dw.DimCustomer;   DBCC CHECKIDENT ('dw.DimCustomer', RESEED, 0) WITH NO_INFOMSGS;
        DELETE FROM dw.DimProduct;    DBCC CHECKIDENT ('dw.DimProduct', RESEED, 0) WITH NO_INFOMSGS;
        DELETE FROM dw.DimSalesRep;   DBCC CHECKIDENT ('dw.DimSalesRep', RESEED, 0) WITH NO_INFOMSGS;
        DELETE FROM dw.DimAccount;    DBCC CHECKIDENT ('dw.DimAccount', RESEED, 0) WITH NO_INFOMSGS;
        DELETE FROM dw.DimCostCenter; DBCC CHECKIDENT ('dw.DimCostCenter', RESEED, 0) WITH NO_INFOMSGS;
        DELETE FROM dw.DimPLLine;

        /* ---------------- dimensioni ---------------- */
        INSERT INTO dw.DimCustomer (CustomerCode, CustomerName, CustomerSegment, City, Province, Region,
                                    SalesArea, Country, CountryCode, Market, PaymentTerms, CustomerSince)
        SELECT  LTRIM(RTRIM(CustomerCode)),
                LTRIM(RTRIM(CustomerName)),
                CustomerSegment,
                NULLIF(City, N''),
                NULLIF(Province, N''),
                NULLIF(Region, N''),
                SalesArea,
                Country,
                CountryCode,
                CASE WHEN CountryCode = N'IT' THEN N'Italia' ELSE N'Estero' END,
                PaymentTerms,
                TRY_CONVERT(DATE, CustomerSince)
        FROM stg.Customers;

        -- membro "sconosciuto" per eventuali codici non in anagrafica
        SET IDENTITY_INSERT dw.DimCustomer ON;
        INSERT INTO dw.DimCustomer (CustomerKey, CustomerCode, CustomerName, CustomerSegment, SalesArea, Country, CountryCode, Market)
        VALUES (-1, N'N/D', N'Cliente non definito', N'N/D', N'N/D', N'N/D', N'ND', N'N/D');
        SET IDENTITY_INSERT dw.DimCustomer OFF;

        INSERT INTO dw.DimProduct (ProductCode, ProductName, ProductCategory, ProductSubcategory,
                                   UnitOfMeasure, LaunchDate, IsActive)
        SELECT ProductCode, ProductName, ProductCategory, ProductSubcategory, UnitOfMeasure,
               TRY_CONVERT(DATE, LaunchDate), TRY_CONVERT(BIT, IsActive)
        FROM stg.Products;

        SET IDENTITY_INSERT dw.DimProduct ON;
        INSERT INTO dw.DimProduct (ProductKey, ProductCode, ProductName, ProductCategory, ProductSubcategory, UnitOfMeasure, IsActive)
        VALUES (-1, N'N/D', N'Articolo non definito', N'N/D', N'N/D', N'PZ', 0);
        SET IDENTITY_INSERT dw.DimProduct OFF;

        INSERT INTO dw.DimSalesRep (SalesRepID, SalesRepName, SalesArea)
        SELECT TRY_CONVERT(INT, SalesRepID), SalesRepName, SalesArea
        FROM stg.SalesReps;

        INSERT INTO dw.DimPLLine (PLLineKey, PLLineName, LineType, SortOrder, IsBold) VALUES
            ( 1, N'Ricavi netti',                  N'Detail',   10, 1),
            ( 2, N'Costo del venduto',             N'Detail',   20, 0),
            ( 3, N'MARGINE LORDO',                 N'Subtotal', 30, 1),
            ( 4, N'Costo del personale',           N'Detail',   40, 0),
            ( 5, N'Servizi',                       N'Detail',   50, 0),
            ( 6, N'Godimento beni di terzi',       N'Detail',   60, 0),
            ( 7, N'Costi commerciali',             N'Detail',   70, 0),
            ( 8, N'Altri costi operativi',         N'Detail',   80, 0),
            ( 9, N'EBITDA',                        N'Subtotal', 90, 1),
            (10, N'Ammortamenti',                  N'Detail',  100, 0),
            (11, N'EBIT - RISULTATO OPERATIVO',    N'Subtotal',110, 1);

        INSERT INTO dw.DimAccount (AccountCode, AccountName, PLSection, PLSubsection, PLLineKey, PLSign, SortOrder)
        SELECT  a.AccountCode,
                a.AccountName,
                a.PLSection,
                a.PLSubsection,
                CASE a.PLSubsection
                    WHEN N'Ricavi netti'            THEN 1
                    WHEN N'COGS'                    THEN 2
                    WHEN N'Personale'               THEN 4
                    WHEN N'Servizi'                 THEN 5
                    WHEN N'Godimento beni di terzi' THEN 6
                    WHEN N'Costi commerciali'       THEN 7
                    WHEN N'Altri costi'             THEN 8
                    WHEN N'D&A'                     THEN 10
                END,
                TRY_CONVERT(SMALLINT, a.PLSign),
                TRY_CONVERT(INT, a.SortOrder)
        FROM stg.ChartOfAccounts a;

        INSERT INTO dw.DimCostCenter (CostCenterCode, CostCenterName, CostCenterGroup)
        SELECT CostCenterCode, CostCenterName, CostCenterGroup
        FROM stg.CostCenters;

        /* ---------------- FactSales ---------------- */
        INSERT INTO dw.FactSales (DateKey, CustomerKey, ProductKey, SalesRepKey, DocumentNumber, DocumentLine,
                                  DocumentType, Quantity, UnitListPrice, DiscountPct, GrossAmount,
                                  DiscountAmount, NetAmount, UnitStandardCost, COGSAmount)
        SELECT  CONVERT(INT, CONVERT(CHAR(8), TRY_CONVERT(DATE, s.DocumentDate), 112)),
                ISNULL(c.CustomerKey, -1),
                ISNULL(p.ProductKey, -1),
                r.SalesRepKey,
                s.DocumentNumber,
                TRY_CONVERT(SMALLINT, s.DocumentLine),
                s.DocumentType,
                TRY_CONVERT(INT, s.Quantity),
                TRY_CONVERT(DECIMAL(18,2), s.UnitListPrice),
                TRY_CONVERT(DECIMAL(5,2),  s.DiscountPct),
                TRY_CONVERT(DECIMAL(18,2), s.GrossAmount),
                TRY_CONVERT(DECIMAL(18,2), s.DiscountAmount),
                TRY_CONVERT(DECIMAL(18,2), s.NetAmount),
                TRY_CONVERT(DECIMAL(18,2), s.UnitStandardCost),
                TRY_CONVERT(DECIMAL(18,2), s.COGSAmount)
        FROM stg.SalesInvoiceLines s
        LEFT JOIN dw.DimCustomer c ON c.CustomerCode = s.CustomerCode
        LEFT JOIN dw.DimProduct  p ON p.ProductCode  = s.ProductCode
        JOIN dw.DimSalesRep      r ON r.SalesRepID   = TRY_CONVERT(INT, s.SalesRepID);

        /* ---------------- FactPL ----------------
           1) ricavi e costo del venduto: sintesi giornaliera di FactSales,
              centro di costo commerciale Italia / Export in base al mercato del cliente
           2) costi operativi e ammortamenti da contabilita' generale            */
        ;WITH SalesDaily AS (
            SELECT  f.DateKey,
                    CASE WHEN c.Market = N'Estero' THEN N'CC310' ELSE N'CC300' END AS CostCenterCode,
                    SUM(f.NetAmount)  AS NetAmount,
                    SUM(f.COGSAmount) AS COGSAmount
            FROM dw.FactSales f
            JOIN dw.DimCustomer c ON c.CustomerKey = f.CustomerKey
            GROUP BY f.DateKey, CASE WHEN c.Market = N'Estero' THEN N'CC310' ELSE N'CC300' END
        )
        INSERT INTO dw.FactPL (DateKey, AccountKey, CostCenterKey, SourceSystem, Amount, SignedAmount)
        SELECT sd.DateKey, a.AccountKey, cc.CostCenterKey, N'SALES',
               v.Amount, v.Amount * a.PLSign
        FROM SalesDaily sd
        CROSS APPLY (VALUES ('410000', sd.NetAmount), ('510000', sd.COGSAmount)) v(AccountCode, Amount)
        JOIN dw.DimAccount    a  ON a.AccountCode     = v.AccountCode
        JOIN dw.DimCostCenter cc ON cc.CostCenterCode = sd.CostCenterCode;

        INSERT INTO dw.FactPL (DateKey, AccountKey, CostCenterKey, SourceSystem, Amount, SignedAmount)
        SELECT  CONVERT(INT, CONVERT(CHAR(8), TRY_CONVERT(DATE, g.PostingDate), 112)),
                a.AccountKey,
                cc.CostCenterKey,
                N'GL',
                SUM(TRY_CONVERT(DECIMAL(18,2), g.Amount)),
                SUM(TRY_CONVERT(DECIMAL(18,2), g.Amount)) * a.PLSign
        FROM stg.GLEntries g
        JOIN dw.DimAccount    a  ON a.AccountCode     = g.AccountCode
        JOIN dw.DimCostCenter cc ON cc.CostCenterCode = g.CostCenterCode
        GROUP BY CONVERT(INT, CONVERT(CHAR(8), TRY_CONVERT(DATE, g.PostingDate), 112)),
                 a.AccountKey, cc.CostCenterKey, a.PLSign;

        COMMIT TRANSACTION;

        SELECT 'dw.FactSales' AS TableName, COUNT_BIG(*) AS RowsLoaded FROM dw.FactSales
        UNION ALL SELECT 'dw.FactPL', COUNT_BIG(*) FROM dw.FactPL
        UNION ALL SELECT 'dw.DimCustomer', COUNT_BIG(*) FROM dw.DimCustomer
        UNION ALL SELECT 'dw.DimProduct', COUNT_BIG(*) FROM dw.DimProduct;
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION;
        THROW;
    END CATCH
END;
GO

EXEC dw.usp_LoadPL;
GO
