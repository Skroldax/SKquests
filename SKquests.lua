-- SKquests addon core (WoW 3.3.5a compatible)
local addonName = "SKuests"
local altAddon  = "SKquests"
local SKquests  = {}
_G.SKquests = SKquests

-- ====================================================
-- DEFAULTS
-- ====================================================
local defaults = {
    profile = {
        currentGuide = "Horde",
        currentStep  = 1,
        language     = "enUS",
    },
    config = {
        showTitle          = true,
        showImage          = true,
        imageSize          = "medium",
        textSize           = "normal",
        opacity            = 0.9,
        frameColor         = { r=0, g=0, b=0 },
        autoMinimize       = false,
        questieIntegration = true,
    }
}

-- ====================================================
-- PRINT  (global dentro del addon, usable desde Config)
-- ====================================================
function SKquests:Print(msg)
    msg = tostring(msg or "")
    local text = "|cff00ff00[SKquests]|r " .. msg
    if DEFAULT_CHAT_FRAME then
        DEFAULT_CHAT_FRAME:AddMessage(text)
    else
        print(text)
    end
end

-- ====================================================
-- DB
-- ====================================================
local function InitializeDB()
    if not SKquestsDB                    then SKquestsDB                    = {} end
    if not SKquestsDB.profile            then SKquestsDB.profile            = {} end
    if not SKquestsDB.config             then SKquestsDB.config             = {} end
    if not SKquestsDB.questIds           then SKquestsDB.questIds           = {} end
    if not SKquestsDB.completedQuests    then SKquestsDB.completedQuests    = {} end
    if not SKquestsDB.activeQuests       then SKquestsDB.activeQuests       = {} end

    for k,v in pairs(defaults.profile) do
        if SKquestsDB.profile[k] == nil then SKquestsDB.profile[k] = v end
    end
    for k,v in pairs(defaults.config) do
        if SKquestsDB.config[k] == nil  then SKquestsDB.config[k]  = v end
    end

    SKquests.db              = SKquestsDB.profile
    SKquests.config          = SKquestsDB.config
    SKquests.questIds        = SKquestsDB.questIds
    SKquests.completedQuests = SKquestsDB.completedQuests
    SKquests.activeQuests    = SKquestsDB.activeQuests
end

local function InitLanguage()
    if SKquests_Localization then
        SKquests_Localization:SetLanguage(SKquests.db.language or "enUS")
    end
end

-- ====================================================
-- NAVEGACION DE GUIA
-- ====================================================
function SKquests:GetGuideTable()
    if self.db.currentGuide == "Alliance" then return SKquests_Alliance end
    return SKquests_Horde
end

function SKquests:GetCurrentStep()
    local guide = self:GetGuideTable()
    if not guide then return nil, nil, 0 end
    local index = self.db.currentStep or 1
    return guide[index], index, #guide
end

function SKquests:SetCurrentStep(index)
    local guide = self:GetGuideTable()
    if not guide then return false end
    if index >= 1 and index <= #guide then
        self.db.currentStep         = index
        SKquestsDB.profile.currentStep = index
        return true
    end
    return false
end

function SKquests:SetCurrentGuide(guide)
    if guide == "Alliance" or guide == "Horde" then
        self.db.currentGuide            = guide
        SKquestsDB.profile.currentGuide = guide
        self.db.currentStep             = 1
        SKquestsDB.profile.currentStep  = 1
        return true
    end
    return false
end

function SKquests:GetCurrentStepTitle()
    local step = self:GetCurrentStep()
    return step and step.title or nil
end

-- Stub para compatibilidad con Config (la UI moderna gestiona su propio estado)
function SKquests:UpdateFrame() end

-- ====================================================
-- MOSTRAR / OCULTAR
-- ====================================================
local function EnsureUI()
    if not SKquests.MainFrame and SKquests.CreateModernUI then
        SKquests:CreateModernUI()
    end
end

function SKquests:ShowFrame()
    EnsureUI()
    if self.MainFrame then self.MainFrame:Show() end
end

function SKquests:HideFrame()
    if self.MainFrame then self.MainFrame:Hide() end
end

