-- ============================================================================
-- SKquests :: Stats & Observación  (F4 Estadísticas globales · F8 Análisis de
-- tiempo · F9 Mob Inspector · F6 observador pasivo de NPCs)
-- ----------------------------------------------------------------------------
-- Módulo desacoplado: solo registra datos por OBSERVACIÓN REAL del jugador y
-- los persiste en SavedVariables (SKQ_Stats y, para NPCs, SKQ_CollectedData.npcs
-- ya existente). Sin Wowhead/Questie/bases externas. Compatible WoW 3.3.5a.
--
-- Rendimiento: F4 (kills, oro, muertes, niveles, quests) y F9 por EVENTOS.
-- Solo el "tiempo jugado" y el clasificador de estado de F8 usan un único
-- OnUpdate con throttle de 1s (sin cálculos pesados por frame).
-- ============================================================================

local ADDON = ...
SKquests = SKquests or {}
local SK = SKquests

-- ── Helpers de idioma / formato (módulo autocontenido) ──────────────────────
local function IsES()
    return SKquests_Localization and SKquests_Localization.currentLanguage == "esES"
end
local function T(es, en) if IsES() then return es else return en end end

local function comma(n)
    n = math.floor((tonumber(n) or 0) + 0.5)
    local neg = n < 0
    if neg then n = -n end
    local s = tostring(n)
    local out = s:reverse():gsub("(%d%d%d)", "%1,"):reverse()
    out = out:gsub("^,", "")
    if neg then out = "-" .. out end
    return out
end

-- ── Estado persistente ──────────────────────────────────────────────────────
local TIME_KEYS = { "questing", "combat", "travel", "flight", "city", "afk", "dead" }

local function EnsureStats()
    SKQ_Stats = SKQ_Stats or {}
    local s = SKQ_Stats
    s.global = s.global or {}
    local g = s.global
    g.played          = g.played          or 0   -- segundos jugados (online real)
    g.questsDone      = g.questsDone      or 0
    g.questsAbandoned = g.questsAbandoned or 0
    g.mobsKilled      = g.mobsKilled      or 0
    g.xp              = g.xp              or 0   -- XP total obtenida
    g.levels          = g.levels          or 0
    g.gold            = g.gold            or 0   -- cobre ganado bruto
    g.deaths          = g.deaths          or 0
    s.timeCats    = s.timeCats    or {}   -- acumulado de por vida por categoría
    s.session     = s.session     or {}   -- sesión actual (persiste entre /reload)
    s.lastSession = s.lastSession or {}   -- última sesión cerrada
    s.mobs        = s.mobs        or {}   -- [name] = { name,id,level,kills,xpTotal,xpKills,loot,looted }
    return s
end

-- ── API pública: lectura de estadísticas (F4) ───────────────────────────────
function SK:StatsGet()
    return EnsureStats().global
end

-- F8: datos de tiempo { last = {...}, session = {...} }
function SK:StatsTimeData()
    local s = EnsureStats()
    return { last = s.lastSession, session = s.session }
end

-- F9: datos de un mob por nombre
function SK:GetMobData(name)
    if not name then return nil end
    return EnsureStats().mobs[name]
end
function SKQ_GetMobData(name) return SK:GetMobData(name) end

-- ── Reinicios ───────────────────────────────────────────────────────────────
function SK:StatsResetGlobal()
    local s = EnsureStats()
    s.global = {
        played = 0, questsDone = 0, questsAbandoned = 0, mobsKilled = 0,
        xp = 0, levels = 0, gold = 0, deaths = 0,
    }
end

-- Cierra la "sesión de tiempo" actual: vuelca session -> lastSession y limpia.
function SK:StatsResetTimeSession()
    local s = EnsureStats()
    local prev = {}
    local total = 0
    for _, k in ipairs(TIME_KEYS) do
        prev[k] = s.session[k] or 0
        total = total + prev[k]
    end
    if total > 5 then s.lastSession = prev end   -- ignorar sesiones triviales
    s.session = {}
end

-- ── F6: observador pasivo de NPCs (escribe en SKQ_CollectedData.npcs) ────────
local function NpcIdFromGuid(guid)
    if not guid or guid == "" then return nil end
    local id = tonumber(guid:sub(9, 12), 16)
    if id and id > 0 then return id end
    return nil
