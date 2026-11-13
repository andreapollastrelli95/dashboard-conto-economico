# -----------------------------------------------------------------------------
# Generazione dataset simulato - Officine Meccaniche Valdarno S.p.A.
# Progetto: Dashboard Conto Economico e Performance Aziendale
#
# Lo script crea gli estratti CSV "come se" arrivassero dall'ERP:
#   - anagrafica clienti, prodotti, agenti, piano dei conti, centri di costo
#   - righe fattura di vendita (con note di credito) 2023-2025
#   - registrazioni di contabilita' generale per i costi operativi e gli ammortamenti
#
# I valori sono calibrati su un'azienda manifatturiera da circa 45-55 mln di
# fatturato. Seed fisso per avere sempre gli stessi numeri.
#
# Uso:  python generate_data.py   (scrive i CSV nella cartella ../data)
# -----------------------------------------------------------------------------
import os
from datetime import date, timedelta

import numpy as np
import pandas as pd

SEED = 2025
rng = np.random.default_rng(SEED)

OUT_DIR = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "data")
os.makedirs(OUT_DIR, exist_ok=True)

START = date(2023, 1, 1)
END = date(2025, 12, 31)

# ------------------------------------------------------------------ prodotti
# margine target per categoria (prezzo listino vs costo standard)
categories = {
    # categoria: (n. articoli, prezzo min, prezzo max, ricarico medio sul costo)
    "Valvole idrauliche":       (34, 42, 480, 2.15),
    "Pompe a ingranaggi":       (26, 210, 1900, 2.05),
    "Cilindri oleodinamici":    (30, 130, 2100, 1.92),
    "Raccorderia":              (40, 3.5, 70, 1.86),
    "Ricambi e kit revisione":  (24, 12, 340, 2.80),
}
subcat = {
    "Valvole idrauliche": ["Valvole di massima", "Distributori", "Valvole di ritegno"],
    "Pompe a ingranaggi": ["Pompe gruppo 1", "Pompe gruppo 2", "Pompe gruppo 3"],
    "Cilindri oleodinamici": ["Doppio effetto", "Semplice effetto", "Telescopici"],
    "Raccorderia": ["Raccordi diritti", "Raccordi a 90", "Adattatori"],
    "Ricambi e kit revisione": ["Kit guarnizioni", "Ricambi pompe", "Ricambi cilindri"],
}
prefix = {"Valvole idrauliche": "VLV", "Pompe a ingranaggi": "PMP",
          "Cilindri oleodinamici": "CIL", "Raccorderia": "RAC",
          "Ricambi e kit revisione": "RIC"}

rows = []
pid = 1
for cat, (n, pmin, pmax, markup) in categories.items():
    for i in range(n):
        price = float(np.round(np.exp(rng.uniform(np.log(pmin), np.log(pmax))), 2))
        mk = markup * rng.normal(1, 0.06)
        cost = round(price / mk, 2)
        sc = subcat[cat][i % 3]
        rows.append({
            "ProductCode": f"{prefix[cat]}-{1000 + i*7:04d}",
            "ProductName": f"{sc} {prefix[cat]}{1000 + i*7}",
            "ProductCategory": cat,
            "ProductSubcategory": sc,
            "UnitOfMeasure": "PZ",
            "ListPrice2023": price,
            "StandardCost2023": cost,
            "LaunchDate": (date(2015, 1, 1) + timedelta(days=int(rng.integers(0, 2900)))).isoformat(),
            "IsActive": 1,
        })
        pid += 1
products = pd.DataFrame(rows)
# un paio di articoli lanciati nel 2024/2025 (nuova linea pompe gruppo 3)
new_idx = products[products.ProductSubcategory == "Pompe gruppo 3"].index[:3]
products.loc[new_idx, "LaunchDate"] = ["2024-03-01", "2024-09-15", "2025-02-01"]
products.insert(0, "ProductID", range(1, len(products) + 1))

