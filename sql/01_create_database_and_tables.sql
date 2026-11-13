/* =============================================================================
   Progetto : Dashboard Conto Economico e Performance Aziendale
   Azienda  : Officine Meccaniche Valdarno S.p.A. (dati simulati)
   Script   : 01 - creazione database, schemi e tabelle
   Target   : SQL Server 2019 o successivo

   Struttura a tre livelli:
     stg  -> copia "grezza" degli estratti ERP (tutto NVARCHAR, nessun vincolo)
     dw   -> modello a stella (dimensioni + fatti) con chiavi surrogate
     rpt  -> viste di reporting lette da Power BI
   ============================================================================= */

IF DB_ID(N'FinancePL') IS NULL
    CREATE DATABASE FinancePL;
GO

USE FinancePL;
GO

IF SCHEMA_ID(N'stg') IS NULL EXEC (N'CREATE SCHEMA stg AUTHORIZATION dbo;');
IF SCHEMA_ID(N'dw')  IS NULL EXEC (N'CREATE SCHEMA dw  AUTHORIZATION dbo;');
IF SCHEMA_ID(N'rpt') IS NULL EXEC (N'CREATE SCHEMA rpt AUTHORIZATION dbo;');
GO

/* -----------------------------------------------------------------------------
   STAGING
   ----------------------------------------------------------------------------- */
DROP TABLE IF EXISTS stg.SalesInvoiceLines;
CREATE TABLE stg.SalesInvoiceLines (
    DocumentNumber      NVARCHAR(30),
    DocumentLine        NVARCHAR(10),
    DocumentDate        NVARCHAR(20),
    DocumentType        NVARCHAR(5),
    CustomerCode        NVARCHAR(20),
    ProductCode         NVARCHAR(20),
    SalesRepID          NVARCHAR(10),
    Quantity            NVARCHAR(20),
    UnitListPrice       NVARCHAR(30),
    DiscountPct         NVARCHAR(20),
    GrossAmount         NVARCHAR(30),
    DiscountAmount      NVARCHAR(30),
    NetAmount           NVARCHAR(30),
    UnitStandardCost    NVARCHAR(30),
    COGSAmount          NVARCHAR(30),
    CurrencyCode        NVARCHAR(5)
);

DROP TABLE IF EXISTS stg.GLEntries;
CREATE TABLE stg.GLEntries (
    GLEntryID       NVARCHAR(20),
    JournalNumber   NVARCHAR(30),
    PostingDate     NVARCHAR(20),
    AccountCode     NVARCHAR(10),
    CostCenterCode  NVARCHAR(10),
    Amount          NVARCHAR(30),
    Description     NVARCHAR(200),
    VendorName      NVARCHAR(200)
);

DROP TABLE IF EXISTS stg.Customers;
CREATE TABLE stg.Customers (
    CustomerID      NVARCHAR(10),
    CustomerCode    NVARCHAR(20),
    CustomerName    NVARCHAR(200),
    CustomerSegment NVARCHAR(50),
    City            NVARCHAR(100),
    Province        NVARCHAR(5),
    Region          NVARCHAR(100),
    SalesArea       NVARCHAR(50),
    Country         NVARCHAR(100),
    CountryCode     NVARCHAR(5),
    SalesRepID      NVARCHAR(10),
    PaymentTerms    NVARCHAR(50),
    CustomerSince   NVARCHAR(20)
);

DROP TABLE IF EXISTS stg.Products;
CREATE TABLE stg.Products (
    ProductID           NVARCHAR(10),
    ProductCode         NVARCHAR(20),
    ProductName         NVARCHAR(200),
    ProductCategory     NVARCHAR(100),
    ProductSubcategory  NVARCHAR(100),
    UnitOfMeasure       NVARCHAR(5),
    ListPrice2023       NVARCHAR(30),
    StandardCost2023    NVARCHAR(30),
    LaunchDate          NVARCHAR(20),
    IsActive            NVARCHAR(5)
);

DROP TABLE IF EXISTS stg.SalesReps;
CREATE TABLE stg.SalesReps (
    SalesRepID      NVARCHAR(10),
    SalesRepName    NVARCHAR(100),
    SalesArea       NVARCHAR(50)
);

DROP TABLE IF EXISTS stg.ChartOfAccounts;
CREATE TABLE stg.ChartOfAccounts (
    AccountCode     NVARCHAR(10),
    AccountName     NVARCHAR(200),
    PLSection       NVARCHAR(100),
    PLSubsection    NVARCHAR(100),
    SortOrder       NVARCHAR(10),
    PLSign          NVARCHAR(5)
);

