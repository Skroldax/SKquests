# HANDOFF: Project Ascension Custom Quests & Rewards Integration

This handoff details the status of the 100% completed database scrape of custom quests, rewards, and spawn coordinates from Project Ascension, and provides instructions on how to integrate them into the `SKquests` addon without breaking the game.

---

## 1. Scrape Results Summary
We successfully scraped all **4,988** custom quests and their corresponding metadata. The raw, parsed JSON files are located in the local git repository under:
📁 **[`Tools/ascension_scraped/`](file:///C:/Users/skrol/OneDrive/Documentos/GitHub/SkQuests/Tools/ascension_scraped/)**

### Files in this directory:
1. **`custom_quests_list.json`** — Basic header info and metadata (levels, faction, item rewards) for the 4,988 custom quests.
2. **`parsed_quests_details.json`** — Quest details including sanitized titles, objectives (`obj_text`), descriptions (`desc_text`), infobox data (start/end NPCs, prerequisites), coordinates, and items.
3. **`parsed_units_coords.json`** — Coordinate data parsed for custom units/NPCs.
4. **`parsed_objects_coords.json`** — Coordinate data parsed for custom world objects.

---

## 2. Technical Decisions & Sanitization
During the scraping and testing process, we implemented several critical fixes that should be kept in mind for future integration:
- **Junk Removal:** Scraped quest texts originally contained HTML fragments, JavaScript mappings (`new Mapper`, `var g_mapperData`, `CDATA`), and raw newline formatting. These have been completely stripped using regex sanitization.
- **Single-Line Formatting:** To match the standard WoW database structure in `SKquests_DetailDB.lua` (one quest table per line) and avoid game client Lua parsing crashes, any carriage returns or newlines were replaced with spaces, and double brackets `[[` and `]]` were escaped.
- **Overlap Resolution:** Many custom quest IDs (e.g., lower IDs like 3, 4, 41, 108) overlap with standard Blizzard quest IDs. When integrating, custom quest records must either overwrite or append at the end of `SKquests_DetailDB.lua` to properly override the classic values via Lua's table assignment.

---

## 3. Current State
- **Reverted Modifications:** All modifications to the game directory files and repository files (`SKquests_DetailDB.lua`, `Media/` folder) have been **completely reverted**. 
- **Addon Status:** The addon and standard in-game quests are working perfectly.
- **No Git Commit/Push:** Reverted database changes were not committed or pushed to GitHub, keeping the remote main branch clean.

---

## 4. Next Steps for the Next Session
To proceed with integrating the scraped data without breaking the game client:

### A. Testing Custom Quest Databases (pfQuest/pfDB compatibility)
You can compile the JSON results into the pfDB tables in `Media/db ascension/` using a Python compiler:
- The script [generate_lua_dbs.py](file:///C:/Users/skrol/.gemini/antigravity/brain/932045aa-ec6f-479c-8db2-bb5a19244bc6/scratch/generate_lua_dbs.py) compiles `parsed_quests_details.json` into:
  - `Media/db ascension/quests-ascension.lua` (Quest metadata)
  - `Media/db ascension/enUS/quests-ascension.lua` (Clean, localized quest texts)
  - `Media/db ascension/units-ascension.lua` & `Media/db/units-ascension.lua` (Merged NPC coords)
  - `Media/db ascension/objects-ascension.lua` & `Media/db/objects-ascension.lua` (Merged object coords)

### B. Appending to UI Database (`SKquests_DetailDB.lua`)
To integrate custom quests into the search index:
1. Run [append_custom_quests.py](file:///C:/Users/skrol/.gemini/antigravity/brain/932045aa-ec6f-479c-8db2-bb5a19244bc6/scratch/append_custom_quests.py) to append the sanitized custom quest rows to the end of `SKquests_DetailDB.lua`.
2. Verify that the file compiles without syntax errors by running a brace/bracket matching check (e.g., using `check_lua_braces.py`).
3. Load the game and confirm that custom quests are searchable and load their details correctly in the UI.