# ------------------------------------------------------------------ agenti
reps = pd.DataFrame({
    "SalesRepID": range(1, 11),
    "SalesRepName": ["Marco Bellini", "Giulia Ferri", "Luca Santoro", "Paolo Greco",
                     "Elena Conti", "Stefano Rinaldi", "Chiara Galli", "Davide Marchetti",
                     "Francesca Lombardi", "Thomas Weber"],
    "SalesArea": ["Nord-Ovest", "Nord-Ovest", "Nord-Est", "Nord-Est", "Centro",
                  "Centro", "Sud e Isole", "Export", "Export", "Export"],
})

# ------------------------------------------------------------------ clienti
italian_cities = {
    "Nord-Ovest": [("Milano", "MI", "Lombardia"), ("Brescia", "BS", "Lombardia"), ("Bergamo", "BG", "Lombardia"),
                   ("Torino", "TO", "Piemonte"), ("Genova", "GE", "Liguria"), ("Varese", "VA", "Lombardia")],
    "Nord-Est": [("Bologna", "BO", "Emilia-Romagna"), ("Modena", "MO", "Emilia-Romagna"), ("Reggio Emilia", "RE", "Emilia-Romagna"),
                 ("Padova", "PD", "Veneto"), ("Vicenza", "VI", "Veneto"), ("Verona", "VR", "Veneto"), ("Udine", "UD", "Friuli-Venezia Giulia")],
    "Centro": [("Firenze", "FI", "Toscana"), ("Arezzo", "AR", "Toscana"), ("Prato", "PO", "Toscana"),
               ("Perugia", "PG", "Umbria"), ("Ancona", "AN", "Marche"), ("Roma", "RM", "Lazio")],
    "Sud e Isole": [("Napoli", "NA", "Campania"), ("Bari", "BA", "Puglia"), ("Salerno", "SA", "Campania"),
                    ("Catania", "CT", "Sicilia"), ("Pescara", "PE", "Abruzzo")],
}
export_countries = [("Germania", "DE"), ("Francia", "FR"), ("Spagna", "ES"), ("Polonia", "PL"),
                    ("Austria", "AT"), ("Paesi Bassi", "NL"), ("Romania", "RO"), ("Turchia", "TR")]

name_a = ["Idraulica", "Oleodinamica", "Meccanica", "Tecno", "Agri", "Hydro", "Fluid", "Macchine",
          "Officine", "Costruzioni", "Impianti", "Sistemi", "Movimento", "Trasmissioni", "Ricambi"]
name_b = ["Padana", "Adriatica", "Lombarda", "Veneta", "Emiliana", "Toscana", "Italia", "Sud", "Alpina",
          "Tirrenica", "Europa", "Service", "Group", "Tech", "Center", "Nord", "Industriale"]
forms_it = ["S.r.l.", "S.p.A.", "S.r.l.", "S.n.c.", "S.r.l."]
forms_ex = {"DE": "GmbH", "FR": "SAS", "ES": "S.L.", "PL": "Sp. z o.o.", "AT": "GmbH",
            "NL": "B.V.", "RO": "S.R.L.", "TR": "A.S."}

n_customers = 430
cust = []
used = set()
for i in range(n_customers):
    is_export = rng.random() < 0.22
    if is_export:
        country, iso = export_countries[rng.choice(len(export_countries), p=[.30, .18, .12, .12, .10, .08, .05, .05])]
        region, city, prov, reg_it = "Export", "", "", ""
        form = forms_ex[iso]
    else:
        country, iso = "Italia", "IT"
        region = rng.choice(list(italian_cities), p=[.34, .32, .20, .14])
        city, prov, reg_it = italian_cities[region][rng.integers(len(italian_cities[region]))]
        form = forms_it[rng.integers(len(forms_it))]
    while True:
        nm = f"{rng.choice(name_a)} {rng.choice(name_b)} {form}"
        if nm not in used:
            used.add(nm)
            break
    seg = rng.choice(["OEM", "Distributore", "Manutenzione / End user"], p=[.28, .37, .35])
    area_reps = reps[reps.SalesArea == region].SalesRepID.tolist()
    cust.append({
        "CustomerCode": f"C{10000 + i*3}",
        "CustomerName": nm,
        "CustomerSegment": seg,
        "City": city,
        "Province": prov,
        "Region": reg_it,
        "SalesArea": region,
        "Country": country,
        "CountryCode": iso,
        "SalesRepID": int(rng.choice(area_reps)),
        "PaymentTerms": rng.choice(["RB 60 gg FM", "RB 90 gg FM", "Bonifico 30 gg", "Bonifico 60 gg DF", "RB 120 gg FM"],
                                   p=[.32, .28, .15, .17, .08]),
        "CustomerSince": (date(2005, 1, 1) + timedelta(days=int(rng.integers(0, 6500)))).isoformat(),
    })
