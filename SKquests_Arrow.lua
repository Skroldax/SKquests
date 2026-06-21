local addonName, addon = ...

-- Usaremos HereBeDragons para los clculos de distancia y ngulo
local HBD = LibStub("HereBeDragons-2.0", true)
if not HBD then 
    print("|cffff0000SKquests:|r HBD no encontrado en Arrow.lua!")
    return 
end
print("|cff00ff00SKquests:|r Modulo Arrow cargado correctamente.")

-- Estado interno
local targetMapId = nil
local targetX = nil
local targetY = nil
local targetTitle = nil

local ArrowFrame = CreateFrame("Button", nil, UIParent)
ArrowFrame:SetSize(64, 64)
ArrowFrame:SetPoint("CENTER", 0, 100)
ArrowFrame:SetMovable(true)
ArrowFrame:EnableMouse(true)
ArrowFrame:SetFrameStrata("TOOLTIP")
ArrowFrame:SetClampedToScreen(true)

-- Aadir un fondo rojo slido para depuracin
local bg = ArrowFrame:CreateTexture(nil, "BACKGROUND")
bg:SetAllPoints()
bg:SetColorTexture(1, 0, 0, 0.5)
ArrowFrame:EnableMouse(true)
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
ArrowFrame:SetScript("OnLeave", function() GameTooltip:Hide() end)
ArrowFrame:Hide()

-- Textura principal (flecha)
local arrowTex = ArrowFrame:CreateTexture(nil, "OVERLAY")
arrowTex:SetTexture("Interface\\Minimap\\MinimapArrow")
arrowTex:SetAllPoints()

-- Texto de distancia
local distText = ArrowFrame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
distText:SetPoint("TOP", ArrowFrame, "BOTTOM", 0, -5)

-- Evento de Update para rotar y calcular distancia
local lastUpdate = 0
ArrowFrame:SetScript("OnUpdate", function(self, elapsed)
    lastUpdate = lastUpdate + elapsed
    if lastUpdate < 0.05 then return end
    lastUpdate = 0
    
    if not targetMapId or not targetX or not targetY then
        -- self:Hide() -- comentado temporalmente
        return
    end

    local px, py, pInstance = HBD:GetPlayerWorldPosition()
    if not px or not py then return end
    
    -- Convertir target a coordenadas de mundo (0-1)
    local x01, y01 = targetX / 100, targetY / 100
    local tx, ty, tInstance = HBD:GetWorldCoordinatesFromZone(x01, y01, targetMapId)
    if not tx or pInstance ~= tInstance then
        distText:SetText("N/A")
        arrowTex:SetVertexColor(0.5, 0.5, 0.5)
        return
    end
    
    local dist, angle = HBD:GetWorldVector(pInstance, px, py, tx, ty)
    if not dist then return end

    -- angle de HBD: 0 es Norte, pi/2 es Oeste (Counter-Clockwise)
    -- GetPlayerFacing(): 0 es Norte, pi/2 es Oeste (Counter-Clockwise)
    local facing = GetPlayerFacing() or 0
    local bearing = angle - facing
    
    -- Interface\Minimap\MinimapArrow apunta hacia Arriba (Norte = 0 rads) por defecto en su textura sin rotar.
    arrowTex:SetRotation(bearing)
    
    -- Mostrar distancia y colorear flecha segn proximidad
    if dist < 20 then
        distText:SetText(math.floor(dist) .. " yd")
        arrowTex:SetVertexColor(0, 1, 0) -- Verde (llegando)
    elseif dist < 100 then
        distText:SetText(math.floor(dist) .. " yd")
        arrowTex:SetVertexColor(1, 1, 0) -- Amarillo
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
function SKQ_Arrow_SetWaypoint(mapId, x, y, title)
    targetMapId = mapId
    targetX = x
    targetY = y
    targetTitle = title
    ArrowFrame:ClearAllPoints()
    ArrowFrame:SetPoint("CENTER", UIParent, "CENTER", 0, 100)
    ArrowFrame:Show()
    print("|cff00ff00SKquests:|r GPS configurado hacia: " .. (title or "Destino") .. " (" .. x .. ", " .. y .. ")")
end

function SKQ_Arrow_ClearWaypoint()
    targetMapId = nil
    targetX = nil
    targetY = nil
    targetTitle = nil
    ArrowFrame:Hide()
    print("|cff00ff00SKquests:|r GPS detenido.")
end

function SKQ_Arrow_GetTarget()
    return targetMapId, targetX, targetY
end

SLASH_SKQARROW1 = "/skqarrow"
SlashCmdList["SKQARROW"] = function()
    ArrowFrame:ClearAllPoints()
    ArrowFrame:SetPoint("CENTER", UIParent, "CENTER", 0, 0)
    ArrowFrame:SetSize(100, 100)
    ArrowFrame:SetFrameLevel(99)
    ArrowFrame:Show()
    print("SKquests: Flecha forzada a mostrarse en el centro.")
end
