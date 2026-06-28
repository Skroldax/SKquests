-- SKquests_Risk.lua
-- Sistema automatico de puntuacion de riesgo Hardcore para WotLK Classic 3.3.5a.
-- Calcula un riesgo por mision combinando: diferencia de nivel, objetivos elite,
-- areas peligrosas (cuevas/zonas confinadas), cantidad de enemigos a matar y el
-- historial real de muertes del jugador en esa mision.
--
-- Clasificacion final:  SAFE / CAUTION / DANGEROUS / EXTREME
-- (En WoW 3.3.5a los emoji a color no se renderizan, asi que la UI usa un punto
--  "●" coloreado con codigo |cffRRGGBB en lugar de 🟢🟡🟠🔴).

SKquests = SKquests or {}

-- ── Base de datos de areas peligrosas ──────────────────────────────────────────
-- Cuevas, minas y zonas confinadas donde es facil quedar rodeado / sin escape.
-- Ampliable libremente: la clave es el nombre exacto (enUS o esES) de la zona,
-- subzona o area; tambien se busca como subcadena dentro del texto de objetivos.
SKQ_DangerAreas = SKQ_DangerAreas or {
    -- Eastern Kingdoms (Alianza inicio)
    ["Echo Ridge Mine"]     = true,
    ["Fargodeep Mine"]      = true,
    ["Jasperlode Mine"]     = true,
    ["The Stonefield Farm"] = true,
    ["The Maclure Vineyards"] = true,
    ["Jangolode Mine"]      = true,
    ["Gold Coast Quarry"]   = true,
    ["The Stockade"]        = true,
    ["The Deadmines"]       = true,
    ["Wendigo Lair"]        = true,
    -- Dun Morogh (Enano/Gnomo)
    ["Coldridge Valley"]    = true,
    ["Frostmane Hold"]      = true,
    ["Gnomeregan"]          = true,
    -- Tirisfal / Silverpine (No-muerto)
    ["Scarlet Monastery"]   = true,
    ["Brightwater Lake"]    = true,
    ["The Sepulcher"]       = true,
    -- Kalimdor (Tauren/Orco/Trol/Elfo de la noche)
    ["Ban'ethil Barrow Den"] = true,
    ["Wailing Caverns"]     = true,
    ["The Barrens"]         = false, -- zona abierta, no confinada (referencia)
    ["Palemane Rock"]       = true,
    ["The Venture Co. Mine"] = true,
    ["Skull Rock"]          = true,
    ["Kolkar Crag"]         = true,
    -- esES (nombres localizados frecuentes)
    ["Mina Cresta del Eco"] = true,
    ["Mina Vadoprofundo"]   = true,
    ["Mina Jaspeada"]       = true,
    ["Mina Jangolode"]      = true,
    ["La Mazmorra"]         = true,
    ["Las Minas de la Muerte"] = true,
    ["Cubil de Ban'ethil"]  = true,
    ["Cavernas de los Lamentos"] = true,
    ["Monasterio Escarlata"] = true,
}

-- ── Niveles de riesgo y colores (hex, sin '#') ─────────────────────────────────
local RISK_LEVELS = {
    { max = 25,       label = "SAFE",      color = "33ff33" }, -- verde
    { max = 50,       label = "CAUTION",   color = "ffff33" }, -- amarillo
    { max = 75,       label = "DANGEROUS", color = "ff9933" }, -- naranja
    { max = math.huge, label = "EXTREME",  color = "ff3333" }, -- rojo
}

local function ClassifyRisk(score)
    for _, lvl in ipairs(RISK_LEVELS) do
        if score <= lvl.max then
            return lvl.label, lvl.color
        end
    end
    return "EXTREME", "ff3333"
end

local function IsES()
    return SKquests_Localization and SKquests_Localization.currentLanguage == "esES"
end