customers = pd.DataFrame(cust)
customers.insert(0, "CustomerID", range(1, len(customers) + 1))

# peso commerciale del cliente: distribuzione molto concentrata (Pareto)
seg_mult = customers.CustomerSegment.map({"OEM": 3.2, "Distributore": 1.6, "Manutenzione / End user": 0.45}).values
weight = rng.lognormal(0, 1.05, n_customers)
weight = weight * seg_mult
weight = weight / weight.sum()
# clienti persi e nuovi clienti: attivita' da/a
active_from = np.full(n_customers, np.datetime64("2023-01-01"))
active_to = np.full(n_customers, np.datetime64("2025-12-31"))
new_c = rng.choice(n_customers, 45, replace=False)
for c in new_c:
    active_from[c] = np.datetime64(START + timedelta(days=int(rng.integers(200, 1000))))
lost = rng.choice(np.setdiff1d(np.arange(n_customers), new_c), 30, replace=False)
for c in lost:
    active_to[c] = np.datetime64(START + timedelta(days=int(rng.integers(150, 900))))

# sconto base per cliente
base_disc = np.where(customers.CustomerSegment == "OEM", rng.uniform(.12, .25, n_customers),
            np.where(customers.CustomerSegment == "Distributore", rng.uniform(.18, .32, n_customers),
                     rng.uniform(0, .10, n_customers)))

# ------------------------------------------------------------------ dinamica prezzi/costi
# 2023: costi materie prime ancora alti; 2024: rincaro acciaio e alluminio sul costo standard (+7%)
# con listino aumentato solo del 3% a marzo 2024; 2025: listino +4,5% a gennaio, costi +1%.
def price_index(d):
    if d < date(2024, 3, 1):
        return 1.0
    if d < date(2025, 1, 1):
        return 1.03
    return 1.03 * 1.045

def cost_index(d):
    if d < date(2024, 1, 1):
        return 1.0
    if d < date(2025, 1, 1):
        return 1.07
    return 1.07 * 1.01

# stagionalita' mensile (manifattura: agosto e dicembre bassi)
season = {1: .86, 2: .97, 3: 1.10, 4: 1.04, 5: 1.12, 6: 1.06, 7: 1.08, 8: .42, 9: 1.08, 10: 1.13, 11: 1.07, 12: .78}
growth = {2023: 1.0, 2024: 1.055, 2025: 1.142}  # volumi

# mix categorie per segmento
cat_list = list(categories)
cat_mix = {
    "OEM": [.24, .30, .34, .10, .02],
    "Distributore": [.26, .18, .14, .32, .10],
    "Manutenzione / End user": [.14, .10, .08, .20, .48],
}
prod_by_cat = {c: products[products.ProductCategory == c] for c in cat_list}

