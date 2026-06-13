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
    textures = { bg = "Interface\\AddOns\\SKquests\\Media\\blizzard_bg.tga", border = "Interface\\AddOns\\SKquests\\Media\\blizzardclassic_border.tga" },
    colors = {
        bgPanel    = {0.12, 0.08, 0.04, 0.98},
        bgHover    = {0.20, 0.14, 0.08, 0.5},
        border     = {0.40, 0.30, 0.15, 1.0},
        textNormal = {0.80, 0.70, 0.50},
        textTitle  = {0.90, 0.75, 0.30},
        accent     = {0.90, 0.75, 0.30},
    },
    metrics = { borderSize = 32, padding = 8 },
}

addon.Themes.Dragonflight = {
    name = "Dragonflight",
    key = "dragonflight",
    isEditable = true,
    textures = { bg = "Interface\\AddOns\\SKquests\\Media\\dragonflight_bg.tga", border = "Interface\\AddOns\\SKquests\\Media\\dragonflight_border.tga" },
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
    textures = { bg = "Interface\\AddOns\\SKquests\\Media\\wrath_bg.tga", border = "Interface\\AddOns\\SKquests\\Media\\wrathclassic_border.tga" },
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
    textures = { bg = "Interface\\AddOns\\SKquests\\Media\\modern_bg.tga", border = "Interface\\AddOns\\SKquests\\Media\\modern_border.tga" },
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
    textures = { bg = "Interface\\AddOns\\SKquests\\Media\\warcraftlogs_bg.tga", border = "Interface\\AddOns\\SKquests\\Media\\warcraftlogs_border.tga" },
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
    textures = { bg = "Interface\\AddOns\\SKquests\\Media\\ascension_bg.tga", border = "Interface\\AddOns\\SKquests\\Media\\ascensionwow_border.tga" },
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
    if ov then
        for k, v in pairs(ov) do c[k] = v end
    end

    return {
        bg         = { c.bgPanel[1], c.bgPanel[2], c.bgPanel[3] },
        bgSide     = mul(c.bgPanel, 1.18),
        bgList     = mul(c.bgPanel, 1.10),
        bgDetail   = mul(c.bgPanel, 1.25),
        bgSelected = { c.accent[1] * 0.45, c.accent[2] * 0.45, c.accent[3] * 0.45 },
        bgHover    = { c.bgHover[1], c.bgHover[2], c.bgHover[3] },
        border     = { c.border[1], c.border[2], c.border[3] },
        borderDim  = mul(c.border, 0.75),
        gold       = { c.textTitle[1], c.textTitle[2], c.textTitle[3] },
        white      = { c.textNormal[1], c.textNormal[2], c.textNormal[3] },
        dim        = mul(c.textNormal, 0.75),
        sectionLbl = mul(c.textNormal, 0.85),
        green      = { 0.2, 0.85, 0.2 },
        objDone    = { c.accent[1], c.accent[2], c.accent[3] },
        objPending = { c.textNormal[1], c.textNormal[2], c.textNormal[3] },
        wowBlue    = { c.accent[1], c.accent[2], c.accent[3] },
        
        textures   = t.textures,
        metrics    = t.metrics
    }
end

