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
-- SKquests - Temas adicionales (ElvUI Dark / Minimal Dark)
-- Disponibles para todos los usuarios. El editor de temas
-- (SKquests_ThemeEditor.lua) requiere contraseña de administrador.
-- ====================================================================

local addon = SKquests
addon.Themes = addon.Themes or {}

-- Contraseña del editor de temas (cámbiala aquí)
SKQUESTS_ADMIN_PASSWORD = "SKadmin"

local Textures = {
    Solid = "Interface\\Buttons\\WHITE8X8",
}

addon.Themes.ElvUIDark = {
    name = "ElvUI Dark",
    key = "elvuidark",
    isEditable = true,
    textures = { bg = Textures.Solid, border = Textures.Solid },
    colors = {
        bgPanel    = {0.08, 0.08, 0.08, 0.95},
        bgHover    = {0.15, 0.15, 0.15, 1.0},
        border     = {0.0, 0.0, 0.0, 1.0},
        textNormal = {0.90, 0.90, 0.90},
        textTitle  = {0.18, 0.52, 0.84}, -- azul ElvUI
        accent     = {0.18, 0.52, 0.84},
    },
    metrics = { borderSize = 32, padding = 8 },
}

addon.Themes.MinimalDark = {
    name = "Minimal Dark",
    key = "minimaldark",
    isEditable = true,
    textures = { bg = Textures.Solid, border = Textures.Solid },
    colors = {
        bgPanel    = {0.11, 0.11, 0.11, 1.0},
        bgHover    = {0.16, 0.17, 0.18, 1.0},
        border     = {0.0, 0.0, 0.0, 0.0},
        textNormal = {0.80, 0.80, 0.80},
        textTitle  = {0.44, 0.53, 0.85}, -- blurple
        accent     = {0.44, 0.53, 0.85},
    },
    metrics = { borderSize = 0, padding = 6 },
}

addon.Themes.BlizzardClassic = {
    name = "Blizzard Classic",
    key = "blizzardclassic",
    isEditable = true,
    textures = { bg = "Interface\\AddOns\\SKquests\\Media\\blizzard_bg.tga", border = "Interface\\AddOns\\SKquests\\Media\\blizzardclassic_border.blp" },
    colors = {
        bgPanel    = {0.95, 0.92, 0.84},
        bgSide     = {0.90, 0.86, 0.76},
        bgList     = {0.88, 0.83, 0.72},
        bgDetail   = {0.93, 0.89, 0.80},
        bgSelected = {0.78, 0.70, 0.52},
        bgHover    = {0.84, 0.78, 0.64},
        border     = {0.50, 0.43, 0.28},
        borderDim  = {0.62, 0.55, 0.40},
        gold       = {0.35, 0.22, 0.05},
        white      = {0.18, 0.14, 0.06},
        dim        = {0.40, 0.35, 0.25},
        sectionLbl = {0.48, 0.40, 0.28},
        -- Fallbacks para el editor
        textNormal = {0.18, 0.14, 0.06},
        textTitle  = {0.35, 0.22, 0.05},
        accent     = {0.35, 0.22, 0.05},
    },
    metrics = { borderSize = 32, padding = 8 },
}

addon.Themes.Dragonflight = {
    name = "Dragonflight",
    key = "dragonflight",
    isEditable = true,
    textures = { bg = "Interface\\AddOns\\SKquests\\Media\\dragonflight_bg.tga", border = "Interface\\AddOns\\SKquests\\Media\\dragonflight_border.blp" },
    colors = {
        bgPanel    = {0.20, 0.05, 0.05, 0.95},
        bgHover    = {0.30, 0.10, 0.10, 0.8},
        border     = {0.60, 0.50, 0.20, 1.0},
        textNormal = {0.85, 0.85, 0.85},
        textTitle  = {0.95, 0.80, 0.30},
        accent     = {0.95, 0.80, 0.30},
    },
    metrics = { borderSize = 32, padding = 8 },
}