function SKquests:ToggleFrame()
    EnsureUI()
    if self.MainFrame then
        if self.MainFrame:IsShown() then self.MainFrame:Hide()
        else                             self.MainFrame:Show() end
    end
end

-- ====================================================
-- WOWHEAD / IDs
-- ====================================================
function SKquests:SetQuestId(name, id)
    id = tonumber(id)
    if not name or not id then return false end
    self.questIds[name]  = id
    SKquestsDB.questIds  = self.questIds
    self:Print(('ID guardado: %s = %d'):format(name, id))
    return true
end

function SKquests:GetQuestWowheadUrl(name)
    -- Iterar la nueva BD para encontrar el link o ID
    if SKquests_DetailDB then
        for id, q in pairs(SKquests_DetailDB) do
            if q.name and q.name:lower() == name:lower() then
                return "https://www.wowhead.com/wotlk/quest=" .. id
            end
        end
    end
    return nil
end

function SKquests:TrackCurrentQuest()
    local step = self:GetCurrentStep()
    if not step or not step.title then self:Print("No hay quest activa"); return end
    local id = self.questIds[step.title]
    if not id then
        self:Print('Sin ID. Usa /skq setid "' .. step.title .. '" <id>')
        return
    end
    if Questie and Questie.TrackerAPI and Questie.TrackerAPI.QuestAdd then
        Questie.TrackerAPI.QuestAdd(id)
        self:Print("Quest rastreada: " .. step.title)
    elseif QuestieTracker and QuestieTracker.AddQuest then
        QuestieTracker:AddQuest(id)
        self:Print("Quest rastreada: " .. step.title)
    else
        self:Print("Questie no disponible")
    end
end

-- ====================================================
-- RASTREO DE QUESTS (sincronizacion web)
-- QUEST_TURNED_IN  -> arg1 = questId  (en 3.3.5a)
-- QUEST_ACCEPTED   -> arg1 = questId  (en 3.3.5a)
-- ====================================================
local tracker = CreateFrame("Frame")
tracker:RegisterEvent("QUEST_TURNED_IN")
tracker:RegisterEvent("QUEST_ACCEPTED")
tracker:SetScript("OnEvent", function(_, event, arg1)
    if not SKquests.completedQuests then return end
    local id = tostring(arg1 or "")
    if id == "" then return end
    if event == "QUEST_TURNED_IN" then
        SKquests.completedQuests[id]  = true
        SKquests.activeQuests[id]     = nil
        SKquestsDB.completedQuests    = SKquests.completedQuests
        SKquestsDB.activeQuests       = SKquests.activeQuests
    elseif event == "QUEST_ACCEPTED" then
        if not SKquests.completedQuests[id] then
            SKquests.activeQuests[id] = true
            SKquestsDB.activeQuests   = SKquests.activeQuests
        end
    end
end)

function SKquests:GenerateExportCode()
    local comp, act = {}, {}
    for id in pairs(self.completedQuests or {}) do table.insert(comp, id) end
    for id in pairs(self.activeQuests    or {}) do table.insert(act,  id) end
    local code = "COMPLETED:" .. table.concat(comp, ",")
    if #act > 0 then code = code .. "|ACTIVE:" .. table.concat(act, ",") end
    return code
end

function SKquests:ExportToChat()
    local nC, nA = 0, 0
    for _ in pairs(self.completedQuests or {}) do nC = nC + 1 end
    for _ in pairs(self.activeQuests    or {}) do nA = nA + 1 end
    self:Print(("Exportando: %d completadas, %d activas"):format(nC, nA))
    DEFAULT_CHAT_FRAME:AddMessage("|cffffff00" .. self:GenerateExportCode() .. "|r")
end

-- ====================================================
-- SLASH COMMANDS
-- ====================================================
local function PrintHelp()
    SKquests:Print("Comandos disponibles:")
    SKquests:Print("  /skq             - Abrir/cerrar ventana")
    SKquests:Print("  /skq show        - Mostrar")
    SKquests:Print("  /skq hide        - Ocultar")
    SKquests:Print("  /skq next        - Siguiente paso")
    SKquests:Print("  /skq prev        - Paso anterior")
    SKquests:Print("  /skq step N      - Ir al paso N")
    SKquests:Print("  /skq guide Alliance|Horde")
    SKquests:Print("  /skq export      - Exportar progreso para la web")
    SKquests:Print("  /skq config      - Abrir configuracion")
    SKquests:Print('  /skq setid "Nombre" ID')
    SKquests:Print("  /skq lang enUS|esES")
    SKquests:Print("  /skq help        - Esta ayuda")