# ------------------------------------------------------------------ righe fattura
# genero le fatture giorno per giorno (solo giorni lavorativi)
lines = []
inv_no = {2023: 0, 2024: 0, 2025: 0}
d = START
holidays = {(1, 1), (1, 6), (4, 25), (5, 1), (6, 2), (8, 15), (11, 1), (12, 8), (12, 25), (12, 26)}
base_inv_per_day = 54
cust_idx = np.arange(n_customers)
while d <= END:
    if d.weekday() < 5 and (d.month, d.day) not in holidays:
        n_inv = rng.poisson(base_inv_per_day * season[d.month] * growth[d.year] / 1.06)
        nd = np.datetime64(d)
        mask = (active_from <= nd) & (active_to >= nd)
        w = weight * mask
        # export cresce piu' velocemente (nuovo distributore in Germania dal 2024)
        if d.year >= 2024:
            w = w * np.where(customers.SalesArea == "Export", 1.12 if d.year == 2024 else 1.25, 1.0)
        w = w / w.sum()
        chosen = rng.choice(cust_idx, n_inv, p=w)
        for c in chosen:
            inv_no[d.year] += 1
            inv = f"FV{d.year}/{inv_no[d.year]:06d}"
            seg = customers.at[c, "CustomerSegment"]
            n_lines = 1 + rng.poisson(1.3 if seg != "OEM" else 1.0)
            # nota di credito (reso / storno) ~1.6% dei documenti
            is_cn = rng.random() < 0.016
            for ln in range(1, n_lines + 1):
                cat = cat_list[rng.choice(5, p=cat_mix[seg])]
                pool = prod_by_cat[cat]
                pr = pool.iloc[rng.integers(len(pool))]
                if pr.LaunchDate > d.isoformat():
                    pr = pool.iloc[0]
                unit_price = pr.ListPrice2023
                if cat == "Raccorderia":
                    qty = int(rng.integers(20, 400))
                elif cat == "Ricambi e kit revisione":
                    qty = int(rng.integers(1, 25))
                else:
                    qty = int(max(1, rng.lognormal(1.3 if seg == "OEM" else 0.6, 0.7)))
                list_p = round(unit_price * price_index(d), 2)
                disc = float(np.clip(base_disc[c] + rng.normal(0, .02), 0, .40))
                std_cost = round(pr.StandardCost2023 * cost_index(d), 2)
                sign = -1 if is_cn else 1
                gross = round(qty * list_p, 2)
                net = round(gross * (1 - disc), 2)
                lines.append((
                    inv.replace("FV", "NC") if is_cn else inv, ln, d.isoformat(),
                    "NC" if is_cn else "FT",
                    customers.at[c, "CustomerCode"], pr.ProductCode, int(customers.at[c, "SalesRepID"]),
                    sign * qty, list_p, round(disc * 100, 2), sign * gross, sign * round(gross - net, 2),
                    sign * net, std_cost, sign * round(qty * std_cost, 2),
                    "EUR",
                ))
    d += timedelta(days=1)

sales = pd.DataFrame(lines, columns=[
    "DocumentNumber", "DocumentLine", "DocumentDate", "DocumentType", "CustomerCode", "ProductCode",
    "SalesRepID", "Quantity", "UnitListPrice", "DiscountPct", "GrossAmount", "DiscountAmount",
    "NetAmount", "UnitStandardCost", "COGSAmount", "CurrencyCode"])

# ------------------------------------------------------------------ piano dei conti (riclassificato)
accounts = pd.DataFrame([
    # AccountCode, AccountName, PLSection, PLSubsection, SortOrder, Sign
    ("410000", "Ricavi vendite prodotti", "Ricavi", "Ricavi netti", 10, 1),
    ("510000", "Costo del venduto (costo standard)", "Costo del venduto", "COGS", 20, -1),
    ("520000", "Varianze di produzione", "Costo del venduto", "COGS", 21, -1),
    ("610000", "Personale indiretto e impiegati", "Costi operativi", "Personale", 30, -1),
    ("620000", "Consulenze e servizi professionali", "Costi operativi", "Servizi", 31, -1),
    ("621000", "Utenze ed energia", "Costi operativi", "Servizi", 32, -1),
    ("622000", "Manutenzioni", "Costi operativi", "Servizi", 33, -1),
    ("630000", "Affitti, noleggi e leasing operativi", "Costi operativi", "Godimento beni di terzi", 34, -1),
    ("640000", "Trasporti su vendite", "Costi operativi", "Costi commerciali", 35, -1),
    ("641000", "Provvigioni agenti", "Costi operativi", "Costi commerciali", 36, -1),
    ("650000", "Marketing e fiere", "Costi operativi", "Costi commerciali", 37, -1),
    ("660000", "Oneri diversi di gestione", "Costi operativi", "Altri costi", 38, -1),
    ("710000", "Ammortamenti immobilizzazioni materiali", "Ammortamenti", "D&A", 50, -1),
    ("720000", "Ammortamenti immobilizzazioni immateriali", "Ammortamenti", "D&A", 51, -1),
], columns=["AccountCode", "AccountName", "PLSection", "PLSubsection", "SortOrder", "PLSign"])

