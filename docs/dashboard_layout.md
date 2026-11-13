# Layout della dashboard

Canvas 1920 × 1080 (16:9). Ogni pagina ha la stessa struttura: barra di intestazione con titolo e navigazione tra pagine (pulsanti con segnalibri), riga di filtri, riga di KPI card, area grafici.

## Tema

| Uso | Colore |
|---|---|
| Intestazione, valori principali, anno corrente nelle serie scure | `#1B2A41` |
| Serie anno corrente | `#2E5C8A` |
| Serie anno precedente | `#9DB7D5` |
| Seconda serie / categorie | `#3A8D8C` |
| Linee di riferimento, target, evidenze | `#E0A100` |
| Variazione favorevole | `#1E8E5A` |
| Variazione sfavorevole | `#C0392B` |
| Testo secondario, valori non disponibili | `#8A94A6` |
| Sfondo pagina | `#F4F6F8` |

Font Segoe UI, titoli visual 12 pt grassetto, valori card 24-28 pt. Verde e rosso usati solo per le variazioni, mai per le categorie, così il colore ha sempre lo stesso significato.

## Filtri (sincronizzati su tutte le pagine)
Anno (selezione singola, default anno più recente) · Mercato · Segmento cliente · Area di vendita.

## Pagina 1 - Overview
| Visual | Tipo | Campi |
|---|---|---|
| 6 KPI card | Card (nuova) con valore di riferimento | Revenue / YoY Growth %, Gross Margin % / Gross Margin % Delta pp, EBITDA / EBITDA YoY %, EBITDA %, Operating Profit, Revenue per Customer / Active Customers |
| Ricavi mensili | Grafico a colonne + linea | Asse: Calendar[MonthShort]; colonne: Revenue; linea: Revenue PY |
| EBITDA % mensile | Linee | Asse: mese; valori: EBITDA % (legenda anno, ultimi 2 anni) con linea costante = EBITDA % annuo |
| Revenue per categoria | Barre orizzontali | Product[ProductCategory], Net Sales, etichetta = Revenue Share by Category % |
| Trend annuale | Colonne + linea su asse secondario | Calendar[Year]; Revenue; EBITDA % |
| Punti chiave | Casella di testo / narrativa intelligente | commento del mese |

## Pagina 2 - Conto Economico
| Visual | Tipo | Campi |
|---|---|---|
| CE riclassificato | Matrice | Righe: PLLayout[PLLineName] (ordinata per SortOrder); valori: PL Amount, PL % on Revenue, PL Amount PY, PL Delta vs PY, PL Delta % vs PY. Righe subtotale in grassetto con sfondo `#EEF3F9` (formattazione condizionale su IsBold) |
| Trend mensile | Linee | Calendar[YearMonth]; Revenue, Gross Margin, EBITDA (ultimi 24 mesi) |
| Dai ricavi all'EBIT | Grafico a cascata | Categoria: PLLayout[PLLineName] (solo righe Detail); valore: PL Amount |
| Margini % | Colonne raggruppate | Calendar[Year]; Gross Margin %, EBITDA %, Operating Profit % |

Drill-through dalla matrice verso il dettaglio conti (`Account[Account]`) e centri di costo.

## Pagina 3 - Clienti
| Visual | Tipo | Campi |
|---|---|---|
| 5 KPI card | Card | Active Customers, Revenue per Customer, New Customers, Lost Customers, Top 10 Customers Share % |
| Curva di Pareto | Colonne + linea | Customer[CustomerName] ordinato per Net Sales; linea Pareto Cumulative %; linea costante 80% |
| Ricavi per area | Barre raggruppate | Customer[SalesArea]; Net Sales, Net Sales PY; etichetta Net Sales YoY % |
| Top 10 clienti | Tabella | CustomerName, CustomerSegment, Net Sales, Pareto Cumulative %, Std Gross Margin %, Net Sales YoY % (filtro Top N = 10 su Net Sales) |
| Sconto medio | Colonne raggruppate | CustomerSegment; Avg Discount %; legenda Year |

Tooltip personalizzato sul cliente: ultimi 12 mesi di fatturato, margine, sconto medio, agente.

## Pagina 4 - Prodotti
| Visual | Tipo | Campi |
|---|---|---|
| Margine per categoria | Colonne raggruppate | ProductCategory; Std Gross Margin %; legenda Year |
| Articoli | Grafico a dispersione | X: Net Sales (scala log); Y: Std Gross Margin %; legenda ProductCategory; dettagli ProductCode; linea media |
| Prezzo / volume / costo | Tabella | da query SQL 06/5 importata come tabella `PVM` oppure con misure dedicate |
| Mix ricavi | Barre in pila 100% | Year; Net Sales per ProductCategory |

## Pagina 5 - Costi operativi
| Visual | Tipo | Campi |
|---|---|---|
| 5 KPI card | Card | Operating Expenses, Opex % on Revenue, costo del personale, energia e utenze, D&A |
| Opex per centro di costo | Barre raggruppate | CostCenter[CostCenterName]; Operating Expenses CY e PY |
| Opex mensili | Colonne in pila | mese; Operating Expenses per Account[PLSubsection] |
| Opex per natura | Tabella | PLSubsection; Operating Expenses, Opex % on Revenue, PY, delta % (formattazione invertita: aumento = rosso) |

## Interazioni
- Pulsanti di navigazione con segnalibri, pagina attiva evidenziata.
- "Modifica interazioni": i grafici di trend non filtrano le card KPI.
- Pulsante "Reset filtri" con segnalibro.
- Pagina nascosta di drill-through "Dettaglio documenti" (righe fattura per cliente/articolo).
