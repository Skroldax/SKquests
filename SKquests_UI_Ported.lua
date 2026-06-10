-- File: SKquests_UI.lua
-- Rediseño completo de la interfaz de SKquests al estilo Web 3 Columnas
-- Soporta modo oscuro/claro, ventana ajustable y pestañas dinámicas.
-- Versión Alpha 0.1.4

local addon = SKquests
local L = function(key) return SKquests_Localization and SKquests_Localization:Get(key) or key end

-- ============================================================
--  MAPA DE ZONAS WotLK/Classic (LOOKUP TABLE)
-- ============================================================
local ZoneMap = {
    [1] = "Dun Morogh",
    [3] = "Badlands",
    [4] = "Durotar",
    [8] = "Swamp of Sorrows",
    [9] = "Mulgore",
    [10] = "Duskwood",
    [11] = "The Barrens",
    [12] = "Elwynn Forest",
    [14] = "Durotar",
    [15] = "Dustwallow Marsh",
    [16] = "Arathi Highlands",
    [17] = "Badlands",
    [19] = "Blasted Lands",
    [20] = "Tirisfal Glades",
    [21] = "Silverpine Forest",
    [22] = "Western Plaguelands",
    [23] = "Eastern Plaguelands",
    [24] = "Hillsbrad Foothills",
    [26] = "The Hinterlands",
    [27] = "Dun Morogh",
    [28] = "Searing Gorge",
    [29] = "Burning Steppes",
    [30] = "Elwynn Forest",
    [32] = "Swamp of Sorrows",
    [33] = "Stranglethorn Vale",
    [34] = "Duskwood",
    [35] = "Loch Modan",
    [36] = "Redridge Mountains",
    [37] = "Stranglethorn Vale",
    [38] = "Wetlands",
    [39] = "Westfall",
    [40] = "Wetlands",
    [41] = "Teldrassil",
    [42] = "Darkshore",
    [43] = "Ashenvale",
    [61] = "Thousand Needles",
    [81] = "Stonetalon Mountains",
    [85] = "Tirisfal Glades",
    [101] = "Desolace",
    [121] = "Feralas",
    [141] = "Dustwallow Marsh",
    [161] = "Tanaris",
    [181] = "Azshara",
    [182] = "Felwood",
    [201] = "Un'Goro Crater",
    [241] = "Moonglade",
    [261] = "Silithus",
    [281] = "Winterspring",
    [301] = "Stormwind City",
    [321] = "Orgrimmar",
    [341] = "Ironforge",
    [362] = "Thunder Bluff",
    [381] = "Darnassus",
    [382] = "Undercity",
    [401] = "Alterac Valley",
    [443] = "Ruins of Gilneas",
    [461] = "Arathi Basin",
    [462] = "Eversong Woods",
    [463] = "Ghostlands",
    [464] = "Azuremyst Isle",
    [465] = "Hellfire Peninsula",
    [467] = "Zangarmarsh",
    [471] = "The Exodar",
    [473] = "Terokkar Forest",
    [475] = "Blade's Edge Mountains",
    [476] = "Bloodmyst Isle",
    [477] = "Nagrand",
    [478] = "Shadowmoon Valley",
    [479] = "Netherstorm",
    [480] = "Shattrath City",
    [481] = "Shattrath City",
    [486] = "Borean Tundra",
    [488] = "Dragonblight",
    [490] = "Grizzly Hills",
    [491] = "Howling Fjord",
    [493] = "Sholazar Basin",
    [495] = "Zul'Drak",
    [496] = "The Storm Peaks",
    [501] = "Wintergrasp",
    [502] = "Icecrown",
    [504] = "Dalaran",
    [510] = "The Underbelly",
    [524] = "Howling Fjord",
    [526] = "Zul'Drak",
    [530] = "Zul'Drak",
    [533] = "The Storm Peaks",
    [534] = "The Storm Peaks",
    [1639] = "Moonglade"
}

local function GetZoneName(zoneId)
    if not zoneId then return "Zona Desconocida" end
    if zoneId == 1 then return "General / Dun Morogh" end
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
        objDone     = {0.15, 0.60, 0.15},
        objPending  = {0.28, 0.24, 0.15},
        wowBlue     = {0.10, 0.35, 0.75},
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

