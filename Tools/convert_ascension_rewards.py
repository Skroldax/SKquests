# -*- coding: utf-8 -*-
"""
Convierte ascension_quests.json (salida del scraper) al formato del addon:
  SKquests_Rewards.lua   ->  [id]={m=cobre, x=XP, cur={..}, it={..}}

- m  = dinero en cobre (Ascension)
- x  = XP (Ascension)
- cur = lista de divisas de recompensa (p.ej. 364 = Mark of Ascension)  [opcional]
- it  = lista de ítems de recompensa                                    [opcional]

USO:
    python convert_ascension_rewards.py
Salida: SKquests_Rewards.lua (en esta carpeta). Cópialo al addon reemplazando el actual.
"""
import os, json

HERE = os.path.dirname(os.path.abspath(__file__))
IN_JSON = os.path.join(HERE, "ascension_quests.json")
OUT_LUA = os.path.join(HERE, "SKquests_Rewards.lua")

def fmt_list(lst):
    return "{" + ",".join(str(i) for i in lst) + "}"

def main():
    data = json.load(open(IN_JSON, encoding="utf-8"))
    rows = {}
    for sid, q in data.items():
        if q.get("_empty"):
            continue
        qid = int(sid)
        m = int(q.get("money") or 0)
        x = int(q.get("xp") or 0)
        cur = q.get("reward_currencies") or []
        it = q.get("reward_items") or []
        if m == 0 and x == 0 and not cur and not it:
            continue
        rows[qid] = (m, x, cur, it)

    with open(OUT_LUA, "w", encoding="utf-8", newline="") as f:
        f.write("-- SKquests - Recompensas de quest (dinero + XP + divisas/ítems).\n")
        f.write("-- Fuente: db.ascension.gg (datos propios de Ascension).\n")
        f.write("-- [questID] = { m = cobre, x = XP, cur = {divisas}, it = {items} }\n")
        f.write("SKquests_Rewards = {\n")
        for qid in sorted(rows):
            m, x, cur, it = rows[qid]
            parts = ["m=%d" % m, "x=%d" % x]
            if cur: parts.append("cur=" + fmt_list(cur))
            if it:  parts.append("it=" + fmt_list(it))
            f.write("[%d]={%s},\n" % (qid, ",".join(parts)))
        f.write("}\n")

    print("Generadas %d recompensas -> %s" % (len(rows), OUT_LUA))

if __name__ == "__main__":
    main()
