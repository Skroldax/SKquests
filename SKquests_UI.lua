-- File: SKquests_UI.lua
-- Rediseño completo de la interfaz de SKquests al estilo Web 3 Columnas
-- Soporta modo oscuro/claro, ventana ajustable y pestañas dinámicas.
-- Versión Alpha 0.8.4

local addon = SKquests

-- Inicializar referencias de Guias globales
SKquests_Guides = {
    Alliance = SKquests_Alliance,
    Horde = SKquests_Horde
}

local L = function(key) return SKquests_Localization and SKquests_Localization:Get(key) or key end

-- Función auxiliar para leer auras de XP personalizadas de Ascension
local function GetAscensionXPMultiplier()
    local mult = 1.0
    for i = 1, 40 do
        local name = UnitBuff("player", i)
        if name then
            local n = string.lower(name)
            -- Aura de Prestigio (200%)
            if (string.find(n, "prestigio") or string.find(n, "prestige") or string.find(n, "prestigie")) and string.find(n, "aura") then
                mult = mult + 2.0
            -- Aura de XP (50%)
            elseif (string.find(n, "aura") and (string.find(n, "experiencia") or string.find(n, "experience"))) then
                mult = mult + 0.5
            -- Poción de XP (25%)
            elseif (string.find(n, "poci") or string.find(n, "potion") or string.find(n, "elixir")) and (string.find(n, "experiencia") or string.find(n, "experience") or string.find(n, "xp")) then
                mult = mult + 0.25
            end
        end
    end
    return mult
end

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
    [206] = "Utgarde Keep",
    [209] = "Shadowfang Keep",
    [210] = "Icecrown Citadel",
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
    [1196] = "Utgarde Pinnacle",
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
    [702]="Teldrassil",[1377]="Silithus",[1497]="Undercity",[1519]="StormwindCity",
    [1537]="Ironforge",[1637]="Ogrimmar",[1638]="ThunderBluff",[1657]="Darnassis",
    [2079]="Dustwallow",[2257]="StormwindCity",[2597]="AlteracValley",
    [2839]="AlteracValley",[3277]="WarsongGulch",[3358]="ArathiBasin",
}

local function GetZoneMapFolder(zoneId)
    if not zoneId then return nil end
    return ZoneMapFolder[zoneId]
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
    return pfDB["units"]["data-ascension"] and pfDB["units"]["data-ascension"][npcId]
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

local function GetZoneName(zoneId)
    if not zoneId then return "Zona Desconocida" end
    if SKquests_Localization and SKquests_Localization.currentLanguage == "esES"
       and pfDB and pfDB["zones"] and pfDB["zones"]["esES"] and pfDB["zones"]["esES"][zoneId] then
        return pfDB["zones"]["esES"][zoneId]
    end
    return ZoneMap[zoneId] or ("Zona " .. zoneId)
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

local listButtons = {}
local MAX_ROWS = 35
local ROW_H = 28

-- ============================================================
--  SOPORTE PARA BACKDROP & THEME
-- ============================================================
local function ApplyBD(f, bg, border, edgeSize)
    -- default fallback if not called inside ApplyTheme
    f:SetBackdrop({
        bgFile   = "Interface\\ChatFrame\\ChatFrameBackground",
        edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
        tile = true, tileSize = 256, edgeSize = edgeSize or 16,
        insets = {left=4, right=4, top=4, bottom=4},
    })
    if bg then f:SetBackdropColor(bg[1], bg[2], bg[3], 0.98) end
    if border then f:SetBackdropBorderColor(border[1], border[2], border[3], 0.8) end
end

function addon:ApplyTheme()
    local theme = SKquestsDB and SKquestsDB.config and SKquestsDB.config.theme or "dark"
    C = Themes[theme] or (addon.GetCustomPalette and addon:GetCustomPalette(theme)) or Themes.dark

    if not MainFrame then return end

    local function UpdateBD(frame, alpha)
        frame:SetBackdrop({
            bgFile   = C.textures and C.textures.bg or "Interface\\ChatFrame\\ChatFrameBackground",
            edgeFile = C.textures and C.textures.border or "Interface\\Tooltips\\UI-Tooltip-Border",
            tile = true, tileSize = 256, 
            edgeSize = C.metrics and C.metrics.borderSize or 16,
            insets = {left=4, right=4, top=4, bottom=4},
        })
        frame:SetBackdropBorderColor(C.border[1], C.border[2], C.border[3], 1.0)
    end

    -- Aplicar texturas, fondos y bordes
    UpdateBD(MainFrame, 0.98)
    MainFrame:SetBackdropColor(C.bg[1], C.bg[2], C.bg[3], 0.98)
    
    UpdateBD(Sidenav, 0.98)
    Sidenav:SetBackdropColor(C.bgSide[1], C.bgSide[2], C.bgSide[3], 0.98)
    Sidenav:SetBackdropBorderColor(C.borderDim[1], C.borderDim[2], C.borderDim[3], 0.8)
    
    UpdateBD(ListPanel, 0.98)
    ListPanel:SetBackdropColor(C.bgList[1], C.bgList[2], C.bgList[3], 0.98)
    ListPanel:SetBackdropBorderColor(C.borderDim[1], C.borderDim[2], C.borderDim[3], 0.8)
    
    UpdateBD(DetailPanel, 0.98)
    DetailPanel:SetBackdropColor(C.bgDetail[1], C.bgDetail[2], C.bgDetail[3], 0.98)
    DetailPanel:SetBackdropBorderColor(C.borderDim[1], C.borderDim[2], C.borderDim[3], 0.8)
    
    UpdateBD(RightSidebar, 0.98)
    RightSidebar:SetBackdropColor(C.bgSide[1], C.bgSide[2], C.bgSide[3], 0.98)
    RightSidebar:SetBackdropBorderColor(C.borderDim[1], C.borderDim[2], C.borderDim[3], 0.8)

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
        
        ch.linkSec.lbl:SetTextColor(C.gold[1], C.gold[2], C.gold[3])
        ch.linkSec.box:SetTextColor(C.white[1], C.white[2], C.white[3])

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

    -- Forzar refresco visual
    addon:UpdateListRows()
    addon:RefreshDetail()
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
    if (l1 > 60) or (l2 > 60) or (l3 > 60) or (l4 > 60) then
        return false
    end
    -- Ocultar quests con nivel < 1 (eventos, clase con level=-1, etc.) a menos
    -- que sean custom o que el jugador ya las tenga aceptadas en su registro.
    if not q.isCustom and l1 <= 0 then
        local active = addon.Tracker and addon.Tracker.IsActive and addon.Tracker:IsActive(q.name)
        if not active then return false end
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
    local origin = pfDB and pfDB['quest_origin'] and pfDB['quest_origin'][id]
    if origin == "tbc" or origin == "wotlk" then
        return false
    end
    return true
