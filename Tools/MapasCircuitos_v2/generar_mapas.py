# SKquests — Trazado visual de circuitos (obra original, datos propios)
# Genera 1 PNG por circuito + circuits.json para re-renderizar sobre mapas reales.
import re, math, json, os, zipfile
import matplotlib
matplotlib.use('Agg')
import matplotlib.pyplot as plt

O = '/sessions/wizardly-clever-hopper/mnt/outputs/'
B = '/sessions/wizardly-clever-hopper/mnt/SKquests/'
IMG = O + 'circuit_maps/'
os.makedirs(IMG, exist_ok=True)

db = open(B+'SKquests_DetailDB.lua', encoding='utf-8', errors='replace').read()
origin = dict((int(a), b) for a, b in re.findall(r"\[(\d+)\] = '(\w+)'", open(B+'quest_origin_pfquest.lua', encoding='utf-8', errors='replace').read()))
pf = open(B+'Media/db/quests.lua', encoding='utf-8', errors='replace').read()
race, objU = {}, {}
tops = [(int(m.group(1)), m.start(), m.end()) for m in re.finditer(r'(?<=[,{])\[(\d+)\]=\{', pf)]
for i, (qid, s, e) in enumerate(tops):
    seg = pf[e: tops[i+1][1] if i+1 < len(tops) else len(pf)]
    r = re.search(r'\["race"\]=(\d+)', seg)
    if r: race[qid] = int(r.group(1))
    u = re.search(r'\["obj"\]=\{.*?\["U"\]=\{([\d,]+)\}', seg)
    if u: objU[qid] = [int(x) for x in u.group(1).split(',') if x]
units = {}
for m in re.finditer(r'\[(\d+)\]=\{\["coords"\]=\{\[1\]=\{([\d.]+),([\d.]+),(\d+)', open(B+'Media/db/units.lua', encoding='utf-8', errors='replace').read()):
    units[int(m.group(1))] = (float(m.group(2)), float(m.group(3)), int(m.group(4)))
quests = {}
for m in re.finditer(r'DB\[(\d+)\]=\{(.*?)\}\n', db, re.S):
    qid = int(m.group(1)); body = m.group(2)
    def num(k):
        r = re.search(r'(?<![a-zA-Z])'+k+r'=(\d+)', body)
        return int(r.group(1)) if r else None
    def txt(k):
        r = re.search(k+r'=\[\[(.*?)\]\]', body, re.S)
        return r.group(1) if r else None
    name = txt('name') or ''
    if not name.strip(): continue
    u = name.upper()
    if any(t in u for t in ('<UNUSED>','<NYI>','<TXT>','[UNUSED]')): continue
    lvl = num('level') or 0
    if max(lvl, num('lvl') or 0, num('minLevel') or 0, num('reqLevel') or 0) > 60: continue
    if origin.get(qid) in ('tbc','wotlk'): continue
    quests[qid] = dict(id=qid, name=name, zone=num('zoneId'), level=lvl, minL=num('minLevel') or 1,
                       giver=num('giverId'), ender=num('enderId'))
ZN = {9:"Northshire",12:"ElwynnForest",40:"Westfall",38:"LochModan",148:"Darkshore",
      44:"Redridge",10:"Duskwood",11:"Wetlands",267:"Hillsbrad",331:"Ashenvale",
      33:"Stranglethorn",405:"Desolace",45:"Arathi",3:"Badlands",8:"SwampOfSorrows",
      440:"Tanaris",357:"Feralas",47:"Hinterlands",51:"SearingGorge",4:"BlastedLands",
      490:"UnGoro",361:"Felwood",46:"BurningSteppes",28:"WesternPlaguelands",
      139:"EasternPlaguelands",618:"Winterspring",1377:"Silithus",363:"ValleyOfTrials",
      14:"Durotar",215:"Mulgore",85:"Tirisfal",17:"Barrens",130:"Silverpine",
      406:"Stonetalon",400:"ThousandNeedles",15:"Dustwallow",1:"DunMorogh",141:"Teldrassil"}
PROG = {
 'Alliance': [(9,1,6),(12,5,10),(1,1,10),(141,1,10),(40,9,16),(38,10,18),(148,11,19),(44,15,22),
              (10,18,28),(11,20,28),(267,20,30),(331,19,30),(405,30,38),(45,30,38),(33,30,43),
              (3,35,44),(8,36,44),(357,40,48),(47,41,48),(440,40,49),(51,43,50),(4,45,54),
              (490,48,55),(361,48,55),(46,50,58),(28,51,58),(618,53,60),(139,54,60),(1377,55,60)],
 'Horde':    [(363,1,6),(14,4,10),(215,1,10),(85,1,10),(17,10,25),(130,10,20),(406,16,26),
              (331,19,30),(400,25,35),(267,20,30),(405,30,38),(15,35,43),(33,30,43),(3,35,44),
              (8,36,44),(357,40,48),(47,41,48),(440,40,49),(51,43,50),(4,45,54),(490,48,55),
              (361,48,55),(46,50,58),(28,51,58),(618,53,60),(139,54,60),(1377,55,60)],
}
def fok(qid, fac):
    r = race.get(qid)
    if not r: return True
    return (r & (77 if fac=='Alliance' else 178)) != 0
