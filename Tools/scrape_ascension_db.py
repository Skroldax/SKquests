# -*- coding: utf-8 -*-
"""
Scraper de db.ascension.gg para SKquests.
Extrae por quest: nombre, objetivo, XP, dinero, ítems/divisas de recompensa,
reputación, giver/ender (NPC). Guarda incremental y reanudable en JSON.

USO (en tu PC, con Python 3):
    pip install requests
    # 1) PRUEBA: scrapea 10 quests y muestra el detalle para validar el parseo
    python scrape_ascension_db.py --test
    # 2) COMPLETO: scrapea todas las IDs de SKquests_DetailDB.lua
    python scrape_ascension_db.py

Salida:  ascension_quests.json   (en la misma carpeta)
Reanudable: si lo cortas y lo vuelves a correr, sigue donde quedó.
"""

import os, re, sys, json, time, html

try:
    import requests
except ImportError:
    print("Falta 'requests'. Instala con:  pip install requests")
    sys.exit(1)

# ---------------------------------------------------------------- rutas / config
HERE = os.path.dirname(os.path.abspath(__file__))
# Ruta al DetailDB del addon (de donde sacamos la lista de IDs). Ajusta si hace falta.
DETAILDB = r"C:\Program Files\Ascension Launcher\resources\client\Interface\AddOns\SKquests\SKquests_DetailDB.lua"
OUT_JSON = os.path.join(HERE, "ascension_quests.json")
RAW_DIR  = os.path.join(HERE, "ascension_raw")  # solo en --test: guarda el HTML crudo

BASE = "https://db.ascension.gg/?quest="
HEADERS = {"User-Agent": "Mozilla/5.0 (SKquests data importer; contacto: addon SKquests)"}
DELAY = 0.4          # segundos entre peticiones (educado; súbelo si te bloquean)
TIMEOUT = 20
RETRIES = 3
SAVE_EVERY = 25      # guarda el JSON cada N quests

# ---------------------------------------------------------------- utilidades
TAG_RE = re.compile(r"<[^>]+>")
def strip_tags(s):
    return html.unescape(TAG_RE.sub(" ", s))

def read_ids(path):
    ids = []
    if not os.path.exists(path):
        print("No encuentro SKquests_DetailDB.lua en:", path)
        print("Edita la variable DETAILDB con la ruta correcta.")
        sys.exit(1)
    txt = open(path, encoding="utf-8", errors="replace").read()
    for m in re.finditer(r"DB\[(\d+)\]\s*=", txt):
        ids.append(int(m.group(1)))
    return sorted(set(ids))

def fetch(qid):
    url = BASE + str(qid)
    last = None
    for attempt in range(RETRIES):
        try:
            r = requests.get(url, headers=HEADERS, timeout=TIMEOUT)
            if r.status_code == 200:
                return r.text
            last = "HTTP %s" % r.status_code
        except Exception as e:
            last = str(e)
        time.sleep(1.5 * (attempt + 1))
    print("  [fallo] quest", qid, "->", last)
    return None

# ---------------------------------------------------------------- parseo
def parse_quest(qid, htmltext):
    out = {"id": qid}

    # nombre desde el <title>: "NOMBRE - Quest - Ascension Database"
    m = re.search(r"<title>(.*?)\s*-\s*Quest\s*-", htmltext, re.I | re.S)
    if m:
        out["name"] = html.unescape(html.unescape(m.group(1))).strip()

    text = strip_tags(htmltext)
    text = re.sub(r"[ \t]+", " ", text)

    # XP: "2,450 experience"
    m = re.search(r"([\d,]+)\s*experience", text, re.I)
    if m:
        out["xp"] = int(m.group(1).replace(",", ""))

    # Dinero: spans de moneda (moneygold/silver/copper). Sumamos a cobre.
    g = re.search(r'moneygold"[^>]*>\s*(\d+)', htmltext)
    s = re.search(r'moneysilver"[^>]*>\s*(\d+)', htmltext)
    c = re.search(r'moneycopper"[^>]*>\s*(\d+)', htmltext)
    gold   = int(g.group(1)) if g else 0
    silver = int(s.group(1)) if s else 0
    copper = int(c.group(1)) if c else 0
    out["money"] = gold * 10000 + silver * 100 + copper

    # Recompensas: ítems y divisas. Acotamos a TODA la sección "Rewards" -> "Gains"
    # (los ítems a elegir salen ARRIBA de la línea del dinero, así que no basta
    # con buscar desde "You will receive").
    lo = htmltext.find(">Rewards<")
    if lo == -1:
        lo = htmltext.find("Rewards")
    hi = htmltext.find(">Gains<", lo) if lo != -1 else -1
    if hi == -1 and lo != -1:
        hi = htmltext.find("Gains", lo)
    if lo != -1 and hi != -1 and hi > lo:
        rew = htmltext[lo:hi]
    elif lo != -1:
        rew = htmltext[lo:lo + 4000]
    else:
        rew = htmltext
    items, currencies = [], []
    for iid in re.findall(r"\?item=(\d+)", rew):
        iid = int(iid)
        if iid not in items:
            items.append(iid)
    for cid in re.findall(r"\?currency=(\d+)", rew):
        cid = int(cid)
        if cid not in currencies:
            currencies.append(cid)
    if items: out["reward_items"] = items
    if currencies: out["reward_currencies"] = currencies
    if "choose one" in rew.lower():
        out["reward_choice"] = True  # el jugador elige uno de los ítems

    # Reputación: "X reputation with Y"
    reps = re.findall(r"([\d,]+)\s*reputation with\s*([^\n.]+)", text, re.I)
    if reps:
        out["reputation"] = [{"amount": int(a.replace(",", "")), "faction": b.strip()} for a, b in reps]

    # Giver / Ender (NPC) desde "Quick Facts": Start / End con ?npc=ID
    qf = htmltext[:htmltext.find("Description") if htmltext.find("Description") != -1 else 3000]
    mstart = re.search(r"(Start|Inicio)[^?]{0,80}\?npc=(\d+)", qf, re.I | re.S)
    mend = re.search(r"(End|Fin|Entrega)[^?]{0,80}\?npc=(\d+)", qf, re.I | re.S)
    if mstart: out["giverId"] = int(mstart.group(2))
    if mend: out["enderId"] = int(mend.group(2))

    # ¿la página existe? (algunas IDs no tienen quest)
    if "does not exist" in text.lower() or (not out.get("name")):
        out["_empty"] = True
    return out