-- ── Calculo principal de riesgo ────────────────────────────────────────────────
-- q        : entrada de SKquests_DetailDB
-- zoneName : nombre de zona ya resuelto por la UI (opcional)
-- Devuelve : score (number), label (string), color (hex), reasons (lista {t=,p=})
function SKquests:GetQuestRisk(q, zoneName)
    if not q then return 0, "SAFE", "33ff33", {} end

    local es = IsES()
    local reasons = {}
    local score = 0

    -- Texto de objetivos: combina DB + datos recolectados en vivo (Collector)
    local cq = SKquests.Collector and SKquests.Collector.GetQuestData
               and SKquests.Collector:GetQuestData(q.id)
    local text = (((q.logDesc or "") .. " " .. (q.objectives or "") .. " "
                 .. ((cq and cq.logDesc) or "")) or ""):lower()

    -- 1) Diferencia de nivel: (nivelQuest - nivelJugador) * 10  (solo si es positiva)
    local pLvl = (UnitLevel and UnitLevel("player")) or 1
    local qLvl = tonumber(q.level) or 0
    if qLvl > 0 and qLvl > pLvl then
        local pts = (qLvl - pLvl) * 10
        score = score + pts
        table.insert(reasons, { t = ("+%d  "):format(pts) ..
            (es and ("Mision sobre tu nivel (%d vs %d)"):format(qLvl, pLvl)
                or  ("Quest above your level (%d vs %d)"):format(qLvl, pLvl)), p = pts })
    end

    -- 2) Objetivos elite (best-effort): flag de DB o la palabra "elite" en el texto
    local elite = q.elite or q.isElite
    if not elite and text:find("elite", 1, true) then elite = true end
    if elite then
        score = score + 50
        table.insert(reasons, { t = "+50  " ..
            (es and "Objetivo Elite" or "Elite objective"), p = 50 })
    end

    -- 3) Cueva / zona confinada (+30)
    local inDanger = false
    if zoneName and SKQ_DangerAreas[zoneName] then inDanger = true end
    if not inDanger and q.area and SKQ_DangerAreas[q.area] then inDanger = true end
    if not inDanger and q.subZone and SKQ_DangerAreas[q.subZone] then inDanger = true end
    if not inDanger and text ~= "" and text ~= "  " then
        for danger, isDanger in pairs(SKQ_DangerAreas) do
            if isDanger and text:find(danger:lower(), 1, true) then
                inDanger = true
                break
            end
        end
    end
    if inDanger then
        score = score + 30
        table.insert(reasons, { t = "+30  " ..
            (es and "Cueva / area confinada" or "Cave / confined area"), p = 30 })
    end

    -- 4) Cantidad de enemigos a matar: 10→+10, 20→+20, 30+→+30
    -- Se parsea el numero objetivo del texto: formato "0/20" o verbos mata/slay/kill.
    local maxKill = 0
    for _, need in text:gmatch("(%d+)%s*/%s*(%d+)") do
        local n = tonumber(need)
        if n and n > maxKill and n <= 250 then maxKill = n end
    end
    if maxKill == 0 then
        for _, verb in ipairs({ "mata", "matar", "slay", "kill", "destruye", "destroy", "elimina" }) do
            for n in text:gmatch(verb .. "%D-(%d+)") do
                local num = tonumber(n)
                if num and num > maxKill and num <= 250 then maxKill = num end
            end
        end
    end
    local killPts = 0
    if     maxKill >= 30 then killPts = 30
    elseif maxKill >= 20 then killPts = 20
    elseif maxKill >= 10 then killPts = 10 end
    if killPts > 0 then
        score = score + killPts
        table.insert(reasons, { t = ("+%d  "):format(killPts) ..
            (es and ("Matar %d enemigos"):format(maxKill)
                or  ("Kill %d enemies"):format(maxKill)), p = killPts })
    end

    -- 5) Historial real de muertes en esta mision: muertes * 2
    local deaths = (SKquestsDB and SKquestsDB.deathStats and q.id
                    and SKquestsDB.deathStats[q.id]) or 0
    if deaths > 0 then
        local pts = deaths * 2
        score = score + pts
        table.insert(reasons, { t = ("+%d  "):format(pts) ..
            (es and ("Historial de muertes (%d)"):format(deaths)
                or  ("Death history (%d)"):format(deaths)), p = pts })
    end

    local label, color = ClassifyRisk(score)
    return score, label, color, reasons
