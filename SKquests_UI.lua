--[[
    SKquests - WoW Leveling Guide & Quest Database Explorer Addon
    Copyright (c) 2026 Skroldax. All rights reserved.
    
    This program is free software: you can redistribute it and/or modify
    it under the terms of the GNU General Public License as published by
    the Free Software Foundation, either version 3 of the License, or
    (at your option) any later version.
    
    This program is distributed in the hope that it will be useful,
    but WITHOUT ANY WARRANTY; without even the implied warranty of
    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the
    GNU General Public License for more details.
--]]

-- File: SKquests_UI.lua
-- Rediseño completo de la interfaz de SKquests al estilo Web 3 Columnas
-- Soporta modo oscuro/claro, ventana ajustable y pestañas dinámicas.
-- Versión Alpha 0.11.4

local addon = SKquests
local HBD = LibStub("HereBeDragonsQuestie-2.0")
local HBDPins = LibStub("HereBeDragonsQuestie-Pins-2.0")

-- Inicializar referencias de Guias globales
SKquests_Guides = {
    Alliance = SKquests_Alliance,
    Horde = SKquests_Horde
}

local L = function(key) return SKquests_Localization and SKquests_Localization:Get(key) or key end

-- Season of Discovery: detección dinámica del buff "Discoverer's Delight"
-- (Spell ID 436412, otorgado/activado vía el posadero) para multiplicar la
-- XP de quests mostrada en la guía. Tramos según el buff real de Blizzard:
--   nivel <=39: +150% XP (x2.5)   nivel 40-49: +100% XP (x2.0)   nivel 50+: sin bono confirmado (x1.0)
local SOD_DISCOVERERS_DELIGHT_SPELLID = 436412
local SOD_DISCOVERERS_DELIGHT_NAME = "Discoverer's Delight"

local function IsDiscoverersDelightActive()
    for i = 1, 40 do
        local name, _, _, _, _, _, _, _, _, _, spellId = UnitAura("player", i, "HELPFUL")
        if not name then break end
        if spellId == SOD_DISCOVERERS_DELIGHT_SPELLID or name == SOD_DISCOVERERS_DELIGHT_NAME then
            return true
        end
    end
    return false
end

local function GetSoDXPMultiplier()
    if not IsDiscoverersDelightActive() then
        return 1
    end
    local level = UnitLevel and UnitLevel("player") or 0
    if level <= 39 then
        return 2.5
    elseif level <= 49 then
        return 2.0
    else
        return 1.0
    end
end

-- ============================================================
--  TOOLTIP DE PROGRESO EN MOBS/NPCS DEL MUNDO
--  Al pasar el mouse sobre un NPC vivo en el mundo (no en un mapa
--  de SKquests), si ese NPC es parte de un objetivo de una quest
--  activa (matar al NPC, o farmear un item que dropea), se agrega
--  una linea al tooltip nativo con el progreso actual (ej "0/5").
-- ============================================================
local function SKQ_NpcIdFromGuid(guid)
    if not guid or guid == "" then return nil end
    -- Formato del servidor (confirmado via idTip): "Creature-0-1469-0-11-2951-0000123456"
    local id = tonumber(guid:match("-(%d+)-%x+$"), 10)
    if id and id > 0 then return id end
    -- Fallback: formato hex clasico "0xF130001E2A000B87"
    id = tonumber(guid:sub(7, 10), 16)
    if id and id > 0 then return id end
    return nil
end

-- Gradiente de color segun progreso: rojo (0%) -> amarillo (50%) -> verde (100%)
local SKQ_COLOR_RED    = {1.00, 0.15, 0.15}
local SKQ_COLOR_YELLOW = {1.00, 0.85, 0.10}
local SKQ_COLOR_GREEN  = {0.15, 1.00, 0.15}

local function SKQ_LerpColor(c1, c2, t)
    return c1[1] + (c2[1] - c1[1]) * t,
           c1[2] + (c2[2] - c1[2]) * t,
           c1[3] + (c2[3] - c1[3]) * t
end

local function SKQ_ProgressColor(numDone, numTotal, done)
    if done then
        return SKQ_COLOR_GREEN[1], SKQ_COLOR_GREEN[2], SKQ_COLOR_GREEN[3]
    end
    if not numTotal or numTotal <= 0 then
        return SKQ_COLOR_YELLOW[1], SKQ_COLOR_YELLOW[2], SKQ_COLOR_YELLOW[3]
    end
    local pct = (numDone or 0) / numTotal
    if pct < 0 then pct = 0 elseif pct > 1 then pct = 1 end
    if pct <= 0.5 then
        return SKQ_LerpColor(SKQ_COLOR_RED, SKQ_COLOR_YELLOW, pct / 0.5)
    else
        return SKQ_LerpColor(SKQ_COLOR_YELLOW, SKQ_COLOR_GREEN, (pct - 0.5) / 0.5)
    end
end

-- Cuenta cuantas palabras del nombre de la unidad aparecen en el texto del
-- objetivo. Esto cubre tanto objetivos de "matar" (el texto suele contener el
-- nombre completo del NPC, ej. "Palemane Poacher slain: 0/5") como objetivos
-- de "recolectar item" donde el item comparte raiz con la familia del mob
-- (ej. unidad "Prairie Wolf Alpha" -> objetivo "Prairie Wolf Paw: 5/6"), sin
-- confundirlo con otro objetivo no relacionado de la misma quest (ej.
-- "Plainstrider Talon: 3/4").
local function SKQ_WordOverlapScore(unitWords, text)
    if not text then return 0 end
    local lo = text:lower()
    local score = 0
    for _, w in ipairs(unitWords) do
        if lo:find(w, 1, true) then score = score + 1 end
    end
    return score
end

local function SKQ_FindQuestObjectivesForNpc(npcId, unitName)
    if not npcId then return nil end
    local active = addon.Tracker and addon.Tracker:GetActiveQuests()
    if not active or not SKquests_ObjectiveLinks then return nil end
    
    local allFoundObjs = {}
    
    for _, entry in pairs(active) do
        local links = entry.id and SKquests_ObjectiveLinks[entry.id]
        if links then
            local isLinked = false
            if links.npcs then
                for _, id in ipairs(links.npcs) do
                    if id == npcId then isLinked = true; break end
                end
            end
            if not isLinked and links.item_npcs then
                for _, id in ipairs(links.item_npcs) do
                    if id == npcId then isLinked = true; break end
                end
            end
            if isLinked then
                local objs = entry.objectives or {}
                if #objs == 1 then
                    table.insert(allFoundObjs, objs[1])
                elseif unitName then
                    local unitWords = {}
                    for w in unitName:lower():gmatch("%a+") do
                        if #w > 2 then table.insert(unitWords, w) end
                    end
                    local best, bestScore = {}, 0
                    for _, obj in ipairs(objs) do
                        local score = SKQ_WordOverlapScore(unitWords, obj.text)
                        if score > bestScore then
                            bestScore = score
                            best = { obj }
                        elseif score == bestScore and score > 0 then
                            table.insert(best, obj)
                        end
                    end
                    if bestScore > 0 then
                        for _, bo in ipairs(best) do table.insert(allFoundObjs, bo) end
                    else
                        for _, bo in ipairs(objs) do table.insert(allFoundObjs, bo) end
                    end
                else
                    for _, bo in ipairs(objs) do table.insert(allFoundObjs, bo) end
                end
            end
        end
    end
    if #allFoundObjs > 0 then return allFoundObjs end
    return nil
end

GameTooltip:HookScript("OnTooltipSetUnit", function(self)
    local _, unit = self:GetUnit()
    if not unit or not UnitExists(unit) then return end
    if UnitIsPlayer(unit) then return end
    local guid = UnitGUID and UnitGUID(unit)
    local npcId = SKQ_NpcIdFromGuid(guid)
    if not npcId then return end
    local name = UnitName(unit)
    local objs = SKQ_FindQuestObjectivesForNpc(npcId, name)
    if objs then
        local shown = false
        for _, obj in ipairs(objs) do
            if obj.text then
                local r, g, b = SKQ_ProgressColor(obj.numDone, obj.numTotal, obj.done)
                self:AddLine(obj.text, r, g, b, true)
                shown = true
            end
        end
        if shown then self:Show() end
    end
end)

-- ============================================================
--  MAPA DE ZONAS WotLK/Classic (LOOKUP TABLE)
-- ============================================================
local ZoneMap = {
    [1] = "Dun Morogh",
    [3] = "Badlands",
    [4] = "Blasted Lands",
    [8] = "Swamp of Sorrows",
    [9] = "Northshire Valley",
    [10] = "Duskwood",
    [11] = "Wetlands",
    [12] = "Elwynn Forest",
    [14] = "Durotar",
    [15] = "Dustwallow Marsh",
    [16] = "Azshara",
    [17] = "The Barrens",
    [19] = "Blasted Lands",
    [25] = "Blackrock Mountain",
    [28] = "Western Plaguelands",
    [33] = "Stranglethorn Vale",
    [36] = "Alterac Mountains",
    [38] = "Loch Modan",
    [40] = "Westfall",
    [44] = "Redridge Mountains",
    [45] = "Arathi Highlands",
    [46] = "Burning Steppes",
    [47] = "The Hinterlands",
    [51] = "Searing Gorge",
    [65] = "Dragonblight",
    [66] = "Zul'Drak",
    [67] = "The Storm Peaks",
    [85] = "Tirisfal Glades",
    [130] = "Silverpine Forest",
    [131] = "Kharanos",
    [132] = "Coldridge Valley",
    [133] = "Gnomeregan",
    [139] = "Eastern Plaguelands",
    [141] = "Teldrassil",
    [148] = "Darkshore",
    [151] = "Designer Island",
    [154] = "Deathknell",
    [188] = "Shadowglen",
    [206] = "Sholazar Basin",
    [209] = "Shadowfang Keep",
    [210] = "Crystalsong Forest",
    [215] = "Mulgore",
    [220] = "Camp Narache",
    [221] = "Echo Isles",
    [267] = "Hillsbrad Foothills",
    [331] = "Ashenvale",
    [357] = "Feralas",
    [361] = "Felwood",
    [363] = "Valley of Trials",
    [393] = "Darkspear Strand",
    [394] = "Grizzly Hills",
    [400] = "Thousand Needles",
    [405] = "Desolace",
    [406] = "Stonetalon Mountains",
    [440] = "Tanaris",
    [490] = "Un'Goro Crater",
    [493] = "Moonglade",
    [495] = "Howling Fjord",
    [618] = "Winterspring",
    [702] = "Rut'theran Village",
    [717] = "The Stockade",
    [718] = "Wailing Caverns",
    [719] = "Blackfathom Deeps",
    [722] = "Razorfen Downs",
    [796] = "Scarlet Monastery",
    [978] = "Zul'Farrak",
    [1116] = "Feathermoon Stronghold",
    [1196] = "Wintergrasp",
    [1377] = "Silithus",
    [1417] = "Sunken Temple",
    [1497] = "Undercity",
    [1517] = "Uldaman",
    [1519] = "Stormwind City",
    [1537] = "Ironforge",
    [1581] = "The Deadmines",
    [1583] = "Blackrock Spire",
    [1584] = "Blackrock Depths",
    [1637] = "Orgrimmar",
    [1638] = "Thunder Bluff",
    [1657] = "Darnassus",
    [1717] = "Razorfen Kraul",
    [1769] = "Timbermaw Hold",
    [1941] = "Caverns of Time",
    [1977] = "Zul'Gurub",
    [2017] = "Stratholme",
    [2057] = "Scholomance",
    [2079] = "Alcaz Island",
    [2100] = "Maraudon",
    [2159] = "Onyxia's Lair",
    [2257] = "Deeprun Tram",
    [2437] = "Ragefire Chasm",
    [2557] = "Dire Maul",
    [2562] = "Karazhan",
    [2597] = "Alterac Valley",
    [2677] = "Blackwing Lair",
    [2717] = "Molten Core",
    [2817] = "Crystalsong Forest",
    [2839] = "Alterac Valley",
    [3277] = "Warsong Gulch",
    [3358] = "Arathi Basin",
    [3428] = "Ahn'Qiraj",
    [3429] = "Ruins of Ahn'Qiraj",
    [3430] = "Eversong Woods",
    [3433] = "Ghostlands",
    [3456] = "Naxxramas",
    [3483] = "Hellfire Peninsula",
    [3487] = "Silvermoon City",
    [3518] = "Nagrand",
    [3519] = "Terokkar Forest",
    [3520] = "Shadowmoon Valley",
    [3521] = "Zangarmarsh",
    [3522] = "Blade's Edge Mountains",
    [3523] = "Netherstorm",
    [3524] = "Azuremyst Isle",
    [3525] = "Bloodmyst Isle",
    [3526] = "Zangarmarsh",
    [3535] = "Hellfire Citadel",
    [3537] = "Borean Tundra",
    [3557] = "The Exodar",
    [3607] = "Serpentshrine Cavern",
    [3703] = "Shattrath City",
    [3711] = "Sholazar Basin",
    [3717] = "The Blood Furnace",
    [3820] = "Eye of the Storm",
    [3836] = "Magtheridon's Lair",
    [3896] = "Aldor Rise",
    [4024] = "Coldarra",
    [4075] = "Sunwell Plateau",
    [4080] = "Isle of Quel'Danas",
    [4100] = "The Culling of Stratholme",
    [4196] = "Gundrak",
    [4197] = "Wintergrasp",
    [4228] = "The Oculus",
    [4264] = "Halls of Stone",
    [4265] = "The Nexus",
    [4272] = "Halls of Lightning",
    [4273] = "Ulduar",
    [4277] = "Azjol-Nerub",
    [4342] = "Ahn'kahet: The Old Kingdom",
    [4384] = "Strand of the Ancients",
    [4395] = "Dalaran",
    [4413] = "Icecrown",         -- Icecrown outdoor (WotLK)
    [4372] = "Dalaran",          -- Dalaran (alt id)
    [2817] = "Icecrown Glacier", -- Icecrown sub-area
    [4415] = "The Violet Hold",
    [4416] = "Gundrak",
    [4445] = "Undercity",
    [4493] = "The Obsidian Sanctum",
    [4494] = "Ahn'kahet",
    [4500] = "The Eye of Eternity",
    [4522] = "Icecrown Citadel",
    [4613] = "Dalaran",
    [4710] = "Isle of Conquest",
    [4722] = "Trial of the Champion",
    [4723] = "Trial of the Crusader",
    [4769] = "The Argent Tournament",
    [4809] = "Forge of Souls",
    [4812] = "Icecrown",
    [4813] = "Pit of Saron",
    [4820] = "Halls of Reflection",
    [4987] = "The Ruby Sanctum",
}

-- ============================================================
--  EXPANSIÓN DE CADA ZONA (por zoneId). Por defecto: Vanilla.
-- ============================================================
local ZoneExpansion = {}
do
    local tbc = {1941, 2562, 3430, 3433, 3483, 3487, 3518, 3519, 3520, 3521, 3522,
                 3523, 3524, 3525, 3526, 3535, 3557, 3607, 3703, 3717, 3820, 3836,
                 3896, 4075, 4080}
    local wotlk = {65, 66, 67, 206, 210, 394, 495, 1196, 2817, 3537, 3711, 4024,
                   4100, 4196, 4197, 4228, 4264, 4265, 4272, 4273, 4277, 4342, 4384,
                   4395, 4415, 4416, 4493, 4494, 4500, 4522, 4613, 4710, 4722, 4723,
                   4769, 4809, 4812, 4813, 4820, 4987}
    local custom = {151, 393}
    for _, id in ipairs(tbc) do ZoneExpansion[id] = "TBC" end
    for _, id in ipairs(wotlk) do ZoneExpansion[id] = "WotLK" end
    for _, id in ipairs(custom) do ZoneExpansion[id] = "Custom" end
end

local function GetZoneExpansion(zoneId)
    if not zoneId then return "Vanilla" end
    return ZoneExpansion[zoneId] or "Vanilla"
end

-- Carpetas de mapa del cliente (Interface\\WorldMap\\<carpeta>\\<carpeta>1..12)
local ZoneMapFolder = {
    [1]="DunMorogh",[3]="Badlands",[4]="BlastedLands",[8]="SwampOfSorrows",
    [9]="Northshire",[10]="Duskwood",[11]="Wetlands",[12]="Elwynn",[14]="Durotar",
    [15]="Dustwallow",[16]="Azshara",[17]="Barrens",[19]="BlastedLands",
    [28]="WesternPlaguelands",[33]="Stranglethorn",[36]="Alterac",[38]="LochModan",
    [40]="Westfall",[44]="Redridge",[45]="Arathi",[46]="BurningSteppes",
    [47]="Hinterlands",[51]="SearingGorge",[85]="Tirisfal",[130]="Silverpine",
    [131]="DunMorogh",[132]="ColdridgeValley",[139]="EasternPlaguelands",[141]="Teldrassil",
    [148]="Darkshore",[154]="Deathknell",[188]="Shadowglen",[215]="Mulgore",
    [220]="CampNarache",[221]="Durotar",[267]="Hillsbrad",[331]="Ashenvale",
    [357]="Feralas",[361]="Felwood",[363]="ValleyOfTrials",[393]="Durotar",
    [400]="ThousandNeedles",[405]="Desolace",[406]="StonetalonMountains",
    [440]="Tanaris",[490]="UngoroCrater",[493]="Moonglade",[618]="Winterspring",
    [702]="Teldrassil",[1377]="Silithus",[1497]="Undercity",[1519]="Stormwind",
    [1537]="Ironforge",[1637]="Orgrimmar",[1638]="ThunderBluff",[1657]="Darnassus",
    [2079]="Dustwallow",[2257]="StormwindCity",[2597]="AlteracValley",
    [2839]="AlteracValley",[3277]="WarsongGulch",[3358]="ArathiBasin",
    -- TBC zones
    [3430]="EversongWoods",[3433]="Ghostlands",[3483]="HellfirePeninsula",
    [3487]="ShattrathCity",[3518]="Nagrand",[3519]="TerokkarForest",
    [3520]="ShadowmoonValley",[3521]="Zangarmarsh",[3522]="BladesEdgeMountains",
    [3523]="Netherstorm",[3524]="AzuremystIsle",[3525]="BloodmystIsle",
    [3557]="TheExodar",[3607]="CoilfangReservoir",[3703]="BlackTemple",
    [3717]="GruulsLair",[3820]="EyeOfTheStorm",[3836]="MagistersTerrace",
    [4080]="IsleofQuelDanas",
    -- WotLK zones
    [65]="Dragonblight",[66]="ZulDrak",[67]="TheStormPeaks",
    [394]="GrizzlyHills",[495]="HowlingFjord",[1196]="Wintergrasp",
    [3537]="BoreanTundra",[3711]="IcecrownCitadel",[4024]="TheNexus",
    [4100]="Naxxramas",[4196]="UlduarFR",[4197]="Wintergrasp",
    [4228]="VaultOfArchavon",[4265]="IcecrownCitadel",[4273]="TrialOfTheCrusader",
    [4395]="Dalaran",[4415]="TheCullingOfStratholme",[4416]="Ulduar",
    [4723]="Icecrown",
    -- WotLK outdoor zones (no duplicates; 394/495/1196 already above)
    [206]="SholazarBasin",[210]="CrystalSong",[2817]="Icecrown",
    [4413]="Icecrown",   -- Icecrown outdoor zone
    [4372]="Dalaran",    -- Dalaran (alternate ID used by some quests)
}

local function GetZoneMapFolder(zoneId)
    if not zoneId then return nil end
    if ZoneMapFolder[zoneId] then return ZoneMapFolder[zoneId] end
    -- Auto-generate: PascalCase, strip spaces/apostrophes/commas/hyphens
    local nm = ZoneMap[zoneId]
    if not nm then
        if pfDB and pfDB["zones"] then nm = (pfDB["zones"]["enUS"] or {})[zoneId] end
    end
    if nm and not nm:find("^Zona %d") then
        local folder = nm:gsub("[%'%,%-]",""):gsub("%s+","")
        ZoneMapFolder[zoneId] = folder  -- cache for reuse
        return folder
    end
    return nil
end

-- Registro de textos localizables (se refrescan al cambiar idioma)
local LocRegistry = {}
local function RegLoc(fs, key, tf)
    LocRegistry[#LocRegistry + 1] = { fs = fs, key = key, tf = tf }
    local txt = L and L(key) or key
    if tf == "upper" then txt = string.upper(txt) end
    fs:SetText(txt)
end

local function IsSpanish()
    return SKquests_Localization and SKquests_Localization.currentLanguage == "esES"
end

-- Texto de quest en español desde la DB de pfQuest (T=título, O=objetivo, D=descripción)
local function GetQuestLoc(id)
    if IsSpanish() and pfDB and pfDB["quests"] and pfDB["quests"]["esES"] then
        return pfDB["quests"]["esES"][id]
    end
end

local function GetLocalizedQuestName(quest)
    if not quest then return "" end
    if IsSpanish() then
        local loc = GetQuestLoc(quest.id)
        return (loc and loc.T) or quest.name_loc or quest.name
    else
        return quest.name
    end
end

-- Normaliza nombres para matching tolerante: minúsculas, sin comillas,
-- espacios colapsados (la DB de pfQuest a veces guarda 'Wanted:  "Hogger"').
local function QNameNorm(s)
    if not s or s == "" then return "" end
    s = s:lower():gsub('"', ''):gsub("%s+", " ")
    return (s:gsub("^%s+", ""):gsub("%s+$", ""))
end

local function GetQuestIdByName(name)
    if not name or name == "" then return nil end
    local target = QNameNorm(name)
    if target == "" then return nil end
    for id, q in pairs(SKquests_DetailDB) do
        if QNameNorm(q.name) == target or QNameNorm(q.name_loc) == target then
            return id
        end
        local loc = GetQuestLoc(id)
        if loc and loc.T and QNameNorm(loc.T) == target then
            return id
        end
    end
    return nil
end

local function PfText(s)
    if not s then return s end
    s = s:gsub("%$[Bb]", "\n")
    s = s:gsub("%$[Nn]", UnitName("player") or "")
    s = s:gsub("%$[CcRr]", "")
    return s
end

-- Datos de un NPC: DB classic de pfQuest con fallback a la de Ascension
local function GetUnitData(npcId)
    if not npcId or not pfDB or not pfDB["units"] then return nil end
    local u = pfDB["units"]["data"] and pfDB["units"]["data"][npcId]
    if u and u.coords and #u.coords > 0 then return u end
    return nil -- [WotLK Classic] data-ascension NPC DB removed
end

-- Datos de un objeto del mundo (cofres, plantas, etc.): DB de pfQuest
local function GetObjectData(objId)
    if not objId or not pfDB or not pfDB["objects"] then return nil end
    return pfDB["objects"]["data"] and pfDB["objects"]["data"][objId]
end

-- Nombre localizado de un NPC (esES -> enUS -> SpawnData -> id)
local function UnitDisplayName(npcId)
    if not npcId then return nil end
    local u = pfDB and pfDB["units"]
    local nm = (IsSpanish() and u and u["esES"] and u["esES"][npcId])
        or (u and u["enUS"] and u["enUS"][npcId])
    if nm then return nm end
    local sd = SKquests_SpawnData and SKquests_SpawnData.npcs and SKquests_SpawnData.npcs[npcId]
    return (sd and sd.name) or ("NPC " .. tostring(npcId))
end

-- Nombre localizado de un objeto (esES -> enUS -> SpawnData -> id)
local function ObjectDisplayName(objId)
    if not objId then return nil end
    local o = pfDB and pfDB["objects"]
    local nm = (IsSpanish() and o and o["esES"] and o["esES"][objId])
        or (o and o["enUS"] and o["enUS"][objId])
    if nm then return nm end
    local sd = SKquests_SpawnData and SKquests_SpawnData.objects and SKquests_SpawnData.objects[objId]
    return (sd and sd.name) or ("Objeto " .. tostring(objId))
end

-- ============================================================
--  TOOLTIP DE PROGRESO EN OBJETOS RECOLECTABLES DEL MUNDO
--  Los GameObjects (herbs, cofres, items de quest en el piso, etc.)
--  no son "unidades": OnTooltipSetUnit nunca dispara para ellos, y
--  tampoco generan un tooltip de item real (OnTooltipSetItem). El
--  cliente solo llama GameTooltip:SetText(nombre) directamente, asi
--  que esa es la unica forma de detectarlos via Lua en 3.3.5a.
-- ============================================================
-- Cache nombre-normalizado -> texto/color de objetivo. El hook global de
-- GameTooltip:SetText (mas abajo) se dispara en CADA tooltip del juego
-- (hechizos, botones de accion, items del bolso, etc.), no solo en los
-- relacionados con misiones. Antes, cada una de esas llamadas recorria
-- todas las quests activas y armaba una tabla temporal de ids por quest;
-- ahora ese trabajo se hace una sola vez por refresh del Tracker (ver
-- SKQ_RebuildObjNameCache, llamado desde addon.Tracker.OnUpdate) y el hook
-- solo hace una busqueda O(1) en la cache.
local objNameCache = {}

local function SKQ_IndexObjNames(idList, objs)
    if not idList then return end
    for _, id in ipairs(idList) do
        local nm = ObjectDisplayName(id)
        if nm then
            local norm = QNameNorm(nm)
            if norm ~= "" then
                if not objNameCache[norm] then objNameCache[norm] = {} end
                local obj = objs[1]
                if #objs > 1 then
                    for _, o in ipairs(objs) do
                        if o.text and QNameNorm(o.text):find(norm, 1, true) then
                            obj = o
                            break
                        end
                    end
                end
                if obj and obj.text then
                    local r, g, b = SKQ_ProgressColor(obj.numDone, obj.numTotal, obj.done)
                    local exists = false
                    for _, e in ipairs(objNameCache[norm]) do
                        if e.text == obj.text then exists = true; break end
                    end
                    if not exists then
                        table.insert(objNameCache[norm], { text = obj.text, r = r, g = g, b = b })
                    end
                end
            end
        end
    end
end

local function SKQ_RebuildObjNameCache()
    wipe(objNameCache)
    local active = addon.Tracker and addon.Tracker:GetActiveQuests()
    if not active or not SKquests_ObjectiveLinks then return end
    for _, entry in pairs(active) do
        local links = entry.id and SKquests_ObjectiveLinks[entry.id]
        if links then
            local objs = entry.objectives or {}
            SKQ_IndexObjNames(links.objects, objs)
            SKQ_IndexObjNames(links.item_objects, objs)
        end
    end
end

local function SKQ_FindQuestProgressForObjectName(displayedName)
    local norm = QNameNorm(displayedName)
    if norm == "" then return nil end
    local hits = objNameCache[norm]
    if not hits or #hits == 0 then return nil end
    return hits
end

hooksecurefunc(GameTooltip, "SetText", function(self, text)
    if not text or text == "" then return end
    local _, unit = self:GetUnit()
    if unit then return end
    if self.GetItem and self:GetItem() then return end
    local hits = SKQ_FindQuestProgressForObjectName(text)
    if hits then
        for _, hit in ipairs(hits) do
            self:AddLine(hit.text, hit.r, hit.g, hit.b, true)
        end
        self:Show()
    end
end)

-- Texto real de una quest del log (API del cliente), restaurando la selección
local function GetLogQuestText(logIdx)
    if not logIdx then return nil end
    local old = GetQuestLogSelection()
    SelectQuestLogEntry(logIdx)
    local desc, obj = GetQuestLogQuestText()
    if old and old > 0 then SelectQuestLogEntry(old) end
    return desc, obj
end

-- Paso de guía traducido (SKquests_Guide_esES.lua)
local function GetGuideES(i)
    if IsSpanish() and SKquests_GuideES then
        local fac = addon.db and addon.db.currentGuide or "Alliance"
        local t = SKquests_GuideES[fac]
        return t and t[i]
    end
end

local SpecialZones = {
    [-22] = { en = "Seasonal", es = "Eventos del Mundo" },
    [-61] = { en = "Warlock", es = "Brujo" },
    [-81] = { en = "Warrior", es = "Guerrero" },
    [-82] = { en = "Shaman", es = "Chamán" },
    [-101] = { en = "Fishing", es = "Pesca" },
    [-121] = { en = "Blacksmithing", es = "Herrería" },
    [-141] = { en = "Paladin", es = "Paladín" },
    [-161] = { en = "Mage", es = "Mago" },
    [-162] = { en = "Rogue", es = "Pícaro" },
    [-181] = { en = "Alchemy", es = "Alquimia" },
    [-201] = { en = "Engineering", es = "Ingeniería" },
    [-261] = { en = "Hunter", es = "Cazador" },
    [-262] = { en = "Priest", es = "Sacerdote" },
    [-263] = { en = "Druid", es = "Druida" },
    [-264] = { en = "Tailoring", es = "Sastrería" },
    [-284] = { en = "Special", es = "Especial" },
    [-304] = { en = "Cooking", es = "Cocina" },
    [-324] = { en = "First Aid", es = "Primeros Auxilios" },
    [-344] = { en = "Legendary", es = "Legendaria" },
    [-364] = { en = "Darkmoon Faire", es = "Feria de la Luna Negra" },
    [-365] = { en = "Lunar Festival", es = "Festival Lunar" },
    [-367] = { en = "Midsummer", es = "Solsticio de Verano" },
    [-369] = { en = "Hallow's End", es = "Halloween" },
    [-370] = { en = "Love is in the Air", es = "Amor en el Aire" },
    [-372] = { en = "Death Knight", es = "Caballero de la Muerte" },
    [-374] = { en = "Noblegarden", es = "Jardín Noble" },
    [-375] = { en = "Pilgrim's Bounty", es = "Generosidad del Peregrino" },
    [-376] = { en = "Brewfest", es = "Fiesta de la Cerveza" },
}

local function GetZoneName(zoneId)
    if not zoneId then return "Zona Desconocida" end
    
    if SpecialZones[zoneId] then
        return IsSpanish() and SpecialZones[zoneId].es or SpecialZones[zoneId].en
    end

    if SKquests_Localization and SKquests_Localization.currentLanguage == "esES"
       and pfDB and pfDB["zones"] and pfDB["zones"]["esES"] and pfDB["zones"]["esES"][zoneId] then
        return pfDB["zones"]["esES"][zoneId]
    end
    if ZoneMap[zoneId] then return ZoneMap[zoneId] end
    -- Augment from pfDB["zones"]["enUS"] for zones not in static table
    if pfDB and pfDB["zones"] then
        local nm = (pfDB["zones"]["enUS"] or {})[zoneId]
        if nm then ZoneMap[zoneId] = nm; return nm end
    end
    return "Zona " .. zoneId
end

-- Resuelve un nombre de zona real (GetRealZoneText) al zoneId interno del
-- addon (esquema pfQuest), para saber si el jugador esta fisicamente en la
-- misma zona que el mapa interactivo mostrado (marcador "tu posicion").
local zoneNameToIdUI
local function SKQ_NormZoneName(s) return (s:lower():gsub("[^%w]", "")) end
local function SKQ_ResolveZoneIdFromRealZone(zoneName)
    if not zoneName or zoneName == "" then return nil end
    if not zoneNameToIdUI then
        zoneNameToIdUI = {}
        if pfDB and pfDB["zones"] then
            for _, locTable in pairs(pfDB["zones"]) do
                for id, nm in pairs(locTable) do
                    if type(nm) == "string" and nm ~= "" then zoneNameToIdUI[SKQ_NormZoneName(nm)] = id end
                end
            end
        end
        if ZoneMap then
            for id, nm in pairs(ZoneMap) do
                if type(nm) == "string" and nm ~= "" then
                    local norm = SKQ_NormZoneName(nm)
                    if not zoneNameToIdUI[norm] then zoneNameToIdUI[norm] = id end
                end
            end
        end
    end
    return zoneNameToIdUI[SKQ_NormZoneName(zoneName)]
end

-- GetItemIcon: WotLK has no GetItemIcon API; use GetItemInfo texture slot
local function GetItemIcon(itemId)
    if not itemId then return nil end
    return select(10, GetItemInfo(itemId))
end

-- GetQuestFixedRewards: guaranteed item rewards (TDB supplement > DB field)
local function GetQuestFixedRewards(q)
    if not q then return {} end
    -- Prioridad: recompensas APRENDIDAS en vivo (capturadas al aceptar la quest
    -- en este servidor) > suplemento TDB > campo del DB extraido.
    local lr = q.id and SKquestsDB and SKquestsDB.learnedRewards and SKquestsDB.learnedRewards[q.id]
    if lr and lr.r and #lr.r > 0 then return lr.r end
    local tdb = SKquests_DetailDB_TDB and SKquests_DetailDB_TDB[q.id]
    if tdb and tdb.r and #tdb.r > 0 then return tdb.r end
    return q.rewards or {}
end

-- GetQuestChoiceRewards: choose-one item rewards (learned live > TDB supplement > DB field)
local function GetQuestChoiceRewards(q)
    if not q then return {} end
    local lr = q.id and SKquestsDB and SKquestsDB.learnedRewards and SKquestsDB.learnedRewards[q.id]
    if lr and lr.c and #lr.c > 0 then return lr.c end
    local tdb = SKquests_DetailDB_TDB and SKquests_DetailDB_TDB[q.id]
    if tdb and tdb.c and #tdb.c > 0 then return tdb.c end
    return q.choiceRewards or {}
end

local function GetQuestTexture(path)
    if not path or path == "" or path:find("placeholder") then
        return "Interface\\AddOns\\SKquests\\Media\\Background.png"
    end
    local filename = path:match("([^/]+)$") or "Background.png"
    return "Interface\\AddOns\\SKquests\\Media\\" .. filename
end

-- ============================================================
--  PALETA DE COLORES (MODO OSCURO / CLARO PERGAMINO)
-- ============================================================
local Themes = {
    dark = {
        bg          = {0.06, 0.06, 0.06}, -- Fondo premium negro/carbón
        bgSide      = {0.08, 0.08, 0.08},
        bgList      = {0.08, 0.08, 0.08},
        bgDetail    = {0.09, 0.09, 0.09},
        bgSelected  = {0.25, 0.25, 0.25},
        bgHover     = {0.18, 0.18, 0.18},
        border      = {0.20, 0.20, 0.20}, -- Bordes elegantes grises
        borderDim   = {0.15, 0.15, 0.15},
        gold        = {0.90, 0.75, 0.30},
        white       = {0.90, 0.90, 0.90},
        dim         = {0.60, 0.60, 0.60},
        sectionLbl  = {0.70, 0.70, 0.70},
        green       = {0.20, 0.85, 0.20},
        objDone     = {0.20, 0.85, 0.20},
        objPending  = {0.85, 0.85, 0.85},
        wowBlue     = {0.35, 0.60, 1.00},
        textures    = { bg = "Interface\\ChatFrame\\ChatFrameBackground", border = "Interface\\Tooltips\\UI-Tooltip-Border" },
        metrics     = { borderSize = 12, padding = 4 },
    },
    light = {
        bg          = {0.95, 0.92, 0.84}, -- pergamino claro
        bgSide      = {0.90, 0.86, 0.76},
        bgList      = {0.88, 0.83, 0.72},
        bgDetail    = {0.93, 0.89, 0.80},
        bgSelected  = {0.78, 0.70, 0.52},
        bgHover     = {0.84, 0.78, 0.64},
        border      = {0.50, 0.43, 0.28},
        borderDim   = {0.62, 0.55, 0.40},
        gold        = {0.35, 0.22, 0.05},
        white       = {0.18, 0.14, 0.06},
        dim         = {0.40, 0.35, 0.25},
        sectionLbl  = {0.48, 0.40, 0.28},
        green       = {0.10, 0.55, 0.10},
        objDone     = {0.25, 0.60, 0.25},
        objPending  = {0.20, 0.15, 0.10},
        wowBlue     = {0.15, 0.35, 0.80},
        textures    = { bg = "Interface\\ChatFrame\\ChatFrameBackground", border = "Interface\\Tooltips\\UI-Tooltip-Border" },
        metrics     = { borderSize = 12, padding = 4 },
    }
}

local C = Themes.dark -- por defecto oscuro

-- ============================================================
--  ESTADO DE LA UI
-- ============================================================
local activeTab = "guide"         -- "guide", "questlog", "quests", "zones", "settings", "about"
local selectedQuestId = nil       -- ID de quest seleccionada en BD
local selectedQuestLogIdx = nil   -- Index de quest activa seleccionada
local selectedStepIdx = 1         -- Paso de la guia activo
local rightSidebarShown = true

-- Variables de busqueda y filtros
local searchText = ""
local selectedZoneFilter = "Todas"
local selectedLevelFilter = "Todos"
local selectedLevelMin = nil      -- filtro de rango: nivel minimo (nil = sin limite)
local selectedLevelMax = nil      -- filtro de rango: nivel maximo (nil = sin limite)
local selectedZoneFactionFilter = "Both" -- "Alliance", "Horde", "Both"

local ZoneCoordinates = {
    -- Continent 1: Kalimdor
    [141]  = { continent = 1, x = 45, y = 10 }, -- Teldrassil
    [188]  = { continent = 1, x = 45, y = 10 }, -- Shadowglen -> Teldrassil
    [148]  = { continent = 1, x = 40, y = 20 }, -- Darkshore
    [331]  = { continent = 1, x = 46, y = 28 }, -- Ashenvale
    [17]   = { continent = 1, x = 48, y = 46 }, -- The Barrens
    [14]   = { continent = 1, x = 58, y = 49 }, -- Durotar
    [363]  = { continent = 1, x = 58, y = 49 }, -- Valley of Trials -> Durotar
    [221]  = { continent = 1, x = 59, y = 54 }, -- Echo Isles -> Durotar
    [215]  = { continent = 1, x = 39, y = 49 }, -- Mulgore
    [220]  = { continent = 1, x = 39, y = 49 }, -- Camp Narache -> Mulgore
    [406]  = { continent = 1, x = 38, y = 35 }, -- Stonetalon Mountains
    [16]   = { continent = 1, x = 59, y = 30 }, -- Azshara
    [493]  = { continent = 1, x = 51, y = 14 }, -- Moonglade
    [361]  = { continent = 1, x = 44, y = 20 }, -- Felwood
    [618]  = { continent = 1, x = 58, y = 15 }, -- Winterspring
    [405]  = { continent = 1, x = 34, y = 45 }, -- Desolace
    [15]   = { continent = 1, x = 56, y = 58 }, -- Dustwallow Marsh
    [357]  = { continent = 1, x = 35, y = 62 }, -- Feralas
    [400]  = { continent = 1, x = 49, y = 67 }, -- Thousand Needles
    [440]  = { continent = 1, x = 54, y = 80 }, -- Tanaris
    [490]  = { continent = 1, x = 43, y = 79 }, -- Un'Goro Crater
    [1377] = { continent = 1, x = 34, y = 78 }, -- Silithus

    -- (Outland/TBC y Northrend/WotLK excluidos - no aplican a Season of Discovery)

    -- Continent 2: Eastern Kingdoms
    [1]    = { continent = 2, x = 48, y = 51 }, -- Dun Morogh
    [132]  = { continent = 2, x = 48, y = 51 }, -- Coldridge Valley -> Dun Morogh
    [12]   = { continent = 2, x = 48, y = 70 }, -- Elwynn Forest
    [9]    = { continent = 2, x = 48, y = 70 }, -- Northshire Valley -> Elwynn Forest
    [40]   = { continent = 2, x = 38, y = 75 }, -- Westfall
    [38]   = { continent = 2, x = 56, y = 52 }, -- Loch Modan
    [44]   = { continent = 2, x = 56, y = 71 }, -- Redridge Mountains
    [10]   = { continent = 2, x = 48, y = 77 }, -- Duskwood
    [11]   = { continent = 2, x = 50, y = 42 }, -- Wetlands
    [47]   = { continent = 2, x = 57, y = 24 }, -- The Hinterlands
    [267]  = { continent = 2, x = 47, y = 29 }, -- Hillsbrad Foothills
    [36]   = { continent = 2, x = 46, y = 25 }, -- Alterac Mountains
    [45]   = { continent = 2, x = 57, y = 30 }, -- Arathi Highlands
    [33]   = { continent = 2, x = 45, y = 88 }, -- Stranglethorn Vale
    [3]    = { continent = 2, x = 55, y = 60 }, -- Badlands
    [8]    = { continent = 2, x = 57, y = 77 }, -- Swamp of Sorrows
    [4]    = { continent = 2, x = 58, y = 85 }, -- Blasted Lands
    [51]   = { continent = 2, x = 48, y = 60 }, -- Searing Gorge
    [46]   = { continent = 2, x = 50, y = 65 }, -- Burning Steppes
    [28]   = { continent = 2, x = 47, y = 18 }, -- Western Plaguelands
    [139]  = { continent = 2, x = 56, y = 16 }, -- Eastern Plaguelands
    [41]   = { continent = 2, x = 52, y = 77 }, -- Deadwind Pass
    [130]  = { continent = 2, x = 38, y = 23 }, -- Silverpine Forest
    [85]   = { continent = 2, x = 38, y = 14 }, -- Tirisfal Glades
    [154]  = { continent = 2, x = 38, y = 14 }, -- Deathknell -> Tirisfal Glades
}

-- Listas filtradas
local filteredQuestIds = {}
local uniqueZones = {}            -- { {name, minL, maxL, count, id}, ... }

-- Métodos públicos para acceder a las colecciones
addon.GetVisibleQuestsCount = function(self) return filteredQuestIds and #filteredQuestIds or 0 end
addon.GetVisibleZonesCount = function(self) return uniqueZones and #uniqueZones or 0 end
addon.GetSelectedQuestId = function(self) return selectedQuestId end

-- Guias
local filteredGuideSteps = {}
local guideChapters = {}
local selectedGuideChapter = 1

-- Coloca botones invisibles sobre cada [nombre de quest] del texto envuelto,
-- para que cada quest (incluida la línea resumen) sea clickeable por separado.
-- Defensivo: se invoca dentro de pcall; si algo falla no rompe el render.
local function LayoutQuestLinks(parent, cb, lblFS, plain, links, width)
    cb.qbtns = cb.qbtns or {}
    for _, b in ipairs(cb.qbtns) do b:Hide() end
    if not links or #links == 0 or not width or width < 20 then return end
    local mfs = parent.measureFS
    if not mfs then
        mfs = parent:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
        mfs:Hide()
        parent.measureFS = mfs
    end
    mfs:SetText("Ay")
    local lineH = (mfs:GetStringHeight() or 12) + 2
    local function W(s) mfs:SetText(s); return mfs:GetStringWidth() or 0 end
    local spaceW = W(" ")
    -- tokenizar y simular el salto de línea (wrap) palabra por palabra
    local words, pos, x, y = {}, {}, 0, 0
    for w in plain:gmatch("%S+") do words[#words + 1] = w end
    for i, w in ipairs(words) do
        local ww = W(w)
        if x > 0 and (x + ww) > width then x = 0; y = y + lineH end
        pos[i] = { x = x, y = y, w = ww }
        x = x + ww + spaceW
    end
    -- emparejar cada run "[...]" con su link (en orden) y crear el botón
    local li, bi, i = 1, 1, 1
    while i <= #words and li <= #links do
        if words[i]:find("[", 1, true) then
            local s = i
            while i <= #words and not words[i]:find("]", 1, true) do i = i + 1 end
            local e = math.min(i, #words)
            local lk = links[li]; li = li + 1
            if lk.qid then
                local rx, ry = pos[s].x, pos[s].y
                local rw = (pos[e].y == ry) and ((pos[e].x + pos[e].w) - rx) or (width - rx)
                local b = cb.qbtns[bi]
                if not b then b = CreateFrame("Button", nil, parent); cb.qbtns[bi] = b end
                b.qid = lk.qid
                b:SetScript("OnClick", function(self)
                    selectedQuestId = self.qid
                    addon:SwitchTab("quests")
                end)
                b:ClearAllPoints()
                b:SetPoint("TOPLEFT", lblFS, "TOPLEFT", rx, -ry)
                b:SetSize(math.max(8, rw), lineH)
                b:Show()
                bi = bi + 1
            end
            i = e + 1
        else
            i = i + 1
        end
    end
end

-- Widgets del addon
local MainFrame = nil
local Sidenav = nil
local ListPanel = nil
local DetailPanel = nil
local RightSidebar = nil
local SettingsPanel = nil
local AboutPanel = nil
local ZonesMapPanel = nil

local listButtons = {}
local MAX_ROWS = 35
local ROW_H = 28

-- ============================================================
--  SOPORTE PARA BACKDROP & THEME
-- ============================================================
local function ApplyBD(f, bg, border, edgeSize)
    -- default fallback if not called inside ApplyTheme
    SKQ_EnsureBackdrop(f)
    f:SetBackdrop({
        bgFile   = "Interface\\ChatFrame\\ChatFrameBackground",
        edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
        tile = true, tileSize = 256, edgeSize = edgeSize or 16,
        insets = {left=4, right=4, top=4, bottom=4},
    })
    if bg then f:SetBackdropColor(bg[1], bg[2], bg[3], 0.98) end
    if border then f:SetBackdropBorderColor(border[1], border[2], border[3], 0.8) end
end

function addon:GetThemeColors()
    return C
end

function addon:ApplyTheme()
    local theme = SKquestsDB and SKquestsDB.config and SKquestsDB.config.theme or "dark"
    if theme == "claro" then theme = "light" end
    if theme == "oscuro" then theme = "dark" end
    C = Themes[theme] or (addon.GetCustomPalette and addon:GetCustomPalette(theme)) or Themes.dark

    if not MainFrame then return end

    -- Marco temático pintado (9-slice) + inset del contenido (o inset normal)
    do
        local tkey = SKquestsDB and SKquestsDB.config and SKquestsDB.config.theme or "dark"
        if tkey == "claro" then tkey = "light" end
        if tkey == "oscuro" then tkey = "dark" end
        local bt = addon.ApplyThemeFrameBorder and addon:ApplyThemeFrameBorder(tkey)
        if addon.SetPanelInset then addon:SetPanelInset(bt or 10) end
    end

    local function UpdateBD(frame, alpha)
        -- IMPORTANTE: no usar el marco pintado como edgeFile (rompe el borde) ni
        -- tilear el bg como fondo de cada panel. Borde estándar + color de paleta.
        SKQ_EnsureBackdrop(frame)
        frame:SetBackdrop({
            bgFile   = "Interface\\ChatFrame\\ChatFrameBackground",
            edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
            tile = true, tileSize = 16,
            edgeSize = 14,
            insets = {left=3, right=3, top=3, bottom=3},
        })
        frame:SetBackdropBorderColor(C.border[1], C.border[2], C.border[3], 1.0)
    end

    -- Aplicar texturas, fondos y bordes
    local isCustomBG = C.textures and C.textures.bg and (C.textures.bg:find("SKquests") or C.textures.bg:find("Media"))
    local panelAlpha = isCustomBG and 0.0 or 0.98

    if isCustomBG then
        SKQ_EnsureBackdrop(MainFrame)
        MainFrame:SetBackdrop({
            bgFile   = C.textures.bg,
            edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
            tile = false,
            edgeSize = 14,
            insets = {left=3, right=3, top=3, bottom=3},
        })
        MainFrame:SetBackdropColor(1, 1, 1, 0.98)
        MainFrame:SetBackdropBorderColor(C.border[1], C.border[2], C.border[3], 0)
    else
        UpdateBD(MainFrame, 0.98)
        MainFrame:SetBackdropColor(C.bg[1], C.bg[2], C.bg[3], 0.98)
    end
    
    UpdateBD(Sidenav, 0.98)
    Sidenav:SetBackdropColor(C.bgSide[1], C.bgSide[2], C.bgSide[3], panelAlpha)
    Sidenav:SetBackdropBorderColor(C.borderDim[1], C.borderDim[2], C.borderDim[3], isCustomBG and 0.25 or 0.8)
    
    UpdateBD(ListPanel, 0.98)
    ListPanel:SetBackdropColor(C.bgList[1], C.bgList[2], C.bgList[3], panelAlpha)
    ListPanel:SetBackdropBorderColor(C.borderDim[1], C.borderDim[2], C.borderDim[3], isCustomBG and 0.25 or 0.8)

    if addon.ZonesListPanel then
        UpdateBD(addon.ZonesListPanel, 0.98)
        addon.ZonesListPanel:SetBackdropColor(C.bgList[1], C.bgList[2], C.bgList[3], panelAlpha)
        addon.ZonesListPanel:SetBackdropBorderColor(C.borderDim[1], C.borderDim[2], C.borderDim[3], isCustomBG and 0.25 or 0.8)
    end

    UpdateBD(DetailPanel, 0.98)
    DetailPanel:SetBackdropColor(C.bgDetail[1], C.bgDetail[2], C.bgDetail[3], panelAlpha)
    DetailPanel:SetBackdropBorderColor(C.borderDim[1], C.borderDim[2], C.borderDim[3], isCustomBG and 0.25 or 0.8)
    
    UpdateBD(RightSidebar, 0.98)
    RightSidebar:SetBackdropColor(C.bgSide[1], C.bgSide[2], C.bgSide[3], panelAlpha)
    RightSidebar:SetBackdropBorderColor(C.borderDim[1], C.borderDim[2], C.borderDim[3], isCustomBG and 0.25 or 0.8)

    if SettingsPanel then
        UpdateBD(SettingsPanel, 0.98)
        SettingsPanel:SetBackdropColor(C.bgSide[1], C.bgSide[2], C.bgSide[3], panelAlpha)
        SettingsPanel:SetBackdropBorderColor(C.borderDim[1], C.borderDim[2], C.borderDim[3], isCustomBG and 0.25 or 0.8)
    end
    if AboutPanel then
        UpdateBD(AboutPanel, 0.98)
        AboutPanel:SetBackdropColor(C.bgSide[1], C.bgSide[2], C.bgSide[3], panelAlpha)
        AboutPanel:SetBackdropBorderColor(C.borderDim[1], C.borderDim[2], C.borderDim[3], isCustomBG and 0.25 or 0.8)
    end
    if GuideCardsPanel then
        UpdateBD(GuideCardsPanel, 0.98)
        GuideCardsPanel:SetBackdropColor(C.bgList[1], C.bgList[2], C.bgList[3], panelAlpha)
        GuideCardsPanel:SetBackdropBorderColor(C.borderDim[1], C.borderDim[2], C.borderDim[3], isCustomBG and 0.25 or 0.8)
        if GuideCardsPanel.titleFS then
            GuideCardsPanel.titleFS:SetTextColor(C.gold[1], C.gold[2], C.gold[3])
        end
        if GuideCardsPanel.cards then
            for _, card in ipairs(GuideCardsPanel.cards) do
                SKQ_EnsureBackdrop(card)
                card:SetBackdrop({
                    bgFile   = "Interface\\ChatFrame\\ChatFrameBackground",
                    edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
                    tile = true, tileSize = 16,
                    edgeSize = 12,
                    insets = {left=3, right=3, top=3, bottom=3},
                })
                card:SetBackdropColor(C.bgDetail[1], C.bgDetail[2], C.bgDetail[3], isCustomBG and 0.15 or 0.98)
                card:SetBackdropBorderColor(C.borderDim[1], C.borderDim[2], C.borderDim[3], isCustomBG and 0.4 or 0.8)
                if card.title then
                    card.title:SetTextColor(C.white[1], C.white[2], C.white[3])
                end
                if card.sub then
                    card.sub:SetTextColor(C.dim[1], C.dim[2], C.dim[3])
                end
            end
        end
    end
    if GuideLockPanel then
        UpdateBD(GuideLockPanel, 0.98)
        GuideLockPanel:SetBackdropColor(C.bgList[1], C.bgList[2], C.bgList[3], panelAlpha)
        GuideLockPanel:SetBackdropBorderColor(C.borderDim[1], C.borderDim[2], C.borderDim[3], isCustomBG and 0.25 or 0.8)
        if GuideLockPanel.title then
            GuideLockPanel.title:SetTextColor(C.gold[1], C.gold[2], C.gold[3])
        end
        if GuideLockPanel.sub then
            GuideLockPanel.sub:SetTextColor(C.white[1], C.white[2], C.white[3])
        end
    end

    -- Aplicar colores de texto de la barra de título
    MainFrame.titleText:SetTextColor(C.gold[1], C.gold[2], C.gold[3])
    MainFrame.hCount:SetTextColor(C.dim[1], C.dim[2], C.dim[3])

    -- Actualizar los botones del menu
    for tab, btn in pairs(Sidenav.buttons) do
        if tab == activeTab then
            btn:SetBackdropColor(C.bgSelected[1], C.bgSelected[2], C.bgSelected[3], 0.9)
            btn.txt:SetTextColor(C.gold[1], C.gold[2], C.gold[3])
        else
            btn:SetBackdropColor(0, 0, 0, 0)
            btn.txt:SetTextColor(C.dim[1], C.dim[2], C.dim[3])
        end
    end

    -- Actualizar colores del panel de configuración
    if SettingsPanel then
        SettingsPanel.title:SetTextColor(C.gold[1], C.gold[2], C.gold[3])
        if SettingsPanel.labels then
            for _, lbl in ipairs(SettingsPanel.labels) do
                lbl:SetTextColor(C.white[1], C.white[2], C.white[3])
            end
        end
    end

    -- Actualizar colores del panel Acerca de
    if AboutPanel then
        AboutPanel.title:SetTextColor(C.gold[1], C.gold[2], C.gold[3])
        AboutPanel.desc:SetTextColor(C.white[1], C.white[2], C.white[3])
    end

    -- Actualizar colores de DetailPanel
    local ch = DetailPanel.child
    if ch then
        ch.header.title:SetTextColor(C.gold[1], C.gold[2], C.gold[3])
        ch.header.meta:SetTextColor(C.dim[1], C.dim[2], C.dim[3])
        ch.header.level:SetTextColor(C.gold[1], C.gold[2], C.gold[3])
        
        ch.objSec.lbl:SetTextColor(C.gold[1], C.gold[2], C.gold[3])
        ch.objSec.box:SetBackdropColor(C.bg[1], C.bg[2], C.bg[3], 0.4)
        ch.objSec.box:SetBackdropBorderColor(C.borderDim[1], C.borderDim[2], C.borderDim[3], 0.6)
        ch.objSec.box.text:SetTextColor(C.white[1], C.white[2], C.white[3])
        
        ch.descSec.lbl:SetTextColor(C.gold[1], C.gold[2], C.gold[3])
        ch.descSec.text:SetTextColor(C.dim[1], C.dim[2], C.dim[3])
        
        ch.npcSec.lbl:SetTextColor(C.gold[1], C.gold[2], C.gold[3])
        ch.npcSec.grid.startCard:SetBackdropColor(C.bg[1], C.bg[2], C.bg[3], 0.4)
        ch.npcSec.grid.startCard:SetBackdropBorderColor(C.borderDim[1], C.borderDim[2], C.borderDim[3], 0.6)
        ch.npcSec.grid.startCard.title:SetTextColor(C.dim[1], C.dim[2], C.dim[3])
        ch.npcSec.grid.startCard.name:SetTextColor(C.white[1], C.white[2], C.white[3])
        
        ch.npcSec.grid.endCard:SetBackdropColor(C.bg[1], C.bg[2], C.bg[3], 0.4)
        ch.npcSec.grid.endCard:SetBackdropBorderColor(C.borderDim[1], C.borderDim[2], C.borderDim[3], 0.6)
        ch.npcSec.grid.endCard.title:SetTextColor(C.dim[1], C.dim[2], C.dim[3])
        ch.npcSec.grid.endCard.name:SetTextColor(C.white[1], C.white[2], C.white[3])
        
    -- [WotLK Classic] ch.linkSec.lbl:SetTextColor(C.gold[1], C.gold[2], C.gold[3])
    -- [WotLK Classic] ch.linkSec.box:SetTextColor(C.white[1], C.white[2], C.white[3])

        if ch.questImgBox then
            ch.questImgBox:SetBackdropColor(C.bg[1], C.bg[2], C.bg[3], 0.4)
            ch.questImgBox:SetBackdropBorderColor(C.borderDim[1], C.borderDim[2], C.borderDim[3], 0.6)
        end
        if ch.rewardSec then
            ch.rewardSec.lbl:SetTextColor(C.gold[1], C.gold[2], C.gold[3])
            for r = 1, 4 do
                ch.rewardSec.buttons[r]:SetBackdropBorderColor(C.borderDim[1], C.borderDim[2], C.borderDim[3], 0.6)
            end
        end
    end

    -- Actualizar colores de RightSidebar
    if RightSidebar then
        RightSidebar.title:SetTextColor(C.gold[1], C.gold[2], C.gold[3])
        RightSidebar.chain.lbl:SetTextColor(C.gold[1], C.gold[2], C.gold[3])
        for _, row in pairs(RightSidebar.rows) do
            row.lbl:SetTextColor(C.dim[1], C.dim[2], C.dim[3])
            row.val:SetTextColor(C.white[1], C.white[2], C.white[3])
        end
    end

    -- Actualizar colores del Mini-Tracker (Estilo transparente sin bordes ni fondo, como pfQuest)
    if SKquests_MiniTracker then
        SKQ_EnsureBackdrop(SKquests_MiniTracker)
        SKquests_MiniTracker:SetBackdrop(nil)
        local header = SKquests_MiniTracker.header
        if header then
            SKQ_EnsureBackdrop(header)
            header:SetBackdrop(nil)
        end
        if SKquests_MiniTracker.titleFS then
            SKquests_MiniTracker.titleFS:SetTextColor(C.gold[1], C.gold[2], C.gold[3])
        end
        addon:RefreshMiniTracker()
    end

    -- Forzar refresco visual
    addon:UpdateListRows()
    addon:RefreshDetail()

    -- Re-aplicar el tema a la ventana del XP Appraiser si existe
    if SKquests.XPApplyTheme then SKquests:XPApplyTheme() end
end

-- ============================================================
--  RESOLVER ZONAS DE LA BD DINAMICAMENTE
-- ============================================================
-- Criterio ÚNICO de elegibilidad, compartido por el tab Zonas y el Explorador.
-- Así una zona nunca puede mostrar quests que la lista después descarta.
-- Inyección ÚNICA de BronzebeardQuestChains como quests custom (nombres limpios,
-- sin sufijo, sin duplicar). Cada una lleva su coord de azerothhub para el pin.
local BQByName = {}
do
    if BronzebeardQuestChains and SKquests_DetailDB then
        local ZMAP = {
            ["camp-narache"] = 220, ["coldridge-valley"] = 132, ["deathknell"] = 154,
            ["northshire"] = 9, ["shadowglen"] = 188, ["valley-of-trials"] = 363,
            ["azshara"] = 16, ["desolace"] = 405, ["wetlands"] = 11,
        }
        local function norm(s) return (string.lower(s):gsub("[^%w]", "")) end
        local present = {}
        for _, q in pairs(SKquests_DetailDB) do
            if q.name then present[norm(q.name)] = true end
        end
        local synthId = 990000
        for _, e in pairs(BronzebeardQuestChains) do
            if e.name then
                BQByName[string.lower(e.name)] = e
                local nkey = norm(e.name)
                if not present[nkey] then
                    present[nkey] = true
                    synthId = synthId + 1
                    SKquests_DetailDB[synthId] = {
                        id = synthId, name = e.name, name_loc = e.name,
                        desc = e.description, logDesc = e.description,
                        zoneId = ZMAP[e.zoneId] or 1, level = 1, minLevel = 1,
                        isCustom = true, faction = e.faction,
                        bqCoord = { x = e.x, y = e.y }, bqId = e.id,
                    }
                end
            end
        end
    end
end

-- Season of Discovery: zonas de Outland (TBC) y Northrend (WotLK), incluyendo
-- capitales y zonas iniciales de razas TBC. Ver también ZoneCoordinates más
-- arriba, de donde se quitaron estas mismas zonas.
local EXPANSION_EXCLUDED_ZONES = {
    [3483]=true, [3518]=true, [3519]=true, [3520]=true, [3521]=true, [3522]=true,
    [3523]=true, [4080]=true, [3487]=true, [3524]=true, [3525]=true, [3557]=true,
    [3430]=true, [3433]=true, -- Eversong Woods / Ghostlands (zona inicial Sangre Élfica TBC)
    [3537]=true, [495]=true, [65]=true, [394]=true, [66]=true, [67]=true,
    [4395]=true, [3711]=true, [210]=true, [206]=true, [4197]=true, [2817]=true,
    [4100]=true, [4196]=true, [4264]=true,
}

local function IsQuestEligible(id, q)
    local title = string.upper(q.name or "")
    -- descartar quests sin nombre (entradas corruptas del volcado)
    if title:gsub("%s", "") == "" then return false end
    -- basura del cliente: <TEST ...>, <UNUSED 1>, <NYI>, <TXT>, [UNUSED], etc.
    if title:find("<TEST") or title:find("<UNUSED") or title:find("<NYI")
       or title:find("<TXT") or title:find("%[UNUSED") or title:find("%[NYI")
       or title:find("%[TEST") or title:find("<DEPRECATED>") then
        return false
    end
    -- Designer Island (151): zona de pruebas de desarrollo, no es del juego
    if q.zoneId == 151 then return false end
    if q.desc == "No information available" then return false end
    if title:find("FLAG") or title:find("BLIZZARD ACCOUNT:") or title:find("COLLECTOR'S EDITION:") then return false end
    local l1 = tonumber(q.level) or 0
    local l2 = tonumber(q.lvl) or 0
    local l3 = tonumber(q.minLevel) or 0
    local l4 = tonumber(q.reqLevel) or 0
    if (l1 > 80) or (l2 > 80) or (l3 > 80) or (l4 > 80) then
        return false
    end
    -- Ocultar quests sin nivel válido (eventos, clase, NYI) salvo que sean custom,
    -- estén activas, o tengan una zona válida (TBC/WotLK quests a veces traen l1=0).
    if not q.isCustom and l1 <= 0 then
        local active = addon.Tracker and addon.Tracker.IsActive and addon.Tracker:IsActive(q.name)
        local hasZone = q.zoneId and ZoneMap[q.zoneId]
        if not active and not hasZone then return false end
    end

    -- Filtrar misiones PvP (Campos de batalla y zonas exclusivas PvP)
    local pvpZones = {
        [2597] = true, -- Alterac Valley
        [2839] = true, -- Alterac Valley
        [3277] = true, -- Warsong Gulch
        [3358] = true, -- Arathi Basin
        [3820] = true, -- Eye of the Storm
        [4384] = true, -- Strand of the Ancients
        [4197] = true, -- Wintergrasp
        [4710] = true, -- Isle of Conquest
    }
    if q.zoneId and pvpZones[q.zoneId] then
        return false
    end
    -- Filtrar por titulo explicito de prueba PvP
    if title:find("PVP") or title:find("JCJ") then
        return false
    end
    -- Season of Discovery: excluir contenido de TBC/WotLK (el ChromieCraft
    -- original incluía las 3 expansiones; SoD es contenido clásico únicamente).
    -- 1) Tabla de origen por quest ID (pfDB.quest_origin, de pfQuest)
    if pfDB and pfDB['quest_origin'] and pfDB['quest_origin'][id] == 'tbc' then
        return false
    end
    -- 2) Zonas de Outland/Northrend/capitales TBC (sin entrada en ZoneCoordinates
    --    tras la exclusión de esas zonas; usamos la lista explícita como respaldo)
    if q.zoneId and EXPANSION_EXCLUDED_ZONES[q.zoneId] then
        return false
    end
    -- 3) Respaldo por nivel: nada en Vanilla/SoD supera el nivel 60
    if l1 > 60 or l2 > 60 or l3 > 60 or l4 > 60 then
        return false
    end
    return true
end

local function GetQuestFaction(id, q)
    if not q then return nil end
    
    -- 1. pfDB race bitmask (supports TBC Draenei=256 / Blood Elf=512)
    --    Alliance races: Human=1, Dwarf=4, NightElf=8, Gnome=64, Draenei=256  => mask 333
    --    Horde races:    Orc=2,  Undead=16, Tauren=32, Troll=128, BloodElf=512 => mask 690
    if pfDB and pfDB["quests"] and pfDB["quests"]["data"] then
        local pq = pfDB["quests"]["data"][id]
        if pq and pq.race and pq.race > 0 then
            local r = pq.race
            local A_MASK, H_MASK = 333, 690
            local hasA = bit.band(r, A_MASK) > 0
            local hasH = bit.band(r, H_MASK) > 0
            if hasA and not hasH then return "Alliance"
            elseif hasH and not hasA then return "Horde"
            end
        end
    end

    -- 2. Try the giver NPC faction
    if q.giverId and q.giverType ~= "GO" then
        local u = GetUnitData(q.giverId)
        if u and u.fac then
            if u.fac == "A" then
                return "Alliance"
            elseif u.fac == "H" then
                return "Horde"
            end
        end
    end

    -- 3. Try the ender NPC faction
    if q.enderId and q.enderType ~= "GO" then
        local u = GetUnitData(q.enderId)
        if u and u.fac then
            if u.fac == "A" then
                return "Alliance"
            elseif u.fac == "H" then
                return "Horde"
            end
        end
    end

    return "Both"
end

local function BuildZonesList()
    local zonesData = {}
    if not SKquests_DetailDB then return end

    for id, q in pairs(SKquests_DetailDB) do
        -- Solo zonas con nombre conocido en ZoneMap (elimina las "Zona N")
        local exp = q.zoneId and GetZoneExpansion(q.zoneId)
        -- Accept zone if it has a known name (static ZoneMap OR pfDB)
        local _zname = q.zoneId and GetZoneName(q.zoneId)
        if IsQuestEligible(id, q) and q.zoneId and _zname and not _zname:find("^Zona %d") then
            local name = GetZoneName(q.zoneId)
            if not zonesData[name] then
                zonesData[name] = { minL = 100, maxL = 0, count = 0, id = q.zoneId, allianceQuests = 0, hordeQuests = 0 }
            end
            local z = zonesData[name]
            z.count = z.count + 1
            
            local fac = GetQuestFaction(id, q)
            if fac == "Alliance" then
                z.allianceQuests = z.allianceQuests + 1
            elseif fac == "Horde" then
                z.hordeQuests = z.hordeQuests + 1
            else
                z.allianceQuests = z.allianceQuests + 1
                z.hordeQuests = z.hordeQuests + 1
            end

            local lvl = tonumber(q.level) or 0
            if lvl > 0 then
                if lvl < z.minL then z.minL = lvl end
                if lvl > z.maxL then z.maxL = lvl end
            end
        end
    end

    uniqueZones = {}
    for name, z in pairs(zonesData) do
        if z.minL == 100 then z.minL = 1 end
        
        local fac = "Both"
        if z.allianceQuests > 0 and z.hordeQuests == 0 then
            fac = "Alliance"
        elseif z.hordeQuests > 0 and z.allianceQuests == 0 then
            fac = "Horde"
        end

        local showZone = false
        if selectedZoneFactionFilter == "Both" then
            showZone = true
        elseif selectedZoneFactionFilter == "Alliance" then
            showZone = (fac == "Alliance" or fac == "Both")
        elseif selectedZoneFactionFilter == "Horde" then
            showZone = (fac == "Horde" or fac == "Both")
        end

        -- Filtro por continente (Kalimdor=1 / Eastern Kingdoms=2, Instancias=3). Las zonas con
        -- continente conocido se filtran; las sin dato (mazmorras, etc.) son instancias.
        local cont = ZoneCoordinates[z.id] and ZoneCoordinates[z.id].continent
        local contOK = false
        if not addon._zoneContinent then
            contOK = true
        elseif addon._zoneContinent == 1 then
            contOK = (cont == 1)
            elseif addon._zoneContinent == 2 then
            contOK = (cont == 2)
        elseif addon._zoneContinent == 0 then
            contOK = (not cont)
        end

        if showZone and contOK then
            table.insert(uniqueZones, {
                name = name,
                minL = z.minL,
                maxL = z.maxL,
                count = z.count,
                id = z.id,
                faction = fac,
                continent = cont,
                expansion = GetZoneExpansion(z.id),
            })
        end
    end
    table.sort(uniqueZones, function(a, b) return a.name < b.name end)
end

-- ============================================================
--  COMPILAR LISTAS SEGMENTADAS
-- ============================================================
local function MatchLevelRange(lvl, range)
    if range == "Todos" then return true end
    local l = tonumber(lvl) or 0
    if l <= 0 then return false end
    if range == "1-10" then return l >= 1 and l <= 10
    elseif range == "11-20" then return l >= 11 and l <= 20
    elseif range == "21-30" then return l >= 21 and l <= 30
    elseif range == "31-40" then return l >= 31 and l <= 40
    elseif range == "41-50" then return l >= 41 and l <= 50
    elseif range == "51-59" then return l >= 51 and l <= 59
    end
    return false
end

local function BuildFilteredQuestIds()
    filteredQuestIds = {}
    if not SKquests_DetailDB then return end

    local query = searchText:lower()
    for id, q in pairs(SKquests_DetailDB) do
        if IsQuestEligible(id, q) then
            local title = string.upper(q.name or "")
            local matchesQuery = true
            if query ~= "" then
                local nameLoc = q.name_loc or ""
                local giver = q.giver or ""
                local ender = q.ender or ""
                local zoneName = GetZoneName(q.zoneId)
                matchesQuery = title:lower():find(query, 1, true) or
                               nameLoc:lower():find(query, 1, true) or
                               giver:lower():find(query, 1, true) or
                               ender:lower():find(query, 1, true) or
                               zoneName:lower():find(query, 1, true)
            end

            local matchesZone = true
            if selectedZoneFilter ~= "Todas" then
                local zoneName = GetZoneName(q.zoneId)
                matchesZone = zoneName == selectedZoneFilter
            end

            local matchesLvl = MatchLevelRange(q.level or 0, selectedLevelFilter)
            if matchesLvl then
                local _lvl = tonumber(q.level) or 0
                if selectedLevelMin and selectedLevelMin > 0 and _lvl < selectedLevelMin then matchesLvl = false end
                if selectedLevelMax and selectedLevelMax > 0 and _lvl > selectedLevelMax then matchesLvl = false end
            end
            
            local matchesFaction = true
            if addon._questFactionFilter and addon._questFactionFilter ~= "Both" then
                local fac = GetQuestFaction(id, q)
                matchesFaction = (fac == addon._questFactionFilter or fac == "Both")
            end
            
            local matchesContinent = true
            if addon._questContinentFilter and addon._questContinentFilter ~= "All" then
                local cont = ZoneCoordinates[q.zoneId] and ZoneCoordinates[q.zoneId].continent
                if addon._questContinentFilter == "Instances" then
                    matchesContinent = (not cont)
                elseif addon._questContinentFilter == "Kalimdor" then
                    matchesContinent = (cont == 1)
                elseif addon._questContinentFilter == "Eastern Kingdoms" then
                    matchesContinent = (cont == 2)
                elseif addon._questContinentFilter == "Dungeons" then
                    matchesContinent = (not cont)
                end
            end

            if matchesQuery and matchesZone and matchesLvl and matchesFaction and matchesContinent then
                table.insert(filteredQuestIds, id)
            end
        end
    end

    -- Ordenar por nivel, luego por nombre (a prueba de fallos con tonumber/tostring)
    pcall(function() table.sort(filteredQuestIds, function(a, b)
        local qa = SKquests_DetailDB[a]
        local qb = SKquests_DetailDB[b]
        if not qa or not qb then return false end
        
        local la = tonumber(qa.level) or 0
        local lb = tonumber(qb.level) or 0
        if la ~= lb then
            return la < lb
        end
        return tostring(qa.name or "") < tostring(qb.name or "")
    end) end)
end

-- ============================================================
--  COMPILAR CAPITULOS DE GUIA
-- ============================================================
local function BuildGuideChapters()
    guideChapters = {}
    local guide = addon:GetGuideTable()
    if not guide then return end

    local currentTitle = ""
    local chapterStartIndex = 1
    
    for i, step in ipairs(guide) do
        local ges = GetGuideES(i)
        local rawTitle = (ges and ges.title) or step.title or "Paso " .. i
        local t = rawTitle
        -- Parse title like "1-5 Northshire Valley — Circuit 1"
        -- Also supports "1-5 Northshire Valley ? Circuit 1" or hyphen
        local zoneMatch = rawTitle:match("^(?:%d+%-%d+%s+)?(.+?)%s*[%-—%?]%s*Circui[to]+")
        if zoneMatch then
            t = zoneMatch:gsub("^%s+", ""):gsub("%s+$", "")
        end

        if t ~= currentTitle then
            if currentTitle ~= "" then
                table.insert(guideChapters, { title = currentTitle, startIndex = chapterStartIndex, endIndex = i - 1 })
            end
            currentTitle = t
            chapterStartIndex = i
        end
    end
    if currentTitle ~= "" then
        table.insert(guideChapters, { title = currentTitle, startIndex = chapterStartIndex, endIndex = #guide })
    end

    if selectedGuideChapter > #guideChapters then selectedGuideChapter = 1 end
    if selectedGuideChapter < 1 then selectedGuideChapter = 1 end

    filteredGuideSteps = {}
    if guideChapters[selectedGuideChapter] then
        local ch = guideChapters[selectedGuideChapter]
        for i = ch.startIndex, ch.endIndex do
            table.insert(filteredGuideSteps, { originalIndex = i, step = guide[i] })
        end
    end
end

-- Getters de diagnóstico (flujo de datos guía/tracker)
addon.GetGuideCounts = function(self)
    local guide = addon:GetGuideTable()
    local guideN = guide and #guide or 0
    local chapN = guideChapters and #guideChapters or 0
    local stepN = filteredGuideSteps and #filteredGuideSteps or 0
    return guideN, chapN, stepN
end
addon.GetActiveQuestCount = function(self)
    local n = 0
    if addon.Tracker and addon.Tracker.GetActiveQuests then
        for _ in pairs(addon.Tracker:GetActiveQuests()) do n = n + 1 end
    end
    return n
end

-- ============================================================
--  ACTUALIZAR ANCLAJES AL EXPANDIR / COLAPSAR PANEL DERECHO
-- ============================================================
local function UpdateDetailPanelAnchors()
    DetailPanel:ClearAllPoints()
    DetailPanel:SetPoint("TOPLEFT", ListPanel, "TOPRIGHT", 6, 0)
    DetailPanel:SetPoint("BOTTOMLEFT", ListPanel, "BOTTOMRIGHT", 6, 0)

    if rightSidebarShown and (activeTab == "quests" or activeTab == "questlog") then
        RightSidebar:Show()
        DetailPanel:SetPoint("BOTTOMRIGHT", RightSidebar, "BOTTOMLEFT", -6, 0)
    else
        RightSidebar:Hide()
        local ins = addon._inset or 10
        DetailPanel:SetPoint("BOTTOMRIGHT", MainFrame, "BOTTOMRIGHT", -ins, ins)
    end
end

-- ============================================================
--  MARCO TEMÁTICO 9-SLICE (texturas pintadas vía SetTexCoord)
--  Recorta esquinas/bordes de una sola textura de marco y mete
--  el contenido hacia adentro para que no se tape nada.
-- ============================================================
-- Fracción del marco que ocupa la esquina (x,y), por tema.
local THEME_FRAC = {
    blizzardclassic = {0.134, 0.371}, wrathclassic = {0.147, 0.396},
    dragonflight = {0.114, 0.331}, modern = {0.109, 0.316},
    warcraftlogs = {0.095, 0.293}, }
local THEME_BT = 44   -- grosor del marco en pantalla = inset del contenido

function addon:SetPanelInset(inset)
    addon._inset = inset
    local f = MainFrame
    if not f then return end
    if f.titlebar then
        f.titlebar:ClearAllPoints()
        f.titlebar:SetPoint("TOPLEFT", f, "TOPLEFT", inset, -(inset + 2))
        f.titlebar:SetPoint("TOPRIGHT", f, "TOPRIGHT", -inset, -(inset + 2))
    end
    if Sidenav then
        Sidenav:ClearAllPoints()
        Sidenav:SetPoint("TOPLEFT", f, "TOPLEFT", inset, -(inset + 28))
        Sidenav:SetPoint("BOTTOMLEFT", f, "BOTTOMLEFT", inset, inset)
    end
    for _, p in ipairs({ GuideCardsPanel, GuideLockPanel }) do
        if p then
            p:ClearAllPoints()
            p:SetPoint("TOPLEFT", ListPanel, "TOPLEFT", 0, 0)
            p:SetPoint("BOTTOMRIGHT", f, "BOTTOMRIGHT", -inset, inset)
        end
    end
    UpdateDetailPanelAnchors()
end

function addon:ApplyThemeFrameBorder(key)
    local f = MainFrame
    if not f then return end
    local fr = THEME_FRAC[key]
    if not fr then
        if f._themeBorder then f._themeBorder:Hide() end
        return
    end
    local fx, fy = fr[1], fr[2]
    local BT = THEME_BT
    local tex = "Interface\\AddOns\\SKquests\\Media\\" .. key .. "_border"
    local tb = f._themeBorder
    if not tb then
        tb = CreateFrame("Frame", nil, f)
        tb:SetAllPoints(f); tb:EnableMouse(false)
        tb:SetFrameLevel(f:GetFrameLevel() + 30)
        tb._t = {}
        for _, k in ipairs({ "tl","tr","bl","br","et","eb","el","er" }) do
            tb._t[k] = tb:CreateTexture(nil, "ARTWORK")
        end
        f._themeBorder = tb
    end
    tb:Show()
    local T = tb._t
    for _, k in ipairs({ "tl","tr","bl","br","et","eb","el","er" }) do
        T[k]:SetTexture(tex); T[k]:ClearAllPoints()
    end
    T.tl:SetTexCoord(0, fx, 0, fy);       T.tl:SetPoint("TOPLEFT", 0, 0);        T.tl:SetSize(BT, BT)
    T.tr:SetTexCoord(1-fx, 1, 0, fy);     T.tr:SetPoint("TOPRIGHT", 0, 0);       T.tr:SetSize(BT, BT)
    T.bl:SetTexCoord(0, fx, 1-fy, 1);     T.bl:SetPoint("BOTTOMLEFT", 0, 0);     T.bl:SetSize(BT, BT)
    T.br:SetTexCoord(1-fx, 1, 1-fy, 1);   T.br:SetPoint("BOTTOMRIGHT", 0, 0);    T.br:SetSize(BT, BT)
    T.et:SetTexCoord(fx, 1-fx, 0, fy);    T.et:SetPoint("TOPLEFT", BT, 0);   T.et:SetPoint("TOPRIGHT", -BT, 0);   T.et:SetHeight(BT)
    T.eb:SetTexCoord(fx, 1-fx, 1-fy, 1);  T.eb:SetPoint("BOTTOMLEFT", BT, 0);T.eb:SetPoint("BOTTOMRIGHT", -BT, 0);T.eb:SetHeight(BT)
    T.el:SetTexCoord(0, fx, fy, 1-fy);    T.el:SetPoint("TOPLEFT", 0, -BT);  T.el:SetPoint("BOTTOMLEFT", 0, BT);  T.el:SetWidth(BT)
    T.er:SetTexCoord(1-fx, 1, fy, 1-fy);  T.er:SetPoint("TOPRIGHT", 0, -BT); T.er:SetPoint("BOTTOMRIGHT", 0, BT); T.er:SetWidth(BT)
    return BT
end

-- ============================================================
--  CONVERSOR DE MAPAS DE GUIA
-- ============================================================
local function GetGuideMapTexture(image)
    if not image or image == "" then return nil end
    local cleanImage = image:gsub("%.jpeg$", ""):gsub("%.jpg$", ""):gsub("%.png$", "")
    local faction = addon.db and addon.db.currentGuide or "Alliance"
    local folder = faction == "Alliance" and "Images Ally" or "Images Horde"
    return "Interface\\AddOns\\SKquests\\Media\\" .. folder .. "\\" .. cleanImage
end

-- ============================================================
--  UTILIDAD PARA EDITBOX COPIABLE
-- ============================================================
local function CreateCopyableBox(parent, w, h)
    local box = CreateFrame("EditBox", nil, parent)
    box:SetSize(w, h)
    box:SetFontObject("GameFontHighlightSmall")
    SKQ_EnsureBackdrop(box)
    box:SetBackdrop({
        bgFile = "Interface\\ChatFrame\\ChatFrameBackground",
        edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
        edgeSize = 8, insets = {left=2, right=2, top=2, bottom=2}
    })
    box:SetBackdropColor(0,0,0,0.6)
    box:SetBackdropBorderColor(0.4, 0.4, 0.4, 0.6)
    box:SetAutoFocus(false)
    box:SetTextInsets(4, 4, 0, 0)
    box:SetScript("OnEscapePressed", function(self) self:ClearFocus() end)
    box:SetScript("OnEditFocusGained", function(self) self:HighlightText() end)
    box:SetScript("OnMouseUp", function(self) self:HighlightText() end)
    return box
end

-- ============================================================
--  DYNAMIC LAYOUT SOLVER
-- ============================================================
local function LayoutDetailSections(ch)
    if not ch then return end

    local prev = ch.header

    -- 1) questImgBox (Ilustración)
    -- Usamos el flag determinista hasMap (fijado en SetQuest) en vez de
    -- :IsShown(), que puede estar desincronizado al momento del layout y
    -- provocar que objSec se ancle al header y se superponga al mapa.
    if (activeTab == "quests" or activeTab == "questlog") and ch.questImgBox and ch.questImgBox.hasMap then
        ch.questImgBox:Show()
        ch.questImgBox:ClearAllPoints()
        ch.questImgBox:SetPoint("TOPLEFT", prev, "BOTTOMLEFT", 0, -6)
        ch.questImgBox:SetPoint("TOPRIGHT", ch.header, "BOTTOMRIGHT", 0, -6)
        prev = ch.questImgBox
    elseif ch.questImgBox then
        ch.questImgBox:Hide()
    end

    -- 2) objSec
    if ch.objSec then
        ch.objSec:ClearAllPoints()
        ch.objSec:SetPoint("TOPLEFT", prev, "BOTTOMLEFT", 0, -6)
        ch.objSec:SetPoint("TOPRIGHT", ch.header, "BOTTOMRIGHT", 0, -6)
        if activeTab == "guide" then
            -- Let RefreshDetail handle the height dynamically based on contents
        else
            ch.objSec:SetHeight(120)
        end
        prev = ch.objSec
    end

    -- 3) mapBox (Only for Guide)
    if activeTab == "guide" and ch.mapBox and ch.mapBox:IsShown() then
        -- MapBox anchoring is handled directly in RefreshDetail (anchors to last guide checkbox)
    elseif ch.mapBox then
        ch.mapBox:Hide()
    end

    -- 4) descSec
    if (activeTab == "quests" or activeTab == "questlog") and ch.descSec then
        ch.descSec:ClearAllPoints()
        ch.descSec:SetPoint("TOPLEFT", prev, "BOTTOMLEFT", 0, -6)
        ch.descSec:SetPoint("TOPRIGHT", ch.header, "BOTTOMRIGHT", 0, -6)
        ch.descSec:Show()
        prev = ch.descSec
    elseif ch.descSec then
        ch.descSec:Hide()
    end

    -- 5) npcSec
    if (activeTab == "quests" or activeTab == "questlog") and ch.npcSec then
        ch.npcSec:ClearAllPoints()
        ch.npcSec:SetPoint("TOPLEFT", prev, "BOTTOMLEFT", 0, -6)
        ch.npcSec:SetPoint("TOPRIGHT", ch.header, "BOTTOMRIGHT", 0, -6)
        ch.npcSec:Show()
        prev = ch.npcSec
    elseif ch.npcSec then
        ch.npcSec:Hide()
    end

    -- 6) rewardSec
    if (activeTab == "quests" or activeTab == "questlog") and ch.rewardSec and ch.rewardSec:IsShown() then
        ch.rewardSec:ClearAllPoints()
        ch.rewardSec:SetPoint("TOPLEFT", prev, "BOTTOMLEFT", 0, -6)
        ch.rewardSec:SetPoint("TOPRIGHT", ch.header, "BOTTOMRIGHT", 0, -6)
        prev = ch.rewardSec
    elseif ch.rewardSec then
        ch.rewardSec:Hide()
    end

    -- [WotLK Classic] linkSec layout removed
end

-- ============================================================
--  XP APPRAISER — controles dentro del panel de Ajustes
--  En su propia función a nivel de archivo a propósito: Lua 5.1
--  limita a 200 locals por función y CreateModernUI ya está al
--  borde, así que estos controles viven aparte.
-- ============================================================
function addon:AddXPAppraiserSettings(SettingsPanel)
    local function XPL(es, en)
        local cur = SKquests_Localization and SKquests_Localization.currentLanguage or "esES"
        if cur == "esES" then return es else return en end
    end

    local xpHdr = SettingsPanel:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    xpHdr:SetPoint("TOPLEFT", 300, -44)
    xpHdr:SetText("XP Appraiser")
    table.insert(SettingsPanel.labels, xpHdr)

    local xpDesc = SettingsPanel:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    xpDesc:SetPoint("TOPLEFT", 300, -66)
    xpDesc:SetText(XPL("Medidor de XP por hora", "Experience per hour meter"))

    -- Activar / desactivar el medidor
    local xpEnable = CreateFrame("CheckButton", "SKquests_CB_xpEnabled", SettingsPanel, "UICheckButtonTemplate")
    xpEnable:SetPoint("TOPLEFT", 300, -88)
    local xpEnableLbl = _G["SKquests_CB_xpEnabledText"]
    if xpEnableLbl then
        xpEnableLbl:SetText(XPL("Activar medidor", "Enable meter"))
        table.insert(SettingsPanel.labels, xpEnableLbl)
    end
    xpEnable:SetChecked(not (SKQ_XPStats and SKQ_XPStats.enabled == false))
    xpEnable:SetScript("OnClick", function(self)
        if SKquests.XPSetEnabled then SKquests:XPSetEnabled(self:GetChecked() and true or false) end
    end)

    -- Auto-pausa al estar AFK
    local xpAfk = CreateFrame("CheckButton", "SKquests_CB_xpAfk", SettingsPanel, "UICheckButtonTemplate")
    xpAfk:SetPoint("TOPLEFT", 300, -118)
    local xpAfkLbl = _G["SKquests_CB_xpAfkText"]
    if xpAfkLbl then
        xpAfkLbl:SetText(XPL("Auto-pausa al estar AFK", "Auto-pause when AFK"))
        table.insert(SettingsPanel.labels, xpAfkLbl)
    end
    xpAfk:SetChecked(not (SKQ_XPStats and SKQ_XPStats.autoPauseAFK == false))
    xpAfk:SetScript("OnClick", function(self)
        SKQ_XPStats = SKQ_XPStats or {}
        SKQ_XPStats.autoPauseAFK = self:GetChecked() and true or false
    end)

    -- Botón: abrir la ventana del medidor
    local xpOpenBtn = CreateFrame("Button", nil, SettingsPanel, "UIPanelButtonTemplate")
    xpOpenBtn:SetPoint("TOPLEFT", 302, -150)
    xpOpenBtn:SetSize(150, 24)
    xpOpenBtn:SetText(XPL("Abrir ventana", "Open window"))
    xpOpenBtn:SetScript("OnClick", function()
        if SKquests.XPShowWindow then SKquests:XPShowWindow() end
    end)

    -- Botón: pausar / reanudar manualmente
    local xpPauseBtn = CreateFrame("Button", nil, SettingsPanel, "UIPanelButtonTemplate")
    xpPauseBtn:SetPoint("TOPLEFT", 302, -178)
    xpPauseBtn:SetSize(150, 24)
    xpPauseBtn:SetText(XPL("Pausar / Reanudar", "Pause / Resume"))
    xpPauseBtn:SetScript("OnClick", function()
        if SKquests.XPTogglePause then SKquests:XPTogglePause() end
    end)

    -- Botones: nueva sesión / reiniciar estadísticas
    local xpNewBtn = CreateFrame("Button", nil, SettingsPanel, "UIPanelButtonTemplate")
    xpNewBtn:SetPoint("TOPLEFT", 302, -206)
    xpNewBtn:SetSize(72, 24)
    xpNewBtn:SetText(XPL("Nueva", "New"))
    xpNewBtn:SetScript("OnClick", function()
        if SKquests.XPNewSession then SKquests:XPNewSession(true) end
    end)

    local xpResetBtn = CreateFrame("Button", nil, SettingsPanel, "UIPanelButtonTemplate")
    xpResetBtn:SetPoint("LEFT", xpNewBtn, "RIGHT", 6, 0)
    xpResetBtn:SetSize(72, 24)
    xpResetBtn:SetText(XPL("Reiniciar", "Reset"))
    xpResetBtn:SetScript("OnClick", function()
        if SKquests.XPResetStats then SKquests:XPResetStats() end
    end)

    -- Opacidad de la ventana del XP Appraiser
    local function xpGetOp()
        return (SKquests.XPGetOpacity and SKquests:XPGetOpacity()) or 0.95
    end
    local xpOpLbl = SettingsPanel:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    xpOpLbl:SetPoint("TOPLEFT", 302, -240)
    xpOpLbl:SetText(XPL("Opacidad de la ventana", "Window opacity"))
    table.insert(SettingsPanel.labels, xpOpLbl)

    local xpOp = CreateFrame("Slider", "SKquestsXPOpacitySlider", SettingsPanel, "OptionsSliderTemplate")
    xpOp:SetPoint("TOPLEFT", 302, -264)
    xpOp:SetWidth(200)
    xpOp:SetMinMaxValues(20, 100)
    xpOp:SetValueStep(5)
    xpOp:SetValue(math.floor(xpGetOp() * 100))
    local xpOpLow = _G["SKquestsXPOpacitySliderLow"]
    if xpOpLow then xpOpLow:SetText("20%") end
    local xpOpHigh = _G["SKquestsXPOpacitySliderHigh"]
    if xpOpHigh then xpOpHigh:SetText("100%") end
    local xpOpTxt = _G["SKquestsXPOpacitySliderText"]
    if xpOpTxt then xpOpTxt:SetText(XPL("Opacidad", "Opacity") .. ": " .. math.floor(xpGetOp() * 100) .. "%") end
    xpOp:SetScript("OnValueChanged", function(self, val)
        if SKquests.XPSetOpacity then SKquests:XPSetOpacity(val / 100) end
        local t = _G[self:GetName() .. "Text"]
        if t then t:SetText(XPL("Opacidad", "Opacity") .. ": " .. math.floor(val) .. "%") end
    end)

    -- Mantener los checkboxes en sincronía cada vez que se abre Ajustes
    SettingsPanel:HookScript("OnShow", function()
        xpEnable:SetChecked(not (SKQ_XPStats and SKQ_XPStats.enabled == false))
        xpAfk:SetChecked(not (SKQ_XPStats and SKQ_XPStats.autoPauseAFK == false))
        xpOp:SetValue(math.floor(xpGetOp() * 100))
    end)
end

-- ============================================================
--  CREACIÓN DE LA INTERFAZ PRINCIPAL
-- ============================================================
function addon:CreateModernUI()
    if MainFrame then return end

    local initialW = SKquestsDB and SKquestsDB.config and SKquestsDB.config.width or 940
    local initialH = SKquestsDB and SKquestsDB.config and SKquestsDB.config.height or 640

    -- La ventana NUNCA debe ser más alta/ancha que la pantalla, o el borde
    -- superior de la lista queda fuera de vista (filas invisibles).
    local screenH = math.floor((UIParent:GetHeight() or 768) - 40)
    local screenW = math.floor((UIParent:GetWidth() or 1024) - 40)
    local maxH = math.min(1000, screenH)
    local maxW = math.min(1600, screenW)
    if initialH > maxH then initialH = maxH end
    if initialW > maxW then initialW = maxW end
    if SKquestsDB and SKquestsDB.config then
        SKquestsDB.config.height = initialH
        SKquestsDB.config.width = initialW
    end

    -- ---- MARCO PRINCIPAL ----
    local f = CreateFrame("Frame", "SKquestsMainFrame", UIParent)
    f:SetSize(initialW, initialH)
    f:SetPoint("CENTER")
    f:SetMovable(true)
    f:SetResizable(true)
    if f.SetResizeBounds then
        f:SetResizeBounds(800, 480, maxW, maxH)
    else
        f:SetMinResize(800, 480)
        f:SetMaxResize(maxW, maxH)
    end
    f:EnableMouse(true)
    f:RegisterForDrag("LeftButton")
    f:SetScript("OnDragStart", function(self)
        if self:IsMovable() then self:StartMoving() end
    end)
    f:SetScript("OnDragStop",  f.StopMovingOrSizing)
    f:SetFrameStrata("DIALOG")
    f:SetFrameLevel(10)
    MainFrame = f
    addon.MainFrame = f

    ApplyBD(f, C.bg, C.border, 12)

    -- Guardar tamaño al terminar resize
    f:SetScript("OnSizeChanged", function(self, w, h)
        w = math.floor(w)
        h = math.floor(h)
        if SKquestsDB and SKquestsDB.config then
            SKquestsDB.config.width = w
            SKquestsDB.config.height = h
        end
        addon:UpdateListRows()
    end)

    -- ---- CONTROL DE REDIMENSIÓN (CORNER HANDLES) ----
    local resizeHandles = {}
    local corners = {
        { point = "BOTTOMRIGHT", x = 0, y = 0, size = 24 },
        { point = "BOTTOMLEFT", x = 0, y = 0, size = 24 },
        { point = "TOPRIGHT", x = 0, y = 0, size = 24 },
        { point = "TOPLEFT", x = 0, y = 0, size = 24 },
    }

    for _, info in ipairs(corners) do
        local handle = CreateFrame("Button", nil, f)
        handle:SetPoint(info.point, f, info.point, info.x, info.y)
        handle:SetSize(info.size, info.size)
        handle:SetFrameLevel(f:GetFrameLevel() + 50)

        if info.point == "BOTTOMRIGHT" then
            handle:SetNormalTexture("Interface\\ChatFrame\\UI-ChatIM-SizeGrabber-Up")
            handle:SetHighlightTexture("Interface\\ChatFrame\\UI-ChatIM-SizeGrabber-Highlight")
        else
            -- Resaltado sutil en hover
            local tex = handle:CreateTexture(nil, "HIGHLIGHT")
            tex:SetAllPoints()
            tex:SetTexture(1, 1, 1, 0.25)
        end

        handle:SetScript("OnMouseDown", function(self, button)
            if button == "LeftButton" then
                f:StartSizing(info.point)
            end
        end)
        handle:SetScript("OnMouseUp", function(self, button)
            f:StopMovingOrSizing()
        end)

        table.insert(resizeHandles, handle)
    end
    f.resizeHandles = resizeHandles

    function addon:UpdateResizeHandles()
        local locked = SKquestsDB and SKquestsDB.config and SKquestsDB.config.locked or false
        if f.resizeHandles then
            for _, handle in ipairs(f.resizeHandles) do
                if locked then
                    handle:Hide()
                else
                    handle:Show()
                end
            end
        end
    end

    -- ---- BARRA DE TÍTULO ----
    local titlebar = CreateFrame("Frame", nil, f)
    titlebar:SetPoint("TOPLEFT", f, "TOPLEFT", 10, -8)
    titlebar:SetPoint("TOPRIGHT", f, "TOPRIGHT", -10, -8)
    titlebar:SetHeight(24)
    f.titlebar = titlebar

    -- Logotipo de WoW en textura circular
    local logo = titlebar:CreateTexture(nil, "OVERLAY")
    logo:SetPoint("LEFT", 4, 0)
    logo:SetSize(22, 22)
    logo:Hide()  -- logo solo en boton de minimapa, no en la barra

    local titleText = titlebar:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    titleText:SetPoint("LEFT", logo, "RIGHT", 8, -1)
    f.titleText = titleText

    local hCount = titlebar:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    hCount:SetPoint("LEFT", titleText, "RIGHT", 14, 0)
    f.hCount = hCount

    -- Botón de cerrar
    local closeBtn = CreateFrame("Button", nil, titlebar, "UIPanelCloseButton")
    closeBtn:SetPoint("RIGHT", 0, 0)
    closeBtn:SetSize(22, 22)
    closeBtn:SetScript("OnClick", function() f:Hide() end)

    -- Botón de expandir/colapsar barra de metadatos (Right Sidebar)
    local toggleSidebarBtn = CreateFrame("Button", nil, titlebar)
    toggleSidebarBtn:SetPoint("RIGHT", closeBtn, "LEFT", -4, 0)
    toggleSidebarBtn:SetSize(18, 18)
    toggleSidebarBtn:SetNormalTexture("Interface\\Buttons\\UI-SpellbookIcon-NextPage-Up")
    toggleSidebarBtn:SetHighlightTexture("Interface\\Buttons\\UI-Common-MouseHilight")
    toggleSidebarBtn:RegisterForClicks("LeftButtonUp")
    toggleSidebarBtn:SetScript("OnClick", function()
        rightSidebarShown = not rightSidebarShown
        UpdateDetailPanelAnchors()
    end)

    -- ================================================================
    --  SIDEBAR IZQUIERDA (NAVEGACIÓN)
    -- ================================================================
    Sidenav = CreateFrame("Frame", nil, f)
    Sidenav:SetPoint("TOPLEFT", f, "TOPLEFT", 10, -32)
    Sidenav:SetPoint("BOTTOMLEFT", f, "BOTTOMLEFT", 10, 10)
    Sidenav:SetWidth(110)
    ApplyBD(Sidenav, C.bgSide, C.borderDim, 8)

    local brand = Sidenav:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    brand:SetPoint("TOP", Sidenav, "TOP", 0, -14)
    brand:SetText("SK")
    brand:SetTextColor(1, 0.8, 0)

    local brandSub = Sidenav:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    brandSub:SetPoint("TOP", brand, "BOTTOM", 0, 2)
    brandSub:SetText("QUESTS")
    brandSub:SetTextColor(0.5, 0.5, 0.5)

    -- Botones del Menu Lateral
    Sidenav.buttons = {}
    local menuItems = {
        { id = "guide",    key = "TAB_GUIDE" },
        { id = "questlog", key = "TAB_QUESTLOG" },
        { id = "quests",   key = "TAB_QUESTS" },
        { id = "zones",    key = "TAB_ZONES" },
        { id = "settings", key = "TAB_SETTINGS" },
        { id = "about",    key = "TAB_ABOUT" },
    }

    local function OnTabClick(self)
        addon:SwitchTab(self.tabId)
        addon:UpdateListRows()
    end

    for i, item in ipairs(menuItems) do
        local btn = CreateFrame("Button", nil, Sidenav)
        btn:SetSize(90, 28)
        btn:SetPoint("TOP", Sidenav, "TOP", 0, -56 - (i - 1) * 32)
        btn.tabId = item.id
        btn:RegisterForClicks("LeftButtonUp")

        SKQ_EnsureBackdrop(btn)
        btn:SetBackdrop({
            bgFile = "Interface\\ChatFrame\\ChatFrameBackground",
            edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
            edgeSize = 8, insets = {left=2, right=2, top=2, bottom=2}
        })
        btn:SetBackdropColor(0,0,0,0)
        btn:SetBackdropBorderColor(0,0,0,0)

        local t = btn:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
        t:SetPoint("LEFT", 8, 0)
        RegLoc(t, item.key)
        btn.txt = t

        btn:SetScript("OnEnter", function(self)
            if activeTab ~= self.tabId then
                self:SetBackdropColor(C.bgHover[1], C.bgHover[2], C.bgHover[3], 0.4)
            end
        end)
        btn:SetScript("OnLeave", function(self)
            if activeTab ~= self.tabId then
                self:SetBackdropColor(0,0,0,0)
            end
        end)
        btn:SetScript("OnClick", OnTabClick)

        Sidenav.buttons[item.id] = btn
    end

    -- ================================================================
    --  COLUMNA CENTRAL (LISTADO & FILTROS)
    -- ================================================================
    ListPanel = CreateFrame("Frame", nil, f)
    ListPanel:SetPoint("TOPLEFT", Sidenav, "TOPRIGHT", 6, 0)
    ListPanel:SetPoint("BOTTOMLEFT", Sidenav, "BOTTOMRIGHT", 6, 0)
    ListPanel:SetWidth(260)
    ApplyBD(ListPanel, C.bgList, C.borderDim, 8)

    -- ================================================================
    --  PANEL DE ZONAS (se muestra a la izquierda de la lista cuando
    --  activeTab es "quests" o "questlog")
    -- ================================================================
    
    -- Removemos ZonePanel completamente

    local function UpdateListPanelAnchor()
        ListPanel:ClearAllPoints()
        ListPanel:SetPoint("TOPLEFT", Sidenav, "TOPRIGHT", 6, 0)
        ListPanel:SetPoint("BOTTOMLEFT", Sidenav, "BOTTOMRIGHT", 6, 0)
    end

    ListPanel.UpdateAnchor = UpdateListPanelAnchor

    -- Cabecera con búsqueda y facción
    local filtersFrame = CreateFrame("Frame", nil, ListPanel)
    filtersFrame:SetPoint("TOPLEFT", ListPanel, "TOPLEFT", 6, -6)
    filtersFrame:SetPoint("TOPRIGHT", ListPanel, "TOPRIGHT", -6, -6)
    filtersFrame:SetHeight(30)
    ListPanel.filtersFrame = filtersFrame

      -- ================================================================
      --  BARRA DE FILTRO DE ZONA (aparece cuando hay zona seleccionada)
      -- ================================================================
      local zoneBar = CreateFrame("Frame", nil, ListPanel)
      zoneBar:SetPoint("TOPLEFT", filtersFrame, "BOTTOMLEFT", 0, -2)
      zoneBar:SetPoint("TOPRIGHT", filtersFrame, "BOTTOMRIGHT", 0, -2)
      zoneBar:SetHeight(20)
      zoneBar:Hide()
      ListPanel.zoneBar = zoneBar

      local zoneBarBtn = CreateFrame("Button", nil, zoneBar)
      zoneBarBtn:SetPoint("TOPLEFT", 0, 0)
      zoneBarBtn:SetPoint("BOTTOMRIGHT", 0, 0)
      ApplyBD(zoneBarBtn, {0.12, 0.06, 0.0}, {0.75, 0.55, 0.20}, 5)
      zoneBarBtn:SetBackdropColor(0.15, 0.08, 0, 0.85)

      local zoneBarIcon = zoneBarBtn:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
      zoneBarIcon:SetPoint("LEFT", 6, 0)
      zoneBarIcon:SetTextColor(1.0, 0.80, 0.15)
      zoneBar.lbl = zoneBarIcon

      local zoneBarClose = zoneBarBtn:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
      zoneBarClose:SetPoint("RIGHT", -6, 0)
      zoneBarClose:SetText("|cffff8888[x] Todas|r")

      zoneBarBtn:SetScript("OnEnter", function(self)
          self:SetBackdropColor(0.25, 0.14, 0, 0.95)
      end)
      zoneBarBtn:SetScript("OnLeave", function(self)
          self:SetBackdropColor(0.15, 0.08, 0, 0.85)
      end)
      zoneBarBtn:SetScript("OnClick", function()
          selectedZoneFilter = "Todas"
          BuildFilteredQuestIds()
          FauxScrollFrame_SetOffset(ListPanel.scroll, 0)
          local zbar = _G[ListPanel.scroll:GetName() .. "ScrollBar"]
          if zbar then zbar:SetValue(0) end
          addon:UpdateListRows()
          PlaySound(SOUND.IG_MAINMENU_OPTION or 856)
      end)

    -- Filtro de Facción (Alliance / Horde)
    addon._questFactionFilter = "Both"
    local qFacBtn = CreateFrame("Button", nil, filtersFrame)
    qFacBtn:SetPoint("TOPRIGHT", -4, -4)
    qFacBtn:SetSize(80, 20)
    qFacBtn:RegisterForClicks("LeftButtonUp")
    ApplyBD(qFacBtn, {0,0,0}, {0.5,0.4,0.3}, 8)
    qFacBtn:SetBackdropColor(0,0,0,0.4)
    local qFacLbl = qFacBtn:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    qFacLbl:SetPoint("CENTER", 0, 0)
    qFacLbl:SetText("Faction")
    qFacBtn.lbl = qFacLbl

    local qFacMenu = CreateFrame("Frame", "SKquestsQuestFacMenu", f)
    qFacMenu:SetSize(100, 70)
    qFacMenu:SetPoint("TOPLEFT", qFacBtn, "BOTTOMLEFT", 0, -2)
    qFacMenu:SetFrameStrata("TOOLTIP")
    ApplyBD(qFacMenu, {0.05, 0.05, 0.05}, {0.5,0.4,0.3}, 8)
    qFacMenu:Hide()

    local facs = {"Both", "Alliance", "Horde"}
    for i, fac in ipairs(facs) do
        local btn = CreateFrame("Button", nil, qFacMenu)
        btn:SetSize(90, 20)
        btn:SetPoint("TOPLEFT", 5, -5 - (i-1)*20)
        local txt = btn:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
        txt:SetPoint("LEFT", 4, 0)
        txt:SetText(fac)
        btn:SetScript("OnClick", function()
            addon._questFactionFilter = fac
            qFacBtn.lbl:SetText(fac == "Both" and "Faction" or fac)
            qFacMenu:Hide()
            BuildFilteredQuestIds()
            FauxScrollFrame_SetOffset(ListPanel.scroll, 0)
            local zbar = _G[ListPanel.scroll:GetName() .. "ScrollBar"]
            if zbar then zbar:SetValue(0) end
            addon:UpdateListRows()
        end)
    end
    qFacBtn:SetScript("OnClick", function() if qFacMenu:IsShown() then qFacMenu:Hide() else qFacMenu:Show() end end)
    qFacBtn:SetScript("OnHide", function() qFacMenu:Hide() end)

    -- EditBox de Búsqueda
    local searchBox = CreateFrame("EditBox", "SKquestsSearchBox", filtersFrame, "InputBoxTemplate")
    searchBox:SetPoint("TOPLEFT", 4, -4)
    searchBox:SetPoint("RIGHT", qFacBtn, "LEFT", -6, 0)
    searchBox:SetHeight(20)
    searchBox:SetAutoFocus(false)
    searchBox:SetText("")
    searchBox:SetScript("OnTextChanged", function(self)
        searchText = self:GetText()
        BuildFilteredQuestIds()
        addon:UpdateListRows()
    end)
    searchBox:SetScript("OnEscapePressed", function(self) self:ClearFocus() end)
    ListPanel.searchBox = searchBox

    -- ================================================================
    --  FILTRO DE RANGO DE NIVEL (min/max) — solo pestaña Quests
    -- ================================================================
    do
    local levelBar = CreateFrame("Frame", nil, ListPanel)
    levelBar:SetPoint("TOPLEFT", filtersFrame, "BOTTOMLEFT", 0, -4)
    levelBar:SetPoint("TOPRIGHT", filtersFrame, "BOTTOMRIGHT", 0, -4)
    levelBar:SetHeight(22)
    levelBar:Hide()
    ListPanel.levelBar = levelBar

    local lvlLbl = levelBar:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    lvlLbl:SetPoint("LEFT", 4, 0)
    lvlLbl:SetText(IsSpanish() and "Nivel:" or "Level:")
    lvlLbl:SetTextColor(1.0, 0.82, 0.0)

    local function MakeLvlBox(name)
        local b = CreateFrame("EditBox", name, levelBar, "InputBoxTemplate")
        b:SetHeight(18); b:SetWidth(40)
        b:SetAutoFocus(false)
        b:SetNumeric(true)
        b:SetMaxLetters(3)
        b:SetJustifyH("CENTER")
        return b
    end

    local lvlMinBox = MakeLvlBox("SKquests_LvlMinBox")
    lvlMinBox:SetPoint("LEFT", lvlLbl, "RIGHT", 12, 0)
    local lvlDash = levelBar:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    lvlDash:SetPoint("LEFT", lvlMinBox, "RIGHT", 8, 0)
    lvlDash:SetText("-")
    local lvlMaxBox = MakeLvlBox("SKquests_LvlMaxBox")
    lvlMaxBox:SetPoint("LEFT", lvlDash, "RIGHT", 8, 0)

    local function ApplyLevelFilter()
        selectedLevelMin = tonumber(lvlMinBox:GetText())
        selectedLevelMax = tonumber(lvlMaxBox:GetText())
        BuildFilteredQuestIds()
        FauxScrollFrame_SetOffset(ListPanel.scroll, 0)
        local zbar = _G[ListPanel.scroll:GetName() .. "ScrollBar"]
        if zbar then zbar:SetValue(0) end
        addon:UpdateListRows()
    end
    lvlMinBox:SetScript("OnTextChanged", ApplyLevelFilter)
    lvlMaxBox:SetScript("OnTextChanged", ApplyLevelFilter)
    lvlMinBox:SetScript("OnEscapePressed", function(self) self:ClearFocus() end)
    lvlMaxBox:SetScript("OnEscapePressed", function(self) self:ClearFocus() end)
    lvlMinBox:SetScript("OnEnterPressed", function(self) self:ClearFocus() end)
    lvlMaxBox:SetScript("OnEnterPressed", function(self) self:ClearFocus() end)

    local lvlClear = CreateFrame("Button", nil, levelBar)
    lvlClear:SetSize(50, 18)
    lvlClear:SetPoint("LEFT", lvlMaxBox, "RIGHT", 12, 0)
    ApplyBD(lvlClear, {0,0,0}, {0.5,0.4,0.3}, 6)
    lvlClear:SetBackdropColor(0,0,0,0.4)
    local lvlClearLbl = lvlClear:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    lvlClearLbl:SetPoint("CENTER")
    lvlClearLbl:SetText(IsSpanish() and "Limpiar" or "Clear")
    lvlClear:SetScript("OnEnter", function(self) self:SetBackdropColor(0.2,0.12,0,0.7) end)
    lvlClear:SetScript("OnLeave", function(self) self:SetBackdropColor(0,0,0,0.4) end)
    lvlClear:SetScript("OnClick", function()
        lvlMinBox:SetText(""); lvlMaxBox:SetText("")
        lvlMinBox:ClearFocus(); lvlMaxBox:ClearFocus()
        ApplyLevelFilter()
        PlaySound(SOUND.IG_MAINMENU_OPTION_CHECKBOX_ON or 856)
    end)
    end -- do (levelBar scope)

    -- Cabecera alternativa para la Guía
    local guideFiltersFrame = CreateFrame("Frame", nil, ListPanel)
    guideFiltersFrame:SetPoint("TOPLEFT", ListPanel, "TOPLEFT", 6, -6)
    guideFiltersFrame:SetPoint("TOPRIGHT", ListPanel, "TOPRIGHT", -6, -6)
    guideFiltersFrame:SetHeight(30)
    guideFiltersFrame:Hide()
    ListPanel.guideFiltersFrame = guideFiltersFrame

    -- Botón de Facción (Alianza / Horda)
    local facBtn = CreateFrame("Button", nil, guideFiltersFrame)
    facBtn:SetPoint("TOPLEFT", 0, -4)
    facBtn:SetSize(80, 20)
    facBtn:RegisterForClicks("LeftButtonUp")
    ApplyBD(facBtn, {0,0,0}, {0.5,0.4,0.3}, 8)
    facBtn:SetBackdropColor(0,0,0,0.4)
    local facLbl = facBtn:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    facLbl:SetPoint("CENTER", 0, 0)
    facLbl:SetText("<- Guías")
    facBtn.lbl = facLbl
    guideFiltersFrame.facBtn = facBtn

    facBtn:SetScript("OnClick", function(self)
        addon.selectedGuideKey = nil
        addon:SwitchTab("guide")
    end)

    -- Botón "volver a la rejilla de guías"
    local backBtn = CreateFrame("Button", nil, guideFiltersFrame)
    backBtn:SetPoint("LEFT", facBtn, "RIGHT", 8, 0)
    backBtn:SetSize(80, 20)
    backBtn:RegisterForClicks("LeftButtonUp")
    ApplyBD(backBtn, {0,0,0}, {0.5,0.4,0.3}, 8)
    backBtn:SetBackdropColor(0,0,0,0.4)
    local backLbl = backBtn:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    backLbl:SetPoint("CENTER", 0, 0)
    backLbl:SetText("<- Guías")
    backBtn.lbl = backLbl
    guideFiltersFrame.backBtn = backBtn
    backBtn:SetScript("OnClick", function()
        addon.selectedGuideKey = nil
        addon:SwitchTab("guide")
    end)

    -- Cabecera alternativa para las Zonas
    local zoneFiltersFrame = CreateFrame("Frame", nil, ListPanel)
    zoneFiltersFrame:SetPoint("TOPLEFT", ListPanel, "TOPLEFT", 6, -6)
    zoneFiltersFrame:SetPoint("TOPRIGHT", ListPanel, "TOPRIGHT", -6, -6)
    zoneFiltersFrame:SetHeight(30)
    zoneFiltersFrame:Hide()
    ListPanel.zoneFiltersFrame = zoneFiltersFrame

    local btnAlliance = CreateFrame("Button", nil, zoneFiltersFrame)
    btnAlliance:SetSize(76, 20)
    btnAlliance:SetPoint("TOPLEFT", 0, -4)
    ApplyBD(btnAlliance, {0,0,0}, {0.5,0.4,0.3}, 8)
    local lblAlliance = btnAlliance:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    lblAlliance:SetPoint("CENTER", 0, 0)
    RegLoc(lblAlliance, "FILTER_ALLIANCE")
    btnAlliance.lbl = lblAlliance

    local btnHorde = CreateFrame("Button", nil, zoneFiltersFrame)
    btnHorde:SetSize(76, 20)
    btnHorde:SetPoint("LEFT", btnAlliance, "RIGHT", 6, 0)
    ApplyBD(btnHorde, {0,0,0}, {0.5,0.4,0.3}, 8)
    local lblHorde = btnHorde:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    lblHorde:SetPoint("CENTER", 0, 0)
    RegLoc(lblHorde, "FILTER_HORDE")
    btnHorde.lbl = lblHorde

    local btnBoth = CreateFrame("Button", nil, zoneFiltersFrame)
    btnBoth:SetSize(76, 20)
    btnBoth:SetPoint("LEFT", btnHorde, "RIGHT", 6, 0)
    ApplyBD(btnBoth, {0,0,0}, {0.5,0.4,0.3}, 8)
    local lblBoth = btnBoth:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    lblBoth:SetPoint("CENTER", 0, 0)
    RegLoc(lblBoth, "FILTER_BOTH")
    btnBoth.lbl = lblBoth

    local function UpdateZoneFactionFilterUI()
        if selectedZoneFactionFilter == "Alliance" then
            btnAlliance:SetBackdropColor(0.2, 0.4, 0.8, 0.8)
            btnHorde:SetBackdropColor(0, 0, 0, 0.4)
            btnBoth:SetBackdropColor(0, 0, 0, 0.4)
        elseif selectedZoneFactionFilter == "Horde" then
            btnAlliance:SetBackdropColor(0, 0, 0, 0.4)
            btnHorde:SetBackdropColor(0.8, 0.2, 0.2, 0.8)
            btnBoth:SetBackdropColor(0, 0, 0, 0.4)
        else
            btnAlliance:SetBackdropColor(0, 0, 0, 0.4)
            btnHorde:SetBackdropColor(0, 0, 0, 0.4)
            btnBoth:SetBackdropColor(0.6, 0.5, 0.3, 0.8)
        end
        BuildZonesList()
        FauxScrollFrame_SetOffset(ListPanel.scroll, 0)
        local zbar = _G[ListPanel.scroll:GetName() .. "ScrollBar"]
        if zbar then zbar:SetValue(0) end
        addon:UpdateListRows()
        if addon.RefreshZonesMap then addon:RefreshZonesMap() end
    end
    addon.UpdateZoneFactionFilterUI = UpdateZoneFactionFilterUI

    btnAlliance:SetScript("OnClick", function()
        selectedZoneFactionFilter = "Alliance"
        UpdateZoneFactionFilterUI()
    end)
    btnHorde:SetScript("OnClick", function()
        selectedZoneFactionFilter = "Horde"
        UpdateZoneFactionFilterUI()
    end)
    btnBoth:SetScript("OnClick", function()
        selectedZoneFactionFilter = "Both"
        UpdateZoneFactionFilterUI()
    end)

    -- Listado Faux Scrollable — Los botones son hijos DIRECTOS del scroll frame
    -- (FauxScrollFrame no necesita scrollContent; el offset se usa en RefreshList)
    local listScroll = CreateFrame("ScrollFrame", "SKquestsListFauxScroll", ListPanel, "FauxScrollFrameTemplate")
    listScroll:SetPoint("TOPLEFT", ListPanel, "TOPLEFT", 6, -66)
    listScroll:SetPoint("BOTTOMRIGHT", ListPanel, "BOTTOMRIGHT", -24, 6)
    ListPanel.scroll = listScroll

    -- scrollContent dummy requerido por FauxScrollFrame como ScrollChild
    local scrollContent = CreateFrame("Frame", nil, listScroll)
    scrollContent:SetSize(230, ROW_H)  -- tamaño mínimo
    listScroll:SetScrollChild(scrollContent)

    -- Crear los row buttons reutilizables — anclados al listScroll directamente
    -- Confirmacion para abandonar misiones desde el Quest Log (clic derecho).
    StaticPopupDialogs["SKQUESTS_ABANDON"] = {
        text = "Abandon quest \"%s\"?",
        button1 = YES,
        button2 = NO,
        OnAccept = function(_, data)
            local idx = data and data.idx
            if not idx then return end
            -- Revalidar por nombre: si el registro de misiones cambio mientras el
            -- popup estaba abierto, el indice podria apuntar a otra mision.
            if data.title and GetQuestLogTitle then
                local t = GetQuestLogTitle(idx)
                if t ~= data.title then
                    idx = nil
                    local n = (GetNumQuestLogEntries and GetNumQuestLogEntries()) or 0
                    for i = 1, n do
                        local ti, _, _, isHeader = GetQuestLogTitle(i)
                        if not isHeader and ti == data.title then idx = i; break end
                    end
                end
            end
            if not idx then return end
            SelectQuestLogEntry(idx)
            SetAbandonQuest()
            if type(AbandonQuest) == "function" then AbandonQuest() end
            selectedQuestLogIdx = nil
            selectedQuestId = nil
            if addon.RefreshList then addon:RefreshList() end
            if addon.RefreshMiniTracker then addon:RefreshMiniTracker() end
            if addon.RefreshDetail then addon:RefreshDetail() end
        end,
        timeout = 0,
        whileDead = 1,
        hideOnEscape = 1,
        preferredIndex = 3,
    }

    listButtons = {}
    for i = 1, MAX_ROWS do
        local btn = CreateFrame("Button", nil, listScroll)
        btn:SetSize(230, ROW_H)
        btn:SetPoint("TOPLEFT", 0, -(i - 1) * ROW_H)
        btn:RegisterForClicks("LeftButtonUp", "RightButtonUp")
        SKQ_EnsureBackdrop(btn)
        btn:SetBackdrop({
            bgFile = "Interface\\ChatFrame\\ChatFrameBackground",
            edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
            edgeSize = 8, insets = {left=2, right=2, top=2, bottom=2}
        })
        btn:SetBackdropColor(0,0,0,0)
        btn:SetBackdropBorderColor(0,0,0,0)

        -- Punto verde / estado
        local dot = btn:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
        dot:SetPoint("LEFT", 6, 0)
        dot:SetTextColor(0.2, 0.9, 0.2)
        btn.dot = dot

        -- Icono opcional
        local icon = btn:CreateTexture(nil, "OVERLAY")
        icon:SetSize(14, 14)
        icon:SetPoint("LEFT", 6, 0)
        btn.icon = icon

        -- Título del item
        local text = btn:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
        text:SetPoint("LEFT", 22, 0)
        text:SetWidth(150)
        text:SetJustifyH("LEFT")
        text:SetWordWrap(false)
        btn.txt = text

        -- Nivel de la quest / contador
        local lvl = btn:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
        lvl:SetPoint("RIGHT", -8, 0)
        lvl:SetTextColor(0.8, 0.6, 0.4)
        btn.lvl = lvl

        -- Indicador de riesgo Hardcore (punto de color, a la izquierda del nivel)
        local riskDot = btn:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
        riskDot:SetPoint("RIGHT", lvl, "LEFT", -4, 0)
        btn.risk = riskDot

        btn:SetScript("OnEnter", function(self)
            local isSel = false
            if activeTab == "quests" then
                isSel = (self.itemId == selectedQuestId)
            elseif activeTab == "questlog" then
                isSel = (self.itemId == selectedQuestLogIdx)
            elseif activeTab == "guide" then
                isSel = (self.itemId == selectedGuideChapter)
            elseif activeTab == "zones" then
                isSel = (self.zoneName == selectedZoneFilter)
            end
            if not isSel then
                self:SetBackdropColor(C.bgHover[1], C.bgHover[2], C.bgHover[3], 0.6)
            end
            -- Tooltip de riesgo Hardcore con el desglose de puntos
            if activeTab == "quests" and self.itemId and SKquests.GetQuestRisk then
                local q = SKquests_DetailDB[self.itemId]
                if q then
                    local zoneName = q.zoneId and GetZoneName(q.zoneId)
                    local score, label, color, reasons = SKquests:GetQuestRisk(q, zoneName)
                    GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
                    GameTooltip:AddLine((IsSpanish() and "Riesgo Hardcore: " or "Hardcore Risk: ")
                        .. "|cff" .. color .. label .. "|r (" .. score .. ")")
                    if reasons and #reasons > 0 then
                        for _, r in ipairs(reasons) do
                            GameTooltip:AddLine(r.t, 0.9, 0.9, 0.9, true)
                        end
                    else
                        GameTooltip:AddLine(IsSpanish() and "Sin factores de riesgo detectados"
                            or "No risk factors detected", 0.6, 0.6, 0.6)
                    end
                    GameTooltip:Show()
                end
            elseif activeTab == "questlog" and self.itemId then
                -- Sugerencia: el quest log permite abandonar con clic derecho
                GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
                GameTooltip:AddLine(IsSpanish() and "Clic derecho: abandonar misión"
                    or "Right-click: abandon quest", 1, 0.82, 0)
                GameTooltip:Show()
            end
        end)
        btn:SetScript("OnLeave", function(self)
            GameTooltip:Hide()
            local isSel = false
            if activeTab == "quests" then
                isSel = (self.itemId == selectedQuestId)
            elseif activeTab == "questlog" then
                isSel = (self.itemId == selectedQuestLogIdx)
            elseif activeTab == "guide" then
                isSel = (self.itemId == selectedGuideChapter)
            elseif activeTab == "zones" then
                isSel = (self.zoneName == selectedZoneFilter)
            end
            if not isSel then
                self:SetBackdropColor(0, 0, 0, 0)
            end
        end)
        btn:SetScript("OnClick", function(self, button)
            if button == "RightButton" then
                -- Clic derecho en el Quest Log: abandonar la mision (con confirmacion)
                if activeTab == "questlog" and self.itemId then
                    local cache = addon.Tracker and addon.Tracker:GetActiveQuests()
                    local entry = cache and cache[self.itemId]
                    local qTitle = (entry and entry.title) or ""
                    StaticPopupDialogs["SKQUESTS_ABANDON"].text =
                        (IsSpanish() and "¿Abandonar la misión \"%s\"?" or "Abandon quest \"%s\"?")
                    StaticPopup_Show("SKQUESTS_ABANDON", qTitle, nil, { idx = self.itemId, title = qTitle })
                end
                return
            end
            if activeTab == "quests" then
                selectedQuestId = self.itemId
                addon:RefreshDetail()
            elseif activeTab == "questlog" then
                if not self.itemId then return end
                selectedQuestLogIdx = self.itemId
                local cache = addon.Tracker:GetActiveQuests()
                local entry = cache[self.itemId]
                selectedQuestId = nil
                if entry then
                    local nameL = entry.title:lower()
                    for id, q in pairs(SKquests_DetailDB) do
                        if q.name and q.name:lower() == nameL then
                            selectedQuestId = id
                            break
                        end
                    end
                end
                addon:RefreshDetail()
            elseif activeTab == "guide" then
                selectedGuideChapter = self.itemId
                BuildGuideChapters()
                local chData = guideChapters[selectedGuideChapter]
                if chData then selectedStepIdx = chData.startIndex end
                addon:UpdateListRows()
                addon:RefreshDetail()
            elseif activeTab == "zones" then
                selectedZoneFilter = self.zoneName
                local zid
                for _, z in ipairs(uniqueZones) do
                    if z.name == self.zoneName then zid = z.id; break end
                end
                -- Subzonas iniciales: tienen carpeta pero NO mapa nativo real
                -- (saldrían en café), así que se tratan como "sin mapa".
                local NO_MAP_FOLDER = {
                    Shadowglen=true, Northshire=true, Deathknell=true,
                    CampNarache=true, ValleyOfTrials=true, ColdridgeValley=true,
                }
                local folder = zid and GetZoneMapFolder(zid)
                if zid and ZonesMapPanel and folder and not NO_MAP_FOLDER[folder] then
                    -- Zona con mapa -> abrir su mapa
                    ZonesMapPanel.currentMapMode = "zone"
                    ZonesMapPanel.currentSelectedZoneId = zid
                    ZonesMapPanel.currentSelectedZoneName = self.zoneName
                    ZonesMapPanel.zoneZoom = 1
                    ZonesMapPanel.zoneOffX = 0
                    ZonesMapPanel.zoneOffY = 0
                    if ZonesMapPanel.UpdateContinentTabs then
                        ZonesMapPanel.UpdateContinentTabs()
                    end
                    PlaySound(SOUND.IG_MAINMENU_OPTION or 856)
                else
                    -- Dungeon / cueva (sin mapa de continente) -> ir a Quests filtrado
                    addon:SwitchTab("quests")
                    BuildFilteredQuestIds()
                    FauxScrollFrame_SetOffset(ListPanel.scroll, 0)
                    local zbar = _G[ListPanel.scroll:GetName() .. "ScrollBar"]
                    if zbar then zbar:SetValue(0) end
                    addon:UpdateListRows()
                end
            end
            addon:RefreshList()
            if ListPanel.RefreshZonePanel then ListPanel.RefreshZonePanel() end
        end)

        listButtons[i] = btn
    end

    listScroll:SetScript("OnShow", function() addon:UpdateListRows() end)
    ListPanel:SetScript("OnSizeChanged", function() addon:UpdateListRows() end)

    listScroll:SetScript("OnVerticalScroll", function(self, offset)
        FauxScrollFrame_OnVerticalScroll(self, offset, ROW_H, function()
            addon:RefreshList()
        end)
    end)

    -- ================================================================
    --  COLUMNA DERECHA — DETALLES (DETAILED INFO)
    -- ================================================================
    DetailPanel = CreateFrame("Frame", nil, f)
    DetailPanel:SetPoint("TOPLEFT", ListPanel, "TOPRIGHT", 6, 0)
    DetailPanel:SetPoint("BOTTOMLEFT", ListPanel, "BOTTOMRIGHT", 6, 0)
    DetailPanel:SetPoint("BOTTOMRIGHT", f, "BOTTOMRIGHT", -10, 10)
    ApplyBD(DetailPanel, C.bgDetail, C.borderDim, 8)

    -- ================================================================
    --  PANEL DE ATLAS / MAPA DEL MUNDO (ZONES MAP PANEL)
    -- ================================================================
    ZonesMapPanel = CreateFrame("Frame", nil, f)
    ZonesMapPanel:SetPoint("TOPLEFT", ListPanel, "TOPRIGHT", 6, 0)
    ZonesMapPanel:SetPoint("BOTTOMLEFT", ListPanel, "BOTTOMRIGHT", 6, 0)
    ZonesMapPanel:SetPoint("BOTTOMRIGHT", f, "BOTTOMRIGHT", -10, 10)
    ApplyBD(ZonesMapPanel, C.bgDetail, C.borderDim, 8)
    ZonesMapPanel:Hide()
    addon.ZonesMapPanel = ZonesMapPanel

    -- ================================================================
    --  PANEL DE LISTA DE ZONAS (3 columnas: Alianza / Horda / Neutral)
    --  Reemplaza al mapa del mundo. Clic en zona -> quests de esa zona.
    -- ================================================================
    do
    local ZonesListPanel = CreateFrame("Frame", nil, f)
    ZonesListPanel:SetPoint("TOPLEFT", ListPanel, "TOPLEFT", 0, 0)
    ZonesListPanel:SetPoint("BOTTOMLEFT", ListPanel, "BOTTOMLEFT", 0, 0)
    ZonesListPanel:SetPoint("BOTTOMRIGHT", f, "BOTTOMRIGHT", -10, 10)
    ApplyBD(ZonesListPanel, C.bgList, C.borderDim, 8)
    ZonesListPanel:Hide()
    addon.ZonesListPanel = ZonesListPanel

    local zlTitle = ZonesListPanel:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    zlTitle:SetPoint("TOPLEFT", 12, -10)
    zlTitle:SetText(IsSpanish() and "ZONAS" or "ZONES")
    zlTitle:SetTextColor(C.gold[1], C.gold[2], C.gold[3])

    -- BOTONES DE FILTRO DE CONTINENTE PARA LA LISTA DE ZONAS
    addon._zonesListContinentFilter = nil -- nil=Todos, 0=Dungeons, 1=Kal, 2=EK, 3=Out, 4=Nor
    
    local zlContFilterFrame = CreateFrame("Frame", nil, ZonesListPanel)
    zlContFilterFrame:SetPoint("TOPLEFT", zlTitle, "BOTTOMLEFT", 0, -8)
    zlContFilterFrame:SetSize(400, 22)
    
    local zlContBtns = {}
    local function SelectZlCont(c)
        addon._zonesListContinentFilter = c
        for _, b in ipairs(zlContBtns) do
            if b.c == c then
                b:SetBackdropColor(C.bgSelected[1], C.bgSelected[2], C.bgSelected[3], 0.95)
            else
                b:SetBackdropColor(0, 0, 0, 0.4)
            end
        end
        if addon.RefreshZonesListPanel then
            addon.RefreshZonesListPanel()
        end
    end
    
    local function CreateZlBtn(idx, c, text, w)
        local btn = CreateFrame("Button", nil, zlContFilterFrame)
        btn:SetSize(w, 20)
        btn.c = c
        if idx == 1 then
            btn:SetPoint("LEFT", zlContFilterFrame, "LEFT", 0, 0)
        else
            btn:SetPoint("LEFT", zlContBtns[idx-1], "RIGHT", 4, 0)
        end
        ApplyBD(btn, {0,0,0}, {0.4,0.4,0.4}, 4)
        local lbl = btn:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
        lbl:SetPoint("CENTER", 0, 0)
        lbl:SetText(text)
        btn.lbl = lbl
        btn:SetScript("OnClick", function() SelectZlCont(c) end)
        table.insert(zlContBtns, btn)
        return btn
    end
    
    CreateZlBtn(1, nil, IsSpanish() and "Todos" or "All", 50)
    CreateZlBtn(2, 0, IsSpanish() and "Dungeons" or "Instances", 70)
    CreateZlBtn(3, 1, "Kalimdor", 65)
    CreateZlBtn(4, 2, IsSpanish() and "Eastern Kingdoms" or "EK", 110)
    CreateZlBtn(5, -1, IsSpanish() and "Profesiones/Clases" or "Profs/Classes", 130)
    -- Iniciar visualmente el boton "Todos" (pero no disparar refresh para no romper el load inicial si no está listo)
    SelectZlCont(nil)

    local ZL_COLS = {
        { key = "alliance", label = IsSpanish() and "Alianza" or "Alliance", color = {0.30, 0.55, 1.0} },
        { key = "horde",    label = IsSpanish() and "Horda"   or "Horde",    color = {1.0, 0.30, 0.25} },
        { key = "neutral",  label = "Neutral",                               color = {1.0, 0.82, 0.0} },
    }

    local zlScroll = CreateFrame("ScrollFrame", "SKquestsZonesListScroll", ZonesListPanel)
    zlScroll:SetPoint("TOPLEFT", 8, -68)
    zlScroll:SetPoint("BOTTOMRIGHT", -8, 8)
    zlScroll:EnableMouseWheel(true)
    local zlChild = CreateFrame("Frame", nil, zlScroll)
    zlChild:SetSize(10, 10)
    zlScroll:SetScrollChild(zlChild)
    zlScroll:SetScript("OnMouseWheel", function(self, delta)
        local cur = self:GetVerticalScroll()
        local maxs = self:GetVerticalScrollRange()
        local new = cur - delta * 40
        if new < 0 then new = 0 elseif new > maxs then new = maxs end
        self:SetVerticalScroll(new)
    end)

    local zlColHeaders = {}
    local zlRowPools = { {}, {}, {} }

    local function ZL_BuildGrouped()
        local groups = { alliance = {}, horde = {}, neutral = {} }
        if not SKquests_DetailDB then return groups end
        local tmp = {}
        local cFilt = addon._zonesListContinentFilter
        
        for id, q in pairs(SKquests_DetailDB) do
            local zname = q.zoneId and GetZoneName(q.zoneId)
            if IsQuestEligible(id, q) and q.zoneId and zname and not zname:find("^Zona %d") then
                
                local passContFilter = true
                if cFilt ~= nil then
                    local zInfo = ZoneCoordinates[q.zoneId]
                    local zCont = zInfo and zInfo.continent
                    if cFilt == 0 then
                        passContFilter = (not zCont and q.zoneId > 0)
                    elseif cFilt == -1 then
                        passContFilter = (q.zoneId < 0)
                    else
                        passContFilter = (zCont == cFilt)
                    end
                end
                
                if passContFilter then
                    if not tmp[zname] then tmp[zname] = { name = zname, id = q.zoneId, a = 0, h = 0, n = 0 } end
                    local z = tmp[zname]
                    local fac = GetQuestFaction(id, q)
                    if fac == "Alliance" then z.a = z.a + 1
                    elseif fac == "Horde" then z.h = z.h + 1
                    else z.n = z.n + 1 end   -- "Both" = neutral (la pueden hacer ambas)
                end
            end
        end
        -- Una zona aparece en VARIAS columnas (se repite). Si tiene misiones
        -- especificas de Alianza va a Alianza; si tiene de Horda va a Horda; las
        -- neutrales suman a ambas. Solo cae en "Neutral" si NO tiene misiones de
        -- faccion (zonas como mazmorras/Rasganorte). Al hacer clic se filtra por
        -- esa faccion para mostrar solo lo jugable por ese bando.
        for name, z in pairs(tmp) do
            local hasA, hasH = z.a > 0, z.h > 0
            if hasA then
                table.insert(groups.alliance, { name = name, count = z.a + z.n, id = z.id, fac = "Alliance" })
            end
            if hasH then
                table.insert(groups.horde, { name = name, count = z.h + z.n, id = z.id, fac = "Horde" })
            end
            if not hasA and not hasH then
                table.insert(groups.neutral, { name = name, count = z.n, id = z.id, fac = "Both" })
            end
        end
        for _, arr in pairs(groups) do
            table.sort(arr, function(x, y) return x.name < y.name end)
        end
        return groups
    end

    function addon.RefreshZonesListPanel()
        local groups = ZL_BuildGrouped()
        local cols = { groups.alliance, groups.horde, groups.neutral }
        local W = zlScroll:GetWidth()
        if not W or W < 60 then W = ZonesListPanel:GetWidth() - 16 end
        zlChild:SetWidth(W)
        local gap = 12
        local colW = (W - gap * 2) / 3
        local rowH = 20
        local maxRows = 0
        for ci = 1, 3 do
            local arr = cols[ci]
            local pool = zlRowPools[ci]
            local colX = (ci - 1) * (colW + gap)

            local hdr = zlColHeaders[ci]
            if not hdr then
                hdr = zlChild:CreateFontString(nil, "OVERLAY", "GameFontNormal")
                hdr:SetJustifyH("LEFT")
                zlColHeaders[ci] = hdr
            end
            hdr:ClearAllPoints()
            hdr:SetPoint("TOPLEFT", colX + 6, -2)
            hdr:SetWidth(colW - 6)
            local cc = ZL_COLS[ci].color
            hdr:SetTextColor(cc[1], cc[2], cc[3])
            hdr:SetText(string.format("%s (%d)", ZL_COLS[ci].label, #arr))
            hdr:Show()

            for ri = 1, #arr do
                local data = arr[ri]
                local b = pool[ri]
                if not b then
                    b = CreateFrame("Button", nil, zlChild)
                    b:SetHeight(rowH)
                    local nm = b:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
                    nm:SetPoint("LEFT", 6, 0)
                    nm:SetJustifyH("LEFT")
                    b.nm = nm
                    local ct = b:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
                    ct:SetPoint("RIGHT", -6, 0)
                    ct:SetTextColor(0.65, 0.65, 0.65)
                    b.ct = ct
                    b:SetScript("OnEnter", function(self) self.nm:SetTextColor(1, 1, 1) end)
                    b:SetScript("OnLeave", function(self) self.nm:SetTextColor(0.90, 0.82, 0.60) end)
                    b:SetScript("OnClick", function(self)
                        selectedZoneFilter = self.zoneName
                        addon._questFactionFilter = self.facFilter or "Both"
                        if qFacBtn and qFacBtn.lbl then
                            qFacBtn.lbl:SetText((self.facFilter and self.facFilter ~= "Both") and self.facFilter or (IsSpanish() and "Facción" or "Faction"))
                        end
                        addon:SwitchTab("quests")
                        BuildFilteredQuestIds()
                        FauxScrollFrame_SetOffset(ListPanel.scroll, 0)
                        local zbar = _G[ListPanel.scroll:GetName() .. "ScrollBar"]
                        if zbar then zbar:SetValue(0) end
                        addon:UpdateListRows()
                        PlaySound(SOUND.IG_MAINMENU_OPTION or 856)
                    end)
                    pool[ri] = b
                end
                b:ClearAllPoints()
                b:SetPoint("TOPLEFT", colX, -(ri * rowH))
                b:SetWidth(colW)
                b.nm:SetWidth(colW - 38)
                b.nm:SetText(data.name)
                b.nm:SetTextColor(0.90, 0.82, 0.60)
                b.ct:SetText(data.count)
                b.zoneName = data.name
                b.facFilter = data.fac
                b:Show()
            end
            for ri = #arr + 1, #pool do pool[ri]:Hide() end
            if #arr > maxRows then maxRows = #arr end
        end
        zlChild:SetHeight((maxRows + 2) * rowH)
    end
    end -- do (ZonesListPanel scope)

    -- Map states
    ZonesMapPanel.currentMapMode = "continent" -- "continent" or "zone"
    ZonesMapPanel.currentSelectedZoneId = nil
    ZonesMapPanel.currentSelectedZoneName = ""
    ZonesMapPanel.zoneZoom = 1
    ZonesMapPanel.zoneOffX = 0
    ZonesMapPanel.zoneOffY = 0
    ZonesMapPanel.customZoneMap = false

    local MapClip = CreateFrame("ScrollFrame", nil, ZonesMapPanel)
    MapClip:SetPoint("TOPLEFT", ZonesMapPanel, "TOPLEFT", 12, -45)
    MapClip:SetPoint("BOTTOMRIGHT", ZonesMapPanel, "BOTTOMRIGHT", -12, 12)
    MapClip:EnableMouse(true)
    MapClip:EnableMouseWheel(true)
    ZonesMapPanel.MapClip = MapClip

    local MapCanvas = CreateFrame("Frame", nil, MapClip)
    MapCanvas:SetSize(480, 360) -- 4:3 Aspect Ratio (default)
    MapClip:SetScrollChild(MapCanvas)
    ZonesMapPanel.MapCanvas = MapCanvas

    -- Pools de pins declarados ANTES de RelayoutZonesMap/RefreshZonesMap para que
    -- esas funciones los capturen como upvalues (no como global nil -> ipairs(nil)).
    local mapPins, questPinsPool = {}, {}
    local activePinsCount, activeQuestPinsCount = 0, 0

    -- Resaltado de zona estilo AzerothHub: silueta nativa de WoW bajo el cursor.
    local zoneHL = MapCanvas:CreateTexture(nil, "OVERLAY")
    zoneHL:SetBlendMode("ADD")
    zoneHL:Hide()
    ZonesMapPanel.zoneHL = zoneHL
    local hoverZoneId, hoverZoneName, lastHLName
    local UpdateZoneHighlight  -- forward-declarada; se asigna tras los helpers

    -- Capas de detalle REVELADO de la zona (sub-áreas). Los tiles base son el
    -- pergamino "sin descubrir"; estas texturas con nombre se dibujan encima para
    -- mostrar el mapa completo (igual que el visor del detalle de quest, OV.Show).
    local ATLAS_MAP_W, ATLAS_MAP_H = 1002, 668
    local atlasOV = { pool = {}, count = 0 }
    function atlasOV.Get(idx)
        local t = atlasOV.pool[idx]
        if not t then
            t = MapCanvas:CreateTexture(nil, "ARTWORK")
            atlasOV.pool[idx] = t
        end
        return t
    end
    function atlasOV.Hide()
        for _, ov in ipairs(atlasOV.pool) do ov:Hide(); ov.relX = nil end
        atlasOV.count = 0
    end
    function atlasOV.Show(folder)
        atlasOV.Hide()
        local zoneData = SKquests_MapData and folder and SKquests_MapData[folder]
        if not zoneData then return end
        for texName, packed in pairs(zoneData) do
            local texW = packed % 1024
            local texH = math.floor(packed / 1024) % 1024
            local offX = math.floor(packed / 1048576) % 1024
            local offY = math.floor(packed / 1073741824) % 1024
            local numWide = math.ceil(texW / 256)
            local numTall = math.ceil(texH / 256)
            local base = "Interface\\WorldMap\\" .. folder .. "\\" .. texName
            for j = 1, numTall do
                local pxH, fileH
                if j < numTall then pxH, fileH = 256, 256
                else
                    pxH = texH % 256; if pxH == 0 then pxH = 256 end
                    fileH = 16; while fileH < pxH do fileH = fileH * 2 end
                end
                for k = 1, numWide do
                    local pxW, fileW
                    if k < numWide then pxW, fileW = 256, 256
                    else
                        pxW = texW % 256; if pxW == 0 then pxW = 256 end
                        fileW = 16; while fileW < pxW do fileW = fileW * 2 end
                    end
                    local idx = atlasOV.count + 1
                    local ov = atlasOV.Get(idx)
                    ov:SetTexture(base .. (((j - 1) * numWide) + k))
                    atlasOV.count = idx
                    ov:SetTexCoord(0, pxW / fileW, 0, pxH / fileH)
                    ov.relX = (offX + 256 * (k - 1)) / ATLAS_MAP_W
                    ov.relY = (offY + 256 * (j - 1)) / ATLAS_MAP_H
                    ov.relW = pxW / ATLAS_MAP_W
                    ov.relH = pxH / ATLAS_MAP_H
                    ov:Show()
                end
            end
        end
    end
    ZonesMapPanel.atlasOV = atlasOV

    -- 12 Tiles for map background (4 columns x 3 rows)
    local MapBGParts = {}
    for r = 1, 3 do
        for c = 1, 4 do
            local idx = (r - 1) * 4 + c
            local tile = MapCanvas:CreateTexture(nil, "BACKGROUND")
            MapBGParts[idx] = tile
        end
    end

    local continentTabFrame = CreateFrame("Frame", nil, ZonesMapPanel)
    continentTabFrame:SetPoint("TOPLEFT", ZonesMapPanel, "TOPLEFT", 12, -12)
    continentTabFrame:SetPoint("TOPRIGHT", ZonesMapPanel, "TOPRIGHT", -12, -12)
    continentTabFrame:SetHeight(30)

    local currentContinent = 1 -- 1 = Kalimdor, 2 = Eastern Kingdoms
    addon._zoneContinent = addon._zoneContinent or 1 -- 0=Dungeons 1=Kalimdor 2=EK

    local btnKalimdor = CreateFrame("Button", nil, continentTabFrame)
    btnKalimdor:SetSize(120, 22)
    btnKalimdor:SetPoint("TOPLEFT", 0, 0)
    ApplyBD(btnKalimdor, {0,0,0}, {0.5,0.4,0.3}, 8)
    local lblKalimdor = btnKalimdor:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    lblKalimdor:SetPoint("CENTER", 0, 0)
    RegLoc(lblKalimdor, "KALIMDOR")
    btnKalimdor.lbl = lblKalimdor

    local btnEK = CreateFrame("Button", nil, continentTabFrame)
    btnEK:SetSize(140, 22)
    btnEK:SetPoint("LEFT", btnKalimdor, "RIGHT", 8, 0)
    ApplyBD(btnEK, {0,0,0}, {0.5,0.4,0.3}, 8)
    local lblEK = btnEK:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    lblEK:SetPoint("CENTER", 0, 0)
    RegLoc(lblEK, "EASTERN_KINGDOMS")
    btnEK.lbl = lblEK

    local btnInstances = CreateFrame("Button", nil, continentTabFrame)
    btnInstances:SetSize(90, 22)
    btnInstances:SetPoint("LEFT", btnEK, "RIGHT", 6, 0)
    ApplyBD(btnInstances, {0,0,0}, {0.5,0.4,0.3}, 8)
    local lblInstances = btnInstances:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    lblInstances:SetPoint("CENTER", 0, 0)
    lblInstances:SetText(IsSpanish() and "Mazmorras" or "Dungeons")
    btnInstances.lbl = lblInstances

    -- Back button
    local backBtn = CreateFrame("Button", nil, ZonesMapPanel)
    backBtn:SetSize(80, 22)
    backBtn:SetPoint("TOPLEFT", ZonesMapPanel, "TOPLEFT", 12, -12)
    backBtn:SetFrameLevel(ZonesMapPanel:GetFrameLevel() + 50)
    ApplyBD(backBtn, {0,0,0}, {0.5,0.4,0.3}, 8)
    local backLbl = backBtn:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    backLbl:SetPoint("CENTER", 0, 0)
    backLbl:SetText(IsSpanish() and "Atrás" or "Back")
    backBtn.lbl = backLbl
    backBtn:Hide()
    ZonesMapPanel.backBtn = backBtn

    -- "No map available" label for instance/dungeon zones
    local noMapLbl = ZonesMapPanel:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    noMapLbl:SetPoint("CENTER", ZonesMapPanel, "CENTER", 0, 0)
    noMapLbl:SetText(IsSpanish() and "|cffaaaaaa(Sin mapa de zona)|r" or "|cffaaaaaa(No map available for this zone)|r")
    noMapLbl:Hide()
    ZonesMapPanel.noMapLabel = noMapLbl

    local function UpdateContinentTabs()
        if ZonesMapPanel.currentMapMode == "continent" then
            continentTabFrame:Show()
            backBtn:Hide()
            local prefix
            if currentContinent == 1 then
                prefix = "Interface\\WorldMap\\Kalimdor\\Kalimdor"
            else
                prefix = "Interface\\WorldMap\\Azeroth\\Azeroth"
            end
            ZonesMapPanel.customZoneMap = false
            for i = 1, 12 do
                MapBGParts[i]:SetTexture(prefix .. i)
            end
            local s = C.bgSelected
            local function hi(btn, active)
                if active then btn:SetBackdropColor(s[1], s[2], s[3], 0.95)
                else btn:SetBackdropColor(0, 0, 0, 0.4) end
            end
            hi(btnKalimdor,  currentContinent == 1)
            hi(btnEK,        currentContinent == 2)
            hi(btnInstances, currentContinent == 0)
        else
            continentTabFrame:Hide()
            backBtn:Show()
        end
        addon:RefreshZonesMap()
    end
    ZonesMapPanel.UpdateContinentTabs = UpdateContinentTabs

    local function SelectContinent(c)
        currentContinent = c
        addon._zoneContinent = c
        ZonesMapPanel.currentMapMode = "continent"
        UpdateContinentTabs()
        -- refrescar la LISTA de zonas filtrada por este continente
        BuildZonesList()
        if ListPanel.scroll then
            FauxScrollFrame_SetOffset(ListPanel.scroll, 0)
            local zbar = _G[ListPanel.scroll:GetName() .. "ScrollBar"]
            if zbar then zbar:SetValue(0) end
        end
        addon:UpdateListRows()
    end

    btnKalimdor:SetScript("OnClick", function() SelectContinent(1) end)
    btnEK:SetScript("OnClick", function() SelectContinent(2) end)
    btnInstances:SetScript("OnClick", function() SelectContinent(0) end)

    backBtn:SetScript("OnClick", function()
        ZonesMapPanel.currentMapMode = "continent"
        ZonesMapPanel.zoneZoom = 1
        ZonesMapPanel.zoneOffX = 0
        ZonesMapPanel.zoneOffY = 0
        UpdateContinentTabs()
        PlaySound(SOUND.IG_MAINMENU_OPTION or 856)
    end)

    -- Dynamic scaling of map canvas on resize (4:3 aspect ratio)
    ZonesMapPanel:SetScript("OnSizeChanged", function(self)
        local w = self:GetWidth() or 500
        local h = self:GetHeight() or 500
        local maxW = w - 24
        local maxH = h - 60
        
        local baseW = maxW
        local baseH = maxW * 0.75 -- 3 / 4
        
        if baseH > maxH then
            baseH = maxH
            baseW = maxH * 1.3333 -- 4 / 3
        end
        
        if baseW < 200 then baseW = 200; baseH = 150 end
        
        self.baseW = baseW
        self.baseH = baseH
        
        addon:RelayoutZonesMap()
    end)

    -- Sizing and layout positioning
    function addon:RelayoutZonesMap()
        local baseW = ZonesMapPanel.baseW or 480
        local baseH = ZonesMapPanel.baseH or 360
        
        -- Mismo método que el visor de mapa del detalle de quest (ImgLayout), que
        -- SÍ renderiza bien: aspecto real 1002x668, tiles de borde 234/156 y recorte
        -- del relleno con SetTexCoord. Antes el atlas estiraba todos a sizeW/4 x
        -- sizeH/3 sin recortar -> el mapa nativo salía mal ("sin revelar").
        local MAP_W, MAP_H = 1002, 668
        local s = (baseW / MAP_W) * ZonesMapPanel.zoneZoom
        local sizeW = MAP_W * s
        local sizeH = MAP_H * s
        MapCanvas:SetSize(sizeW, sizeH)

        if ZonesMapPanel.customZoneMap then
            local tile = MapBGParts[1]
            tile:SetSize(sizeW, sizeH)
            tile:ClearAllPoints()
            tile:SetPoint("TOPLEFT", MapCanvas, "TOPLEFT", 0, 0)
            tile:SetTexCoord(0, 1, 0, 1)
            tile:Show()
            for i = 2, 12 do
                MapBGParts[i]:Hide()
            end
        else
            for i = 1, 12 do
                local col = (i - 1) % 4
                local row = math.floor((i - 1) / 4)
                local tile = MapBGParts[i]
                local tw = (col == 3) and 234 or 256
                local th = (row == 2) and 156 or 256
                tile:SetSize(tw * s, th * s)
                tile:ClearAllPoints()
                tile:SetPoint("TOPLEFT", MapCanvas, "TOPLEFT", col * 256 * s, -row * 256 * s)
                tile:SetTexCoord(0, tw / 256, 0, th / 256)
                tile:Show()
            end
        end
        
        -- Enforce scroll boundaries
        local cw = MapClip:GetWidth() or 480
        local chh = MapClip:GetHeight() or 360
        local maxX = math.max(0, sizeW - cw)
        local maxY = math.max(0, sizeH - chh)
        if ZonesMapPanel.zoneOffX > maxX then ZonesMapPanel.zoneOffX = maxX end
        if ZonesMapPanel.zoneOffY > maxY then ZonesMapPanel.zoneOffY = maxY end
        if ZonesMapPanel.zoneOffX < 0 then ZonesMapPanel.zoneOffX = 0 end
        if ZonesMapPanel.zoneOffY < 0 then ZonesMapPanel.zoneOffY = 0 end
        MapClip:SetHorizontalScroll(ZonesMapPanel.zoneOffX)
        MapClip:SetVerticalScroll(ZonesMapPanel.zoneOffY)
        
        -- Position pins
        if ZonesMapPanel.currentMapMode == "continent" then
            for _, pin in ipairs(mapPins) do
                if pin.coords and pin:IsShown() then
                    pin:ClearAllPoints()
                    pin:SetPoint("CENTER", MapCanvas, "TOPLEFT", (pin.coords.x / 100) * sizeW, -(pin.coords.y / 100) * sizeH)
                end
            end
        else
            for _, pin in ipairs(questPinsPool) do
                if pin.relX and pin:IsShown() then
                    pin:ClearAllPoints()
                    pin:SetPoint("CENTER", MapCanvas, "TOPLEFT", pin.relX * sizeW, -pin.relY * sizeH)
                end
            end
        end

        -- Capas de detalle revelado de la zona (sub-áreas), mismo factor de escala
        for _, ov in ipairs(atlasOV.pool) do
            if ov.relX and ov:IsShown() then
                ov:ClearAllPoints()
                ov:SetPoint("TOPLEFT", MapCanvas, "TOPLEFT", ov.relX * sizeW, -(ov.relY * sizeH))
                ov:SetSize(ov.relW * sizeW, ov.relH * sizeH)
            end
        end
    end

    -- Scroll / Zoom / Drag events
    MapClip:SetScript("OnMouseWheel", function(self, delta)
        local old = ZonesMapPanel.zoneZoom
        ZonesMapPanel.zoneZoom = math.max(1, math.min(5, ZonesMapPanel.zoneZoom + delta * 0.25))
        if ZonesMapPanel.zoneZoom ~= old then
            local cw = MapClip:GetWidth() or 480
            local chh = MapClip:GetHeight() or 360
            local fz = ZonesMapPanel.zoneZoom / old
            ZonesMapPanel.zoneOffX = (ZonesMapPanel.zoneOffX + cw / 2) * fz - cw / 2
            ZonesMapPanel.zoneOffY = (ZonesMapPanel.zoneOffY + chh / 2) * fz - chh / 2
            addon:RelayoutZonesMap()
        end
    end)
    
    local zoneDragging, zoneDragMoved, zoneDragX, zoneDragY
    MapClip:SetScript("OnMouseDown", function(self, button)
        if button == "RightButton" then
            if ZonesMapPanel.currentMapMode == "zone" then
                ZonesMapPanel.currentMapMode = "continent"
                ZonesMapPanel.zoneZoom = 1
                ZonesMapPanel.zoneOffX = 0
                ZonesMapPanel.zoneOffY = 0
                UpdateContinentTabs()
                PlaySound(SOUND.IG_MAINMENU_OPTION or 856)
            end
        else
            zoneDragging = true
            zoneDragMoved = false
            zoneDragX, zoneDragY = GetCursorPosition()
        end
    end)
    
    MapClip:SetScript("OnMouseUp", function(self, button)
        if button ~= "RightButton" then
            local wasDrag = zoneDragMoved
            zoneDragging = false
            -- clic sin arrastre sobre el continente => abrir la zona resaltada
            if not wasDrag and ZonesMapPanel.currentMapMode == "continent" and hoverZoneId then
                ZonesMapPanel.currentMapMode = "zone"
                ZonesMapPanel.currentSelectedZoneId = hoverZoneId
                ZonesMapPanel.currentSelectedZoneName = hoverZoneName or ""
                ZonesMapPanel.zoneZoom = 1
                ZonesMapPanel.zoneOffX = 0
                ZonesMapPanel.zoneOffY = 0
                zoneHL:Hide(); lastHLName = nil
                if GameTooltip:IsOwned(MapClip) then GameTooltip:Hide() end
                UpdateContinentTabs()
                PlaySound(SOUND.IG_MAINMENU_OPTION or 856)
            end
        end
    end)

    MapClip:SetScript("OnUpdate", function(self)
        if zoneDragging then
            local x, y = GetCursorPosition()
            local sc = self:GetEffectiveScale() or 1
            local dx = (x - zoneDragX) / sc
            local dy = (y - zoneDragY) / sc
            if math.abs(dx) > 4 or math.abs(dy) > 4 then zoneDragMoved = true end
            if zoneDragMoved then
                ZonesMapPanel.zoneOffX = ZonesMapPanel.zoneOffX - dx
                ZonesMapPanel.zoneOffY = ZonesMapPanel.zoneOffY + dy
                zoneDragX, zoneDragY = x, y
                addon:RelayoutZonesMap()
            end
        end
        -- (Detección por cursor en el continente desactivada: UpdateMapHighlight
        --  devuelve la zona desfasada en este cliente. Las zonas se abren desde
        --  la lista izquierda, que resuelve el id de forma determinista.)
    end)

    -- Select and scroll to quest helper
    function addon:SelectQuestById(questId)
        selectedQuestId = questId
        local idx = nil
        for i, qid in ipairs(filteredQuestIds) do
            if qid == questId then
                idx = i
                break
            end
        end
        if idx then
            local visibleRows = 18
            local h = ListPanel.scroll:GetHeight()
            if h and h > 0 then
                visibleRows = math.min(MAX_ROWS, math.floor(h / ROW_H))
                if visibleRows < 1 then visibleRows = 18 end
            end
            local offset = math.max(0, idx - math.floor(visibleRows / 2))
            local maxOffset = math.max(0, #filteredQuestIds - visibleRows)
            if offset > maxOffset then offset = maxOffset end
            FauxScrollFrame_SetOffset(ListPanel.scroll, offset)
            local sbar = _G[ListPanel.scroll:GetName() .. "ScrollBar"]
            if sbar then sbar:SetValue(offset * ROW_H) end
        end
        addon:UpdateListRows()
        addon:RefreshDetail()
    end

    function addon:CollectSpawnCoords(kind, id, zoneId)
        local out = {}
        if not id then return out end
        
        if BronzebeardQuestChains and BronzebeardQuestChains[id] then
            local bq = BronzebeardQuestChains[id]
            local zID = SKquests_DetailDB[id] and SKquests_DetailDB[id].zoneId or 141
            if zID == zoneId then
                table.insert(out, {bq.x, bq.y, zID})
            end
            return out
        end
        
        local folder = GetZoneMapFolder(zoneId)
        local function OnThisMap(z)
            return z == zoneId or (folder and GetZoneMapFolder(z) == folder)
        end
        
        if kind == "object" then
            local o = GetObjectData(id)
            if o and o.coords then
                for _, c in ipairs(o.coords) do
                    if c[3] and OnThisMap(c[3]) then
                        table.insert(out, {c[1], c[2], c[3]})
                    end
                end
            end
            local sd = SKquests_SpawnData and SKquests_SpawnData.objects and SKquests_SpawnData.objects[id]
            if sd and sd.spawns then
                for z, sp in pairs(sd.spawns) do
                    if OnThisMap(z) then
                        for _, c in ipairs(sp) do
                            table.insert(out, {c[1], c[2], z})
                        end
                    end
                end
            end
        else
            local u = GetUnitData(id)
            if u and u.coords then
                for _, c in ipairs(u.coords) do
                    if c[3] and OnThisMap(c[3]) then
                        table.insert(out, {c[1], c[2], c[3]})
                    end
                end
            end
            local sd = SKquests_SpawnData and SKquests_SpawnData.npcs and SKquests_SpawnData.npcs[id]
            if sd and sd.spawns then
                for z, sp in pairs(sd.spawns) do
                    if OnThisMap(z) then
                        for _, c in ipairs(sp) do
                            table.insert(out, {c[1], c[2], z})
                        end
                    end
                end
            end
        end
        return out
    end

    local function CollectZoneQuests(zoneId)
        local list = {}
        if not SKquests_DetailDB then return list end
        local zoneFolder = GetZoneMapFolder(zoneId)
        
        for id, q in pairs(SKquests_DetailDB) do
            if IsQuestEligible(id, q) then
                local qZone = q.zoneId
                if qZone then
                    
                    if (qZone == zoneId) or (zoneFolder and GetZoneMapFolder(qZone) == zoneFolder) then
                        local fac = GetQuestFaction(id, q)
                        local matchFaction = false
                        if selectedZoneFactionFilter == "Both" then
                            matchFaction = true
                        elseif selectedZoneFactionFilter == "Alliance" then
                            matchFaction = (fac == "Alliance" or fac == "Both")
                        elseif selectedZoneFactionFilter == "Horde" then
                            matchFaction = (fac == "Horde" or fac == "Both")
                        end
                        
                        if matchFaction then
                            table.insert(list, { id = id, q = q, faction = fac })
                        end
                    end
                end
            end
        end
        return list
    end

    -- Resaltado de zona bajo el cursor usando el sistema nativo del WorldMap.
    -- Devuelve la silueta exacta de la zona (no una caja), la coloca sobre el
    -- lienzo y resuelve el id por cercanía al centro de la silueta.
    UpdateZoneHighlight = function()
        if not MapClip:IsMouseOver() then
            zoneHL:Hide(); lastHLName = nil; hoverZoneId = nil
            if GameTooltip:IsOwned(MapClip) then GameTooltip:Hide() end
            return
        end
        -- mantener el WorldMap en el continente correcto para UpdateMapHighlight
        if GetCurrentMapContinent() ~= currentContinent or (GetCurrentMapZone() or 0) ~= 0 then
            pcall(SetMapZoom, currentContinent)
        end
        local w, h = MapCanvas:GetWidth(), MapCanvas:GetHeight()
        if not w or w == 0 then return end
        local cx, cy = GetCursorPosition()
        local sc = MapCanvas:GetEffectiveScale() or 1
        cx, cy = cx / sc, cy / sc
        local nx = (cx - MapCanvas:GetLeft()) / w
        local ny = (MapCanvas:GetTop() - cy) / h
        if nx < 0 or nx > 1 or ny < 0 or ny > 1 then
            zoneHL:Hide(); lastHLName = nil; hoverZoneId = nil
            if GameTooltip:IsOwned(MapClip) then GameTooltip:Hide() end
            return
        end
        local ok, name, fileName, tpx, tpy, tx, ty = pcall(UpdateMapHighlight, nx, ny)
        if not ok or not name or not fileName then
            zoneHL:Hide(); lastHLName = nil; hoverZoneId = nil
            if GameTooltip:IsOwned(MapClip) then GameTooltip:Hide() end
            return
        end
        if name == lastHLName then return end  -- misma zona; ya está mostrada
        lastHLName = name

        -- silueta de la zona
        zoneHL:SetTexture("Interface\\WorldMap\\" .. fileName .. "\\" .. fileName)
        zoneHL:SetTexCoord(0, tpx, 0, tpy)
        zoneHL:ClearAllPoints()
        zoneHL:SetPoint("TOPLEFT", MapCanvas, "TOPLEFT", tx * w, -ty * h)
        zoneHL:SetWidth(tpx * w)
        zoneHL:SetHeight(tpy * h)

        -- id de la zona: traducir el nombre LOCALIZADO que devuelve el juego a
        -- nuestro areaID via pfDB (determinista). Antes fallaba por usar cercanía.
        if not addon._zoneNameToId then
            addon._zoneNameToId = {}
            local L0 = (GetLocale and GetLocale()) or "enUS"
            local loc = pfDB and pfDB["zones"] and (pfDB["zones"][L0] or pfDB["zones"]["enUS"] or pfDB["zones"]["esES"])
            if loc then for aid, nm in pairs(loc) do addon._zoneNameToId[nm] = aid end end
        end
        local best = addon._zoneNameToId[name]
        hoverZoneId = best
        hoverZoneName = name

        local z
        for _, uz in ipairs(uniqueZones) do if uz.id == best then z = uz; break end end
        local fr, fg, fb = 1.0, 0.82, 0.2
        if z then
            if z.faction == "Alliance" then fr, fg, fb = 0.35, 0.6, 1.0
            elseif z.faction == "Horde" then fr, fg, fb = 1.0, 0.35, 0.35 end
        end
        zoneHL:SetVertexColor(fr, fg, fb, 0.5)
        zoneHL:Show()

        -- tooltip con la lista de misiones de la zona
        GameTooltip:SetOwner(MapClip, "ANCHOR_RIGHT")
        GameTooltip:ClearLines()
        GameTooltip:AddLine(name, 1, 0.82, 0)
        if z then
            local minL, maxL = z.minL or 1, z.maxL or 60
            GameTooltip:AddLine(L("LEVELS") .. ": " .. minL .. " - " .. maxL, 1, 1, 1)
        end
        local zq = best and CollectZoneQuests(best) or {}
        if #zq > 0 then
            GameTooltip:AddLine(" ")
            GameTooltip:AddLine(IsSpanish() and "Misiones disponibles:" or "Available quests:", 1, 0.82, 0)
            local dc = math.min(15, #zq)
            for i = 1, dc do
                local q = zq[i].q
                local lv = tonumber(q.level) or 0
                GameTooltip:AddLine("- " .. GetLocalizedQuestName(q) .. (lv > 0 and (" (" .. lv .. ")") or ""), 0.9, 0.9, 0.9)
            end
            if #zq > dc then
                GameTooltip:AddLine(string.format(IsSpanish() and "... y %d más" or "... and %d more", #zq - dc), 0.5, 0.5, 0.5)
            end
        end
        GameTooltip:Show()
    end

    -- Pin pools (ya declarados arriba como upvalues; aquí solo se reinician)
    activePinsCount = 0
    mapPins = {}

    local function GetPinFrame()
        activePinsCount = activePinsCount + 1
        if not mapPins[activePinsCount] then
            local pin = CreateFrame("Button", nil, MapCanvas)
            pin:SetSize(20, 20)  -- zona de clic alrededor del marcador

            -- Marcador (punto) visible siempre, color por facción (WHITE8X8 = fiable y tintable)
            local dot = pin:CreateTexture(nil, "ARTWORK")
            dot:SetTexture("Interface\\Buttons\\WHITE8X8")
            dot:SetSize(10, 10)
            dot:SetPoint("CENTER")
            pin.dot = dot

            -- Borde negro fino del marcador (legibilidad sobre el mapa)
            local dotEdge = pin:CreateTexture(nil, "BORDER")
            dotEdge:SetTexture("Interface\\Buttons\\WHITE8X8")
            dotEdge:SetVertexColor(0, 0, 0, 0.9)
            dotEdge:SetSize(14, 14)
            dotEdge:SetPoint("CENTER")
            pin.dotEdge = dotEdge

            -- Resplandor (solo hover)
            local bgGlow = pin:CreateTexture(nil, "BACKGROUND")
            bgGlow:SetTexture("Interface\\Buttons\\WHITE8X8")
            bgGlow:SetPoint("CENTER")
            bgGlow:SetSize(26, 26)
            bgGlow:SetBlendMode("ADD")
            bgGlow:Hide()
            pin.bgGlow = bgGlow

            -- Nombre: SOLO al pasar el ratón (mapa limpio por defecto)
            local txtName = pin:CreateFontString(nil, "OVERLAY", "GameFontNormal")
            txtName:SetPoint("BOTTOM", pin, "TOP", 0, 2)
            txtName:SetJustifyH("CENTER")
            txtName:SetWordWrap(false)
            txtName:SetShadowColor(0, 0, 0, 1)
            txtName:SetShadowOffset(1.2, -1.2)
            txtName:Hide()
            pin.txtName = txtName

            pin:SetScript("OnEnter", function(self)
                local r, g, b = 1.0, 0.85, 0.3
                if self.faction == "Alliance" then r, g, b = 0.45, 0.75, 1.0
                elseif self.faction == "Horde" then r, g, b = 1.0, 0.45, 0.45 end
                self.txtName:SetText(self.zoneName)
                self.txtName:SetTextColor(r, g, b)
                self.txtName:Show()
                self.dot:SetSize(14, 14); self.dotEdge:SetSize(18, 18)
                self.dot:SetVertexColor(r, g, b, 1)
                self.bgGlow:SetVertexColor(r, g, b, 0.5)
                self.bgGlow:Show()

                GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
                GameTooltip:ClearLines()
                GameTooltip:AddLine(self.zoneName, 1, 0.82, 0, true)
                local minL, maxL = self.minL or 1, self.maxL or 60
                GameTooltip:AddLine(L("LEVELS") .. ": " .. minL .. " - " .. maxL, 1, 1, 1)
                
                local qTxt = IsSpanish() and "misiones" or "quests"
                GameTooltip:AddLine(tostring(self.count or 0) .. " " .. qTxt, 0.8, 0.8, 0.8)
                
                local facText = L("CONTESTED")
                local r, g, b = 0.9, 0.6, 0.1
                if self.faction == "Alliance" then
                    facText = L("ALLIANCE")
                    r, g, b = 0.3, 0.5, 0.9
                elseif self.faction == "Horde" then
                    facText = L("HORDE")
                    r, g, b = 0.9, 0.2, 0.2
                end
                GameTooltip:AddLine(facText, r, g, b)

                -- List quests in this zone
                GameTooltip:AddLine(" ")
                local zoneQuests = CollectZoneQuests(self.zoneId)
                if #zoneQuests > 0 then
                    local displayCount = math.min(15, #zoneQuests)
                    GameTooltip:AddLine(IsSpanish() and "Misiones disponibles:" or "Available quests:", 1, 0.82, 0)
                    for idx = 1, displayCount do
                        local q = zoneQuests[idx].q
                        local qName = GetLocalizedQuestName(q)
                        local qLvl = tonumber(q.level) or 0
                        local lvlStr = qLvl > 0 and (" (" .. qLvl .. ")") or ""
                        GameTooltip:AddLine("- " .. qName .. lvlStr, 0.9, 0.9, 0.9)
                    end
                    if #zoneQuests > displayCount then
                        local remaining = #zoneQuests - displayCount
                        local extraTxt = IsSpanish() and ("... y %d misiones más") or ("... and %d more quests")
                        GameTooltip:AddLine(string.format(extraTxt, remaining), 0.5, 0.5, 0.5)
                    end
                else
                    GameTooltip:AddLine(IsSpanish() and "No hay misiones disponibles" or "No quests available", 0.5, 0.5, 0.5)
                end
                
                GameTooltip:Show()
            end)

            pin:SetScript("OnLeave", function(self)
                self.txtName:Hide()
                self.dot:SetSize(10, 10); self.dotEdge:SetSize(14, 14)
                if self.baseR then self.dot:SetVertexColor(self.baseR, self.baseG, self.baseB, 1) end
                self.bgGlow:Hide()
                GameTooltip:Hide()
            end)

            pin:SetScript("OnClick", function(self)
                ZonesMapPanel.currentMapMode = "zone"
                ZonesMapPanel.currentSelectedZoneId = self.zoneId
                ZonesMapPanel.currentSelectedZoneName = self.zoneName
                ZonesMapPanel.zoneZoom = 1
                ZonesMapPanel.zoneOffX = 0
                ZonesMapPanel.zoneOffY = 0
                UpdateContinentTabs()
                PlaySound(SOUND.IG_MAINMENU_OPTION or 856)
            end)

            mapPins[activePinsCount] = pin
        end
        return mapPins[activePinsCount]
    end

    activeQuestPinsCount = 0
    questPinsPool = {}

    local function GetQuestPinFrame()
        activeQuestPinsCount = activeQuestPinsCount + 1
        if not questPinsPool[activeQuestPinsCount] then
            local pin = CreateFrame("Button", nil, MapCanvas)
            pin:SetSize(16, 16)
            
            local tex = pin:CreateTexture(nil, "OVERLAY")
            tex:SetAllPoints()
            pin.tex = tex
            
            local glow = pin:CreateTexture(nil, "BACKGROUND")
            glow:SetTexture("Interface\\AddOns\\SKquests\\Media\\circle.tga")
            glow:SetPoint("CENTER")
            glow:SetSize(22, 22)
            glow:SetBlendMode("ADD")
            pin.glow = glow
            
            local hl = pin:CreateTexture(nil, "HIGHLIGHT")
            hl:SetAllPoints()
            hl:SetTexture("Interface\\Buttons\\UI-Common-MouseHilight")
            hl:SetBlendMode("ADD")
            
            pin:SetScript("OnEnter", function(self)
                GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
                GameTooltip:ClearLines()
                GameTooltip:AddLine(self.questName, 1, 0.82, 0, true)
                GameTooltip:AddLine(L("LEVEL") .. ": " .. (self.level or "?"), 1, 1, 1)
                if self.giverName then
                    GameTooltip:AddLine(L("GIVER") .. ": " .. self.giverName, 0.8, 0.8, 0.8)
                end
                
                local facText = L("CONTESTED")
                local r, g, b = 0.9, 0.6, 0.1
                if self.faction == "Alliance" then
                    facText = L("ALLIANCE")
                    r, g, b = 0.3, 0.5, 0.9
                elseif self.faction == "Horde" then
                    facText = L("HORDE")
                    r, g, b = 0.9, 0.2, 0.2
                end
                GameTooltip:AddLine(facText, r, g, b)
                GameTooltip:Show()
            end)
            
            pin:SetScript("OnLeave", function(self)
                GameTooltip:Hide()
            end)
            
            pin:SetScript("OnClick", function(self)
                selectedQuestId = self.questId
                local _zn = ZonesMapPanel and ZonesMapPanel.currentSelectedZoneId and GetZoneName(ZonesMapPanel.currentSelectedZoneId)
                if _zn then selectedZoneFilter = _zn; BuildFilteredQuestIds() end
                addon:SwitchTab("quests")
                addon:SelectQuestById(self.questId)
                PlaySound(SOUND.IG_MAINMENU_OPTION or 856)
            end)
            
            questPinsPool[activeQuestPinsCount] = pin
        end
        return questPinsPool[activeQuestPinsCount]
    end

    function addon:RefreshZonesMap()
        for _, pin in ipairs(mapPins) do
            pin:Hide()
        end
        for _, pin in ipairs(questPinsPool) do
            pin:Hide()
        end
        activePinsCount = 0
        activeQuestPinsCount = 0

        if activeTab ~= "zones" then return end

        -- Las texturas NATIVAS del juego SÍ renderizan en este cliente (las
        -- ciudades lo confirman). Mis .tga propios no. Así que usamos siempre el
        -- mapa nativo (ruta de 12 tiles), que es lo que funciona.
        -- Solo unas pocas subzonas/Azshara carecen de mapa nativo propio: para
        -- esas caemos a su zona padre (CUSTOM_PARENT) y mostramos el mapa padre.
        -- En este cliente los mapas NATIVOS respetan la niebla (salen sin revelar
        -- si no exploraste la zona). Nuestros .tga salen SIEMPRE completos y SÍ
        -- renderizan (Azshara lo confirma; mismo formato que el resto). Por eso
        -- usamos .tga propio para toda zona que lo tenga, y nativo solo de respaldo.
        -- Nativo para todas (siempre se ven, con niebla donde no exploraste).
        -- Solo Azshara usa .tga (no tiene mapa nativo y su .tga sí renderiza).
        -- Cuando confirmemos por qué los .tga de base_maps no renderizan, se
        -- vuelven a añadir aquí para mapas completos sin niebla.
        local CUSTOM_TGA = { Azshara = true }  -- Azshara usa su .tga restaurado
        -- Instance/city zones that have no standard world-map tiles
        local NO_MAP_ZONES = {
            IcecrownCitadel=true, UtgardeKeep=true, UtgardePinnacle=true,
            TheNexus=true, Naxxramas=true, Ulduar=true, VaultOfArchavon=true,
            TrialOfTheCrusader=true, TheCullingOfStratholme=true,
            AuchenaiCrypts=true, CoilfangReservoir=true, BlackTemple=true,
            GruulsLair=true, MagistersTerrace=true, TheStockade=true,
            Gnomeregan=true, BlackrockDepths=true,
        }
        local function LoadZoneMapTextures(folder)
            ZonesMapPanel.customZoneMap = false
            if not folder then return false end
            if NO_MAP_ZONES[folder] then
                -- Instance zone: clear tiles and show no-map message
                for i = 1, 12 do MapBGParts[i]:SetTexture(nil) end
                if ZonesMapPanel.noMapLabel then
                    ZonesMapPanel.noMapLabel:Show()
                end
                return false
            end
            if ZonesMapPanel.noMapLabel then ZonesMapPanel.noMapLabel:Hide() end
            if CUSTOM_TGA[folder] then
                MapBGParts[1]:SetTexture("Interface\\AddOns\\SKquests\\Media\\Maps\\" .. folder .. ".tga")
                ZonesMapPanel.customZoneMap = true
                return true
            end
            local base = "Interface\\WorldMap\\" .. folder .. "\\" .. folder
            MapBGParts[1]:SetTexture(base .. "1")
            for i = 2, 12 do
                MapBGParts[i]:SetTexture(base .. i)
            end
            return true
        end

        if ZonesMapPanel.currentMapMode == "continent" then
            continentTabFrame:Show()
            backBtn:Hide()
            local prefix
            if currentContinent == 1 then
                prefix = "Interface\\WorldMap\\Kalimdor\\Kalimdor"
            else
                prefix = "Interface\\WorldMap\\Azeroth\\Azeroth"
            end
            ZonesMapPanel.customZoneMap = false
            for i = 1, 12 do
                MapBGParts[i]:SetTexture(prefix .. i)
            end
            local s = C.bgSelected
            local function hi(btn, active)
                if active then btn:SetBackdropColor(s[1], s[2], s[3], 0.95)
                else btn:SetBackdropColor(0, 0, 0, 0.4) end
            end
            hi(btnKalimdor,  currentContinent == 1)
            hi(btnEK,        currentContinent == 2)
            hi(btnInstances, currentContinent == 0)
            pcall(SetMapZoom, currentContinent)
            zoneHL:Hide(); lastHLName = nil; hoverZoneId = nil
            atlasOV.Hide()
        else
            continentTabFrame:Hide()
            backBtn:Show()

            local baseFolder = GetZoneMapFolder(ZonesMapPanel.currentSelectedZoneId)
            local zoneName = GetZoneName(ZonesMapPanel.currentSelectedZoneId)
            local customFolder = SKQ_Data and SKQ_Data.Maps and SKQ_Data.Maps[zoneName] and SKQ_Data.Maps[zoneName].mapName
            local folder = customFolder or baseFolder
            local loadedFolder = folder
            local usedMap = false
            if folder then
                usedMap = LoadZoneMapTextures(folder)
                if not usedMap then
                    local zd = pfDB and pfDB["zones"] and pfDB["zones"]["data"] and pfDB["zones"]["data"][ZonesMapPanel.currentSelectedZoneId]
                    local parent = zd and zd[1]
                    local pf = parent and GetZoneMapFolder(parent)
                    if pf then
                        usedMap = LoadZoneMapTextures(pf)
                        if usedMap then
                            ZonesMapPanel.currentSelectedZoneId = parent
                            loadedFolder = pf
                        end
                    end
                end
            end
            -- Dibujar las capas de detalle revelado (sub-áreas) sobre el pergamino
            -- base. Los .tga custom (Azshara) ya son completos -> sin capas.
            if usedMap and not ZonesMapPanel.customZoneMap then
                atlasOV.Show(loadedFolder)
            else
                atlasOV.Hide()
            end

            local quests = CollectZoneQuests(ZonesMapPanel.currentSelectedZoneId)
            local selZone = ZonesMapPanel.currentSelectedZoneId
            local function PlaceQuestPin(qid, q, faction, cx, cy)
                local pin = GetQuestPinFrame()
                pin.questId = qid
                pin.questName = GetLocalizedQuestName(q)
                pin.level = q.level
                pin.faction = faction
                if q.giverId then
                    pin.giverName = (q.giverType == "GO") and ObjectDisplayName(q.giverId) or UnitDisplayName(q.giverId)
                else
                    pin.giverName = nil
                end
                local isComplete = false
                local isActive, logIdx = addon.Tracker:IsActive(q.name)
                if isActive and addon.Tracker:IsComplete(logIdx) then
                    isComplete = true
                end
                if isComplete then
                    pin.tex:SetTexture("Interface\\GossipFrame\\ActiveQuestIcon")
                    pin.glow:SetVertexColor(0.2, 0.9, 0.2, 0.8)
                elseif isActive then
                    pin.tex:SetTexture("Interface\\GossipFrame\\IncompleteQuestIcon")
                    pin.glow:SetVertexColor(0.9, 0.9, 0.2, 0.8)
                else
                    pin.tex:SetTexture("Interface\\GossipFrame\\AvailableQuestIcon")
                    if faction == "Alliance" then
                        pin.glow:SetVertexColor(0.2, 0.5, 1.0, 0.8)
                    elseif faction == "Horde" then
                        pin.glow:SetVertexColor(1.0, 0.2, 0.2, 0.8)
                    else
                        pin.glow:SetVertexColor(1.0, 0.8, 0.2, 0.8)
                    end
                end
                pin.relX = cx / 100
                pin.relY = cy / 100
                pin:Show()
            end
            local calibPts, pinnedQ = {}, {}
            for _, entry in ipairs(quests) do
                local q = entry.q
                local kind = (q.giverType == "GO") and "object" or "npc"
                local coordsList = addon:CollectSpawnCoords(kind, q.giverId, selZone)
                if coordsList and #coordsList > 0 then
                    local coord = coordsList[1]
                    local cx, cy, cz = coord[1], coord[2], coord[3]
                    if cz and cz ~= selZone then
                        local czData = pfDB and pfDB["zones"] and pfDB["zones"]["data"] and pfDB["zones"]["data"][cz]
                        if czData and czData[1] == selZone and czData[2] and czData[4] then
                            local zw, zh, zx, zy = czData[2], czData[3], czData[4], czData[5]
                            cx = zx + (cx * zw / 100)
                            cy = zy + (cy * zh / 100)
                        end
                    end
                    PlaceQuestPin(entry.id, q, entry.faction, cx, cy)
                    pinnedQ[entry.id] = true
                    if q.poiX and q.poiY then
                        calibPts[#calibPts + 1] = { q.poiX, q.poiY, cx, cy }
                    end
                end
            end
            local ca, cb, cc, cd
            local nC = #calibPts
            if nC >= 2 then
                local sY, smX, sYmX, sYY = 0, 0, 0, 0
                local sX, smY, sXmY, sXX = 0, 0, 0, 0
                for _, t in ipairs(calibPts) do
                    local pX, pY, mX, mY = t[1], t[2], t[3], t[4]
                    sY = sY + pY; smX = smX + mX; sYmX = sYmX + pY * mX; sYY = sYY + pY * pY
                    sX = sX + pX; smY = smY + mY; sXmY = sXmY + pX * mY; sXX = sXX + pX * pX
                end
                local denY = nC * sYY - sY * sY
                local denX = nC * sXX - sX * sX
                if denY > 1e-6 or denY < -1e-6 then
                    ca = (nC * sYmX - sY * smX) / denY
                    cb = (smX - ca * sY) / nC
                end
                if denX > 1e-6 or denX < -1e-6 then
                    cc = (nC * sXmY - sX * smY) / denX
                    cd = (smY - cc * sX) / nC
                end
            end
            if ca and cc then
                for _, entry in ipairs(quests) do
                    local q = entry.q
                    if not pinnedQ[entry.id] and q.poiX and q.poiY then
                        local px = ca * q.poiY + cb
                        local py = cc * q.poiX + cd
                        if px >= 0 and px <= 100 and py >= 0 and py <= 100 then
                            PlaceQuestPin(entry.id, q, entry.faction, px, py)
                        end
                    end
                end
            end
        end
        addon:RelayoutZonesMap()
    end
    
    UpdateContinentTabs()

    -- ================================================================
    --  PANEL DE SELECCIÓN DE GUÍAS (rejilla de tarjetas, estilo Zonas)
    --  Se muestra al entrar a la pestaña "guide" cuando Pro está
    --  desbloqueado y aún no se eligió una guía (addon.selectedGuideKey == nil)
    -- ================================================================
    GuideCardsPanel = CreateFrame("Frame", nil, f)
    GuideCardsPanel:SetPoint("TOPLEFT", ListPanel, "TOPLEFT", 0, 0)
    GuideCardsPanel:SetPoint("BOTTOMRIGHT", f, "BOTTOMRIGHT", -10, 10)
    ApplyBD(GuideCardsPanel, C.bgList, C.borderDim, 8)
    GuideCardsPanel:Hide()
    addon.GuideCardsPanel = GuideCardsPanel

    local gcTitle = GuideCardsPanel:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    gcTitle:SetPoint("TOPLEFT", 16, -14)
    RegLoc(gcTitle, "CHOOSE_LEVELING_GUIDE")
    gcTitle:SetTextColor(C.gold[1], C.gold[2], C.gold[3])
    GuideCardsPanel.titleFS = gcTitle

    -- Metadatos de presentación por facción (autodetectado contra SKquests_Guides)
    local GUIDE_META = {
        Alliance = { label = "Alianza", color = {0.30, 0.50, 0.95}, levels = "1-60" },
        Horde    = { label = "Horda",   color = {0.90, 0.25, 0.25}, levels = "1-60" },
    }

    function addon:RefreshGuideCards()
        local panel = addon.GuideCardsPanel
        panel.cards = panel.cards or {}
        for _, c in ipairs(panel.cards) do c:Hide() end

        local keys = {}
        if SKquests_Guides then
            for k in pairs(SKquests_Guides) do table.insert(keys, k) end
        end
        table.sort(keys)

        local COLS, CW, CH, GAP = 2, 300, 84, 14
        for i, key in ipairs(keys) do
            local card = panel.cards[i]
            if not card then
                card = CreateFrame("Button", nil, panel)
                card:SetSize(CW, CH)
                local isCustom = C.textures and C.textures.bg and (C.textures.bg:find("SKquests") or C.textures.bg:find("Media"))
                ApplyBD(card, C.bgDetail, C.borderDim, 6)
                card:SetBackdropColor(C.bgDetail[1], C.bgDetail[2], C.bgDetail[3], isCustom and 0.15 or 0.98)
                card:SetBackdropBorderColor(C.borderDim[1], C.borderDim[2], C.borderDim[3], isCustom and 0.4 or 0.8)
                card.title = card:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
                card.title:SetPoint("TOPLEFT", 14, -12)
                card.fac = card:CreateFontString(nil, "OVERLAY", "GameFontNormal")
                card.fac:SetPoint("TOPLEFT", 14, -36)
                card.sub = card:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
                card.sub:SetPoint("BOTTOMLEFT", 14, 12)
                card:SetScript("OnEnter", function(self)
                    local isCustom = C.textures and C.textures.bg and (C.textures.bg:find("SKquests") or C.textures.bg:find("Media"))
                    self:SetBackdropColor(C.bgHover[1], C.bgHover[2], C.bgHover[3], isCustom and 0.35 or 1.0)
                end)
                card:SetScript("OnLeave", function(self)
                    local isCustom = C.textures and C.textures.bg and (C.textures.bg:find("SKquests") or C.textures.bg:find("Media"))
                    self:SetBackdropColor(C.bgDetail[1], C.bgDetail[2], C.bgDetail[3], isCustom and 0.15 or 0.98)
                end)
                panel.cards[i] = card
            end
            local row = math.floor((i - 1) / COLS)
            local col = (i - 1) % COLS
            card:ClearAllPoints()
            card:SetPoint("TOPLEFT", panel, "TOPLEFT", 16 + col * (CW + GAP), -44 - row * (CH + GAP))

            local meta = GUIDE_META[key] or { label = key, color = {0.8, 0.8, 0.8}, levels = "" }
            local guide = SKquests_Guides[key]
            local steps = (type(guide) == "table") and #guide or 0
            local localizedLabel = L(key:upper())
            card.title:SetText(localizedLabel)
            card.title:SetTextColor(C.white[1], C.white[2], C.white[3])
            card.fac:SetText(localizedLabel)
            card.fac:SetTextColor(meta.color[1], meta.color[2], meta.color[3])
            card.sub:SetText(("%s: %s  -  %d %s"):format(L("LEVELS"), meta.levels, steps, L("STEPS_LBL")))
            card.guideKey = key
            card:SetScript("OnClick", function(self)
                if addon.SetCurrentGuide then
                    addon:SetCurrentGuide(self.guideKey)
                else
                    addon.db = addon.db or {}
                    addon.db.currentGuide = self.guideKey
                end
                addon.selectedGuideKey = self.guideKey
                selectedGuideChapter = 1
                BuildGuideChapters()
                addon:SwitchTab("guide")
                addon:UpdateListRows()
                if addon.RefreshDetail then addon:RefreshDetail() end
            end)
            card:Show()
        end
    end

    -- ================================================================
    --  PANEL DE CANDADO PRO (pestaña "guide" cuando Pro está bloqueado)
    -- ================================================================
    GuideLockPanel = CreateFrame("Frame", nil, f)
    GuideLockPanel:SetPoint("TOPLEFT", ListPanel, "TOPLEFT", 0, 0)
    GuideLockPanel:SetPoint("BOTTOMRIGHT", f, "BOTTOMRIGHT", -10, 10)
    ApplyBD(GuideLockPanel, C.bgList, C.borderDim, 8)
    GuideLockPanel:Hide()
    addon.GuideLockPanel = GuideLockPanel

    local lockIcon = GuideLockPanel:CreateTexture(nil, "ARTWORK")
    lockIcon:SetTexture("Interface\\Buttons\\LockButton-Locked-Up")
    lockIcon:SetSize(64, 64)
    lockIcon:SetPoint("CENTER", 0, 50)

    local lockText = GuideLockPanel:CreateFontString(nil, "OVERLAY", "GameFontHighlightLarge")
    lockText:SetPoint("TOP", lockIcon, "BOTTOM", 0, -14)
    RegLoc(lockText, "PRO_GUIDES_LOCKED")
    lockText:SetTextColor(C.gold[1], C.gold[2], C.gold[3])
    GuideLockPanel.title = lockText

    local lockSub = GuideLockPanel:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    lockSub:SetPoint("TOP", lockText, "BOTTOM", 0, -8)
    RegLoc(lockSub, "PRO_UNLOCK_HINT")
    GuideLockPanel.sub = lockSub

    local unlockBtn = CreateFrame("Button", nil, GuideLockPanel, "UIPanelButtonTemplate")
    unlockBtn:SetSize(170, 26)
    unlockBtn:SetPoint("TOP", lockSub, "BOTTOM", 0, -18)
    RegLoc(unlockBtn, "UNLOCK_PRO")
    unlockBtn:SetScript("OnClick", function()
        if addon.RequestProCode then addon:RequestProCode("guides") end
    end)

    local dScroll = CreateFrame("ScrollFrame", "SKquestsDetailScroll", DetailPanel, "UIPanelScrollFrameTemplate")
    dScroll:SetPoint("TOPLEFT", DetailPanel, "TOPLEFT", 6, -6)
    dScroll:SetPoint("BOTTOMRIGHT", DetailPanel, "BOTTOMRIGHT", -26, 6)

    local dChild = CreateFrame("Frame", nil, dScroll)
    dChild:SetWidth(400)
    dChild:SetHeight(850)
    dScroll:SetScrollChild(dChild)
    DetailPanel.scroll = dScroll
    DetailPanel.child = dChild

    dScroll:SetScript("OnSizeChanged", function(self, w, h)
        if w > 0 then
            dChild:SetWidth(w - 12)
        end
    end)

    -- 1) Cabecera de Quest
    local detailHeader = CreateFrame("Frame", nil, dChild)
    detailHeader:SetPoint("TOPLEFT", dChild, "TOPLEFT", 4, -4)
    detailHeader:SetPoint("TOPRIGHT", dChild, "TOPRIGHT", -4, -4)
    detailHeader:SetHeight(60)
    dChild.header = detailHeader

    local qTitle = detailHeader:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    qTitle:SetPoint("TOPLEFT", 4, -4)
    qTitle:SetWidth(320)
    qTitle:SetJustifyH("LEFT")
    qTitle:SetTextColor(1, 0.82, 0)
    detailHeader.title = qTitle

    local qMeta = detailHeader:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    qMeta:SetPoint("TOPLEFT", qTitle, "BOTTOMLEFT", 0, -4)
    qMeta:SetTextColor(0.5, 0.5, 0.5)
    detailHeader.meta = qMeta

    local qLevel = detailHeader:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    qLevel:SetPoint("TOPRIGHT", -4, -4)
    qLevel:SetTextColor(1, 0.82, 0)
    detailHeader.level = qLevel

    detailHeader.trackBtn = CreateFrame("Button", nil, detailHeader, "UIPanelButtonTemplate")
    detailHeader.trackBtn:SetSize(75, 22)
    detailHeader.trackBtn:SetPoint("BOTTOMRIGHT", -4, 4)
    detailHeader.trackBtn:SetText(IsSpanish() and "Seguir" or "Track")
    detailHeader.trackBtn:Hide()

    detailHeader.shareNativeBtn = CreateFrame("Button", nil, detailHeader, "UIPanelButtonTemplate")
    detailHeader.shareNativeBtn:SetSize(80, 22)
    detailHeader.shareNativeBtn:SetPoint("RIGHT", detailHeader.trackBtn, "LEFT", -4, 0)
    detailHeader.shareNativeBtn:SetText(IsSpanish() and "Compartir" or "Share")
    detailHeader.shareNativeBtn:Hide()

    detailHeader.downBtn = CreateFrame("Button", nil, detailHeader, "UIPanelButtonTemplate")
    detailHeader.downBtn:SetSize(22, 22)
    detailHeader.downBtn:SetPoint("RIGHT", detailHeader.shareNativeBtn, "LEFT", -4, 0)
    detailHeader.downBtn:SetText("v")
    detailHeader.downBtn:Hide()

    detailHeader.upBtn = CreateFrame("Button", nil, detailHeader, "UIPanelButtonTemplate")
    detailHeader.upBtn:SetSize(22, 22)
    detailHeader.upBtn:SetPoint("RIGHT", detailHeader.downBtn, "LEFT", -2, 0)
    detailHeader.upBtn:SetText("^")
    detailHeader.upBtn:Hide()


    -- Ilustración de Quest (Ilustración superior)
    -- ---- VISOR DE MAPA / ILUSTRACIÓN INTERACTIVO ----
    -- Rueda: zoom · Arrastrar: desplazar · Clic: restablecer.
    -- El zoom ocurre DENTRO del recuadro (clip), así el resto del detalle
    -- nunca se mueve aunque se agrande la imagen.
    local questImgBox = CreateFrame("Frame", nil, dChild)
    questImgBox:SetHeight(220)
    SKQ_EnsureBackdrop(questImgBox)
    questImgBox:SetBackdrop({
        bgFile = "Interface\\ChatFrame\\ChatFrameBackground",
        edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
        edgeSize = 8, insets = {left=2, right=2, top=2, bottom=2}
    })
    questImgBox:SetBackdropColor(0,0,0,0.5)
    questImgBox:SetBackdropBorderColor(0.5,0.4,0.3,0.5)
    questImgBox:EnableMouse(true)
    questImgBox:EnableMouseWheel(true)

    -- Boton Inicio/Fin: alterna el mapa entre zona de inicio (giver) y fin (ender)
    local seBtn = CreateFrame("Button", nil, dChild)
    seBtn:SetFrameLevel(questImgBox:GetFrameLevel() + 40)
    seBtn:SetSize(210, 22)
    seBtn:SetPoint("TOPLEFT", questImgBox, "TOPLEFT", 6, -6)
    SKQ_EnsureBackdrop(seBtn)
    seBtn:SetBackdrop({ bgFile = "Interface\\ChatFrame\\ChatFrameBackground", edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border", edgeSize = 8, insets = {left=2,right=2,top=2,bottom=2} })
    seBtn:SetBackdropColor(0, 0, 0, 0.75)
    seBtn:SetBackdropBorderColor(1, 0.82, 0, 0.7)
    seBtn:SetHighlightTexture("Interface\\Buttons\\UI-Common-MouseHilight")
    local seTxt = seBtn:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    seTxt:SetPoint("LEFT", seBtn, "LEFT", 6, 0)
    seTxt:SetTextColor(1, 0.82, 0)
    seBtn.txt = seTxt
    seBtn:Hide()
    questImgBox.startEndArrow = seBtn
    questImgBox.startEndLbl = seTxt
    seBtn:SetScript("OnClick", function()
        questImgBox.showEnd = not questImgBox.showEnd
        if questImgBox.currentQuest then questImgBox:SetQuest(questImgBox.currentQuest) end
    end)

    local imgClip = CreateFrame("ScrollFrame", nil, questImgBox)
    imgClip:SetPoint("TOPLEFT", 3, -3)
    imgClip:SetPoint("BOTTOMRIGHT", -3, 3)

    local imgCanvas = CreateFrame("Frame", nil, imgClip)
    imgCanvas:SetSize(256, 256)
    imgClip:SetScrollChild(imgCanvas)

    local mapTiles = {}
    for i = 1, 12 do
        mapTiles[i] = imgCanvas:CreateTexture(nil, "ARTWORK")
        mapTiles[i]:Hide()
    end
    local flatTex = imgCanvas:CreateTexture(nil, "ARTWORK")
    flatTex:Hide()
    questImgBox.tex = flatTex -- compatibilidad

    -- Pins interactivos estilo Wowhead (inicio "!" / entrega "?")
    -- NUEVO: progreso en vivo del objetivo bajo el cursor (cuanto falta, ej "0/5")
    local function GetQuestObjectiveProgress(qid, label)
        if not qid then return nil end
        local active = addon.Tracker and addon.Tracker:GetActiveQuests()
        if not active then return nil end
        local entry
        for _, e in pairs(active) do
            if e.id == qid then entry = e; break end
        end
        if not entry then return nil end
        local objs = entry.objectives or {}
        if #objs == 0 then return nil end
        if #objs == 1 then return objs[1].text end
        -- Varios objetivos: intentar emparejar por el nombre del NPC/objeto del pin
        if label then
            local lo = label:lower()
            for _, obj in ipairs(objs) do
                if obj.text and obj.text:lower():find(lo, 1, true) then
                    return obj.text
                end
            end
        end
        -- Sin match claro: mostrar todos los objetivos de la quest
        local lines = {}
        for _, obj in ipairs(objs) do
            if obj.text then table.insert(lines, obj.text) end
        end
        return #lines > 0 and table.concat(lines, "\n") or nil
    end

    local pinPool = {}
    local function GetPin(idx)
        local pin = pinPool[idx]
        if not pin then
            pin = CreateFrame("Button", nil, imgCanvas)
            pin:SetSize(20, 20)
            pin.tex = pin:CreateTexture(nil, "OVERLAY")
            pin.tex:SetAllPoints(pin)
            pin:SetScript("OnEnter", function(self)
                GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
                GameTooltip:SetText(self.label or "", 1, 0.82, 0)
                if self.sub then GameTooltip:AddLine(self.sub, 1, 1, 1) end
                if self.questId then
                    local progress = GetQuestObjectiveProgress(self.questId, self.label)
                    if progress then
                        GameTooltip:AddLine(progress, 0.2, 1.0, 0.2, true)
                    end
                end
                GameTooltip:Show()
            end)
            pin:SetScript("OnLeave", function() GameTooltip:Hide() end)
            pin:SetScript("OnClick", function(self)
                if IsControlKeyDown() and self.category then
                    SKquestsDB.config.pinColors = SKquestsDB.config.pinColors or { kill=1, interact=1, gather=1 }
                    local idx = (SKquestsDB.config.pinColors[self.category] or 1) + 1
                    if idx > 6 then idx = 1 end
                    SKquestsDB.config.pinColors[self.category] = idx
                    if questImgBox.currentQuest then
                        questImgBox:SetQuest(questImgBox.currentQuest)
                    end
                    return
                end
                if self.label then
                    print("|cff33ff99SKquests|r: " .. self.label .. (self.sub and (" - " .. self.sub) or ""))
                end
            end)
            pinPool[idx] = pin
        end
        return pin
    end

    -- Marcador "tu posicion" (jugador) en el mapa interactivo. Solo se
    -- muestra cuando el jugador esta fisicamente en la zona mostrada.
    local playerPin = CreateFrame("Frame", nil, imgCanvas)
    playerPin:SetSize(14, 14)
    playerPin:Hide()
    playerPin:SetFrameLevel(imgCanvas:GetFrameLevel() + 10)
    local playerPinGlow = playerPin:CreateTexture(nil, "ARTWORK")
    playerPinGlow:SetPoint("CENTER")
    playerPinGlow:SetSize(28, 28)
    playerPinGlow:SetTexture("Interface\\AddOns\\SKquests\\Media\\circle.tga")
    playerPinGlow:SetVertexColor(0.25, 0.65, 1.0, 0.35)
    playerPinGlow:SetBlendMode("ADD")
    local playerPinTex = playerPin:CreateTexture(nil, "OVERLAY")
    playerPinTex:SetAllPoints(playerPin)
    playerPinTex:SetTexture("Interface\\AddOns\\SKquests\\Media\\circle.tga")
    playerPinTex:SetVertexColor(0.35, 0.75, 1.0, 1)
    playerPinTex:SetBlendMode("ADD")
    playerPin:EnableMouse(true)
    playerPin:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        GameTooltip:SetText(IsSpanish() and "Tu posición" or "Your position", 0.35, 0.75, 1)
        GameTooltip:Show()
    end)
    playerPin:SetScript("OnLeave", function() GameTooltip:Hide() end)

    local imgMode = "flat"
    local customMap = false
    local imgZoom = 1
    local imgOffX, imgOffY = 0, 0
    local MAP_W, MAP_H = 1002, 668

    -- ============================================================
    --  OVERLAYS COLOREADOS DE SUBZONAS (restaurado 2026-06-11)
    --  Datos: SKquests_MapData.lua
    --  Formato: valor = ancho + alto*2^10 + offsetX*2^20 + offsetY*2^30
    --  (espacio de mapa de 1002x668, mismo empaquetado que WorldMapOverlay)
    -- ============================================================
    local OV = { pool = {}, count = 0 }

    function OV.Get(idx)
        local tex = OV.pool[idx]
        if not tex then
            tex = imgCanvas:CreateTexture(nil, "OVERLAY")
            OV.pool[idx] = tex
        end
        return tex
    end

    function OV.Hide()
        for _, ov in ipairs(OV.pool) do ov:Hide(); ov.relX = nil end
        OV.count = 0
    end

    function OV.Show(folder)
        OV.count = 0
        local zoneData = SKquests_MapData and folder and SKquests_MapData[folder]
        if not zoneData then return end
        for texName, packed in pairs(zoneData) do
            local texW = packed % 1024
            local texH = math.floor(packed / 1024) % 1024
            local offX = math.floor(packed / 1048576) % 1024
            local offY = math.floor(packed / 1073741824) % 1024
            local numWide = math.ceil(texW / 256)
            local numTall = math.ceil(texH / 256)
            local base = "Interface\\WorldMap\\" .. folder .. "\\" .. texName
            for j = 1, numTall do
                local pxH, fileH
                if j < numTall then
                    pxH, fileH = 256, 256
                else
                    pxH = texH % 256
                    if pxH == 0 then pxH = 256 end
                    fileH = 16
                    while fileH < pxH do fileH = fileH * 2 end
                end
                for k = 1, numWide do
                    local pxW, fileW
                    if k < numWide then
                        pxW, fileW = 256, 256
                    else
                        pxW = texW % 256
                        if pxW == 0 then pxW = 256 end
                        fileW = 16
                        while fileW < pxW do fileW = fileW * 2 end
                    end
                    local idx = OV.count + 1
                    local ov = OV.Get(idx)
                    ov:SetTexture(base .. (((j - 1) * numWide) + k))
                    OV.count = idx
                    ov:SetTexCoord(0, pxW / fileW, 0, pxH / fileH)
                    ov.relX = (offX + 256 * (k - 1)) / MAP_W
                    ov.relY = (offY + 256 * (j - 1)) / MAP_H
                    ov.relW = pxW / MAP_W
                    ov.relH = pxH / MAP_H
                    ov:Show()
                end
            end
        end
    end

    local function ImgLayout()
        local cw = imgClip:GetWidth()
        local chh = imgClip:GetHeight()
        if not cw or cw < 1 then return end
        if imgMode == "map" then
            local s = (cw / MAP_W) * imgZoom
            imgCanvas:SetSize(MAP_W * s, MAP_H * s)
            if customMap then
                local t = mapTiles[1]
                t:SetSize(MAP_W * s, MAP_H * s)
                t:ClearAllPoints()
                t:SetPoint("TOPLEFT", imgCanvas, "TOPLEFT", 0, 0)
                t:SetTexCoord(0, 1, 0, 1)
            else
                for i = 1, 12 do
                    local col = (i - 1) % 4
                    local row = math.floor((i - 1) / 4)
                    local t = mapTiles[i]
                    local tw = (col == 3) and 234 or 256
                    local th = (row == 2) and 156 or 256
                    t:SetSize(tw * s, th * s)
                    t:ClearAllPoints()
                    t:SetPoint("TOPLEFT", imgCanvas, "TOPLEFT", col * 256 * s, -row * 256 * s)
                    t:SetTexCoord(0, tw / 256, 0, th / 256)
                end
            end
        else
            imgCanvas:SetSize(cw * imgZoom, chh * imgZoom)
            flatTex:ClearAllPoints()
            flatTex:SetAllPoints(imgCanvas)
        end
        local maxX = math.max(0, imgCanvas:GetWidth() - cw)
        local maxY = math.max(0, imgCanvas:GetHeight() - chh)
        if imgOffX > maxX then imgOffX = maxX end
        if imgOffY > maxY then imgOffY = maxY end
        if imgOffX < 0 then imgOffX = 0 end
        if imgOffY < 0 then imgOffY = 0 end
        imgClip:SetHorizontalScroll(imgOffX)
        imgClip:SetVerticalScroll(imgOffY)
        local W, H = imgCanvas:GetWidth(), imgCanvas:GetHeight()
        for _, pin in ipairs(pinPool) do
            if pin.relX and pin:IsShown() then
                pin:ClearAllPoints()
                pin:SetPoint("CENTER", imgCanvas, "TOPLEFT", pin.relX * W, -pin.relY * H)
            end
        end
        -- Overlays coloreados: escalar y posicionar con el mismo factor del lienzo
        for _, ov in ipairs(OV.pool) do
            if ov.relX and ov:IsShown() then
                ov:ClearAllPoints()
                ov:SetPoint("TOPLEFT", imgCanvas, "TOPLEFT", ov.relX * W, -(ov.relY * H))
                ov:SetSize(ov.relW * W, ov.relH * H)
            end
        end
        -- Marcador del jugador: reposicionar con el mismo factor del lienzo
        if playerPin.relX and playerPin:IsShown() then
            playerPin:ClearAllPoints()
            playerPin:SetPoint("CENTER", imgCanvas, "TOPLEFT", playerPin.relX * W, -(playerPin.relY * H))
        end
    end
    questImgBox.Relayout = ImgLayout

    -- Actualiza la posicion del marcador del jugador: solo visible si esta
    -- fisicamente parado en la misma zona que el mapa interactivo mostrado.
    local playerPinElapsed = 0
    local function UpdatePlayerPin()
        local zoneId = _G.SKquests_UI_CurrentMapZone
        local realZone = GetRealZoneText and GetRealZoneText()
        local hereId = realZone and realZone ~= "" and SKQ_ResolveZoneIdFromRealZone(realZone)
        if not zoneId or not hereId or tostring(hereId) ~= tostring(zoneId) then
            playerPin.relX, playerPin.relY = nil, nil
            playerPin:Hide()
            return
        end
        local px, py
        if addon.GetPlayerMapCoords then px, py = addon:GetPlayerMapCoords() end
        if not px or not py then
            playerPin:Hide()
            return
        end
        playerPin.relX, playerPin.relY = px / 100, py / 100
        local cW, cH = imgCanvas:GetWidth(), imgCanvas:GetHeight()
        playerPin:ClearAllPoints()
        playerPin:SetPoint("CENTER", imgCanvas, "TOPLEFT", playerPin.relX * cW, -(playerPin.relY * cH))
        playerPin:Show()
    end
    questImgBox:SetScript("OnSizeChanged", ImgLayout)

    questImgBox:SetScript("OnMouseWheel", function(self, delta)
        local old = imgZoom
        imgZoom = math.max(1, math.min(3, imgZoom + delta * 0.25))
        if imgZoom ~= old then
            local cw, chh = imgClip:GetWidth(), imgClip:GetHeight()
            local fz = imgZoom / old
            imgOffX = (imgOffX + cw / 2) * fz - cw / 2
            imgOffY = (imgOffY + chh / 2) * fz - chh / 2
            ImgLayout()
        end
    end)

    local imgDragging, imgDragMoved, imgDragX, imgDragY
    questImgBox:SetScript("OnMouseDown", function(self)
        imgDragging = true; imgDragMoved = false
        imgDragX, imgDragY = GetCursorPosition()
    end)
    questImgBox:SetScript("OnMouseUp", function(self)
        imgDragging = false
        if not imgDragMoved then
            imgZoom = 1; imgOffX = 0; imgOffY = 0
            ImgLayout()
        end
    end)
    questImgBox:SetScript("OnUpdate", function(self, elapsed)
        if self.needsLayout and imgClip:GetWidth() and imgClip:GetWidth() > 1 then
            self.needsLayout = false
            ImgLayout()
        end
        playerPinElapsed = playerPinElapsed + (elapsed or 0)
        if playerPinElapsed >= 1 then
            playerPinElapsed = 0
            UpdatePlayerPin()
        end
        if not imgDragging then return end
        local x, y = GetCursorPosition()
        local sc = self:GetEffectiveScale()
        local dx = (x - imgDragX) / sc
        local dy = (y - imgDragY) / sc
        if math.abs(dx) > 4 or math.abs(dy) > 4 then imgDragMoved = true end
        if imgDragMoved then
            imgOffX = imgOffX - dx
            imgOffY = imgOffY + dy
            imgDragX, imgDragY = x, y
            ImgLayout()
        end
    end)

    questImgBox:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_TOPRIGHT")
        GameTooltip:SetText(L and L("MAP_HINT") or "", 1, 1, 1)
        GameTooltip:Show()
    end)
    questImgBox:SetScript("OnLeave", function() GameTooltip:Hide() end)

    function questImgBox:SetQuest(q)
        if questImgBox.currentQuest ~= q then
            imgZoom = 1; imgOffX = 0; imgOffY = 0
            questImgBox.showEnd = false
        end
        questImgBox.currentQuest = q
        for _, pin in ipairs(pinPool) do pin:Hide(); pin.relX = nil; pin.category = nil end
        OV.Hide()
        local function NpcZone(npcId)
            local u = GetUnitData(npcId)
            local c = u and u.coords and u.coords[1]
            return c and c[3]
        end

        -- Obtener la zona de inicio (usando la del Giver NPC si es posible, o cayendo al zoneId de la quest)
        local mapZone = (q and q.giverId) and NpcZone(q.giverId) or nil
        
        local function ResolveFolder(zId)
            if not zId then return nil end
            local zName = GetZoneName(zId)
            local liveData = zName and SKQ_Data and SKQ_Data.Maps and SKQ_Data.Maps[zName]
            if liveData and liveData.mapName then
                return liveData.mapName
            end
            return GetZoneMapFolder(zId)
        end

        local folder = ResolveFolder(mapZone)
        if not folder then
            mapZone = q and q.zoneId
            folder = ResolveFolder(mapZone)
        end
        if not folder then
            mapZone = (q and q.enderId) and NpcZone(q.enderId) or nil
            folder = ResolveFolder(mapZone)
        end
        
        local originalMapZone = mapZone
        _G.SKquests_UI_CurrentMapZone = mapZone
        UpdatePlayerPin()

        -- Inicio/Fin: alternar a la zona del ender si se apreto la flecha
        local _endZone = (q and q.enderId) and NpcZone(q.enderId) or nil
        local _hasTwo = mapZone and _endZone and _endZone ~= mapZone and ResolveFolder(_endZone)
        
        if _hasTwo and questImgBox.showEnd then
            mapZone = _endZone
            originalMapZone = _endZone
            folder = ResolveFolder(_endZone)
            _G.SKquests_UI_CurrentMapZone = mapZone
        end
        
        if questImgBox.startEndArrow then
            if _hasTwo then
                questImgBox.startEndArrow:Show()
                questImgBox.startEndLbl:Show()
                questImgBox.startEndLbl:SetText((questImgBox.showEnd and (IsSpanish() and "Fin: " or "End: ") or (IsSpanish() and "Inicio: " or "Start: ")) .. (GetZoneName(mapZone) or "") .. (IsSpanish() and "  (clic: cambiar)" or "  (click: switch)"))
            else
                questImgBox.startEndArrow:Hide()
                questImgBox.startEndLbl:Hide()
            end
        end

        local usedMap = false
        customMap = false
        -- Mapas custom que SÍ existen en Media\Maps (lista blanca determinista).
        -- En este cliente SetTexture() devuelve verdadero aunque el archivo no
        -- exista, así que no podemos confiar en su retorno: usamos la lista.
        local CUSTOM_MAP_FILES = {
            Shadowglen = true, Northshire = true, Deathknell = true,
            CampNarache = true, ValleyOfTrials = true, ColdridgeValley = true,
            Azshara = true,
        }
        local function TryCustomMap(fld)
            if not fld or not CUSTOM_MAP_FILES[fld] then return false end
            local basePath = "Interface\\AddOns\\SKquests\\Media\\Maps\\" .. fld
            mapTiles[1]:SetTexture(basePath .. ".tga")
            customMap = true
            return true
        end

        -- Intenta la carpeta de la zona (estándar de WoW)
        local function TryFolder(fld)
            if not fld then return false end
            if TryCustomMap(fld) then return true end
            local base = "Interface\\WorldMap\\" .. fld .. "\\" .. fld
            if mapTiles[1]:SetTexture(base .. "1") then
                for i = 2, 12 do mapTiles[i]:SetTexture(base .. i) end
                return true
            end
            return false
        end
        if folder then
            usedMap = TryFolder(folder)
            if not usedMap then
                -- La subzona no tiene textura propia (p. ej. Shadowglen).
                -- Mostramos el mapa de la zona PADRE y reasignamos mapZone al
                -- padre: así zData queda nulo y los pins se colocan en
                -- coordenadas del padre, sin la traducción a subzona.
                local zd = pfDB and pfDB["zones"] and pfDB["zones"]["data"] and pfDB["zones"]["data"][mapZone]
                local parent = zd and zd[1]
                local pf = parent and GetZoneMapFolder(parent)
                if pf and TryFolder(pf) then
                    usedMap = true
                    mapZone = parent
                    folder = pf
                end
            end
        end
        if usedMap then
            imgMode = "map"
            if customMap then
                mapTiles[1]:Show()
                for i = 2, 12 do mapTiles[i]:Hide() end
            else
                for i = 1, 12 do mapTiles[i]:Show() end
            end
            flatTex:Hide()
            OV.Show(folder)
            local nPin = 0
            local PIN_BUDGET = 160

            local originalZData = pfDB and pfDB["zones"] and pfDB["zones"]["data"] and pfDB["zones"]["data"][originalMapZone]
            local expectedParent = originalZData and originalZData[1]
            
            -- AUTO ZOOM ELIMINADO (El usuario prefiere el mapa padre sin zoom o usar custom maps)

            -- Reúne coordenadas de un NPC u objeto en la zona del mapa:
            -- pfQuest classic + pfQuest ascension + SKquests_SpawnData
            local function CollectCoords(kind, id)
                local out = {}
                if not id then return out end

                -- Inyectar coordenadas custom si el id es de BronzebeardQuestChains
                if BronzebeardQuestChains and BronzebeardQuestChains[id] then
                    local bq = BronzebeardQuestChains[id]
                    local zID = SKquests_DetailDB[id] and SKquests_DetailDB[id].zoneId or 141
                    -- Aquí asumimos que siempre lo queremos pintar si estamos en su zona, 
                    -- así que devolvemos la coordenada.
                    table.insert(out, {bq.x, bq.y, zID})
                    return out
                end

                -- Una coordenada pertenece a este mapa si su zona usa la misma
                -- carpeta de mapa (el DetailDB usa subzonas, pfQuest usa zonas
                -- de mapa: p.ej. 9 Northshire y 12 Elwynn comparten "Elwynn")
                local function OnThisMap(z)
                    return z == mapZone or z == originalMapZone or (expectedParent and z == expectedParent) or (folder and GetZoneMapFolder(z) == folder)
                end
                if kind == "object" then
                    local o = GetObjectData(id)
                    if o and o.coords then
                        for _, c in ipairs(o.coords) do
                            if c[3] and OnThisMap(c[3]) then out[#out + 1] = {c[1], c[2], c[3]} end
                        end
                    end
                    local sd = SKquests_SpawnData and SKquests_SpawnData.objects and SKquests_SpawnData.objects[id]
                    if sd and sd.spawns then
                        for z, sp in pairs(sd.spawns) do
                            if OnThisMap(z) then
                                for _, c in ipairs(sp) do out[#out + 1] = {c[1], c[2], z} end
                            end
                        end
                    end
                else
                    local u = GetUnitData(id)
                    if u and u.coords then
                        for _, c in ipairs(u.coords) do
                            if c[3] and OnThisMap(c[3]) then out[#out + 1] = {c[1], c[2], c[3]} end
                        end
                    end
                    local sd = SKquests_SpawnData and SKquests_SpawnData.npcs and SKquests_SpawnData.npcs[id]
                    if sd and sd.spawns then
                        for z, sp in pairs(sd.spawns) do
                            if OnThisMap(z) then
                                for _, c in ipairs(sp) do out[#out + 1] = {c[1], c[2], z} end
                            end
                        end
                    end
                end
                return out
            end

            -- Tomamos la transformación REAL de cada subzona desde pfQuest
            -- (pfDB.zones.data[zona] = {padre, ancho, alto, x, y}), que es la
            -- calibración correcta. Formato CustomMapOffsets = {zw, zh, zx, zy}.
            if not _G.SKquests_CustomMapOffsets then
                _G.SKquests_CustomMapOffsets = {}
                local zd = pfDB and pfDB["zones"] and pfDB["zones"]["data"]
                if zd then
                    for _, zid in ipairs({188, 220, 154, 9, 363, 132}) do
                        local d = zd[zid]
                        if d and d[2] and d[4] then
                            _G.SKquests_CustomMapOffsets[zid] = { d[2], d[3], d[4], d[5] }
                        end
                    end
                end
            end
            local CustomMapOffsets = _G.SKquests_CustomMapOffsets

            -- Punto coloreado de objetivo, con agrupado de spawns próximos
            local placed = {}
            local function PlaceDot(x, y, z, r, g, b, label, sub, category)
                -- 1. Proyectar PADRE -> SUBZONA (cuando vemos mapa custom)
                if customMap and z and z ~= mapZone then
                    local parentData = pfDB and pfDB["zones"] and pfDB["zones"]["data"] and pfDB["zones"]["data"][mapZone]
                    if parentData and parentData[1] == z then
                        -- Usar calibracion custom si existe, sino intentar usar DB
                        local calib = CustomMapOffsets[mapZone]
                        if calib then
                            local zw, zh, zx, zy = calib[1], calib[2], calib[3], calib[4]
                            x = (x - zx) * 100 / zw
                            y = (y - zy) * 100 / zh
                        elseif parentData[2] and parentData[4] then
                            local zw, zh, zx, zy = parentData[2], parentData[3], parentData[4], parentData[5]
                            x = (x - zx) * 100 / zw
                            y = (y - zy) * 100 / zh
                        end
                    end
                -- 2. Proyectar SUBZONA -> PADRE (cuando vemos mapa Vanilla normal)
                elseif not customMap and z and z ~= mapZone then
                    local czData = pfDB and pfDB["zones"] and pfDB["zones"]["data"] and pfDB["zones"]["data"][z]
                    if czData and czData[1] == mapZone and czData[2] and czData[4] then
                        local zw, zh, zx, zy = czData[2], czData[3], czData[4], czData[5]
                        x = zx + (x * zw / 100)
                        y = zy + (y * zh / 100)
                    end
                end
                
                for _, p in ipairs(placed) do
                    if p.r == r and p.g == g and math.abs(p.x - x) < 1.0 and math.abs(p.y - y) < 1.0 then
                        return false -- cluster: ya hay un punto igual al lado
                    end
                end
                nPin = nPin + 1
                placed[#placed + 1] = { x = x, y = y, r = r, g = g }
                local pin = GetPin(nPin)
                pin.category = category
                pin.questId  = q and q.id
                pin:SetSize(14, 14)
                pin.tex:SetTexture("Interface\\AddOns\\SKquests\\Media\\circle.tga")
                pin.tex:SetVertexColor(r, g, b, 0.5)
                pin.tex:SetBlendMode("ADD")

                -- Glow central
                if not pin.glow then
                    pin.glow = pin:CreateTexture(nil, "OVERLAY")
                    pin.glow:SetTexture("Interface\\AddOns\\SKquests\\Media\\circle.tga")
                    pin.glow:SetPoint("CENTER")
                end
                pin.glow:SetSize(9, 9)
                pin.glow:SetVertexColor(r, g, b, 0.9)
                pin.glow:SetBlendMode("ADD")
                pin.glow:Show()

                pin.relX = x / 100
                pin.relY = y / 100
                pin.label = label
                pin.sub = string.format("%s (%.1f, %.1f)", sub or "", x, y)
                pin:EnableMouse(true)
                pin:SetScript("OnMouseDown", function(self, button)
                    if IsControlKeyDown() and button == "LeftButton" then
                        if self.category then
                            SKquestsDB.config.pinColors = SKquestsDB.config.pinColors or { kill=1, interact=1, gather=1 }
                            SKquestsDB.config.pinColors[self.category] = (SKquestsDB.config.pinColors[self.category] % 6) + 1
                            addon:RefreshDetail()
                        end
                    end
                end)
                pin:Show()
                return true
            end

            local Palette = {
                kill = { {1.0, 0.2, 0.2}, {0.9, 0.1, 0.3}, {1.0, 0.3, 0.0}, {0.8, 0.0, 0.0}, {1.0, 0.1, 0.6}, {0.9, 0.4, 0.4} },
                interact = { {1.0, 0.8, 0.1}, {1.0, 0.6, 0.0}, {0.9, 0.9, 0.3}, {1.0, 0.5, 0.1}, {1.0, 0.9, 0.5}, {0.8, 0.6, 0.1} },
                gather = { {0.2, 1.0, 0.2}, {0.1, 0.8, 0.4}, {0.3, 0.9, 0.6}, {0.0, 0.7, 0.3}, {0.4, 1.0, 0.5}, {0.2, 0.6, 0.1} }
            }

            local function AddObjectivePins(list, kind, category, roleTxt)
                if not list then return end
                SKquestsDB.config.pinColors = SKquestsDB.config.pinColors or { kill=1, interact=1, gather=1 }
                local idx = SKquestsDB.config.pinColors[category] or 1
                local r, g, b = unpack(Palette[category][idx])
                
                for _, id in ipairs(list) do
                    if nPin >= PIN_BUDGET then return end
                    local name = (kind == "object") and ObjectDisplayName(id) or UnitDisplayName(id)
                    local added = 0
                    for _, c in ipairs(CollectCoords(kind, id)) do
                        if nPin >= PIN_BUDGET or added >= 15 then break end
                        if PlaceDot(c[1], c[2], c[3], r, g, b, name, roleTxt, category) then
                            added = added + 1
                        end
                    end
                end
            end

            -- Giver/finisher: iconos vanilla "!" y "?" amarillos
            local function AddPins(id, kind, name, icon, role)
                local added = 0
                for _, c in ipairs(CollectCoords(kind, id)) do
                    if added < 5 then
                        local cx, cy, cz = c[1], c[2], c[3]
                        -- 1. Proyectar PADRE -> SUBZONA (cuando vemos mapa custom)
                        if customMap and cz and cz ~= mapZone then
                            local parentData = pfDB and pfDB["zones"] and pfDB["zones"]["data"] and pfDB["zones"]["data"][mapZone]
                            if parentData and parentData[1] == cz then
                                local calib = CustomMapOffsets[mapZone]
                                if calib then
                                    local zw, zh, zx, zy = calib[1], calib[2], calib[3], calib[4]
                                    cx = (cx - zx) * 100 / zw
                                    cy = (cy - zy) * 100 / zh
                                elseif parentData[2] and parentData[4] then
                                    local zw, zh, zx, zy = parentData[2], parentData[3], parentData[4], parentData[5]
                                    cx = (cx - zx) * 100 / zw
                                    cy = (cy - zy) * 100 / zh
                                end
                            end
                        -- 2. Proyectar SUBZONA -> PADRE (cuando vemos mapa Vanilla normal)
                        elseif not customMap and cz and cz ~= mapZone then
                            local czData = pfDB and pfDB["zones"] and pfDB["zones"]["data"] and pfDB["zones"]["data"][cz]
                            if czData and czData[1] == mapZone and czData[2] and czData[4] then
                                local zw, zh, zx, zy = czData[2], czData[3], czData[4], czData[5]
                                cx = zx + (cx * zw / 100)
                                cy = zy + (cy * zh / 100)
                            end
                        end
                        nPin = nPin + 1; added = added + 1
                        local pin = GetPin(nPin)
                        pin:SetSize(20, 20)
                        pin.relX = cx / 100
                        pin.relY = cy / 100
                        pin.tex:SetTexture(icon)
                        pin.tex:SetVertexColor(1, 1, 1, 1)
                        pin.tex:SetBlendMode("BLEND")
                        if pin.glow then pin.glow:Hide() end
                        pin:SetScript("OnMouseDown", nil)
                        pin.label = name or ("NPC " .. tostring(id))
                        pin.sub = string.format("%s (%.1f, %.1f)", role, cx, cy)
                        pin.questId = nil
                        pin:Show()
                    end
                end
            end

            if q then
                local hasNpc = q.giverId or q.enderId
                local bq = q.bqCoord or (q.name and BQByName[string.lower(q.name)])

                -- 1) Pines de objetivos (SKquests_ObjectiveDB)
                local links = SKquests_ObjectiveLinks and SKquests_ObjectiveLinks[q.id]
                if links then
                    local txtKill = IsSpanish() and "Objetivo: matar" or "Objective: kill"
                    local txtUse  = IsSpanish() and "Objeto: interactuar" or "Object: interact"
                    local txtLoot = IsSpanish() and "Recoleccion" or "Collect"
                    local txtLootObj = IsSpanish() and "Recoleccion (Objeto)" or "Collect (Object)"

                    AddObjectivePins(links.npcs,         "npc",    "kill",     txtKill)
                    AddObjectivePins(links.objects,      "object", "interact", txtUse)
                    AddObjectivePins(links.item_npcs,    "npc",    "gather",   txtLoot)
                    AddObjectivePins(links.item_objects, "object", "gather",   txtLootObj)
                end

                if hasNpc then
                    -- 2) Giver/finisher con NPC (misma proyección que los puntos verdes)
                    local gName = (IsSpanish() and q.giver_loc) or q.giver
                    local eName = (IsSpanish() and q.ender_loc) or q.ender
                    local gKind = (q.giverType == "GO") and "object" or "npc"
                    local eKind = (q.enderType == "GO") and "object" or "npc"
                    AddPins(q.giverId, gKind, gName, "Interface\\GossipFrame\\AvailableQuestIcon", L("MAP_START"))
                    if q.enderId ~= q.giverId then
                        AddPins(q.enderId, eKind, eName, "Interface\\GossipFrame\\ActiveQuestIcon", L("MAP_END"))
                    end
                elseif bq then
                    -- Quest nueva (BronzebeardQuestChains): solo el NPC de inicio,
                    -- en coords de azerothhub DIRECTAS sobre la imagen custom de
                    -- la subzona (la imagen y las coords vienen de la misma página).
                    nPin = nPin + 1
                    local pin = GetPin(nPin)
                    pin:SetSize(20, 20)
                    pin.relX = bq.x / 100
                    pin.relY = bq.y / 100
                    pin.tex:SetTexture("Interface\\GossipFrame\\AvailableQuestIcon")
                    pin.tex:SetVertexColor(1, 1, 1, 1)
                    pin.tex:SetBlendMode("BLEND")
                    if pin.glow then pin.glow:Hide() end
                    pin:SetScript("OnMouseDown", nil)
                    pin.label = q.name
                    pin.sub = string.format("%s (%.0f, %.0f)", L("MAP_START"), bq.x, bq.y)
                    pin.questId = nil
                    pin:Show()
                end

                -- FEATURE: coordenada guardada al ACEPTAR la quest. Se pinta si
                -- la zona del mapa mostrado coincide con la zona donde se acepto.
                local savedC = q and q.name and SKquestsDB and SKquestsDB.acceptedCoords and SKquestsDB.acceptedCoords[q.name]
                if savedC and savedC.zone and savedC.x and GetZoneName(mapZone) == savedC.zone then
                    nPin = nPin + 1
                    local pin = GetPin(nPin)
                    pin:SetSize(18, 18)
                    pin.relX = savedC.x / 100
                    pin.relY = savedC.y / 100
                    pin.tex:SetTexture("Interface\\GossipFrame\\AvailableQuestIcon")
                    pin.tex:SetVertexColor(0.4, 1, 0.4, 1)
                    pin.tex:SetBlendMode("BLEND")
                    if pin.glow then pin.glow:Hide() end
                    pin:SetScript("OnMouseDown", nil)
                    pin.label = q.name
                    pin.sub = (IsSpanish() and "Guardado al aceptar" or "Saved on accept") .. string.format(" (%.0f, %.0f)", savedC.x, savedC.y)
                    pin.questId = nil
                    pin:Show()
                end
            end
        else
            imgMode = "flat"
            for i = 1, 12 do mapTiles[i]:Hide() end
            flatTex:SetTexture(GetQuestTexture(q and q.image))
            flatTex:Show()
        end
                -- Mostramos la caja siempre que se haya cargado un mapa:
        -- custom (azerothhub, Media\Maps) para quests BronzebeardQuestChains,
        -- y el mapa WorldMap de la zona para las vanilla (con sus pines pfQuest).
        if usedMap then
            self.hasMap = true
            self:Show()
            self.needsLayout = true
        else
            self.hasMap = false
            self:Hide()
        end
        ImgLayout()
    end

    dChild.questImgBox = questImgBox

    -- 2) Sección Objetivo
    local objSec = CreateFrame("Frame", nil, dChild)
    objSec:SetHeight(120)
    dChild.objSec = objSec

    local objLbl = objSec:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    objLbl:SetPoint("TOPLEFT", 4, -4)
    RegLoc(objLbl, "OBJECTIVES", "upper")
    objLbl:SetTextColor(0.85, 0.70, 0.35)
    objSec.lbl = objLbl

    -- Botón de Navegación GPS (estilo TomTom)
    local tomtomBtn = CreateFrame("Button", nil, objSec, "UIPanelButtonTemplate")
    tomtomBtn:SetPoint("TOPRIGHT", -108, -2)
    tomtomBtn:SetSize(120, 20)
    tomtomBtn:SetText(IsSpanish() and "Seguir GPS" or "Track GPS")
    tomtomBtn:Hide()
    tomtomBtn:SetScript("OnClick", function(self)
        local cM, cX, cY, cTitle = SKQ_Arrow_GetTarget()
        if cM == self.targetMapId and cTitle == self.targetTitle and self.targetTitle ~= nil then
            if SKQ_Arrow_ClearWaypoint then SKQ_Arrow_ClearWaypoint() end
            self:SetText(IsSpanish() and "Seguir GPS" or "Track GPS")
            return
        end
        if self.targetMapId and self.targetX and self.targetY then
            if SKQ_Arrow_SetWaypoint then
                SKQ_Arrow_SetWaypoint(self.targetMapId, self.targetX, self.targetY, self.targetTitle, self.targetCoords)
                self:SetText(IsSpanish() and "Detener GPS" or "Stop GPS")
            end
        end
    end)
    objSec.tomtomBtn = tomtomBtn

    local objBox = CreateFrame("Frame", nil, objSec)
    objBox:SetPoint("TOPLEFT", 4, -24)
    objBox:SetPoint("BOTTOMRIGHT", -4, -4)
    SKQ_EnsureBackdrop(objBox)
    objBox:SetBackdrop({
        bgFile = "Interface\\ChatFrame\\ChatFrameBackground",
        edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
        edgeSize = 8, insets = {left=2, right=2, top=2, bottom=2}
    })
    objBox:SetBackdropColor(0,0,0,0.3)
    objBox:SetBackdropBorderColor(0.5, 0.4, 0.3, 0.4)
    objSec.box = objBox

      -- Botón "Compartir al chat" (quest log con progreso)
      local shareBtn = CreateFrame("Button", nil, objSec, "UIPanelButtonTemplate")
      shareBtn:SetPoint("TOPRIGHT", -4, -2)
      shareBtn:SetSize(100, 18)
      shareBtn:SetText(">> Chat")
      shareBtn:Hide()
      objSec.shareBtn = shareBtn
      -- ── Menú de canal: Say / Party / Guild ─────────────────────────────────
      local shareChanMenu = CreateFrame("Frame", nil, objSec)
      shareChanMenu:SetSize(90, 70)
      shareChanMenu:SetPoint("BOTTOMRIGHT", shareBtn, "TOPRIGHT", 0, 2)
      shareChanMenu:SetFrameStrata("TOOLTIP")
      ApplyBD(shareChanMenu, {0.05, 0.05, 0.07}, {0.60, 0.50, 0.20}, 6)
      shareChanMenu:Hide()
      objSec.shareChanMenu = shareChanMenu

      local SKQ_CHANNELS = {
          { label = "Say",   chan = "SAY"   },
          { label = "Party", chan = "PARTY" },
          { label = "Guild", chan = "GUILD" },
      }
      for i, chDef in ipairs(SKQ_CHANNELS) do
          local cBtn = CreateFrame("Button", nil, shareChanMenu)
          cBtn:SetSize(86, 20)
          cBtn:SetPoint("TOPLEFT", 2, -2 - (i-1)*22)
          ApplyBD(cBtn, {0,0,0}, {0.45, 0.38, 0.18}, 4)
          cBtn:SetBackdropColor(0,0,0,0)
          local cLbl = cBtn:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
          cLbl:SetPoint("CENTER", 0, 0)
          cLbl:SetText(chDef.label)
          cBtn:SetScript("OnEnter", function(self) self:SetBackdropColor(0.28, 0.18, 0, 0.9) end)
          cBtn:SetScript("OnLeave", function(self) self:SetBackdropColor(0, 0, 0, 0) end)
          local chanName = chDef.chan  -- upvalue por botón
          cBtn:SetScript("OnClick", function()
              local sb = objSec.shareBtn
              if sb and ((sb.shareLines and #sb.shareLines > 0) or sb.isComplete) then
                  local qId   = sb.questId or 0
                  local qLvl  = sb.questLevel or 0
                  local qName = sb.questTitle or ""
                  local qLink = "|cff808080|Hquest:" .. qId .. ":" .. qLvl .. "|h[" .. qName .. "]|h|r"
                  local prog
                  if sb.shareLines and #sb.shareLines > 0 then
                      prog = table.concat(sb.shareLines, ", ")
                  else
                      prog = IsSpanish() and "¡Completada! Lista para entregar." or "Completed! Ready to turn in."
                  end
                  SendChatMessage("SKquests: " .. qLink .. " - " .. prog, chanName)
              end
              shareChanMenu:Hide()
          end)
      end

      -- El botón principal ahora abre/cierra el menú de canal
      shareBtn:SetScript("OnClick", function(self)
            if (self.shareLines and #self.shareLines > 0) or self.isComplete then
                if shareChanMenu:IsShown() then
                    shareChanMenu:Hide()
                else
                    shareChanMenu:Show()
                end
            end
        end)
      shareBtn:SetScript("OnHide", function() shareChanMenu:Hide() end)

      local objText = objBox:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    objText:SetPoint("TOPLEFT", 8, -8)
    objText:SetPoint("BOTTOMRIGHT", -8, -8)
    objText:SetJustifyH("LEFT")
    objText:SetJustifyV("TOP")
    objBox.text = objText

    -- 3) Sección Descripción
    local descSec = CreateFrame("Frame", nil, dChild)
    descSec:SetHeight(100)
    dChild.descSec = descSec

    local descLbl = descSec:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    descLbl:SetPoint("TOPLEFT", 4, -4)
    RegLoc(descLbl, "DESCRIPTION", "upper")
    descLbl:SetTextColor(0.85, 0.70, 0.35)
    descSec.lbl = descLbl

    local descText = descSec:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    descText:SetPoint("TOPLEFT", 4, -22)
    descText:SetPoint("BOTTOMRIGHT", -4, -4)
    descText:SetJustifyH("LEFT")
    descText:SetJustifyV("TOP")
    descText:SetTextColor(0.75, 0.70, 0.60)
    descSec.text = descText

    -- 4) Imagen de Mapa (Guía)
    local mapBox = CreateFrame("Frame", nil, dChild)
    mapBox:SetHeight(180)
    SKQ_EnsureBackdrop(mapBox)
    mapBox:SetBackdrop({
        bgFile = "Interface\\ChatFrame\\ChatFrameBackground",
        edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
        edgeSize = 8, insets = {left=2, right=2, top=2, bottom=2}
    })
    mapBox:SetBackdropColor(0,0,0,0.5)
    mapBox:SetBackdropBorderColor(0.5,0.4,0.3,0.5)

    local mapTex = mapBox:CreateTexture(nil, "BACKGROUND")
    mapTex:SetAllPoints(mapBox)
    mapBox.tex = mapTex
    dChild.mapBox = mapBox

    -- 5) NPCs Card Grid
    local npcSec = CreateFrame("Frame", nil, dChild)
    npcSec:SetHeight(80)
    dChild.npcSec = npcSec

    local npcLbl = npcSec:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    npcLbl:SetPoint("TOPLEFT", 4, -4)
    RegLoc(npcLbl, "START_END", "upper")
    npcLbl:SetTextColor(0.85, 0.70, 0.35)
    npcSec.lbl = npcLbl

    local npcGrid = CreateFrame("Frame", nil, npcSec)
    npcGrid:SetPoint("TOPLEFT", 4, -20)
    npcGrid:SetPoint("BOTTOMRIGHT", -4, -4)

    local function MakeNpcCard(parent, titleText)
        local card = CreateFrame("Frame", nil, parent)
        card:SetSize(185, 54)
        SKQ_EnsureBackdrop(card)
        card:SetBackdrop({
            bgFile = "Interface\\ChatFrame\\ChatFrameBackground",
            edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
            edgeSize = 8, insets = {left=2, right=2, top=2, bottom=2}
        })
        card:SetBackdropColor(0,0,0,0.3)
        card:SetBackdropBorderColor(0.5, 0.4, 0.3, 0.4)

        local t = card:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
        t:SetPoint("TOPLEFT", 8, -6)
        t:SetText(titleText)
        card.title = t

        local name = card:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
        name:SetPoint("TOPLEFT", t, "BOTTOMLEFT", 0, -2)
        card.name = name

        return card
    end

    npcGrid.startCard = MakeNpcCard(npcGrid, "INICIO")
    npcGrid.startCard:SetPoint("LEFT", 0, 0)

    npcGrid.endCard = MakeNpcCard(npcGrid, "ENTREGA")
    npcGrid.endCard:SetPoint("RIGHT", 0, 0)
    npcSec.grid = npcGrid

    -- 6) Sección Recompensas (fijas + elección)
    local rewardSec = CreateFrame("Frame", nil, dChild)
    rewardSec:SetHeight(110)
    dChild.rewardSec = rewardSec

    local rewardLbl = rewardSec:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    rewardLbl:SetPoint("TOPLEFT", 4, -4)
    RegLoc(rewardLbl, "REWARDS", "upper")
    rewardLbl:SetTextColor(0.85, 0.70, 0.35)
    rewardSec.lbl = rewardLbl

    -- Dinero + XP de recompensa (datos de SKquests_Rewards / quest_template)
    local moneyLbl = rewardSec:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    moneyLbl:SetPoint("TOPRIGHT", rewardSec, "TOPRIGHT", -8, -3)
    moneyLbl:SetJustifyH("RIGHT")
    rewardSec.moneyLbl = moneyLbl

    -- Sub-label recompensas fijas
    local fixedLbl = rewardSec:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    fixedLbl:SetPoint("TOPLEFT", 4, -20)
    RegLoc(fixedLbl, "FIXED_REWARDS")
    fixedLbl:SetTextColor(0.7, 0.65, 0.5)
    rewardSec.fixedLbl = fixedLbl

    -- Sub-label recompensas a elección
    local choiceLbl = rewardSec:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    choiceLbl:SetPoint("TOPLEFT", 4, -64)
    RegLoc(choiceLbl, "CHOICE_REWARDS")
    choiceLbl:SetTextColor(0.7, 0.65, 0.5)
    rewardSec.choiceLbl = choiceLbl

    local function MakeItemBtn(parent, bname, xOffset, yOffset)
        local btn = CreateFrame("Button", bname, parent)
        btn:SetSize(36, 36)
        btn:SetPoint("TOPLEFT", xOffset, yOffset)
        SKQ_EnsureBackdrop(btn)
        btn:SetBackdrop({
            edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
            edgeSize = 8, insets = {left=1, right=1, top=1, bottom=1}
        })
        btn:SetBackdropBorderColor(0.5, 0.4, 0.3, 0.6)
        local tex = btn:CreateTexture(nil, "BACKGROUND")
        tex:SetAllPoints(btn)
        btn.tex = tex
        btn:SetScript("OnEnter", function(self)
            if self.itemLink then
                GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
                GameTooltip:SetHyperlink(self.itemLink)
                GameTooltip:Show()
            elseif self.itemId and self.itemId > 0 then
                GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
                GameTooltip:SetHyperlink("item:" .. self.itemId)
                GameTooltip:Show()
            end
        end)
        btn:SetScript("OnLeave", function() GameTooltip:Hide() end)
        btn:SetScript("OnClick", function(self)
            if self.itemLink and IsShiftKeyDown() then
                local editBox = ChatEdit_GetActiveWindow()
                if editBox and editBox:IsShown() then
                    editBox:Insert(self.itemLink)
                end
            end
        end)
        return btn
    end

    rewardSec.buttons = {}
    for r = 1, 4 do
        rewardSec.buttons[r] = MakeItemBtn(rewardSec, "SKquestsRewardBtn" .. r, 4 + (r-1)*44, -34)
    end

    rewardSec.choiceButtons = {}
    for r = 1, 6 do
        rewardSec.choiceButtons[r] = MakeItemBtn(rewardSec, "SKquestsChoiceBtn" .. r, 4 + (r-1)*44, -78)
    end

    -- El servidor solo envía los datos de un item cuando se le piden:
    -- pedimos los no cacheados y refrescamos los iconos en cuanto llegan.
    local itemCacheTip = CreateFrame("GameTooltip", "SKquestsItemCacheTip", UIParent, "GameTooltipTemplate")
    itemCacheTip:SetOwner(UIParent, "ANCHOR_NONE")
    local rewardRetry = CreateFrame("Frame")
    rewardRetry:Hide()
    rewardRetry.elapsed = 0
    rewardRetry.tries = 0
    rewardRetry:SetScript("OnUpdate", function(self, e)
        self.elapsed = self.elapsed + e
        if self.elapsed < 0.4 then return end
        self.elapsed = 0
        self.tries = self.tries + 1
        local pending = false
        local function fill(btns)
            for _, btn in ipairs(btns) do
                if btn:IsShown() and btn.itemId and not btn.itemLink then
                    local tx = GetItemIcon(btn.itemId)
                    if tx then btn.tex:SetTexture(tx) end
                    local nm, lk = GetItemInfo(btn.itemId)
                    if nm then
                        btn.itemLink = lk
                    else
                        pending = true
                    end
                end
            end
        end
        fill(rewardSec.buttons)
        fill(rewardSec.choiceButtons)
        if not pending or self.tries > 12 then self:Hide() end
    end)
    function rewardSec:RequestUncached()
        local any = false
        local function req(btns)
            for _, btn in ipairs(btns) do
                if btn:IsShown() and btn.itemId and not btn.itemLink then
                    itemCacheTip:SetOwner(UIParent, "ANCHOR_NONE")
                    itemCacheTip:SetHyperlink("item:" .. btn.itemId)
                    any = true
                end
            end
        end
        req(self.buttons)
        req(self.choiceButtons)
        if any then
            rewardRetry.elapsed = 0
            rewardRetry.tries = 0
            rewardRetry:Show()
        end
    end

    -- 7) Enlaces (Wowhead copiable con botón de copiar integrado)
    -- [WotLK Classic] linkSec frame creation removed

    -- ================================================================
    --  BARRA LATERAL DERECHA (METADATOS DE QUEST)
    -- ================================================================
    RightSidebar = CreateFrame("Frame", nil, f)
    RightSidebar:SetPoint("TOPRIGHT", f, "TOPRIGHT", -10, -32)
    RightSidebar:SetPoint("BOTTOMRIGHT", f, "BOTTOMRIGHT", -10, 10)
    RightSidebar:SetWidth(200)
    ApplyBD(RightSidebar, C.bgSide, C.borderDim, 8)

    local rsTitle = RightSidebar:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    rsTitle:SetPoint("TOPLEFT", 12, -14)
    RegLoc(rsTitle, "QUEST_DETAILS", "upper")
    rsTitle:SetTextColor(1, 0.8, 0)
    RightSidebar.title = rsTitle

    local function MakeInfoRow(parent, labelText, yOff)
        local row = CreateFrame("Frame", nil, parent)
        row:SetPoint("TOPLEFT", 12, yOff)
        row:SetPoint("TOPRIGHT", -12, yOff)
        row:SetHeight(28)

        local lbl = row:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
        lbl:SetPoint("TOPLEFT", 0, 0)
        lbl:SetText(labelText)

        local val = row:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
        val:SetPoint("TOPLEFT", lbl, "BOTTOMLEFT", 0, -2)
        row.lbl = lbl
        row.val = val

        return row
    end

    RightSidebar.rows = {
        questId  = MakeInfoRow(RightSidebar, L("ROW_QUESTID"), -40),
        minLvl   = MakeInfoRow(RightSidebar, L("ROW_MINLVL"), -80),
        status   = MakeInfoRow(RightSidebar, L("ROW_STATUS"), -120),
    }

    local chainSec = CreateFrame("Frame", nil, RightSidebar)
    chainSec:SetPoint("TOPLEFT", 12, -160)
    chainSec:SetSize(180, 80)

    local chainLbl = chainSec:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    chainLbl:SetPoint("TOPLEFT", 0, 0)
    RegLoc(chainLbl, "QUEST_CHAIN", "upper")
    chainLbl:SetTextColor(1, 0.8, 0)
    chainSec.lbl = chainLbl

    local function MakeChainButton(parent, text, yOff)
        local btn = CreateFrame("Button", nil, parent, "UIPanelButtonTemplate")
        btn:SetPoint("TOPLEFT", 0, yOff)
        btn:SetSize(176, 22)
        btn:SetText(text)
        return btn
    end

    chainSec.prevBtn = MakeChainButton(chainSec, "◄ Anterior", -20)
    chainSec.nextBtn = MakeChainButton(chainSec, "Siguiente ►", -46)
    RightSidebar.chain = chainSec

    -- ================================================================
    --  SECCIÓN: CONFIGURACIÓN INTEGRADA (ANCLADO A SIDENAV)
    -- ================================================================
    SettingsPanel = CreateFrame("Frame", nil, f)
    SettingsPanel:SetPoint("TOPLEFT", Sidenav, "TOPRIGHT", 6, 0)
    SettingsPanel:SetPoint("BOTTOMRIGHT", f, "BOTTOMRIGHT", -10, 10)
    ApplyBD(SettingsPanel, C.bgDetail, C.borderDim, 8)
    SettingsPanel:Hide()

    local cfgTitle = SettingsPanel:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    cfgTitle:SetPoint("TOPLEFT", 16, -16)
    RegLoc(cfgTitle, "SETTINGS_TITLE")
    SettingsPanel.title = cfgTitle
    SettingsPanel.labels = {}

    local function CreateCheckbox(parent, textKey, x, y, key)
        local cbName = "SKquests_CB_" .. key
        local cb = CreateFrame("CheckButton", cbName, parent, "UICheckButtonTemplate")
        cb:SetPoint("TOPLEFT", x, y)
        local label = _G[cbName .. "Text"]
        if label then
            RegLoc(label, textKey)
            table.insert(SettingsPanel.labels, label)
        end
        cb:SetChecked(SKquestsDB and SKquestsDB.config and SKquestsDB.config[key] ~= false)
        cb:SetScript("OnClick", function(self)
            SKquests.config[key] = self:GetChecked()
            SKquestsDB.config[key] = self:GetChecked()
            addon:ApplyTheme()
            if addon.RefreshMiniTracker then addon:RefreshMiniTracker() end
        end)
        return cb
    end

    CreateCheckbox(SettingsPanel, "AUTO_MINIMIZE", 20, -50, "autoMinimize")

    local lockBtn = CreateFrame("CheckButton", "SKquests_CB_lock", SettingsPanel, "UICheckButtonTemplate")
    lockBtn:SetPoint("TOPLEFT", 20, -80)
    local lockLabel = _G["SKquests_CB_lockText"]
    if lockLabel then
        RegLoc(lockLabel, "LOCK_WINDOW")
        table.insert(SettingsPanel.labels, lockLabel)
    end
    lockBtn:SetChecked(SKquestsDB and SKquestsDB.config and SKquestsDB.config.locked or false)
    lockBtn:SetScript("OnClick", function(self)
        local lock = self:GetChecked()
        SKquests.config.locked = lock
        SKquestsDB.config.locked = lock
        f:SetMovable(not lock)
        f:SetResizable(not lock)
        addon:UpdateResizeHandles()
    end)

    -- ---- MINI-TRACKER CHECKBOX ----
    local trackerBtn = CreateFrame("CheckButton", "SKquests_CB_showTracker", SettingsPanel, "UICheckButtonTemplate")
    trackerBtn:SetPoint("TOPLEFT", 20, -110)
    local trackerLabel = _G["SKquests_CB_showTrackerText"]
    if trackerLabel then
        RegLoc(trackerLabel, "SHOW_TRACKER")
        table.insert(SettingsPanel.labels, trackerLabel)
    end
    trackerBtn:SetChecked(SKquestsDB and SKquestsDB.config and SKquestsDB.config.showTracker ~= false)
    trackerBtn:SetScript("OnClick", function(self)
        local show = self:GetChecked()
        SKquests.config.showTracker = show
        SKquestsDB.config.showTracker = show
        if show then
            if not SKquests_MiniTracker then
                addon:CreateMiniTracker()
            end
            SKquests_MiniTracker:Show()
            addon:RefreshMiniTracker()
        else
            if SKquests_MiniTracker then
                SKquests_MiniTracker:Hide()
            end
        end
    end)

    -- ---- SELECTOR DE TEMA Y EDITOR PRO ELIMINADOS (v0.9.0) ----
    -- Esta build usa solo la paleta oscura. El Modo Pro ahora protege
    -- las GUÍAS de leveo (no los temas). Se conserva un no-op por si
    -- alguna ruta antigua llama a RefreshThemeDropdown.
    function addon:RefreshThemeDropdown() end

    -- ---- CONFIGURACIONES ADICIONALES DEL MINI-TRACKER ----
    local trackerObjsBtn = CreateFrame("CheckButton", "SKquests_CB_trackerShowObjectives", SettingsPanel, "UICheckButtonTemplate")
    trackerObjsBtn:SetPoint("TOPLEFT", 20, -140)
    local trackerObjsLabel = _G["SKquests_CB_trackerShowObjectivesText"]
    if trackerObjsLabel then
        RegLoc(trackerObjsLabel, "TRACKER_SHOW_OBJS")
        table.insert(SettingsPanel.labels, trackerObjsLabel)
    end
    trackerObjsBtn:SetChecked(SKquestsDB and SKquestsDB.config and SKquestsDB.config.trackerShowObjectives ~= false)
    trackerObjsBtn:SetScript("OnClick", function(self)
        local show = self:GetChecked()
        SKquests.config.trackerShowObjectives = show
        SKquestsDB.config.trackerShowObjectives = show
        addon:RefreshMiniTracker()
    end)

    local trackerZoneBtn = CreateFrame("CheckButton", "SKquests_CB_trackerZoneOnly", SettingsPanel, "UICheckButtonTemplate")
    trackerZoneBtn:SetPoint("TOPLEFT", 180, -140)
    local trackerZoneLabel = _G["SKquests_CB_trackerZoneOnlyText"]
    if trackerZoneLabel then
        trackerZoneLabel:SetText(IsSpanish() and "Zona actual" or "Current zone")
        table.insert(SettingsPanel.labels, trackerZoneLabel)
    end
    trackerZoneBtn:SetChecked(SKquestsDB and SKquestsDB.config and SKquestsDB.config.trackerCurrentZoneOnly or false)
    trackerZoneBtn:SetScript("OnClick", function(self)
        local show = self:GetChecked()
        SKquests.config.trackerCurrentZoneOnly = show
        SKquestsDB.config.trackerCurrentZoneOnly = show
        addon:RefreshMiniTracker()
    end)

    local limitLbl = SettingsPanel:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    limitLbl:SetPoint("TOPLEFT", 20, -170)
    RegLoc(limitLbl, "TRACKER_LIMIT")
    table.insert(SettingsPanel.labels, limitLbl)

    local limitSlider = CreateFrame("Slider", "SKquestsTrackerLimitSliderUI", SettingsPanel, "OptionsSliderTemplate")
    limitSlider:SetPoint("TOPLEFT", 20, -195)
    limitSlider:SetWidth(220)
    limitSlider:SetMinMaxValues(1, 20)
    local limitVal = SKquestsDB and SKquestsDB.config and SKquestsDB.config.trackerQuestLimit or 10
    limitSlider:SetValue(limitVal)
    limitSlider:SetValueStep(1)
    
    local limitLow = _G["SKquestsTrackerLimitSliderUILow"]
    if limitLow then limitLow:SetText("1") end
    local limitHigh = _G["SKquestsTrackerLimitSliderUIHigh"]
    if limitHigh then limitHigh:SetText("20") end
    local limitText = _G["SKquestsTrackerLimitSliderUIText"]
    if limitText then
        limitText:SetText(L("TRACKER_LIMIT") .. ": " .. limitVal)
    end

    limitSlider:SetScript("OnValueChanged", function(self, val)
        val = math.floor(val)
        SKquests.config.trackerQuestLimit = val
        SKquestsDB.config.trackerQuestLimit = val
        local sliderText = _G[self:GetName() .. "Text"]
        if sliderText then
            sliderText:SetText(L("TRACKER_LIMIT") .. ": " .. val)
        end
        addon:RefreshMiniTracker()
    end)

    local opLbl = SettingsPanel:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    opLbl:SetPoint("TOPLEFT", 20, -240)
    RegLoc(opLbl, "OPACITY_LBL")
    table.insert(SettingsPanel.labels, opLbl)

    local opSlider = CreateFrame("Slider", "SKquestsOpacitySliderUI", SettingsPanel, "OptionsSliderTemplate")
    opSlider:SetPoint("TOPLEFT", 20, -265)
    opSlider:SetWidth(220)
    opSlider:SetMinMaxValues(20, 100)
    opSlider:SetValue((SKquestsDB and SKquestsDB.config and SKquestsDB.config.opacity or 0.9) * 100)
    opSlider:SetValueStep(5)
    
    local lowLabel = _G["SKquestsOpacitySliderUILow"]
    if lowLabel then lowLabel:SetText("20%") end
    local highLabel = _G["SKquestsOpacitySliderUIHigh"]
    if highLabel then highLabel:SetText("100%") end
    local textLabel = _G["SKquestsOpacitySliderUIText"]
    if textLabel then textLabel:SetText(L("OPACITY") .. ": " .. math.floor((SKquestsDB and SKquestsDB.config and SKquestsDB.config.opacity or 0.9) * 100) .. "%") end

    opSlider:SetScript("OnValueChanged", function(self, val)
        local op = val / 100
        SKquests.config.opacity = op
        SKquestsDB.config.opacity = op
        f:SetAlpha(op)
        local sliderText = _G[self:GetName() .. "Text"]
        if sliderText then
            sliderText:SetText(L("OPACITY") .. ": " .. math.floor(val) .. "%")
        end
    end)

    -- ---- IDIOMA ----
    local langLbl = SettingsPanel:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    langLbl:SetPoint("TOPLEFT", 20, -310)
    RegLoc(langLbl, "LANGUAGE")
    table.insert(SettingsPanel.labels, langLbl)

    local langBtn = CreateFrame("Button", nil, SettingsPanel, "UIPanelButtonTemplate")
    langBtn:SetPoint("LEFT", langLbl, "RIGHT", 10, -1)
    langBtn:SetSize(120, 22)
    local function LangBtnText()
        local cur = SKquests_Localization and SKquests_Localization.currentLanguage or "esES"
        return cur == "esES" and "Español" or "English"
    end
    langBtn:SetText(LangBtnText())
    langBtn:SetScript("OnClick", function(self)
        local cur = SKquests_Localization and SKquests_Localization.currentLanguage or "esES"
        local nxt = cur == "esES" and "enUS" or "esES"
        if SKquests.db then SKquests.db.language = nxt end
        if SKquestsDB and SKquestsDB.profile then SKquestsDB.profile.language = nxt end
        addon:ApplyLanguage(nxt)
        self:SetText(LangBtnText())
    end)

    -- ---- TEMA ----
    local themeLbl = SettingsPanel:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    themeLbl:SetPoint("TOPLEFT", 20, -350)
    RegLoc(themeLbl, "THEME_LBL")
    table.insert(SettingsPanel.labels, themeLbl)

    local themeBtn = CreateFrame("Button", nil, SettingsPanel)
    themeBtn:SetPoint("LEFT", themeLbl, "RIGHT", 10, -1)
    themeBtn:SetSize(140, 22)
    themeBtn:RegisterForClicks("LeftButtonUp")
    ApplyBD(themeBtn, {0,0,0}, {0.5,0.4,0.3}, 8)
    themeBtn:SetBackdropColor(0,0,0,0.4)
    
    local themeBtnLbl = themeBtn:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    themeBtnLbl:SetPoint("LEFT", 6, 0)
    themeBtn.lbl = themeBtnLbl
    
    local themeIcon = themeBtn:CreateTexture(nil, "OVERLAY")
    themeIcon:SetSize(12, 12)
    themeIcon:SetPoint("RIGHT", -4, 0)
    themeIcon:SetTexture("Interface\\ChatFrame\\ChatFrameExpandArrow")

    local function ThemeBtnText()
        local t = addon.config and addon.config.theme or "oscuro"
        if t == "oscuro" then return L("THEME_DARK") end
        if t == "claro" then return L("THEME_LIGHT") end
        if t == "elvuidark" then return "ElvUI Dark" end
        if t == "minimaldark" then return "Minimal Dark" end
        if t == "blizzardclassic" then return L("THEME_BLIZZARDCLASSIC") end
        if t == "dragonflight" then return L("THEME_DRAGONFLIGHT") end
        if t == "wrathclassic" then return L("THEME_WRATHCLASSIC") end
        if t == "modern" then return L("THEME_MODERN") end
        if t == "warcraftlogs" then return L("THEME_WARCRAFTLOGS") end
    -- [WotLK Classic] if t == "dragonflight" then return L("THEME_ASCENSION") end
        return t
    end
    themeBtnLbl:SetText(ThemeBtnText())
    
    local themesList = { "oscuro", "claro", "elvuidark", "minimaldark", "blizzardclassic", "dragonflight", "wrathclassic", "modern", "warcraftlogs" }
    
    local themeMenu = CreateFrame("Frame", "SKquestsThemeMenu", SettingsPanel)
    themeMenu:SetSize(160, 115)
    themeMenu:SetPoint("TOPLEFT", themeBtn, "BOTTOMLEFT", 0, -2)
    themeMenu:SetFrameStrata("TOOLTIP")
    ApplyBD(themeMenu, {0.05, 0.05, 0.05}, {0.5,0.4,0.3}, 8)
    themeMenu:Hide()

    local tScroll = CreateFrame("ScrollFrame", "SKquestsThemeScroll", themeMenu, "FauxScrollFrameTemplate")
    tScroll:SetPoint("TOPLEFT", 4, -4)
    tScroll:SetPoint("BOTTOMRIGHT", -26, 4)
    
    local tButtons = {}
    for i = 1, 5 do
        local btn = CreateFrame("Button", nil, themeMenu)
        btn:SetSize(130, 20)
        if i == 1 then
            btn:SetPoint("TOPLEFT", tScroll, "TOPLEFT", 0, 0)
        else
            btn:SetPoint("TOPLEFT", tButtons[i-1], "BOTTOMLEFT", 0, 0)
        end
        local hl = btn:CreateTexture(nil, "HIGHLIGHT")
        hl:SetAllPoints()
        hl:SetTexture("Interface\\Buttons\\WHITE8X8"); hl:SetVertexColor(1, 1, 1, 0.1)
        local txt = btn:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
        txt:SetPoint("LEFT", 4, 0)
        txt:SetPoint("RIGHT", -4, 0)
        txt:SetJustifyH("LEFT")
        btn.txt = txt
        
        btn:SetScript("OnClick", function(self)
            local nextT = self.themeKey
            if SKquests.config then SKquests.config.theme = nextT end
            if SKquestsDB and SKquestsDB.config then SKquestsDB.config.theme = nextT end
            addon:ApplyTheme()
            themeBtnLbl:SetText(ThemeBtnText())
            themeMenu:Hide()
        end)
        tButtons[i] = btn
    end

    local function RefreshThemeMenu()
        FauxScrollFrame_Update(tScroll, #themesList, 5, 20)
        local offset = FauxScrollFrame_GetOffset(tScroll)
        for i = 1, 5 do
            local idx = offset + i
            if idx <= #themesList then
                local tKey = themesList[idx]
                tButtons[i].themeKey = tKey
                
                local tName = tKey
                if tKey == "oscuro" then tName = L("THEME_DARK")
                elseif tKey == "claro" then tName = L("THEME_LIGHT")
                elseif tKey == "elvuidark" then tName = "ElvUI Dark"
                elseif tKey == "minimaldark" then tName = "Minimal Dark"
                elseif tKey == "blizzardclassic" then tName = L("THEME_BLIZZARDCLASSIC")
                elseif tKey == "dragonflight" then tName = L("THEME_DRAGONFLIGHT")
                elseif tKey == "wrathclassic" then tName = L("THEME_WRATHCLASSIC")
                elseif tKey == "modern" then tName = L("THEME_MODERN")
                elseif tKey == "warcraftlogs" then tName = L("THEME_WARCRAFTLOGS")
    -- [WotLK Classic] elseif tKey == "dragonflight" then tName = L("THEME_ASCENSION")
                end
                
                tButtons[i].txt:SetText(tName)
                tButtons[i]:Show()
            else
                tButtons[i]:Hide()
            end
        end
    end

    tScroll:SetScript("OnVerticalScroll", function(self, offset)
        FauxScrollFrame_OnVerticalScroll(self, offset, 20, RefreshThemeMenu)
    end)
    themeMenu:SetScript("OnShow", RefreshThemeMenu)

    themeBtn:SetScript("OnClick", function()
        if themeMenu:IsShown() then themeMenu:Hide() else themeMenu:Show() end
    end)
    themeBtn:SetScript("OnHide", function() themeMenu:Hide() end)

    local editThemeBtn = CreateFrame("Button", nil, SettingsPanel, "UIPanelButtonTemplate")
    editThemeBtn:SetPoint("LEFT", themeBtn, "RIGHT", 10, 0)
    editThemeBtn:SetSize(120, 22)
    RegLoc(editThemeBtn, "EDIT_THEME", "upper")
    editThemeBtn:SetScript("OnClick", function()
        if addon.OpenThemeEditor then
            addon:OpenThemeEditor()
        end
    end)



    -- ---- MULTIPLICADOR XP DINÁMICO (Season of Discovery: Discoverer's Delight) ----
    local sodXPLbl = SettingsPanel:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    sodXPLbl:SetPoint("TOPLEFT", 20, -430)
    sodXPLbl:SetText("Multiplicador XP (Dinámico - SoD)")
    table.insert(SettingsPanel.labels, sodXPLbl)

    local sodXPStatus = SettingsPanel:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    sodXPStatus:SetPoint("TOPLEFT", 20, -452)
    sodXPStatus:SetWidth(320)
    sodXPStatus:SetJustifyH("LEFT")
    table.insert(SettingsPanel.labels, sodXPStatus)

    local function RefreshSoDXPStatus()
        local mult = GetSoDXPMultiplier()
        if mult > 1 then
            sodXPStatus:SetText(("|cff40ff40Discoverer's Delight ACTIVO|r (x%.1f XP de quest)"):format(mult))
        else
            sodXPStatus:SetText("|cffaaaaaaDiscoverer's Delight inactivo|r (x1.0 XP de quest)")
        end
    end
    RefreshSoDXPStatus()
    SettingsPanel:HookScript("OnShow", RefreshSoDXPStatus)

    -- Controles del XP Appraiser (en su propia función: ver nota más abajo)
    addon:AddXPAppraiserSettings(SettingsPanel)

    local acceptCfgBtn = CreateFrame("Button", nil, SettingsPanel, "UIPanelButtonTemplate")
    acceptCfgBtn:SetPoint("BOTTOMRIGHT", SettingsPanel, "BOTTOMRIGHT", -20, 20)
    acceptCfgBtn:SetSize(110, 26)
    RegLoc(acceptCfgBtn, "ACCEPT")
    acceptCfgBtn:SetScript("OnClick", function() addon:SwitchTab("quests") end)

    -- ================================================================
    --  SECCIÓN: ACERCA DE (ANCLADO A SIDENAV)
    -- ================================================================
    AboutPanel = CreateFrame("Frame", nil, f)
    AboutPanel:SetPoint("TOPLEFT", Sidenav, "TOPRIGHT", 6, 0)
    AboutPanel:SetPoint("BOTTOMRIGHT", f, "BOTTOMRIGHT", -10, 10)
    ApplyBD(AboutPanel, C.bgDetail, C.borderDim, 8)
    AboutPanel:Hide()

    local abTitle = AboutPanel:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    abTitle:SetPoint("TOPLEFT", 16, -16)
    RegLoc(abTitle, "ABOUT_TITLE")
    AboutPanel.title = abTitle

    local abDesc = AboutPanel:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    abDesc:SetPoint("TOPLEFT", 16, -50)
    abDesc:SetPoint("BOTTOMRIGHT", -16, 50)
    abDesc:SetJustifyH("LEFT")
    abDesc:SetJustifyV("TOP")
    RegLoc(abDesc, "ABOUT_DESC")
    AboutPanel.desc = abDesc

    local acceptAbBtn = CreateFrame("Button", nil, AboutPanel, "UIPanelButtonTemplate")
    acceptAbBtn:SetPoint("BOTTOMRIGHT", AboutPanel, "BOTTOMRIGHT", -20, 20)
    acceptAbBtn:SetSize(110, 26)
    RegLoc(acceptAbBtn, "ACCEPT")
    acceptAbBtn:SetScript("OnClick", function() addon:SwitchTab("quests") end)

    -- ================================================================
    --  SCRIPT OnShow DE WINDOW (FORZAR RENDER COMPLETO AL CARGAR)
    -- ================================================================
    f:SetScript("OnShow", function(self)
        BuildZonesList()
        BuildFilteredQuestIds()
        addon:UpdateListRows()
        addon:RefreshDetail()
    end)

    -- ================================================================
    --  REGISTRO DE ESCAPE
    -- ================================================================
    tinsert(UISpecialFrames, "SKquestsMainFrame")

    if SKquestsDB and SKquestsDB.config then
        if SKquestsDB.config.locked then
            f:SetMovable(false)
            f:SetResizable(false)
        end
        f:SetAlpha(SKquestsDB.config.opacity or 0.9)
    end
    addon:UpdateResizeHandles()

    BuildZonesList()
    BuildFilteredQuestIds()

    -- Aplicar idioma guardado a todos los textos registrados
    if SKquests_Localization and addon.db and addon.db.language then
        SKquests_Localization:SetLanguage(addon.db.language)
    end
    for _, e in ipairs(LocRegistry) do
        local txt = L(e.key)
        if e.tf == "upper" then txt = string.upper(txt) end
        e.fs:SetText(txt)
    end
    BuildGuideChapters()
    addon:ApplyTheme()
    addon:SwitchTab("guide")

    if addon.Tracker then
        addon.Tracker.OnUpdate = function()
            SKQ_RebuildObjNameCache()
            if MainFrame and MainFrame:IsShown() then
                addon:UpdateListRows()
                addon:RefreshDetail()
            end
            if SKquests_MiniTracker and SKquests_MiniTracker:IsShown() then
                addon:RefreshMiniTracker()
            end
        end
    end

    -- ============================================================
    --  CAPTURA DE COORDENADA AL ACEPTAR UNA QUEST (FEATURE)
    --  Guarda la posicion del jugador (donde esta el NPC que da la
    --  mision) en SavedVariables para luego pintarla en el mapa.
    -- ============================================================
    function addon:CaptureQuestCoord(questLogIndex)
        if not questLogIndex or type(GetQuestLogTitle) ~= "function" then return end
        local title = GetQuestLogTitle(questLogIndex)
        if not title or title == "" then return end
        local x, y
        if addon.GetPlayerMapCoords then x, y = addon:GetPlayerMapCoords() end
        if not x or not y then return end
        local zone = (GetRealZoneText and GetRealZoneText()) or (GetZoneText and GetZoneText()) or nil
        if not zone or zone == "" then return end
        SKquestsDB = SKquestsDB or {}
        SKquestsDB.acceptedCoords = SKquestsDB.acceptedCoords or {}
        SKquestsDB.acceptedCoords[title] = { x = x, y = y, zone = zone }
    end

    -- ============================================================
    --  CAPTURA DE RECOMPENSAS EN VIVO (FEATURE)
    --  Al aceptar/escanear una quest, leemos del registro real del
    --  juego los item IDs de recompensa y los guardamos por questID en
    --  SavedVariables (SKquestsDB.learnedRewards). Asi, las misiones
    --  custom del servidor cuyas recompensas no se extrajeron quedan
    --  completas a medida que el jugador las va aceptando.
    -- ============================================================
    local function SKQ_QuestIdFromLog(index)
        if type(GetQuestLink) ~= "function" then return nil end
        local link = GetQuestLink(index)
        if not link then return nil end
        return tonumber(link:match("Hquest:(%d+)"))
    end

    function addon:CaptureQuestRewards(questLogIndex)
        if not questLogIndex or questLogIndex == 0 then return end
        if type(GetQuestLogItemLink) ~= "function" then return end
        local qid = SKQ_QuestIdFromLog(questLogIndex)
        if not qid then return end
        local prevSel = (type(GetQuestLogSelection) == "function") and GetQuestLogSelection() or nil
        SelectQuestLogEntry(questLogIndex)
        local fixed, choice = {}, {}
        local nFixed = (type(GetNumQuestLogRewards) == "function") and GetNumQuestLogRewards() or 0
        for i = 1, nFixed do
            local link = GetQuestLogItemLink("reward", i)
            local iid = link and tonumber(link:match("item:(%d+)"))
            if iid then table.insert(fixed, { id = iid }) end
        end
        local nChoice = (type(GetNumQuestLogChoices) == "function") and GetNumQuestLogChoices() or 0
        for i = 1, nChoice do
            local link = GetQuestLogItemLink("choice", i)
            local iid = link and tonumber(link:match("item:(%d+)"))
            if iid then table.insert(choice, { id = iid }) end
        end
        -- Restaurar SIEMPRE la seleccion del registro de Blizzard (0 = ninguna)
        -- para no dejar marcada la quest escaneada durante el backfill.
        if type(SelectQuestLogEntry) == "function" then SelectQuestLogEntry(prevSel or 0) end
        if #fixed == 0 and #choice == 0 then return end
        SKquestsDB = SKquestsDB or {}
        SKquestsDB.learnedRewards = SKquestsDB.learnedRewards or {}
        SKquestsDB.learnedRewards[qid] = { r = fixed, c = choice }
    end

    -- Backfill: recorre el registro de misiones actual y captura recompensas
    -- de las quests ya aceptadas (las cogidas antes de instalar esta version).
    function addon:ScanQuestLogRewards()
        if type(GetNumQuestLogEntries) ~= "function" then return end
        local n = GetNumQuestLogEntries() or 0
        for i = 1, n do
            local _, _, _, isHeader = GetQuestLogTitle(i)
            if not isHeader then
                addon:CaptureQuestRewards(i)
            end
        end
    end

    -- WoW 3.3.5a NO tiene el evento GET_ITEM_INFO_RECEIVED (se agrego en 5.x).
    -- Los items custom/del servidor devuelven nil en GetItemInfo hasta que el
    -- cliente los cachea; usamos un sondeo por OnUpdate para refrescar cuando
    -- lleguen. Tambien capturamos coordenadas al aceptar una quest (FEATURE).
    local eventFrame = CreateFrame("Frame")
    eventFrame:RegisterEvent("QUEST_ACCEPTED")
    eventFrame:RegisterEvent("QUEST_TURNED_IN")
    eventFrame:RegisterEvent("QUEST_LOG_UPDATE")
    eventFrame._acc = 0
    eventFrame._tries = 0
    eventFrame:SetScript("OnUpdate", function(self, elapsed)
        if not (MainFrame and MainFrame:IsShown()) then return end
        if not addon._pendingItems then self._tries = 0; return end
        self._acc = self._acc + elapsed
        if self._acc >= 0.5 then
            self._acc = 0
            self._tries = self._tries + 1
            if self._tries > 12 then
                -- Dejar de reintentar; los items que sigan sin cachear se
                -- quedan con el icono de interrogacion.
                addon._pendingItems = false
                addon._tries = 0
                return
            end
            addon:RefreshDetail()
        end
    end)
    eventFrame:SetScript("OnEvent", function(self, event, arg1)
        if event == "QUEST_ACCEPTED" then
            addon:CaptureQuestCoord(arg1)
            addon:CaptureQuestRewards(arg1)
        elseif event == "QUEST_LOG_UPDATE" then
            -- Un unico escaneo completo del registro tras iniciar sesion para
            -- rellenar las quests ya aceptadas; los nuevos aceptados se capturan
            -- en QUEST_ACCEPTED.
            if not self._scannedLog then
                self._scannedLog = true
                addon:ScanQuestLogRewards()
            end
        end
        if MainFrame and MainFrame:IsShown() then
            addon:RefreshDetail()
        end
    end)

    -- Inicializar el Mini-Tracker si está habilitado en la configuración
    if SKquestsDB and SKquestsDB.config and SKquestsDB.config.showTracker ~= false then
        addon:CreateMiniTracker()
    end
end

function addon:GetQuestLogDisplayList()
    local cache = self.Tracker and self.Tracker:GetActiveQuests() or {}
    
    local byCategory = {}
    local catOrder = {}
    local totalQuestsCount = 0
    for logIdx, entry in pairs(cache) do
        local cat = entry.category or "Miscellaneous"
        if not byCategory[cat] then
            byCategory[cat] = {}
            table.insert(catOrder, cat)
        end
        table.insert(byCategory[cat], { idx=logIdx, entry=entry })
        totalQuestsCount = totalQuestsCount + 1
    end
    
    table.sort(catOrder)
    
    local displayList = {}
    for _, cat in ipairs(catOrder) do
        table.insert(displayList, { isHeader = true, title = cat })
        table.sort(byCategory[cat], function(a, b)
            local la = tonumber(a.entry.level) or 0
            local lb = tonumber(b.entry.level) or 0
            if la ~= lb then return la < lb end
            return tostring(a.entry.title or "") < tostring(b.entry.title or "")
        end)
        for _, q in ipairs(byCategory[cat]) do
            table.insert(displayList, q)
        end
    end
    return displayList, totalQuestsCount
end

-- ============================================================
--  CAMBIO DE FILAS VISIBLES DINÁMICAS Y REFRESCO DE SCROLL
-- ============================================================
function addon:UpdateListRows()
    if not ListPanel or not ListPanel.scroll then return end
    if addon._inListUpdate then return end   -- guarda anti-recursion (OnShow -> UpdateListRows)
    addon._inListUpdate = true
    local h = ListPanel.scroll:GetHeight()
    
    -- Fallback si el motor de WoW aún no ha dibujado y da altura 0
    local visibleRows = 18
    if h and h > 0 then
        visibleRows = math.min(MAX_ROWS, math.floor(h / ROW_H))
        -- Altura menor que una fila (panel aun sin layout): no dejar la lista en 0
        if visibleRows < 1 then visibleRows = 18 end
    end

    -- Solo mostrar los botones necesarios
    for i = 1, MAX_ROWS do
        if i <= visibleRows then
            listButtons[i]:Show()
        else
            listButtons[i]:Hide()
        end
    end

    local totalItems = 0
    if activeTab == "quests" then
        totalItems = #filteredQuestIds
    elseif activeTab == "questlog" then
        local displayList, _ = addon:GetQuestLogDisplayList()
        totalItems = #displayList
    elseif activeTab == "guide" then
        totalItems = guideChapters and #guideChapters or 0
    elseif activeTab == "zones" then
        totalItems = #uniqueZones
    end

    -- Limitar el scroll a exactamente los items disponibles
    totalItems = math.max(0, totalItems)
    -- Si el offset quedó más allá del final (p. ej. al filtrar), volver arriba
    local curOffset = FauxScrollFrame_GetOffset(ListPanel.scroll) or 0
    if curOffset > math.max(0, totalItems - visibleRows) then
        FauxScrollFrame_SetOffset(ListPanel.scroll, 0)
        local bar = _G[ListPanel.scroll:GetName() .. "ScrollBar"]
        if bar then bar:SetValue(0) end
    end
    FauxScrollFrame_Update(ListPanel.scroll, totalItems, visibleRows, ROW_H)
    -- FauxScrollFrame_Update oculta el frame si los items caben sin scroll;
    -- re-mostrarlo aqui (la guarda evita la recursion del OnShow).
    ListPanel.scroll:Show()
    addon:RefreshList()
    addon._inListUpdate = false
end

-- ============================================================
--  ACTUALIZAR LISTADO
-- ============================================================
function addon:RefreshList()
    if not ListPanel or not ListPanel.scroll then return end
    -- Re-mostrar el frame por si FauxScrollFrame_Update lo ocultó (pocos items).
    -- Es seguro: UpdateListRows tiene guarda anti-recursión (_inListUpdate).
    ListPanel.scroll:Show()

      -- Actualizar barra de filtro de zona
      if ListPanel.zoneBar then
          if activeTab == "quests" and selectedZoneFilter ~= "Todas" then
              ListPanel.zoneBar.lbl:SetText("<< " .. selectedZoneFilter)
              ListPanel.zoneBar:Show()
          else
              ListPanel.zoneBar:Hide()
          end
      end

      -- FIX solapamiento: zoneBar y levelBar anclaban ambas a filtersFrame BOTTOM.
      -- Cuando hay zona seleccionada Y filtro de nivel activo se montaban una sobre
      -- otra. Solucion: apilar levelBar debajo de zoneBar cuando esta visible, y
      -- ajustar el TOP del scroll para dejar sitio a una o dos barras.
      if activeTab == "quests" and ListPanel.levelBar then
          local lb = ListPanel.levelBar
          local zb = ListPanel.zoneBar
          lb:ClearAllPoints()
          if zb and zb:IsShown() then
              lb:SetPoint("TOPLEFT",  zb, "BOTTOMLEFT",  0, -2)
              lb:SetPoint("TOPRIGHT", zb, "BOTTOMRIGHT", 0, -2)
          else
              lb:SetPoint("TOPLEFT",  ListPanel.filtersFrame, "BOTTOMLEFT",  0, -4)
              lb:SetPoint("TOPRIGHT", ListPanel.filtersFrame, "BOTTOMRIGHT", 0, -4)
          end
          if lb:IsShown() then
              local top = (zb and zb:IsShown()) and -106 or -86
              ListPanel.scroll:ClearAllPoints()
              ListPanel.scroll:SetPoint("TOPLEFT", ListPanel, "TOPLEFT", 6, top)
              ListPanel.scroll:SetPoint("BOTTOMRIGHT", ListPanel, "BOTTOMRIGHT", -24, 6)
          end
      end

      local offset = FauxScrollFrame_GetOffset(ListPanel.scroll)
      local h = ListPanel.scroll:GetHeight()
    local visibleRows = 18
    if h and h > 0 then
        visibleRows = math.min(MAX_ROWS, math.floor(h / ROW_H))
        if visibleRows < 1 then visibleRows = 18 end
    end

    local offset = FauxScrollFrame_GetOffset(ListPanel.scroll) or 0
    
    local debug_visibleQuests = addon:GetVisibleQuestsCount()
    local debug_activeQuests = 0
    local debug_drawnRows = visibleRows
    local debug_shownBtns = 0

    for i = 1, visibleRows do
        local btn = listButtons[i]
        local dataIdx = offset + i
        if btn.risk then btn.risk:SetText("") end

        if activeTab == "quests" then
            local id = filteredQuestIds[dataIdx]
            if id then
                local q = SKquests_DetailDB[id]
                btn.itemId = id
                btn.icon:Hide()
                
                -- Mostrar nombre localizado (Español) si está disponible
                local locN = GetQuestLoc(q.id)
                local displayName = (IsSpanish() and ((locN and locN.T) or (q.name_loc and q.name_loc ~= "" and q.name_loc))) or q.name
                
                local isDone = false
                if C_QuestLog and C_QuestLog.IsQuestFlaggedCompleted then
                    isDone = C_QuestLog.IsQuestFlaggedCompleted(id) == true
                elseif IsQuestFlaggedCompleted then
                    isDone = IsQuestFlaggedCompleted(id) == true
                end
                
                if isDone then
                    displayName = "|TInterface\\Buttons\\UI-CheckBox-Check:14|t " .. displayName
                end
                
                btn.txt:SetText(displayName)
                
                local lvl = tonumber(q.level) or 0
                btn.lvl:SetText(lvl > 0 and lvl or "")

                -- Indicador de riesgo Hardcore (icono nativo: dot de color / calavera)
                if btn.risk and SKquests.GetQuestRisk and SKquests.GetRiskIcon then
                    local zoneName = q.zoneId and GetZoneName(q.zoneId)
                    local _, riskLabel = SKquests:GetQuestRisk(q, zoneName)
                    btn.risk:SetText(SKquests:GetRiskIcon(riskLabel, 14))
                end

                local act, lIdx = addon.Tracker:IsActive(q.name)
                if act then
                    if addon.Tracker:IsComplete(lIdx) then
                        btn.dot:SetText("|TInterface\\Buttons\\UI-CheckBox-Check:14|t")
                        btn.dot:SetTextColor(1, 1, 1)
                    else
                        btn.dot:SetText("-")
                        btn.dot:SetTextColor(0.9, 0.9, 0.2)
                    end
                else
                    btn.dot:SetText("")
                end

                if id == selectedQuestId then
                    btn:SetBackdropColor(C.bgSelected[1], C.bgSelected[2], C.bgSelected[3], 0.95)
                    btn.txt:SetTextColor(C.gold[1], C.gold[2], C.gold[3])
                else
                    btn:SetBackdropColor(0,0,0,0)
                    btn.txt:SetTextColor(C.white[1], C.white[2], C.white[3])
                end
                btn:Show()
                debug_shownBtns = debug_shownBtns + 1
            else
                btn:Hide()
            end

        elseif activeTab == "questlog" then
            local displayList, activeCount = addon:GetQuestLogDisplayList()
            debug_activeQuests = activeCount
            
            local item = displayList[dataIdx]
            if item then
                if item.isHeader then
                    btn.itemId = nil
                    btn.icon:Hide()
                    btn.txt:SetText(item.title)
                    btn.lvl:SetText("")
                    btn.dot:SetText("")
                    btn:SetBackdropColor(0, 0, 0, 0)
                    btn.txt:SetTextColor(1, 0.82, 0)
                else
                    local entry = item.entry
                    btn.itemId = item.idx
                    btn.icon:Hide()
                    local titleText = "  " .. tostring(entry.title or (IsSpanish() and "Misión" or "Quest"))
                    local qColor = GetQuestDifficultyColor(entry.level or 0)
                    if qColor then
                        local dotHex = string.format(" |cff%02x%02x%02x•|r", (qColor.r or 1) * 255, (qColor.g or 1) * 255, (qColor.b or 1) * 255)
                        titleText = titleText .. dotHex
                    end
                    btn.txt:SetText(titleText)
                    
                    local lvl = tonumber(entry.level) or 0
                    btn.lvl:SetText(lvl > 0 and lvl or "")
                    
                    if entry.isComplete then
                        btn.dot:SetText("   |TInterface\\Buttons\\UI-CheckBox-Check:14|t")
                        btn.dot:SetTextColor(1, 1, 1)
                    else
                        btn.dot:SetText("   -")
                        btn.dot:SetTextColor(0.9, 0.9, 0.2)
                    end

                    if item.idx == selectedQuestLogIdx then
                        btn:SetBackdropColor(C.bgSelected[1], C.bgSelected[2], C.bgSelected[3], 0.95)
                        btn.txt:SetTextColor(C.gold[1], C.gold[2], C.gold[3])
                    else
                        btn:SetBackdropColor(0,0,0,0)
                        btn.txt:SetTextColor(C.white[1], C.white[2], C.white[3])
                    end
                end
                btn:Show()
                debug_shownBtns = debug_shownBtns + 1
            else
                btn:Hide()
            end

        elseif activeTab == "guide" then
            local chData = guideChapters and guideChapters[dataIdx]
            if chData then
                btn.itemId = dataIdx
                btn.dot:SetText("")
                btn.icon:Show()
                btn.icon:SetTexture("Interface\\QuestFrame\\UI-QuestLog-BookIcon")
                btn.txt:SetText(chData.title or (L("CHAPTER") .. " " .. dataIdx))
                btn.lvl:SetText("")

                if dataIdx == selectedGuideChapter then
                    btn:SetBackdropColor(C.bgSelected[1], C.bgSelected[2], C.bgSelected[3], 0.95)
                    btn.txt:SetTextColor(C.gold[1], C.gold[2], C.gold[3])
                else
                    btn:SetBackdropColor(0, 0, 0, 0)
                    btn.txt:SetTextColor(C.white[1], C.white[2], C.white[3])
                end
                btn:Show()
            else
                btn:Hide()
            end

        elseif activeTab == "zones" then
            local z = uniqueZones[dataIdx]
            if z then
                btn.itemId = dataIdx
                btn.zoneName = z.name
                local expColor = (z.expansion == "Custom" and "|cff66ccff")
                    or (z.expansion == "TBC" and "|cff77ee77")
                    or (z.expansion == "WotLK" and "|cff88aaff")
                    or "|cff999999"
                btn.txt:SetText(z.name .. " " .. expColor .. "(" .. (z.expansion or "Vanilla") .. ")|r")
                btn.lvl:SetText(z.count .. " quests")
                btn.dot:SetText("")

                if z.name == selectedZoneFilter then
                    btn:SetBackdropColor(C.bgSelected[1], C.bgSelected[2], C.bgSelected[3], 0.95)
                    btn.txt:SetTextColor(C.gold[1], C.gold[2], C.gold[3])
                else
                    btn:SetBackdropColor(0,0,0,0)
                    btn.txt:SetTextColor(C.white[1], C.white[2], C.white[3])
                end
                btn:Show()
            else
                btn:Hide()
            end
        end
    end

    -- Ocultar los restantes del pool que no se dibujaron
    for i = visibleRows + 1, MAX_ROWS do
        listButtons[i]:Hide()
    end

    if activeTab == "quests" then
        MainFrame.hCount:SetText(string.format(L("COUNT_FOUND"), #filteredQuestIds))
    elseif activeTab == "questlog" then
        local _, count = addon:GetQuestLogDisplayList()
        MainFrame.hCount:SetText(string.format(L("COUNT_ACTIVE"), count))
    elseif activeTab == "guide" then
        MainFrame.hCount:SetText(string.format(L("COUNT_STEPS"), #filteredGuideSteps))
    elseif activeTab == "zones" then
        MainFrame.hCount:SetText(string.format(L("COUNT_ZONES"), #uniqueZones))
    end
    
    -- Diagnóstico del último render (consultable con /skqdiag)
    local shownNow = 0
    for i = 1, visibleRows do
        if listButtons[i] and listButtons[i]:IsShown() then shownNow = shownNow + 1 end
    end
    local totalNow = 0
    if activeTab == "quests" then totalNow = #filteredQuestIds
    elseif activeTab == "guide" then totalNow = guideChapters and #guideChapters or 0
    elseif activeTab == "zones" then totalNow = #uniqueZones
    elseif activeTab == "questlog" and addon.Tracker then
        for _ in pairs(addon.Tracker:GetActiveQuests()) do totalNow = totalNow + 1 end
    end
    local b1 = listButtons[1]
    local sampleTxt, txtShown, r1, g1, bl1, a1, bw, bh = "?", false, -1, -1, -1, -1, -1, -1
    if b1 and b1.txt then
        sampleTxt = b1.txt:GetText() or "(vacio)"
        txtShown = b1.txt:IsShown()
        r1, g1, bl1, a1 = b1.txt:GetTextColor()
        bw, bh = b1:GetWidth(), b1:GetHeight()
    end
    local function box(fr)
        if not fr or not fr.GetLeft or not fr:GetLeft() then return "nil" end
        return string.format("L%.0f R%.0f T%.0f B%.0f", fr:GetLeft(), fr:GetRight(), fr:GetTop(), fr:GetBottom())
    end
    local zp = ListPanel and ListPanel.zonePanel
    addon._diagRender = {
        tab = activeTab, rows = visibleRows, offset = offset,
        shown = shownNow, total = totalNow,
        listShown = ListPanel and ListPanel:IsShown() or false,
        scrollH = ListPanel and ListPanel.scroll and ListPanel.scroll:GetHeight() or -1,
        sampleTxt = sampleTxt, txtShown = txtShown,
        txtColor = string.format("%.2f,%.2f,%.2f a=%.2f", r1, g1, bl1, a1),
        btnSize = string.format("%.0fx%.0f", bw, bh),
        btnShown = b1 and b1:IsShown() or false,
        boxBtn = box(b1),
        boxScroll = box(ListPanel and ListPanel.scroll),
        boxList = box(ListPanel),
        zoneShown = zp and zp:IsShown() or false,
        boxZone = box(zp),
        parentShown = b1 and b1:GetParent() and b1:GetParent():IsShown() or false,
    }

    if SKquests.db and SKquests.db.debugLogs then
        print("|cff33ff99[SKquests Debug]|r quests visibles (GetVisibleQuestsCount):", debug_visibleQuests)
        print("|cff33ff99[SKquests Debug]|r filas dibujadas:", debug_drawnRows)
        print("|cff33ff99[SKquests Debug]|r botones mostrados:", debug_shownBtns)
        print("|cff33ff99[SKquests Debug]|r elementos en QuestLog cache:", debug_activeQuests)
    end
end

addon.GetDiagRender = function(self) return addon._diagRender end

-- ============================================================
-- HELPER PARA OBJETIVOS COMPLETADOS
-- ============================================================
local function SKQ_IsObjectiveFinished(qEntry, sdName)
    if not qEntry or not qEntry.index or not sdName then return false end
    if not GetNumQuestLeaderBoards or not GetQuestLogLeaderBoard then return false end
    
    local numObjectives = GetNumQuestLeaderBoards(qEntry.index)
    if not numObjectives or numObjectives == 0 then return false end

    local isFinished = false
    local isAlsoUnfinished = false
    local sdLower = string.lower(sdName)

    for i = 1, numObjectives do
        local text, objType, finished = GetQuestLogLeaderBoard(i, qEntry.index)
        if text then
            local textLower = string.lower(text)
            if string.find(textLower, sdLower, 1, true) then
                if finished then
                    isFinished = true
                else
                    isAlsoUnfinished = true
                end
            end
        end
    end
    
    return isFinished and not isAlsoUnfinished
end

-- ============================================================
-- HELPER PARA OBTENER COORDENADAS GPS
-- ============================================================
local function SKQ_GetFirstQuestCoordinate(q)
    if not q or not SKquests_SpawnData then return nil end
    local function searchSpawns(idList, typeName)
        if not idList then return nil end
        if type(idList) ~= "table" then idList = {idList} end
        for _, id in ipairs(idList) do
            local sd = SKquests_SpawnData[typeName] and SKquests_SpawnData[typeName][id]
            if sd and sd.spawns and not SKQ_IsObjectiveFinished(q, sd.name) then
                for mapId, coords in pairs(sd.spawns) do
                    if coords[1] then return mapId, coords[1][1], coords[1][2], sd.name, coords end
                end
            end
        end
    end

    local qId = tonumber(q.id)
    if qId and SKquests_ObjectiveLinks and SKquests_ObjectiveLinks[qId] then
        local links = SKquests_ObjectiveLinks[qId]
        local m, x, y, n = searchSpawns(links.npcs, "npcs")
        if m then return m, x, y, n end
        m, x, y, n = searchSpawns(links.objects, "objects")
        if m then return m, x, y, n end
        m, x, y, n = searchSpawns(links.item_npcs, "npcs")
        if m then return m, x, y, n end
        m, x, y, n = searchSpawns(links.item_objects, "objects")
        if m then return m, x, y, n end
    end

    -- Fallback: NPC de entrega
    local m,x,y,n = searchSpawns(q.enderId, "npcs")
    if m then return m,x,y,n end

    -- Fallback final: NPC que da la misión
    return searchSpawns(q.giverId, "npcs")
end

-- ============================================================
--  ACTUALIZAR PANEL DE DETALLES
-- ============================================================
function addon:RefreshDetail()
    if not DetailPanel or not DetailPanel.scroll then return end
    addon._pendingItems = false

    local ch = DetailPanel.child
    if not ch then return end

    if ch.header and ch.header.trackBtn then
        ch.header.trackBtn:Hide()
        ch.header.shareNativeBtn:Hide()
        if ch.header.upBtn then ch.header.upBtn:Hide() end
        if ch.header.downBtn then ch.header.downBtn:Hide() end
    end

    -- Por defecto, ocultar TODOS los elementos de la guía (checkboxes, sus
    -- botones de link, encabezados de circuito y cajas de mapa) para que no
    -- queden visibles "detrás" del detalle de quest.
    if ch.objSec.checkbuttons then
        for _, cb in ipairs(ch.objSec.checkbuttons) do
            cb:Hide()
            if cb.linkBtn then cb.linkBtn:Hide() end
            if cb.qbtns then for _, b in ipairs(cb.qbtns) do b:Hide() end end
        end
    end
    if ch.objSec.circuitHeaders then
        for _, h in ipairs(ch.objSec.circuitHeaders) do h:Hide() end
    end
    if ch.objSec.mapBoxes then
        for _, m in ipairs(ch.objSec.mapBoxes) do m:Hide() end
    end

    if ch.rewardSec then
        ch.rewardSec:Hide()
    end

    if activeTab == "quests" then
        local questKey = selectedQuestId
        
        if not SKquests_DetailDB[questKey] then
            questKey = tostring(selectedQuestId)
        end
        
        if not SKquests_DetailDB[questKey] then
            questKey = tonumber(selectedQuestId)
        end
        
        local q = SKquests_DetailDB[questKey]
          -- [WotLK Collector] Enrich with live-collected data
          if SKquests and SKquests.Collector then
            if q then
              q = SKquests.Collector:EnrichQuestEntry(q)
            else
              -- Quest not in static DB — use 100% collected data (custom quest)
              q = SKquests.Collector:GetQuestData(tonumber(selectedQuestId))
            end
          end
        
        -- Módulo SKQ Collector: Inyectar datos en vivo
        if q and q.name and SKQ_Data and SKQ_Data.Quests and SKQ_Data.Quests[q.name] then
            local liveData = SKQ_Data.Quests[q.name]
            if liveData.description and liveData.description ~= "" then
                q.desc = liveData.description
            end
            if liveData.objectiveText and liveData.objectiveText ~= "" then
                q.logDesc = liveData.objectiveText
            end
            if liveData.xp and liveData.xp > 0 then
                if SKquests_RewardsDB then
                    SKquests_RewardsDB[tonumber(questKey)] = liveData.xp
                end
            end
        end
        
        ch.header:Show()
        ch.objSec:Show()
        ch.descSec:Show()
        ch.npcSec:Show()
    -- [WotLK Classic] ch.linkSec:Show()
        ch.mapBox:Hide()
        ch.objSec.tomtomBtn:Hide()
        ch.objSec.box:Show()

        if not selectedQuestId or not q then
            ch.header.title:SetText(L("NO_QUEST_SELECTED"))
            ch.header.meta:SetText(L("SELECT_QUEST_HINT"))
            ch.header.level:SetText("")
            ch.objSec.box.text:SetText(L("NO_DETAILS"))
            ch.descSec.text:SetText("")
            ch.npcSec.grid.startCard.name:SetText("-")
            ch.npcSec.grid.endCard.name:SetText("-")
    -- [WotLK Classic] ch.linkSec.box:SetText("")
            ch.questImgBox:Hide()
            
            RightSidebar.rows.questId.val:SetText("-")
            RightSidebar.rows.minLvl.val:SetText("-")
            RightSidebar.rows.status.val:SetText("-")
            RightSidebar.chain.prevBtn:Hide()
            RightSidebar.chain.nextBtn:Hide()
            LayoutDetailSections(ch)
            return
        end

        -- Mostrar títulos bilingües: Español (Inglés)
        local titleText = q.name
        if SKquests_Localization and SKquests_Localization.currentLanguage == "esES" and q.name_loc and q.name_loc ~= "" and q.name_loc ~= q.name then
            titleText = ((GetQuestLoc(q.id) and GetQuestLoc(q.id).T) or q.name_loc) .. " (" .. q.name .. ")"
        end
        ch.header.title:SetText(titleText)
        local lvl = tonumber(q.level) or 0
        ch.header.level:SetText(L("LVL_ABBR") .. " " .. (lvl > 0 and lvl or "?"))

        local zoneName = GetZoneName(q.zoneId)
        ch.header.meta:SetText(string.format(L("ZONE_META"), zoneName))

        -- Mostrar Ilustración
        ch.questImgBox:SetQuest(q)

        local active, logIdx = addon.Tracker:IsActive(q.name)
        if active then
            local objs = addon.Tracker:GetObjectivesFor(logIdx)
            if #objs == 0 then
                ch.objSec.box.text:SetText(L("ACTIVE_NO_OBJ"))
            else
                local str = ""
                for _, obj in ipairs(objs) do
                    local color = obj.done and "|cff00ff00" or "|cffffffff"
                    local isExploration = obj.text and (string.match(obj.text:lower(), "^explore ") or string.match(obj.text:lower(), "^explorar "))
                    local mark = obj.done and "|TInterface\\Buttons\\UI-CheckBox-Check:14|t " or (isExploration and "|TInterface\\Icons\\INV_Misc_Spyglass_02:14|t " or "- ")
                    str = str .. color .. mark .. obj.text .. "|r\n"
                end
                ch.objSec.box.text:SetText(str)
            end
        else
            -- Mostrar logDesc (objetivo del log) si existe, si no mostrar pista de inicio
            local objText = ""
            local locO = GetQuestLoc(q.id)
            local logD = (locO and locO.O) or q.logDesc
            if logD and logD ~= "" then
                objText = "|cffd4c078" .. PfText(logD) .. "|r"
            end
            -- (Se quitó la línea "Starts with / Turn in to" porque ya aparece
            --  en la sección START / TURN IN; era información duplicada.)
            ch.objSec.box.text:SetText(objText)
        end

        -- Mostrar descripción completa de la quest si existe
        local locD = GetQuestLoc(q.id)
        local descText = PfText((locD and locD.D) or q.desc) or ""
        if descText == "" then
            -- Si la quest está activa, usar el texto real del log del juego
            local act2, logIdx2 = addon.Tracker:IsActive(q.name)
            local logDesc = act2 and GetLogQuestText(logIdx2)
            descText = logDesc or L("NO_INFORMATION")
        end
        ch.descSec.text:SetText(descText)
        
        -- Dador/Ender localizados (con inyección de datos en vivo del recolector)
        local liveData = SKQ_Data and SKQ_Data.Quests and SKQ_Data.Quests[(IsSpanish() and q.name_loc) or q.name]
        local liveGiver = liveData and liveData.npcName
        local liveEnder = liveData and liveData.enderNpcName

        local giverName = liveGiver or (IsSpanish() and q.giver_loc) or q.giver or q.giver_loc or L("UNKNOWN")
        if q.giverType == "GO" and not liveGiver then
            ch.npcSec.grid.startCard.title:SetText(L("START_GO"))
        else
            ch.npcSec.grid.startCard.title:SetText(L("START_NPC"))
        end
        ch.npcSec.grid.startCard.name:SetText(giverName)

        local enderName = liveEnder or (IsSpanish() and q.ender_loc) or q.ender or q.ender_loc or L("UNKNOWN")
        if q.enderType == "GO" and not liveEnder then
            ch.npcSec.grid.endCard.title:SetText(L("END_GO"))
        else
            ch.npcSec.grid.endCard.title:SetText(L("END_NPC"))
        end
        ch.npcSec.grid.endCard.name:SetText(enderName)

    -- [WotLK Classic] ch.linkSec.box:SetText("https://db.ascension.gg/?quest=" .. q.id)

        RightSidebar.rows.questId.val:SetText(q.id)
        local ml = tonumber(q.minLevel) or 0
        RightSidebar.rows.minLvl.val:SetText(ml > 0 and ml or "1")
        
        local isCompleted = addon.completedQuests and addon.completedQuests[tostring(q.id)]
        local statusText = active and L("ST_ACTIVE") or (isCompleted and L("ST_DONE") or L("ST_NOT_STARTED"))
        RightSidebar.rows.status.val:SetText(statusText)

        -- Dinero + XP de recompensa (SKquests_Rewards, desde quest_template)
        local rwd = SKquests_Rewards and SKquests_Rewards[tonumber(q.id) or q.id]
        local rwParts = {}
        
        local liveData = SKQ_Data and SKQ_Data.Quests and SKQ_Data.Quests[(IsSpanish() and q.name_loc) or q.name]
        
        local baseXP = (liveData and liveData.xp) or (rwd and rwd.x) or 0
        local finalMoney = (liveData and liveData.money) or (rwd and rwd.m) or 0
        local finalXP = baseXP
        
        -- Integración con Questie para obtener bonos de XP dinámicos (Ascension rates, Rested, Heirlooms, Penalty)
        if QuestieLoader and type(QuestieLoader.ImportModule) == "function" then
            local QuestXP = QuestieLoader:ImportModule("QuestXP")
            if QuestXP and type(QuestXP.GetQuestLogRewardXP) == "function" then
                local qidNum = tonumber(q.id)
                if qidNum then
                    local dynXp = QuestXP:GetQuestLogRewardXP(qidNum, false)
                    if dynXp then
                        finalXP = dynXp
                    end
                end
            end
        end

        -- Multiplicador dinámico de XP (Season of Discovery: Discoverer's Delight)
        local customMult = GetSoDXPMultiplier()
        if customMult ~= 1 and not usedDynamic and baseXP > 0 then
            finalXP = math.floor(baseXP * customMult)
        end

        if finalMoney > 0 then
            rwParts[#rwParts + 1] = (GetCoinTextureString and GetCoinTextureString(finalMoney)) or tostring(finalMoney)
        end
        
        if finalXP > 0 or baseXP > 0 then
            if not usedDynamic and customMult ~= 1 and baseXP > 0 then
                -- Custom rate applied to DB base: show calculation
                local multStr = string.format("%.2f", customMult):gsub("%.?0+$","")
                rwParts[#rwParts + 1] = "|cffffd200" .. finalXP .. " XP|r |cffaaaaaa(Base: " .. baseXP .. " XP, x" .. multStr .. ")|r"
            else
                -- Live API XP or no custom rate: just show the value
                rwParts[#rwParts + 1] = "|cffffd200" .. finalXP .. " XP|r"
            end
        end
    -- [WotLK Classic] Marks removed: if SKquests_Marks and SKquests_Marks[q.id] then rwParts[#rwParts + 1] = "|cff66ccff" .. SKquests_Marks[q.id] .. " " .. (IsSpanish() and "Marcas de Ascension" or "Marks of Ascension") .. "|r" end
        local moneyStr = table.concat(rwParts, "   ")
        ch.rewardSec.moneyLbl:SetText(moneyStr)

        -- Mostrar Recompensas (fijas)
        local fixedRewards = (liveData and liveData.rewards and #liveData.rewards > 0) and liveData.rewards or GetQuestFixedRewards(q)
        local hasFixed = fixedRewards and #fixedRewards > 0
        local choiceRewards = GetQuestChoiceRewards(q)
        local hasChoice = choiceRewards and #choiceRewards > 0

        if hasFixed or hasChoice or moneyStr ~= "" then
            ch.rewardSec:Show()
            -- Botones de recompensas fijas
            for r = 1, 4 do
                local btn = ch.rewardSec.buttons[r]
                local rew = fixedRewards and fixedRewards[r]
                if rew then
                    local rId = rew.id or rew.itemID
                    btn.itemId = rId
                    btn.itemName = rew.name
                    btn.itemLink = rew.link
                    btn.tex:SetTexture("Interface\\Icons\\INV_Misc_QuestionMark")
                    local itemTexture = GetItemIcon(rId)
                    if itemTexture then btn.tex:SetTexture(itemTexture) end
                    local itemName, itemLink = GetItemInfo(rId)
                    if itemName then
                        btn.itemLink = itemLink
                    else
                        addon._pendingItems = true
                    end
                    btn:Show()
                else
                    btn:Hide()
                end
            end
            -- Botones de recompensas a elección
            if (hasChoice) then ch.rewardSec.choiceLbl:Show() else ch.rewardSec.choiceLbl:Hide() end
            if (hasFixed) then ch.rewardSec.fixedLbl:Show() else ch.rewardSec.fixedLbl:Hide() end
            for r = 1, 6 do
                local btn = ch.rewardSec.choiceButtons[r]
                local rew = choiceRewards and choiceRewards[r]
                if rew then
                    btn.itemId = rew.id
                    btn.itemLink = nil
                    btn.tex:SetTexture("Interface\\Icons\\INV_Misc_QuestionMark")
                    local itemTexture = GetItemIcon(rew.id)
                    if itemTexture then btn.tex:SetTexture(itemTexture) end
                    local itemName, itemLink = GetItemInfo(rew.id)
                    if itemName then
                        btn.itemLink = itemLink
                    else
                        addon._pendingItems = true
                    end
                    btn:Show()
                else
                    btn:Hide()
                end
            end
            ch.rewardSec:RequestUncached()
            -- Ajustar altura según haya choice, fijas o solo dinero/XP
            if hasChoice then
                ch.rewardSec:SetHeight(110)
            elseif hasFixed then
                ch.rewardSec:SetHeight(64)
                ch.rewardSec.choiceLbl:Hide()
                for r = 1, 6 do ch.rewardSec.choiceButtons[r]:Hide() end
            else
                -- solo dinero/XP, sin items: panel compacto
                ch.rewardSec:SetHeight(24)
                ch.rewardSec.fixedLbl:Hide()
                ch.rewardSec.choiceLbl:Hide()
                for r = 1, 4 do ch.rewardSec.buttons[r]:Hide() end
                for r = 1, 6 do ch.rewardSec.choiceButtons[r]:Hide() end
            end
        else
            ch.rewardSec:Hide()
        end

        local prevQ = q.prevId and SKquests_DetailDB[q.prevId]
        if prevQ then
            RightSidebar.chain.prevBtn:Show()
            RightSidebar.chain.prevBtn:SetText("Prev: " .. GetLocalizedQuestName(prevQ))
            RightSidebar.chain.prevBtn:SetScript("OnClick", function()
                selectedQuestId = q.prevId
                addon:RefreshDetail()
                addon:RefreshList()
            end)
        else
            RightSidebar.chain.prevBtn:Hide()
        end

        local nextQ = (q.nextId and SKquests_DetailDB[q.nextId]) or (q.rewardNextId and SKquests_DetailDB[q.rewardNextId])
        if nextQ then
            RightSidebar.chain.nextBtn:Show()
            RightSidebar.chain.nextBtn:SetText(GetLocalizedQuestName(nextQ) .. " (Next)")
            RightSidebar.chain.nextBtn:SetScript("OnClick", function()
                selectedQuestId = nextQ.id
                addon:RefreshDetail()
                addon:RefreshList()
            end)
        else
            RightSidebar.chain.nextBtn:Hide()
        end

        local tM, tX, tY, tN, tCoords = SKQ_GetFirstQuestCoordinate(q)
        if tM and tX and tY then
            ch.objSec.tomtomBtn.targetMapId = tM
            ch.objSec.tomtomBtn.targetX = tX
            ch.objSec.tomtomBtn.targetY = tY
            ch.objSec.tomtomBtn.targetCoords = tCoords
            ch.objSec.tomtomBtn.targetTitle = tN or GetLocalizedQuestName(q)
            ch.objSec.tomtomBtn:Show()
            local cM, cX, cY, cTitle = SKQ_Arrow_GetTarget()
            if cM == tM and cTitle == ch.objSec.tomtomBtn.targetTitle then
                ch.objSec.tomtomBtn:SetText(IsSpanish() and "Detener GPS" or "Stop GPS")
            else
                ch.objSec.tomtomBtn:SetText(IsSpanish() and "Seguir GPS" or "Track GPS")
            end
        else
            ch.objSec.tomtomBtn:Hide()
        end

        LayoutDetailSections(ch)

    elseif activeTab == "questlog" then
        ch.header:Show()
        ch.objSec:Show()
        ch.descSec:Show()
        ch.npcSec:Show()
    -- [WotLK Classic] ch.linkSec:Show()
        ch.mapBox:Hide()
        ch.objSec.tomtomBtn:Hide()
        ch.objSec.box:Show()

        local cache = addon.Tracker:GetActiveQuests()
        local entry = cache[selectedQuestLogIdx]
        if not entry then
            -- Fallback
            local firstIdx = nil
            for k in pairs(cache) do
                if not firstIdx or k < firstIdx then firstIdx = k end
            end
            if firstIdx then
                selectedQuestLogIdx = firstIdx
                entry = cache[firstIdx]
            end
        end

        if not entry then
            ch.header.title:SetText(IsSpanish() and "Ninguna misión activa seleccionada" or "No active quest selected")
            ch.header.meta:SetText("Selecciona una misión del Quest Log del panel izquierdo.")
            ch.header.level:SetText("")
            ch.objSec.box.text:SetText(L("NO_DETAILS"))
            ch.descSec.text:SetText("")
            ch.npcSec.grid.startCard.name:SetText("-")
            ch.npcSec.grid.endCard.name:SetText("-")
    -- [WotLK Classic] ch.linkSec.box:SetText("")
            ch.questImgBox:Hide()
            
            RightSidebar.rows.questId.val:SetText("-")
            RightSidebar.rows.minLvl.val:SetText("-")
            RightSidebar.rows.status.val:SetText("-")
            RightSidebar.chain.prevBtn:Hide()
            RightSidebar.chain.nextBtn:Hide()
            LayoutDetailSections(ch)
            return
        end

        local q = nil
        -- 1) Vía rápida y fiable: por ID de quest del propio log
        if entry and entry.id and SKquests_DetailDB[entry.id] then
            q = SKquests_DetailDB[entry.id]
        end
        -- 2) Respaldo: emparejar por nombre (exacto en cualquier idioma)
        if not q and entry and entry.title then
            local eTitle = entry.title:lower()
            for id, quest in pairs(SKquests_DetailDB) do
                local locN = GetQuestLoc(id)
                local t1 = quest.name and quest.name:lower() or ""
                local t2 = quest.name_loc and quest.name_loc:lower() or ""
                local t3 = locN and locN.T and locN.T:lower() or ""
                if t1 == eTitle or t2 == eTitle or t3 == eTitle then
                    q = quest
                    break
                end
            end
        end
        -- Guardar el id en la entrada para que el clic en la lista lo seleccione
        if q then selectedQuestId = q.id end

        local titleText = entry.title
        if q and SKquests_Localization and SKquests_Localization.currentLanguage == "esES" and q.name_loc and q.name_loc ~= "" and q.name_loc ~= q.name then
            titleText = ((GetQuestLoc(q.id) and GetQuestLoc(q.id).T) or q.name_loc) .. " (" .. q.name .. ")"
        end
        ch.header.title:SetText(titleText)
        local lvl = tonumber(entry.level) or 0
        ch.header.level:SetText(L("LVL_ABBR") .. " " .. (lvl > 0 and lvl or "?"))

        local zoneName = q and q.zoneId and GetZoneName(q.zoneId) or "Quest Log"
        ch.header.meta:SetText(string.format(L("ZONE_META"), zoneName))

        if ch.header.trackBtn then
            local qKey = entry.id or entry.title
            ch.header.trackBtn:SetScript("OnClick", function()
                if SKquests.config.manualTrackState[qKey] == true then
                    SKquests.config.manualTrackState[qKey] = false
                elseif SKquests.config.manualTrackState[qKey] == false then
                    SKquests.config.manualTrackState[qKey] = nil
                else
                    SKquests.config.manualTrackState[qKey] = true
                end
                addon:RefreshDetail()
                if addon.RefreshMiniTracker then addon:RefreshMiniTracker() end
            end)
            
            local trackState = SKquests.config.manualTrackState[qKey]
            if trackState == true then
                ch.header.trackBtn:SetText(IsSpanish() and "Fijo" or "Pinned")
            elseif trackState == false then
                ch.header.trackBtn:SetText(IsSpanish() and "Oculto" or "Hidden")
            else
                ch.header.trackBtn:SetText("Auto")
            end
            ch.header.trackBtn:Show()
            
            if GetQuestLogPushable(selectedQuestLogIdx) then
                ch.header.shareNativeBtn:Enable()
            else
                ch.header.shareNativeBtn:Disable()
            end
            ch.header.shareNativeBtn:SetScript("OnClick", function()
                QuestLogPushQuest(selectedQuestLogIdx)
            end)
            ch.header.shareNativeBtn:Show()

            if ch.header.upBtn and ch.header.downBtn then
                local function moveQuest(targetQKey, direction)
                    local activeQuests = addon.Tracker and addon.Tracker:GetActiveQuests()
                    if not activeQuests then return end
                    
                    local sortedQuests = {}
                    for i = 1, 100 do
                        local e = activeQuests[i]
                        if e then
                            local started = e.isComplete or false
                            if not started and e.objectives then
                                for _, obj in ipairs(e.objectives) do
                                    if obj.numDone and obj.numDone > 0 then started = true; break end
                                end
                            end
                            table.insert(sortedQuests, { entry = e, started = started, origIndex = i })
                        end
                    end
                    
                    if not SKquests.config.userSortPriority then SKquests.config.userSortPriority = {} end
                    local prio = SKquests.config.userSortPriority
                    
                    table.sort(sortedQuests, function(a, b)
                        local keyA = a.entry.id or a.entry.title
                        local keyB = b.entry.id or b.entry.title
                        local pA = prio[keyA] or 0
                        local pB = prio[keyB] or 0
                        if pA ~= pB then return pA > pB end
                        if a.started ~= b.started then return a.started end
                        return a.origIndex < b.origIndex
                    end)
                    
                    local N = #sortedQuests
                    for i, item in ipairs(sortedQuests) do
                        local k = item.entry.id or item.entry.title
                        prio[k] = N - i + 1
                    end
                    
                    for i, item in ipairs(sortedQuests) do
                        local k = item.entry.id or item.entry.title
                        if k == targetQKey then
                            local targetIdx = i + direction
                            if targetIdx >= 1 and targetIdx <= N then
                                local targetItem = sortedQuests[targetIdx]
                                local targetKey = targetItem.entry.id or targetItem.entry.title
                                local temp = prio[k]
                                prio[k] = prio[targetKey]
                                prio[targetKey] = temp
                            end
                            break
                        end
                    end
                    if addon.RefreshMiniTracker then addon:RefreshMiniTracker() end
                end

                ch.header.upBtn:SetScript("OnClick", function() moveQuest(qKey, -1) end)
                ch.header.downBtn:SetScript("OnClick", function() moveQuest(qKey, 1) end)
                ch.header.upBtn:Show()
                ch.header.downBtn:Show()
            end
        end

        -- Mostrar Ilustración
        ch.questImgBox:SetQuest(q)

        -- Mostrar objetivos activos
        local objs = entry.objectives or {}
        if #objs == 0 then
            ch.objSec.box.text:SetText("|cff00ff00Misión completada o sin objetivos.|r")
            -- Antes esto ocultaba el botón "Chat" directamente. Ahora lo
            -- dejamos visible (sin lineas de progreso) para poder avisar al
            -- chat que la mision ya esta completada/lista para entregar.
            if ch.objSec.shareBtn then
                ch.objSec.shareBtn.shareLines = nil
                ch.objSec.shareBtn.isComplete = true
                ch.objSec.shareBtn.questId    = entry.id
                ch.objSec.shareBtn.questTitle = entry.title or "?"
                ch.objSec.shareBtn.questLevel = (q and q.level) or (entry.level) or 0
                ch.objSec.shareBtn:Show()
            end
        else
            local str = ""
            local shareLines = {}
            for _, obj in ipairs(objs) do
                local color = obj.done and "|cff00ff00" or "|cffffffff"
                local isExploration = obj.text and (string.match(obj.text:lower(), "^explore ") or string.match(obj.text:lower(), "^explorar "))
                local mark = obj.done and "|TInterface\\Buttons\\UI-CheckBox-Check:14|t " or (isExploration and "|TInterface\\Icons\\INV_Misc_Spyglass_02:14|t " or "- ")
                str = str .. color .. mark .. obj.text .. "|r\n"
                -- Añadir al share cualquier objetivo pendiente, tenga o no
                -- contador numérico (antes exigía "/" como en "5/7", lo que
                -- dejaba el botón oculto en quests de un solo paso, p.ej.
                -- "usa la maza en el peón" sin contador).
                if not obj.done and obj.text and obj.text ~= "" then
                    table.insert(shareLines, obj.text)
                end
            end
            ch.objSec.box.text:SetText(str)
            if ch.objSec.shareBtn then
                ch.objSec.shareBtn.questId    = entry.id
                ch.objSec.shareBtn.questTitle = entry.title or "?"
                ch.objSec.shareBtn.questLevel = (q and q.level) or (entry.level) or 0
                if #shareLines > 0 then
                    ch.objSec.shareBtn.shareLines = shareLines
                    ch.objSec.shareBtn.isComplete = nil
                else
                    -- Todos los objetivos estan en "done" (lista para
                    -- entregar): igual mostramos el boton, en modo
                    -- "completada", en vez de ocultarlo sin mas.
                    ch.objSec.shareBtn.shareLines = nil
                    ch.objSec.shareBtn.isComplete = true
                end
                ch.objSec.shareBtn:Show()
            end
        end

        -- Descripción: DB en español si existe; si no, el texto real del log
        local logDesc = GetLogQuestText(selectedQuestLogIdx)
        local dbDesc = q and PfText((GetQuestLoc(q.id) and GetQuestLoc(q.id).D) or nil)
        ch.descSec.text:SetText(dbDesc or logDesc or (q and PfText(q.desc)) or L("NO_INFORMATION"))

        local liveData = SKQ_Data and SKQ_Data.Quests and SKQ_Data.Quests[entry.title]
        local liveGiver = liveData and liveData.npcName
        local liveEnder = liveData and liveData.enderNpcName

        if not q and liveData then
            ch.npcSec.grid.startCard.title:SetText(L("START_NPC"))
            ch.npcSec.grid.startCard.name:SetText(liveGiver or L("UNKNOWN"))
            ch.npcSec.grid.endCard.title:SetText(L("END_NPC"))
            ch.npcSec.grid.endCard.name:SetText(liveEnder or L("UNKNOWN"))
        end

        if q then
            
            local giverName = liveGiver or (IsSpanish() and q.giver_loc) or q.giver or q.giver_loc or L("UNKNOWN")
            if q.giverType == "GO" and not liveGiver then
                ch.npcSec.grid.startCard.title:SetText(L("START_GO"))
            else
                ch.npcSec.grid.startCard.title:SetText(L("START_NPC"))
            end
            ch.npcSec.grid.startCard.name:SetText(giverName)

            local enderName = liveEnder or (IsSpanish() and q.ender_loc) or q.ender or q.ender_loc or L("UNKNOWN")
            if q.enderType == "GO" and not liveEnder then
                ch.npcSec.grid.endCard.title:SetText(L("END_GO"))
            else
                ch.npcSec.grid.endCard.title:SetText(L("END_NPC"))
            end
            ch.npcSec.grid.endCard.name:SetText(enderName)

    -- [WotLK Classic] ch.linkSec.box:SetText("https://db.ascension.gg/?quest=" .. q.id)

            RightSidebar.rows.questId.val:SetText(q.id)
            local ml = tonumber(q.minLevel) or 0
            RightSidebar.rows.minLvl.val:SetText(ml > 0 and ml or "1")
            RightSidebar.rows.status.val:SetText(entry.isComplete and L("ST_READY") or L("ST_PROGRESS"))

            if q then
                local prevQ = q.prevId and SKquests_DetailDB[q.prevId]
                if prevQ then
                    RightSidebar.chain.prevBtn:Show()
                    RightSidebar.chain.prevBtn:SetText("Prev: " .. GetLocalizedQuestName(prevQ))
                    RightSidebar.chain.prevBtn:SetScript("OnClick", function()
                        selectedQuestId = q.prevId
                        addon:SwitchTab("quests")
                    end)
                else
                    RightSidebar.chain.prevBtn:Hide()
                end

                local nextQ = (q.nextId and SKquests_DetailDB[q.nextId]) or (q.rewardNextId and SKquests_DetailDB[q.rewardNextId])
                if nextQ then
                    RightSidebar.chain.nextBtn:Show()
                    RightSidebar.chain.nextBtn:SetText(GetLocalizedQuestName(nextQ) .. " (Next)")
                    RightSidebar.chain.nextBtn:SetScript("OnClick", function()
                        selectedQuestId = nextQ.id
                        addon:SwitchTab("quests")
                    end)
                else
                    RightSidebar.chain.nextBtn:Hide()
                end
            end
        else
            ch.descSec.text:SetText(L("NOT_IN_DB"))
            
            -- Conservar liveGiver y liveEnder si están disponibles, no sobreescribir con UNKNOWN a menos que falten
            ch.npcSec.grid.startCard.title:SetText(L("START_NPC"))
            ch.npcSec.grid.startCard.name:SetText(liveGiver or L("UNKNOWN"))
            ch.npcSec.grid.endCard.title:SetText(L("END_NPC"))
            ch.npcSec.grid.endCard.name:SetText(liveEnder or L("UNKNOWN"))
    -- [WotLK Classic] ch.linkSec.box:SetText("")

            RightSidebar.rows.questId.val:SetText("-")
            RightSidebar.rows.minLvl.val:SetText("-")
            RightSidebar.rows.status.val:SetText(entry.isComplete and L("ST_READY") or L("ST_PROGRESS"))
            RightSidebar.chain.prevBtn:Hide()
            RightSidebar.chain.nextBtn:Hide()
        end

        -- Dinero + XP de recompensa
        local rwParts = {}
        SelectQuestLogEntry(selectedQuestLogIdx)
        local logMoney = GetQuestLogRewardMoney and GetQuestLogRewardMoney() or 0
        local logXP = GetQuestLogRewardXP and GetQuestLogRewardXP() or 0
        
        local rwd = SKquests_Rewards and SKquests_Rewards[tonumber(q and q.id or 0) or (q and q.id)]
        
        local baseXP = (liveData and liveData.xp) or (rwd and rwd.x) or 0
        local finalMoney = (logMoney and logMoney > 0) and logMoney or (liveData and liveData.money) or (rwd and rwd.m or 0)
        local finalXP = baseXP
        local usedDynamic = false

        if logXP and logXP > 0 then
            finalXP = logXP
            usedDynamic = true
        end

        -- Integración con Questie para obtener bonos de XP dinámicos (Ascension rates, Rested, Heirlooms, Penalty)
        if QuestieLoader and type(QuestieLoader.ImportModule) == "function" and q and q.id then
            local QuestXP = QuestieLoader:ImportModule("QuestXP")
            if QuestXP and type(QuestXP.GetQuestLogRewardXP) == "function" then
                local qidNum = tonumber(q.id)
                if qidNum then
                    local dynXp = QuestXP:GetQuestLogRewardXP(qidNum, false)
                    if dynXp then
                        finalXP = dynXp
                        usedDynamic = true
                    end
                end
            end
        end

        -- Multiplicador dinámico de XP (Season of Discovery: Discoverer's Delight)
        -- Nota: si la XP viene de la API en vivo (usedDynamic), el cliente ya
        -- refleja el bono del buff, así que sólo se aplica sobre la XP base de la DB.
        local customMult = GetSoDXPMultiplier()
        if customMult ~= 1 and not usedDynamic and baseXP > 0 then
            finalXP = math.floor(baseXP * customMult)
        end
        
        if finalMoney > 0 then
            rwParts[#rwParts + 1] = (GetCoinTextureString and GetCoinTextureString(finalMoney)) or tostring(finalMoney)
        end
        
        if finalXP > 0 or baseXP > 0 then
            if not usedDynamic and customMult ~= 1 and baseXP > 0 then
                -- Custom rate applied to DB base: show calculation
                local multStr = string.format("%.2f", customMult):gsub("%.?0+$","")
                rwParts[#rwParts + 1] = "|cffffd200" .. finalXP .. " XP|r |cffaaaaaa(Base: " .. baseXP .. " XP, x" .. multStr .. ")|r"
            else
                -- Live API XP or no custom rate: just show the value
                rwParts[#rwParts + 1] = "|cffffd200" .. finalXP .. " XP|r"
            end
        end
        
    -- [WotLK Classic] Marks removed: if q and SKquests_Marks and SKquests_Marks[q.id] then rwParts[#rwParts + 1] = "|cff66ccff" .. SKquests_Marks[q.id] .. " " .. (IsSpanish() and "Marcas de Ascension" or "Marks of Ascension") .. "|r" end
        local moneyStr = table.concat(rwParts, "   ")
        if ch.rewardSec.moneyLbl then
            ch.rewardSec.moneyLbl:SetText(moneyStr)
        end

        -- Mostrar Recompensas
        local fixedRewards = (liveData and liveData.rewards and #liveData.rewards > 0) and liveData.rewards or GetQuestFixedRewards(q)
        local hasFixed = fixedRewards and #fixedRewards > 0
        local choiceRewardsQL = GetQuestChoiceRewards(q)
        local hasChoiceQL = choiceRewardsQL and #choiceRewardsQL > 0
        if hasFixed or hasChoiceQL or moneyStr ~= "" then
            ch.rewardSec:Show()
            -- Recompensas fijas
            for r = 1, 4 do
                local btn = ch.rewardSec.buttons[r]
                local rew = fixedRewards and fixedRewards[r]
                if rew then
                    local rId = rew.id or rew.itemID
                    btn.itemId = rId
                    btn.itemName = rew.name
                    btn.itemLink = rew.link
                    btn.tex:SetTexture("Interface\\Icons\\INV_Misc_QuestionMark")
                    local itemTexture = GetItemIcon(rId)
                    if itemTexture then btn.tex:SetTexture(itemTexture) end
                    local itemName, itemLink = GetItemInfo(rId)
                    if itemName then btn.itemLink = itemLink else addon._pendingItems = true end
                    btn:Show()
                else
                    btn:Hide()
                end
            end
            -- Recompensas a eleccion (Choose One)
            if hasChoiceQL then ch.rewardSec.choiceLbl:Show() else ch.rewardSec.choiceLbl:Hide() end
            if hasFixed then ch.rewardSec.fixedLbl:Show() else ch.rewardSec.fixedLbl:Hide() end
            for r = 1, 6 do
                local btn = ch.rewardSec.choiceButtons[r]
                local rew = choiceRewardsQL and choiceRewardsQL[r]
                if rew then
                    btn.itemId = rew.id
                    btn.itemLink = nil
                    btn.tex:SetTexture("Interface\\Icons\\INV_Misc_QuestionMark")
                    local itemTexture = GetItemIcon(rew.id)
                    if itemTexture then btn.tex:SetTexture(itemTexture) end
                    local itemName, itemLink = GetItemInfo(rew.id)
                    if itemName then btn.itemLink = itemLink else addon._pendingItems = true end
                    btn:Show()
                else
                    btn:Hide()
                end
            end
            ch.rewardSec:RequestUncached()
            -- Ajustar altura
            if hasChoiceQL then
                ch.rewardSec:SetHeight(110)
            elseif hasFixed then
                ch.rewardSec:SetHeight(64)
                ch.rewardSec.choiceLbl:Hide()
                for r = 1, 6 do ch.rewardSec.choiceButtons[r]:Hide() end
            else
                ch.rewardSec:SetHeight(24)
                ch.rewardSec.fixedLbl:Hide()
                ch.rewardSec.choiceLbl:Hide()
                for r = 1, 4 do ch.rewardSec.buttons[r]:Hide() end
                for r = 1, 6 do ch.rewardSec.choiceButtons[r]:Hide() end
            end
        else
            ch.rewardSec:Hide()
        end

        local dbQ = entry and SKquests_DetailDB[entry.id]
        local tM, tX, tY, tN, tCoords = SKQ_GetFirstQuestCoordinate(dbQ)
        if tM and tX and tY then
            ch.objSec.tomtomBtn.targetMapId = tM
            ch.objSec.tomtomBtn.targetX = tX
            ch.objSec.tomtomBtn.targetY = tY
            ch.objSec.tomtomBtn.targetCoords = tCoords
            ch.objSec.tomtomBtn.targetTitle = tN or (dbQ and GetLocalizedQuestName(dbQ)) or entry.title
            ch.objSec.tomtomBtn:Show()
            local cM, cX, cY, cTitle = SKQ_Arrow_GetTarget()
            if cM == tM and cTitle == ch.objSec.tomtomBtn.targetTitle then
                ch.objSec.tomtomBtn:SetText(IsSpanish() and "Detener GPS" or "Stop GPS")
            else
                ch.objSec.tomtomBtn:SetText(IsSpanish() and "Seguir GPS" or "Track GPS")
            end
        else
            ch.objSec.tomtomBtn:Hide()
        end

        LayoutDetailSections(ch)

    elseif activeTab == "guide" then
        ch.header:Show()
        ch.objSec:Show()
        ch.descSec:Hide()
        ch.npcSec:Hide()
    -- [WotLK Classic] ch.linkSec:Hide()
        ch.questImgBox:Hide()

        local guide = addon:GetGuideTable()
        if not guide or not guideChapters or not guideChapters[selectedGuideChapter] then
            ch.header.title:SetText(IsSpanish() and "No hay pasos de guía cargados" or "No guide steps loaded")
            ch.header.meta:SetText("Elige otra facción en Ajustes si es necesario.")
            ch.header.level:SetText("")
            ch.objSec.box.text:SetText("")
            ch.mapBox:Hide()
            ch.objSec.tomtomBtn:Hide()
            ch.objSec.box:Show()
            ch.objSec:SetHeight(320)
            LayoutDetailSections(ch)
            return
        end

        local chapterData = guideChapters[selectedGuideChapter]
        ch.header.title:SetText(chapterData.title)
        ch.header.level:SetText("")
        ch.header.meta:SetText("Progreso de Zona")

        ch.objSec.box:Hide()
        ch.mapBox:Hide()
        ch.objSec.tomtomBtn:Hide()

        -- Configurar pools dinámicos
        ch.objSec.checkbuttons = ch.objSec.checkbuttons or {}
        ch.objSec.circuitHeaders = ch.objSec.circuitHeaders or {}
        ch.objSec.mapBoxes = ch.objSec.mapBoxes or {}

        -- Ocultar todo el pool primero
        for _, cb in ipairs(ch.objSec.checkbuttons) do cb:Hide() end
        for _, h in ipairs(ch.objSec.circuitHeaders) do h:Hide() end
        for _, m in ipairs(ch.objSec.mapBoxes) do m:Hide() end

        local showMap = SKquestsDB and SKquestsDB.config and SKquestsDB.config.showImage ~= false
        local prevAnchor = ch.objSec.lbl
        local cbIndex = 1
        local headerIndex = 1
        local mapIndex = 1

        for stepIdx = chapterData.startIndex, chapterData.endIndex do
            local step = guide[stepIdx]
            local ges = GetGuideES(stepIdx)
            if step then
                -- Título del Circuito
                local hd = ch.objSec.circuitHeaders[headerIndex]
                if not hd then
                    hd = ch.objSec:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
                    hd:SetJustifyH("LEFT")
                    hd:SetTextColor(1, 0.82, 0)
                    ch.objSec.circuitHeaders[headerIndex] = hd
                end
                
                -- Usa el título traducido si existe (y saca solo la parte del Circuito)
                local fullTitle = (ges and ges.title) or step.title
                local circMatch = fullTitle:match("Circui[to]+.*")
                if circMatch then
                    hd:SetText(circMatch)
                else
                    hd:SetText(fullTitle)
                end
                
                hd:ClearAllPoints()
                if headerIndex == 1 then
                    hd:SetPoint("TOPLEFT", prevAnchor, "BOTTOMLEFT", 0, -15)
                else
                    hd:SetPoint("TOPLEFT", prevAnchor, "BOTTOMLEFT", 0, -35)
                end
                hd:Show()
                prevAnchor = hd
                headerIndex = headerIndex + 1

                -- Líneas del circuito
                local rawText = (ges and ges.text) or step.text or step.objectives or ""
                local lineCount = 1
                for line in rawText:gmatch("[^\r\n]+") do
                    line = line:gsub("^%s+", ""):gsub("%s+$", "")
                    if line ~= "" then
                        local cb = ch.objSec.checkbuttons[cbIndex]
                        if not cb then
                            cb = CreateFrame("CheckButton", "SKquests_GuideCB_"..cbIndex, ch.objSec, "UICheckButtonTemplate")
                            cb:SetSize(20, 20)
                            local lbl = cb:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
                            lbl:SetPoint("TOPLEFT", cb, "RIGHT", 6, 6)
                            lbl:SetJustifyH("LEFT")
                            lbl:SetJustifyV("TOP")
                            lbl:SetWordWrap(true)
                            lbl:SetNonSpaceWrap(true)
                            cb.lbl = lbl
                            ch.objSec.checkbuttons[cbIndex] = cb
                        end

                                                cb.stepIdx = stepIdx
                        cb.lineIdx = lineCount
                        
                        cb:ClearAllPoints()
                        if lineCount == 1 then
                            cb:SetPoint("TOPLEFT", prevAnchor, "BOTTOMLEFT", 20, -10)
                        else
                            cb:SetPoint("TOPLEFT", prevAnchor, "BOTTOMLEFT", -26, -6)
                        end
                        
                        -- Resaltar CADA nombre de quest entrecomillado con su propia
                        -- traducción. (Antes se tomaba solo el primero y se reemplazaban
                        -- todos por ese mismo, causando "[A Threat Within] and [A Threat Within]...")
                        -- Resaltar cada quest y recolectar sus links (cada [nombre]
                        -- entra en 'links' en orden; qid puede ser nil si no se halla).
                        local firstQid = nil
                        local links = {}
                        line = line:gsub('"(.-)"', function(name)
                            local qid = GetQuestIdByName(name)
                            local q = qid and SKquests_DetailDB[qid]
                            local locName = (q and GetLocalizedQuestName(q)) or name
                            local disp = '[' .. locName .. ']'
                            if qid and not firstQid then firstQid = qid end
                            links[#links + 1] = { disp = disp, qid = qid }
                            return '|cff00ccff' .. disp .. '|r'
                        end)
                        cb.questIdLink = firstQid
                        cb.links = links

                        -- Ancho explícito para que el texto envuelva (multilínea).
                        local availW = ch.objSec:GetWidth()
                        if not availW or availW < 60 then availW = 470 end
                        cb.lbl:SetWidth(availW - 44)
                        cb.lbl:SetText(line)
                        cb.lbl:SetTextColor(C.white[1], C.white[2], C.white[3])

                        -- Botón sobre toda la línea: si hay 1 quest, abre su ficha;
                        -- si hay varias, despliega un menú para elegir cuál abrir.
                        if not cb.linkBtn then
                            cb.linkBtn = CreateFrame("Button", nil, ch.objSec)
                            cb.linkBtn:SetScript("OnClick", function()
                                local resolved = {}
                                if cb.links then
                                    for _, lk in ipairs(cb.links) do
                                        if lk.qid then resolved[#resolved + 1] = lk end
                                    end
                                end
                                if #resolved == 1 then
                                    selectedQuestId = resolved[1].qid
                                    addon:SwitchTab("quests")
                                elseif #resolved > 1 then
                                    local menu = {}
                                    for _, lk in ipairs(resolved) do
                                        local nm = lk.disp:gsub("^%[", ""):gsub("%]$", "")
                                        menu[#menu + 1] = {
                                            text = nm, notCheckable = true,
                                            func = function()
                                                selectedQuestId = lk.qid
                                                addon:SwitchTab("quests")
                                            end,
                                        }
                                    end
                                    if not addon._linkMenu then
                                        addon._linkMenu = CreateFrame("Frame", "SKquestsLinkMenu", UIParent, "UIDropDownMenuTemplate")
                                    end
                                    if EasyMenu then EasyMenu(menu, addon._linkMenu, "cursor", 0, 0, "MENU") end
                                elseif cb.questIdLink then
                                    selectedQuestId = cb.questIdLink
                                    addon:SwitchTab("quests")
                                end
                            end)
                        end
                        cb.linkBtn:ClearAllPoints()
                        cb.linkBtn:SetPoint("TOPLEFT", cb.lbl, "TOPLEFT")
                        cb.linkBtn:SetPoint("BOTTOMRIGHT", cb.lbl, "BOTTOMRIGHT")
                        if cb.questIdLink then cb.linkBtn:Show() else cb.linkBtn:Hide() end
                        if cb.qbtns then for _, b in ipairs(cb.qbtns) do b:Hide() end end

                        local key = stepIdx .. "_" .. lineCount
                        local checked = SKquestsDB.profile.guideProgress and SKquestsDB.profile.guideProgress[key] or false
                        cb:SetChecked(checked)
                        
                        cb:SetScript("OnClick", function(self)
                            if not SKquestsDB.profile.guideProgress then
                                SKquestsDB.profile.guideProgress = {}
                            end
                            local key = self.stepIdx .. "_" .. self.lineIdx
                            SKquestsDB.profile.guideProgress[key] = self:GetChecked()
                        end)
                        
                        cb:Show()

                        prevAnchor = cb.lbl
                        cbIndex = cbIndex + 1
                        lineCount = lineCount + 1
                    end
                end

                -- Imagen del circuito
                local mapPath = GetGuideMapTexture(step.image)
                if showMap and mapPath then
                    local mb = ch.objSec.mapBoxes[mapIndex]
                    if not mb then
                        mb = CreateFrame("Frame", nil, ch.objSec)
                        SKQ_EnsureBackdrop(mb)
                        mb:SetBackdrop({
                            bgFile = "Interface\\ChatFrame\\ChatFrameBackground",
                            edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
                            edgeSize = 8, insets = {left=2, right=2, top=2, bottom=2}
                        })
                        mb:SetBackdropColor(0,0,0,0.5)
                        mb:SetBackdropBorderColor(0.5,0.4,0.3,0.5)
                        local tex = mb:CreateTexture(nil, "ARTWORK")
                        tex:SetPoint("TOPLEFT", 4, -4)
                        tex:SetPoint("BOTTOMRIGHT", -4, 4)
                        tex:SetTexCoord(0, 1, 0, 1)
                        mb.tex = tex
                        ch.objSec.mapBoxes[mapIndex] = mb
                    end
                    
                    mb.tex:SetTexture(mapPath)
                    mb:ClearAllPoints()
                    mb:SetPoint("TOPLEFT", prevAnchor, "BOTTOMLEFT", -26, -15)
                    mb:SetPoint("TOPRIGHT", ch.objSec, "TOPRIGHT", -8, 0)
                    
                    mb:SetHeight(320)
                    mb:Show()
                    prevAnchor = mb
                    mapIndex = mapIndex + 1
                end
            end
        end

        LayoutDetailSections(ch)

        -- Calculate total height of the content dynamically
        local totalHeight = 40
        if prevAnchor and prevAnchor.GetBottom and ch.objSec:GetTop() then
            totalHeight = ch.objSec:GetTop() - prevAnchor:GetBottom() + 20
        end
        ch.objSec:SetHeight(math.max(320, totalHeight))
        
        local dHeight = 0
        if ch.header:GetTop() and ch.objSec:GetBottom() then
             dHeight = ch.header:GetTop() - ch.objSec:GetBottom() + 20
        end
        ch:SetHeight(math.max(DetailPanel.scroll:GetHeight() or 320, dHeight))

    else
        ch.header:Hide()
        ch.objSec:Hide()
        ch.descSec:Hide()
        ch.npcSec:Hide()
    -- [WotLK Classic] ch.linkSec:Hide()
        ch.mapBox:Hide()
        ch.questImgBox:Hide()
        ch.objSec.tomtomBtn:Hide()
        ch.objSec.box:Show()
        LayoutDetailSections(ch)
    end
end

-- ============================================================
--  INTERCAMBIO DE PESTAÑAS (SWITCH TAB)
-- ============================================================
function addon:SwitchTab(tabId)
    activeTab = tabId

    -- Paneles de guía Pro: ocultos salvo que la pestaña "guide" los active
    if GuideCardsPanel then GuideCardsPanel:Hide() end
    if GuideLockPanel then GuideLockPanel:Hide() end
    if addon.GuideSoonPanel then addon.GuideSoonPanel:Hide() end
    if addon.GuideCardsPanel then addon.GuideCardsPanel:Hide() end
    if addon.GuideLockPanel then addon.GuideLockPanel:Hide() end
    if ZonesMapPanel then ZonesMapPanel:Hide() end
    if ListPanel and ListPanel.levelBar then ListPanel.levelBar:Hide() end
    if addon.ZonesListPanel then addon.ZonesListPanel:Hide() end

    -- Gating Pro de la pestaña Guía: candado (bloqueado) o rejilla (sin elegir)
    if tabId == "guide" then
        SettingsPanel:Hide(); AboutPanel:Hide()
        ListPanel:Hide(); DetailPanel:Hide(); RightSidebar:Hide()
        if ListPanel.guideFiltersFrame then ListPanel.guideFiltersFrame:Hide() end
        if ListPanel.zoneFiltersFrame then ListPanel.zoneFiltersFrame:Hide() end
        
        if not addon.GuideSoonPanel then
            local gSoon = CreateFrame("Frame", nil, MainFrame)
            gSoon:SetPoint("TOPLEFT", ListPanel, "TOPLEFT", 0, 0)
            gSoon:SetPoint("BOTTOMRIGHT", MainFrame, "BOTTOMRIGHT", -10, 10)
            ApplyBD(gSoon, C.bgList, C.borderDim, 8)
            
            local soonText = gSoon:CreateFontString(nil, "OVERLAY", "GameFontHighlightLarge")
            soonText:SetPoint("CENTER", 0, 0)
            soonText:SetText(IsSpanish() and "Próximamente en futuras actualizaciones" or "Coming soon in future updates")
            soonText:SetTextColor(C.gold[1], C.gold[2], C.gold[3])
            
            addon.GuideSoonPanel = gSoon
        end
        addon.GuideSoonPanel:Show()
        if MainFrame and MainFrame.titleText then MainFrame.titleText:SetText(IsSpanish() and "Guías" or "Guides") end
        addon:ApplyTheme()
        return
    end

    if tabId == "settings" then
        if ListPanel.zonePanel then ListPanel.zonePanel:Hide() end
        if ListPanel.UpdateAnchor then ListPanel.UpdateAnchor() end
        ListPanel:Hide()
        DetailPanel:Hide()
        RightSidebar:Hide()
        AboutPanel:Hide()
        SettingsPanel:Show()
    elseif tabId == "about" then
        if ListPanel.zonePanel then ListPanel.zonePanel:Hide() end
        if ListPanel.UpdateAnchor then ListPanel.UpdateAnchor() end
        ListPanel:Hide()
        DetailPanel:Hide()
        RightSidebar:Hide()
        SettingsPanel:Hide()
        AboutPanel:Show()
    else
        SettingsPanel:Hide()
        AboutPanel:Hide()
        ListPanel:Show()
        
        if tabId == "zones" then
            DetailPanel:Hide()
            ListPanel:Hide()
            if RightSidebar then RightSidebar:Hide() end
            if ZonesMapPanel then ZonesMapPanel:Hide() end
            if addon.ZonesListPanel then
                addon.ZonesListPanel:Show()
                if addon.RefreshZonesListPanel then addon.RefreshZonesListPanel() end
            end
        else
            DetailPanel:Show()
            if ZonesMapPanel then ZonesMapPanel:Hide() end
            if addon.ZonesListPanel then addon.ZonesListPanel:Hide() end
            if RightSidebar and rightSidebarShown then RightSidebar:Show() end
        end
        
        if ListPanel.scroll then ListPanel.scroll:Show() end  -- el scroll quedaba oculto

        local showZonePanel = (tabId == "quests" or tabId == "questlog")
        if ListPanel.zonePanel then
            if showZonePanel then
                ListPanel.zonePanel:Show()
                if ListPanel.UpdateAnchor then ListPanel.UpdateAnchor() end
                if ListPanel.RefreshZonePanel then ListPanel.RefreshZonePanel() end
            else
                ListPanel.zonePanel:Hide()
                if ListPanel.UpdateAnchor then ListPanel.UpdateAnchor() end
            end
        end

        if tabId == "quests" or tabId == "questlog" then
            ListPanel.filtersFrame:Show()
            if ListPanel.guideFiltersFrame then ListPanel.guideFiltersFrame:Hide() end
            if ListPanel.zoneFiltersFrame then ListPanel.zoneFiltersFrame:Hide() end
            ListPanel.scroll:ClearAllPoints()
            if tabId == "quests" then
                if ListPanel.levelBar then ListPanel.levelBar:Show() end
                ListPanel.scroll:SetPoint("TOPLEFT", ListPanel, "TOPLEFT", 6, -86)
            else
                if ListPanel.levelBar then ListPanel.levelBar:Hide() end
                ListPanel.scroll:SetPoint("TOPLEFT", ListPanel, "TOPLEFT", 6, -38)
            end
            ListPanel.scroll:SetPoint("BOTTOMRIGHT", ListPanel, "BOTTOMRIGHT", -24, 6)
        elseif tabId == "guide" then
            ListPanel.filtersFrame:Hide()
            if ListPanel.zoneFiltersFrame then ListPanel.zoneFiltersFrame:Hide() end
            if ListPanel.guideFiltersFrame then 
                ListPanel.guideFiltersFrame:Show()
                ListPanel.guideFiltersFrame.facBtn.lbl:SetText(addon.db and addon.db.currentGuide == "Alliance" and L("ALLIANCE") or L("HORDE"))
            end
            ListPanel.scroll:ClearAllPoints()
            ListPanel.scroll:SetPoint("TOPLEFT", ListPanel, "TOPLEFT", 6, -38)
            ListPanel.scroll:SetPoint("BOTTOMRIGHT", ListPanel, "BOTTOMRIGHT", -24, 6)
        elseif tabId == "zones" then
            ListPanel.filtersFrame:Hide()
            if ListPanel.guideFiltersFrame then ListPanel.guideFiltersFrame:Hide() end
            if ListPanel.zoneFiltersFrame then 
                ListPanel.zoneFiltersFrame:Show()
                if addon.UpdateZoneFactionFilterUI then addon.UpdateZoneFactionFilterUI() end
            end
            ListPanel.scroll:ClearAllPoints()
            ListPanel.scroll:SetPoint("TOPLEFT", ListPanel, "TOPLEFT", 6, -38)
            ListPanel.scroll:SetPoint("BOTTOMRIGHT", ListPanel, "BOTTOMRIGHT", -24, 6)
        else
            ListPanel.filtersFrame:Hide()
            if ListPanel.guideFiltersFrame then ListPanel.guideFiltersFrame:Hide() end
            if ListPanel.zoneFiltersFrame then ListPanel.zoneFiltersFrame:Hide() end
            ListPanel.scroll:ClearAllPoints()
            ListPanel.scroll:SetPoint("TOPLEFT", ListPanel, "TOPLEFT", 6, -6)
            ListPanel.scroll:SetPoint("BOTTOMRIGHT", ListPanel, "BOTTOMRIGHT", -24, 6)
        end

        UpdateDetailPanelAnchors()
    end

    local faction = addon.db and addon.db.currentGuide or "Alliance"
    local fStr = faction == "Alliance" and L("ALLIANCE") or L("HORDE")
    if tabId == "guide" then
        MainFrame.titleText:SetText(string.format(L("TITLE_GUIDE"), fStr))
    elseif tabId == "questlog" then
        MainFrame.titleText:SetText(L("TITLE_QUESTLOG"))
    elseif tabId == "quests" then
        MainFrame.titleText:SetText(L("TITLE_EXPLORER"))
    elseif tabId == "zones" then
        MainFrame.titleText:SetText(L("TITLE_ZONES"))
    elseif tabId == "settings" then
        MainFrame.titleText:SetText(L("SETTINGS_TITLE"))
    elseif tabId == "about" then
        MainFrame.titleText:SetText(L("TITLE_ABOUT"))
    end

    addon:ApplyTheme()
end

-- Refrescar todos los textos localizables al cambiar idioma
function addon:ApplyLanguage(lang)
    if lang and SKquests_Localization then
        SKquests_Localization:SetLanguage(lang)
    end
    for _, e in ipairs(LocRegistry) do
        local txt = L(e.key)
        if e.tf == "upper" then txt = string.upper(txt) end
        e.fs:SetText(txt)
    end
    if MainFrame then
        selectedZoneFilter = "Todas"
        BuildZonesList()
        BuildFilteredQuestIds()
        BuildGuideChapters()
        addon:SwitchTab(activeTab)
        addon:UpdateListRows()
        if addon.RefreshDetail then addon:RefreshDetail() end
    end
end

SLASH_SKQCALIB1 = "/skqcalib"
SlashCmdList["SKQCALIB"] = function(msg)
    local cmd, val = strsplit(" ", msg or "")
    val = tonumber(val)
    if not val or not _G.SKquests_CustomMapOffsets then
        print("|cff00ff00SKquests Calib:|r Uso: /skqcalib x|y|w|h <valor> (ej: /skqcalib x 0.5)")
        return
    end
    local mapZone = _G.SKquests_UI_CurrentMapZone
    if not mapZone or not _G.SKquests_CustomMapOffsets[mapZone] then
        print("|cff00ff00SKquests Calib:|r Abre una zona custom primero.")
        return
    end
    local calib = _G.SKquests_CustomMapOffsets[mapZone]
    if cmd == "x" then calib[3] = calib[3] + val
    elseif cmd == "y" then calib[4] = calib[4] + val
    elseif cmd == "w" then calib[1] = calib[1] + val
    elseif cmd == "h" then calib[2] = calib[2] + val
    end
    print(string.format("|cff00ff00Calibracion [%d]:|r w=%.2f, h=%.2f, x=%.2f, y=%.2f", mapZone, calib[1], calib[2], calib[3], calib[4]))
    if SKquests.RefreshMap then SKquests:RefreshMap() end
end

-- ============================================================
--  PINES DE QUEST GIVER/ENDER EN EL MAPA DEL MUNDO Y EL MINIMAPA
-- ============================================================
-- Estilo Questie: muestra sobre el WorldMapFrame nativo de Blizzard (tecla M)
-- y sobre el Minimap la ubicacion de los NPCs dadores ("!") y entregadores
-- ("?") de TODAS las quests disponibles/activas de la zona, usando
-- SKquests_DetailDB + las coordenadas de pfDB (pfQuest).

-- Proyecta la coordenada (0-100%) de un NPC al sistema de la zona objetivo,
-- maneja el caso subzona<->zona padre (p.ej. Northshire dentro de Elwynn),
-- reutilizando la misma calibracion (pfDB.zones.data) que ya usa el panel de
-- mapa propio del addon.
local function SKQ_GetNpcCoordInZone(npcId, targetZoneId)
    if not npcId or not targetZoneId then return nil end
    local u = GetUnitData(npcId)
    if not u or not u.coords then return nil end

    -- 1. Coincidencia directa: el NPC tiene coords registradas en esta zona
    for _, c in ipairs(u.coords) do
        if c[3] == targetZoneId then return c[1], c[2] end
    end

    local zonesData = pfDB and pfDB["zones"] and pfDB["zones"]["data"]

    -- 2. El NPC esta en una subzona hija de targetZoneId -> proyectar hijo->padre
    for _, c in ipairs(u.coords) do
        local cz = c[3]
        local czData = cz and zonesData and zonesData[cz]
        if czData and czData[1] == targetZoneId and czData[2] and czData[4] then
            local zw, zh, zx, zy = czData[2], czData[3], czData[4], czData[5]
            return zx + (c[1] * zw / 100), zy + (c[2] * zh / 100)
        end
    end

    -- 3. targetZoneId es una subzona y el NPC esta en la zona padre -> padre->hijo
    local targetData = zonesData and zonesData[targetZoneId]
    local parent = targetData and targetData[1]
    if parent and targetData[2] and targetData[4] then
        for _, c in ipairs(u.coords) do
            if c[3] == parent then
                local zw, zh, zx, zy = targetData[2], targetData[3], targetData[4], targetData[5]
                return (c[1] - zx) * 100 / zw, (c[2] - zy) * 100 / zh
            end
        end
    end
    return nil
end

-- Wrapper de compatibilidad: en clientes modernos (Classic Era/SoD), el
-- global IsQuestFlaggedCompleted fue reemplazado por C_QuestLog.IsQuestFlaggedCompleted
-- y puede no existir como global suelto -> sin este wrapper, la condicion
-- "IsQuestFlaggedCompleted and ..." se evaluaba directo a false y TODAS las
-- quests ya completadas se mostraban para siempre como disponibles ("!").
local function SKQ_IsQuestCompletedCompat(questId)
    if not questId then return false end
    if C_QuestLog and C_QuestLog.IsQuestFlaggedCompleted then
        return C_QuestLog.IsQuestFlaggedCompleted(questId) == true
    end
    if IsQuestFlaggedCompleted then
        return IsQuestFlaggedCompleted(questId) == true
    end
    return false
end

-- Estado de una quest para decidir que pin mostrar: "active"/"complete"
-- (esta en el log) o "available" (no iniciada y no completada de forma
-- permanente). Devuelve nil si no se debe mostrar ningun pin.
local function SKQ_GetQuestPinStatus(questId)
    if not questId then return nil end
    local active = addon.Tracker and addon.Tracker:GetActiveQuests()
    if active then
        for _, entry in pairs(active) do
            if entry.id == questId then
                return entry.isComplete and "complete" or "active"
            end
        end
    end
    if SKQ_IsQuestCompletedCompat(questId) then
        return nil
    end
    -- Quests de cadena (campo prevId en la DB): el NPC todavia no la ofrece
    -- de verdad si la quest anterior de la cadena no esta completada de
    -- forma permanente
    local q = SKquests_DetailDB and SKquests_DetailDB[questId]
    if q then
        if q.minLevel and UnitLevel("player") < q.minLevel then
            return nil
        end
        if q.prevId and not SKQ_IsQuestCompletedCompat(q.prevId) then
            return nil
        end
    end
    if SKquests.hiddenQuests and SKquests.hiddenQuests[questId] then
        return nil
    end
    return "available"
end

-- Indice estatico (zoneId -> lista de quests de SKquests_DetailDB en esa
-- zona). SKquests_DetailDB no cambia en tiempo de ejecucion, asi que esto se
-- calcula una sola vez por zona y se cachea para no recorrer toda la DB en
-- cada refresh del minimapa.
local skqZoneQuestsStaticCache = {}
local function SKQ_GetZoneQuestsStatic(zoneId)
    if not zoneId then return {} end
    local cached = skqZoneQuestsStaticCache[zoneId]
    if cached then return cached end
    local list = {}
    if SKquests_DetailDB then
        for questId, q in pairs(SKquests_DetailDB) do
            if q.zoneId == zoneId then
                table.insert(list, { questId = questId, q = q })
            end
        end
    end
    skqZoneQuestsStaticCache[zoneId] = list
    return list
end

-- Lista final de pines a mostrar para una zona: NPC a usar (giver si esta
-- disponible, ender si esta activa/completa) + estado.
local function SKQ_GetZoneQuestPins(zoneId)
    local out = {}
    for _, item in ipairs(SKQ_GetZoneQuestsStatic(zoneId)) do
        local q = item.q
        local status = SKQ_GetQuestPinStatus(item.questId)
        if status then
            local npcId, npcType
            if status == "available" then
                npcId, npcType = q.giverId, q.giverType
            else
                npcId, npcType = q.enderId or q.giverId, q.enderType or q.giverType
            end
            if npcId and npcType ~= "GO" then
                table.insert(out, { questId = item.questId, npcId = npcId, status = status, q = q })
            end
        end
    end
    return out
end

local function SKQ_PinIconFor(status)
    if status == "available" then return "Interface\\GossipFrame\\AvailableQuestIcon" end
    if status == "complete" then return "Interface\\GossipFrame\\ActiveQuestIcon" end
    return "Interface\\GossipFrame\\IncompleteQuestIcon"
end

-- ----------------------------------------------------------
--  WORLDMAPFRAME (tecla M)
-- ----------------------------------------------------------
local SKQ_QUEST_COLORS = {
    {0, 0.8, 1},   -- default light blue
    {0, 1, 0},     -- green
    {1, 1, 0},     -- yellow
    {1, 0.5, 0},   -- orange
    {1, 0, 1},     -- magenta
    {1, 0, 0},     -- red
    {0.5, 0, 1},   -- purple
    {1, 1, 1},     -- white
}
local SKQ_RefreshWorldMapPins
local SKQ_RefreshMinimapPinsFull
local function SKQ_CycleQuestColor(qId)
    if not qId then return end
    SKquestsDB.questColors = SKquestsDB.questColors or {}
    local current = SKquestsDB.questColors[qId]
    local idx = 1
    if current then
        for i, c in ipairs(SKQ_QUEST_COLORS) do
            if math.abs(c[1]-current[1]) < 0.01 and math.abs(c[2]-current[2]) < 0.01 and math.abs(c[3]-current[3]) < 0.01 then
                idx = i
                break
            end
        end
    end
    local nextIdx = (idx % #SKQ_QUEST_COLORS) + 1
    SKquestsDB.questColors[qId] = SKQ_QUEST_COLORS[nextIdx]
    if SKQ_RefreshWorldMapPins then SKQ_RefreshWorldMapPins() end
    if SKQ_RefreshMinimapPinsFull then SKQ_RefreshMinimapPinsFull() end
end

local function SKQ_GetQuestColor(qId)
    if SKquestsDB and SKquestsDB.questColors and SKquestsDB.questColors[qId] then
        local c = SKquestsDB.questColors[qId]
        return c[1], c[2], c[3]
    end
    return 0, 0.8, 1
end

local skqWorldMapPins = {}
local skqWorldMapPinCount = 0

local function SKQ_GetWorldMapPin(i)
    local pin = skqWorldMapPins[i]
    if not pin then
        pin = CreateFrame("Frame", nil, WorldMapDetailFrame)
        pin:SetSize(10, 10)
        pin:SetFrameStrata("TOOLTIP")
        local tex = pin:CreateTexture(nil, "OVERLAY")
        tex:SetAllPoints()
        pin.tex = tex
        pin:EnableMouse(true)
        pin:SetScript("OnEnter", function(self)
            GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
            GameTooltip:SetText(self.label or "", 1, 1, 1)
            if self.sub then GameTooltip:AddLine(self.sub, 1, 0.82, 0, true) end
            GameTooltip:AddLine("<Click derecho para cambiar color>", 0.5, 0.5, 0.5)
            GameTooltip:Show()
        end)
        pin:SetScript("OnLeave", function() GameTooltip:Hide() end)
        pin:SetScript("OnMouseUp", function(self, button)
            if button == "RightButton" and self.qId then
                if IsShiftKeyDown() then
                    if not SKquests.hiddenQuests then SKquests.hiddenQuests = {} end
                    if not SKquestsDB.hiddenQuests then SKquestsDB.hiddenQuests = {} end
                    SKquests.hiddenQuests[self.qId] = true
                    SKquestsDB.hiddenQuests[self.qId] = true
                    print(IsSpanish() and "|cff00ff00SKquests:|r Misión oculta del mapa. Para volver a verla, usa /skq unhide" or "|cff00ff00SKquests:|r Quest hidden from map. To unhide it, use /skq unhide")
                    if SKQ_RefreshWorldMapPins then SKQ_RefreshWorldMapPins() end
                    if SKQ_RefreshMinimapPinsFull then SKQ_RefreshMinimapPinsFull() end
                else
                    SKQ_CycleQuestColor(self.qId)
                end
            end
        end)
        skqWorldMapPins[i] = pin
    end
    return pin
end

local function SKQ_HideWorldMapPins()
    for i = 1, skqWorldMapPinCount do skqWorldMapPins[i]:Hide() end
    skqWorldMapPinCount = 0
end
local function SKQ_GetActiveQuestIds()
    local ids = {}
    if type(GetNumQuestLogEntries) ~= "function" then return ids end
    local n = GetNumQuestLogEntries() or 0
    for i = 1, n do
        local title, _, _, isHeader, _, isComplete, _, questID = GetQuestLogTitle(i)
        if not isHeader and questID and questID > 0 then
            ids[questID] = title
        end
    end
    return ids
end

local zoneIdToModernMapIdCache
local modernMapIdToZoneIdCache
local function SKQ_InitMapIdCaches()
    if zoneIdToModernMapIdCache then return end
    zoneIdToModernMapIdCache = {}
    modernMapIdToZoneIdCache = {}
    local nameToMapId = {}
    for i = 1, 2000 do
        local name = HBD:GetLocalizedMap(i)
        if name then nameToMapId[SKQ_NormZoneName(name)] = i end
    end
    if pfDB and pfDB["zones"] then
        for _, locTable in pairs(pfDB["zones"]) do
            for id, nm in pairs(locTable) do
                if type(nm) == "string" and nm ~= "" then
                    local uiMapID = nameToMapId[SKQ_NormZoneName(nm)]
                    if uiMapID and not zoneIdToModernMapIdCache[id] then
                        zoneIdToModernMapIdCache[id] = uiMapID
                        modernMapIdToZoneIdCache[uiMapID] = id
                    end
                end
            end
        end
    end
    if ZoneMap then
        for id, nm in pairs(ZoneMap) do
            if type(nm) == "string" and nm ~= "" then
                local uiMapID = nameToMapId[SKQ_NormZoneName(nm)]
                if uiMapID and not zoneIdToModernMapIdCache[id] then
                    zoneIdToModernMapIdCache[id] = uiMapID
                    modernMapIdToZoneIdCache[uiMapID] = id
                end
            end
        end
    end
end

local function SKQ_GetPfDBZoneForModernMapID(uiMapID)
    if not uiMapID then return nil end
    SKQ_InitMapIdCaches()
    return modernMapIdToZoneIdCache[uiMapID]
end

SKQ_RefreshWorldMapPins = function()
    if not WorldMapFrame or not WorldMapFrame:IsShown() then HBDPins:RemoveAllWorldMapIcons(addon); return end
    if SKquestsDB and SKquestsDB.config and SKquestsDB.config.showMapPins == false then
        HBDPins:RemoveAllWorldMapIcons(addon); return
    end

    HBDPins:RemoveAllWorldMapIcons(addon)

    local mapId = WorldMapFrame:GetMapID()
    if not mapId then return end
    
    local zoneId = SKQ_GetPfDBZoneForModernMapID(mapId)
    if not zoneId then return end -- Si es Kalimdor u otro continente, zoneId es nil, no se dibuja nada

    local n = 0
    
    -- 1. Quest Givers
    for _, p in ipairs(SKQ_GetZoneQuestPins(zoneId)) do
        local x, y = SKQ_GetNpcCoordInZone(p.npcId, zoneId)
        if x and y then
            n = n + 1
            local pin = SKQ_GetWorldMapPin(n)
            pin.tex:SetTexture(SKQ_PinIconFor(p.status))
            pin.tex:SetTexCoord(0, 1, 0, 1)
            pin.tex:SetVertexColor(1, 1, 1)
            pin.label = GetLocalizedQuestName(p.q) or p.q.name
            pin.sub = UnitDisplayName(p.npcId)
            pin.qId = p.questId
            
            -- 1 = HBD_PINS_WORLDMAP_SHOW_PARENT (solo zona actual o su padre si esta configurado)
            HBDPins:AddWorldMapIconMap(addon, pin, mapId, x/100, y/100, 1)
        end
    end

    -- 2. Quest Objectives
    if SKquests_ObjectiveLinks and SKquests_SpawnData then
        local activeQuestsDict = addon.Tracker and addon.Tracker:GetActiveQuests() or {}
        local activeQuests = SKQ_GetActiveQuestIds()
        for qId, qTitle in pairs(activeQuests) do
            local qEntry = nil
            for i = 1, 100 do
                if activeQuestsDict[i] and activeQuestsDict[i].id == qId then
                    qEntry = activeQuestsDict[i]
                    break
                end
            end
            
            if not qEntry or not qEntry.isComplete then
                local links = SKquests_ObjectiveLinks[qId]
                if links then
                    local idsToSpawn = {}
                    for _, id in ipairs(links.npcs or {}) do idsToSpawn[id] = { type="npc", icon="slay_mono.tga" } end
                    for _, id in ipairs(links.item_npcs or {}) do idsToSpawn[id] = { type="npc", icon="slay_mono.tga" } end
                    for _, id in ipairs(links.objects or {}) do idsToSpawn[id] = { type="object", icon="loot_mono.tga" } end
                    for _, id in ipairs(links.item_objects or {}) do idsToSpawn[id] = { type="object", icon="loot_mono.tga" } end
                    
                    for id, info in pairs(idsToSpawn) do
                        local spawnInfo = SKquests_SpawnData[info.type .. "s"] and SKquests_SpawnData[info.type .. "s"][id]
                        -- Solo iteramos los spawns en la zona especifica que estamos mirando
                        if spawnInfo and spawnInfo.spawns and spawnInfo.spawns[zoneId] and not SKQ_IsObjectiveFinished(qEntry, spawnInfo.name) then
                            for _, coord in ipairs(spawnInfo.spawns[zoneId]) do
                                local x, y = coord[1], coord[2]
                                n = n + 1
                                local pin = SKQ_GetWorldMapPin(n)
                                pin.tex:SetTexture("Interface\\AddOns\\SKquests\\Media\\textures\\QuestieIcons\\" .. info.icon)
                                pin.tex:SetTexCoord(0, 1, 0, 1)
                                pin.tex:SetVertexColor(SKQ_GetQuestColor(qId))
                                pin.label = qTitle or tostring(qId)
                                pin.sub = spawnInfo.name or "Objetivo"
                                pin.qId = qId
                                
                                HBDPins:AddWorldMapIconMap(addon, pin, mapId, x/100, y/100, 1)
                            end
                        end
                    end
                end
            end
        end
    end
    for i = n + 1, skqWorldMapPinCount do skqWorldMapPins[i]:Hide() end
    skqWorldMapPinCount = n
end

-- NOTA: "WORLD_MAP_UPDATE" no existe como evento en este cliente (lanzaba
-- "Attempt to register unknown event", lo que abortaba el resto de la carga
-- de este archivo y producia errores en cascada en CreateModernUI). En vez
-- de depender de un evento, se usa un ticker liviano que solo corre mientras
-- el mapa esta abierto -- igual de fiable y no depende del nombre exacto de
-- ningun evento de este cliente en particular.
local skqWorldMapWatcher = CreateFrame("Frame")
skqWorldMapWatcher:RegisterEvent("QUEST_LOG_UPDATE")
skqWorldMapWatcher:SetScript("OnEvent", function()
    if WorldMapFrame and WorldMapFrame:IsShown() then SKQ_RefreshWorldMapPins() end
end)
skqWorldMapWatcher.acc = 0
skqWorldMapWatcher:SetScript("OnUpdate", function(self, elapsed)
    if not (WorldMapFrame and WorldMapFrame:IsShown()) then return end
    self.acc = self.acc + elapsed
    if self.acc < 0.3 then return end
    self.acc = 0
    SKQ_RefreshWorldMapPins()
end)
if WorldMapFrame then
    WorldMapFrame:HookScript("OnShow", SKQ_RefreshWorldMapPins)
    WorldMapFrame:HookScript("OnHide", SKQ_HideWorldMapPins)
end

-- ----------------------------------------------------------
--  MINIMAP
-- ----------------------------------------------------------
-- NOTA: el cliente 3.3.5a no expone una API limpia para "cuantas yardas
-- representa el radio del minimapa en este nivel de zoom". Las tablas de
-- abajo son las constantes de uso comun en addons de esa era. Si los pines
-- del minimapa aparecen sistematicamente mas cerca o mas lejos de lo real,
-- ajustar SKQ_MINIMAP_SCALE (p.ej. 0.9 o 1.1) es el arreglo esperado.
local SKQ_MINIMAP_SCALE = 1.0
local MINIMAP_RADIUS_YARDS_OUTDOOR = { [0] = 333.33, [1] = 266.66, [2] = 200.0,  [3] = 133.33, [4] = 66.66,  [5] = 33.33 }
local MINIMAP_RADIUS_YARDS_INDOOR  = { [0] = 200.0,  [1] = 166.66, [2] = 133.33, [3] = 100.0,  [4] = 66.66,  [5] = 33.33 }
local MINIMAP_RADIUS_YARDS_CITY    = { [0] = 133.33, [1] = 100.0,  [2] = 66.66,  [3] = 33.33,  [4] = 16.66,  [5] = 10.0  }

-- Radio fijo (en yardas) usado para decidir si un pin entra en rango del
-- minimapa y para escalar su posicion a pixeles. A pedido: no depende del
-- zoom actual del minimapa (Minimap:GetZoom()), que resulto poco confiable
-- como fuente de esa escala. Ajustar este numero si el rango se ve muy
-- chico/grande comparado con el radio real del minimapa.
local SKQ_MINIMAP_FIXED_RADIUS_YARDS = 400

local skqMinimapPins = {}
local skqMinimapPinCount = 0

local function SKQ_GetMinimapPin(i)
    local pin = skqMinimapPins[i]
    if not pin then
        pin = CreateFrame("Frame", nil, Minimap)
        pin:SetSize(10, 10)
        pin:SetFrameStrata("TOOLTIP")
        local tex = pin:CreateTexture(nil, "OVERLAY")
        tex:SetAllPoints()
        pin.tex = tex
        pin:EnableMouse(true)
        pin:SetScript("OnEnter", function(self)
            GameTooltip:SetOwner(self, "ANCHOR_LEFT")
            GameTooltip:SetText(self.label or "", 1, 1, 1)
            if self.sub then GameTooltip:AddLine(self.sub, 1, 0.82, 0, true) end
            GameTooltip:AddLine("<Click derecho para cambiar color>", 0.5, 0.5, 0.5)
            GameTooltip:Show()
        end)
        pin:SetScript("OnLeave", function() GameTooltip:Hide() end)
        pin:SetScript("OnMouseUp", function(self, button)
            if button == "RightButton" and self.qId then
                if IsShiftKeyDown() then
                    if not SKquests.hiddenQuests then SKquests.hiddenQuests = {} end
                    if not SKquestsDB.hiddenQuests then SKquestsDB.hiddenQuests = {} end
                    SKquests.hiddenQuests[self.qId] = true
                    SKquestsDB.hiddenQuests[self.qId] = true
                    print(IsSpanish() and "|cff00ff00SKquests:|r Misión oculta del mapa. Para volver a verla, usa /skq unhide" or "|cff00ff00SKquests:|r Quest hidden from map. To unhide it, use /skq unhide")
                    if SKQ_RefreshWorldMapPins then SKQ_RefreshWorldMapPins() end
                    if SKQ_RefreshMinimapPinsFull then SKQ_RefreshMinimapPinsFull() end
                else
                    SKQ_CycleQuestColor(self.qId)
                end
            end
        end)
        skqMinimapPins[i] = pin
    end
    return pin
end

local function SKQ_HideMinimapPins()
    for i = 1, skqMinimapPinCount do skqMinimapPins[i]:Hide() end
    skqMinimapPinCount = 0
end

local function SKQ_GetMinimapRadiusYards()
    local zoom = Minimap:GetZoom() or 0
    local isIndoor = IsIndoors and IsIndoors()
    local tbl = isIndoor and MINIMAP_RADIUS_YARDS_INDOOR or MINIMAP_RADIUS_YARDS_OUTDOOR
    return (tbl[zoom] or tbl[0] or 200) * SKQ_MINIMAP_SCALE
end

-- addon:GetPlayerMapCoords() llama internamente a SetMapToCurrentZone(), que
-- cambia la zona/continente seleccionados del WorldMapFrame como efecto
-- secundario. Como este refresh corre cada segundo SIEMPRE (no solo con el
-- mapa abierto), eso pelearia con cualquier navegacion manual del jugador en
-- el mapa del mundo (p.ej. mirando una zona distinta a la propia). Por eso
-- guardamos la seleccion previa y la restauramos justo despues de leer la
-- posicion del jugador.
local function SKQ_GetPlayerCoordsSafe()
    local prevContinent = GetCurrentMapContinent and GetCurrentMapContinent()
    local prevZone = GetCurrentMapZone and GetCurrentMapZone()
    local px, py
    if addon.GetPlayerMapCoords then px, py = addon:GetPlayerMapCoords() end
    if prevContinent and prevZone and SetMapZoom then
        SetMapZoom(prevContinent, prevZone)
    end
    return px, py
end

-- Cache de pines "activos" decididos por el ultimo pase completo (full pass):
-- coords crudas (%) del NPC y dims de zona usadas para convertirlas a yardas.
-- El pase barato (reposition) usa esta cache para reubicar pines en cada tick
-- SIN volver a escanear quests/zona. Antes, el pase completo (filtrar que NPC
-- entra en rango, decidir icono/label, escanear SKQ_GetZoneQuestPins) corria
-- entero 10 veces por segundo: cualquier bache transitorio en ese escaneo
-- (orden de iteracion del log de quests, cache no actualizada todavia, etc.)
-- podia hacer que un pin se ocultara y volviera a aparecer de un tick a otro,
-- lo que se percibe como que la quest "se refresca" en vez de quedarse
-- estatica. Separar "decidir que pin mostrar" (poco frecuente) de "donde
-- dibujarlo" (muy frecuente, pura matematica con datos ya decididos) es el
-- mismo patron que usa HereBeDragons-Pins, la libreria de minimapa que usa
-- Questie para este mismo problema.

SKQ_RefreshMinimapPinsFull = function()
    if SKquestsDB and SKquestsDB.config and SKquestsDB.config.showMapPins == false then
        HBDPins:RemoveAllMinimapIcons(addon)
        return
    end
    if WorldMapFrame and WorldMapFrame:IsShown() then return end
    
    HBDPins:RemoveAllMinimapIcons(addon)
    
    local realZone = GetRealZoneText and GetRealZoneText()
    local zoneId = realZone and SKQ_ResolveZoneIdFromRealZone(realZone)
    if not zoneId then return end
    
    local mapId = C_Map and C_Map.GetBestMapForUnit and C_Map.GetBestMapForUnit("player")
    if not mapId then return end
    
    local n = 0
    
    -- 1. Quest Givers and Enders
    for _, p in ipairs(SKQ_GetZoneQuestPins(zoneId)) do
        local x, y = SKQ_GetNpcCoordInZone(p.npcId, zoneId)
        if x and y then
            n = n + 1
            local pin = SKQ_GetMinimapPin(n)
            pin.tex:SetTexture(SKQ_PinIconFor(p.status))
            pin.tex:SetTexCoord(0, 1, 0, 1) -- Reset tex coord
            pin.tex:SetVertexColor(1, 1, 1) -- Reset color
            pin.label = GetLocalizedQuestName(p.q) or p.q.name
            pin.sub = UnitDisplayName(p.npcId)
            pin.qId = p.questId
            
            HBDPins:AddMinimapIconMap(addon, pin, mapId, x/100, y/100, true, false)
        end
    end
    
    -- 2. Quest Objectives (Mobs/Items)
    if SKquests_ObjectiveLinks and SKquests_SpawnData then
        local activeQuestsDict = addon.Tracker and addon.Tracker:GetActiveQuests() or {}
        local activeQuests = SKQ_GetActiveQuestIds()
        for qId, qTitle in pairs(activeQuests) do
            local qEntry = nil
            for i = 1, 100 do
                if activeQuestsDict[i] and activeQuestsDict[i].id == qId then
                    qEntry = activeQuestsDict[i]
                    break
                end
            end
            
            if not qEntry or not qEntry.isComplete then
                local links = SKquests_ObjectiveLinks[qId]
                if links then
                    local idsToSpawn = {}
                    for _, id in ipairs(links.npcs or {}) do idsToSpawn[id] = { type="npc", icon="slay_mono.tga" } end
                    for _, id in ipairs(links.item_npcs or {}) do idsToSpawn[id] = { type="npc", icon="slay_mono.tga" } end
                    for _, id in ipairs(links.objects or {}) do idsToSpawn[id] = { type="object", icon="loot_mono.tga" } end
                    for _, id in ipairs(links.item_objects or {}) do idsToSpawn[id] = { type="object", icon="loot_mono.tga" } end
                    
                    for id, info in pairs(idsToSpawn) do
                        local spawnInfo = SKquests_SpawnData[info.type .. "s"] and SKquests_SpawnData[info.type .. "s"][id]
                        if spawnInfo and spawnInfo.spawns and spawnInfo.spawns[zoneId] and not SKQ_IsObjectiveFinished(qEntry, spawnInfo.name) then
                            for _, coord in ipairs(spawnInfo.spawns[zoneId]) do
                                local x, y = coord[1], coord[2]
                                n = n + 1
                                local pin = SKQ_GetMinimapPin(n)
                                pin.tex:SetTexture("Interface\\AddOns\\SKquests\\Media\\textures\\QuestieIcons\\" .. info.icon)
                                pin.tex:SetTexCoord(0, 1, 0, 1) -- Reset tex coord
                                pin.tex:SetVertexColor(SKQ_GetQuestColor(qId))
                                pin.label = qTitle or tostring(qId)
                                pin.sub = spawnInfo.name or "Objetivo"
                                pin.qId = qId
                                
                                HBDPins:AddMinimapIconMap(addon, pin, mapId, x/100, y/100, true, false)
                            end
                        end
                    end
                end
            end
        end
    end
    
    for i = n + 1, skqMinimapPinCount do skqMinimapPins[i]:Hide() end
    skqMinimapPinCount = n
end

local function SKQ_RefreshMinimapPins()
    SKQ_RefreshMinimapPinsFull()
end

-- Comando de diagnostico: imprime los numeros crudos del calculo de pines
-- del minimapa (posicion del jugador, dims de zona, yardas/radio, pixeles)
-- para poder detectar a ojo si algo no se actualiza o esta mal escalado.
SLASH_SKQPINS1 = "/skqpins"
SlashCmdList["SKQPINS"] = function()
    local realZone = GetRealZoneText and GetRealZoneText()
    local zoneId = realZone and SKQ_ResolveZoneIdFromRealZone(realZone)
    print(string.format("|cff00ff00SKquests pins debug:|r zona=%s zoneId=%s", tostring(realZone), tostring(zoneId)))
    if not zoneId then return end
    local px, py = SKQ_GetPlayerCoordsSafe()
    print(string.format("  jugador px=%s py=%s", tostring(px), tostring(py)))
    local dims = pfDB and pfDB["minimap"] and pfDB["minimap"][zoneId]
    if not dims then
        print("  dims: NO HAY (pfDB.minimap[zoneId] vacio)")
        return
    end
    print(string.format("  dims zoneWidthYards=%.1f zoneHeightYards=%.1f", dims[1], dims[2]))
    local radiusYards = SKQ_MINIMAP_FIXED_RADIUS_YARDS
    local scaleRadiusYards = SKQ_GetMinimapRadiusYards() or radiusYards
    local mmRadiusPx = (Minimap:GetWidth() or 140) / 2
    print(string.format("  zoom=%s radiusYards=%.1f (fijo, rango) scaleRadiusYards=%.1f (real, escala) mmRadiusPx=%.1f", tostring(Minimap:GetZoom()), radiusYards, scaleRadiusYards, mmRadiusPx))
    if not px or not py then return end
    local zoneWidthYards, zoneHeightYards = SKQ_GetModernZoneDimensionsYards(dims[1], dims[2])
    for _, p in ipairs(SKQ_GetZoneQuestPins(zoneId)) do
        local x, y = SKQ_GetNpcCoordInZone(p.npcId, zoneId)
        if x and y then
            local dxYards = (x - px) / 100 * zoneWidthYards
            local dyYards = (y - py) / 100 * zoneHeightYards
            local dxPx = (dxYards / scaleRadiusYards) * mmRadiusPx
            local dyPx = (dyYards / scaleRadiusYards) * mmRadiusPx
            local dist = math.sqrt(dxYards * dxYards + dyYards * dyYards)
            print(string.format("  [%s] %s npc(x=%.1f,y=%.1f) d=(%.1f,%.1f)yd px=(%.1f,%.1f) dist=%.0fyd",
                p.status, (p.q and p.q.name) or "?", x, y, dxYards, dyYards, dxPx, dyPx, dist))
        else
            print(string.format("  [%s] %s -> SIN COORDS NPC (npcId=%s)", p.status, (p.q and p.q.name) or "?", tostring(p.npcId)))
        end
    end
end

local skqMinimapWatcher = CreateFrame("Frame")
skqMinimapWatcher.acc = 0
skqMinimapWatcher.fullAcc = 0
skqMinimapWatcher:SetScript("OnUpdate", function(self, elapsed)
    -- Pase completo (decide que pin va, icono, label): cada 0.75s. Es el
    -- unico que reescanea quests/zona, asi que cualquier bache transitorio
    -- de ese escaneo solo puede notarse, como mucho, una vez cada 0.75s
    -- en vez de 10 veces por segundo.
    self.fullAcc = self.fullAcc + elapsed
    if self.fullAcc >= 0.75 then
        self.fullAcc = 0
        self.acc = 0
        SKQ_RefreshMinimapPinsFull()
        return
    end
    -- Pase barato eliminado: HereBeDragons-Pins maneja la actualizacion
    -- de posiciones en cada frame de forma nativa e interna.
end)
-- Cambios de zoom o de zona deben reflejarse al instante, no esperar hasta
-- 0.75s al siguiente pase completo periodico.
skqMinimapWatcher:RegisterEvent("MINIMAP_UPDATE_ZOOM")
skqMinimapWatcher:RegisterEvent("ZONE_CHANGED_NEW_AREA")
skqMinimapWatcher:RegisterEvent("ZONE_CHANGED")
skqMinimapWatcher:RegisterEvent("ZONE_CHANGED_INDOORS")
skqMinimapWatcher:SetScript("OnEvent", function(self)
    self.acc, self.fullAcc = 0, 0
    SKQ_RefreshMinimapPinsFull()
end)

-- ============================================================
--  INTERACTIVE MINI-TRACKER FEATURE IMPLEMENTATION
-- ============================================================
local titleButtons = {}
local objectiveStrings = {}
local expandButtons = {}

function addon:ShowQuest(questId)
    -- 1. Asegurar/mostrar ventana principal
    addon:ShowFrame()
    
    -- 2. Buscar la quest en el quest log activo
    local activeQuests = addon.Tracker and addon.Tracker:GetActiveQuests() or {}
    local logIndex = nil
    
    -- Buscar por ID
    for idx, entry in pairs(activeQuests) do
        if entry.id == questId then
            logIndex = idx
            break
        end
    end
    
    -- Fallback: buscar por nombre coincidente
    if not logIndex and SKquests_DetailDB then
        local q = SKquests_DetailDB[questId]
        local qTitle = q and q.name
        if qTitle then
            for idx, entry in pairs(activeQuests) do
                if entry.title:lower() == qTitle:lower() then
                    logIndex = idx
                    break
                end
            end
        end
    end
    
    -- 3. Cambiar a la pestaña del Quest Log
    addon:SwitchTab("questlog")
    
    if logIndex then
        selectedQuestLogIdx = logIndex
        selectedQuestId = nil
        
        -- Obtener lista ordenada alfabéticamente tal como se renderiza en la UI
        local activeQuestsList = {}
        for idx, entry in pairs(activeQuests) do
            table.insert(activeQuestsList, { idx = idx, entry = entry })
        end
        table.sort(activeQuestsList, function(a, b)
            local ta = a.entry.title or ""
            local tb = b.entry.title or ""
            return ta < tb
        end)
        
        -- Buscar la posición en la lista ordenada
        local listIndex = nil
        for i, item in ipairs(activeQuestsList) do
            if item.idx == logIndex then
                listIndex = i
                break
            end
        end
        
        -- Hacer scroll hasta la posición seleccionada
        if listIndex and ListPanel and ListPanel.scroll then
            local visibleRows = 18
            local h = ListPanel.scroll:GetHeight()
            if h and h > 0 then
                visibleRows = math.min(MAX_ROWS, math.floor(h / ROW_H))
                if visibleRows < 1 then visibleRows = 18 end
            end
            local offset = math.max(0, listIndex - math.floor(visibleRows / 2))
            local maxOffset = math.max(0, #activeQuestsList - visibleRows)
            if offset > maxOffset then offset = maxOffset end
            FauxScrollFrame_SetOffset(ListPanel.scroll, offset)
            local sbar = _G[ListPanel.scroll:GetName() .. "ScrollBar"]
            if sbar then sbar:SetValue(offset * ROW_H) end
        end
    end
    
    -- 4. Actualizar filas y detalles
    addon:UpdateListRows()
    addon:RefreshDetail()
end

function addon:CreateMiniTracker()
    if SKquests_MiniTracker then return end

    local mt = CreateFrame("Frame", "SKquests_MiniTracker", UIParent)
    mt:SetSize(SKquests.config.trackerWidth or 260, SKquests.config.trackerHeight or 300)
    mt:SetPoint("TOPRIGHT", UIParent, "TOPRIGHT", -200, -200)
    mt:SetMovable(true)
    mt:EnableMouse(true)
    mt:SetClampedToScreen(true)
    mt:RegisterForDrag("LeftButton")
    mt:SetScript("OnDragStart", function(self)
        if not SKquests.config.locked then
            self:StartMoving()
        end
    end)
    mt:SetScript("OnDragStop", function(self)
        self:StopMovingOrSizing()
        self:SetUserPlaced(true)
    end)
    
    mt:SetResizable(true)
    if mt.SetResizeBounds then
        mt:SetResizeBounds(180, 80, 400, 600)
    else
        mt:SetMinResize(180, 80)
        mt:SetMaxResize(400, 600)
    end
    mt:SetScript("OnSizeChanged", function(self, w, h)
        if w and h and w > 0 and h > 0 then
            SKquests.config.trackerWidth = w
            SKquests.config.trackerHeight = h
            SKquestsDB.config.trackerWidth = w
            SKquestsDB.config.trackerHeight = h
        end
    end)
    
    -- Barra de cabecera (Header/Title bar) - Ajustado a todo el ancho (0, 0)
    local header = CreateFrame("Frame", nil, mt)
    header:SetHeight(24)
    header:SetPoint("TOPLEFT", mt, "TOPLEFT", 0, 0)
    header:SetPoint("TOPRIGHT", mt, "TOPRIGHT", 0, 0)
    header:EnableMouse(true)
    header:RegisterForDrag("LeftButton")
    header:SetScript("OnDragStart", function(self)
        if not SKquests.config.locked then
            mt:StartMoving()
        end
    end)
    header:SetScript("OnDragStop", function(self)
        mt:StopMovingOrSizing()
        mt:SetUserPlaced(true)
    end)
    mt.header = header
    
    local titleFS = header:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    titleFS:SetPoint("LEFT", header, "LEFT", 8, 0)
    titleFS:SetText("SKQuests")
    titleFS:SetShadowColor(0, 0, 0, 1)
    titleFS:SetShadowOffset(1, -1)
    mt.titleFS = titleFS
    
    -- Botón de minimizar
    local minBtn = CreateFrame("Button", nil, header)
    minBtn:SetSize(16, 16)
    minBtn:SetPoint("RIGHT", header, "RIGHT", -6, 0)
    
    local minBtnTxt = minBtn:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    minBtnTxt:SetAllPoints()
    minBtnTxt:SetJustifyH("CENTER")
    minBtnTxt:SetJustifyV("MIDDLE")
    minBtn.txt = minBtnTxt
    
    minBtn:SetScript("OnClick", function()
        local min = not SKquests.config.trackerMinimized
        SKquests.config.trackerMinimized = min
        SKquestsDB.config.trackerMinimized = min
        addon:RefreshMiniTracker()
    end)
    mt.minBtn = minBtn

    -- Botón de lock (Bloquear) - Texto "lock" o "unlock"
    local lockBtn = CreateFrame("Button", nil, header)
    lockBtn:SetSize(36, 16)
    lockBtn:SetPoint("RIGHT", minBtn, "LEFT", -6, 0)
    
    local lockBtnTxt = lockBtn:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    lockBtnTxt:SetAllPoints()
    lockBtnTxt:SetJustifyH("RIGHT")
    lockBtnTxt:SetJustifyV("MIDDLE")
    lockBtn.txt = lockBtnTxt
    
    lockBtn:SetScript("OnClick", function()
        local nextLockState = not SKquests.config.locked
        SKquests.config.locked = nextLockState
        SKquestsDB.config.locked = nextLockState
        if SKquests_CB_lock then
            SKquests_CB_lock:SetChecked(nextLockState)
        end
        if MainFrame then
            MainFrame:SetMovable(not nextLockState)
            MainFrame:SetResizable(not nextLockState)
            addon:UpdateResizeHandles()
        end
        header:SetScript("OnUpdate", nil)
        addon:RefreshMiniTracker()
        if nextLockState then
            SKquests:Print(IsSpanish() and "Tracker fijado. Pasa el cursor por arriba para desbloquear." or "Tracker locked. Hover top area to unlock.")
        else
            SKquests:Print(IsSpanish() and "Tracker desbloqueado." or "Tracker unlocked.")
        end
    end)
    mt.lockBtn = lockBtn
    
    -- Efecto de hover inteligente cuando la ventana está bloqueada
    header:SetScript("OnEnter", function(self)
        if SKquests.config.locked then
            self:SetScript("OnUpdate", function(sf, elapsed)
                local mouseOver = sf:IsMouseOver() or (minBtn and minBtn:IsMouseOver()) or (lockBtn and lockBtn:IsMouseOver())
                if mouseOver then
                    -- Mostrar cabecera y controles
                    SKQ_EnsureBackdrop(sf)
                    sf:SetBackdrop({
                        bgFile   = "Interface\\ChatFrame\\ChatFrameBackground",
                        tile = true, tileSize = 16,
                        insets = {left=0, right=0, top=0, bottom=0},
                    })
                    sf:SetBackdropColor(0, 0, 0, 0.7)
                    if lockBtn then
                        lockBtn.txt:SetText("unlock")
                        lockBtn:Show()
                    end
                    if minBtn then minBtn:Show() end
                    if mt.titleFS then mt.titleFS:Show() end
                else
                    -- Ocultar y detener actualización
                    SKQ_EnsureBackdrop(sf)
                    sf:SetBackdrop(nil)
                    if lockBtn then lockBtn:Hide() end
                    if minBtn then minBtn:Hide() end
                    if mt.titleFS then mt.titleFS:Hide() end
                    sf:SetScript("OnUpdate", nil)
                end
            end)
        end
    end)
    
    -- Botón de resize corner (esquina inferior derecha para arrastrar el tamaño)
    local rb = CreateFrame("Button", nil, mt)
    rb:SetSize(16, 16)
    rb:SetPoint("BOTTOMRIGHT", mt, "BOTTOMRIGHT", 0, 0)
    rb:SetNormalTexture("Interface\\ChatFrame\\UI-ChatIM-SizeGrabber-Up")
    rb:SetHighlightTexture("Interface\\ChatFrame\\UI-ChatIM-SizeGrabber-Highlight")
    rb:SetScript("OnMouseDown", function(self, button)
        mt:StartSizing("BOTTOMRIGHT")
    end)
    rb:SetScript("OnMouseUp", function(self, button)
        mt:StopMovingOrSizing()
        local w, h = mt:GetSize()
        if w and h and w > 0 and h > 0 then
            SKquests.config.trackerWidth = w
            SKquests.config.trackerHeight = h
            SKquestsDB.config.trackerWidth = w
            SKquestsDB.config.trackerHeight = h
        end
    end)
    mt.resizeBtn = rb
    
    -- Scroll Frame (sin scrollbar bulky) - Empieza justo abajo del header (-28)
    local sf = CreateFrame("ScrollFrame", "SKquests_MiniTrackerScroll", mt)
    sf:SetPoint("TOPLEFT", mt, "TOPLEFT", 8, -28)
    sf:SetPoint("BOTTOMRIGHT", mt, "BOTTOMRIGHT", -8, 8)
    mt.scrollFrame = sf
    
    local content = CreateFrame("Frame", "SKquests_MiniTrackerScrollContent", sf)
    content:SetSize(244, 10)
    sf:SetScrollChild(content)
    mt.content = content
    
    -- Soporte para rueda de ratón (Mouse wheel scrolling)
    sf:EnableMouseWheel(true)
    sf:SetScript("OnMouseWheel", function(self, delta)
        local cur = self:GetVerticalScroll()
        local maxScroll = math.max(0, content:GetHeight() - self:GetHeight())
        local newScroll = cur - delta * 20
        if newScroll < 0 then newScroll = 0 end
        if newScroll > maxScroll then newScroll = maxScroll end
        self:SetVerticalScroll(newScroll)
    end)
    
    -- Aplicar tema inicial
    addon:ApplyTheme()
    
    if not SKquests.config.showTracker then
        mt:Hide()
    else
        mt:Show()
    end
end

function addon:RefreshMiniTracker()
    if not SKquests_MiniTracker then return end
    
    local mt = SKquests_MiniTracker
    local sf = mt.scrollFrame
    local content = mt.content
    local minBtn = mt.minBtn
    local lockBtn = mt.lockBtn
    local resizeBtn = mt.resizeBtn
    local header = mt.header
    local minBtnTxt = minBtn and minBtn.txt
    
    local isLocked = SKquests.config.locked
    
    -- Ajustar interactividad, fondos y visibilidad de controles según estado de bloqueo
    if isLocked then
        SKQ_EnsureBackdrop(mt)
        mt:SetBackdrop(nil)
        if header then
            SKQ_EnsureBackdrop(header)
            header:SetBackdrop(nil)
        end
        if minBtn then minBtn:Hide() end
        if lockBtn then lockBtn:Hide() end
        if resizeBtn then resizeBtn:Hide() end
        if mt.titleFS then mt.titleFS:Hide() end
        mt:EnableMouse(false)
        if header then header:EnableMouse(true) end
    else
        -- Fondo sutil semi-transparente para indicar que es arrastrable
        SKQ_EnsureBackdrop(mt)
        mt:SetBackdrop({
            bgFile   = "Interface\\ChatFrame\\ChatFrameBackground",
            edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
            tile = true, tileSize = 16,
            edgeSize = 8,
            insets = {left=2, right=2, top=2, bottom=2},
        })
        mt:SetBackdropColor(0, 0, 0, 0.45)
        mt:SetBackdropBorderColor(C.border[1], C.border[2], C.border[3], 0.6)
        
        if header then
            SKQ_EnsureBackdrop(header)
            header:SetBackdrop({
                bgFile   = "Interface\\ChatFrame\\ChatFrameBackground",
                edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
                tile = true, tileSize = 16,
                edgeSize = 8,
                insets = {left=2, right=2, top=2, bottom=2},
            })
            header:SetBackdropColor(C.bgDetail[1], C.bgDetail[2], C.bgDetail[3], 0.85)
            header:SetBackdropBorderColor(C.border[1], C.border[2], C.border[3], 0.6)
            header:EnableMouse(true)
        end
        if minBtn then minBtn:Show() end
        if lockBtn then
            lockBtn.txt:SetText("lock")
            lockBtn:Show()
        end
        if resizeBtn then resizeBtn:Show() end
        if mt.titleFS then mt.titleFS:Show() end
        mt:EnableMouse(true)
    end
    
    -- Auto-minimizar dinámico: cuando está activado, el tracker se contrae solo
    -- si no hay misiones activas y se expande automáticamente al aparecer alguna.
    if SKquests.config.autoMinimize then
        local aq = addon.Tracker and addon.Tracker:GetActiveQuests()
        local activeCount = 0
        if aq then
            for i = 1, 100 do if aq[i] then activeCount = activeCount + 1 end end
        end
        local shouldMin = (activeCount == 0)
        SKquests.config.trackerMinimized = shouldMin
        if SKquestsDB and SKquestsDB.config then
            SKquestsDB.config.trackerMinimized = shouldMin
        end
    end

    if minBtnTxt then
        minBtnTxt:SetText(SKquests.config.trackerMinimized and "+" or "-")
    end
    
    local trackerW = SKquests.config.trackerWidth or 260
    local trackerH = SKquests.config.trackerHeight or 300
    
    if SKquests.config.trackerMinimized then
        mt:SetSize(trackerW, 28)
        sf:Hide()
        return
    else
        mt:SetSize(trackerW, trackerH)
        sf:Show()
    end
    
    -- Ajustar dinámicamente el ancho del contenido del scroll
    content:SetWidth(trackerW - 16)
    
    -- Ocultar elementos en pools
    for _, btn in ipairs(titleButtons) do btn:Hide() end
    for _, fs in ipairs(objectiveStrings) do fs:Hide() end
    for _, exp in ipairs(expandButtons) do exp:Hide() end
    
    local activeQuests = addon.Tracker and addon.Tracker:GetActiveQuests()
    if not activeQuests then return end
    
    local yOffset = -4
    local titleCount = 0
    local objCount = 0
    local totalQuestsCount = 0
    
    local showObjs = SKquests.config.trackerShowObjectives ~= false
    local questLimit = SKquests.config.trackerQuestLimit or 10
    local showCurrentZoneOnly = SKquests.config.trackerCurrentZoneOnly
    local currentZone    = GetRealZoneText()
    local currentSubZone = GetSubZoneText()
    local questsDisplayed = 0

    local sortedQuests = {}
    for i = 1, 100 do
        local entry = activeQuests[i]
        if entry then
            local started = entry.isComplete or false
            if not started and entry.objectives then
                for _, obj in ipairs(entry.objectives) do
                    if obj.numDone and obj.numDone > 0 then started = true; break end
                end
            end
            table.insert(sortedQuests, { entry = entry, started = started, origIndex = i })
        end
    end
    table.sort(sortedQuests, function(a, b)
        local keyA = a.entry.id or a.entry.title
        local keyB = b.entry.id or b.entry.title
        local pA = SKquests.config.userSortPriority and SKquests.config.userSortPriority[keyA] or 0
        local pB = SKquests.config.userSortPriority and SKquests.config.userSortPriority[keyB] or 0
        
        if pA ~= pB then return pA > pB end
        if a.started ~= b.started then return a.started end
        return a.origIndex < b.origIndex
    end)

    -- Recorrer en orden del log de misiones (con iniciadas primero)
    for _, item in ipairs(sortedQuests) do
        local entry = item.entry
        if entry then
            local qKey = entry.id or entry.title
            local trackState = SKquests.config.manualTrackState and SKquests.config.manualTrackState[qKey]
            
            local passZone = true
            if trackState == false then
                passZone = false
            elseif trackState == true then
                passZone = true
            else
                if showCurrentZoneOnly and entry.category and entry.category ~= "" then
                -- El encabezado del quest log a veces usa la zona amplia
                -- ("Mulgore") y a veces la subzona puntual ("Red Cloud Mesa").
                -- Aceptamos cualquiera de las dos para no ocultar todo.
                local matchesZone    = currentZone    and currentZone    ~= "" and entry.category == currentZone
                local matchesSubZone = currentSubZone and currentSubZone ~= "" and entry.category == currentSubZone
                if not (matchesZone or matchesSubZone) then
                    -- No ocultamos una quest en la que ya hay progreso real
                    -- (objetivo con X/Y > 0): esas son justo las quests que
                    -- el jugador esta "haciendo" activamente, y es normal
                    -- alejarse de su zona de origen para cumplir objetivos
                    -- (viajar a otra zona, entrar a una cueva/subzona, etc.).
                    -- Sin esto, el filtro de zona las ocultaba de golpe en
                    -- cuanto el jugador salia de la zona donde se acepto.
                    local hasProgress = false
                    if entry.objectives then
                        for _, obj in ipairs(entry.objectives) do
                            if obj.numDone and obj.numDone > 0 then
                                hasProgress = true
                                break
                            end
                        end
                    end
                    if not hasProgress then
                        passZone = false
                    end
                end
            end
            end
            
            if passZone then
                if questsDisplayed >= questLimit then
                    break
                end
                questsDisplayed = questsDisplayed + 1
                totalQuestsCount = totalQuestsCount + 1
            
            local qKey = entry.id or entry.title
            local isCollapsed = SKquests.config.trackerCollapsedQuests[qKey] == true
            
            -- Crear o recuperar botón de expandir/colapsar (► / ▼)
            local objs = entry.objectives or {}
            local hasObjs = #objs > 0
            
            local expBtn = expandButtons[totalQuestsCount]
            if not expBtn then
                expBtn = CreateFrame("Button", nil, content)
                expBtn:SetSize(14, 14)
                
                local expTxt = expBtn:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
                expTxt:SetAllPoints()
                expTxt:SetJustifyH("CENTER")
                expTxt:SetJustifyV("MIDDLE")
                expBtn.txt = expTxt
                
                expandButtons[totalQuestsCount] = expBtn
            end
            
            if showObjs and hasObjs then
                expBtn:SetPoint("TOPLEFT", content, "TOPLEFT", 4, yOffset - 2)
                expBtn.txt:SetText(isCollapsed and ">" or "v")
                expBtn.txt:SetTextColor(C.gold[1], C.gold[2], C.gold[3])
                expBtn:SetScript("OnClick", function()
                    SKquests.config.trackerCollapsedQuests[qKey] = not isCollapsed
                    SKquestsDB.config.trackerCollapsedQuests[qKey] = SKquests.config.trackerCollapsedQuests[qKey]
                    addon:RefreshMiniTracker()
                end)
                expBtn:Show()
            else
                expBtn:Hide()
            end
            
            -- Obtener o crear botón de título de la quest
            titleCount = titleCount + 1
            local btn = titleButtons[titleCount]
            if not btn then
                btn = CreateFrame("Button", nil, content)
                btn:SetHeight(18)
                
                local txt = btn:CreateFontString(nil, "OVERLAY", "GameFontNormal")
                txt:SetPoint("LEFT", btn, "LEFT", 2, 0)
                txt:SetPoint("RIGHT", btn, "RIGHT", -2, 0)
                txt:SetJustifyH("LEFT")
                txt:SetShadowColor(0, 0, 0, 1)
                txt:SetShadowOffset(1, -1)
                btn.txt = txt
                
                titleButtons[titleCount] = btn
            end
            
            -- Ajustar el ancho del botón según el tamaño dinámico del tracker
            btn:SetWidth(trackerW - 36)
            
            -- Colores temáticos dinámicos
            local normalColor = entry.isComplete and C.green or C.gold
            btn.txt:SetTextColor(normalColor[1], normalColor[2], normalColor[3])
            
            btn:SetScript("OnEnter", function()
                btn.txt:SetTextColor(1, 1, 1)
            end)
            btn:SetScript("OnLeave", function()
                btn.txt:SetTextColor(normalColor[1], normalColor[2], normalColor[3])
            end)
            
            local questId = entry.id or GetQuestIdByName(entry.title)
            btn:SetScript("OnClick", function()
                if questId then
                    addon:ShowQuest(questId)
                else
                    addon:ShowFrame()
                    addon:SwitchTab("questlog")
                end
            end)
            
            -- Prefijo con el icono de riesgo Hardcore (mismo que en la lista)
            local riskPrefix = ""
            local rqid = entry.id or questId
            if rqid and SKquests_DetailDB and SKquests_DetailDB[rqid]
               and SKquests.GetQuestRisk and SKquests.GetRiskIcon then
                local rq = SKquests_DetailDB[rqid]
                local rzone = rq.zoneId and GetZoneName(rq.zoneId)
                local _, rlabel = SKquests:GetQuestRisk(rq, rzone)
                riskPrefix = SKquests:GetRiskIcon(rlabel, 12) .. " "
            end

            -- Prefijo con el icono del item especial que hay que usar para esta
            -- quest (p.ej. la maza de Lazy Peons), vía la API en vivo del
            -- cliente (GetQuestLogSpecialItemInfo) -- no depende de ninguna DB
            -- propia del addon, así que cubre cualquier quest que lo tenga.
            local itemPrefix = ""
            if entry.logIndex then
                local _, itemIcon = GetQuestLogSpecialItemInfo(entry.logIndex)
                if type(itemIcon) == "string" and itemIcon ~= "" then
                    itemPrefix = "|T" .. itemIcon .. ":12:12:0:0|t "
                end
            end

            local titleText = riskPrefix .. itemPrefix .. string.format("[%d] %s", entry.level or 0, entry.title or "")
            -- [REMOVED] if entry.isComplete then titleText = titleText .. " (Completa)" end
            
            local qColor = GetQuestDifficultyColor(entry.level or 0)
            if qColor then
                local dotHex = string.format("|cff%02x%02x%02x", (qColor.r or 1) * 255, (qColor.g or 1) * 255, (qColor.b or 1) * 255)
                titleText = titleText .. " " .. dotHex .. "•|r"
            end
            btn.txt:SetText(titleText)
            
            -- Si el arrow está visible, desfasar el título un poco a la derecha
            if showObjs and hasObjs then
                btn:SetPoint("TOPLEFT", content, "TOPLEFT", 18, yOffset)
            else
                btn:SetPoint("TOPLEFT", content, "TOPLEFT", 4, yOffset)
            end
            
            btn:Show()
            yOffset = yOffset - 18
            
            -- Dibujar objetivos si la quest no está colapsada y el toggle global está activo
            if showObjs and not isCollapsed then
                for _, obj in ipairs(objs) do
                    objCount = objCount + 1
                    local fs = objectiveStrings[objCount]
                    if not fs then
                        fs = content:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
                        fs:SetHeight(14)
                        fs:SetShadowColor(0, 0, 0, 1)
                        fs:SetShadowOffset(1, -1)
                        objectiveStrings[objCount] = fs
                    end
                    
                    fs:SetWidth(trackerW - 36)
                    fs:SetJustifyH("LEFT")
                    
                    local color = obj.done and C.green or C.white
                    fs:SetTextColor(color[1], color[2], color[3])
                    
                    -- Usar la textura de checkmark oficial de WoW dentro del texto para evitar fallos de fuente
                    local mark = obj.done and "|TInterface\\Buttons\\UI-CheckBox-Check:14|t " or "- "
                    fs:SetText("  " .. mark .. (obj.text or ""))
                    fs:SetPoint("TOPLEFT", content, "TOPLEFT", 18, yOffset)
                    fs:Show()
                    yOffset = yOffset - 14
                end
            end
            
            yOffset = yOffset - 4
            end
        end
    end
    
    if totalQuestsCount == 0 then
        if not mt.emptyFS then
            mt.emptyFS = content:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
            mt.emptyFS:SetPoint("TOPLEFT", content, "TOPLEFT", 10, -10)
            mt.emptyFS:SetPoint("RIGHT", content, "RIGHT", -10, 0)
            mt.emptyFS:SetJustifyH("CENTER")
            mt.emptyFS:SetShadowColor(0, 0, 0, 1)
            mt.emptyFS:SetShadowOffset(1, -1)
        end
        mt.emptyFS:SetText(IsSpanish() and "No hay misiones activas" or "No active quests")
        mt.emptyFS:Show()
        content:SetHeight(40)
    else
        if mt.emptyFS then mt.emptyFS:Hide() end
        content:SetHeight(math.abs(yOffset))
    end

    -- Reajustar el scroll si el contenido se encogio (p.ej. tras filtrar por
    -- zona o completar misiones): sin esto, el scroll podia quedar mas abajo
    -- que el nuevo contenido y la lista se veia vacia hasta mover/arrastrar
    -- la ventana (lo que forzaba un redraw) o hacer scroll manualmente.
    if sf then
        local maxScroll = math.max(0, content:GetHeight() - sf:GetHeight())
        if sf:GetVerticalScroll() > maxScroll then
            sf:SetVerticalScroll(maxScroll)
        end
    end
end




-- --- MERGED ARROW LOGIC ---

-- Usaremos HereBeDragonsQuestie para los calculos de distancia y angulo
local HBD_Arrow = LibStub("HereBeDragonsQuestie-2.0", true)
if not HBD_Arrow then 
    print("|cffff0000SKquests:|r HBD no encontrado en Arrow logic!")
    return 
end
print("|cff00ff00SKquests:|r Modulo Arrow cargado correctamente.")

-- Estado interno
local targetMapId = nil
local targetUiMapId = nil
local targetX = nil
local targetY = nil
local targetCoords = nil
local targetTitle = nil

local ArrowFrame = CreateFrame("Button", nil, UIParent)
ArrowFrame:SetSize(56, 56)
ArrowFrame:SetPoint("CENTER", 0, 100)
ArrowFrame:SetMovable(true)
ArrowFrame:EnableMouse(true)
ArrowFrame:SetFrameStrata("TOOLTIP")
ArrowFrame:SetClampedToScreen(true)

ArrowFrame:RegisterForDrag("LeftButton")
ArrowFrame:SetScript("OnDragStart", function(self) self:StartMoving() end)
ArrowFrame:SetScript("OnDragStop", function(self)
    self:StopMovingOrSizing()
    -- Guardar posicin si existe SKquestsDB
    if SKquestsDB and SKquestsDB.config then
        local point, relativeTo, relativePoint, xOfs, yOfs = self:GetPoint()
        SKquestsDB.config.arrowPos = {point, relativePoint, xOfs, yOfs}
    end
end)
ArrowFrame:SetScript("OnEnter", function(self)
    GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
    GameTooltip:AddLine("SKquests GPS")
    if targetTitle then
        GameTooltip:AddLine(targetTitle, 1, 1, 1)
    end
    GameTooltip:AddLine("<Arrastra para mover>", 0.5, 0.5, 0.5)
    GameTooltip:Show()
end)

local distText = ArrowFrame:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
distText:SetPoint("TOP", arrowTex, "BOTTOM", 0, 0)

-- Debug string eliminado

ArrowFrame:SetScript("OnLeave", function() GameTooltip:Hide() end)
ArrowFrame:Hide()

-- Textura principal (flecha)
local arrowTex = ArrowFrame:CreateTexture(nil, "OVERLAY")
arrowTex:SetTexture("Interface\\Minimap\\MinimapArrow")
arrowTex:SetAllPoints()

-- Texto de distancia

distText:SetPoint("TOP", ArrowFrame, "BOTTOM", 0, -5)

-- Evento de Update para rotar y calcular distancia
local lastUpdate = 0
ArrowFrame:SetScript("OnUpdate", function(self, elapsed)
    lastUpdate = lastUpdate + elapsed
    if lastUpdate < 0.05 then return end
    lastUpdate = 0
    
    local px, py, pInstance = HBD_Arrow:GetPlayerWorldPosition()
    if not px or not py then return end
    
    local x01, y01 = targetX / 100, targetY / 100
    local tx, ty, tInstance = HBD_Arrow:GetWorldCoordinatesFromZone(x01, y01, targetUiMapId)
    if not tx or pInstance ~= tInstance then
        distText:SetText("N/A")
        arrowTex:SetVertexColor(0.5, 0.5, 0.5)
        return
    end
    
    local angle, dist = HBD_Arrow:GetWorldVector(pInstance, px, py, tx, ty)
    if not dist then return end

    -- Restauramos la conversión matemática correcta ahora que los valores no están al revés
    local facing = GetPlayerFacing() or 0
    local bearing = angle - facing
    
    arrowTex:SetRotation(bearing)
    
    if dist < 20 then
        distText:SetText(math.floor(dist) .. " yd")
        arrowTex:SetVertexColor(0, 1, 0) -- Verde (llegando)
    elseif dist < 80 then
        distText:SetText(math.floor(dist) .. " yd")
        arrowTex:SetVertexColor(1, 1, 0) -- Amarillo (cerca)
    else
        distText:SetText(math.floor(dist) .. " yd")
        arrowTex:SetVertexColor(1, 0, 0) -- Rojo (lejos)
    end
end)

-- Inicializacin de posicin guardada
ArrowFrame:SetScript("OnEvent", function(self, event)
    if event == "PLAYER_ENTERING_WORLD" then
        if SKquestsDB and SKquestsDB.config and SKquestsDB.config.arrowPos then
            local pos = SKquestsDB.config.arrowPos
            self:ClearAllPoints()
            self:SetPoint(pos[1], UIParent, pos[2], pos[3], pos[4])
        end
    end
end)
ArrowFrame:RegisterEvent("PLAYER_ENTERING_WORLD")

-- API Global
function SKQ_Arrow_SetWaypoint(mapId, x, y, title, coords)
    if SKQ_InitMapIdCaches then SKQ_InitMapIdCaches() end
    local uiMapId = (zoneIdToModernMapIdCache and zoneIdToModernMapIdCache[mapId]) or mapId
    
    -- Si tenemos multiples coordenadas, calcular el punto mas cercano al jugador
    local bestX, bestY = x, y
    if coords and #coords > 1 then
        local px, py, pInstance = HBD_Arrow:GetPlayerWorldPosition()
        if px and py then
            local minDist = math.huge
            for i, c in ipairs(coords) do
                local tx, ty, tInstance = HBD_Arrow:GetWorldCoordinatesFromZone(c[1]/100, c[2]/100, uiMapId)
                if tx and tInstance == pInstance then
                    local dx, dy = px - tx, py - ty
                    local distSq = dx*dx + dy*dy
                    if distSq < minDist then
                        minDist = distSq
                        bestX = c[1]
                        bestY = c[2]
                    end
                end
            end
        end
    end
    
    targetMapId = mapId
    targetUiMapId = uiMapId
    targetX = bestX
    targetY = bestY
    targetCoords = coords
    targetTitle = title
    ArrowFrame:ClearAllPoints()
    ArrowFrame:SetPoint("CENTER", UIParent, "CENTER", 0, 100)
    ArrowFrame:Show()
    print("|cff00ff00SKquests:|r " .. (IsSpanish() and "GPS configurado hacia: " or "GPS pointing to: ") .. (title or (IsSpanish() and "Destino" or "Destination")) .. " (" .. math.floor(x) .. ", " .. math.floor(y) .. ")")
end

function SKQ_Arrow_ClearWaypoint()
    targetMapId = nil
    targetUiMapId = nil
    targetX = nil
    targetY = nil
    targetCoords = nil
    targetTitle = nil
    ArrowFrame:Hide()
    print(IsSpanish() and "|cff00ff00SKquests:|r GPS detenido." or "|cff00ff00SKquests:|r GPS stopped.")
end

function SKQ_Arrow_GetTarget()
    return targetMapId, targetX, targetY, targetTitle
end

SLASH_SKQARROW1 = "/skqarrow"
SlashCmdList["SKQARROW"] = function()
    ArrowFrame:ClearAllPoints()
    ArrowFrame:SetPoint("CENTER", UIParent, "CENTER", 0, 0)
    ArrowFrame:SetSize(100, 100)
    ArrowFrame:SetFrameLevel(99)
    ArrowFrame:Show()
    print(IsSpanish() and "SKquests: Flecha forzada a mostrarse en el centro." or "SKquests: Arrow forced to show in the center.")
end