addon.Themes.WrathClassic = {
    name = "Wrath Classic",
    key = "wrathclassic",
    isEditable = true,
    textures = { bg = "Interface\\AddOns\\SKquests\\Media\\wrath_bg.tga", border = "Interface\\AddOns\\SKquests\\Media\\wrathclassic_border.blp" },
    colors = {
        bgPanel    = {0.05, 0.10, 0.15, 0.95},
        bgHover    = {0.10, 0.20, 0.30, 0.6},
        border     = {0.30, 0.40, 0.50, 1.0},
        textNormal = {0.85, 0.90, 0.95},
        textTitle  = {0.60, 0.80, 1.0},
        accent     = {0.40, 0.70, 0.95},
    },
    metrics = { borderSize = 32, padding = 8 },
}

addon.Themes.Modern = {
    name = "Modern",
    key = "modern",
    isEditable = true,
    textures = { bg = "Interface\\AddOns\\SKquests\\Media\\modern_bg.tga", border = "Interface\\AddOns\\SKquests\\Media\\modern_border.blp" },
    colors = {
        bgPanel    = {0.04, 0.08, 0.15, 0.95},
        bgHover    = {0.08, 0.16, 0.30, 0.8},
        border     = {0.10, 0.20, 0.35, 1.0},
        textNormal = {0.80, 0.85, 0.90},
        textTitle  = {0.40, 0.60, 0.95},
        accent     = {0.20, 0.50, 0.90},
    },
    metrics = { borderSize = 32, padding = 8 },
}

addon.Themes.WarcraftLogs = {
    name = "Warcraft Logs",
    key = "warcraftlogs",
    isEditable = true,
    textures = { bg = "Interface\\AddOns\\SKquests\\Media\\warcraftlogs_bg.tga", border = "Interface\\AddOns\\SKquests\\Media\\warcraftlogs_border.blp" },
    colors = {
        bgPanel    = {0.07, 0.07, 0.07, 0.98},
        bgHover    = {0.12, 0.12, 0.12, 1.0},
        border     = {0.15, 0.15, 0.15, 1.0},
        textNormal = {0.75, 0.75, 0.80},
        textTitle  = {0.80, 0.40, 0.10},
        accent     = {0.80, 0.40, 0.10},
    },
    metrics = { borderSize = 32, padding = 8 },
}

addon.Themes.AscensionWoW = {
    name = "Ascension WoW",
    key = "ascensionwow",
    isEditable = true,
    textures = { bg = "Interface\\AddOns\\SKquests\\Media\\ascension_bg.tga", border = "Interface\\AddOns\\SKquests\\Media\\ascensionwow_border.blp" },
    colors = {
        bgPanel    = {0.18, 0.14, 0.08, 0.98},
        bgHover    = {0.28, 0.22, 0.14, 0.80},
        border     = {0.40, 0.32, 0.20, 1.0},
        textNormal = {0.90, 0.84, 0.74},
        textTitle  = {0.82, 0.62, 0.23},
        accent     = {0.82, 0.62, 0.23},
    },
    metrics = { borderSize = 32, padding = 8 },
}

-- índice por clave de config
addon.ThemesByKey = {
    elvuidark       = addon.Themes.ElvUIDark,
    minimaldark     = addon.Themes.MinimalDark,
    blizzardclassic = addon.Themes.BlizzardClassic,
    dragonflight    = addon.Themes.Dragonflight,
    wrathclassic    = addon.Themes.WrathClassic,
    modern          = addon.Themes.Modern,
    warcraftlogs    = addon.Themes.WarcraftLogs,
    ascensionwow    = addon.Themes.AscensionWoW,
}

-- Orden de temas extra para el desplegable
addon.ThemeOrder = { "elvuidark", "minimaldark", "blizzardclassic", "dragonflight", "wrathclassic", "modern", "warcraftlogs", "ascensionwow" }