end

local function PlayerCoords()
    if SetMapToCurrentZone then SetMapToCurrentZone() end
    if not GetPlayerMapPosition then return nil, nil end
    local x, y = GetPlayerMapPosition("player")
    if not x or (x == 0 and y == 0) then return nil, nil end
    return math.floor(x * 1000) / 10, math.floor(y * 1000) / 10
end

local function EnsureNpcStore()
    SKQ_CollectedData = SKQ_CollectedData or {}
    SKQ_CollectedData.npcs = SKQ_CollectedData.npcs or {}
    return SKQ_CollectedData.npcs
end

-- Registra un NPC/criatura observado al targetear o pasar el cursor.
local function ObserveUnit(unit)
    if not UnitExists or not UnitExists(unit) then return end
    if UnitIsPlayer and UnitIsPlayer(unit) then return end
    if UnitPlayerControlled and UnitPlayerControlled(unit) then return end
    local name = UnitName and UnitName(unit)
    if not name or name == "" then return end
    local guid = UnitGUID and UnitGUID(unit)
    local id   = NpcIdFromGuid(guid)
    local key  = id or name
    local npcs = EnsureNpcStore()
    local rec  = npcs[key]
    if not rec then
        local x, y = PlayerCoords()
        rec = {
            id      = id,
            name    = name,
            zone    = (GetRealZoneText and GetRealZoneText()) or "",
            subZone = (GetSubZoneText and GetSubZoneText()) or "",
            x = x, y = y,
            gives = {}, ends = {},
        }
        npcs[key] = rec
    else
        rec.name = rec.name or name
        if not rec.x or not rec.y then rec.x, rec.y = PlayerCoords() end
    end
    -- F9: nivel del mob (cuando es observable y atacable)
    local lvl = UnitLevel and UnitLevel(unit)
    if lvl and lvl > 0 and UnitCanAttack and UnitCanAttack("player", unit) then
        local s = EnsureStats()
        local m = s.mobs[name]
        if m then m.level = lvl
        else s.mobs[name] = { name = name, id = id, level = lvl, kills = 0, xpTotal = 0, xpKills = 0, loot = {}, looted = 0 } end
    end
end

-- API de búsqueda de NPCs (F6). Coincidencia por subcadena, sin distinguir mayúsc.
function SK:SearchNPC(query)
    local out = {}
    if not query or query == "" then return out end
    local q = query:lower()
    local npcs = (SKQ_CollectedData and SKQ_CollectedData.npcs) or {}
    for _, rec in pairs(npcs) do
        local nm = rec.name
        if nm and nm:lower():find(q, 1, true) then
            table.insert(out, {
                id = rec.id, name = nm, zone = rec.zone, subZone = rec.subZone,
                x = rec.x, y = rec.y,
            })
        end
    end
    table.sort(out, function(a, b) return (a.name or "") < (b.name or "") end)
    while #out > 60 do table.remove(out) end
    return out
end
function SKQ_SearchNPC(name) return SK:SearchNPC(name) end

-- ── F9: clasificación de XP por mob (parseo de mensajes de combate) ──────────
-- Reutiliza las cadenas globales del cliente (locale-safe). El primer %s es el
-- nombre del mob y el primer número es la XP otorgada.
local xpKillPats
local function fmtToPattern(fmt)
    if not fmt then return nil end
    local p = fmt:gsub("([%^%$%(%)%.%[%]%*%+%-%?])", "%%%1")
    p = p:gsub("%%d", "(%%d+)")
    p = p:gsub("%%s", "(.-)")
    return p
end
local function buildKillPatterns()
    xpKillPats = {}
    local function add(s) local p = fmtToPattern(s); if p then table.insert(xpKillPats, p) end end
    add(COMBATLOG_XPGAIN_EXHAUSTION1)
    add(COMBATLOG_XPGAIN_EXHAUSTION2)
    add(COMBATLOG_XPGAIN_EXHAUSTION4)
    add(COMBATLOG_XPGAIN_EXHAUSTION5)
    add(COMBATLOG_XPGAIN_FIRSTPERSON)        -- "%s dies, you gain %d experience."
