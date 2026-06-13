# Reordena los circuitos de cada guia POR NIVEL dentro de cada zona,
# conservando titulo/objetivos/texto/imagen de cada paso intactos
# (asi el mapa de cada circuito sigue coincidiendo). No deduplica quests:
# las quests que aparecen en varios circuitos suelen ser cadenas de varios
# pasos (legitimas). Hace backup .bak antes de escribir.
import re, os, shutil

ADDON = r'C:\Program Files\Ascension Launcher\resources\client\Interface\AddOns\SKquests'
FILES = ['Alliance_1_60.lua', 'Horde_1_60.lua']

def reorder(path):
    raw = open(path, 'rb').read().rstrip(b'\x00')          # quita NULL de cola
    src = raw.decode('utf-8', errors='replace')
    m = re.search(r'\n(\s*\[1\]\s*=\s*\{)', src)
    if not m:
        print('  (no se encontro la tabla en', os.path.basename(path), ')'); return False
    head = src[:m.start()+1]
    body = src[m.start()+1:]
    mclose = re.search(r'\n\}\s*$', body)
    table_close = body[mclose.start():]
    parts = [p for p in re.split(r'\n(?=\s*\[\d+\]\s*=\s*\{)', body[:mclose.start()]) if p.strip()]

    def title(p):
        mm = re.search(r'title\s*=\s*\[\[(.*?)\]\]', p, re.S); return mm.group(1) if mm else ''
    def zone(t):
        mm = re.match(r'\s*[\d-]+\s+(.*?)\s+[—-]\s*Circuit', t); return mm.group(1) if mm else t
    def lvls(t):
        mm = re.match(r'\s*(\d+)-(\d+)', t)
        if mm: return (int(mm.group(1)), int(mm.group(2)))
        mm = re.match(r'\s*(\d+)', t)
        return (int(mm.group(1)), 0) if mm else (999, 999)

    # agrupar entradas CONSECUTIVAS por zona; ordenar cada grupo por (nivel ini, nivel fin)
    groups, cur, curz = [], [], None
    for p in parts:
        z = zone(title(p))
        if z != curz and cur:
            groups.append(cur); cur = []
        cur.append(p); curz = z
    if cur: groups.append(cur)
    ordered = []
    for g in groups:
        ordered.extend(sorted(g, key=lambda p: lvls(title(p))))

    out = [head]
    for i, p in enumerate(ordered, start=1):
        p2 = re.sub(r'^\s*\[\d+\]\s*=\s*\{', '    [%d] = {' % i, p, count=1)
        p2 = re.sub(r'step\s*=\s*\d+', 'step = %d' % i, p2, count=1)
        out.append(p2); out.append('\n')
    out.append(table_close.lstrip('\n'))
    result = ''.join(out)

    shutil.copyfile(path, path + '.bak')
    open(path, 'w', encoding='utf-8', newline='').write(result)
    return len(parts)

for fn in FILES:
    p = os.path.join(ADDON, fn)
    if not os.path.exists(p):
        print('FALTA', p); continue
    n = reorder(p)
    print('OK', fn, '->', n, 'pasos reordenados por nivel (backup en', fn + '.bak)')

print('Listo. Recarga el juego (/reload) para ver los circuitos en orden.')
