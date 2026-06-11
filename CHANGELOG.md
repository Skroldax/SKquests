# Changelog

All notable changes to SKquests will be documented in this file.
This project follows [Semantic Versioning](https://semver.org/) and [Keep a Changelog](https://keepachangelog.com/).

## [0.7.0-alpha] - 2026-06-11

### Added
- **Cartographer Foglight integration**: the interactive map now dynamically overlays the colored map patches on top of zone maps to reflect quest areas, replacing fog-of-war shadows while keeping the visual design intact.
- **Cross-zone navigation**: directional arrows (`<` and `>`) anchored to the map viewer edges let the player visually switch between the quest-start zone map and the turn-in zone map when a quest requires traveling between zones (e.g. Redridge to Stormwind).
- **Secondary lookup engine (pfQuest)**: the navigation arrows query the pfQuest database directly for turn-in NPCs missing from the local database (such as General Marcus Jonathan), enabling seamless map transitions on complex quests.

### Fixed
- **Spawn-point reload**: worked around a native 3.3.5 (WotLK) quirk where unchecking "Show spawn points" did nothing (the engine returned `nil` instead of `false`). Toggling the checkbox now reloads the map instantly without switching quests.
- **Map layer priority (z-index)**: the sepia base map was covering Cartographer's colored highlights because the 3.3.5 engine ignores numeric sub-layers. The base map is now forced to the `BACKGROUND` layer while the colors live permanently on `ARTWORK`.
- **Map mirage protection**: rescue logic in the map renderer — if the turn-in map of a capital city fails to load its textures (an occasional client issue), the viewer locks the flat image instead of misleadingly showing the start-zone map underneath the pins.
- **Lua syntax cleanups**: removed multiple syntax errors and BOM (Byte Order Mark) artifacts that prevented the UI from loading after code injections.

## [0.6.0-alpha] - 2026-06-11

### Added
- **All 7 themes** from the design sheet: ElvUI Dark and Minimal Dark free for everyone; Blizzard Classic, Dragonflight, Wrath Classic, RUF Modern and Warcraft Logs as **Pro Mode** themes.
- **Pro Mode with redeemable codes**: 30 random codes (`SKPRO-XXXX-XXXX`) validated in-game through an in-UI popup — no file editing needed. Codes live in `SKquests_ProCodes.lua`, which is **git-ignored** so they never reach the public GitHub repo. Unlock persists per account.
- **Theme dropdown** in Settings replacing the cycle button: lists every theme, marks locked ones with [Pro], and selecting a locked theme prompts for a code and applies it on unlock.
- Theme editor now Pro-gated, opens above the main window (strata fix), and edits 6 colors (background, hover, accent, titles, borders, text) with live preview.
- **Quest Log detail enriched from the game client**: description now falls back to the real quest text from the quest log (`GetQuestLogQuestText`) when the database lacks it — fixes quests like the Ascension-reworked starters showing "Desconocido"/empty info.

### Fixed
- Pro/admin password popup could open behind the main window (frame strata).

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