end
-- Devuelve nombre, xp de un mensaje de "X muere y obtienes N de XP".
local function parseKillXP(msg)
    if not msg then return nil end
    if not xpKillPats then buildKillPatterns() end
    for _, pat in ipairs(xpKillPats) do
        local caps = { msg:match(pat) }
        if caps[1] then
            local name = caps[1]
            local xp
            for i = 2, #caps do local n = tonumber(caps[i]); if n then xp = n; break end end
            if name and xp then return name, xp end
        end
    end
    return nil
end

-- ── Estado en memoria para deltas / correlación de loot ──────────────────────
local lastXP, lastMax = 0, 0
local lastMoney = 0
local lastKill  = nil   -- { name, t }
local playerGUID

local function ResetXPBase()
    lastXP  = (UnitXP and UnitXP("player")) or 0
    lastMax = (UnitXPMax and UnitXPMax("player")) or 0
end

-- F4: acumula XP obtenida (delta total, robusto al cruce de nivel).
local function AccumXP()
    local cur = (UnitXP and UnitXP("player")) or 0
    local mx  = (UnitXPMax and UnitXPMax("player")) or 0
    local delta
    if mx == lastMax then delta = cur - lastXP
    else delta = (lastMax - lastXP) + cur end
    lastXP, lastMax = cur, mx
    if delta and delta > 0 then
        EnsureStats().global.xp = EnsureStats().global.xp + delta
    end
end

-- F8: clasificación del estado actual del jugador (prioridad fija).
local function ClassifyState()
    if UnitIsDeadOrGhost and UnitIsDeadOrGhost("player") then return "dead" end
    if UnitIsAFK and UnitIsAFK("player") then return "afk" end
    if UnitOnTaxi and UnitOnTaxi("player") then return "flight" end
    if UnitAffectingCombat and UnitAffectingCombat("player") then return "combat" end
    if IsResting and IsResting() then return "city" end
    local speed = (GetUnitSpeed and GetUnitSpeed("player")) or 0
    if speed and speed > 0 then return "travel" end
    return "questing"
end

-- ── Eventos ─────────────────────────────────────────────────────────────────
local f = CreateFrame("Frame", "SKquestsStatsFrame")
f:RegisterEvent("ADDON_LOADED")
f:RegisterEvent("PLAYER_ENTERING_WORLD")
f:RegisterEvent("PLAYER_XP_UPDATE")
f:RegisterEvent("PLAYER_LEVEL_UP")
f:RegisterEvent("PLAYER_MONEY")
f:RegisterEvent("PLAYER_DEAD")
f:RegisterEvent("QUEST_TURNED_IN")
f:RegisterEvent("CHAT_MSG_COMBAT_XP_GAIN")
f:RegisterEvent("COMBAT_LOG_EVENT_UNFILTERED")
f:RegisterEvent("PLAYER_TARGET_CHANGED")
f:RegisterEvent("UPDATE_MOUSEOVER_UNIT")
f:RegisterEvent("LOOT_OPENED")