end

-- ── Icono de riesgo (textura en linea) ─────────────────────────────────────────
-- En 3.3.5a los emoji a color no se renderizan y un punto "●" coloreado se veia
-- pobre. Usamos texturas nativas del cliente, nitidas a cualquier tamano:
-- indicadores de color redondos para SAFE/CAUTION/DANGEROUS y una calavera para
-- EXTREME. Devuelve una cadena con escape |T...|t lista para SetText.
-- Nota: las texturas Interface\COMMON\Indicator-* NO existen en el cliente
-- 3.3.5a, por eso no se renderizaban. Usamos texturas garantizadas en 3.3.5a
-- (el set ReadyCheck y la calavera del TargetingFrame), que se ven nitidas en
-- linea: check verde (SAFE), reloj amarillo (CAUTION), X roja (DANGEROUS) y
-- calavera (EXTREME).
local RISK_ICON = {
    SAFE      = "Interface\\RAIDFRAME\\ReadyCheck-Ready",
    CAUTION   = "Interface\\RAIDFRAME\\ReadyCheck-Waiting",
    DANGEROUS = "Interface\\RAIDFRAME\\ReadyCheck-NotReady",
    EXTREME   = "Interface\\TargetingFrame\\UI-TargetingFrame-Skull",
}

function SKquests:GetRiskIcon(label, size)
    size = size or 14
    local tex = RISK_ICON[label] or RISK_ICON.SAFE
    return "|T" .. tex .. ":" .. size .. ":" .. size .. "|t"
end

-- ── Seguimiento de muertes (PLAYER_DEAD) ───────────────────────────────────────
-- Cada muerte incrementa el contador de TODAS las misiones activas en el log,
-- alimentando el factor 5 del riesgo y la tabla de muertes para exportacion.
local riskFrame = CreateFrame("Frame", "SKquestsRiskFrame")
riskFrame:RegisterEvent("PLAYER_DEAD")
riskFrame:SetScript("OnEvent", function(_, event)
    if event ~= "PLAYER_DEAD" then return end

    SKquestsDB = SKquestsDB or {}
    SKquestsDB.deathStats = SKquestsDB.deathStats or {}
    SKquestsDB.deathLog   = SKquestsDB.deathLog   or {}

    local lvl  = (UnitLevel and UnitLevel("player")) or 0
    local zone = (GetRealZoneText and GetRealZoneText()) or (GetZoneText and GetZoneText()) or "?"
    local sub  = (GetSubZoneText and GetSubZoneText()) or ""

    local active = {}
    local n = (GetNumQuestLogEntries and GetNumQuestLogEntries()) or 0
    for i = 1, n do
        -- 3.3.5a (ChromieCraft) devuelve questID en la 9a posicion
        local title, _, _, _, isHeader, _, _, _, questId = GetQuestLogTitle(i)
        if not isHeader and questId and questId > 0 then
            SKquestsDB.deathStats[questId] = (SKquestsDB.deathStats[questId] or 0) + 1
            table.insert(active, questId)
            -- Reflejar tambien en la estructura exportable
            if SKQ_CollectedData then
                SKQ_CollectedData.deaths = SKQ_CollectedData.deaths or {}
                SKQ_CollectedData.deaths[questId] = (SKQ_CollectedData.deaths[questId] or 0) + 1
            end
        end
    end

    table.insert(SKquestsDB.deathLog, {
        level   = lvl,
        zone    = zone,
        subZone = sub,
        quests  = active,
        time    = (time and time()) or 0,
    })
end)