-- Guias
local filteredGuideSteps = {}
local guideChapters = {}
local selectedGuideChapter = 1

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
    f:SetBackdrop({
        bgFile   = "Interface\\ChatFrame\\ChatFrameBackground",
        edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
        tile = true, tileSize = 16, edgeSize = edgeSize or 12,
        insets = {left=3, right=3, top=3, bottom=3},
    })
    f:SetBackdropColor(bg[1], bg[2], bg[3], 0.98)
    f:SetBackdropBorderColor(border[1], border[2], border[3], 0.8)
end

function addon:ApplyTheme()
    local theme = SKquestsDB and SKquestsDB.config and SKquestsDB.config.theme or "dark"
    C = Themes[theme] or Themes.dark

    if not MainFrame then return end

    -- Aplicar colores de fondo y bordes
    MainFrame:SetBackdropColor(C.bg[1], C.bg[2], C.bg[3], 0.98)
    MainFrame:SetBackdropBorderColor(C.border[1], C.border[2], C.border[3], 0.8)

    Sidenav:SetBackdropColor(C.bgSide[1], C.bgSide[2], C.bgSide[3], 0.98)
    Sidenav:SetBackdropBorderColor(C.borderDim[1], C.borderDim[2], C.borderDim[3], 0.8)

    ListPanel:SetBackdropColor(C.bgList[1], C.bgList[2], C.bgList[3], 0.98)
    ListPanel:SetBackdropBorderColor(C.borderDim[1], C.borderDim[2], C.borderDim[3], 0.8)

    DetailPanel:SetBackdropColor(C.bgDetail[1], C.bgDetail[2], C.bgDetail[3], 0.98)
    DetailPanel:SetBackdropBorderColor(C.borderDim[1], C.borderDim[2], C.borderDim[3], 0.8)

    RightSidebar:SetBackdropColor(C.bgSide[1], C.bgSide[2], C.bgSide[3], 0.98)
    RightSidebar:SetBackdropBorderColor(C.borderDim[1], C.borderDim[2], C.borderDim[3], 0.8)

    -- Aplicar colores de texto de la barra de título
    MainFrame.titleText:SetTextColor(C.gold[1], C.gold[2], C.gold[3])
    MainFrame.hCount:SetTextColor(C.dim[1], C.dim[2], C.dim[3])

    -- Actualizar los botones del menu
    for tab, btn in pairs(Sidenav.buttons) do
        if tab == activeTab then
            btn:SetBackdropColor(C.bgSelected[1], C.bgSelected[2], C.bgSelected[3], 0.9)
            btn.text:SetTextColor(C.gold[1], C.gold[2], C.gold[3])
        else
            btn:SetBackdropColor(0, 0, 0, 0)
            btn.text:SetTextColor(C.dim[1], C.dim[2], C.dim[3])
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
local function BuildZonesList()
    local zonesData = {}
    if not SKquests_DetailDB then return end

    for id, q in pairs(SKquests_DetailDB) do
        -- Filtro de Expansiones: Ignorar TBC y WotLK
        local isClassicOrCustom = (id < 9300 or id > 14000)
        
        if q.zoneId and isClassicOrCustom then
            local name = GetZoneName(q.zoneId)
            if not zonesData[name] then
                zonesData[name] = { minL = 100, maxL = 0, count = 0, id = q.zoneId }
            end
            local z = zonesData[name]
            z.count = z.count + 1
            local qL = q.level or 0
            if qL > 0 then
                if qL < z.minL then z.minL = qL end
                if qL > z.maxL then z.maxL = qL end
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
            id = z.id
        })
    end
    table.sort(uniqueZones, function(a, b) return a.name < b.name end)
end