end

local function BuildZonesList()
    local zonesData = {}
    if not SKquests_DetailDB then return end

    for id, q in pairs(SKquests_DetailDB) do
        -- Solo zonas con nombre conocido en ZoneMap (elimina las "Zona N")
        local exp = q.zoneId and GetZoneExpansion(q.zoneId)
        if IsQuestEligible(id, q) and q.zoneId and ZoneMap[q.zoneId]
           and exp ~= "TBC" and exp ~= "WotLK" then
            local name = GetZoneName(q.zoneId)
            if not zonesData[name] then
                zonesData[name] = { minL = 100, maxL = 0, count = 0, id = q.zoneId }
            end
            local z = zonesData[name]
            z.count = z.count + 1
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
        table.insert(uniqueZones, {
            name = name,
            minL = z.minL,
            maxL = z.maxL,
            count = z.count,
            id = z.id,
            expansion = GetZoneExpansion(z.id),
        })
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
            if matchesQuery and matchesZone and matchesLvl then
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
        DetailPanel:SetPoint("BOTTOMRIGHT", MainFrame, "BOTTOMRIGHT", -10, 10)
    end
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
    if (activeTab == "quests" or activeTab == "questlog") and ch.questImgBox and ch.questImgBox:IsShown() then
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

    -- 7) linkSec
    if (activeTab == "quests" or activeTab == "questlog") and ch.linkSec then
        ch.linkSec:ClearAllPoints()
        ch.linkSec:SetPoint("TOPLEFT", prev, "BOTTOMLEFT", 0, -6)
        ch.linkSec:SetPoint("TOPRIGHT", ch.header, "BOTTOMRIGHT", 0, -6)
        ch.linkSec:Show()
        prev = ch.linkSec
    elseif ch.linkSec then
        ch.linkSec:Hide()
    end
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
    f:SetMinResize(800, 480)
    f:SetMaxResize(maxW, maxH)
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

    -- Sliders creados dinámicamente más adelante en SettingsPanel
    local wSlider, hSlider

    -- Guardar tamaño al terminar resize
    f:SetScript("OnSizeChanged", function(self, w, h)
        w = math.floor(w)
        h = math.floor(h)
        if SKquestsDB and SKquestsDB.config then
            SKquestsDB.config.width = w
            SKquestsDB.config.height = h
        end
        if wSlider then wSlider:SetValue(w) end
        if hSlider then hSlider:SetValue(h) end
        addon:UpdateListRows()
    end)

    -- ---- CONTROL DE REDIMENSIÓN (GRABBER) ----
    local grabber = CreateFrame("Button", nil, f)
    grabber:SetPoint("BOTTOMRIGHT", f, "BOTTOMRIGHT", -2, 2)
    grabber:SetSize(16, 16)
    grabber:SetNormalTexture("Interface\\ChatFrame\\UI-ChatIM-SizeGrabber-Up")
    grabber:SetHighlightTexture("Interface\\ChatFrame\\UI-ChatIM-SizeGrabber-Highlight")
    grabber:SetFrameLevel(f:GetFrameLevel() + 5)
    grabber:SetScript("OnMouseDown", function(self, button)
        f:StartSizing("BOTTOMRIGHT")
    end)
    grabber:SetScript("OnMouseUp", function(self, button)
        f:StopMovingOrSizing()
    end)

    -- ---- BARRA DE TÍTULO ----
    local titlebar = CreateFrame("Frame", nil, f)
    titlebar:SetPoint("TOPLEFT", f, "TOPLEFT", 10, -8)
    titlebar:SetPoint("TOPRIGHT", f, "TOPRIGHT", -10, -8)
    titlebar:SetHeight(24)

    -- Logotipo de WoW en textura circular
    local logo = titlebar:CreateTexture(nil, "OVERLAY")
    logo:SetPoint("LEFT", 4, 0)
    logo:SetSize(22, 22)
    logo:SetTexture("Interface\\AddOns\\SKquests\\Media\\Logo.tga")

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

    -- Cabecera con búsqueda (sin dropdowns)
    local filtersFrame = CreateFrame("Frame", nil, ListPanel)
    filtersFrame:SetPoint("TOPLEFT", ListPanel, "TOPLEFT", 6, -6)
    filtersFrame:SetPoint("TOPRIGHT", ListPanel, "TOPRIGHT", -6, -6)
    filtersFrame:SetHeight(30)
    ListPanel.filtersFrame = filtersFrame

    -- EditBox de Búsqueda
    local searchBox = CreateFrame("EditBox", "SKquestsSearchBox", filtersFrame, "InputBoxTemplate")
    searchBox:SetPoint("TOPLEFT", 4, -4)
    searchBox:SetPoint("TOPRIGHT", -4, -4)
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

    local zoneBtn = CreateFrame("Button", nil, filtersFrame)
    filtersFrame.zoneBtn = zoneBtn
    zoneBtn:SetPoint("TOPRIGHT", -4, -4)
    zoneBtn:SetWidth(80)
    zoneBtn:SetHeight(20)
    zoneBtn:RegisterForClicks("LeftButtonUp")
    ApplyBD(zoneBtn, {0,0,0}, {0.5,0.4,0.3}, 8)
    zoneBtn:SetBackdropColor(0,0,0,0.4)
    local zoneBtnLbl = zoneBtn:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    zoneBtnLbl:SetPoint("LEFT", 6, 0)
    RegLoc(zoneBtnLbl, "ZONES_BTN")
    zoneBtn.lbl = zoneBtnLbl

    local zoneIcon = zoneBtn:CreateTexture(nil, "OVERLAY")
    zoneIcon:SetSize(12, 12)
    zoneIcon:SetPoint("RIGHT", -4, 0)
    zoneIcon:SetTexture("Interface\\ChatFrame\\ChatFrameExpandArrow")

    local zoneMenu = CreateFrame("Frame", "SKquestsZoneMenu", f)
    zoneMenu:SetSize(180, 115) -- 5 items de 20px + margins
    zoneMenu:SetPoint("TOPLEFT", zoneBtn, "BOTTOMLEFT", 0, -2)
    zoneMenu:SetFrameStrata("TOOLTIP")
    ApplyBD(zoneMenu, {0.05, 0.05, 0.05}, {0.5,0.4,0.3}, 8)
    zoneMenu:Hide()
    filtersFrame.zoneMenu = zoneMenu

    local zScroll = CreateFrame("ScrollFrame", "SKquestsZoneScroll", zoneMenu, "FauxScrollFrameTemplate")
    zScroll:SetPoint("TOPLEFT", 4, -4)
    zScroll:SetPoint("BOTTOMRIGHT", -26, 4)
    
    local zButtons = {}
    for i = 1, 5 do
        local btn = CreateFrame("Button", nil, zoneMenu)
        btn:SetSize(150, 20)
        if i == 1 then
            btn:SetPoint("TOPLEFT", zScroll, "TOPLEFT", 0, 0)
        else
            btn:SetPoint("TOPLEFT", zButtons[i-1], "BOTTOMLEFT", 0, 0)
        end
        local hl = btn:CreateTexture(nil, "HIGHLIGHT")
        hl:SetAllPoints()
        hl:SetColorTexture(1, 1, 1, 0.1)
        
        local txt = btn:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
        txt:SetPoint("LEFT", 4, 0)
        txt:SetPoint("RIGHT", -4, 0)
        txt:SetJustifyH("LEFT")
        btn.txt = txt
        
        btn:SetScript("OnClick", function(self)
            selectedZoneFilter = self.zoneName
            zoneBtn.lbl:SetText(self.zoneName == "Todas" and L("ZONES_BTN") or self.zoneName)
            zoneMenu:Hide()
            BuildFilteredQuestIds()
            FauxScrollFrame_SetOffset(ListPanel.scroll, 0)
            local zbar = _G[ListPanel.scroll:GetName() .. "ScrollBar"]
            if zbar then zbar:SetValue(0) end
            addon:UpdateListRows()
        end)
        zButtons[i] = btn
    end

    -- El menú lee uniqueZones (construido por BuildZonesList); antes leía una
    -- variable fuera de alcance y aparecía vacío.
    local function RefreshZoneMenu()
        local zones = { {name = "Todas", count = 0} }
        for _, z in ipairs(uniqueZones) do
            table.insert(zones, {name = z.name, count = z.count})
        end

        FauxScrollFrame_Update(zScroll, #zones, 5, 20)
        local offset = FauxScrollFrame_GetOffset(zScroll)
        for i = 1, 5 do
            local idx = offset + i
            if idx <= #zones then
                zButtons[i].zoneName = zones[idx].name
                if zones[idx].name == "Todas" then
                    zButtons[i].txt:SetText(L("ALL_ZONES"))
                else
                    zButtons[i].txt:SetText(zones[idx].name .. " (" .. zones[idx].count .. ")")
                end
                zButtons[i]:Show()
            else
                zButtons[i]:Hide()
            end
        end
    end

    zScroll:SetScript("OnVerticalScroll", function(self, offset)
        FauxScrollFrame_OnVerticalScroll(self, offset, 20, RefreshZoneMenu)
    end)
    zoneMenu:SetScript("OnShow", RefreshZoneMenu)

    zoneBtn:SetScript("OnClick", function()
        if zoneMenu:IsShown() then
            zoneMenu:Hide()
        else
            zoneMenu:Show()
        end
    end)
    zoneBtn:SetScript("OnHide", function() zoneMenu:Hide() end)
    
    -- Ajustar los anchors para evitar dependencia circular
    searchBox:ClearAllPoints()
    searchBox:SetPoint("TOPLEFT", 4, -4)
    searchBox:SetPoint("RIGHT", zoneBtn, "LEFT", -6, 0)

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

    -- Listado Faux Scrollable — Los botones son hijos DIRECTOS del scroll frame
    -- (FauxScrollFrame no necesita scrollContent; el offset se usa en RefreshList)
    local listScroll = CreateFrame("ScrollFrame", "SKquestsListFauxScroll", ListPanel, "FauxScrollFrameTemplate")
    listScroll:SetPoint("TOPLEFT", ListPanel, "TOPLEFT", 6, -38)
    listScroll:SetPoint("BOTTOMRIGHT", ListPanel, "BOTTOMRIGHT", -24, 6)
    ListPanel.scroll = listScroll

    -- scrollContent dummy requerido por FauxScrollFrame como ScrollChild
    local scrollContent = CreateFrame("Frame", nil, listScroll)
    scrollContent:SetSize(230, ROW_H)  -- tamaño mínimo
    listScroll:SetScrollChild(scrollContent)

    -- Crear los row buttons reutilizables — anclados al listScroll directamente
    listButtons = {}
    for i = 1, MAX_ROWS do
        local btn = CreateFrame("Button", nil, listScroll)
        btn:SetSize(230, ROW_H)
        btn:SetPoint("TOPLEFT", 0, -(i - 1) * ROW_H)
        btn:RegisterForClicks("LeftButtonUp")
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
        end)
        btn:SetScript("OnLeave", function(self)
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
        btn:SetScript("OnClick", function(self)
            if activeTab == "quests" then
                selectedQuestId = self.itemId
                addon:RefreshDetail()
            elseif activeTab == "questlog" then
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
                addon:SwitchTab("quests")
                BuildFilteredQuestIds()
                -- Al venir de una lista larga, empezar la nueva lista arriba
                FauxScrollFrame_SetOffset(ListPanel.scroll, 0)
                local zbar = _G[ListPanel.scroll:GetName() .. "ScrollBar"]
                if zbar then zbar:SetValue(0) end
                addon:UpdateListRows()
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
    gcTitle:SetText("Elige una guía de leveo")
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
                ApplyBD(card, C.bgDetail, C.borderDim, 6)
                card.title = card:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
                card.title:SetPoint("TOPLEFT", 14, -12)
                card.fac = card:CreateFontString(nil, "OVERLAY", "GameFontNormal")
                card.fac:SetPoint("TOPLEFT", 14, -36)
                card.sub = card:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
                card.sub:SetPoint("BOTTOMLEFT", 14, 12)
                card:SetScript("OnEnter", function(self) self:SetBackdropColor(C.bgHover[1], C.bgHover[2], C.bgHover[3], 1) end)
                card:SetScript("OnLeave", function(self) self:SetBackdropColor(C.bgDetail[1], C.bgDetail[2], C.bgDetail[3], 1) end)
                panel.cards[i] = card
            end
            local row = math.floor((i - 1) / COLS)
            local col = (i - 1) % COLS
            card:ClearAllPoints()
            card:SetPoint("TOPLEFT", panel, "TOPLEFT", 16 + col * (CW + GAP), -44 - row * (CH + GAP))

            local meta = GUIDE_META[key] or { label = key, color = {0.8, 0.8, 0.8}, levels = "" }
            local guide = SKquests_Guides[key]
            local steps = (type(guide) == "table") and #guide or 0
            card.title:SetText(meta.label)
            card.title:SetTextColor(C.white[1], C.white[2], C.white[3])
            card.fac:SetText(meta.label)
            card.fac:SetTextColor(meta.color[1], meta.color[2], meta.color[3])
            card.sub:SetText(("Niveles: %s  -  %d pasos"):format(meta.levels, steps))
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
    lockText:SetText("Guías Pro bloqueadas")
    lockText:SetTextColor(C.gold[1], C.gold[2], C.gold[3])

    local lockSub = GuideLockPanel:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    lockSub:SetPoint("TOP", lockText, "BOTTOM", 0, -8)
    lockSub:SetText("Introduce tu código Pro para desbloquear las guías de leveo.")

    local unlockBtn = CreateFrame("Button", nil, GuideLockPanel, "UIPanelButtonTemplate")
    unlockBtn:SetSize(170, 26)
    unlockBtn:SetPoint("TOP", lockSub, "BOTTOM", 0, -18)
    unlockBtn:SetText("Desbloquear Pro")
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

    -- Ilustración de Quest (Ilustración superior)
    -- ---- VISOR DE MAPA / ILUSTRACIÓN INTERACTIVO ----
    -- Rueda: zoom · Arrastrar: desplazar · Clic: restablecer.
    -- El zoom ocurre DENTRO del recuadro (clip), así el resto del detalle
    -- nunca se mueve aunque se agrande la imagen.
    local questImgBox = CreateFrame("Frame", nil, dChild)
    questImgBox:SetHeight(220)
    questImgBox:SetBackdrop({
        bgFile = "Interface\\ChatFrame\\ChatFrameBackground",
        edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
        edgeSize = 8, insets = {left=2, right=2, top=2, bottom=2}
    })
    questImgBox:SetBackdropColor(0,0,0,0.5)
    questImgBox:SetBackdropBorderColor(0.5,0.4,0.3,0.5)
    questImgBox:EnableMouse(true)
    questImgBox:EnableMouseWheel(true)

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
    end
    questImgBox.Relayout = ImgLayout
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
    questImgBox:SetScript("OnUpdate", function(self)
        if self.needsLayout and imgClip:GetWidth() and imgClip:GetWidth() > 1 then
            self.needsLayout = false
            ImgLayout()
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
        end
        questImgBox.currentQuest = q
        for _, pin in ipairs(pinPool) do pin:Hide(); pin.relX = nil; pin.category = nil end
        OV.Hide()
        local function NpcZone(npcId)
            local u = GetUnitData(npcId)
            local c = u and u.coords and u.coords[1]
            return c and c[3]
        end

        local mapZone = q and q.zoneId
        -- Subzonas de inicio -> usar el mapa PADRE (Teldrassil, Elwynn, etc.).
        -- Los spawns de pfQuest ya están en coords del padre, así que se colocan
        -- directos sin proyección (Shadowglen queda arriba-izquierda, etc.).
        local STARTING_PARENT = {
            [188] = 141, [9] = 12, [154] = 85, [220] = 215, [363] = 14, [132] = 1,
        }
        -- Solo las quests VANILLA usan el mapa padre (coords pfQuest directas).
        -- Las custom (BronzebeardQuestChains) mantienen su subzona para cargar la
        -- imagen de azerothhub y colocar el pin con sus coords directas.
        if mapZone and STARTING_PARENT[mapZone] and not (q and q.bqCoord) then
            mapZone = STARTING_PARENT[mapZone]
        end
        local originalMapZone = mapZone
        local folder = mapZone and GetZoneMapFolder(mapZone)
        if q and not folder then
            -- la quest no tiene mapa propio: usar la zona del NPC de inicio/entrega
            mapZone = NpcZone(q.giverId) or NpcZone(q.enderId)
            originalMapZone = mapZone
            folder = mapZone and GetZoneMapFolder(mapZone)
        end
        _G.SKquests_UI_CurrentMapZone = mapZone

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
                kill = { {0.2, 1.0, 0.2}, {0.1, 0.8, 0.4}, {0.3, 0.9, 0.6}, {0.0, 0.7, 0.3}, {0.4, 1.0, 0.5}, {0.2, 0.6, 0.1} },
                interact = { {1.0, 0.8, 0.1}, {1.0, 0.6, 0.0}, {0.9, 0.9, 0.3}, {1.0, 0.5, 0.1}, {1.0, 0.9, 0.5}, {0.8, 0.6, 0.1} },
                gather = { {1.0, 0.2, 0.2}, {0.9, 0.1, 0.3}, {1.0, 0.3, 0.0}, {0.8, 0.0, 0.0}, {1.0, 0.1, 0.6}, {0.9, 0.4, 0.4} }
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
            self:Show()
            self.needsLayout = true
        else
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

    -- Botón de TomTom obsoleto e invisible
    local tomtomBtn = CreateFrame("Button", nil, objSec, "UIPanelButtonTemplate")
    tomtomBtn:SetPoint("TOPRIGHT", -4, -2)
    tomtomBtn:SetSize(120, 20)
    tomtomBtn:SetText("TomTom 📍")
    tomtomBtn:Hide()
    objSec.tomtomBtn = tomtomBtn

    local objBox = CreateFrame("Frame", nil, objSec)
    objBox:SetPoint("TOPLEFT", 4, -24)
    objBox:SetPoint("BOTTOMRIGHT", -4, -4)
    objBox:SetBackdrop({
        bgFile = "Interface\\ChatFrame\\ChatFrameBackground",
        edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
        edgeSize = 8, insets = {left=2, right=2, top=2, bottom=2}
    })
    objBox:SetBackdropColor(0,0,0,0.3)
    objBox:SetBackdropBorderColor(0.5, 0.4, 0.3, 0.4)
    objSec.box = objBox

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
    local linkSec = CreateFrame("Frame", nil, dChild)
    linkSec:SetHeight(44)
    dChild.linkSec = linkSec

    local linkLbl = linkSec:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    linkLbl:SetPoint("TOPLEFT", 4, -4)
    RegLoc(linkLbl, "WOWHEAD_LINK", "upper")
    linkLbl:SetTextColor(0.85, 0.70, 0.35)
    linkSec.lbl = linkLbl

    linkSec.box = CreateCopyableBox(linkSec, 280, 20)
    linkSec.box:SetPoint("TOPLEFT", 4, -20)

    local copyBtn = CreateFrame("Button", nil, linkSec, "UIPanelButtonTemplate")
    copyBtn:SetPoint("LEFT", linkSec.box, "RIGHT", 6, 0)
    copyBtn:SetSize(80, 22)
    RegLoc(copyBtn, "COPY")
    copyBtn:SetScript("OnClick", function()
        linkSec.box:SetFocus()
        linkSec.box:HighlightText()
        addon:Print("Enlace de Wowhead copiado! Presiona Ctrl+C")
    end)
    linkSec.copyBtn = copyBtn

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

    local function CreateCheckbox(parent, text, x, y, key)
        local cbName = "SKquests_CB_" .. key
        local cb = CreateFrame("CheckButton", cbName, parent, "UICheckButtonTemplate")
        cb:SetPoint("TOPLEFT", x, y)
        local label = _G[cbName .. "Text"]
        if label then
            label:SetText(text)
            table.insert(SettingsPanel.labels, label)
        end
        cb:SetChecked(SKquestsDB and SKquestsDB.config and SKquestsDB.config[key] ~= false)
        cb:SetScript("OnClick", function(self)
            SKquests.config[key] = self:GetChecked()
            SKquestsDB.config[key] = self:GetChecked()
            addon:ApplyTheme()
        end)
        return cb
    end

    CreateCheckbox(SettingsPanel, "Minimizar en combate", 20, -50, "autoMinimize")
    CreateCheckbox(SettingsPanel, "Integración con Questie", 20, -80, "questieIntegration")
    CreateCheckbox(SettingsPanel, "Mostrar mapa en guía", 20, -110, "showImage")

    -- ---- SELECTOR DE TEMA Y EDITOR PRO ELIMINADOS (v0.9.0) ----
    -- Esta build usa solo la paleta oscura. El Modo Pro ahora protege
    -- las GUÍAS de leveo (no los temas). Se conserva un no-op por si
    -- alguna ruta antigua llama a RefreshThemeDropdown.
    function addon:RefreshThemeDropdown() end

    local opLbl = SettingsPanel:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    opLbl:SetPoint("TOPLEFT", 20, -190)
    RegLoc(opLbl, "OPACITY_LBL")
    table.insert(SettingsPanel.labels, opLbl)

    local opSlider = CreateFrame("Slider", "SKquestsOpacitySliderUI", SettingsPanel, "OptionsSliderTemplate")
    opSlider:SetPoint("TOPLEFT", 20, -215)
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

    local lockBtn = CreateFrame("CheckButton", "SKquests_CB_lock", SettingsPanel, "UICheckButtonTemplate")
    lockBtn:SetPoint("TOPLEFT", 20, -250)
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
        if lock then
            grabber:Hide()
        else
            grabber:Show()
        end
    end)

    local facLbl = SettingsPanel:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    facLbl:SetPoint("TOPLEFT", 20, -290)
    RegLoc(facLbl, "GUIDE_FORMULA")
    table.insert(SettingsPanel.labels, facLbl)

    local facBtn = CreateFrame("Button", nil, SettingsPanel, "UIPanelButtonTemplate")
    facBtn:SetPoint("LEFT", facLbl, "RIGHT", 10, -1)
    facBtn:SetSize(120, 22)
    facBtn:SetText(addon.db and addon.db.currentGuide == "Alliance" and L("ALLIANCE") or L("HORDE"))
    facBtn:SetScript("OnClick", function(self)
        local currentG = addon.db and addon.db.currentGuide or "Horde"
        local nextG = currentG == "Alliance" and "Horde" or "Alliance"
        addon:SetCurrentGuide(nextG)
        self:SetText(nextG == "Alliance" and L("ALLIANCE") or L("HORDE"))
        BuildFilteredQuestIds()
        addon:UpdateListRows()
        addon:RefreshDetail()
    end)

    -- ---- IDIOMA ----
    local langLbl = SettingsPanel:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    langLbl:SetPoint("LEFT", facBtn, "RIGHT", 40, 1)
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
    themeLbl:SetPoint("TOPLEFT", 20, -330)
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
        if t == "blizzardclassic" then return "Blizzard Classic" end
        if t == "dragonflight" then return "Dragonflight" end
        if t == "wrathclassic" then return "Wrath Classic" end
        if t == "modern" then return L("THEME_MODERN") end
        if t == "warcraftlogs" then return "Warcraft Logs" end
        if t == "ascensionwow" then return L("THEME_ASCENSION") end
        return t
    end
    themeBtnLbl:SetText(ThemeBtnText())
    
    local themesList = { "oscuro", "claro", "elvuidark", "minimaldark", "blizzardclassic", "dragonflight", "wrathclassic", "modern", "warcraftlogs", "ascensionwow" }
    
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
        hl:SetColorTexture(1, 1, 1, 0.1)
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
                elseif tKey == "blizzardclassic" then tName = "Blizzard Classic"
                elseif tKey == "dragonflight" then tName = "Dragonflight"
                elseif tKey == "wrathclassic" then tName = "Wrath Classic"
                elseif tKey == "modern" then tName = L("THEME_MODERN")
                elseif tKey == "warcraftlogs" then tName = "Warcraft Logs"
                elseif tKey == "ascensionwow" then tName = L("THEME_ASCENSION")
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

    -- ---- CONFIGURACIÓN DE REDIMENSIÓN POR SLIDERS ----
    local wLbl = SettingsPanel:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    wLbl:SetPoint("TOPLEFT", 20, -370)
    RegLoc(wLbl, "WIDTH_LBL")
    table.insert(SettingsPanel.labels, wLbl)

    wSlider = CreateFrame("Slider", "SKquestsWidthSliderUI", SettingsPanel, "OptionsSliderTemplate")
    wSlider:SetPoint("TOPLEFT", 20, -395)
    wSlider:SetWidth(220)
    wSlider:SetMinMaxValues(800, 1600)
    wSlider:SetValue(initialW)
    wSlider:SetValueStep(10)
    
    local wLow = _G["SKquestsWidthSliderUILow"]
    if wLow then wLow:SetText("800") end
    local wHigh = _G["SKquestsWidthSliderUIHigh"]
    if wHigh then wHigh:SetText("1600") end
    local wText = _G["SKquestsWidthSliderUIText"]
    if wText then wText:SetText("Ancho: " .. initialW .. "px") end

    -- Slider de ancho: actualizar etiqueta en tiempo real, aplicar tamaño solo al soltar
    wSlider:SetScript("OnValueChanged", function(self, val)
        val = math.floor(val)
        local sliderText = _G[self:GetName() .. "Text"]
        if sliderText then sliderText:SetText("Ancho: " .. val .. "px") end
    end)
    wSlider:SetScript("OnMouseUp", function(self)
        local val = math.floor(self:GetValue())
        if SKquestsDB and SKquestsDB.config then
            SKquestsDB.config.width = val
        end
        f:SetWidth(val)
        addon:UpdateListRows()
    end)

    local hLbl = SettingsPanel:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    hLbl:SetPoint("TOPLEFT", 280, -370)
    RegLoc(hLbl, "HEIGHT_LBL")
    table.insert(SettingsPanel.labels, hLbl)

    hSlider = CreateFrame("Slider", "SKquestsHeightSliderUI", SettingsPanel, "OptionsSliderTemplate")
    hSlider:SetPoint("TOPLEFT", 280, -395)
    hSlider:SetWidth(220)
    hSlider:SetMinMaxValues(480, 1000)
    hSlider:SetValue(initialH)
    hSlider:SetValueStep(10)
    
    local hLow = _G["SKquestsHeightSliderUILow"]
    if hLow then hLow:SetText("480") end
    local hHigh = _G["SKquestsHeightSliderUIHigh"]
    if hHigh then hHigh:SetText("1000") end
    local hText = _G["SKquestsHeightSliderUIText"]
    if hText then hText:SetText("Alto: " .. initialH .. "px") end

    -- Slider de alto: igual, aplicar solo al soltar
    hSlider:SetScript("OnValueChanged", function(self, val)
        val = math.floor(val)
        local sliderText = _G[self:GetName() .. "Text"]
        if sliderText then sliderText:SetText("Alto: " .. val .. "px") end
    end)
    hSlider:SetScript("OnMouseUp", function(self)
        local val = math.floor(self:GetValue())
        if SKquestsDB and SKquestsDB.config then
            SKquestsDB.config.height = val
        end
        f:SetHeight(val)
        addon:UpdateListRows()
    end)

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
    abDesc:SetText([[
SKquests es un addon para la versión 3.3.5a de World of Warcraft que sirve como guía paso a paso y rastreador de misiones de nivel 1-60.

Combina una base de datos local optimizada con las famosas guías de leveo de la Alianza y la Horda.

Características:
• Rediseño completo estilo Web 3 Columnas ajustable.
• Modo oscuro y modo claro pergamino premium.
• Checklist dinámico de pasos por puntos en el panel derecho.
• Tracking en vivo de objetivos y Quest Log integrado.
• Enlaces rápidos y botón copiables a Wowhead.

Creado con amor para la comunidad.
Versión Alpha 0.1.4
]])
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
            grabber:Hide()
        end
        f:SetAlpha(SKquestsDB.config.opacity or 0.9)
    end

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
            if MainFrame and MainFrame:IsShown() then
                addon:UpdateListRows()
                addon:RefreshDetail()
            end
        end
    end

    -- Escuchar la recepción de información de items de WoW de forma asíncrona
    local eventFrame = CreateFrame("Frame")
    eventFrame:RegisterEvent("GET_ITEM_INFO_RECEIVED")
    eventFrame:SetScript("OnEvent", function(self, event)
        if MainFrame and MainFrame:IsShown() then
            addon:RefreshDetail()
        end
    end)
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
        local cache = addon.Tracker:GetActiveQuests()
        local count = 0
        for _ in pairs(cache) do count = count + 1 end
        totalItems = count
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

        if activeTab == "quests" then
            local id = filteredQuestIds[dataIdx]
            if id then
                local q = SKquests_DetailDB[id]
                btn.itemId = id
                btn.icon:Hide()
                
                -- Mostrar nombre localizado (Español) si está disponible
                local locN = GetQuestLoc(q.id)
                local displayName = (IsSpanish() and ((locN and locN.T) or (q.name_loc and q.name_loc ~= "" and q.name_loc))) or q.name
                btn.txt:SetText(displayName)
                
                local lvl = tonumber(q.level) or 0
                btn.lvl:SetText(lvl > 0 and lvl or "")

                local act, lIdx = addon.Tracker:IsActive(q.name)
                if act then
                    if addon.Tracker:IsComplete(lIdx) then
                        btn.dot:SetText("✔")
                        btn.dot:SetTextColor(0.2, 0.9, 0.2)
                    else
                        btn.dot:SetText("●")
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
            -- Solo quests ACTIVAS (no completadas aún, a menos que estén listas para entregar)
            local activeQuests = {}
            local cache = addon.Tracker:GetActiveQuests()
            for logIdx, entry in pairs(cache) do
                table.insert(activeQuests, { idx=logIdx, entry=entry })
            end
            debug_activeQuests = #activeQuests
            table.sort(activeQuests, function(a, b)
                local la = tonumber(a.entry.level) or 0
                local lb = tonumber(b.entry.level) or 0
                if la ~= lb then return la < lb end
                return tostring(a.entry.title or "") < tostring(b.entry.title or "")
            end)

            local item = activeQuests[dataIdx]
            if item then
                local entry = item.entry
                btn.itemId = item.idx
                btn.icon:Hide()
                btn.txt:SetText(tostring(entry.title or "Misión"))
                
                local lvl = tonumber(entry.level) or 0
                btn.lvl:SetText(lvl > 0 and lvl or "")
                
                if entry.isComplete then
                    btn.dot:SetText("✔")
                    btn.dot:SetTextColor(0.2, 0.9, 0.2)
                else
                    btn.dot:SetText("●")
                    btn.dot:SetTextColor(0.9, 0.9, 0.2)
                end

                if item.idx == selectedQuestLogIdx then
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

        elseif activeTab == "guide" then
            local chData = guideChapters and guideChapters[dataIdx]
            if chData then
                btn.itemId = dataIdx
                btn.dot:SetText("")
                btn.icon:Show()
                btn.icon:SetTexture("Interface\\QuestFrame\\UI-QuestLog-BookIcon")
                btn.txt:SetText(chData.title or "Capítulo " .. dataIdx)
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
        local cache = addon.Tracker:GetActiveQuests()
        local count = 0
        for _ in pairs(cache) do count = count + 1 end
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
--  ACTUALIZAR PANEL DE DETALLES
-- ============================================================
function addon:RefreshDetail()
    if not DetailPanel or not DetailPanel.scroll then return end

    local ch = DetailPanel.child
    if not ch then return end

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
        
        ch.header:Show()
        ch.objSec:Show()
        ch.descSec:Show()
        ch.npcSec:Show()
        ch.linkSec:Show()
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
            ch.linkSec.box:SetText("")
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
                    local mark = obj.done and "[✔] " or "[ ] "
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
        
        -- Dador/Ender localizados
        local giverName = (IsSpanish() and q.giver_loc) or q.giver or q.giver_loc or L("UNKNOWN")
        if q.giverType == "GO" then
            ch.npcSec.grid.startCard.title:SetText(L("START_GO"))
        else
            ch.npcSec.grid.startCard.title:SetText(L("START_NPC"))
        end
        ch.npcSec.grid.startCard.name:SetText(giverName)

        local enderName = (IsSpanish() and q.ender_loc) or q.ender or q.ender_loc or L("UNKNOWN")
        if q.enderType == "GO" then
            ch.npcSec.grid.endCard.title:SetText(L("END_GO"))
        else
            ch.npcSec.grid.endCard.title:SetText(L("END_NPC"))
        end
        ch.npcSec.grid.endCard.name:SetText(enderName)

        ch.linkSec.box:SetText(q.wowhead or "https://www.wowhead.com/wotlk/quest=" .. q.id)

        RightSidebar.rows.questId.val:SetText(q.id)
        local ml = tonumber(q.minLevel) or 0
        RightSidebar.rows.minLvl.val:SetText(ml > 0 and ml or "1")
        
        local isCompleted = addon.completedQuests and addon.completedQuests[tostring(q.id)]
        local statusText = active and L("ST_ACTIVE") or (isCompleted and L("ST_DONE") or L("ST_NOT_STARTED"))
        RightSidebar.rows.status.val:SetText(statusText)

        -- Dinero + XP de recompensa (SKquests_Rewards, desde quest_template)
        local rwd = SKquests_Rewards and SKquests_Rewards[tonumber(q.id) or q.id]
        local rwParts = {}
        
        local baseXP = rwd and rwd.x or 0
        local finalMoney = rwd and rwd.m or 0
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

        -- Multiplicadores de auras custom de Ascension
        local customMult = GetAscensionXPMultiplier()
        if customMult ~= 1.0 then
            finalXP = math.floor(finalXP * customMult)
        end

        if finalMoney > 0 then
            rwParts[#rwParts + 1] = (GetCoinTextureString and GetCoinTextureString(finalMoney)) or tostring(finalMoney)
        end
        
        if finalXP > 0 or baseXP > 0 then
            if finalXP ~= baseXP and baseXP > 0 then
                local mult = finalXP / baseXP
                local multStr = string.format("%.2f", mult)
                multStr = string.gsub(multStr, "%.?0+$", "")
                rwParts[#rwParts + 1] = "|cffffd200" .. finalXP .. " XP|r |cffaaaaaa(Base: " .. baseXP .. " XP, x" .. multStr .. ")|r"
            else
                rwParts[#rwParts + 1] = "|cffffd200" .. finalXP .. " XP|r"
            end
        end
        local moneyStr = table.concat(rwParts, "   ")
        ch.rewardSec.moneyLbl:SetText(moneyStr)

        -- Mostrar Recompensas (fijas)
        local hasFixed = q.rewards and #q.rewards > 0
        local hasChoice = q.choiceRewards and #q.choiceRewards > 0

        if hasFixed or hasChoice or moneyStr ~= "" then
            ch.rewardSec:Show()
            -- Botones de recompensas fijas
            for r = 1, 4 do
                local btn = ch.rewardSec.buttons[r]
                local rew = q.rewards and q.rewards[r]
                if rew then
                    btn.itemId = rew.id
                    btn.itemName = rew.name
                    btn.itemLink = nil
                    btn.tex:SetTexture("Interface\\Icons\\INV_Misc_QuestionMark")
                    local itemTexture = GetItemIcon(rew.id)
                    if itemTexture then btn.tex:SetTexture(itemTexture) end
                    local itemName, itemLink = GetItemInfo(rew.id)
                    if itemName then
                        btn.itemLink = itemLink
                    end
                    btn:Show()
                else
                    btn:Hide()
                end
            end
            -- Botones de recompensas a elección
            ch.rewardSec.choiceLbl:SetShown(hasChoice)
            ch.rewardSec.fixedLbl:SetShown(hasFixed)
            for r = 1, 6 do
                local btn = ch.rewardSec.choiceButtons[r]
                local rew = q.choiceRewards and q.choiceRewards[r]
                if rew then
                    btn.itemId = rew.id
                    btn.itemLink = nil
                    btn.tex:SetTexture("Interface\\Icons\\INV_Misc_QuestionMark")
                    local itemTexture = GetItemIcon(rew.id)
                    if itemTexture then btn.tex:SetTexture(itemTexture) end
                    local itemName, itemLink = GetItemInfo(rew.id)
                    if itemName then
                        btn.itemLink = itemLink
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

        LayoutDetailSections(ch)

    elseif activeTab == "questlog" then
        ch.header:Show()
        ch.objSec:Show()
        ch.descSec:Show()
        ch.npcSec:Show()
        ch.linkSec:Show()
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
            ch.header.title:SetText("Ninguna misión activa seleccionada")
            ch.header.meta:SetText("Selecciona una misión del Quest Log del panel izquierdo.")
            ch.header.level:SetText("")
            ch.objSec.box.text:SetText(L("NO_DETAILS"))
            ch.descSec.text:SetText("")
            ch.npcSec.grid.startCard.name:SetText("-")
            ch.npcSec.grid.endCard.name:SetText("-")
            ch.linkSec.box:SetText("")
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

        -- Mostrar Ilustración
        ch.questImgBox:SetQuest(q)

        -- Mostrar objetivos activos
        local objs = entry.objectives
        if #objs == 0 then
            ch.objSec.box.text:SetText("|cff00ff00Misión completada o sin objetivos.|r")
        else
            local str = ""
            for _, obj in ipairs(objs) do
                local color = obj.done and "|cff00ff00" or "|cffffffff"
                local mark = obj.done and "[✔] " or "[ ] "
                str = str .. color .. mark .. obj.text .. "|r\n"
            end
            ch.objSec.box.text:SetText(str)
        end

        -- Descripción: DB en español si existe; si no, el texto real del log
        local logDesc = GetLogQuestText(selectedQuestLogIdx)
        local dbDesc = q and PfText((GetQuestLoc(q.id) and GetQuestLoc(q.id).D) or nil)
        ch.descSec.text:SetText(dbDesc or logDesc or (q and PfText(q.desc)) or L("NO_INFORMATION"))

        if q then
            
            local giverName = (IsSpanish() and q.giver_loc) or q.giver or q.giver_loc or L("UNKNOWN")
            if q.giverType == "GO" then
                ch.npcSec.grid.startCard.title:SetText(L("START_GO"))
            else
                ch.npcSec.grid.startCard.title:SetText(L("START_NPC"))
            end
            ch.npcSec.grid.startCard.name:SetText(giverName)

            local enderName = (IsSpanish() and q.ender_loc) or q.ender or q.ender_loc or L("UNKNOWN")
            if q.enderType == "GO" then
                ch.npcSec.grid.endCard.title:SetText(L("END_GO"))
            else
                ch.npcSec.grid.endCard.title:SetText(L("END_NPC"))
            end
            ch.npcSec.grid.endCard.name:SetText(enderName)

            ch.linkSec.box:SetText(q.wowhead or "https://www.wowhead.com/wotlk/quest=" .. q.id)

            RightSidebar.rows.questId.val:SetText(q.id)
            local ml = tonumber(q.minLevel) or 0
            RightSidebar.rows.minLvl.val:SetText(ml > 0 and ml or "1")
            RightSidebar.rows.status.val:SetText(entry.isComplete and L("ST_READY") or L("ST_PROGRESS"))

            -- Dinero + XP de recompensa
            local rwParts = {}
            SelectQuestLogEntry(selectedQuestLogIdx)
            local logMoney = GetQuestLogRewardMoney and GetQuestLogRewardMoney() or 0
            local logXP = GetQuestLogRewardXP and GetQuestLogRewardXP() or 0
            
            local rwd = SKquests_Rewards and SKquests_Rewards[tonumber(q.id) or q.id]
            
            local baseXP = rwd and rwd.x or 0
            local finalMoney = (logMoney and logMoney > 0) and logMoney or (rwd and rwd.m or 0)
            local finalXP = baseXP
            
            if logXP and logXP > 0 then
                finalXP = logXP
            end
            
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
            
            -- Multiplicadores de auras custom de Ascension
            local customMult = GetAscensionXPMultiplier()
            if customMult ~= 1.0 then
                finalXP = math.floor(finalXP * customMult)
            end
            
            if finalMoney > 0 then
                rwParts[#rwParts + 1] = (GetCoinTextureString and GetCoinTextureString(finalMoney)) or tostring(finalMoney)
            end
            
            if finalXP > 0 or baseXP > 0 then
                if finalXP ~= baseXP and baseXP > 0 then
                    local mult = finalXP / baseXP
                    local multStr = string.format("%.2f", mult)
                    multStr = string.gsub(multStr, "%.?0+$", "")
                    rwParts[#rwParts + 1] = "|cffffd200" .. finalXP .. " XP|r |cffaaaaaa(Base: " .. baseXP .. " XP, x" .. multStr .. ")|r"
                else
                    rwParts[#rwParts + 1] = "|cffffd200" .. finalXP .. " XP|r"
                end
            end
            
            local moneyStr = table.concat(rwParts, "   ")
            if ch.rewardSec.moneyLbl then
                ch.rewardSec.moneyLbl:SetText(moneyStr)
            end

            -- Mostrar Recompensas
            if (q.rewards and #q.rewards > 0) or moneyStr ~= "" then
                ch.rewardSec:Show()
                for r = 1, 4 do
                    local btn = ch.rewardSec.buttons[r]
                    local rew = q.rewards and q.rewards[r]
                    if rew then
                        btn.itemId = rew.id
                        btn.itemName = rew.name
                        btn.itemLink = nil
                        btn.tex:SetTexture("Interface\\Icons\\INV_Misc_QuestionMark")
                        
                        local itemTexture = GetItemIcon(rew.id)
                        if itemTexture then
                            btn.tex:SetTexture(itemTexture)
                        end
                        local itemName, itemLink = GetItemInfo(rew.id)
                        if itemName then
                            btn.itemLink = itemLink
                        end
                        btn:Show()
                    else
                        btn:Hide()
                    end
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
        else
            ch.descSec.text:SetText(L("NOT_IN_DB"))
            ch.npcSec.grid.startCard.title:SetText(L("START_NPC"))
            ch.npcSec.grid.startCard.name:SetText(L("UNKNOWN"))
            ch.npcSec.grid.endCard.title:SetText(L("END_NPC"))
            ch.npcSec.grid.endCard.name:SetText(L("UNKNOWN"))
            ch.linkSec.box:SetText("")

            RightSidebar.rows.questId.val:SetText("-")
            RightSidebar.rows.minLvl.val:SetText("-")
            RightSidebar.rows.status.val:SetText(entry.isComplete and L("ST_READY") or L("ST_PROGRESS"))
            RightSidebar.chain.prevBtn:Hide()
            RightSidebar.chain.nextBtn:Hide()
        end

        LayoutDetailSections(ch)

    elseif activeTab == "guide" then
        ch.header:Show()
        ch.objSec:Show()
        ch.descSec:Hide()
        ch.npcSec:Hide()
        ch.linkSec:Hide()
        ch.questImgBox:Hide()

        local guide = addon:GetGuideTable()
        if not guide or not guideChapters or not guideChapters[selectedGuideChapter] then
            ch.header.title:SetText("No hay pasos de guía cargados")
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
        ch.linkSec:Hide()
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
    if addon.GuideCardsPanel then addon.GuideCardsPanel:Hide() end
    if addon.GuideLockPanel then addon.GuideLockPanel:Hide() end

    -- Gating Pro de la pestaña Guía: candado (bloqueado) o rejilla (sin elegir)
    if tabId == "guide" then
        if not addon:IsProUnlocked() then
            SettingsPanel:Hide(); AboutPanel:Hide()
            ListPanel:Hide(); DetailPanel:Hide(); RightSidebar:Hide()
            if ListPanel.guideFiltersFrame then ListPanel.guideFiltersFrame:Hide() end
            if addon.GuideLockPanel then addon.GuideLockPanel:Show() end
            if MainFrame and MainFrame.titleText then MainFrame.titleText:SetText("Guías (Pro)") end
            return
        elseif not addon.selectedGuideKey then
            SettingsPanel:Hide(); AboutPanel:Hide()
            ListPanel:Hide(); DetailPanel:Hide(); RightSidebar:Hide()
            if ListPanel.guideFiltersFrame then ListPanel.guideFiltersFrame:Hide() end
            if addon.GuideCardsPanel then
                addon.GuideCardsPanel:Show()
                addon:RefreshGuideCards()
            end
            if MainFrame and MainFrame.titleText then MainFrame.titleText:SetText("Elige tu guía de leveo") end
            return
        end
        -- Pro desbloqueado + guía elegida: cae al flujo normal (panel de pasos)
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
        DetailPanel:Show()
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
            ListPanel.scroll:ClearAllPoints()
            ListPanel.scroll:SetPoint("TOPLEFT", ListPanel, "TOPLEFT", 6, -38)
            ListPanel.scroll:SetPoint("BOTTOMRIGHT", ListPanel, "BOTTOMRIGHT", -24, 6)
        elseif tabId == "guide" then
            ListPanel.filtersFrame:Hide()
            if ListPanel.guideFiltersFrame then 
                ListPanel.guideFiltersFrame:Show()
                ListPanel.guideFiltersFrame.facBtn.lbl:SetText(addon.db and addon.db.currentGuide == "Alliance" and L("ALLIANCE") or L("HORDE"))
            end
            ListPanel.scroll:ClearAllPoints()
            ListPanel.scroll:SetPoint("TOPLEFT", ListPanel, "TOPLEFT", 6, -38)
            ListPanel.scroll:SetPoint("BOTTOMRIGHT", ListPanel, "BOTTOMRIGHT", -24, 6)
        else
            ListPanel.filtersFrame:Hide()
            if ListPanel.guideFiltersFrame then ListPanel.guideFiltersFrame:Hide() end
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
