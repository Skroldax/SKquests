# Changelog

All notable changes to SKquests will be documented in this file.
This project follows [Semantic Versioning](https://semver.org/) and [Keep a Changelog](https://keepachangelog.com/).

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

## [0.1.5-alpha] - earlier

- Previous development snapshot (pre-changelog).
