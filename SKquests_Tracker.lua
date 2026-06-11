-- File: SKquests_Tracker.lua
-- Modulo de tracking en tiempo real de quests del quest log del jugador.
-- Escanea los eventos del WoW API y expone datos limpios a la UI.

local addon = SKquests

addon.Tracker = {}
local T = addon.Tracker

-- Cache interno: { [logIndex] = { title, level, isComplete, objectives={} } }
T._cache    = {}
T._byTitle  = {}   -- titulo en minusculas -> logIndex
T.OnUpdate  = nil  -- callback(T) que la UI puede suscribir

-- ============================================================
--  REFRESH: re-escanea el quest log completo
-- ============================================================
function T:Refresh()
    self._cache   = {}
    self._byTitle = {}

    local numEntries = GetNumQuestLogEntries()
    for i = 1, numEntries do
        local title, level, _, _, isHeader, _, isComplete = GetQuestLogTitle(i)
        if title and not isHeader then
            local objectives = {}
            local numObj = GetNumQuestLeaderBoards(i)
            for o = 1, numObj do
                local text, _, finished = GetQuestLogLeaderBoard(o, i)
                if text then
                    -- Extrae numeros de progreso "X/Y" del texto
                    local done, total = text:match("(%d+)/(%d+)")
                    table.insert(objectives, {
                        text     = text,
                        done     = finished,
                        numDone  = tonumber(done)  or 0,
                        numTotal = tonumber(total) or 0,
                    })
                end
            end

            local entry = {
                logIndex   = i,
                title      = title,
                level      = level or 0,
                isComplete = (isComplete == 1 or isComplete == true),
                objectives = objectives,
            }
            self._cache[i]              = entry
            self._byTitle[title:lower()] = i
        end
    end

    -- Notifica a la UI si hay un callback registrado
    if self.OnUpdate then
        pcall(self.OnUpdate, self)
    end
end

-- ============================================================
--  API PUBLICA
-- ============================================================

-- Devuelve la tabla de quests activas: { logIndex -> entry }
function T:GetActiveQuests()
    return self._cache
end

-- Busca una quest por titulo exacto o parcial. Devuelve logIndex o nil.
function T:FindByTitle(name)
    if not name then return nil end
    local lo = name:lower()
    -- Busqueda exacta primero
    if self._byTitle[lo] then return self._byTitle[lo] end
    -- Busqueda parcial
    for key, idx in pairs(self._byTitle) do
        if key:find(lo, 1, true) then return idx end
    end
    return nil
end

-- Devuelve los objetivos de una entrada del log. Devuelve {} si no existe.
function T:GetObjectivesFor(logIndex)
    local entry = self._cache[logIndex]
    return entry and entry.objectives or {}
end

-- Devuelve true + logIndex si la quest esta activa, false + nil si no.
function T:IsActive(name)
    local idx = self:FindByTitle(name)
    return idx ~= nil, idx
end

-- Devuelve true si la quest esta completada en el log.
function T:IsComplete(logIndex)
    local entry = self._cache[logIndex]
    return entry and entry.isComplete or false
end

-- ============================================================
--  FRAME DE EVENTOS
-- ============================================================
local trackerFrame = CreateFrame("Frame")
trackerFrame:RegisterEvent("QUEST_LOG_UPDATE")
trackerFrame:RegisterEvent("UNIT_QUEST_LOG_CHANGED")
trackerFrame:RegisterEvent("QUEST_WATCH_UPDATE")
trackerFrame:RegisterEvent("PLAYER_ENTERING_WORLD")

trackerFrame:SetScript("OnEvent", function(_, event, arg1)
    -- UNIT_QUEST_LOG_CHANGED solo nos interesa para el jugador
    if event == "UNIT_QUEST_LOG_CHANGED" and arg1 ~= "player" then return end
    addon.Tracker:Refresh()
end)