-- ============================================================
--  COMPILAR LISTAS SEGMENTADAS
-- ============================================================
local function MatchLevelRange(lvl, range)
    if range == "Todos" then return true end
    if not lvl or lvl <= 0 then return false end
    if range == "1-10" then return lvl >= 1 and lvl <= 10
    elseif range == "11-20" then return lvl >= 11 and lvl <= 20
    elseif range == "21-30" then return lvl >= 21 and lvl <= 30
    elseif range == "31-40" then return lvl >= 31 and lvl <= 40
    elseif range == "41-50" then return lvl >= 41 and lvl <= 50
    elseif range == "51-59" then return lvl >= 51 and lvl <= 59
    end
    return false
end

local function BuildFilteredQuestIds()
    filteredQuestIds = {}
    local seenNames = {}
    if not SKquests_DetailDB then return end

    local query = searchText:lower()
    for id, q in pairs(SKquests_DetailDB) do
        local lvl = q.level or 0
        -- Sin filtro de nivel máximo: mostrar todas las quests
        local matchesQuery = true
        if query ~= "" then
            local name = q.name or ""
            local nameLoc = q.name_loc or ""
            local giver = q.giver or ""
            local ender = q.ender or ""
            local zoneName = GetZoneName(q.zoneId)
            matchesQuery = name:lower():find(query, 1, true) or
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

        local matchesLvl = MatchLevelRange(lvl, selectedLevelFilter)

        -- Filtro de Expansiones: Ignorar TBC (9300-11400) y WotLK (11400-14000)
        local isClassicOrCustom = (id < 9300 or id > 14000)

        if matchesQuery and matchesZone and matchesLvl and isClassicOrCustom then
            local qNameLower = (q.name or ""):lower()
            if not seenNames[qNameLower] then
                seenNames[qNameLower] = true
                table.insert(filteredQuestIds, id)
            end
        end
    end

    -- Ordenar por nivel, luego por nombre
    table.sort(filteredQuestIds, function(a, b)
        local qa = SKquests_DetailDB[a]
        local qb = SKquests_DetailDB[b]
        if qa.level ~= qb.level then
            return (qa.level or 0) < (qb.level or 0)
        end
        return (qa.name or "") < (qb.name or "")
    end)
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
        local t = step.title or "Paso " .. i
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
            ch.objSec:SetHeight(320)
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

    if self.MainFrame then
        return
    end

    ----------------------------------------------------
    -- FRAME PRINCIPAL
    ----------------------------------------------------

    local frame = CreateFrame(
        "Frame",
        "SKquestsMainFrame",
        UIParent,
        "BackdropTemplate"
    )

    frame:SetSize(1100, 700)
    frame:SetPoint("CENTER")
    frame:SetMovable(true)
    frame:EnableMouse(true)
    frame:RegisterForDrag("LeftButton")

    frame:SetScript("OnDragStart", frame.StartMoving)
    frame:SetScript("OnDragStop", frame.StopMovingOrSizing)

    frame:SetBackdrop({
        bgFile = "Interface\\Buttons\\WHITE8X8",
        edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
        tile = false,
        edgeSize = 12,
        insets = {
            left = 3,
            right = 3,
            top = 3,
            bottom = 3
        }
    })

    frame:SetBackdropColor(
        0.05,
        0.05,
        0.05,
        0.95
    )

    frame:Hide()

    self.MainFrame = frame

    ----------------------------------------------------
    -- HEADER
    ----------------------------------------------------

    local header = CreateFrame(
        "Frame",
        nil,
        frame,
        "BackdropTemplate"
    )

    header:SetPoint("TOPLEFT")
    header:SetPoint("TOPRIGHT")
    header:SetHeight(70)

    header:SetBackdrop({
        bgFile = "Interface\\Buttons\\WHITE8X8"
    })

    header:SetBackdropColor(
        0.10,
        0.10,
        0.10,
        1
    )

    ----------------------------------------------------
    -- LOGO
    ----------------------------------------------------

        local logo = header:CreateTexture(nil,"ARTWORK")
        logo:SetSize(180,50)
        logo:SetTexture(
            "Interface\\AddOns\\SKquests\\Media\\logo.blp"
        )

    ----------------------------------------------------
    -- SEARCH
    ----------------------------------------------------

    local searchBox = CreateFrame(
        "EditBox",
        nil,
        header,
        "InputBoxTemplate"
    )

    searchBox:SetSize(250,30)

    searchBox:SetPoint(
        "LEFT",
        logo,
        "RIGHT",
        40,
        0
    )

    searchBox:SetAutoFocus(false)

    searchBox:SetText("Search quest...")

    frame.SearchBox = searchBox

    ----------------------------------------------------
    -- CLOSE
    ----------------------------------------------------

    local close = CreateFrame(
        "Button",
        nil,
        header,
        "UIPanelCloseButton"
    )

    close:SetPoint(
        "RIGHT",
        -5,
        0
    )

    ----------------------------------------------------
    -- SIDEBAR
    ----------------------------------------------------

    local sidebar = CreateFrame(
        "Frame",
        nil,
        frame,
        "BackdropTemplate"
    )

    sidebar:SetPoint("TOPLEFT",0,-70)
    sidebar:SetPoint("BOTTOMLEFT",0,0)

    sidebar:SetWidth(220)

    sidebar:SetBackdrop({
        bgFile = "Interface\\Buttons\\WHITE8X8"
    })

    sidebar:SetBackdropColor(
        0.08,
        0.08,
        0.08,
        1
    )

    ----------------------------------------------------
    -- BOTONES SIDEBAR
    ----------------------------------------------------

    local buttons = {
        "Dashboard",
        "Quest Search",
        "Alliance",
        "Horde",
        "Settings"
    }

    local previous

    for _,text in ipairs(buttons) do

        sidebar.buttons = sidebar.buttons or {}
        local btn = CreateFrame(
            "Button",
            nil,
            sidebar,
            "UIPanelButtonTemplate"
        )

        btn:SetSize(180,32)

        if not previous then
            btn:SetPoint("TOP",0,-20)
        else
            btn:SetPoint(
                "TOP",
                previous,
                "BOTTOM",
                0,
                -10
            )
        end

        btn:SetText(text)
        table.insert(sidebar.buttons, btn)

        previous = btn
    end

    ----------------------------------------------------
    -- QUEST LIST PANEL
    ----------------------------------------------------

    local listPanel = CreateFrame(
        "Frame",
        nil,
        frame,
        "BackdropTemplate"
    )

    listPanel:SetPoint(
        "TOPLEFT",
        sidebar,
        "TOPRIGHT",
        10,
        0
    )

    listPanel:SetSize(
        300,
        600
    )

    listPanel:SetBackdrop({
        bgFile = "Interface\\Buttons\\WHITE8X8"
    })

    listPanel:SetBackdropColor(
        0.12,
        0.12,
        0.12,
        1
    )

    ----------------------------------------------------
    -- SCROLL QUESTS
    ----------------------------------------------------

    local scroll = CreateFrame("ScrollFrame", "SKquestsListFauxScroll", listPanel, "FauxScrollFrameTemplate")

    scroll:SetPoint("TOPLEFT",10,-10)
    scroll:SetPoint("BOTTOMRIGHT",-30,10)

    local content = CreateFrame(
        "Frame",
        nil,
        scroll
    )

    content:SetSize(250,2000)

    scroll:SetScrollChild(content)
    scroll:SetScript("OnVerticalScroll", function(self, offset)
        FauxScrollFrame_OnVerticalScroll(self, offset, 40, function() addon:UpdateListRows() end)
    end)

    frame.QuestListContent = content
    addon.ListPanel = listPanel
    addon.ListPanel.scroll = scroll
    addon.ListPanel.content = content
    addon.DetailPanel = detail
    addon.Sidenav = sidebar

    ----------------------------------------------------
    -- QUEST DETAIL PANEL
    ----------------------------------------------------

    local detail = CreateFrame(
        "Frame",
        nil,
        frame,
        "BackdropTemplate"
    )

    detail:SetPoint(
        "TOPLEFT",
        listPanel,
        "TOPRIGHT",
        10,
        0
    )

    detail:SetPoint(
        "BOTTOMRIGHT",
        -10,
        10
    )

    detail:SetBackdrop({
        bgFile = "Interface\\Buttons\\WHITE8X8"
    })

    detail:SetBackdropColor(
        0.15,
        0.15,
        0.15,
        1
    )

    ----------------------------------------------------
    -- QUEST TITLE
    ----------------------------------------------------

    local questTitle = detail:CreateFontString(
        nil,
        "OVERLAY",
        "GameFontNormalLarge"
    )

    questTitle:SetPoint(
        "TOPLEFT",
        20,
        -20
    )

    questTitle:SetText(
        "Select a Quest"
    )

    frame.QuestTitle = questTitle

    ----------------------------------------------------
    -- WOWHEAD BUTTON
    ----------------------------------------------------

    local wowheadBtn = CreateFrame(
        "Button",
        nil,
        detail,
        "UIPanelButtonTemplate"
    )

    wowheadBtn:SetSize(
        120,
        28
    )

    wowheadBtn:SetPoint(
        "TOPRIGHT",
        -20,
        -15
    )

    wowheadBtn:SetText(
        "Wowhead"
    )

    frame.WowheadButton = wowheadBtn

    ----------------------------------------------------
    -- DESCRIPTION
    ----------------------------------------------------

    local description = detail:CreateFontString(
        nil,
        "OVERLAY",
        "GameFontHighlight"
    )

    description:SetPoint(
        "TOPLEFT",
        20,
        -70
    )

    description:SetWidth(500)

    description:SetJustifyH("LEFT")
    description:SetJustifyV("TOP")

    description:SetText(
        "Quest information will appear here."
    )

    frame.Description = description

    ----------------------------------------------------
    -- IMAGE
    ----------------------------------------------------

    local image = detail:CreateTexture(
        nil,
        "ARTWORK"
    )

    image:SetSize(
        450,
        250
    )

    image:SetPoint(
        "BOTTOM",
        0,
        30
    )

    image:SetTexture(
        "Interface\\Icons\\INV_Misc_Map_01"
    )

    frame.QuestImage = image

    ----------------------------------------------------
    -- RESIZE
    ----------------------------------------------------

    local resize = CreateFrame(
        "Button",
        nil,
        frame
    )

    resize:SetPoint(
        "BOTTOMRIGHT"
    )

    resize:SetSize(
        16,
        16
    )

    resize:SetNormalTexture(
        "Interface\\ChatFrame\\UI-ChatIM-SizeGrabber-Up"
    )

    resize:SetHighlightTexture(
        "Interface\\ChatFrame\\UI-ChatIM-SizeGrabber-Highlight"
    )

    resize:SetPushedTexture(
        "Interface\\ChatFrame\\UI-ChatIM-SizeGrabber-Down"
    )

    frame:SetResizable(true)

    resize:SetScript(
        "OnMouseDown",
        function()
            frame:StartSizing("BOTTOMRIGHT")
        end
    )

    resize:SetScript(
        "OnMouseUp",
        function()
            frame:StopMovingOrSizing()
        end
    )


    -- Inject missing sections for old logic
    local ch = detail
    addon.DetailPanel.child = detail
    ch.header = frame.QuestTitle
    ch.descSec = frame.Description
    ch.questImgBox = frame.QuestImage

    -- NPC section
    local npcSec = CreateFrame("Frame", nil, detail)
    npcSec:SetSize(300, 50)
    npcSec.startLbl = npcSec:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    npcSec.startLbl:SetPoint("TOPLEFT", 0, 0)
    npcSec.endLbl = npcSec:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    npcSec.endLbl:SetPoint("TOPLEFT", 0, -20)
    ch.npcSec = npcSec

    -- Objectives section
    local objSec = CreateFrame("Frame", nil, detail)
    objSec:SetSize(300, 50)
    objSec.lbl = objSec:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    objSec.lbl:SetPoint("TOPLEFT", 0, 0)
    ch.objSec = objSec

    -- Rewards section
    local rewardSec = CreateFrame("Frame", nil, detail)
    rewardSec:SetSize(300, 100)
    rewardSec.lbl = rewardSec:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    rewardSec.lbl:SetPoint("TOPLEFT", 0, 0)
    rewardSec.buttons = {}
    ch.rewardSec = rewardSec
    
    -- Mappings
    addon.ListPanel.searchBox = frame.SearchBox
    addon.ListPanel.searchBox:SetScript("OnTextChanged", function()
        BuildFilteredQuestIds()
        addon:UpdateListRows()
    end)
    
    addon.ListPanel.filtersFrame = CreateFrame("Frame", nil, listPanel)
    addon.ListPanel.filtersFrame:Hide()
    local filtersFrame = addon.ListPanel.filtersFrame
        local zoneBtn = CreateFrame("Button", nil, filtersFrame)
    filtersFrame.zoneBtn = zoneBtn
    zoneBtn:SetPoint("TOPLEFT", 4, -4)
    zoneBtn:SetPoint("RIGHT", searchBox, "LEFT", -6, 0)
    zoneBtn:SetHeight(20)
    zoneBtn:RegisterForClicks("LeftButtonUp")
    ApplyBD(zoneBtn, {0,0,0}, {0.5,0.4,0.3}, 8)
    zoneBtn:SetBackdropColor(0,0,0,0.4)
    local zoneBtnLbl = zoneBtn:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    zoneBtnLbl:SetPoint("LEFT", 6, 0)
    zoneBtnLbl:SetPoint("RIGHT", -16, 0)
    zoneBtnLbl:SetJustifyH("LEFT")
    zoneBtnLbl:SetText("Zonas: Todas")
    zoneBtn.lbl = zoneBtnLbl

    local zoneBtnArrow = zoneBtn:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    zoneBtnArrow:SetPoint("RIGHT", -6, 0)
    zoneBtnArrow:SetText("v")

    -- MenÃº Desplegable personalizado para Zonas (scrollable, max 5)
    local zoneMenu = CreateFrame("Frame", "SKquestsZoneMenu", f)
    zoneMenu:SetSize(180, 115) -- 5 items de 20px + margins
    zoneMenu:SetPoint("TOPLEFT", zoneBtn, "BOTTOMLEFT", 0, -2)
    zoneMenu:SetFrameStrata("TOOLTIP")
    ApplyBD(zoneMenu, C.bgList, C.borderDim, 8)
    zoneMenu:SetBackdropColor(C.bgList[1], C.bgList[2], C.bgList[3], 0.95)
    zoneMenu:Hide()

    local zmScroll = CreateFrame("ScrollFrame", "SKquestsZMScroll", zoneMenu, "FauxScrollFrameTemplate")
    zmScroll:SetPoint("TOPLEFT", zoneMenu, "TOPLEFT", 4, -6)
    zmScroll:SetPoint("BOTTOMRIGHT", zoneMenu, "BOTTOMRIGHT", -24, 6)

    local zmButtons = {}
    for i = 1, 5 do
        local zb = CreateFrame("Button", nil, zoneMenu)
        zb:SetHeight(20)
        zb:SetPoint("TOPLEFT", zmScroll, "TOPLEFT", 0, -(i-1)*20)
        zb:SetPoint("TOPRIGHT", zmScroll, "TOPRIGHT", 0, -(i-1)*20)
        zb:RegisterForClicks("LeftButtonUp")
        local zbl = zb:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
        zbl:SetPoint("LEFT", 4, 0)
        zbl:SetPoint("RIGHT", -4, 0)
        zbl:SetJustifyH("LEFT")
        zb.lbl = zbl

        zb:SetScript("OnEnter", function(self) self.lbl:SetTextColor(C.gold[1], C.gold[2], C.gold[3]) end)
        zb:SetScript("OnLeave", function(self) self.lbl:SetTextColor(C.white[1], C.white[2], C.white[3]) end)
        zb:SetScript("OnClick", function(self)
            selectedZoneFilter = self.zoneName
            zoneBtnLbl:SetText("Zonas: " .. self.zoneName)
            BuildFilteredQuestIds()
            addon:UpdateListRows()
            zoneMenu:Hide()
        end)
        zmButtons[i] = zb
    end

    local function RefreshZoneMenu()
        local zlist = {}
        table.insert(zlist, { name = "Todas", count = 0, all = true })
        for _, z in ipairs(uniqueZones) do table.insert(zlist, z) end
        
        local total = #zlist
        FauxScrollFrame_Update(zmScroll, total, 5, 20)
        local off = FauxScrollFrame_GetOffset(zmScroll)
        
        for i = 1, 5 do
            local idx = off + i
            local item = zlist[idx]
            local zb = zmButtons[i]
            if item then
                zb.zoneName = item.name
                zb.lbl:SetText(item.name .. (item.all and "" or (" ("..item.count..")")))
                zb:Show()
            else
                zb:Hide()
            end
        end
    end

    zmScroll:SetScript("OnVerticalScroll", function(self, offset)
        FauxScrollFrame_OnVerticalScroll(self, offset, 20, RefreshZoneMenu)
    end)

    zoneBtn:SetScript("OnClick", function()
        if zoneMenu:IsShown() then
            zoneMenu:Hide()
        else
            RefreshZoneMenu()
            zoneMenu:Show()
        end
    end)

    -- Cabecera alternativa para la GuÃ­a
    local guideFiltersFrame = CreateFrame("Frame", nil, ListPanel)
    guideFiltersFrame:SetPoint("TOPLEFT", ListPanel, "TOPLEFT", 6, -6)
    guideFiltersFrame:SetPoint("TOPRIGHT", ListPanel, "TOPRIGHT", -6, -6)
    guideFiltersFrame:SetHeight(30)
    guideFiltersFrame:Hide()
    ListPanel.guideFiltersFrame = guideFiltersFrame


    -- Fix anchors for zoneBtn
    zoneBtn:SetParent(header)
    zoneBtn:ClearAllPoints()
    zoneBtn:SetPoint("RIGHT", addon.ListPanel.searchBox, "LEFT", -10, 0)
    zoneBtn:Show()
    
    -- Bind Sidenav clicks
    local tabs = {"dashboard", "quests", "guide", "guide", "settings"}
    for i, btn in ipairs(sidebar.buttons) do
        local tab = tabs[i] or "quests"
        btn:SetScript("OnClick", function() addon:SwitchTab(tab) end)
    end

