# Data dictionary

## dw.FactSales
Grain: una riga per riga documento di vendita (fattura `FT` o nota di credito `NC`).

| Colonna | Tipo | Descrizione |
|---|---|---|
| SalesLineKey | BIGINT | chiave surrogata |
| DateKey | INT | data documento (yyyymmdd) → DimDate |
| CustomerKey | INT | → DimCustomer (-1 se codice cliente non trovato) |
| ProductKey | INT | → DimProduct (-1 se articolo non trovato) |
| SalesRepKey | INT | agente → DimSalesRep |
| DocumentNumber | NVARCHAR(30) | numero documento (FV2025/000123, NC2025/000045) |
| DocumentLine | SMALLINT | numero riga |
| DocumentType | CHAR(2) | FT = fattura, NC = nota di credito |
| Quantity | INT | quantità (negativa sulle note di credito) |
| UnitListPrice | DECIMAL(18,2) | prezzo di listino unitario alla data documento |
| DiscountPct | DECIMAL(5,2) | sconto riga % |
| GrossAmount | DECIMAL(18,2) | quantità × prezzo listino |
| DiscountAmount | DECIMAL(18,2) | importo sconto |
| NetAmount | DECIMAL(18,2) | imponibile riga = ricavo netto |
| UnitStandardCost | DECIMAL(18,2) | costo standard unitario in vigore alla data |
| COGSAmount | DECIMAL(18,2) | quantità × costo standard |

## dw.FactPL
Grain: giorno × conto × centro di costo.

| Colonna | Tipo | Descrizione |
|---|---|---|
| DateKey | INT | data registrazione |
| AccountKey | INT | → DimAccount |
| CostCenterKey | INT | → DimCostCenter |
| SourceSystem | NVARCHAR(10) | SALES (ricavi e costo standard da FactSales) / GL (contabilità generale) |
| Amount | DECIMAL(18,2) | importo in segno naturale (ricavi e costi positivi) |
| SignedAmount | DECIMAL(18,2) | importo con segno da conto economico (Amount × PLSign) |

## Dimensioni

**DimDate** - calendario 2022-2027: anno, trimestre, mese (nomi in italiano), settimana ISO, giorno lavorativo (festività nazionali + Pasquetta).

**DimCustomer** - CustomerCode, ragione sociale, segmento (OEM / Distributore / Manutenzione - End user), città, provincia, regione, area di vendita, paese, mercato (Italia / Estero), condizioni di pagamento, cliente dal.

**DimProduct** - codice articolo, descrizione, categoria (5), sottocategoria (15), unità di misura, data lancio.

**DimSalesRep** - agente e area di competenza.

**DimAccount** - piano dei conti gestionale. `PLSection` (Ricavi, Costo del venduto, Costi operativi, Ammortamenti), `PLSubsection`, `PLLineKey` (riga del CE riclassificato), `PLSign` (+1 ricavi, -1 costi).

**DimPLLine** - righe del conto economico riclassificato:

| PLLineKey | Riga | Tipo |
|---:|---|---|
| 1 | Ricavi netti | Detail |
| 2 | Costo del venduto | Detail |
| 3 | MARGINE LORDO | Subtotal |
| 4 | Costo del personale | Detail |
| 5 | Servizi | Detail |
| 6 | Godimento beni di terzi | Detail |
| 7 | Costi commerciali | Detail |
| 8 | Altri costi operativi | Detail |
| 9 | EBITDA | Subtotal |
| 10 | Ammortamenti | Detail |
| 11 | EBIT - RISULTATO OPERATIVO | Subtotal |

**DimCostCenter** - 7 centri di costo raggruppati in Industriale, Commerciale, Generale.

## Piano dei conti

| Conto | Descrizione | Riga CE |
|---|---|---|
| 410000 | Ricavi vendite prodotti | Ricavi netti |
| 510000 | Costo del venduto (costo standard) | Costo del venduto |
| 520000 | Varianze di produzione | Costo del venduto |
| 610000 | Personale indiretto e impiegati | Costo del personale |
| 620000 | Consulenze e servizi professionali | Servizi |
| 621000 | Utenze ed energia | Servizi |
| 622000 | Manutenzioni | Servizi |
| 630000 | Affitti, noleggi e leasing operativi | Godimento beni di terzi |
| 640000 | Trasporti su vendite | Costi commerciali |
| 641000 | Provvigioni agenti | Costi commerciali |
| 650000 | Marketing e fiere | Costi commerciali |
| 660000 | Oneri diversi di gestione | Altri costi operativi |
| 710000 | Ammortamenti immobilizzazioni materiali | Ammortamenti |
| 720000 | Ammortamenti immobilizzazioni immateriali | Ammortamenti |

Nota: il personale di produzione diretto è già compreso nel costo standard del prodotto, per questo il conto 610000 contiene solo personale indiretto e impiegati.
