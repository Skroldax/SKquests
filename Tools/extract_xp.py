import re
import json
import urllib.request

url = "https://classicdb.ch/?quests"
req = urllib.request.Request(url, headers={'User-Agent': 'Mozilla/5.0'})
with urllib.request.urlopen(req) as response:
    data = response.read().decode('utf-8')

# Find the list of quests
try:
    inner = data.split("new Listview({template:'quest',id:'quests',data:[")[1]
except IndexError:
    print("Could not find data array!")
    exit(1)

parts = inner.split("{id:'")
out_dict = {}
for p in parts[1:]:
    q_id = p.split("'", 1)[0]
    name_match = re.search(r"name:'(.*?)',", p)
    xp_match = re.search(r"xp:(\d+)", p)
    if name_match:
        q_name = name_match.group(1).replace("\\'", "'")
        q_xp = int(xp_match.group(1)) if xp_match else 0
        out_dict[int(q_id)] = {"name": q_name, "xp": q_xp}

print(f"Found {len(out_dict)} quests.")
with open("quest_xp.json", "w", encoding="utf-8") as f:
    json.dump(out_dict, f, indent=4, ensure_ascii=False)

print("Saved to quest_xp.json")
