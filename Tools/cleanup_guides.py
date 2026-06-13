# Limpieza puntual de las guias (hace backup .bak2 antes de escribir):
#  1) Arregla comillas mal anidadas tipo  "Wanted:  "Hogger""  ->  "Wanted: Hogger"
#     (rompian el resaltado del nombre de la quest).
#  2) Elimina circuitos de la quest falsa "Wabbit Pelts".
#  3) Elimina circuitos de 1 sola quest en Northshire cuyo quest YA esta en un
#     circuito multi-quest de Northshire (duplicados como "Kobold Camp Cleanup").
#     Solo Northshire para no tocar cadenas legitimas de otras zonas.
import re, os, shutil

ADDON = r'C:\Program Files\Ascension Launcher\resources\client\Interface\AddOns\SKquests'
FILES = ['Alliance_1_60.lua', 'Horde_1_60.lua']

def clean(path):
    raw = open(path, 'rb').read().rstrip(b'\x00').decode('utf-8', errors='replace')
    m = re.search(r'\n(\s*\[1\]\s*=\s*\{)', raw)
    if not m:
        return None
    head = raw[:m.start()+1]; body = raw[m.start()+1:]
    mc = re.search(r'\n\}\s*$', body); close = body[mc.start():]
    parts = [p for p in re.split(r'\n(?=\s*\[\d+\]\s*=\s*\{)', body[:mc.start()]) if p.strip()]

    def text(p):
        mm = re.search(r'text\s*=\s*\[\[(.*?)\]\]', p, re.S); return mm.group(1) if mm else ''
    def title(p):
        mm = re.search(r'title\s*=\s*\[\[(.*?)\]\]', p, re.S); return (mm.group(1) if mm else '').strip()
    def zone(t):
        mm = re.match(r'\s*[\d-]+\s+(.*?)\s+[—-]\s*Circuit', t); return mm.group(1) if mm else t
    def quests(p):
        return {n.strip() for n in re.findall(r'"([^"\n]+)"', text(p)) if len(n.strip()) > 2}

    # 1) comillas anidadas
    fixq = 0
    for i, p in enumerate(parts):
        np = re.sub(r'"([^"\n]*?)\s+"([^"\n]+)""', r'"\1 \2"', p)
        if np != p:
            fixq += 1; parts[i] = np

    # paso 1: quests presentes en circuitos multi-quest, por zona
    multi = {}
    for p in parts:
        z = zone(title(p)); qs = quests(p)
        if len(qs) > 1:
            multi.setdefault(z, set()).update(qs)

    # paso 2: filtrar
    keep, removed = [], []
    for p in parts:
        z = zone(title(p)); qs = quests(p)
        if 'Wabbit Pelts' in text(p):
            removed.append(title(p)); continue
        if z == 'Northshire Valley' and len(qs) == 1 and next(iter(qs)) in multi.get(z, set()):
            removed.append(title(p)); continue
        keep.append(p)

    out = [head]
    for i, p in enumerate(keep, 1):
        p = re.sub(r'^\s*\[\d+\]\s*=\s*\{', '    [%d] = {' % i, p, 1)
        p = re.sub(r'step\s*=\s*\d+', 'step = %d' % i, p, 1)
        out.append(p); out.append('\n')
    out.append(close.lstrip('\n'))
    return ''.join(out), fixq, removed

for fn in FILES:
    path = os.path.join(ADDON, fn)
    if not os.path.exists(path):
        print('FALTA', path); continue
    r = clean(path)
    if not r:
        print('  (no se encontro la tabla en', fn, ')'); continue
    res, fixq, removed = r
    shutil.copyfile(path, path + '.bak2')
    open(path, 'w', encoding='utf-8', newline='').write(res)
    print('OK', fn, '| comillas arregladas:', fixq, '| circuitos eliminados:', len(removed), removed)

print('Listo. /reload en el juego para ver los cambios.')