DROP TABLE IF EXISTS stg.CostCenters;
CREATE TABLE stg.CostCenters (
    CostCenterCode  NVARCHAR(10),
    CostCenterName  NVARCHAR(100),
    CostCenterGroup NVARCHAR(50)
);
GO

/* -----------------------------------------------------------------------------
   DATA WAREHOUSE - prima i fatti (per poter droppare le FK), poi le dimensioni
   ----------------------------------------------------------------------------- */
DROP TABLE IF EXISTS dw.FactSales;
DROP TABLE IF EXISTS dw.FactPL;
DROP TABLE IF EXISTS dw.DimCustomer;
DROP TABLE IF EXISTS dw.DimProduct;
DROP TABLE IF EXISTS dw.DimSalesRep;
DROP TABLE IF EXISTS dw.DimAccount;
DROP TABLE IF EXISTS dw.DimPLLine;
DROP TABLE IF EXISTS dw.DimCostCenter;
DROP TABLE IF EXISTS dw.DimDate;
GO

CREATE TABLE dw.DimDate (
    DateKey             INT          NOT NULL CONSTRAINT PK_DimDate PRIMARY KEY,   -- yyyymmdd
    [Date]              DATE         NOT NULL,
    [Year]              SMALLINT     NOT NULL,
    [Quarter]           TINYINT      NOT NULL,
    QuarterLabel        CHAR(2)      NOT NULL,     -- Q1..Q4
    [Month]             TINYINT      NOT NULL,
    MonthName           NVARCHAR(15) NOT NULL,     -- Gennaio ...
    MonthShort          NVARCHAR(3)  NOT NULL,     -- Gen ...
    YearMonth           INT          NOT NULL,     -- 202501
    YearMonthLabel      NVARCHAR(10) NOT NULL,     -- Gen 2025
    WeekOfYear          TINYINT      NOT NULL,     -- ISO
    DayOfWeek           TINYINT      NOT NULL,     -- 1 = lunedi'
    DayName             NVARCHAR(10) NOT NULL,
    IsWeekend           BIT          NOT NULL,
    IsHoliday           BIT          NOT NULL,
    IsWorkingDay        BIT          NOT NULL,
    MonthStartDate      DATE         NOT NULL,
    MonthEndDate        DATE         NOT NULL
);

CREATE TABLE dw.DimCustomer (
    CustomerKey         INT IDENTITY(1,1) NOT NULL CONSTRAINT PK_DimCustomer PRIMARY KEY,
    CustomerCode        NVARCHAR(20)  NOT NULL CONSTRAINT UQ_DimCustomer_Code UNIQUE,
    CustomerName        NVARCHAR(200) NOT NULL,
    CustomerSegment     NVARCHAR(50)  NOT NULL,
    City                NVARCHAR(100) NULL,
    Province            NVARCHAR(5)   NULL,
    Region              NVARCHAR(100) NULL,
    SalesArea           NVARCHAR(50)  NOT NULL,
    Country             NVARCHAR(100) NOT NULL,
    CountryCode         CHAR(2)       NOT NULL,
    Market              NVARCHAR(10)  NOT NULL,      -- Italia / Estero
    PaymentTerms        NVARCHAR(50)  NULL,
    CustomerSince       DATE          NULL
);

CREATE TABLE dw.DimProduct (
    ProductKey          INT IDENTITY(1,1) NOT NULL CONSTRAINT PK_DimProduct PRIMARY KEY,
    ProductCode         NVARCHAR(20)  NOT NULL CONSTRAINT UQ_DimProduct_Code UNIQUE,
    ProductName         NVARCHAR(200) NOT NULL,
    ProductCategory     NVARCHAR(100) NOT NULL,
    ProductSubcategory  NVARCHAR(100) NOT NULL,
    UnitOfMeasure       NVARCHAR(5)   NOT NULL,
    LaunchDate          DATE          NULL,
    IsActive            BIT           NOT NULL
);

CREATE TABLE dw.DimSalesRep (
    SalesRepKey         INT IDENTITY(1,1) NOT NULL CONSTRAINT PK_DimSalesRep PRIMARY KEY,
    SalesRepID          INT           NOT NULL CONSTRAINT UQ_DimSalesRep_ID UNIQUE,
    SalesRepName        NVARCHAR(100) NOT NULL,
    SalesArea           NVARCHAR(50)  NOT NULL
);

