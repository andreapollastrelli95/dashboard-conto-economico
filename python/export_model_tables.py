# -----------------------------------------------------------------------------
# Esporta le tabelle del modello Power BI in CSV (cartella data/model).
# Replica la logica degli script SQL 04-05 (schema dw / viste rpt), per poter
# usare il report anche senza SQL Server: Power Query legge questi file.
# -----------------------------------------------------------------------------
import os
import pandas as pd

BASE = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "data")
OUT = os.path.join(BASE, "model")
os.makedirs(OUT, exist_ok=True)

MESI = ["Gennaio", "Febbraio", "Marzo", "Aprile", "Maggio", "Giugno", "Luglio", "Agosto",
        "Settembre", "Ottobre", "Novembre", "Dicembre"]

# calendario
d = pd.DataFrame({"Date": pd.date_range("2023-01-01", "2025-12-31")})
d["DateKey"] = d.Date.dt.strftime("%Y%m%d").astype(int)
d["Year"] = d.Date.dt.year
d["Quarter"] = "Q" + d.Date.dt.quarter.astype(str)
d["Month"] = d.Date.dt.month
d["MonthName"] = d.Month.map(lambda m: MESI[m - 1])
d["MonthShort"] = d.MonthName.str[:3]
d["YearMonth"] = d.Year * 100 + d.Month
d["YearMonthLabel"] = d.MonthShort + " " + d.Year.astype(str)
d["Date"] = d.Date.dt.strftime("%Y-%m-%d")
d[["DateKey", "Date", "Year", "Quarter", "Month", "MonthName", "MonthShort", "YearMonth", "YearMonthLabel"]] \
    .to_csv(os.path.join(OUT, "calendar.csv"), index=False)

cust = pd.read_csv(os.path.join(BASE, "customers.csv"))
cust["Market"] = cust.CountryCode.map(lambda c: "Italia" if c == "IT" else "Estero")
cust["Region"] = cust.Region.fillna(cust.Country)
cust[["CustomerID", "CustomerCode", "CustomerName", "CustomerSegment", "Region", "SalesArea", "Country", "Market"]] \
    .rename(columns={"CustomerID": "CustomerKey"}).to_csv(os.path.join(OUT, "customer.csv"), index=False)

prod = pd.read_csv(os.path.join(BASE, "products.csv"))
prod[["ProductID", "ProductCode", "ProductName", "ProductCategory", "ProductSubcategory"]] \
    .rename(columns={"ProductID": "ProductKey"}).to_csv(os.path.join(OUT, "product.csv"), index=False)

reps = pd.read_csv(os.path.join(BASE, "sales_reps.csv"))
reps.rename(columns={"SalesRepID": "SalesRepKey"}).to_csv(os.path.join(OUT, "sales_rep.csv"), index=False)

layout = pd.DataFrame([
    (1, "Ricavi netti", "Detail", 10), (2, "Costo del venduto", "Detail", 20), (3, "MARGINE LORDO", "Subtotal", 30),
    (4, "Costo del personale", "Detail", 40), (5, "Servizi", "Detail", 50), (6, "Godimento beni di terzi", "Detail", 60),
    (7, "Costi commerciali", "Detail", 70), (8, "Altri costi operativi", "Detail", 80), (9, "EBITDA", "Subtotal", 90),
    (10, "Ammortamenti", "Detail", 100), (11, "EBIT - RISULTATO OPERATIVO", "Subtotal", 110)],
    columns=["PLLineKey", "PLLineName", "LineType", "SortOrder"])
layout.to_csv(os.path.join(OUT, "pl_layout.csv"), index=False)

acc = pd.read_csv(os.path.join(BASE, "chart_of_accounts.csv"), dtype={"AccountCode": str})
sub_to_line = {"Ricavi netti": 1, "COGS": 2, "Personale": 4, "Servizi": 5, "Godimento beni di terzi": 6,
               "Costi commerciali": 7, "Altri costi": 8, "D&A": 10}
acc["PLLineKey"] = acc.PLSubsection.map(sub_to_line)
acc.insert(0, "AccountKey", range(1, len(acc) + 1))
acc["Account"] = acc.AccountCode + " - " + acc.AccountName
acc[["AccountKey", "AccountCode", "Account", "PLSection", "PLSubsection", "PLLineKey", "PLSign", "SortOrder"]] \
    .to_csv(os.path.join(OUT, "account.csv"), index=False)

cc = pd.read_csv(os.path.join(BASE, "cost_centers.csv"))
cc.insert(0, "CostCenterKey", range(1, len(cc) + 1))
cc.to_csv(os.path.join(OUT, "cost_center.csv"), index=False)

# FactSales
s = pd.read_csv(os.path.join(BASE, "sales_invoice_lines.csv"))
s["DateKey"] = s.DocumentDate.str.replace("-", "").astype(int)
s = s.merge(cust[["CustomerID", "CustomerCode", "Market"]], on="CustomerCode") \
     .merge(prod[["ProductID", "ProductCode"]], on="ProductCode")
s.rename(columns={"CustomerID": "CustomerKey", "ProductID": "ProductKey", "SalesRepID": "SalesRepKey"}) \
 [["DateKey", "CustomerKey", "ProductKey", "SalesRepKey", "DocumentNumber", "DocumentType", "Quantity",
   "GrossAmount", "DiscountAmount", "NetAmount", "COGSAmount"]].to_csv(os.path.join(OUT, "fact_sales.csv"), index=False)

# FactPL: ricavi e costo standard da vendite + contabilita' generale
akey = acc.set_index("AccountCode").AccountKey
asign = acc.set_index("AccountCode").PLSign
ckey = cc.set_index("CostCenterCode").CostCenterKey
s["CostCenterCode"] = s.Market.map({"Italia": "CC300", "Estero": "CC310"})
sd = s.groupby(["DateKey", "CostCenterCode"])[["NetAmount", "COGSAmount"]].sum().reset_index()
rows = []
for acc_code, col in (("410000", "NetAmount"), ("510000", "COGSAmount")):
    t = sd[["DateKey", "CostCenterCode", col]].rename(columns={col: "Amount"})
    t["AccountCode"] = acc_code
    t["SourceSystem"] = "SALES"
    rows.append(t)
g = pd.read_csv(os.path.join(BASE, "gl_entries.csv"), dtype={"AccountCode": str})
g["DateKey"] = g.PostingDate.str.replace("-", "").astype(int)
g = g.groupby(["DateKey", "CostCenterCode", "AccountCode"]).Amount.sum().reset_index()
g["SourceSystem"] = "GL"
rows.append(g)
pl = pd.concat(rows, ignore_index=True)
pl["AccountKey"] = pl.AccountCode.map(akey)
pl["CostCenterKey"] = pl.CostCenterCode.map(ckey)
pl["SignedAmount"] = (pl.Amount * pl.AccountCode.map(asign)).round(2)
pl["Amount"] = pl.Amount.round(2)
pl[["DateKey", "AccountKey", "CostCenterKey", "SourceSystem", "Amount", "SignedAmount"]] \
    .to_csv(os.path.join(OUT, "fact_pl.csv"), index=False)

print("tabelle esportate in", os.path.abspath(OUT))
