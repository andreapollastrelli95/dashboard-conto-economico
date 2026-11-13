/* =============================================================================
   Script 03 - caricamento CSV in staging (BULK INSERT)
   Prima di eseguire: impostare @DataPath con la cartella "data" del repository.
   Nota: il percorso deve essere visibile dal servizio SQL Server, non dal client.
   FORMAT = 'CSV' richiede SQL Server 2017 o successivo.
   ============================================================================= */
USE FinancePL;
GO
SET NOCOUNT ON;

DECLARE @DataPath NVARCHAR(400) = N'C:\Projects\dashboard-conto-economico\data\';   -- <-- modificare
DECLARE @sql NVARCHAR(MAX);

DECLARE @files TABLE (TableName SYSNAME, FileName NVARCHAR(200));
INSERT INTO @files VALUES
    (N'stg.Customers',          N'customers.csv'),
    (N'stg.Products',           N'products.csv'),
    (N'stg.SalesReps',          N'sales_reps.csv'),
    (N'stg.ChartOfAccounts',    N'chart_of_accounts.csv'),
    (N'stg.CostCenters',        N'cost_centers.csv'),
    (N'stg.SalesInvoiceLines',  N'sales_invoice_lines.csv'),
    (N'stg.GLEntries',          N'gl_entries.csv');

DECLARE @t SYSNAME, @f NVARCHAR(200);
DECLARE cur CURSOR LOCAL FAST_FORWARD FOR SELECT TableName, FileName FROM @files;
OPEN cur;
FETCH NEXT FROM cur INTO @t, @f;
WHILE @@FETCH_STATUS = 0
BEGIN
    SET @sql = N'TRUNCATE TABLE ' + @t + N';
    BULK INSERT ' + @t + N'
    FROM ''' + @DataPath + @f + N'''
    WITH (FORMAT = ''CSV'', FIRSTROW = 2, FIELDTERMINATOR = '','', ROWTERMINATOR = ''0x0a'',
          CODEPAGE = ''65001'', FIELDQUOTE = ''"'', TABLOCK);';
    EXEC sys.sp_executesql @sql;
    PRINT CONCAT(@t, N' caricata');
    FETCH NEXT FROM cur INTO @t, @f;
END;
CLOSE cur;
DEALLOCATE cur;

-- conteggio righe caricate
SELECT 'stg.SalesInvoiceLines' AS TableName, COUNT(*) AS RowsLoaded FROM stg.SalesInvoiceLines
UNION ALL SELECT 'stg.GLEntries',       COUNT(*) FROM stg.GLEntries
UNION ALL SELECT 'stg.Customers',       COUNT(*) FROM stg.Customers
UNION ALL SELECT 'stg.Products',        COUNT(*) FROM stg.Products
UNION ALL SELECT 'stg.SalesReps',       COUNT(*) FROM stg.SalesReps
UNION ALL SELECT 'stg.ChartOfAccounts', COUNT(*) FROM stg.ChartOfAccounts
UNION ALL SELECT 'stg.CostCenters',     COUNT(*) FROM stg.CostCenters;
GO
