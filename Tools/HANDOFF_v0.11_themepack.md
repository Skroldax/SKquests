# Handoff SKquests — estado v0.11.0 + integrar Theme Pack

Para la siguiente IA. Reglas del proyecto:
- Editar SIEMPRE el archivo real en `C:\Program Files\Ascension Launcher\resources\client\Interface\AddOns\SKquests\` (Read/Edit; el mount de bash está desincronizado).
- NO subir a git: `PRO_CODES.txt` ni `SKquests_ProCodes.lua` (gitignored).
- Scripts pesados (SQL, imágenes) corren en la máquina del usuario, no en sandbox.
- Cliente: WoW 3.3.5a (Ascension).

## Estado actual — YA FUNCIONA (v0.11.0)

- **Recompensas (dinero + XP)**: COMPLETO. `SKquests_Rewards.lua` (`[id]={m=cobre, x=xp}`) está en el `.toc` (línea 25) y en el addon. El detalle de quest muestra dinero (`GetCoinTextureString`) y XP (`rwd.x`), en pestaña quests y questlog. Datos: dinero de `quest_template` (TDB 335), XP de `quests_xp_db.json`. Generador: `Tools\gen_rewards.py` (escribe `Tools\SKquests_Rewards.lua` → copiar al addon).
  - NOTA: el addon tiene una versión (170 KB) y `Tools` tiene una más nueva (177 KB). Si faltan recompensas, re-copia la de Tools:
    `Copy-Item "C:\Users\skrol\OneDrive\Documentos\GitHub\SkQuests\Tools\SKquests_Rewards.lua" "C:\Program Files\...\SKquests\SKquests_Rewards.lua"`
- **Mapa de Azshara**: añadido a la lista blanca `CUSTOM_MAP_FILES` + `Media\Maps\Azshara.tga`. Funciona.
- **NPC "Archmage" (no "Archimago")**: `giverName`/`enderName` respetan idioma.
- **Línea duplicada "Starts with"** quitada de OBJETIVOS.
- **Guías**: circuitos ordenados por nivel; Wabbit Pelts y Kobold duplicado eliminados; "Wanted: Hogger" resuelto (matching tolerante en `GetQuestIdByName`).
- **Versión**: `.toc` en `Alpha 0.11.0`. Verificar que el CHANGELOG tenga la entrada 0.11.0; si no, añadirla (recompensas = feature).

## PENDIENTE 1: integrar el Theme Pack (6 temas, marcos pintados 9-slice)

El usuario generó marcos pintados (IA de imágenes) y se cortaron en 9-slice. El pack está en
`outputs\themepack\` (entregado como `SKquests_ThemePack.zip`). Cada tema:
`Corner_TopLeft/TopRight/BottomLeft/BottomRight.png`, `Edge_Top/Bottom/Left/Right.png`, `Background.png`
+ `SKquests_ThemePanel.lua` (helper) + `README.txt` con los insets.

Temas e inset (tamaño de esquina, px): BlizzardClassic 118, WrathClassic 130, Dragonflight 101,
Modern 96, WarcraftLogs 84, AscensionWoW 103.

Pasos de integración:
1. Copiar cada carpeta a `Media\Themes\<Tema>\` dentro del addon.
2. Convertir los PNG a **BLP** (BLPConverter / Ladik's MPQ Editor, conservando alfa). El helper
   usa `SetTexture` sin extensión (= BLP). Si se dejan como `.tga`, cambiar el helper para añadir `.tga`.
3. Añadir `SKquests_ThemePanel.lua` al `.toc` (antes de `SKquests_UI.lua`).
4. Aplicar al frame principal: `SKquests_ApplyThemePanel(MainFrame, "Dragonflight")` (o el tema elegido).
   - El helper hace 9-slice: esquinas fijas (inset por tema), bordes que se ESTIRAN entre esquinas,
     fondo al centro. Funciona en cualquier tamaño de ventana.
5. (Opcional) Reactivar un **selector de temas** en Ajustes que llame a `SKquests_ApplyThemePanel`
   y guarde la elección en `SKquestsDB.config.theme`. OJO: los temas se habían quitado del addon
   antes; esto los reintroduce como sistema de marcos (distinto del antiguo de paletas).

Aviso: los marcos son apaisados (~883×300 nativo); en ventanas muy altas los bordes laterales se
estiran bastante. Si un ornamento de esquina se ve cortado en un panel pequeño, baja el inset del
tema en `THEME_CORNER` dentro de `SKquests_ThemePanel.lua`.

## PENDIENTE 2: subir a GitHub (release 0.11.0)

```powershell
robocopy "C:\Program Files\Ascension Launcher\resources\client\Interface\AddOns\SKquests" "C:\Users\skrol\SKquests-repo" /E `
  /XD ".git" "RouteDrafts" "Media\Images Ally" "Media\Images Horde" "Media\Interfaz" "Media\Themes" `
  /XF "PRO_CODES.txt" "SKquests_ProCodes.lua" "*.bak" "*.bak2" "*.zip" "*.png" "*.tga" "*.blp" "*.jpeg" "skquests-repo.bundle"
cd C:\Users\skrol\SKquests-repo
git add -A
git status      # confirmar que NO aparezcan PRO_CODES.txt ni SKquests_ProCodes.lua
git commit -m "Release Alpha 0.11.0"
git push
git tag -a v0.11.0 -m "Alpha 0.11.0"
git push origin v0.11.0
```
Luego publicar la Release de `v0.11.0` en GitHub (el badge del README es dinámico, se actualiza solo).
Nota: las texturas (`*.png/.tga/.blp`, `Media\Themes`, `Media\Images*`) están excluidas del repo
(binarios pesados); se respaldan aparte. El código + datos sí suben.

## Archivos clave
- `SKquests_UI.lua` — UI principal (recompensas ~3593 y ~3863; lista blanca de mapas ~1991; SwitchTab ~3909).
- `SKquests_Rewards.lua` — datos de recompensa (generado; no editar a mano, usar `gen_rewards.py`).
- `SKquests_ThemePanel.lua` — helper 9-slice (en el zip del themepack).
- `SKquests.toc` — orden de carga + versión.
- `Tools\` — scripts y datasets (gen_rewards.py, quests_xp_db.json, quest_template_section.sql, etc.). No van al repo del addon.