end
function addon:SwitchTab(tabId)
    activeTab = tabId

    if tabId == "settings" then
        if ListPanel.UpdateAnchor then ListPanel.UpdateAnchor() end
        ListPanel:Hide()
        DetailPanel:Hide()
        RightSidebar:Hide()
        AboutPanel:Hide()
        SettingsPanel:Show()
    elseif tabId == "about" then
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

        if ListPanel.UpdateAnchor then ListPanel.UpdateAnchor() end

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
                ListPanel.guideFiltersFrame.facBtn.lbl:SetText(addon.db and addon.db.currentGuide == "Alliance" and "Alianza" or "Horda")
                if guideChapters[selectedGuideChapter] then
                    ListPanel.guideFiltersFrame.chapBtn.lbl:SetText(guideChapters[selectedGuideChapter].title)
                end
            end
            ListPanel.scroll:SetPoint("TOPLEFT", ListPanel, "TOPLEFT", 6, -38)
        else
            ListPanel.filtersFrame:Hide()
            if ListPanel.guideFiltersFrame then ListPanel.guideFiltersFrame:Hide() end
            ListPanel.scroll:SetPoint("TOPLEFT", ListPanel, "TOPLEFT", 6, -6)
        end

        UpdateDetailPanelAnchors()
    end

    local faction = addon.db and addon.db.currentGuide or "Alliance"
    local fStr = faction == "Alliance" and "Alianza" or "Horda"
    if tabId == "guide" then
        MainFrame.titleText:SetText("SKquests - Guía Leveo " .. fStr)
    elseif tabId == "questlog" then
        MainFrame.titleText:SetText("SKquests - Quest Log")
    elseif tabId == "quests" then
        MainFrame.titleText:SetText("SKquests - Explorador de Misiones")
    elseif tabId == "zones" then
        MainFrame.titleText:SetText("SKquests - Zonas de Azeroth")
    elseif tabId == "settings" then
        MainFrame.titleText:SetText("SKquests - Configuración")
    elseif tabId == "about" then
        MainFrame.titleText:SetText("SKquests - Acerca de")
    end

    addon:ApplyTheme()
end