end

SLASH_SKQUESTS1 = "/skq"
SLASH_SKQUESTS2 = "/skquests"
SlashCmdList["SKQUESTS"] = function(msg)
    if msg == "debug" then
        local numQuests = 0
        if SKquests_DetailDB then
            for _ in pairs(SKquests_DetailDB) do numQuests = numQuests + 1 end
        end
        print("--- SKquests Debug ---")
        print("Total quests cargadas:", numQuests)
        print("Total quests visibles:", addon.GetVisibleQuestsCount and addon:GetVisibleQuestsCount() or 0)
        print("Total zonas detectadas:", addon.GetVisibleZonesCount and addon:GetVisibleZonesCount() or 0)
        print("selectedQuestId actual:", addon.GetSelectedQuestId and addon:GetSelectedQuestId() or "nil")
        print("----------------------")
        return
    end

    if not msg or msg == "" then
        SKquests:ToggleFrame()
        return
    end

    local cmd, rest = msg:match("^(%S+)%s*(.*)")
    cmd  = string.lower(cmd or "")
    rest = rest or ""

    if     cmd == "show"   then SKquests:ShowFrame()
    elseif cmd == "hide"   then SKquests:HideFrame()
    elseif cmd == "toggle" then SKquests:ToggleFrame()
    elseif cmd == "next"   then
        local _, idx, tot = SKquests:GetCurrentStep()
        if idx and idx < tot then SKquests:SetCurrentStep(idx + 1) end
    elseif cmd == "prev"   then
        local _, idx = SKquests:GetCurrentStep()
        if idx and idx > 1 then SKquests:SetCurrentStep(idx - 1) end
    elseif cmd == "step"   then
        local n = tonumber(rest)
        if n then SKquests:SetCurrentStep(n)
        else SKquests:Print("Uso: /skq step <numero>") end
    elseif cmd == "guide"  then
        if SKquests:SetCurrentGuide(rest) then SKquests:Print("Guia: " .. rest)
        else SKquests:Print("Uso: /skq guide Alliance|Horde") end
    elseif cmd == "export" then
        SKquests:ExportToChat()
    elseif cmd == "config" then
        SKquests:ShowConfig()
    elseif cmd == "setid"  then
        local name, id = rest:match('^"([^"]+)"%s+(%d+)$')
        if not name then
            local n2 = rest:match("^current%s+(%d+)$")
            if n2 then name = SKquests:GetCurrentStepTitle(); id = n2 end
        end
        if name and id then SKquests:SetQuestId(name, id)
        else SKquests:Print('Uso: /skq setid "Nombre Quest" <id>') end
    elseif cmd == "lang"   then
        if rest == "enUS" or rest == "esES" then
            SKquests.db.language            = rest
            SKquestsDB.profile.language     = rest
            InitLanguage()
            SKquests:Print("Idioma: " .. rest)
        else SKquests:Print("Uso: /skq lang enUS|esES") end
    elseif cmd == "help"   then PrintHelp()
    else
        SKquests:Print("Comando desconocido. /skq help para ver la lista")
    end
end

-- ====================================================
-- ADDON LOADED
-- ====================================================
local initFrame = CreateFrame("Frame")
initFrame:RegisterEvent("ADDON_LOADED")
initFrame:SetScript("OnEvent", function(_, event, arg1)
    if event ~= "ADDON_LOADED" then return end
    if arg1 ~= addonName and arg1 ~= altAddon then return end

    InitializeDB()
    InitLanguage()

    if SKquests.CreateModernUI then
        SKquests:CreateModernUI()
    end
    if SKquests.InitConfig then
        SKquests:InitConfig()
    end

    SKquests:Print("Cargado! Version Alpha 0.1.2 - Escribe /skq para abrir la interfaz")
end)