cost_centers = pd.DataFrame([
    ("CC100", "Produzione", "Industriale"),
    ("CC200", "Logistica e magazzino", "Industriale"),
    ("CC300", "Commerciale Italia", "Commerciale"),
    ("CC310", "Commerciale Export", "Commerciale"),
    ("CC400", "Amministrazione e finanza", "Generale"),
    ("CC500", "Ricerca e sviluppo", "Generale"),
    ("CC600", "Direzione generale", "Generale"),
], columns=["CostCenterCode", "CostCenterName", "CostCenterGroup"])

# ------------------------------------------------------------------ registrazioni contabili costi
# costi annui di riferimento 2023 (euro) per conto / centro di costo, poi crescita e stagionalita'
annual = {
    ("610000", "CC100"): 1_350_000, ("610000", "CC200"): 640_000, ("610000", "CC300"): 1_080_000,
    ("610000", "CC310"): 520_000, ("610000", "CC400"): 760_000, ("610000", "CC500"): 690_000, ("610000", "CC600"): 540_000,
    ("620000", "CC400"): 310_000, ("620000", "CC600"): 240_000, ("620000", "CC500"): 150_000,
    ("621000", "CC100"): 1_420_000, ("621000", "CC200"): 160_000,
    ("622000", "CC100"): 520_000, ("622000", "CC200"): 90_000,
    ("630000", "CC100"): 380_000, ("630000", "CC200"): 210_000, ("630000", "CC600"): 120_000,
    ("650000", "CC300"): 260_000, ("650000", "CC310"): 190_000,
    ("660000", "CC400"): 230_000,
    ("710000", "CC100"): 1_520_000, ("710000", "CC200"): 180_000,
    ("720000", "CC500"): 240_000, ("720000", "CC400"): 85_000,
}
# fattori anno: energia in calo dopo il picco 2022-23, personale con rinnovo CCNL metalmeccanici
year_factor = {
    "610000": {2023: 1.0, 2024: 1.052, 2025: 1.097},
    "621000": {2023: 1.0, 2024: 0.79, 2025: 0.74},
    "710000": {2023: 1.0, 2024: 1.04, 2025: 1.16},   # nuovo centro di lavoro da aprile 2025
    "default": {2023: 1.0, 2024: 1.03, 2025: 1.055},
}
vendors = {
    "620000": ["Studio Associato Mariotti", "Deloitte & Partners Advisory", "Software Gestionali Toscana S.r.l.", "Studio Legale Barbieri"],
    "621000": ["Enel Energia S.p.A.", "Estra Energie S.r.l.", "Publiacqua S.p.A."],
    "622000": ["Manutenzioni Industriali Arno S.r.l.", "Tecnoservice Impianti S.r.l.", "Fanuc Italia S.r.l."],
    "630000": ["Immobiliare Valdarno S.r.l.", "Leasys Rent S.p.A.", "Linde Material Handling Italia S.p.A."],
    "650000": ["Fiera Milano S.p.A.", "Agenzia Comunicazione Lab51", "Hannover Messe GmbH"],
    "660000": ["Diversi"],
    "640000": ["BRT S.p.A.", "DHL Express Italy S.r.l.", "Arcese Trasporti S.p.A."],
}

