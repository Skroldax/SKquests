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
local isScanning = false

function T:Refresh()
    if isScanning then return end
    isScanning = true

    self._cache   = {}
    self._byTitle = {}

    -- Guardar estado de headers colapsados y expandirlos
    local collapsedHeaders = {}
    local numEntries = GetNumQuestLogEntries()
    for i = numEntries, 1, -1 do
        local _, _, _, _, isHeader, isCollapsed = GetQuestLogTitle(i)
        if isHeader and isCollapsed then
            table.insert(collapsedHeaders, i)
            ExpandQuestHeader(i)
        end
    end

    -- Escanear todo (ahora esta totalmente expandido)
    numEntries = GetNumQuestLogEntries()
    local currentHeader = "Unknown"
    for i = 1, numEntries do
        local title, level, _, _, isHeader, _, isComplete, _, questID = GetQuestLogTitle(i)
        if title then
            if not isHeader and not questID then
                local link = GetQuestLink and GetQuestLink(i)
                if link then questID = tonumber(link:match("quest:(%d+)")) end
            end
            if isHeader then
                currentHeader = title
            else
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
                    id         = questID,
                    category   = currentHeader,
                }
                self._cache[i]              = entry
                self._byTitle[title:lower()] = i
            end
        end
    end

    -- Restaurar el estado de los headers (de abajo hacia arriba para mantener indices)
    for _, headerIndex in ipairs(collapsedHeaders) do
        CollapseQuestHeader(headerIndex)
    end

    isScanning = false

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
    local lo = name:lower():gsub("^%s+", ""):gsub("%s+$", "")
    if lo == "" then return nil end
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

-- Varios de estos eventos suelen dispararse en rafaga (2-4 veces) por una
-- sola accion del jugador: aceptar/entregar una quest dispara QUEST_LOG_UPDATE
-- y UNIT_QUEST_LOG_CHANGED casi al mismo tiempo. Cada Refresh() es O(n) sobre
-- el quest log completo e incluye expandir y volver a colapsar TODOS los
-- headers, asi que sin agrupar esas rafagas se repetia ese trabajo varias
-- veces de forma redundante. Se agrupan en un unico Refresh() en el siguiente
-- frame (latencia imperceptible, ~1 frame).
local refreshPending = false
local function RequestRefresh()
    if refreshPending then return end
    refreshPending = true
    trackerFrame:SetScript("OnUpdate", function(self)
        self:SetScript("OnUpdate", nil)
        refreshPending = false
        addon.Tracker:Refresh()
    end)
end

trackerFrame:SetScript("OnEvent", function(_, event, arg1)
    -- UNIT_QUEST_LOG_CHANGED solo nos interesa para el jugador
    if event == "UNIT_QUEST_LOG_CHANGED" and arg1 ~= "player" then return end
    RequestRefresh()
end)
