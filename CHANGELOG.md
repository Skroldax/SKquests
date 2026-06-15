# Changelog

All notable changes to SKquests will be documented in this file.
This project follows [Semantic Versioning](https://semver.org/) and [Keep a Changelog](https://keepachangelog.com/).

## [0.0.1-beta] - 2026-06-14

### Added
- **Mensaje temporal en pestaña Guías**: Se implementó una pantalla con el mensaje "Próximamente en futuras actualizaciones" en la pestaña de Guías.
- **Backups automáticos**: Creación de respaldos locales `.zip` de los archivos en funcionamiento.

### Fixed
- **Botón de inicio/fin de mapa superpuesto**: Se solucionó un problema de capas (strata/frame level) donde el botón de alternar mapa inicial/final se renderizaba por debajo de las texturas del mapa, haciéndose invisible. Ahora se asocia a `dChild` (hermano del mapa) y se dibuja correctamente al frente.
- **Rutas de mapas de capitales**: Se corrigieron errores de escritura en los nombres de las carpetas de mapas de capitales (`StormwindCity` -> `Stormwind`, `Ogrimmar` -> `Orgrimmar`, `Darnassis` -> `Darnassus`) en `ZoneMapFolder` que causaban que los mapas salieran en blanco al alternar el destino.
- **Detección de mapa de inicio por NPC Giver**: Se mejoró la lógica de detección del mapa inicial para usar la zona del NPC que entrega la misión en lugar del zoneId general, permitiendo que el botón de alternar mapa se muestre correctamente en misiones que inician y terminan en zonas distintas (ej. inicio en Ventormenta y entrega en Crestagrana).

### Removed
- **Limpieza de archivos innecesarios**: Eliminación de archivos residuales del repositorio (`.bak`, `.bak2`, `*_fixed.lua`, carpetas duplicadas de desarrollo y pruebas) para optimizar el tamaño de carga del Addon.

## [0.12.0-alpha] - 2026-06-13

### Added
- **Atlas de Zonas interactivo**: la pestaña Zonas muestra el mapa del continente (Kalimdor / Eastern Kingdoms) y, al elegir una zona en la lista, abre su mapa con los pines de misión. Los pines distinguen disponible (`!`), activa (`?` gris) y completa (`?` dorado), y al hacer clic saltan a la misión en la pestaña Quests.
- **Capas de detalle revelado en los mapas de zona**: los tiles base de WoW son el pergamino "sin descubrir"; ahora se dibujan encima las texturas de sub-área (desde `SKquests_MapData`) para mostrar el mapa completo, igual que el visor del detalle de misión. Renderizado con aspecto real 1002×668, tiles de borde 234/156 y recorte por `SetTexCoord`.
- **Marco temático pintado (9-slice)**: los temas Pro aplican un marco ornamentado alrededor de la ventana mediante texturas BLP recortadas en 9 segmentos (esquinas + bordes), con el contenido insertado para no tapar pestañas ni el botón de cerrar.
- **Filtros de la pestaña Zonas**: los botones Alianza / Horda / Ambos y las pestañas Kalimdor / Eastern Kingdoms ahora filtran la lista de zonas.

### Fixed
- **El mapa de Zonas no se dibujaba**: `RelayoutZonesMap` usaba `mapPins`/`questPinsPool` antes de su declaración (resolvían a global `nil` → `ipairs(nil)`), abortando el dibujado. Se declaran ahora como upvalues antes de las funciones que los usan.
- **Mapas de zona "sin revelar"**: el atlas dibujaba los 12 tiles estirados y sin recortar; ahora usa el mismo método del detalle de misión, incluyendo las capas de sub-área reveladas.
- **Apertura de zona fiable**: clic en la zona desde la lista abre su mapa de forma determinista (se descartó la detección por cursor, que devolvía la zona desfasada en este cliente).
- **Mazmorras/cuevas y subzonas iniciales sin mapa**: al clickearlas en la lista, redirigen a la pestaña Quests filtrada por la zona, en vez de mostrar una pantalla vacía.



### Added
- **Mejora del tema Blizzard Classic**: se procesó e integró una nueva textura de fondo de pergamino clara, suave y limpia (sin marcas de agua ni ruidos visuales molestos).
- **Tarjetas de selección de guías integradas**: ahora el fondo de las tarjetas de Alianza y Horda se adapta dinámicamente al tema, usando transparencias suaves (15% de opacidad) al usar fondos personalizados y respondiendo al hover dinámicamente.

### Fixed
- **Superposición de paneles en la interfaz**: corregido un error de renderizado donde las tarjetas de selección de guía se superponían con otras pestañas (como Acerca de) al cambiar de pestaña.
- **Sincronización del tema**: corregido un problema donde los cambios del tema no se aplicaban al panel de selección de guías debido a early returns y scripts OnLeave que forzaban colores sólidos.

## [0.11.0-alpha] - 2026-06-13

### Added
- **Base de datos de Experiencia completa**: se reemplazó la base de datos parcial de vanilla por una extracción completa desde los archivos internos de *Questie*. El archivo `SKquests_Rewards.lua` ahora cuenta con más de 9,400 valores exactos de experiencia base para todas las misiones (incluyendo las custom y WotLK).
- **Multiplicadores Dinámicos de XP**: integración nativa con la API de Questie (`QuestXP:GetQuestLogRewardXP`) para calcular en tiempo real los modificadores de experiencia por nivel, reliquias y Joyous Journeys.
- **Auras Custom de Ascension**: escáner automático de buffs del jugador en la interfaz para aplicar los bonos de experiencia propios de Ascension (Aura de Experiencia +50%, Pociones +25%, Aura de Prestigio +200%).
- **Visualización de Multiplicador**: la interfaz ahora desglosa la experiencia si tienes bonos, mostrando el total final junto a la base y el multiplicador exacto (ej. `334 XP (Base: 215 XP, x1.55)`).

### Fixed
- **Crashes por API faltante en 3.3.5**: la llamada nativa a `GetQuestLogRewardXP()` rompía silenciosamente la pestaña del *Quest Log* porque dicha función es de Cataclysm. Ahora se envuelve de forma segura y se calcula desde Questie.
- **Iconos invisibles en el Quest Log**: al ver una recompensa por primera vez, el icono salía como interrogación porque el servidor aún no la cacheaba. Se cambió el uso asíncrono de `GetItemInfo` por la lectura síncrona `GetItemIcon` desde los archivos locales.
- **Eliminación de misiones corruptas**: se borraron del código y la base de datos las misiones de prueba residuales ("The 'Chow' Quest (123)aa COPY").

## [0.10.17-alpha] - 2026-06-12

### Added
- **Menú desplegable de quests en líneas con varias**: al hacer clic en una línea de guía con varias quests, se abre un menú con cada una; al elegir, abre su ficha. Para líneas de una sola quest, el clic abre directamente. Robusto a redimensionar e idioma (no calcula posiciones).

### Fixed
- **Elementos de la guía colándose en el detalle de quest**: al ir de la guía a una quest, el encabezado de circuito ("circuit 4") y el mapa del circuito quedaban visibles detrás del detalle, y los botones de link colgaban interceptando clics. `RefreshDetail` ahora oculta también encabezados de circuito, cajas de mapa y botones de link de la guía.
- **Links de quest que no resolvían (p. ej. "Wanted: Hogger")**: la DB de pfQuest guarda algunos nombres con comillas o espacios dobles (`Wanted:  "Hogger"`), así que el nombre del texto no coincidía. Ahora `GetQuestIdByName` normaliza (minúsculas, sin comillas, espacios colapsados), por lo que el clic en cada quest de su línea (Aceptar/Hacer/Entregar) abre su ficha correctamente.

## [0.10.16-alpha] - 2026-06-12

### Fixed
- **Circuitos de guía ordenados por nivel**: dentro de cada zona los circuitos estaban desordenados (5-10, 5-11, 5-9, 5-8…). Ahora se ordenan por nivel inicial y final, conservando título/texto/imagen de cada uno (los mapas siguen coincidiendo).
- **Comillas mal anidadas (p. ej. "Wanted: Hogger")**: el texto traía comillas dentro de comillas que partían el nombre de la quest ("[Wanted: ]Hogger[]"). Corregido a un nombre limpio y enlazable.
- **Quest falsa "Wabbit Pelts" eliminada** de la guía Alianza.
- **Circuito duplicado de "Kobold Camp Cleanup" (Northshire) eliminado** (su quest ya estaba en el circuito completo).

## [0.10.15-alpha] - 2026-06-12

### Fixed
- **Mapas de quest restaurados**: se revirtió el ocultado de la caja de mapa en quests vanilla. Ahora las quests custom muestran su mapa azerothhub y las vanilla muestran su mapa WorldMap de zona con los pines de pfQuest. La lista blanca de `TryCustomMap` se mantiene para no intentar mapas custom inexistentes.

## [0.10.14-alpha] - 2026-06-12

### Fixed
- **Texto de pasos cortado con "..."**: las líneas largas de la guía se truncaban en vez de envolverse. Ahora el texto baja a la siguiente línea (ancho explícito + word wrap), aprovechando que el panel es scrolleable.
- **Mapa azerothhub en el detalle de quests vanilla**: la lista blanca mostraba el mapa de zona azerothhub (parecía "mapa de guía") en quests normales. Ahora la caja de mapa del detalle solo aparece para quests custom (con `bqCoord`); las vanilla ocultan la caja.
- **Mapas de zonas iniciales (Northshire / Valley of Trials) en negro**: sus mapas base no se descargaban desde la fuente original, dejando esos 5 circuitos sin imagen. Regenerados desde mapas base alternativos con marcadores reducidos.
- **Marcadores de circuito demasiado grandes**: reducido el tamaño de HUB/objetivos/entregas en el render para que no tapen el mapa.
- **Quest Log en blanco**: en WoW 3.3.5a `FauxScrollFrame_Update` oculta el frame del scroll cuando los ítems caben sin barra (p. ej. 1 misión activa); como las filas son hijas de ese frame, desaparecían todas. Se restauró `ListPanel.scroll:Show()` protegido por una guarda anti-recursión (`_inListUpdate`) para no reintroducir el stack overflow que motivó su eliminación en 0.10.5.
- **Mapas de circuito en negro**: las 436 imágenes de circuito estaban en TGA de 32 bits, formato que el cliente 3.3.5a suele renderizar en negro. Reconvertidas a TGA de 24 bits sin canal alfa (las imágenes son opacas), compatibles con el cliente.

- **Enlaces de quest repetidos en la guía**: cada nombre entrecomillado de una línea se resaltaba con el nombre del PRIMERO (ej. "[A Threat Within] and [A Threat Within]..."). Ahora cada quest usa su propio nombre localizado y el enlace apunta a la primera quest válida de la línea.
- **Título de circuito cortado a la izquierda**: el encabezado del circuito se anclaba a -20 px (fuera del borde). Ahora se alinea con "OBJECTIVES".
- **Cuadro negro en cada misión**: el cliente devuelve `true` en `SetTexture()` aunque el archivo no exista, así que la caja de mapa se mostraba en negro para zonas con textura WorldMap inexistente. Ahora se usa una lista blanca determinista de los mapas custom que sí existen (las 6 zonas iniciales); el resto oculta la caja en vez de mostrar un recuadro negro.

### Removed
- **Misión custom "Archmage Xylem"** (Azshara) eliminada de `BronzebeardQuestChains`.

## [0.10.5-alpha] - 2026-06-12

### Added
- **Hipervínculos en la guía**: el texto de misiones en la pestaña Guía detecta el nombre, lo localiza (`GetLocalizedQuestName`), lo resalta en azul y añade un botón invisible que redirige al detalle en Quests.
- **Conversión de assets**: procesamiento de imágenes PNG de circuitos a TGA potencia de 2 (512x512) para los pasos de la guía.

### Fixed
- Stack overflow por recursión en `RefreshList` (eliminado `scroll:Show()` — ver corrección en 0.10.6).
- Cuadros negros en detalles de misión (validación de `TryFolder` en `questImgBox:SetQuest`).
- Iconos `?` en botones de cadena: `◄`/`►` reemplazados por `Prev:`/`(Next)`.
- Traducciones de la guía vía `GetLocalizedQuestName` + filtrado de quests vacías/corruptas en `IsQuestEligible`.

## [0.9.0-alpha] - 2026-06-12

### Added
- Guías de leveo como función Pro: rejilla de tarjetas (autodetectadas desde `SKquests_Guides`) estilo Zonas; al elegir una se abre el panel de capítulos/pasos con imágenes.
- Pantalla de candado en la pestaña Guía hasta introducir un código Pro válido.

### Removed
- Selector de temas y editor de temas eliminados del build (solo paleta oscura).

### Changed
- El gating Pro ahora protege las guías (antes los temas). Stub público de `IsProUnlocked` devuelve `false` por defecto.


## [0.8.5-alpha] - 2026-06-12

### Added
- **Custom quest map support (azerothhub)**: custom quests from `BronzebeardQuestChains` now render their dedicated azerothhub starting-zone maps (Shadowglen, Northshire, Deathknell, Camp Narache, Valley of Trials, Coldridge Valley) with spawn pins placed directly from azerothhub coordinates.
- **Starting-zone pin alignment**: vanilla starting subzones (Shadowglen→Teldrassil, Northshire→Elwynn, Deathknell→Tirisfal, Camp Narache→Mulgore, Valley of Trials→Durotar, Coldridge→Dun Morogh) now project their pins onto the parent map using exact pfQuest coordinates, fixing previously misaligned spawn dots.

### Fixed
- **Duplicate "(Custom)" quests removed**: custom chain quests were being injected twice — once with a `(Custom)` name suffix and once clean — producing duplicate list entries. There is now a single, clean injection (synthetic ids `990000+`, normalized-name dedup against the main quest DB) with no suffix.
- **Event/junk quests hidden**: quests with no real level (`level <= 0`, e.g. event or class-trainer quests) and placeholder/test entries (`<TEST>`, `<UNUSED>`, `<NYI>`, Designer Island zone) are now hidden from the list unless they are custom or currently active in the tracker.

### Changed
- `_G.SKquests_CustomMapOffsets` is now populated from the bundled pfQuest `zones.data` (subzone bounding boxes) instead of hardcoded values, so map projection stays consistent across starting zones.

## [0.8.4-alpha] - 2026-06-11

### Added
- **Full Objective Map Pins System**: Restored and expanded the interactive map pins to show kill (red), interact (yellow), and gather (green) objectives, including clustering for nearby spawns.
- **Dynamic Color Palettes**: Added 6 different hex color variations for each objective category. Users can cycle through colors in real-time by doing `Ctrl + Click` on any pin.

### Fixed
- **Map Rendering Bug**: Fixed a `SetTexture` return value check that is unsupported in WoW 3.3.5a, which was preventing interactive maps from rendering.
- **Map View Reset**: Changing pin colors no longer resets the map zoom and pan state.
- **Missing Starting Zone Quests**: Fixed an issue where quests in starting subzones (like Valley of Trials or Northshire) were unlisted by dynamically merging them under their parent zone (e.g., Durotar, Elwynn Forest).
- **PvP Quests Filter**: PvP quests and Battleground zones are now filtered out from the database to keep the interface focused on PvE.

### Fixed
- **Quest Log map broken**: opening a quest in the Quest Log tab incorrectly displayed the map and coordinates of the last viewed quest in the Explorer tab, due to a stale ID reference. It now correctly identifies the active quest by its localized title and updates the map and details accordingly.
- **Starting Zones missing from Quests list**: missions for Valley of Trials, Northshire, etc., silently aborted the database filtering because `IsQuestEligible` performed string/number comparisons on `q.level` (e.g., `"5" > 60` in Lua 5.1). The filter now correctly uses `tonumber()` so starting zones appear again.
- **Map pins too thick and opaque**: reduced pin size from 10x10 to 6x6, added a glowing blend mode (`ADD`), and adjusted opacities and palettes to create a subtle, aesthetically pleasing glowing effect that makes the exact coordinate clearer when zoomed.
- **Customizable pin colors**: you can now cycle through 6 distinct color presets for map pins (gathering, killing, interacting) by `Ctrl + Left Click` on any pin. The map updates the colors instantly without resetting your zoom or pan position.

## [0.5.0-alpha] - 2026-06-11

### Added
- Two new themes available to everyone: **ElvUI Dark** and **Minimal Dark** (`SKquests_Themes.lua`), selectable from Settings by cycling the theme button (Oscuro → Claro → ElvUI Dark → Minimal Dark).
- **Theme editor gated behind an admin password** (`SKquests_ThemeEditor.lua`): hex input + native WoW color picker for background, accent, borders and text, with live preview and per-theme persistent overrides. Password is set in `SKQUESTS_ADMIN_PASSWORD` (default `SKadmin`); unlock persists per account.
- Spanish zone names from the bundled pfQuest esES zones database — the Zones tab, the zone dropdown and quest metadata now translate (e.g. "Valle de Villanorte") when the language is Spanish.

### Fixed
- **Quest Log always empty / active quests never marked**: the tracker misread `GetQuestLogTitle` return values (3.3.5 returns `isHeader` 5th and `isComplete` 7th; it read positions 4 and 6), so every entry looked like a header and the cache stayed empty. Active-quest dots (●/✔) in the explorer and the whole Quest Log tab now work.
- **Guide chapters not switching**: clicking a chapter changed the selection but never rebuilt the step list nor moved the current step. It now rebuilds chapters and jumps to the chapter's first step.
- **Blank rows when first opening the Quests tab**: the row pool was sized from a stale panel height. The list now recalculates on show and on resize.
- Language switching now also rebuilds zones, quest filters and guide chapters, and resets the zone filter, so no stale names remain after changing language.
- Localized remaining hardcoded strings (active-quest notice, database notices).

## [0.4.0-alpha] - 2026-06-10

### Added
- Interactive POI pins on the quest map, Wowhead-style: quest start ("!") and turn-in ("?") NPC locations from pfQuest spawn data, up to 5 spots per NPC. Pins scale with zoom, show a tooltip with the NPC name and coordinates, and print the location to chat on click.
- Map fallback for quests without a mapped zone (dungeons, missing zoneId): the viewer derives the zone from the quest giver's (or ender's) spawn location, so far fewer quests show a blank image.
- Full Spanish quest texts: title, objectives and description now come from the bundled pfQuest esES database (~4,900 quests) when the language is Spanish, with $B/$N token handling.
- Spanish leveling guide: all 383 steps (Alliance 208, Horde 175) machine-translated to understandable Spanish in `SKquests_Guide_esES.lua`; chapter titles and step text switch with the language. Quest names remain in English for in-game identification.

