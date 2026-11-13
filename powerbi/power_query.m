// =============================================================================
//  Power Query (M) - query del modello
//  Parametri (Gestisci parametri): ServerName, DatabaseName
//  Tutte le tabelle arrivano dalle viste dello schema rpt -> query folding
//  completo, nessuna trasformazione pesante lato Power BI.
// =============================================================================

// ---- Parametri ---------------------------------------------------------------
// ServerName   = "localhost"        meta [IsParameterQuery = true, Type = "Text"]
// DatabaseName = "FinancePL"        meta [IsParameterQuery = true, Type = "Text"]


// ---- fnGetView: funzione di supporto per leggere una vista rpt ---------------
(ViewName as text) as table =>
let
    Source = Sql.Database(ServerName, DatabaseName),
    View   = Source{[Schema = "rpt", Item = ViewName]}[Data]
in
    View


// ---- Calendar ----------------------------------------------------------------
let
    Source = fnGetView("Calendar"),
    Types  = Table.TransformColumnTypes(Source, {
                {"Date", type date}, {"Year", Int64.Type}, {"Quarter", Int64.Type},
                {"Month", Int64.Type}, {"YearMonth", Int64.Type}, {"IsWorkingDay", type logical}}),
    // colonna di ordinamento per i mesi (MonthShort ordinata per Month nel modello)
    AddFiscalLabel = Table.AddColumn(Types, "YearQuarter",
                each Text.From([Year]) & " " & [QuarterLabel], type text)
in
    AddFiscalLabel


// ---- Customer ----------------------------------------------------------------
let
    Source  = fnGetView("Customer"),
    // per i clienti esteri la regione e' vuota: la sostituisco con il paese
    Region  = Table.ReplaceValue(Source, null, each [Country], Replacer.ReplaceValue, {"Region"}),
    Tenure  = Table.AddColumn(Region, "CustomerTenureYears",
                each if [CustomerSince] = null then null
                     else Number.RoundDown(Duration.Days(#date(2025, 12, 31) - [CustomerSince]) / 365.25),
                Int64.Type)
in
    Tenure


// ---- Product -----------------------------------------------------------------
let
    Source = fnGetView("Product")
in
    Source


// ---- SalesRep / Account / CostCenter / PLLayout ------------------------------
let Source = fnGetView("SalesRep")   in Source
let Source = fnGetView("Account")    in Source
let Source = fnGetView("CostCenter") in Source
let
    Source = fnGetView("PLLayout"),
    Types  = Table.TransformColumnTypes(Source, {{"IsBold", type logical}})
in
    Types


// ---- FactSales ---------------------------------------------------------------
let
    Source = fnGetView("FactSales"),
    Types  = Table.TransformColumnTypes(Source, {
                {"Quantity", Int64.Type},
                {"GrossAmount", Currency.Type}, {"DiscountAmount", Currency.Type},
                {"NetAmount", Currency.Type},   {"COGSAmount", Currency.Type}})
in
    Types


// ---- FactPL ------------------------------------------------------------------
let
    Source = fnGetView("FactPL"),
    Types  = Table.TransformColumnTypes(Source, {
                {"Amount", Currency.Type}, {"SignedAmount", Currency.Type}})
in
    Types


// ---- _Measures (tabella vuota che contiene solo le misure) -------------------
let
    Source = #table(type table [Dummy = text], {})
in
    Source
