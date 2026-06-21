# SKquests (Season of Discovery)

Leveling guide and quest database explorer addon for **World of Warcraft Classic Era — Season of Discovery**, built on top of the original SKquests project and adapted to run on SoD-flavored servers.

![Version](https://img.shields.io/github/v/release/Skroldax/SKquests?include_prereleases&label=version&color=orange)
![Interface](https://img.shields.io/badge/interface-11508-blue)

## Features

- **Leveling guide 1–60**: Step-by-step leveling routes for Alliance and Horde, complete with detailed objectives, coordinates, and custom maps per step.
- **Quest database explorer**: Explore thousands of quests with name, NPC, or zone search, alongside level and zone filters.
- **Interactive map viewer**: Seamless map preview inside the quest details panel, supporting wheel zoom (1x–3x), drag to pan, and click to reset, keeping the layout static.
- **Zones tab**: Displaying expansion labels, level ranges, and total quests per zone.
- **Integrated Tracker (Quest Log)**: Real-time quest objective tracking with collapsible quests and automatic filtering to your current zone.
- **Live quest-progress tooltips**: Hovering a world NPC, a gameobject (herb/ore/chest), or a map pin shows the exact objective progress tied to it (e.g. "Prairie Wolf Paw: 5/6"). Matching is name/word-aware so it won't show unrelated objectives from the same multi-objective quest.
- **Experience Appraiser**: A full XP/efficiency toolkit with dedicated tabs — **Session** (live XP/h, time-to-level estimate), **Stats** (persistent totals: playtime, quests completed/abandoned, mobs killed, XP, levels, gold, deaths), **Time** (breakdown of session time by activity: questing, combat, travel, flying, city, AFK, dead), **NPCs** (passively logged NPCs with name/zone/coords, searchable), **Mobs** (kills and average XP per mob, with observed loot odds from your own kills), and **Quests** (a "Worth It?" XP/min efficiency rating per quest).
- **Dynamic SoD XP multiplier detection**: Automatically detects the active Season of Discovery XP buff instead of relying on a manual multiplier selector.
- **Custom data collector**: Passively captures SoD-specific quests, NPCs, and items that aren't in the static database as you play, and merges them into your local quest database (`/skq merge`).
- **Rewards**: Shows fixed and choice rewards per quest, with integrated items directly supported in the bundled pfQuest database (`["rew"]` / `["rewc"]`).
- **Quest chains**: Links to previous/next quests in the chain and direct links to Wowhead.
- **Bilingual Interface**: Seamlessly switch between Spanish and English in real-time from the Settings tab.
- **Themes**: Elegant Dark and Light (parchment) themes, with a resizable and lockable window.

## Installation

1. Download the latest release from [Releases](../../releases).
2. Extract the `SKquests` folder into the `Interface\AddOns\` directory of your Classic Era / Season of Discovery client.
3. Restart the client or run `/reload`.

## Usage

| Command | Action |
|---|---|
| `/skq` | Toggle UI window |
| `/skq lang enUS\|esES` | Switch language |
| `/skq merge` | Merge passively-collected SoD data (quests/NPCs/items) into the local database |
| `/skq help` | Show help |

Settings (theme, opacity, language, window size, zone filter) can be configured directly in the **Settings** tab within the UI.

## Project Structure

```
SKquests/
├── SKquests.lua                  # Core: events, slash commands, state
├── SKquests_UI.lua               # Main UI window (tabs, layouts, interactive map, tooltips)
├── SKquests_Tracker.lua          # Active quest tracker / Mini-Tracker
├── SKquests_Collector.lua        # Runtime collector for SoD-specific quests/NPCs/items
├── SKquests_Stats.lua            # Combat log, loot, and kill tracking (Experience Appraiser data)
├── SKquests_XPTracker.lua        # Experience Appraiser window (Session/Stats/Time/NPCs/Mobs/Quests tabs)
├── SKquests_Risk.lua             # Hardcore-style risk classification per quest/zone
├── SKquests_Rewards.lua          # Quest reward data and rendering
├── SKquests_ObjectiveDB.lua      # NPC/object ↔ quest objective links and spawn data
├── SKquests_SpawnData_Questie.lua# Spawn coordinate data
├── SKquests_MapData.lua          # Map/zone metadata for the interactive map viewer
├── SKquests_Marks.lua            # Custom map markers
├── SKquests_Themes.lua           # Theme definitions (Dark/Light)
├── SKquests_ThemeEditor.lua      # In-UI theme editor
├── SKquests_MinimapButton.lua    # Minimap launcher button
├── SKquests_Localization.lua     # EN/ES translation strings
├── SKquests_DetailDB.lua         # Quest database (auto-generated)
├── Alliance_1_60.lua             # Alliance leveling guide
├── Horde_1_60.lua                # Horde leveling guide
├── SKquests_Guide_esES.lua       # Spanish leveling guide strings
├── BronzebeardQuestChains.lua    # Quest chain links
├── quest_origin_pfquest.lua      # Quest expansion source (classic/tbc)
└── Media/                        # Images, logos, and pfQuest DB
```

## Data Sources

Quest, NPC, and reward data are built from:

- [pfQuest](https://github.com/shagu/pfQuest) — classic quest database client (included in `Media/db/`)
- [AzerothCore](https://www.azerothcore.org/) — `quest_template` and world database reference
- [Wowhead](https://www.wowhead.com/classic/) — chain, level, and reward validation
- The addon's own **runtime collector**, for Season of Discovery–specific quests, NPCs, and items not present in the static databases

## Changelog

See [CHANGELOG.md](CHANGELOG.md). This project follows [Semantic Versioning](https://semver.org/).

## Author

**Skroldax**

## License

GNU GPL v3. Leveling guides are based on public community classic routes; quest databases are sourced from the public repositories listed in [Data Sources](#data-sources).
