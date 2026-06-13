import urllib.request
import json
import os
import matplotlib
matplotlib.use('Agg')
import matplotlib.pyplot as plt
import matplotlib.patheffects as path_effects
import matplotlib.image as mpimg

# Paths
JSON_FILE = 'MapasCircuitos_v2/circuits.json'
BASE_DIR = 'base_maps'
OUT_DIR = 'circuit_maps_with_bg'

os.makedirs(BASE_DIR, exist_ok=True)
os.makedirs(OUT_DIR, exist_ok=True)

# 1. Load the data
print("Loading circuits...")
try:
    with open(JSON_FILE, 'r', encoding='utf-8') as f:
        circuits = json.load(f)
except FileNotFoundError:
    print(f"Error: {JSON_FILE} not found.")
    exit(1)

# 2. Extract unique zones
zones = {}
for c in circuits:
    z_id = c['zone']
    z_name = c['zoneName']
    zones[z_id] = z_name

# 3. Download base maps
print("Downloading base maps...")
for z_id, z_name in zones.items():
    img_path = os.path.join(BASE_DIR, f"{z_name}.jpg")
    if not os.path.exists(img_path):
        url = f"https://wow.zamimg.com/images/wow/maps/enus/original/{z_id}.jpg"
        print(f"Downloading {z_name} from {url}...")
        try:
            # We use a user-agent to avoid 403 Forbidden
            req = urllib.request.Request(url, headers={'User-Agent': 'Mozilla/5.0'})
            with urllib.request.urlopen(req) as response, open(img_path, 'wb') as out_file:
                out_file.write(response.read())
        except Exception as e:
            print(f"Failed to download {z_name}: {e}")

# 4. Render circuits
print("Rendering maps...")
count = 0
for c in circuits:
    fac = c['faction']
    z_id = c['zone']
    z_name = c['zoneName']
    circuit_idx = c['circuit']
    path = c['path']
    fname = c['file']
    
    img_path = os.path.join(BASE_DIR, f"{z_name}.jpg")
    if not os.path.exists(img_path):
        continue
    
    out_path = os.path.join(OUT_DIR, fname)
    
    try:
        img = mpimg.imread(img_path)
    except Exception as e:
        print(f"Failed to read image {img_path}: {e}")
        continue

    # WoW maps on wowhead might have different aspect ratios, but generally the coordinates 
    # (0 to 100) are mapped over the full image.
    fig, ax = plt.subplots(figsize=(10, 6.6), dpi=100)
    
    # extent=[left, right, bottom, top] -> left=0, right=100, bottom=100, top=0
    # because WoW Y axis is inverted (0 is top, 100 is bottom)
    ax.imshow(img, extent=[0, 100, 100, 0])
    
    # Hide axes
    ax.axis('off')
    
    xs = [p['x'] for p in path if p['kind'] in ('hub','obj')]
    ys = [p['y'] for p in path if p['kind'] in ('hub','obj')]
    
    # Draw path
    ax.plot(xs, ys, '-', color='#d9b245', lw=2, alpha=0.9, zorder=2)

    # Draw markers (tamaños reducidos para no tapar el mapa)
    for p in path:
        if p['kind'] == 'hub':
            ax.scatter([p['x']], [p['y']], s=70, marker='s', c='#39c75a', edgecolors='black', linewidths=0.6, zorder=4)
            ax.annotate('HUB', (p['x'], p['y']), textcoords='offset points', xytext=(7, -3),
                        color='#39c75a', fontsize=7, weight='bold', path_effects=[path_effects.withStroke(linewidth=2, foreground='black')])
        elif p['kind'] == 'obj':
            ax.scatter([p['x']], [p['y']], s=80, c='#d9b245', edgecolors='black', linewidths=0.6, zorder=4)
            ax.annotate(str(p['n']), (p['x'], p['y']), ha='center', va='center',
                        color='black', fontsize=6, weight='bold', zorder=5)
        else: # turnin
            ax.scatter([p['x']], [p['y']], s=60, marker='v', c='#e05c4f', edgecolors='black', linewidths=0.6, zorder=4)
            
    ax.set_title(f'{fac} — {z_name} — Circuito {circuit_idx}', color='white', fontsize=16, weight='bold',
                 path_effects=[matplotlib.patheffects.withStroke(linewidth=3, foreground='black')])
    
    fig.tight_layout(pad=0)
    fig.savefig(out_path, bbox_inches='tight', pad_inches=0)
    plt.close(fig)
    
    count += 1
    if count % 20 == 0:
        print(f"Rendered {count} maps...")

print(f"Done! Rendered {count} maps with real backgrounds.")

# 5. Generate HTML Viewer
html = "<html><head><title>Visor de Circuitos con Fondo</title><style>body { background-color: #1a1a1a; color: white; font-family: sans-serif; } .zone { margin-bottom: 30px; } .circuit { display: inline-block; margin: 10px; text-align: center; } img { border: 2px solid #555; border-radius: 8px; max-width: 400px; transition: transform .2s; } img:hover { transform: scale(1.5); }</style></head><body><h1>Circuitos de Misiones (Mapas Reales)</h1>"

zones_dict = {}
for c in circuits:
    fac = c['faction']
    z_name = c['zoneName']
    if z_name not in zones_dict:
        zones_dict[z_name] = []
    zones_dict[z_name].append((fac, c['file']))

for z_name in sorted(zones_dict.keys()):
    html += f"<div class='zone'><h2>Zona: {z_name}</h2>"
    for fac, fname in zones_dict[z_name]:
        html += f"<div class='circuit'><img src='circuit_maps_with_bg/{fname}'><br>{fname}</div>"
    html += "</div>"
    
html += "</body></html>"

with open('visor_circuitos_real.html', 'w', encoding='utf-8') as f:
    f.write(html)

print("Created visor_circuitos_real.html")