gl = []
je = 0
months = pd.period_range("2023-01", "2025-12", freq="M")
for (acc, cc), base in annual.items():
    yf = year_factor.get(acc, year_factor["default"])
    for m in months:
        y, mo = m.year, m.month
        amount_month = base * yf[y] / 12
        if acc == "610000" and mo in (7, 12):  # mensilita' aggiuntive (14ma e 13ma)
            amount_month *= 1.85
        if acc == "621000":
            amount_month *= {1: 1.15, 2: 1.12, 8: 0.55, 12: 0.95}.get(mo, 1.02)
        if acc == "650000":
            amount_month *= {4: 2.6, 10: 2.1, 8: 0.2}.get(mo, 0.65)
        if acc == "710000" and y == 2025 and mo >= 4:
            amount_month *= 1.08
        last_day = (m.end_time.date())
        if acc in ("610000", "710000", "720000"):
            # una scrittura mensile (cedolini / ammortamento mensile)
            je += 1
            desc = "Costo personale - cedolini" if acc == "610000" else "Quota ammortamento mensile"
            gl.append((f"PN{y}/{je:06d}", last_day.isoformat(), acc, cc,
                       round(amount_month * rng.normal(1, 0.015), 2), desc, ""))
        else:
            # piu' fatture fornitore nel mese
            n_docs = int(rng.integers(3, 9))
            parts = rng.dirichlet(np.ones(n_docs)) * amount_month * rng.normal(1, 0.05)
            for p in parts:
                je += 1
                dd = date(y, mo, int(rng.integers(1, 28)))
                v = rng.choice(vendors.get(acc, ["Fornitore generico"]))
                gl.append((f"PN{y}/{je:06d}", dd.isoformat(), acc, cc, round(float(p), 2),
                           "Fattura fornitore", v))

gl = pd.DataFrame(gl, columns=["JournalNumber", "PostingDate", "AccountCode", "CostCenterCode",
                               "Amount", "Description", "VendorName"])

# trasporti su vendite e provvigioni: legati al fatturato del mese
sales["_m"] = sales.DocumentDate.str[:7]
monthly_rev = sales.groupby("_m").NetAmount.sum()
extra = []
for mth, rev in monthly_rev.items():
    y = int(mth[:4]); mo = int(mth[5:])
    for acc, pct, cc in (("640000", 0.021, "CC200"), ("641000", 0.024, "CC300")):
        n_docs = 6 if acc == "640000" else 1
        for p in rng.dirichlet(np.ones(n_docs)) * rev * pct * rng.normal(1, 0.04):
            je += 1
            dd = date(y, mo, int(rng.integers(1, 28)))
            vend = rng.choice(vendors["640000"]) if acc == "640000" else "Enasarco / agenti"
            extra.append((f"PN{y}/{je:06d}", dd.isoformat(), acc, cc, round(float(p), 2),
                          "Fattura fornitore" if acc == "640000" else "Liquidazione provvigioni", vend))
    # varianze di produzione (negative = favorevoli)
    je += 1
    var = rev * rng.normal(0.006 if y == 2024 else 0.002, 0.004)
    extra.append((f"PN{y}/{je:06d}", (pd.Period(mth).end_time.date()).isoformat(), "520000", "CC100",
                  round(float(var), 2), "Rilevazione varianze di produzione", ""))
gl = pd.concat([gl, pd.DataFrame(extra, columns=gl.columns)], ignore_index=True)
gl = gl.sort_values(["PostingDate", "JournalNumber"]).reset_index(drop=True)
gl.insert(0, "GLEntryID", range(1, len(gl) + 1))
sales = sales.drop(columns="_m")

# ------------------------------------------------------------------ scrittura CSV
products.to_csv(os.path.join(OUT_DIR, "products.csv"), index=False)
customers.to_csv(os.path.join(OUT_DIR, "customers.csv"), index=False)
reps.to_csv(os.path.join(OUT_DIR, "sales_reps.csv"), index=False)
accounts.to_csv(os.path.join(OUT_DIR, "chart_of_accounts.csv"), index=False)
cost_centers.to_csv(os.path.join(OUT_DIR, "cost_centers.csv"), index=False)
sales.to_csv(os.path.join(OUT_DIR, "sales_invoice_lines.csv"), index=False)
gl.to_csv(os.path.join(OUT_DIR, "gl_entries.csv"), index=False)

print(f"prodotti: {len(products)}  clienti: {len(customers)}")
print(f"righe fattura: {len(sales):,}  registrazioni CoGe: {len(gl):,}")
s = sales.assign(y=sales.DocumentDate.str[:4]).groupby("y")[["NetAmount", "COGSAmount"]].sum()
s["GM%"] = 1 - s.COGSAmount / s.NetAmount
print(s.round(0))
