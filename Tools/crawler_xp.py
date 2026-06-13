import urllib.request
import re
import json
import time

def fetch_html(url, retries=3):
    req = urllib.request.Request(url, headers={'User-Agent': 'Mozilla'})
    for _ in range(retries):
        try:
            return urllib.request.urlopen(req, timeout=5).read().decode('utf-8')
        except Exception:
            time.sleep(1)
    return ""

print("Fetching locale_enus.js to discover categories...")
locale_js = fetch_html('https://classicdb.ch/templates/wowhead/js/locale_enus.js')

match = re.search(r'var mn_quests\s*=\s*\[(.*?)\];', locale_js, re.DOTALL)
if not match:
    print("Could not find mn_quests!")
    exit(1)

category_text = match.group(1)

main_cats = re.split(r'\n\t\[', category_text)
urls_to_fetch = []

for mc in main_cats:
    if not mc.strip(): continue
    m_match = re.search(r'^(\-?\d+),\s*"([^"]+)"', mc)
    if not m_match: continue
    cat_id = m_match.group(1)
    
    subcats = re.findall(r'\[(\-?\d+),\s*"([^"]+)"\]', mc)
    if subcats:
        for sub_id, sub_name in subcats:
            urls_to_fetch.append((f"{cat_id}.{sub_id}", f"{m_match.group(2)} - {sub_name}"))
    else:
        urls_to_fetch.append((cat_id, m_match.group(2)))

print(f"Found {len(urls_to_fetch)} subcategories to fetch.")

all_quests = {}

for cat_path, cat_name in urls_to_fetch:
    url = f"https://classicdb.ch/?quests={cat_path}"
    print(f"Fetching {cat_name} ({url})...", flush=True)
    
    html = fetch_html(url)
    if not html:
        print(f"  Failed to fetch.")
        continue
    try:
        inner = html.split("new Listview({template:'quest',id:'quests',data:[")[1]
    except IndexError:
        print(f"  No quests found or empty category.")
        time.sleep(0.1)
        continue
        
    parts = inner.split("{id:'")
    count = 0
    for p in parts[1:]:
        q_id = p.split("'", 1)[0]
        name_match = re.search(r"name:'(.*?)',", p)
        xp_match = re.search(r"xp:(\d+)", p)
        
        if name_match:
            q_name = name_match.group(1).replace("\\'", "'")
            q_xp = int(xp_match.group(1)) if xp_match else 0
            if int(q_id) not in all_quests:
                all_quests[int(q_id)] = {"name": q_name, "xp": q_xp}
                count += 1
                
    print(f"  Added {count} quests.")
    time.sleep(0.1)

print(f"Total unique quests collected: {len(all_quests)}")

with open("quests_xp_db.json", "w", encoding="utf-8") as f:
    json.dump(all_quests, f, indent=4, ensure_ascii=False)

print("Saved to quests_xp_db.json")