-- Fallback del sistema Pro (build público sin SKquests_ProCodes.lua):
-- bloqueado por defecto. SKquests_ProCodes.lua (privado) se carga DESPUÉS
-- y sobreescribe estas funciones con la validación real de códigos.
function addon:IsProUnlocked() return SKquestsDB and SKquestsDB.proUnlocked == true end
function addon:TryUnlockPro() return false end
function addon:RequestProCode() end

-- ====================================================================
-- Adaptador: convierte un tema nuevo a la paleta C que usa la UI.
-- Respeta los colores personalizados guardados por el editor
-- (SKquestsDB.config.themeOverrides[clave]).
-- ====================================================================
local function mul(col, f)
    return { math.min(col[1] * f, 1), math.min(col[2] * f, 1), math.min(col[3] * f, 1) }
end

function addon:GetCustomPalette(themeKey)
    local t = addon.ThemesByKey and addon.ThemesByKey[themeKey]
    if not t then return nil end

    -- copiar colores base y aplicar overrides del editor
    local c = {}
    for k, v in pairs(t.colors) do c[k] = v end
    local ov = SKquestsDB and SKquestsDB.config and SKquestsDB.config.themeOverrides
    ov = ov and ov[themeKey]
    
    -- Reset old dark overrides for Blizzard Classic if they exist
    if themeKey == "blizzardclassic" and ov and ov.bgPanel and ov.bgPanel[1] < 0.5 then
        SKquestsDB.config.themeOverrides.blizzardclassic = nil
        ov = nil
        -- Re-copy base colors
        c = {}
        for k, v in pairs(t.colors) do c[k] = v end
    end
    
    if ov then
        for k, v in pairs(ov) do c[k] = v end
    end

    local bgVal = c.bg or { c.bgPanel[1], c.bgPanel[2], c.bgPanel[3] }
    local bgSideVal = c.bgSide or mul(c.bgPanel, 1.18)
    local bgListVal = c.bgList or mul(c.bgPanel, 1.10)
    local bgDetailVal = c.bgDetail or mul(c.bgPanel, 1.25)
    local bgSelectedVal = c.bgSelected or { c.accent[1] * 0.45, c.accent[2] * 0.45, c.accent[3] * 0.45 }
    local bgHoverVal = c.bgHover or { c.bgHover[1], c.bgHover[2], c.bgHover[3] }
    local borderVal = c.border or { c.border[1], c.border[2], c.border[3] }
    local borderDimVal = c.borderDim or mul(c.border, 0.75)
    local goldVal = c.gold or { c.textTitle[1], c.textTitle[2], c.textTitle[3] }
    local whiteVal = c.white or { c.textNormal[1], c.textNormal[2], c.textNormal[3] }
    local dimVal = c.dim or mul(c.textNormal, 0.75)
    local sectionLblVal = c.sectionLbl or mul(c.textNormal, 0.85)
    local greenVal = c.green or { 0.2, 0.85, 0.2 }
    local objDoneVal = c.objDone or { c.accent[1], c.accent[2], c.accent[3] }
    local objPendingVal = c.objPending or { c.textNormal[1], c.textNormal[2], c.textNormal[3] }
    local wowBlueVal = c.wowBlue or { c.accent[1], c.accent[2], c.accent[3] }

    return {
        bg         = bgVal,
        bgSide     = bgSideVal,
        bgList     = bgListVal,
        bgDetail   = bgDetailVal,
        bgSelected = bgSelectedVal,
        bgHover    = bgHoverVal,
        border     = borderVal,
        borderDim  = borderDimVal,
        gold       = goldVal,
        white      = whiteVal,
        dim        = dimVal,
        sectionLbl = sectionLblVal,
        green      = greenVal,
        objDone    = objDoneVal,
        objPending = objPendingVal,
        wowBlue    = wowBlueVal,
        
        textures   = t.textures,
        metrics    = t.metrics
    }
end


