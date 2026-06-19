-- ============================================================================
-- SKquests :: Experience Appraiser (XP/H Tracker)
-- ----------------------------------------------------------------------------
-- Mide, clasifica y analiza la experiencia obtenida en tiempo real.
-- Estilo FonzAppraiser pero enfocado en XP. Compatible con WoW 3.3.5a.
-- Diseno modular: sin calculos pesados en OnUpdate (solo throttle de 1s y
-- acumuladores ligeros). Toda la XP total se mide con PLAYER_XP_UPDATE; las
-- fuentes se clasifican con CHAT_MSG_COMBAT_XP_GAIN + medicion de entrega.
-- ============================================================================

local ADDON = ...
SKquests = SKquests or {}
local SK = SKquests

-- ── Idioma / helpers de formato ─────────────────────────────────────────────
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

local function durStr(sec)
    sec = math.floor(tonumber(sec) or 0)
    local h = math.floor(sec / 3600)
    local m = math.floor((sec % 3600) / 60)
    local s = sec % 60
    if h > 0 then return string.format("%dh %02dm", h, m) end
    if m > 0 then return string.format("%dm %02ds", m, s) end
    return string.format("%ds", s)
end

local function curZone()
    local z = GetRealZoneText()
    if not z or z == "" then z = GetZoneText() end
    if not z or z == "" then z = "?" end
    return z
end

local function ratingFor(xpm)
    if not xpm then return T("N/D", "N/A"), "888888" end
    if     xpm >= 120 then return T("Excelente", "Excellent"), "33ff33"
    elseif xpm >=  80 then return T("Buena", "Good"),          "ffff33"
    elseif xpm >=  50 then return T("Media", "Average"),       "ff9933"
    else                    return T("Pobre", "Poor"),         "ff3333" end
end

-- ── Estado de SavedVariables ────────────────────────────────────────────────
local function EnsureDB()
    SKQ_XPStats = SKQ_XPStats or {}
    local db = SKQ_XPStats
    if db.enabled      == nil then db.enabled      = true end
    if db.autoPauseAFK == nil then db.autoPauseAFK = true end
    db.Sessions = db.Sessions or {}
    db.Zones    = db.Zones    or {}   -- [zone] = { xp, time }
    db.Quests   = db.Quests   or {}   -- [qid]  = { name, xp, count, time, bestXPM, lastXPM }
    db.accepts  = db.accepts  or {}   -- [qid]  = acceptTime (persistente entre /reload)
    db.window   = db.window   or {}
    db.Loot     = db.Loot     or {}   -- [nombreMinus] = { name, total, zones = { [zona]=n } }
    if db.LootActive == nil then db.LootActive = false end
    return db
end

-- ── Estado de sesion en memoria ─────────────────────────────────────────────
local S = {
    active = false, startTime = 0, startLevel = 0,
    xpGained = 0, lastXP = 0, lastMax = 0,
    paused = false, autoPaused = false, pauseStart = 0, pausedTotal = 0,
    src = { quest = 0, mob = 0, expl = 0 },
    zone = nil, zones = {},
}

-- ── Clasificacion de XP por fuente (parseo de mensajes de combate) ───────────
local xpPatterns
local function fmtToPattern(fmt)
    if not fmt then return nil end
    local p = fmt:gsub("([%^%$%(%)%.%[%]%*%+%-%?])", "%%%1")
    p = p:gsub("%%d", "(%%d+)")
    p = p:gsub("%%s", "(.-)")
    return p
end
local function buildPatterns()
    xpPatterns = {}
    local function add(globalStr, kind)
        local pat = fmtToPattern(globalStr)
        if pat then table.insert(xpPatterns, { pat = pat, kind = kind }) end
    end
    add(ERR_ZONE_EXPLORED_XP, "expl")                 -- "Discovered %s: %d experience gained."
    add(COMBATLOG_XPGAIN_FIRSTPERSON, "mob")          -- "%s dies, you gain %d experience."
    -- Nota: "You gain %d experience." (sin nombre) NO se fuerza a "mob": puede ser
    -- XP compartida de grupo/otras fuentes. Se deja sin clasificar y cae en "Otros"
    -- (residual = total - quest - mob - expl), evitando inflar el conteo de mobs.
end
local function classifyXP(msg)
    if not xpPatterns then buildPatterns() end
    for _, e in ipairs(xpPatterns) do
        local c1, c2 = msg:match(e.pat)
        local amt = tonumber(c2) or tonumber(c1)
        if amt then return amt, e.kind end
    end
    return nil, nil
end

-- ── Calculo de tiempo / XP por hora ─────────────────────────────────────────
function SK:XPElapsed()
    if not S.active then return 0 end
    local e = (GetTime() - S.startTime) - S.pausedTotal
    if S.paused then e = e - (GetTime() - S.pauseStart) end
    if e < 0 then e = 0 end
    return e
end

-- ── Sesion: nueva / guardar / pausa ─────────────────────────────────────────
function SK:XPNewSession(saveOld)
    if S.active and saveOld then SK:XPSaveSession() end
    -- F8: cerrar la "sesión de tiempo" del módulo Stats en sincronía con la de XP
    if SK.StatsResetTimeSession then SK:StatsResetTimeSession() end
    S.active      = true
    S.startTime   = GetTime()
    S.startLevel  = UnitLevel("player") or 1
    S.xpGained    = 0
    S.lastXP      = UnitXP("player") or 0
    S.lastMax     = UnitXPMax("player") or 0
    S.paused      = false
    S.autoPaused  = false
    S.pauseStart  = 0
    S.pausedTotal = 0
    S.src         = { quest = 0, mob = 0, expl = 0 }
    S.zones       = {}
    S.zone        = curZone()
end

function SK:XPSaveSession()
    if not S.active then return end
    local el = SK:XPElapsed()
    if el < 30 then return end           -- ignorar sesiones triviales
    local db = EnsureDB()
    table.insert(db.Sessions, 1, {
        date     = date("%Y-%m-%d %H:%M"),
        duration = el,
        xp       = S.xpGained,
        xph      = (el > 0) and (S.xpGained / el * 3600) or 0,
        levels   = (UnitLevel("player") or 0) - S.startLevel,
    })
    while #db.Sessions > 50 do table.remove(db.Sessions) end
end

function SK:XPPause(auto)
    if not S.active or S.paused then return end
    S.paused     = true
    S.autoPaused = auto and true or false
    S.pauseStart = GetTime()
end

function SK:XPResume()
    if not S.active or not S.paused then return end
    S.pausedTotal = S.pausedTotal + (GetTime() - S.pauseStart)
    S.paused      = false
    S.autoPaused  = false
    S.lastXP      = UnitXP("player") or 0   -- no contar XP ganada durante la pausa
    S.lastMax     = UnitXPMax("player") or 0
end

function SK:XPTogglePause()
    if not S.active then return end
    if S.paused then SK:XPResume() else SK:XPPause(false) end
end

function SK:XPSetEnabled(on)
    local db = EnsureDB()
    db.enabled = on and true or false
    if on then
        if not S.active then SK:XPNewSession(false) end
    else
        if S.active then SK:XPSaveSession(); S.active = false end
    end
end

function SK:XPResetStats()
    local db = EnsureDB()
    db.Sessions = {}
    db.Zones    = {}
    db.Quests   = {}
    SK:XPNewSession(false)
end

-- ── Manejo de XP total y por zona ───────────────────────────────────────────
local function OnXPUpdate()
    if not S.active then return end
    local cur = UnitXP("player") or 0
    local mx  = UnitXPMax("player") or 0
    local delta
    if mx == S.lastMax then
        delta = cur - S.lastXP
    else
        delta = (S.lastMax - S.lastXP) + cur   -- cruce de nivel
    end
    S.lastXP = cur
    S.lastMax = mx
    if delta and delta > 0 and not S.paused then
        S.xpGained = S.xpGained + delta
        local z = S.zone or curZone()
        local db = EnsureDB()
        db.Zones[z] = db.Zones[z] or { xp = 0, time = 0 }
        db.Zones[z].xp = db.Zones[z].xp + delta
        S.zones[z] = S.zones[z] or { xp = 0, time = 0 }
        S.zones[z].xp = S.zones[z].xp + delta
    end
