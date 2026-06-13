import re, os, json

TOOLS = os.path.dirname(os.path.abspath(__file__))
SQL = os.path.join(TOOLS, 'quest_template_section.sql')
QUESTIE_XP = r'C:\Program Files\Ascension Launcher\resources\client\Interface\AddOns\Questie-335\Database\QuestXP\DB\xpDB-wotlk.lua'
OUT = os.path.join(TOOLS, 'SKquests_Rewards.lua')

# 1. Extraer dinero del SQL
d = open(SQL, encoding='utf-8', errors='replace').read()
pat = re.compile(r'\((-?\d+),(-?\d+),(-?\d+),(-?\d+),(-?\d+),(-?\d+),(-?\d+),(-?\d+),(-?\d+),(-?\d+),(-?\d+),(-?\d+),(-?\d+),(-?\d+),')
rows = {}
for m in pat.finditer(d):
    g = m.groups()
    qid = int(g[0]); money = int(g[13])
    rows[qid] = {'m': money, 'x': 0}

# 2. Extraer XP de Questie
if os.path.exists(QUESTIE_XP):
    q_data = open(QUESTIE_XP, encoding='utf-8', errors='replace').read()
    # Busca [44] = {10, 850},
    xp_pat = re.compile(r'\[(\d+)\]\s*=\s*\{\s*\d+\s*,\s*(\d+)\s*\}')
    for m in xp_pat.finditer(q_data):
        qid = int(m.group(1))
        xp = int(m.group(2))
        if qid in rows:
            rows[qid]['x'] = xp
        elif xp > 0:
            rows[qid] = {'m': 0, 'x': xp}

# 3. Escribir
with open(OUT, 'w', encoding='utf-8', newline='') as f:
    f.write('-- SKquests - Recompensas de quest (dinero + XP).\n')
    f.write('-- Dinero: quest_template (TDB 335). XP: Questie xpDB-wotlk.lua.\n')
    f.write('-- [questID] = { m = dinero en cobre, x = XP }\n')
    f.write('SKquests_Rewards = {\n')
    for qid in sorted(rows):
        r = rows[qid]
        if (r.get('m') or 0) != 0 or (r.get('x') or 0) != 0:
            f.write('[%d]={m=%d,x=%d},\n' % (qid, r.get('m') or 0, r.get('x') or 0))
    f.write('}\n')

print('Generado %d recompensas exactas WotLK -> %s' % (len(rows), OUT))