# ---------------------------------------------------------------- main
def main():
    test = "--test" in sys.argv
    # --ids 6,2562,1105 : probar quests concretas (modo prueba, verboso)
    forced = None
    for a in sys.argv:
        if a.startswith("--ids"):
            val = a.split("=", 1)[1] if "=" in a else None
            if not val:
                i = sys.argv.index(a)
                if i + 1 < len(sys.argv):
                    val = sys.argv[i + 1]
            if val:
                forced = [int(x) for x in re.findall(r"\d+", val)]
    if forced:
        os.makedirs(RAW_DIR, exist_ok=True)
        print("PRUEBA de IDs concretos:", forced, "\n")
        for qid in forced:
            h = fetch(qid)
            if not h:
                print("quest", qid, "-> sin respuesta"); continue
            open(os.path.join(RAW_DIR, "%d.html" % qid), "w", encoding="utf-8").write(h)
            print("quest %d: %s" % (qid, json.dumps(parse_quest(qid, h), ensure_ascii=False)))
            time.sleep(DELAY)
        return
    ids = read_ids(DETAILDB)
    # Añadir también las quests CUSTOM de Ascension (si está el archivo en esta carpeta).
    custom = os.path.join(HERE, "custom_quests_list.json")
    if os.path.exists(custom):
        try:
            cl = json.load(open(custom, encoding="utf-8"))
            cids = [q["id"] for q in cl if isinstance(q, dict) and "id" in q]
            before = len(ids)
            ids = sorted(set(ids) | set(cids))
            print("IDs: %d (DetailDB) + custom -> %d totales" % (before, len(ids)))
        except Exception as e:
            print("No pude leer custom_quests_list.json:", e)
    if test:
        ids = ids[:10]
        os.makedirs(RAW_DIR, exist_ok=True)
        print("MODO PRUEBA: %d quests\n" % len(ids))

    data = {}
    if os.path.exists(OUT_JSON) and not test:
        data = json.load(open(OUT_JSON, encoding="utf-8"))
        print("Reanudando: ya hay %d quests guardadas." % len(data))

    done = 0
    for qid in ids:
        if str(qid) in data and not test:
            continue
        h = fetch(qid)
        if h is None:
            continue
        if test:
            open(os.path.join(RAW_DIR, "%d.html" % qid), "w", encoding="utf-8").write(h)
        q = parse_quest(qid, h)
        data[str(qid)] = q
        done += 1
        if test:
            print("quest %d: %s" % (qid, json.dumps(q, ensure_ascii=False)))
        else:
            if done % SAVE_EVERY == 0:
                json.dump(data, open(OUT_JSON, "w", encoding="utf-8"), ensure_ascii=False)
                print("  ...%d nuevas (total %d)" % (done, len(data)))
        time.sleep(DELAY)

    json.dump(data, open(OUT_JSON, "w", encoding="utf-8"), ensure_ascii=False, indent=(2 if test else None))
    print("\nListo. %d quests en %s" % (len(data), OUT_JSON))
    if test:
        print("HTML crudo de prueba en:", RAW_DIR)
        print(">>> Mándame este JSON (y si quieres un .html) para afinar el parseo antes del scrape completo.")

if __name__ == "__main__":
    main()