end

-- ── Medicion de XP de entrega de quest (diferida) ───────────────────────────
local questPending = nil
local function MeasureQuestXP()
    local after  = UnitXP("player") or 0
    local xp     = after - questPending.xpBefore
    if xp < 0 then xp = (questPending.maxBefore - questPending.xpBefore) + after end
    local qid    = questPending.qid
    local name   = questPending.name
    local db     = EnsureDB()
    local accept = qid and db.accepts[qid]
    local duration = accept and (time() - accept) or nil
    if S.active and not S.paused then S.src.quest = S.src.quest + xp end
    if qid then
        local q = db.Quests[qid] or { name = name, xp = 0, count = 0, time = 0 }
        q.name  = name or q.name
        q.xp    = q.xp + xp
        q.count = q.count + 1
        if duration and duration > 0 then q.time = q.time + duration end
        local xpm = (duration and duration > 0) and (xp / (duration / 60)) or nil
        q.lastXPM = xpm
        if xpm and (not q.bestXPM or xpm > q.bestXPM) then q.bestXPM = xpm end
        db.Quests[qid] = q
        db.accepts[qid] = nil
    end
    questPending = nil
end

-- ── Auto-pausa por AFK ──────────────────────────────────────────────────────
local function OnFlagsChanged()
    local db = EnsureDB()
    if not (db.autoPauseAFK and S.active) then return end
    if UnitIsAFK("player") then
        if not S.paused then SK:XPPause(true) end
    elseif S.autoPaused then
        SK:XPResume()
    end
end

-- ============================================================================
-- INTERFAZ
-- ============================================================================
local W = {}            -- referencias de widgets
local ROWS = 9
local ROWH = 18

local function NewScroll(parent, updateFn)
    local sf = CreateFrame("ScrollFrame", "SKQ_XPScroll_" .. tostring(parent:GetName() or math.random(1, 99999)),
                           parent, "FauxScrollFrameTemplate")
    sf:SetPoint("TOPLEFT", 4, -4)
    sf:SetPoint("BOTTOMRIGHT", -28, 4)
    sf.rows = {}
    for i = 1, ROWS do
        local r = CreateFrame("Frame", nil, parent)
        r:SetHeight(ROWH)
        if i == 1 then r:SetPoint("TOPLEFT", sf, "TOPLEFT", 0, -1)
        else           r:SetPoint("TOPLEFT", sf.rows[i - 1], "BOTTOMLEFT", 0, 0) end
        r:SetPoint("RIGHT", sf, "RIGHT", -2, 0)
        r.left  = r:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
        r.left:SetPoint("LEFT", 2, 0); r.left:SetJustifyH("LEFT"); r.left:SetWidth(150)
        if r.left.SetWordWrap then r.left:SetWordWrap(false) end
        r.mid   = r:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
        r.mid:SetPoint("RIGHT", -78, 0); r.mid:SetJustifyH("RIGHT")
        r.right = r:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
        r.right:SetPoint("RIGHT", -4, 0); r.right:SetJustifyH("RIGHT"); r.right:SetWidth(72)
        sf.rows[i] = r
    end
    sf:SetScript("OnVerticalScroll", function(self, offset)
        FauxScrollFrame_OnVerticalScroll(self, offset, ROWH, function() updateFn() end)
    end)
    sf.update = updateFn
    return sf
end

local function MakeButton(parent, w, text, onClick)
    local b = CreateFrame("Button", nil, parent, "UIPanelButtonTemplate")
    b:SetSize(w, 22)
    b:SetText(text)
    b:SetScript("OnClick", onClick)
    return b
end

-- XP/h "real": el promedio de la ULTIMA sesion ya terminada (total / tiempo).
-- Se evita el XP/h en vivo porque al inicio de la sesion es irreal (muy volatil).
local function LastSessionXPH()
    local db = EnsureDB()
    local s = db.Sessions and db.Sessions[1]
    if s and s.xph and s.xph > 0 then return s.xph end
    return nil
end

-- XP/h "en vivo": tras 1 min de sesión activa usamos el ritmo real actual; si no
-- hay sesión válida, caemos a la última sesión terminada. nil si no hay dato.
local function CurrentXPH()
    if S.active and not S.paused then
        local el = SK:XPElapsed()
        if el and el > 60 and S.xpGained and S.xpGained > 0 then
            return S.xpGained / el * 3600
        end
    end
    return LastSessionXPH()
end

-- ── Refresco: pestana SESION ────────────────────────────────────────────────
local function RefreshSession()
    local el  = SK:XPElapsed()
    W.xph:SetText("|cffffffff" .. comma(S.xpGained) .. "|r |cff33ff99XP|r")
    local last = LastSessionXPH()
    if last then
        W.gained:SetText(T("XP/h última sesión: ", "Last session XP/h: ") .. "|cff33ff99" .. comma(last) .. "|r")
    else
        W.gained:SetText("|cff888888" .. T("XP/h: se calcula al finalizar la sesión", "XP/h: calculated when the session ends") .. "|r")
    end
    W.timep:SetText(T("Tiempo: ", "Time: ") .. "|cffffffff" .. durStr(el) .. "|r")
    W.levelp:SetText(T("Nivel: ", "Level: ") .. "|cffffffff" .. (UnitLevel("player") or 0) .. "|r")

    -- F1: tiempo estimado al siguiente nivel (con XP/h real observada)
    if W.f1 then
        local cur = UnitXP("player") or 0
        local mx  = UnitXPMax("player") or 0
        local lvl = UnitLevel("player") or 0
        local remaining = mx - cur
        local pct = (mx > 0) and math.floor(cur / mx * 100 + 0.5) or 0
        local xph = CurrentXPH()
        if mx <= 0 or lvl >= 80 then
            W.f1:SetText("|cffaaaaaa" .. T("Nivel máximo alcanzado.", "Max level reached.") .. "|r")
        elseif xph and xph > 0 then
            local secs = remaining / xph * 3600
            W.f1:SetText(
                T("Completado: ", "Completed: ") .. "|cffffffff" .. pct .. "%|r  " ..
                "|cff888888(" .. comma(remaining) .. " XP " .. T("restante", "left") .. ")|r\n" ..
                T("Tiempo estimado: ", "ETA: ") .. "|cff33ff99" .. durStr(secs) ..
                "|r |cff888888(" .. comma(xph) .. " XP/h)|r")
        else
            W.f1:SetText(
                T("Completado: ", "Completed: ") .. "|cffffffff" .. pct .. "%|r  " ..
                "|cff888888(" .. comma(remaining) .. " XP " .. T("restante", "left") .. ")|r\n" ..
                "|cff888888" .. T("Tiempo estimado: — (sin XP/h aún)", "ETA: — (no XP/h yet)") .. "|r")
        end
    end

    local total = S.xpGained
    local q, m, e = S.src.quest, S.src.mob, S.src.expl
    local other = total - (q + m + e)
    if other < 0 then other = 0 end
    local function line(v)
        local pct = (total > 0) and math.floor(v / total * 100 + 0.5) or 0
        return "|cffffffff" .. comma(v) .. "|r |cff888888(" .. pct .. "%)|r"
    end
    W.sQuest:SetText(line(q))
    W.sMob:SetText(line(m))
    W.sExpl:SetText(line(e))
    W.sOther:SetText(line(other))

    if not EnsureDB().enabled then
        W.status:SetText("|cffff5555" .. T("Seguimiento DESACTIVADO", "Tracking DISABLED") .. "|r")
    elseif S.paused then
        local why = S.autoPaused and (" (AFK)") or ""
        W.status:SetText("|cffffcc00" .. T("EN PAUSA", "PAUSED") .. why .. "|r")
    else
        W.status:SetText("|cff33ff99" .. T("Activo", "Active") .. "|r")
    end
    W.btnPause:SetText(S.paused and T("Reanudar", "Resume") or T("Pausar", "Pause"))
    W.btnEnable:SetText(EnsureDB().enabled and T("Desactivar", "Disable") or T("Activar", "Enable"))
