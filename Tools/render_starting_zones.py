# Renderiza SOLO Northshire y ValleyOfTrials (los 5 circuitos que faltan)
# con marcadores pequeños y los convierte a TGA 24-bit directo en Media.
# Requisitos: guardar antes los mapas base en base_maps\Northshire.jpg y
# base_maps\ValleyOfTrials.jpg.
import json, os
import matplotlib
matplotlib.use('Agg')
import matplotlib.pyplot as plt
import matplotlib.patheffects as pe
import matplotlib.image as mpimg
from PIL import Image, ImageFile
ImageFile.LOAD_TRUNCATED_IMAGES = True

TOOLS = os.path.dirname(os.path.abspath(__file__))
JSON_FILE = os.path.join(TOOLS, 'MapasCircuitos_v2', 'circuits.json')
BASE_DIR  = os.path.join(TOOLS, 'base_maps')
OUT_DIR   = os.path.join(TOOLS, 'circuit_maps_with_bg')
MEDIA     = r'C:\Program Files\Ascension Launcher\resources\client\Interface\AddOns\SKquests\Media'

ZONES = ['Northshire', 'ValleyOfTrials']
os.makedirs(OUT_DIR, exist_ok=True)
circuits = json.load(open(JSON_FILE, encoding='utf-8'))

def crop_white_top(img):
    # Recorta filas superiores casi-blancas (la franja blanca) si las hay.
    import numpy as np
    a = np.asarray(img)
    if a.ndim < 3:
        return img
    h = a.shape[0]
    cut = 0
    for y in range(min(60, h)):
        row = a[y, :, :3]
        if row.mean() > 235:   # fila casi blanca
            cut = y + 1
        else:
            break
    return img.crop((0, cut, img.width, img.height)) if cut > 0 else img

count = 0
for c in circuits:
    if c['zoneName'] not in ZONES:
        continue
    z_name, fname, path, fac = c['zoneName'], c['file'], c['path'], c['faction']
    base = os.path.join(BASE_DIR, z_name + '.jpg')
    if not os.path.exists(base):
        base = os.path.join(BASE_DIR, z_name + '.png')
    if not os.path.exists(base):
        print('FALTA base map ->', os.path.join(BASE_DIR, z_name + '.jpg/.png'), '(guarda la imagen ahi primero)'); continue
    pil = crop_white_top(Image.open(base).convert('RGB'))
    img = pil  # matplotlib acepta PIL
    fig, ax = plt.subplots(figsize=(10, 6.6), dpi=100)
    ax.imshow(img, extent=[0, 100, 100, 0]); ax.axis('off')
    xs = [p['x'] for p in path if p['kind'] in ('hub','obj')]
    ys = [p['y'] for p in path if p['kind'] in ('hub','obj')]
    ax.plot(xs, ys, '-', color='#d9b245', lw=2, alpha=0.9, zorder=2)
    for p in path:
        if p['kind'] == 'hub':
            ax.scatter([p['x']],[p['y']], s=70, marker='s', c='#39c75a', edgecolors='black', linewidths=0.6, zorder=4)
            ax.annotate('HUB', (p['x'],p['y']), textcoords='offset points', xytext=(7,-3),
                        color='#39c75a', fontsize=7, weight='bold', path_effects=[pe.withStroke(linewidth=2, foreground='black')])
        elif p['kind'] == 'obj':
            ax.scatter([p['x']],[p['y']], s=80, c='#d9b245', edgecolors='black', linewidths=0.6, zorder=4)
            ax.annotate(str(p['n']), (p['x'],p['y']), ha='center', va='center', color='black', fontsize=6, weight='bold', zorder=5)
        else:
            ax.scatter([p['x']],[p['y']], s=60, marker='v', c='#e05c4f', edgecolors='black', linewidths=0.6, zorder=4)
    out_png = os.path.join(OUT_DIR, fname)
    fig.tight_layout(pad=0); fig.savefig(out_png, bbox_inches='tight', pad_inches=0); plt.close(fig)
    dst_dir = os.path.join(MEDIA, 'Images Ally' if fac == 'Alliance' else 'Images Horde')
    dst = os.path.join(dst_dir, os.path.splitext(fname)[0] + '.tga')
    Image.open(out_png).convert('RGB').resize((512, 512)).save(dst)
    count += 1
    print('OK', fname, '->', dst)

print('Listo. Generados', count, 'mapas (esperados 5).')