-- righe del conto economico riclassificato (dettagli + subtotali)
CREATE TABLE dw.DimPLLine (
    PLLineKey           INT           NOT NULL CONSTRAINT PK_DimPLLine PRIMARY KEY,
    PLLineName          NVARCHAR(100) NOT NULL,
    LineType            NVARCHAR(10)  NOT NULL,      -- Detail / Subtotal
    SortOrder           INT           NOT NULL,
    IsBold              BIT           NOT NULL
);

CREATE TABLE dw.DimAccount (
    AccountKey          INT IDENTITY(1,1) NOT NULL CONSTRAINT PK_DimAccount PRIMARY KEY,
    AccountCode         CHAR(6)       NOT NULL CONSTRAINT UQ_DimAccount_Code UNIQUE,
    AccountName         NVARCHAR(200) NOT NULL,
    PLSection           NVARCHAR(100) NOT NULL,
    PLSubsection        NVARCHAR(100) NOT NULL,
    PLLineKey           INT           NOT NULL CONSTRAINT FK_DimAccount_PLLine REFERENCES dw.DimPLLine(PLLineKey),
    PLSign              SMALLINT      NOT NULL,      -- +1 ricavi, -1 costi
    SortOrder           INT           NOT NULL
);

CREATE TABLE dw.DimCostCenter (
    CostCenterKey       INT IDENTITY(1,1) NOT NULL CONSTRAINT PK_DimCostCenter PRIMARY KEY,
    CostCenterCode      NVARCHAR(10)  NOT NULL CONSTRAINT UQ_DimCostCenter_Code UNIQUE,
    CostCenterName      NVARCHAR(100) NOT NULL,
    CostCenterGroup     NVARCHAR(50)  NOT NULL
);

-- grain: riga documento di vendita (fattura o nota di credito)
CREATE TABLE dw.FactSales (
    SalesLineKey        BIGINT IDENTITY(1,1) NOT NULL CONSTRAINT PK_FactSales PRIMARY KEY NONCLUSTERED,
    DateKey             INT           NOT NULL CONSTRAINT FK_FactSales_Date     REFERENCES dw.DimDate(DateKey),
    CustomerKey         INT           NOT NULL CONSTRAINT FK_FactSales_Customer REFERENCES dw.DimCustomer(CustomerKey),
    ProductKey          INT           NOT NULL CONSTRAINT FK_FactSales_Product  REFERENCES dw.DimProduct(ProductKey),
    SalesRepKey         INT           NOT NULL CONSTRAINT FK_FactSales_SalesRep REFERENCES dw.DimSalesRep(SalesRepKey),
    DocumentNumber      NVARCHAR(30)  NOT NULL,
    DocumentLine        SMALLINT      NOT NULL,
    DocumentType        CHAR(2)       NOT NULL,      -- FT fattura, NC nota credito
    Quantity            INT           NOT NULL,
    UnitListPrice       DECIMAL(18,2) NOT NULL,
    DiscountPct         DECIMAL(5,2)  NOT NULL,
    GrossAmount         DECIMAL(18,2) NOT NULL,
    DiscountAmount      DECIMAL(18,2) NOT NULL,
    NetAmount           DECIMAL(18,2) NOT NULL,
    UnitStandardCost    DECIMAL(18,2) NOT NULL,
    COGSAmount          DECIMAL(18,2) NOT NULL
);

-- grain: giorno x conto x centro di costo. Contiene sia ricavi/COGS (sintesi da FactSales)
-- sia i costi da contabilita' generale. Amount sempre in segno "naturale" (costi positivi),
-- SignedAmount con segno da conto economico (ricavi +, costi -).
CREATE TABLE dw.FactPL (
    PLEntryKey          BIGINT IDENTITY(1,1) NOT NULL CONSTRAINT PK_FactPL PRIMARY KEY NONCLUSTERED,
    DateKey             INT           NOT NULL CONSTRAINT FK_FactPL_Date       REFERENCES dw.DimDate(DateKey),
    AccountKey          INT           NOT NULL CONSTRAINT FK_FactPL_Account    REFERENCES dw.DimAccount(AccountKey),
    CostCenterKey       INT           NOT NULL CONSTRAINT FK_FactPL_CostCenter REFERENCES dw.DimCostCenter(CostCenterKey),
    SourceSystem        NVARCHAR(10)  NOT NULL,      -- SALES / GL
    Amount              DECIMAL(18,2) NOT NULL,
    SignedAmount        DECIMAL(18,2) NOT NULL
);
GO

-- columnstore sui fatti: compressione e scansioni veloci per le query aggregate
CREATE CLUSTERED COLUMNSTORE INDEX CCI_FactSales ON dw.FactSales;
CREATE CLUSTERED COLUMNSTORE INDEX CCI_FactPL    ON dw.FactPL;
GO
