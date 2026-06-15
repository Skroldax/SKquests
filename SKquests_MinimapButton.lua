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

-- ====================================================================
-- SKquests - Botón del minimapa (burbuja con el logo)
-- Clic izquierdo: abrir/cerrar SKquests. Arrastrar: mover alrededor
-- del minimapa. La posición se guarda en SKquestsDB.config.minimapPos.
-- ====================================================================

local addon = SKquests

local btn = CreateFrame("Button", "SKquestsMinimapButton", Minimap)
btn:SetSize(32, 32)
btn:SetFrameStrata("MEDIUM")
btn:SetFrameLevel(8)
btn:RegisterForClicks("LeftButtonUp")
btn:RegisterForDrag("LeftButton")
btn:SetMovable(true)

-- icono (logo) recortado en círculo
local icon = btn:CreateTexture(nil, "BACKGROUND")
icon:SetSize(20, 20)
icon:SetPoint("CENTER", 0, 1)
icon:SetTexture("Interface\\AddOns\\SKquests\\Media\\Logo.tga")
icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
btn.icon = icon

-- anillo dorado estándar de botón de minimapa
local border = btn:CreateTexture(nil, "OVERLAY")
border:SetSize(54, 54)
border:SetPoint("TOPLEFT")
border:SetTexture("Interface\\Minimap\\MiniMap-TrackingBorder")

btn:SetHighlightTexture("Interface\\Minimap\\UI-Minimap-ZoomButton-Highlight")

-- ---- posicionamiento alrededor del minimapa ----
local function GetPos()
    return (SKquestsDB and SKquestsDB.config and SKquestsDB.config.minimapPos) or 220
end

local function SetPos(angle)
    if SKquestsDB and SKquestsDB.config then
        SKquestsDB.config.minimapPos = angle
    end
    local rad = math.rad(angle)
    btn:ClearAllPoints()
    btn:SetPoint("CENTER", Minimap, "CENTER", math.cos(rad) * 80, math.sin(rad) * 80)
end

local function OnDragUpdate()
    local mx, my = Minimap:GetCenter()
    local cx, cy = GetCursorPosition()
    local scale = Minimap:GetEffectiveScale()
    cx, cy = cx / scale, cy / scale
    SetPos(math.deg(math.atan2(cy - my, cx - mx)))
end

btn:SetScript("OnDragStart", function(self)
    self:SetScript("OnUpdate", OnDragUpdate)
end)
btn:SetScript("OnDragStop", function(self)
    self:SetScript("OnUpdate", nil)
end)

btn:SetScript("OnClick", function()
    if addon and addon.ToggleFrame then addon:ToggleFrame() end
end)

btn:SetScript("OnEnter", function(self)
    GameTooltip:SetOwner(self, "ANCHOR_LEFT")
    GameTooltip:SetText("SKquests", 0.9, 0.75, 0.3)
    GameTooltip:AddLine("Clic: abrir/cerrar la ventana", 1, 1, 1)
    GameTooltip:AddLine("Arrastrar: mover el botón", 0.8, 0.8, 0.8)
    GameTooltip:Show()
end)
btn:SetScript("OnLeave", function() GameTooltip:Hide() end)

-- aplicar posición guardada cuando las SavedVariables ya existen
local posFrame = CreateFrame("Frame")
posFrame:RegisterEvent("PLAYER_LOGIN")
posFrame:SetScript("OnEvent", function()
    SetPos(GetPos())
end)
SetPos(220)