f:SetScript("OnEvent", function(self, event, a1, a2, a3, a4, a5, a6, a7, a8)
    if event == "ADDON_LOADED" then
        if a1 == "SKquests" or a1 == ADDON then
            EnsureStats()
            buildKillPatterns()
        end
        return

    elseif event == "PLAYER_ENTERING_WORLD" then
        EnsureStats()
        playerGUID = UnitGUID and UnitGUID("player")
        ResetXPBase()
        lastMoney = (GetMoney and GetMoney()) or 0
        return

    elseif event == "PLAYER_XP_UPDATE" or event == "PLAYER_LEVEL_UP" then
        AccumXP()
        if event == "PLAYER_LEVEL_UP" then
            local s = EnsureStats()
            s.global.levels = (s.global.levels or 0) + 1
        end

    elseif event == "PLAYER_MONEY" then
        local now = (GetMoney and GetMoney()) or 0
        local d = now - lastMoney
        lastMoney = now
        if d > 0 then EnsureStats().global.gold = EnsureStats().global.gold + d end

    elseif event == "PLAYER_DEAD" then
        EnsureStats().global.deaths = EnsureStats().global.deaths + 1

    elseif event == "QUEST_TURNED_IN" then
        EnsureStats().global.questsDone = EnsureStats().global.questsDone + 1

    elseif event == "CHAT_MSG_COMBAT_XP_GAIN" then
        local name, xp = parseKillXP(a1)
        if name and xp then
            local s = EnsureStats()
            local m = s.mobs[name]
            if not m then m = { name = name, kills = 0, xpTotal = 0, xpKills = 0, loot = {}, looted = 0 }; s.mobs[name] = m end
            m.xpTotal = (m.xpTotal or 0) + xp
            m.xpKills = (m.xpKills or 0) + 1
        end

    elseif event == "COMBAT_LOG_EVENT_UNFILTERED" then
        -- 3.3.5a: a1=timestamp, a2=subevent, a3=srcGUID, a4=srcName, a5=srcFlags,
        --         a6=dstGUID, a7=dstName, a8=dstFlags
        if a2 ~= "PARTY_KILL" then return end
        local mine = (a3 and (a3 == playerGUID))
        if not mine and UnitGUID then
            local pet = UnitGUID("pet")
            if pet and a3 == pet then mine = true end
        end
        if not mine then return end
        local name = a7
        if not name or name == "" then return end
        local s = EnsureStats()
        s.global.mobsKilled = s.global.mobsKilled + 1
        local m = s.mobs[name]
        if not m then m = { name = name, kills = 0, xpTotal = 0, xpKills = 0, loot = {}, looted = 0 }; s.mobs[name] = m end
        m.kills = (m.kills or 0) + 1
        if not m.id then m.id = NpcIdFromGuid(a6) end
        lastKill = { name = name, t = (GetTime and GetTime()) or 0 }

    elseif event == "PLAYER_TARGET_CHANGED" then
        ObserveUnit("target")

    elseif event == "UPDATE_MOUSEOVER_UNIT" then
        ObserveUnit("mouseover")

    elseif event == "LOOT_OPENED" then
        -- F9 loot best-effort: si hay un kill reciente, atribuir el contenido del
        -- cadáver (ítems reales de este loot) a ese mob. Si no, no se atribuye.
        if not lastKill then return end
        local now = (GetTime and GetTime()) or 0
        if (now - (lastKill.t or 0)) > 15 then lastKill = nil; return end
        local nItems = (GetNumLootItems and GetNumLootItems()) or 0
        if nItems <= 0 then return end
        local s = EnsureStats()
        local m = s.mobs[lastKill.name]
        if not m then lastKill = nil; return end
        local recorded = false
        for i = 1, nItems do
            local link = GetLootSlotLink and GetLootSlotLink(i)
            if link then
                local iname = link:match("%[(.-)%]")
                if iname and iname ~= "" then
                    m.loot = m.loot or {}
                    m.loot[iname] = (m.loot[iname] or 0) + 1
                    recorded = true
                end
            end
        end
        if recorded then m.looted = (m.looted or 0) + 1 end
        lastKill = nil
    end
end)

-- ── Único OnUpdate (throttle 1s): tiempo jugado + clasificador de tiempo (F8) ─
f.acc = 0
f:SetScript("OnUpdate", function(self, e)
    self.acc = self.acc + (e or 0)
    if self.acc < 1 then return end
    local dt = self.acc
    self.acc = 0
    local s = EnsureStats()
    s.global.played = s.global.played + dt
    local cat = ClassifyState()
    s.session[cat]  = (s.session[cat]  or 0) + dt
    s.timeCats[cat] = (s.timeCats[cat] or 0) + dt
end)

-- F4: contar misiones abandonadas. En 3.3.5a no hay un evento fiable de
-- "quest removida", pero AbandonQuest() es la función global que ejecuta el
-- abandono (tanto desde la UI por defecto como desde el flujo propio del addon
-- SelectQuestLogEntry -> SetAbandonQuest -> AbandonQuest). La enganchamos.
if type(hooksecurefunc) == "function" and type(AbandonQuest) == "function" then
    hooksecurefunc("AbandonQuest", function()
        local s = EnsureStats()
        s.global.questsAbandoned = (s.global.questsAbandoned or 0) + 1
    end)
end
