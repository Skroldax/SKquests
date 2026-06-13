import re, os, json

TOOLS = os.path.dirname(os.path.abspath(__file__))
SQL = os.path.join(TOOLS, 'quest_template_section.sql')
XPJSON = os.path.join(TOOLS, 'quests_xp_db.json')
OUT = os.path.join(TOOLS, 'SKquests_Rewards.lua')

# dinero desde el SQL
d = open(SQL, encoding='utf-8', errors='replace').read()
pat = re.compile(r'\((-?\d+),(-?\d+),(-?\d+),(-?\d+),(-?\d+),(-?\d+),(-?\d+),(-?\d+),(-?\d+),(-?\d+),(-?\d+),(-?\d+),(-?\d+),(-?\d+),')
rows = {}
for m in pat.finditer(d):
    g = m.groups()
    qid = int(g[0]); money = int(g[13])
    rows[qid] = {'m': money, 'x': 0}

# XP directo desde el JSON
xpdb = json.load(open(XPJSON, encoding='utf-8'))
for k, v in xpdb.items():
    qid = int(k)
    xp = int(v.get('xp') or 0)
    if qid in rows:
        rows[qid]['x'] = xp
    elif xp > 0:
        rows[qid] = {'m': 0, 'x': xp}

with open(OUT, 'w', encoding='utf-8', newline='') as f:
    f.write('-- SKquests - Recompensas de quest (dinero + XP).\n')
    f.write('-- Dinero: quest_template (TDB 335). XP: quests_xp_db.json (vanilla).\n')
    f.write('-- [questID] = { m = dinero en cobre, x = XP }\n')
    f.write('SKquests_Rewards = {\n')
    for qid in sorted(rows):
        r = rows[qid]
        if (r.get('m') or 0) != 0 or (r.get('x') or 0) != 0:
            f.write('[%d]={m=%d,x=%d},\n' % (qid, r.get('m') or 0, r.get('x') or 0))
    f.write('}\n')

print('Generado %d recompensas -> %s' % (len(rows), OUT))
