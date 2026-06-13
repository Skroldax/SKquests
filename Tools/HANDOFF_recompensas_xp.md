# Handoff SKquests — Recompensas (dinero ✅ / XP pendiente) y cierre 0.11.x

Para la siguiente IA. Continúa desde aquí. Reglas del proyecto:
- Editar SIEMPRE el archivo real en `C:\Program Files\Ascension Launcher\resources\client\Interface\AddOns\SKquests\` (el mount de bash está desincronizado/truncado; usar Read/Edit).
- NO subir a git: `PRO_CODES.txt` ni `SKquests_ProCodes.lua` (privados, gitignored).
- Los scripts pesados (parseo SQL, conversión imágenes) se ejecutan en la máquina del usuario, no en el sandbox (escribe ahí con permisos; bash del sandbox no persiste a la carpeta real).

## Estado actual (todo esto YA funciona, confirmado por el usuario)

- **Versión** en `.toc`: `Alpha 0.10.17`.
- **Mapa de Azshara**: arreglado. Se añadió `Azshara = true` a la lista blanca `CUSTOM_MAP_FILES` en `SKquests_UI.lua` (función `TryCustomMap`, ~línea 1991) y el usuario colocó `Media\Maps\Azshara.tga`. Se ve bien.
- **Nombre de NPC "Archimago" → "Archmage"**: `giverName`/`enderName` ahora usan `(IsSpanish() and q.giver_loc) or q.giver` (respetan idioma) en `SKquests_UI.lua` (~3388 y ~3601 giver; ~3396 y ~3609 ender).
- **Línea duplicada "Starts with / Turn in to"** eliminada de la sección OBJETIVOS (se quitó el append de `STARTS_WITH`/`ENDS_WITH` a `objText`, ~línea 3371).
- **Dinero de recompensa**: FUNCIONA. 
  - Datos extraídos de `quest_template` (TrinityCore TDB 335) → script `Tools\gen_rewards.py` genera `SKquests_Rewards.lua` con `[id]={m=dinero_cobre, l=nivel, d=RewardXPDifficulty}`.
  - `SKquests_Rewards.lua` ya está en el `.toc` (antes de `SKquests_UI.lua`).
  - Display: en `RefreshDetail` (pestaña quests, ~línea 3420) se muestra `GetCoinTextureString(rwd.m)` en `rewardSec.moneyLbl` (etiqueta arriba-derecha del panel de recompensas, creada ~línea 2461). El panel se muestra aunque solo haya dinero (sin items).

## PENDIENTE: integrar el XP (es lo único que falta)

El usuario consiguue un JSON con el XP directo por questID:
- `Tools\quests_xp_db.json` (333 KB), formato:
  ```json
  { "522": { "name": "Assassin's Contract", "xp": 700 }, "523": {...}, ... }
  ```
  (XP directo, no índice de dificultad — mucho mejor.)

### Paso 1 — modificar `Tools\gen_rewards.py` para incluir el XP directo

Edita `gen_rewards.py` así (añade lectura del JSON y el campo `x`):

```python
import re, os, json

TOOLS = os.path.dirname(os.path.abspath(__file__))
SQL = os.path.join(TOOLS, 'quest_template_section.sql')
XPJSON = os.path.join(TOOLS, 'quests_xp_db.json')
OUT = r'C:\Program Files\Ascension Launcher\resources\client\Interface\AddOns\SKquests\SKquests_Rewards.lua'

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
```

Luego ejecuta (PowerShell **como administrador**, escribe en Program Files):

```powershell
cd "C:\Users\skrol\OneDrive\Documentos\GitHub\SkQuests\Tools"
python gen_rewards.py
```

### Paso 2 — mostrar el XP directo en `SKquests_UI.lua`

En `RefreshDetail` (~línea 3420), el bloque actual calcula XP con una tabla `SKquests_QuestXP` que NO existe. Cámbialo para usar `rwd.x` directo. Busca:

```lua
            if SKquests_QuestXP and rwd.d and rwd.d > 0 and rwd.l and SKquests_QuestXP[rwd.l] then
                local xp = SKquests_QuestXP[rwd.l][rwd.d]
                if xp and xp > 0 then rwParts[#rwParts + 1] = "|cffffd200" .. xp .. " XP|r" end
            end
```

y reemplázalo por:

```lua
            if rwd.x and rwd.x > 0 then
                rwParts[#rwParts + 1] = "|cffffd200" .. rwd.x .. " XP|r"
            end
```

(También sirve para la pestaña questlog si se quiere; el bloque de quests es el principal.)

### Paso 3 — verificar
`/reload` y abrir varias quests: deben mostrar **dinero (oro/plata/cobre) + "N XP"** en el panel de recompensas. Quests sin XP en el JSON simplemente no muestran XP (normal — el JSON cubre vanilla).

## Cierre: versión, changelog y push

1. `SKquests.toc`: subir a `## Version: Alpha 0.11.0` (recompensas = feature, +0.1.0 desde 0.10.x).
2. `CHANGELOG.md`, añadir arriba:
   ```markdown
   ## [0.11.0-alpha] - 2026-06-13

   ### Added
   - **Recompensas de quest**: el detalle ahora muestra el dinero (oro/plata/cobre) y el XP de cada misión. Dinero extraído de quest_template (TDB 335); XP de una base de datos de XP vanilla. Datos en SKquests_Rewards.lua.

   ### Fixed
   - Mapa de Azshara (zona sin WorldMap en el cliente): añadida a la lista blanca de mapas custom (Media\Maps\Azshara.tga).
   - Nombre de NPC respeta el idioma (mostraba "Archimago" en inglés; ahora "Archmage").
   - Quitada la línea duplicada "Starts with / Turn in to" de OBJETIVOS (ya está en START/TURN IN).
   ```
3. Push (revisar que NO suban privados):
   ```powershell
   robocopy "C:\Program Files\Ascension Launcher\resources\client\Interface\AddOns\SKquests" "C:\Users\skrol\SKquests-repo" /E `
     /XD ".git" "RouteDrafts" "Media\Images Ally" "Media\Images Horde" "Media\Interfaz" `
     /XF "PRO_CODES.txt" "SKquests_ProCodes.lua" "*.bak" "*.bak2" "*.zip" "*.png" "*.tga" "*.blp" "*.jpeg" "skquests-repo.bundle"
   cd C:\Users\skrol\SKquests-repo
   git add -A
   git status   # confirmar que NO aparezcan PRO_CODES.txt ni SKquests_ProCodes.lua
   git commit -m "Release Alpha 0.11.0"
   git push
   git tag -a v0.11.0 -m "Alpha 0.11.0"
   git push origin v0.11.0
   ```
   Luego publicar la Release de `v0.11.0` en GitHub (el badge del README es dinámico y se actualizará solo).

## Notas / atribución
- El XP viene de un dataset externo (vanilla); el dinero de TDB/quest_template. Mantener la atribución a Questie/pfQuest/azerothhub en THIRD_PARTY.md como hasta ahora.
- `SKquests_Rewards.lua` es generado: NO editarlo a mano, regenerar con `gen_rewards.py`.
- Archivos de datos grandes (`quest_template_section.sql`, los `.json`, el TDB) viven en `Tools` (no en el addon) — no van al repo del addon.