end

-- ── Refresco: vista compacta ────────────────────────────────────────────────
local function RefreshCompact()
    if not W.cXph then return end
    local el  = SK:XPElapsed()
    W.cXph:SetText("|cffffffff" .. comma(S.xpGained) .. "|r |cff33ff99XP|r")
    W.cGained:SetText(T("Tiempo: ", "Time: ") .. "|cffffffff" .. durStr(el) .. "|r")
    local last = LastSessionXPH()
    if last then
        W.cTime:SetText("|cff888888" .. T("XP/h última: ", "Last XP/h: ") .. "|r|cff33ff99" .. comma(last) .. "|r")
    else
        W.cTime:SetText("|cff888888" .. T("XP/h: al finalizar la sesión", "XP/h: at session end") .. "|r")
    end
    if not EnsureDB().enabled then
        W.cStatus:SetText("|cffff5555" .. T("OFF", "OFF") .. "|r")
    elseif S.paused then
        W.cStatus:SetText("|cffffcc00" .. T("PAUSA", "PAUSED") .. "|r")
    else
        W.cStatus:SetText("|cff33ff99" .. T("Activo", "Active") .. "|r")
    end
end

-- ── Refresco: pestana ZONAS ─────────────────────────────────────────────────
local zoneArr = {}
local function RefreshZones()
    wipe(zoneArr)
    for name, z in pairs(EnsureDB().Zones) do
        if (z.time or 0) > 0 then
            table.insert(zoneArr, { name = name, xp = z.xp or 0, time = z.time, xph = (z.xp or 0) / z.time * 3600 })
        end
    end
    table.sort(zoneArr, function(a, b) return a.xph > b.xph end)
    local sf = W.zScroll
    FauxScrollFrame_Update(sf, #zoneArr, ROWS, ROWH)
    local off = FauxScrollFrame_GetOffset(sf)
    for i = 1, ROWS do
        local r = sf.rows[i]
        local d = zoneArr[i + off]
        if d then
            r.left:SetText(d.name)
            r.mid:SetText("|cff888888" .. comma(d.xp) .. "|r")
            r.right:SetText("|cff33ff99" .. comma(d.xph) .. "|r")
            r:Show()
        else r:Hide() end
    end
end

-- ── Refresco: pestana QUESTS ────────────────────────────────────────────────
local questArr = {}
local function RefreshQuests()
    wipe(questArr)
    for qid, q in pairs(EnsureDB().Quests) do
        local avg = (q.time and q.time > 0) and (q.xp / (q.time / 60)) or q.bestXPM
        local cnt = q.count or 0
        local avgTime = (cnt > 0 and q.time and q.time > 0) and (q.time / cnt) or nil
        table.insert(questArr, {
            name = q.name or ("Quest " .. tostring(qid)),
            xpm = avg, count = cnt, xp = q.xp or 0, avgTime = avgTime,
        })
    end
    table.sort(questArr, function(a, b) return (a.xpm or -1) > (b.xpm or -1) end)
    local sf = W.qScroll
    FauxScrollFrame_Update(sf, #questArr, ROWS, ROWH)
    local off = FauxScrollFrame_GetOffset(sf)
    for i = 1, ROWS do
        local r = sf.rows[i]
        local d = questArr[i + off]
        if d then
            local label, color = ratingFor(d.xpm)
            -- F11 "Worth It?": punto coloreado (los emoji no renderizan en 3.3.5a)
            r.left:SetText("|cff" .. color .. "\226\151\143|r |cff" .. color .. d.name .. "|r")
            r.mid:SetText("|cff888888x" .. d.count .. "|r")
            r.right:SetText(d.xpm and ("|cff" .. color .. comma(d.xpm) .. "|r") or "|cff888888-|r")
            r.skqQ = d
            if not r.skqHooked then
                r.skqHooked = true
                r:EnableMouse(true)
                r:SetScript("OnEnter", function(self)
                    local q = self.skqQ
                    if not q then return end
                    local lab, col = ratingFor(q.xpm)
                    GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
                    GameTooltip:AddLine(q.name, 1, 0.82, 0)
                    GameTooltip:AddDoubleLine("XP:", comma(q.xp), 1, 1, 1, 1, 1, 1)
                    GameTooltip:AddDoubleLine(T("Tiempo medio:", "Avg time:"),
                        q.avgTime and durStr(q.avgTime) or "-", 1, 1, 1, 1, 1, 1)
                    GameTooltip:AddDoubleLine("XP/min:", q.xpm and comma(q.xpm) or "-", 1, 1, 1, 1, 1, 1)
                    GameTooltip:AddDoubleLine(T("Clasificación:", "Rating:"),
                        "|cff" .. col .. lab .. "|r", 1, 1, 1)
                    GameTooltip:Show()
                end)
                r:SetScript("OnLeave", function() GameTooltip:Hide() end)
            end
            r:Show()
        else
            r.skqQ = nil
            r:Hide()
        end
    end
end

-- ── Refresco: pestana HISTORIAL ─────────────────────────────────────────────
local function RefreshHistory()
    local db = EnsureDB()
    -- resumen
    local bestXPH = 0
    for _, s in ipairs(db.Sessions) do if (s.xph or 0) > bestXPH then bestXPH = s.xph end end
    local bz, bzv, wz, wzv
    for name, z in pairs(db.Zones) do
        if (z.time or 0) > 60 then
            local xph = (z.xp or 0) / z.time * 3600
            if not bzv or xph > bzv then bz, bzv = name, xph end
            if not wzv or xph < wzv then wz, wzv = name, xph end
        end
    end
    local bestQ, bestQv
    for _, q in pairs(db.Quests) do
        local avg = (q.time and q.time > 0) and (q.xp / (q.time / 60)) or q.bestXPM
        if avg and (not bestQv or avg > bestQv) then bestQ, bestQv = (q.name or "?"), avg end
    end
    W.hSummary:SetText(
        T("Mejor XP/h: ", "Best XP/h: ") .. "|cff33ff99" .. comma(bestXPH) .. "|r\n" ..
        T("Mejor zona: ", "Best zone: ") .. "|cffffffff" .. (bz or "-") ..
            (bzv and (" |cff33ff99" .. comma(bzv) .. "|r") or "") .. "\n" ..
        T("Peor zona: ", "Worst zone: ") .. "|cffffffff" .. (wz or "-") ..
            (wzv and (" |cffff5555" .. comma(wzv) .. "|r") or "") .. "\n" ..
        T("Mejor quest: ", "Best quest: ") .. "|cffffffff" .. (bestQ or "-") ..
            (bestQv and (" |cff33ff99" .. comma(bestQv) .. " xp/m|r") or "")
    )
    -- lista de sesiones
    local sf = W.hScroll
    FauxScrollFrame_Update(sf, #db.Sessions, ROWS, ROWH)
    local off = FauxScrollFrame_GetOffset(sf)
    for i = 1, ROWS do
        local r = sf.rows[i]
        local d = db.Sessions[i + off]
        if d then
            r.left:SetText("|cffcccccc" .. (d.date or "?") .. "|r")
            r.mid:SetText("|cff888888" .. durStr(d.duration) .. "|r")
            r.right:SetText("|cff33ff99" .. comma(d.xph) .. "|r")
            r:Show()
        else r:Hide() end
    end
end

-- ── Rastreador de BOTIN (loot) por nombre ───────────────────────────────────
-- El usuario escribe el nombre del objeto (en inglés) en un buscador; cada vez
-- que lo recoge se cuenta y se reparte por zona para ver dónde lo farmea más.
local lootArr = {}
local function RefreshLoot()
    local db  = EnsureDB()
    local sf  = W.lootScroll
    local rec = db.LootActive and db.Loot[db.LootActive]
    if not rec then
        if W.lootHdr then
            W.lootHdr:SetText("|cffaaaaaa" .. T(
                "Escribe el nombre de un objeto en inglés (ej: Linen Cloth) y pulsa Trackear.",
                "Type an item name in English (e.g. Linen Cloth) and press Track.") .. "|r")
        end
        if sf then
            FauxScrollFrame_Update(sf, 0, ROWS, ROWH)
            for i = 1, ROWS do sf.rows[i]:Hide() end
        end
        return
    end
    wipe(lootArr)
    rec.zones = rec.zones or {}
    local bz, bn
    for z, n in pairs(rec.zones) do
        table.insert(lootArr, { name = z, n = n })
        if not bn or n > bn then bz, bn = z, n end
    end
    table.sort(lootArr, function(a, b) return a.n > b.n end)
    local tot = rec.total or 0
    W.lootHdr:SetText(
        "|cffffd100" .. (rec.name or "?") .. "|r  |cff888888x|r|cffffffff" .. comma(tot) .. "|r\n" ..
        (bz and (T("Más farmeado en: ", "Most farmed in: ") .. "|cff33ff99" .. bz ..
                 "|r |cff888888(" .. comma(bn) .. ")|r")
            or ("|cff888888" .. T("Aún sin botín registrado para este objeto…",
                                  "No loot recorded for this item yet…") .. "|r"))
    )
    FauxScrollFrame_Update(sf, #lootArr, ROWS, ROWH)
    local off = FauxScrollFrame_GetOffset(sf)
    for i = 1, ROWS do
        local r = sf.rows[i]
        local d = lootArr[i + off]
        if d then
            r.left:SetText("|cffffffff" .. d.name .. "|r")
            r.mid:SetText("")
            r.right:SetText("|cff33ff99" .. comma(d.n) .. "|r")
            r:Show()
        else r:Hide() end
    end
end

local function recordLoot(name, count)
    if not name then return end
    local db  = EnsureDB()
    local key = name:lower()
    local rec = db.Loot[key]
    if not rec then return end   -- solo cuenta objetos que el usuario eligió trackear
    rec.name  = name
    rec.total = (rec.total or 0) + count
    rec.zones = rec.zones or {}
    local z   = curZone()
    rec.zones[z] = (rec.zones[z] or 0) + count
    if db.LootActive == key then SK:XPRefresh() end
end

-- Parseo de mensajes de loot propios (no de otros jugadores). Reusa fmtToPattern.
-- Los patrones "_MULTIPLE" se prueban primero porque traen la cantidad (x%d).
local lootPats
local function onLoot(msg)
    if not msg then return end
    if not lootPats then
        lootPats = {
            { fmtToPattern(LOOT_ITEM_SELF_MULTIPLE),        true  },
            { fmtToPattern(LOOT_ITEM_PUSHED_SELF_MULTIPLE), true  },
            { fmtToPattern(LOOT_ITEM_SELF),                 false },
            { fmtToPattern(LOOT_ITEM_PUSHED_SELF),          false },
        }
    end
    local link, count
    for _, p in ipairs(lootPats) do
        if p[1] then
            if p[2] then link, count = msg:match(p[1])
            else         link, count = msg:match(p[1]), 1 end
            if link then break end
        end
    end
    if not link then return end
    local name = link:match("%[(.-)%]")
    if not name or name == "" then return end
    recordLoot(name, tonumber(count) or 1)
end

function SK:XPTrackLoot(name)
    if not name then return end
    name = name:gsub("^%s+", ""):gsub("%s+$", "")
    if name == "" then return end
    local db  = EnsureDB()
    local key = name:lower()
    if not db.Loot[key] then db.Loot[key] = { name = name, total = 0, zones = {} } end
    db.LootActive = key
    SK:XPRefresh()
end

-- Limpiar = dejar de trackear el objeto activo y vaciar sus datos y el buscador,
-- volviendo al estado inicial (mensaje "escribe un objeto…").
function SK:XPLootClear()
    local db  = EnsureDB()
    local key = db.LootActive
    if key and db.Loot[key] then db.Loot[key] = nil end
    db.LootActive = false
    if W.lootSearch then W.lootSearch:SetText(""); W.lootSearch:ClearFocus() end
    SK:XPRefresh()
end

-- ── Refresco: F4 ESTADÍSTICAS globales persistentes ─────────────────────────
local function RefreshStats()
    if not W.statsText then return end
    local g = (SK.StatsGet and SK:StatsGet()) or {}
    local function ln(lbl, val)
        return "|cffaaaaaa" .. lbl .. "|r  |cffffffff" .. val .. "|r"
    end
    local gold = g.gold or 0
    local goldStr = GetCoinTextureString and GetCoinTextureString(gold) or comma(gold)
    W.statsText:SetText(table.concat({
        ln(T("Tiempo jugado:", "Played time:"),           durStr(g.played or 0)),
        ln(T("Quests completadas:", "Quests completed:"),  comma(g.questsDone or 0)),
        ln(T("Quests abandonadas:", "Quests abandoned:"),  comma(g.questsAbandoned or 0)),
        ln(T("Mobs asesinados:", "Mobs killed:"),          comma(g.mobsKilled or 0)),
        ln(T("XP obtenida:", "XP gained:"),                comma(g.xp or 0)),
        ln(T("Niveles ganados:", "Levels gained:"),        comma(g.levels or 0)),
        ln(T("Oro obtenido:", "Gold gained:"),             goldStr),
        ln(T("Muertes:", "Deaths:"),                       comma(g.deaths or 0)),
    }, "\n"))
end

-- ── Refresco: F8 ANÁLISIS DE TIEMPO PERDIDO ─────────────────────────────────
local TIME_DEF = {
    { "questing", "Questing", "Questing" },
    { "combat",   "Combate",  "Combat" },
    { "travel",   "Viaje",    "Travel" },
    { "flight",   "Vuelo",    "Flight" },
    { "city",     "Ciudad",   "City" },
    { "afk",      "AFK",      "AFK" },
    { "dead",     "Muerto",   "Dead" },
}
local function RefreshTime()
    if not W.timeText then return end
    local data = SK.StatsTimeData and SK:StatsTimeData()
    local cats = (data and data.last) or {}
    local label = T("Última sesión", "Last session")
    local total = 0
    for _, c in ipairs(TIME_DEF) do total = total + (cats[c[1]] or 0) end
    if total <= 0 and data then
        cats  = data.session or {}
        label = T("Sesión actual", "Current session")
        total = 0
        for _, c in ipairs(TIME_DEF) do total = total + (cats[c[1]] or 0) end
    end
    if total <= 0 then
        W.timeText:SetText("|cff888888" .. T("Sin datos de sesión todavía…", "No session data yet…") .. "|r")
        return
    end
    local arr = {}
    for _, c in ipairs(TIME_DEF) do
        table.insert(arr, { label = T(c[2], c[3]), v = cats[c[1]] or 0 })
    end
    table.sort(arr, function(a, b) return a.v > b.v end)
    local out = { "|cffffd100" .. label .. "|r  |cff888888(" .. durStr(total) .. ")|r", "" }
    for _, e in ipairs(arr) do
        local pct = math.floor(e.v / total * 100 + 0.5)
        table.insert(out, "|cffaaaaaa" .. e.label .. ":|r  |cffffffff" .. pct .. "%|r  |cff666666(" .. durStr(e.v) .. ")|r")
    end
    W.timeText:SetText(table.concat(out, "\n"))
end

-- ── Refresco: F6 BUSCADOR DE NPCs ───────────────────────────────────────────
local npcArr = {}
local function RefreshNPCs()
    local sf = W.npcScroll
    if not sf then return end
    local query = W.npcQuery or ""
    wipe(npcArr)
    if query ~= "" and SK.SearchNPC then
        for _, r in ipairs(SK:SearchNPC(query)) do table.insert(npcArr, r) end
    end
    if W.npcHdr then
        if query == "" then
            W.npcHdr:SetText("|cffaaaaaa" .. T("Escribe el nombre de un NPC observado.", "Type an observed NPC name.") .. "|r")
        else
            W.npcHdr:SetText("|cffffd100" .. #npcArr .. "|r |cffaaaaaa" .. T("resultados", "results") .. "|r")
        end
    end
    FauxScrollFrame_Update(sf, #npcArr, ROWS, ROWH)
    local off = FauxScrollFrame_GetOffset(sf)
    for i = 1, ROWS do
        local r = sf.rows[i]
        local d = npcArr[i + off]
        if d then
            r.left:SetText("|cffffffff" .. (d.name or "?") .. "|r")
            r.mid:SetText("|cff888888" .. (d.zone or "") .. "|r")
            local coord = (d.x and d.y) and string.format("%.1f, %.1f", d.x, d.y) or "-"
            r.right:SetText("|cff33ff99" .. coord .. "|r")
            r:Show()
        else r:Hide() end
    end
end

-- ── Refresco: F9 MOB INSPECTOR (panel + tooltip de loot) ────────────────────
local mobArr = {}
local function RefreshMobs()
    local sf = W.mobScroll
    if not sf then return end
    local query = (W.mobQuery or ""):lower()
    wipe(mobArr)
    local mobs = SKQ_Stats and SKQ_Stats.mobs
    if mobs then
        for name, m in pairs(mobs) do
            if (m.kills or 0) > 0 and (query == "" or name:lower():find(query, 1, true)) then
                table.insert(mobArr, m)
            end
        end
    end
    table.sort(mobArr, function(a, b) return (a.kills or 0) > (b.kills or 0) end)
    if W.mobHdr then
        W.mobHdr:SetText("|cffaaaaaa" .. T("Mobs observados — kills · XP media. Pasa el cursor para ver el loot.",
                                           "Observed mobs — kills · avg XP. Hover for loot.") .. "|r")
    end
    FauxScrollFrame_Update(sf, #mobArr, ROWS, ROWH)
    local off = FauxScrollFrame_GetOffset(sf)
    for i = 1, ROWS do
        local r = sf.rows[i]
        local d = mobArr[i + off]
        if d then
            r.left:SetText("|cffffffff" .. (d.name or "?") .. "|r")
            r.mid:SetText("|cff888888x" .. (d.kills or 0) .. "|r")
            local avg = (d.xpKills and d.xpKills > 0) and comma(d.xpTotal / d.xpKills) or "-"
            r.right:SetText("|cff33ff99" .. avg .. "|r")
            r.skqMob = d
            if not r.skqHooked then
                r.skqHooked = true
                r:EnableMouse(true)
                r:SetScript("OnEnter", function(self)
                    local m = self.skqMob
                    if not m then return end
                    GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
                    GameTooltip:AddLine(m.name or "?", 1, 0.82, 0)
                    if m.level then GameTooltip:AddDoubleLine(T("Nivel", "Level"), tostring(m.level), 1, 1, 1, 1, 1, 1) end
                    GameTooltip:AddDoubleLine(T("Kills registradas", "Kills recorded"), tostring(m.kills or 0), 1, 1, 1, 1, 1, 1)
                    if m.xpKills and m.xpKills > 0 then
                        GameTooltip:AddDoubleLine(T("XP media", "Avg XP"), comma(m.xpTotal / m.xpKills), 1, 1, 1, 0.6, 1, 0.6)
                    end
                    if m.loot and (m.looted or 0) > 0 then
                        local la = {}
                        for iname, cnt in pairs(m.loot) do table.insert(la, { n = iname, c = cnt }) end
                        table.sort(la, function(a, b) return a.c > b.c end)
                        if #la > 0 then
                            GameTooltip:AddLine(" ")
                            GameTooltip:AddLine(T("Loot observado:", "Observed loot:"), 0.7, 0.7, 0.7)
                            for j = 1, math.min(5, #la) do
                                local pct = math.floor(la[j].c / m.looted * 100 + 0.5)
                                GameTooltip:AddDoubleLine(la[j].n, pct .. "%", 0.9, 0.9, 0.9, 0.6, 1, 0.6)
                            end
                        end
                    end
                    GameTooltip:Show()
                end)
                r:SetScript("OnLeave", function() GameTooltip:Hide() end)
            end
            r:Show()
        else
            r.skqMob = nil
            r:Hide()
        end
    end
end

-- ── Cambio de pestana ───────────────────────────────────────────────────────
local function ShowTab(name)
    W.curTab = name
    for k, frame in pairs(W.tabs) do frame:Hide() end
    for k, btn in pairs(W.tabBtns) do
        btn.txt:SetTextColor(k == name and 1 or 0.6, k == name and 0.82 or 0.6, k == name and 0 or 0.6)
    end
    W.tabs[name]:Show()
    SK:XPRefresh()
end

function SK:XPRefresh()
    if not W.frame or not W.frame:IsShown() then return end
    if EnsureDB().window.min then RefreshCompact(); return end
    if     W.curTab == "session" then RefreshSession()
    elseif W.curTab == "zones"   then RefreshZones()
    elseif W.curTab == "quests"  then RefreshQuests()
    elseif W.curTab == "history" then RefreshHistory()
    elseif W.curTab == "loot"    then RefreshLoot()
    elseif W.curTab == "stats"   then RefreshStats()
    elseif W.curTab == "time"    then RefreshTime()
    elseif W.curTab == "npcs"    then RefreshNPCs()
    elseif W.curTab == "mobs"    then RefreshMobs() end
end

-- ── Construccion de la ventana ──────────────────────────────────────────────
local function BuildWindow()
    if W.frame then return W.frame end
    local f = CreateFrame("Frame", "SKQ_XPFrame", UIParent)
    f:SetSize(400, 384)
    W.fullW, W.fullH = 400, 384
    W.compactW, W.compactH = 236, 104
    f:SetFrameStrata("DIALOG")
    SKQ_EnsureBackdrop(f)
    f:SetBackdrop({
        bgFile   = "Interface\\DialogFrame\\UI-DialogBox-Background",
        edgeFile = "Interface\\DialogFrame\\UI-DialogBox-Border",
        tile = true, tileSize = 32, edgeSize = 32,
        insets = { left = 11, right = 12, top = 12, bottom = 11 },
    })
    f:SetMovable(true)
    f:EnableMouse(true)
    f:RegisterForDrag("LeftButton")
    f:SetScript("OnDragStart", function(self) self:StartMoving() end)
    f:SetScript("OnDragStop", function(self)
        self:StopMovingOrSizing()
        local p, _, rp, x, y = self:GetPoint()
        local db = EnsureDB()
        db.window.point, db.window.rp, db.window.x, db.window.y = p, rp, x, y
    end)
    f:SetScript("OnShow", function() EnsureDB().window.shown = true; SK:XPRefresh() end)
    f:SetScript("OnHide", function() EnsureDB().window.shown = false end)
    W.frame = f

    local db = EnsureDB()
    if db.window.min == nil then db.window.min = true end
    if db.window.point then
        f:ClearAllPoints()
        f:SetPoint(db.window.point, UIParent, db.window.rp or db.window.point, db.window.x or 0, db.window.y or 0)
    else
        f:SetPoint("CENTER")
    end

    local title = f:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    title:SetPoint("TOP", 0, -16)
    title:SetText("SKQ Experience Appraiser")
    W.title = title

    local close = CreateFrame("Button", nil, f, "UIPanelCloseButton")
    close:SetPoint("TOPRIGHT", -6, -6)

    -- Botón de minimizar (estilo tracker)
    local minBtn = CreateFrame("Button", nil, f)
    minBtn:SetSize(22, 22)
    minBtn:SetPoint("RIGHT", close, "LEFT", 6, 0)
    local minTxt = minBtn:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    minTxt:SetAllPoints()
    minTxt:SetJustifyH("CENTER")
    minTxt:SetJustifyV("MIDDLE")
    minTxt:SetText("-")
    minTxt:SetTextColor(1, 0.82, 0)
    minBtn.txt = minTxt
    minBtn:SetScript("OnEnter", function() minTxt:SetTextColor(1, 1, 1) end)
    minBtn:SetScript("OnLeave", function() minTxt:SetTextColor(1, 0.82, 0) end)
    minBtn:SetScript("OnClick", function() SK:XPToggleMinimize() end)
    W.minBtn = minBtn

    -- Vista compacta (resumen acotado): XP/h, XP total y tiempo
    W.cXph = f:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    W.cXph:SetPoint("TOP", 0, -36)
    W.cGained = f:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    W.cGained:SetPoint("TOPLEFT", 18, -62)
    W.cTime = f:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    W.cTime:SetPoint("TOPLEFT", 18, -82)
    W.cStatus = f:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    W.cStatus:SetPoint("TOPRIGHT", -18, -62)
    W.compact = { W.cXph, W.cGained, W.cTime, W.cStatus }

    -- pestanas
    W.tabs, W.tabBtns = {}, {}
    local tabDefs = {
        { "session", T("Sesión", "Session") },
        { "zones",   T("Zonas", "Zones") },
        { "quests",  "Quests" },
        { "history", T("Historial", "History") },
        { "loot",    T("Botín", "Loot") },
        { "stats",   "Stats" },
        { "time",    T("Tiempo", "Time") },
        { "npcs",    "NPCs" },
        { "mobs",    "Mobs" },
    }
    local TABW, PERROW = 74, 5
    for i, d in ipairs(tabDefs) do
        local key, label = d[1], d[2]
        local col = (i - 1) % PERROW
        local row = math.floor((i - 1) / PERROW)
        local b = CreateFrame("Button", nil, f)
        b:SetSize(TABW, 22)
        b:SetPoint("TOPLEFT", 16 + col * (TABW + 1), -42 - row * 23)
        b.txt = b:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
        b.txt:SetPoint("CENTER")
        b.txt:SetText(label)
        b:SetScript("OnClick", function() ShowTab(key) end)
        local hl = b:CreateTexture(nil, "BACKGROUND")
        hl:SetAllPoints(); hl:SetTexture(1, 1, 1, 0.08)
        W.tabBtns[key] = b

        local c = CreateFrame("Frame", nil, f)
        c:SetPoint("TOPLEFT", 16, -94)
        c:SetPoint("BOTTOMRIGHT", -16, 16)
        c:Hide()
        W.tabs[key] = c
    end

    -- contenido: SESION
    do
        local c = W.tabs.session
        W.xph = c:CreateFontString(nil, "OVERLAY", "GameFontNormalHuge")
        W.xph:SetPoint("TOP", 0, -6)
        W.gained = c:CreateFontString(nil, "OVERLAY", "GameFontNormal")
        W.gained:SetPoint("TOPLEFT", 8, -44)
        W.timep = c:CreateFontString(nil, "OVERLAY", "GameFontNormal")
        W.timep:SetPoint("TOPLEFT", 8, -66)
        W.levelp = c:CreateFontString(nil, "OVERLAY", "GameFontNormal")
        W.levelp:SetPoint("TOPRIGHT", -8, -66)
        W.status = c:CreateFontString(nil, "OVERLAY", "GameFontNormal")
        W.status:SetPoint("TOPRIGHT", -8, -44)

        local hdr = c:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
        hdr:SetPoint("TOPLEFT", 8, -96)
        hdr:SetText("|cffaaaaaa" .. T("Fuentes de XP", "XP sources") .. "|r")
        local function srcRow(labelEs, labelEn, y)
            local l = c:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
            l:SetPoint("TOPLEFT", 12, y)
            l:SetText(T(labelEs, labelEn))
            local v = c:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
            v:SetPoint("TOPLEFT", 130, y)
            return v
        end
        W.sQuest = srcRow("Quest:", "Quest:", -114)
        W.sMob   = srcRow("Mobs:", "Mobs:", -132)
        W.sExpl  = srcRow("Exploración:", "Exploration:", -150)
        W.sOther = srcRow("Otros:", "Other:", -168)

        local f1hdr = c:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
        f1hdr:SetPoint("TOPLEFT", 8, -190)
        f1hdr:SetText("|cffaaaaaa" .. T("Siguiente nivel", "Next level") .. "|r")
        W.f1 = c:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
        W.f1:SetPoint("TOPLEFT", 12, -206)
        W.f1:SetPoint("TOPRIGHT", -12, -206)
        W.f1:SetJustifyH("LEFT")
        W.f1:SetSpacing(3)

        W.btnPause = MakeButton(c, 110, T("Pausar", "Pause"), function() SK:XPTogglePause(); SK:XPRefresh() end)
        W.btnPause:SetPoint("BOTTOMLEFT", 4, 6)
        W.btnNew = MakeButton(c, 110, T("Nueva sesión", "New session"), function() SK:XPNewSession(true); SK:XPRefresh() end)
        W.btnNew:SetPoint("BOTTOM", 0, 6)
        W.btnEnable = MakeButton(c, 110, T("Desactivar", "Disable"), function()
            SK:XPSetEnabled(not EnsureDB().enabled); SK:XPRefresh()
        end)
        W.btnEnable:SetPoint("BOTTOMRIGHT", -4, 6)
    end

    -- contenido: ZONAS / QUESTS / HISTORIAL
    W.zScroll = NewScroll(W.tabs.zones, RefreshZones)
    W.qScroll = NewScroll(W.tabs.quests, RefreshQuests)

    do
        local c = W.tabs.history
        W.hSummary = c:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
        W.hSummary:SetPoint("TOPLEFT", 8, -4)
        W.hSummary:SetJustifyH("LEFT")
        W.hSummary:SetSpacing(3)
        local listHost = CreateFrame("Frame", "SKQ_XPHistHost", c)
        listHost:SetPoint("TOPLEFT", 0, -82)
        listHost:SetPoint("BOTTOMRIGHT", 0, 30)
        W.hScroll = NewScroll(listHost, RefreshHistory)
        W.btnReset = MakeButton(c, 150, T("Reiniciar estadísticas", "Reset stats"), function()
            StaticPopup_Show("SKQ_XP_RESET")
        end)
        W.btnReset:SetPoint("BOTTOM", 0, 4)
    end

    -- contenido: BOTIN (loot)
    do
        local c = W.tabs.loot
        local lbl = c:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
        lbl:SetPoint("TOPLEFT", 4, -2)
        lbl:SetText("|cffaaaaaa" .. T("Objeto (en inglés):", "Item (English):") .. "|r")

        local eb = CreateFrame("EditBox", "SKQ_XPLootSearch", c, "InputBoxTemplate")
        eb:SetSize(150, 20)
        eb:SetPoint("TOPLEFT", 10, -18)
        eb:SetAutoFocus(false)
        eb:SetScript("OnEnterPressed", function(self)
            SK:XPTrackLoot(self:GetText()); self:ClearFocus()
        end)
        eb:SetScript("OnEscapePressed", function(self) self:ClearFocus() end)
        W.lootSearch = eb

        local btnT = MakeButton(c, 78, T("Trackear", "Track"), function()
            SK:XPTrackLoot(eb:GetText()); eb:ClearFocus()
        end)
        btnT:SetPoint("LEFT", eb, "RIGHT", 10, 0)
        local btnC = MakeButton(c, 70, T("Limpiar", "Clear"), function()
            SK:XPLootClear()
        end)
        btnC:SetPoint("LEFT", btnT, "RIGHT", 4, 0)

        W.lootHdr = c:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
        W.lootHdr:SetPoint("TOPLEFT", 8, -44)
        W.lootHdr:SetPoint("TOPRIGHT", -8, -44)
        W.lootHdr:SetJustifyH("LEFT")
        W.lootHdr:SetSpacing(3)

        local colZ = c:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
        colZ:SetPoint("TOPLEFT", 6, -74)
        colZ:SetText("|cffaaaaaa" .. T("Zona", "Zone") .. "|r")
        local colC = c:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
        colC:SetPoint("TOPRIGHT", -10, -74)
        colC:SetText("|cffaaaaaa" .. T("Cantidad", "Count") .. "|r")

        local lootHost = CreateFrame("Frame", "SKQ_XPLootHost", c)
        lootHost:SetPoint("TOPLEFT", 0, -84)
        lootHost:SetPoint("BOTTOMRIGHT", 0, 4)
        W.lootScroll = NewScroll(lootHost, RefreshLoot)
    end

    -- contenido: F4 STATS (estadísticas globales persistentes)
    do
        local c = W.tabs.stats
        local title = c:CreateFontString(nil, "OVERLAY", "GameFontNormal")
        title:SetPoint("TOPLEFT", 8, -4)
        title:SetText("|cffffd100SKQ Statistics|r")
        W.statsText = c:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
        W.statsText:SetPoint("TOPLEFT", 10, -28)
        W.statsText:SetPoint("TOPRIGHT", -10, -28)
        W.statsText:SetJustifyH("LEFT")
        W.statsText:SetSpacing(5)
        W.btnStatsReset = MakeButton(c, 180, T("Reiniciar estadísticas", "Reset statistics"), function()
            StaticPopup_Show("SKQ_STATS_RESET")
        end)
        W.btnStatsReset:SetPoint("BOTTOM", 0, 4)
    end

    -- contenido: F8 TIEMPO (análisis de tiempo perdido)
    do
        local c = W.tabs.time
        local title = c:CreateFontString(nil, "OVERLAY", "GameFontNormal")
        title:SetPoint("TOPLEFT", 8, -4)
        title:SetText("|cffffd100" .. T("Análisis de tiempo", "Time analysis") .. "|r")
        W.timeText = c:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
        W.timeText:SetPoint("TOPLEFT", 10, -28)
        W.timeText:SetPoint("TOPRIGHT", -10, -28)
        W.timeText:SetJustifyH("LEFT")
        W.timeText:SetSpacing(5)
    end

    -- contenido: F6 NPCs (buscador de NPCs observados)
    do
        local c = W.tabs.npcs
        local lbl = c:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
        lbl:SetPoint("TOPLEFT", 4, -2)
        lbl:SetText("|cffaaaaaa" .. T("Nombre del NPC:", "NPC name:") .. "|r")
        local eb = CreateFrame("EditBox", "SKQ_XPNpcSearch", c, "InputBoxTemplate")
        eb:SetSize(180, 20)
        eb:SetPoint("TOPLEFT", 10, -18)
        eb:SetAutoFocus(false)
        local function doSearch() W.npcQuery = eb:GetText() or ""; SK:XPRefresh() end
        eb:SetScript("OnEnterPressed", function(self) doSearch(); self:ClearFocus() end)
        eb:SetScript("OnTextChanged", function() doSearch() end)
        eb:SetScript("OnEscapePressed", function(self) self:ClearFocus() end)
        W.npcSearch = eb
        local btnS = MakeButton(c, 78, T("Buscar", "Search"), function() doSearch(); eb:ClearFocus() end)
        btnS:SetPoint("LEFT", eb, "RIGHT", 10, 0)
        W.npcHdr = c:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
        W.npcHdr:SetPoint("TOPLEFT", 8, -44)
        W.npcHdr:SetPoint("TOPRIGHT", -8, -44)
        W.npcHdr:SetJustifyH("LEFT")
        local colN = c:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
        colN:SetPoint("TOPLEFT", 6, -62)
        colN:SetText("|cffaaaaaa" .. T("Nombre / Zona", "Name / Zone") .. "|r")
        local colC = c:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
        colC:SetPoint("TOPRIGHT", -10, -62)
        colC:SetText("|cffaaaaaa" .. T("Coords", "Coords") .. "|r")
        local host = CreateFrame("Frame", "SKQ_XPNpcHost", c)
        host:SetPoint("TOPLEFT", 0, -74)
        host:SetPoint("BOTTOMRIGHT", 0, 4)
        W.npcScroll = NewScroll(host, RefreshNPCs)
    end

    -- contenido: F9 MOBS (Mob Inspector)
    do
        local c = W.tabs.mobs
        local lbl = c:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
        lbl:SetPoint("TOPLEFT", 4, -2)
        lbl:SetText("|cffaaaaaa" .. T("Filtrar mob:", "Filter mob:") .. "|r")
        local eb = CreateFrame("EditBox", "SKQ_XPMobSearch", c, "InputBoxTemplate")
        eb:SetSize(180, 20)
        eb:SetPoint("TOPLEFT", 10, -18)
        eb:SetAutoFocus(false)
        local function doFilter() W.mobQuery = eb:GetText() or ""; SK:XPRefresh() end
        eb:SetScript("OnTextChanged", function() doFilter() end)
        eb:SetScript("OnEnterPressed", function(self) doFilter(); self:ClearFocus() end)
        eb:SetScript("OnEscapePressed", function(self) self:ClearFocus() end)
        W.mobSearch = eb
        W.mobHdr = c:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
        W.mobHdr:SetPoint("TOPLEFT", 8, -44)
        W.mobHdr:SetPoint("TOPRIGHT", -8, -44)
        W.mobHdr:SetJustifyH("LEFT")
        local colN = c:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
        colN:SetPoint("TOPLEFT", 6, -62)
        colN:SetText("|cffaaaaaa" .. T("Mob / kills", "Mob / kills") .. "|r")
        local colX = c:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
        colX:SetPoint("TOPRIGHT", -10, -62)
        colX:SetText("|cffaaaaaa" .. T("XP media", "Avg XP") .. "|r")
        local host = CreateFrame("Frame", "SKQ_XPMobHost", c)
        host:SetPoint("TOPLEFT", 0, -74)
        host:SetPoint("BOTTOMRIGHT", 0, 4)
        W.mobScroll = NewScroll(host, RefreshMobs)
    end

    StaticPopupDialogs["SKQ_XP_RESET"] = {
        text = T("¿Borrar TODO el histórico de XP (sesiones, zonas y quests)?",
                 "Erase ALL XP history (sessions, zones and quests)?"),
        button1 = YES, button2 = NO,
        OnAccept = function() SK:XPResetStats(); SK:XPRefresh() end,
        timeout = 0, whileDead = 1, hideOnEscape = 1, preferredIndex = 3,
    }

    StaticPopupDialogs["SKQ_STATS_RESET"] = {
        text = T("¿Reiniciar las estadísticas globales del personaje?",
                 "Reset the character's global statistics?"),
        button1 = YES, button2 = NO,
        OnAccept = function() if SK.StatsResetGlobal then SK:StatsResetGlobal() end; SK:XPRefresh() end,
        timeout = 0, whileDead = 1, hideOnEscape = 1, preferredIndex = 3,
    }

    SK:XPApplyTheme()
    ShowTab("session")
    SK:XPApplyMinimize()
    return f
end

function SK:XPShowWindow()
    BuildWindow()
    W.frame:Show()
end
function SK:XPHideWindow()
    if W.frame then W.frame:Hide() end
end
function SK:XPToggleWindow()
    BuildWindow()
    if W.frame:IsShown() then W.frame:Hide() else W.frame:Show() end
end

function SK:XPApplyTheme()
    local f = W.frame
    if not f then return end
    f:SetAlpha(EnsureDB().window.opacity or 0.95)
    local C = SKquests.GetThemeColors and SKquests:GetThemeColors()
    if not C then return end
    SKQ_EnsureBackdrop(f)
    f:SetBackdrop({
        bgFile   = "Interface\\ChatFrame\\ChatFrameBackground",
        edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
        tile = true, tileSize = 16, edgeSize = 16,
        insets = { left = 4, right = 4, top = 4, bottom = 4 },
    })
    local bg = C.bg or { 0.05, 0.05, 0.05 }
    local br = C.border or { 0.6, 0.5, 0.3 }
    f:SetBackdropColor(bg[1], bg[2], bg[3], 0.95)
    f:SetBackdropBorderColor(br[1], br[2], br[3], 1)
    if W.title and C.gold then
        W.title:SetTextColor(C.gold[1], C.gold[2], C.gold[3])
    end
end

function SK:XPGetOpacity()
    return EnsureDB().window.opacity or 0.95
end

function SK:XPSetOpacity(v)
    local db = EnsureDB()
    db.window.opacity = v
    if W.frame then W.frame:SetAlpha(v) end
end

function SK:XPApplyMinimize()
    if not W.frame then return end
    local db = EnsureDB()
    if db.window.min then
        if W.tabBtns then for _, b in pairs(W.tabBtns) do b:Hide() end end
        if W.tabs then for _, c in pairs(W.tabs) do c:Hide() end end
        if W.compact then for _, fs in ipairs(W.compact) do fs:Show() end end
        W.frame:SetSize(W.compactW or 236, W.compactH or 104)
        if W.minBtn and W.minBtn.txt then W.minBtn.txt:SetText("+") end
        RefreshCompact()
    else
        if W.compact then for _, fs in ipairs(W.compact) do fs:Hide() end end
        if W.tabBtns then for _, b in pairs(W.tabBtns) do b:Show() end end
        W.frame:SetSize(W.fullW or 400, W.fullH or 360)
        if W.minBtn and W.minBtn.txt then W.minBtn.txt:SetText("-") end
        ShowTab(W.curTab or "session")
    end
end

function SK:XPToggleMinimize()
    if not W.frame then return end
    local db = EnsureDB()
    db.window.min = not db.window.min
    SK:XPApplyMinimize()
end

-- ── Comando /skq xp ─────────────────────────────────────────────────────────
function SK:XPCommand(rest)
    rest = (rest or ""):lower():gsub("^%s+", ""):gsub("%s+$", "")
    if rest == "on" then
        SK:XPSetEnabled(true);  SK:Print(T("XP Appraiser activado.", "XP Appraiser enabled."))
    elseif rest == "off" then
        SK:XPSetEnabled(false); SK:Print(T("XP Appraiser desactivado.", "XP Appraiser disabled."))
    elseif rest == "pause" then
        SK:XPTogglePause()
    elseif rest == "new" then
        SK:XPNewSession(true); SK:Print(T("Nueva sesión de XP.", "New XP session."))
    elseif rest == "reset" then
        SK:XPResetStats(); SK:Print(T("Estadísticas de XP reiniciadas.", "XP stats reset."))
    else
        SK:XPToggleWindow()
    end
    SK:XPRefresh()
end

-- ── API para guias futuras (Fase 8) ─────────────────────────────────────────
function SK:GetZoneXPH(zone)
    local z = EnsureDB().Zones[zone]
    if not z or not z.time or z.time <= 0 then return 0 end
    return z.xp / z.time * 3600
end
function SK:GetQuestEfficiency(questID)
    local q = EnsureDB().Quests[questID]
    if not q then return nil end
    local avg = (q.time and q.time > 0) and (q.xp / (q.time / 60)) or q.bestXPM
    local label = ratingFor(avg)
    return avg, label
end

-- ── Eventos ─────────────────────────────────────────────────────────────────
local ev = CreateFrame("Frame")
ev:RegisterEvent("ADDON_LOADED")
ev:RegisterEvent("PLAYER_ENTERING_WORLD")
ev:RegisterEvent("PLAYER_XP_UPDATE")
ev:RegisterEvent("PLAYER_LEVEL_UP")
ev:RegisterEvent("QUEST_ACCEPTED")
ev:RegisterEvent("QUEST_COMPLETE")
ev:RegisterEvent("CHAT_MSG_COMBAT_XP_GAIN")
ev:RegisterEvent("CHAT_MSG_LOOT")
ev:RegisterEvent("ZONE_CHANGED_NEW_AREA")
ev:RegisterEvent("PLAYER_FLAGS_CHANGED")
ev:RegisterEvent("PLAYER_LOGOUT")

ev:SetScript("OnEvent", function(self, event, arg1, ...)
    if event == "ADDON_LOADED" then
        if arg1 == ADDON or arg1 == "SKquests" then
            EnsureDB()
            buildPatterns()
        end

    elseif event == "PLAYER_ENTERING_WORLD" then
        local db = EnsureDB()
        S.zone = curZone()
        if db.enabled and not S.active then SK:XPNewSession(false) end
        if db.window.shown then SK:XPShowWindow() end

    elseif event == "PLAYER_XP_UPDATE" then
        OnXPUpdate()

    elseif event == "PLAYER_LEVEL_UP" then
        OnXPUpdate()

    elseif event == "ZONE_CHANGED_NEW_AREA" then
        S.zone = curZone()
        local db = EnsureDB()
        db.Zones[S.zone] = db.Zones[S.zone] or { xp = 0, time = 0 }

    elseif event == "QUEST_ACCEPTED" then
        -- arg1 = questLogIndex, arg2 = questID (3.3.5a)
        local qid = select(1, ...)   -- arg2
        if qid and qid ~= 0 then EnsureDB().accepts[qid] = time() end

    elseif event == "QUEST_COMPLETE" then
        questPending = {
            xpBefore  = UnitXP("player") or 0,
            maxBefore = UnitXPMax("player") or 0,
            name      = (GetTitleText and GetTitleText()) or nil,
            armed     = false, t = 0,
        }

    elseif event == "CHAT_MSG_COMBAT_XP_GAIN" then
        if S.active and not S.paused then
            local amt, kind = classifyXP(arg1 or "")
            if amt and kind then S.src[kind] = (S.src[kind] or 0) + amt end
        end

    elseif event == "CHAT_MSG_LOOT" then
        onLoot(arg1)

    elseif event == "PLAYER_FLAGS_CHANGED" then
        OnFlagsChanged()

    elseif event == "PLAYER_LOGOUT" then
        SK:XPSaveSession()
    end
end)

-- En 3.3.5a no existe QUEST_TURNED_IN, así que detectamos la entrega con GetQuestReward
hooksecurefunc("GetQuestReward", function()
    if questPending then
        local target = ""
        if questPending.name then
            target = questPending.name:lower():gsub('"', ''):gsub("%s+", " "):gsub("^%s+", ""):gsub("%s+$", "")
        end
        local qid = 0
        if SKquests_DetailDB and target ~= "" then
            for id, q in pairs(SKquests_DetailDB) do
                local n = q.name and q.name:lower():gsub('"', ''):gsub("%s+", " "):gsub("^%s+", ""):gsub("%s+$", "")
                if n == target then qid = id; break end
                local nloc = q.name_loc and q.name_loc:lower():gsub('"', ''):gsub("%s+", " "):gsub("^%s+", ""):gsub("%s+$", "")
                if nloc == target then qid = id; break end
            end
        end
        questPending.qid   = qid
        questPending.armed = true
        questPending.t     = 0
    end
end)

-- OnUpdate unico: lectura diferida de XP de quest + throttle de 1s
ev.acc = 0
ev:SetScript("OnUpdate", function(self, e)
    if questPending and questPending.armed then
        questPending.t = (questPending.t or 0) + e
        if questPending.t >= 0.25 then MeasureQuestXP() end
    end
    self.acc = self.acc + e
    if self.acc >= 1 then
        local dt = self.acc
        self.acc = 0
        if S.active and not S.paused then
            local z = S.zone or curZone()
            local db = EnsureDB()
            db.Zones[z] = db.Zones[z] or { xp = 0, time = 0 }
            db.Zones[z].time = db.Zones[z].time + dt
            S.zones[z] = S.zones[z] or { xp = 0, time = 0 }
            S.zones[z].time = S.zones[z].time + dt
        end
        if W.frame and W.frame:IsShown() then SK:XPRefresh() end
    end
end)
