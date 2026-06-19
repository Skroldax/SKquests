# SKquests

Leveling guide and quest database explorer addon for **World of Warcraft 3.3.5a** (WotLK), developed for [Project Ascension](https://ascension.gg/) and compatible with any 3.3.5a server.

![Version](https://img.shields.io/github/v/release/Skroldax/SKquests?include_prereleases&label=version&color=orange)
![Interface](https://img.shields.io/badge/interface-30300-blue)

## Features

- **Leveling guide 1–60**: Step-by-step leveling routes for Alliance and Horde, complete with detailed objectives, coordinates, and custom maps per step.
- **Quest database explorer**: Explore over 5,000 quests with name, NPC, or zone search, alongside level and zone filters.
- **Interactive map viewer**: Seamless map preview inside the quest details panel, supporting wheel zoom (1x–3x), drag to pan, and click to reset, keeping the layout static.
- **Zones tab**: Displaying expansion labels (Vanilla/Custom), level ranges, and total quests per zone.
- **Integrated Tracker (Quest Log)**: Real-time quest objective tracking.
- **Rewards**: Shows fixed and choice rewards per quest, with integrated items directly supported in the bundled pfQuest database (`["rew"]` / `["rewc"]`).
- **Quest chains**: Links to previous/next quests in the chain and direct links to Wowhead.
- **Bilingual Interface**: Seamlessly switch between Spanish and English in real-time from the Settings tab.
- **Themes**: Elegant Dark and Light (parchment) themes, with a resizable and lockable window.

## Installation

1. Download the latest release from [Releases](../../releases).
2. Extract the `SKquests` folder into the `Interface\AddOns\` directory of your 3.3.5a client.
3. Restart the client or run `/reload`.

## Usage

| Command | Action |
|---|---|
| `/skq` | Toggle UI window |
| `/skq lang enUS\|esES` | Switch language |
| `/skq help` | Show help |

Settings (theme, opacity, language, window size) can be configured directly in the **Settings** tab within the UI.

## Project Structure

```
SKquests/
├── SKquests.lua              # Core: events, slash commands, state
├── SKquests_UI.lua           # Main UI window (tabs, layouts, interactive map)
├── SKquests_Tracker.lua      # Active quest tracker
├── SKquests_Config.lua       # Legacy config panel
├── SKquests_Localization.lua # EN/ES translation strings
├── SKquests_DetailDB.lua     # Quest database (auto-generated)
├── Alliance_1_60.lua         # Alliance leveling guide
├── Horde_1_60.lua            # Horde leveling guide
├── quest_origin_pfquest.lua  # Quest expansion source (classic/tbc)
└── Media/                    # Images, logos, and pfQuest DB
```

## Data Sources

Quest, NPC, and reward data are built from:

- [pfQuest](https://github.com/shagu/pfQuest) — classic quest database client (included in `Media/db/`)
- [AzerothCore](https://www.azerothcore.org/) — `quest_template` and 3.3.5a world databases
- [Wowhead](https://www.wowhead.com/wotlk/) — chain, level, and reward validation (WotLK Classic version)
- [Ascension Database](https://db.ascension.gg/) — custom quests and items from Project Ascension

## Changelog

See [CHANGELOG.md](CHANGELOG.md). This project follows [Semantic Versioning](https://semver.org/).

## Author

**Skroldax** 
https://discord.gg/vUtNFcK4Z8 Discord for you get updates :D

## License

Personal project in development. Leveling guides are based on public community classic routes; quest databases are sourced from the public repositories listed in [Data Sources](#data-sources).