def d(a,b): return math.hypot(a[0]-b[0], a[1]-b[1])
def centroid(q):
    pts = [units[n][:2] for n in objU.get(q['id'],[]) if n in units and units[n][2]==q['zone']]
    if pts: return (sum(p[0] for p in pts)/len(pts), sum(p[1] for p in pts)/len(pts))
    c = units.get(q['ender']) or units.get(q['giver'])
    return (c[0],c[1]) if c else None

export = []
count = 0
for fac in ('Alliance','Horde'):
    used = set()
    for zone, lo, hi in PROG[fac]:
        qs = [q for q in quests.values() if q['zone']==zone and q['id'] not in used
              and fok(q['id'],fac) and lo<=q['minL']<=hi]
        if not qs: continue
        for q in qs: used.add(q['id'])
        hubs = []
        for q in sorted(qs, key=lambda q:(q['minL'],q['level'])):
            g = units.get(q['giver']); placed=False
            if g:
                for h in hubs:
                    if h['c'] and d(h['c'],g[:2])<8 and len(h['qs'])<7 and abs(h['lvl']-q['minL'])<=6:
                        h['qs'].append(q); placed=True; break
            if not placed: hubs.append({'c':g[:2] if g else None,'qs':[q],'lvl':q['minL']})
        cur=(50.0,50.0); ordered=[]; rest=hubs[:]
        while rest:
            best,bi=None,None
            for i,h in enumerate(rest):
                dd = d(cur,h['c']) if h['c'] else 70
                key=(h['lvl']//6, dd)
                if best is None or key<best: best,bi=key,i
            h=rest.pop(bi); ordered.append(h)
            if h['c']: cur=h['c']
        zname = ZN.get(zone, "Zone%d"%zone)
        for hn,h in enumerate(ordered,1):
            batch = h['qs']
            # recorrido: hub -> centroides en orden NN -> entregas
            path = []
            if h['c']: path.append(dict(kind='hub', x=h['c'][0], y=h['c'][1],
                                        label='Inicio: aceptar %d quests' % len(batch)))
            cur2 = h['c'] or (50.0,50.0); restq = batch[:]
            order_n = 0
            while restq:
                best,bi=None,None
                for i,q in enumerate(restq):
                    c = centroid(q); dd = d(cur2,c) if c else 70
                    if best is None or dd<best: best,bi=dd,i
                q = restq.pop(bi); c = centroid(q)
                if c:
                    order_n += 1
                    path.append(dict(kind='obj', x=c[0], y=c[1], n=order_n, label=q['name'], quest=q['id']))
                    cur2 = c
            seen_end = set()
            for q in batch:
                e = units.get(q['ender'])
                if e and e[2]==zone and q['ender'] not in seen_end:
                    seen_end.add(q['ender'])
                    path.append(dict(kind='turnin', x=e[0], y=e[1], label='Entrega'))
            if len([p for p in path if p['kind']!='turnin']) < 2: continue
            count += 1
            fname = '%s_%s_c%02d.png' % (fac, zname, hn)
            export.append(dict(faction=fac, zone=zone, zoneName=zname, circuit=hn,
                               file=fname, path=path))
            # ---- dibujo ----
            fig, ax = plt.subplots(figsize=(6,6), dpi=80)
            ax.set_xlim(0,100); ax.set_ylim(100,0)   # Y invertida como en WoW
            ax.set_facecolor('#10130f')
            ax.grid(color='#2a2f28', lw=0.5)
            xs = [p['x'] for p in path if p['kind'] in ('hub','obj')]
            ys = [p['y'] for p in path if p['kind'] in ('hub','obj')]
            ax.plot(xs, ys, '-', color='#d9b245', lw=2, alpha=0.85, zorder=2)
            for p in path:
                if p['kind']=='hub':
                    ax.scatter([p['x']],[p['y']], s=160, marker='s', c='#39c75a', zorder=4)
                    ax.annotate('HUB', (p['x'],p['y']), textcoords='offset points', xytext=(7,-4),
                                color='#39c75a', fontsize=9, weight='bold')
                elif p['kind']=='obj':
                    ax.scatter([p['x']],[p['y']], s=200, c='#d9b245', zorder=4)
                    ax.annotate(str(p['n']), (p['x'],p['y']), ha='center', va='center',
                                color='#10130f', fontsize=9, weight='bold', zorder=5)
                else:
                    ax.scatter([p['x']],[p['y']], s=150, marker='v', c='#e05c4f', zorder=4)
            ax.set_title('%s — %s — Circuito %d' % (fac, zname, hn), color='#e8d8a0', fontsize=11)
            ax.tick_params(colors='#777', labelsize=7)
            fig.patch.set_facecolor('#191d17')
            fig.tight_layout()
            fig.savefig(IMG + fname, facecolor=fig.get_facecolor())
            plt.close(fig)

json.dump(export, open(O+'circuits.json','w',encoding='utf-8'), ensure_ascii=False, indent=1)
z = zipfile.ZipFile(O+'SKquests_MapasCircuitos.zip','w',zipfile.ZIP_DEFLATED)
for f in sorted(os.listdir(IMG)): z.write(IMG+f, 'circuit_maps/'+f)
z.write(O+'circuits.json','circuits.json')
z.write('/tmp/skq_maps.py','generar_mapas.py')
z.close()
print('imágenes:', count, '| zip listo')