### Fixed
- Reward item icons stuck as "?" until hovered: uncached items are now requested from the server automatically and icons refresh as the data arrives (retry loop, up to ~5s).

## [0.3.0-alpha] - 2026-06-10

### Added
- Interactive quest map viewer replacing the static quest image: shows the quest's zone map (client WorldMap tiles), with mouse-wheel zoom (1x-3x), drag to pan, and click to reset. Zoom happens inside a clipped box, so the detail panel layout never shifts when zooming.
- Full EN/ES localization of the UI chrome (tabs, section headers, titles, counters, settings labels) via an extended `SKquests_Localization` with a live-refresh registry (`ApplyLanguage`).
- Language toggle button (Español/English) in the in-UI Settings panel; choice persists in `SKquestsDB.profile.language`.
- Quest titles now respect the active language: Spanish shows "Nombre (English)", English shows the original name only.

### Changed
- Zones tab now lists Vanilla (and Custom) zones only — TBC and WotLK zones removed per design.
- Default language set to Spanish (esES), matching the original UI.
- Reverted the per-zone guide-image fallback from 0.2.0 (guide images don't correspond to quests); the map viewer covers quest visuals now.

### Removed
- `/skq config` command and its help entry — settings live inside the main interface.

## [0.2.0-alpha] - 2026-06-10

### Added
- Expansion label next to each zone in the Zones tab, color-coded: Vanilla (gray), TBC (green), WotLK (blue), Custom (light blue).
- `ZoneExpansion` table mapping every zoneId to its expansion; Designer Island and Darkspear Strand flagged as Custom.
- Deterministic per-zone quest images: quests with a placeholder image now display an image from `Media/Images Ally|Horde` selected by zoneId and active guide faction.
- Quest rewards merged into the bundled pfQuest database (`Media/db/quests.lua`, `Media/db/quests-tbc.lua`): 2,953 entries with `["rew"]` (fixed rewards) and `["rewc"]` (choice rewards) in `{itemId, quantity}` format, sourced from SKquests_DetailDB. Backups kept as `.bak`.

### Fixed
- Sidenav tab buttons not switching tabs: `ApplyTheme` read `btn.txt` while buttons stored the FontString as `btn.text`, aborting `SwitchTab` mid-click (errors at SKquests_UI.lua:317/320).
- `attempt to call global 'SafePrint' (a nil value)` when changing language in Settings — replaced undefined `SafePrint` with a standard `print` call.
- "Frame SKquestsMainFrame is not movable" error when dragging a locked frame — `OnDragStart` now checks `IsMovable()` first.
- Zone filter dropdown in the Quest Explorer rendered empty: it referenced an out-of-scope variable and only populated on scroll. It now reads `uniqueZones` and populates on show.
- Zones appearing with no quests (Howling Fjord, Strand of the Ancients, Isle of Conquest, Eye of the Storm): the Zones tab and the quest list used different level filters. Both now share a single `IsQuestEligible()` predicate, so empty zones can no longer appear.
- Unnamed zones "Zona 24" and "Zona 35" removed from the zone list (zoneIds without a ZoneMap entry are skipped).
- `ZoneMap[9]` mislabeled as "Mulgore" — corrected to "Northshire Valley" (real Mulgore is zoneId 215). Human starting quests no longer appear under Mulgore.

### Changed
- Removed debug `print()` spam from `BuildZonesList` and `BuildFilteredQuestIds` (fired on every filter change).

## [0.1.x-alpha] - pre-release development record

Comprehensive rebuild after integrating the full server database (`quest_template`), focused on stability, performance and a clean user experience.

### Added
- **Database migration & optimization**: parsed the full `quest_template` dump (7,100+ quests) and converted it into a native, heavily optimized Lua table (`SKquests_DetailDB.lua`) that the WoW engine loads instantly without excessive memory use.
- **Smart filtering engine (Vanilla purity)**: new `BuildFilteredQuestIds` sanitizes the list — junk/test/unimplemented quests (`<UNUSED>`, `<NYI>`, `<TXT>`) are hidden, and a strict expansion block filters out all TBC/WotLK quests and anything above level 60. The raw list went from 7,119 chaotic entries to a clean, playable 4,695 quests.
- **Dynamic zone resolution (ZoneMap)**: the database only provided raw numeric IDs (e.g. 1581). A scraper extracted all 105 unique zone IDs and a full translation dictionary was injected into the UI, covering open-world zones, capitals, dungeons and raids — actual names ("The Deadmines", "Kharanos") instead of "Zone 1581".
- **UI & performance**: perfected the `FauxScrollFrame` system (4,695 quests scrolling at 60 FPS with zero lag) and repaired button layouts so long guide texts no longer word-wrap over other UI elements.

### Fixed
- **Rendering crash**: silent `btn.text`/`btn.txt` typo destroying the UI rendering cycle and leaving the main list blank.
- **Zone filter crash**: `zonesData` variable scoping issue that made the zone dropdown fail silently and render as a black box.
- **Tab freezing**: reconnected the Sidenav logic — clicking "Quest Log" or "Zones" did not refresh the central list.
- **Sorting protection**: wrapped `table.sort` in `pcall` so minor database inconsistencies can't halt the entire addon.
