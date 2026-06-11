-- ====================================================================
-- SKquests - Temas (2 libres + 5 Modo Pro)
-- Libres: ElvUI Dark, Minimal Dark (más Oscuro/Claro clásicos).
-- Modo Pro (código requerido): Blizzard Classic, Dragonflight,
-- Wrath Classic, RUF Modern, Warcraft Logs + Editor de temas.
-- Los códigos viven en SKquests_ProCodes.lua (NO se sube a GitHub).
-- ====================================================================

local addon = SKquests
addon.Themes = addon.Themes or {}

local Solid = "Interface\\Buttons\\WHITE8X8"
local BorderClassic = "Interface\\Tooltips\\UI-Tooltip-Border"

-- ============================ TEMAS =================================
addon.Themes.ElvUIDark = {
    name = "ElvUI Dark", key = "elvuidark", isPro = false, isEditable = true,
    colors = {
        bgPanel = {0.08, 0.08, 0.08, 0.95}, bgHover = {0.15, 0.15, 0.15, 1.0},
        border = {0.0, 0.0, 0.0, 1.0}, textNormal = {0.90, 0.90, 0.90},
        textTitle = {0.18, 0.52, 0.84}, accent = {0.18, 0.52, 0.84},
    },
}

addon.Themes.MinimalDark = {
    name = "Minimal Dark", key = "minimaldark", isPro = false, isEditable = true,
    colors = {
        bgPanel = {0.11, 0.11, 0.11, 1.0}, bgHover = {0.16, 0.17, 0.18, 1.0},
        border = {0.0, 0.0, 0.0, 0.0}, textNormal = {0.80, 0.80, 0.80},
        textTitle = {0.44, 0.53, 0.85}, accent = {0.44, 0.53, 0.85},
    },
}

addon.Themes.BlizzardClassic = {
    name = "Blizzard Classic", key = "blizzardclassic", isPro = true, isEditable = false,
    colors = {
        bgPanel = {0.93, 0.87, 0.73, 1.0}, bgHover = {0.80, 0.60, 0.20, 0.30},
        border = {0.60, 0.60, 0.60, 1.0}, textNormal = {0.15, 0.09, 0.04},
        textTitle = {0.35, 0.22, 0.05}, accent = {0.60, 0.40, 0.10},
    },
}

addon.Themes.Dragonflight = {
    name = "Dragonflight", key = "dragonflight", isPro = true, isEditable = true,
    colors = {
        bgPanel = {0.11, 0.12, 0.13, 0.95}, bgHover = {0.20, 0.22, 0.25, 0.5},
        border = {0.35, 0.35, 0.38, 1.0}, textNormal = {0.85, 0.85, 0.85},
        textTitle = {0.95, 0.80, 0.30}, accent = {0.20, 0.60, 1.0},
    },
}

addon.Themes.WrathClassic = {
    name = "Wrath Classic", key = "wrathclassic", isPro = true, isEditable = false,
    colors = {
        bgPanel = {0.05, 0.08, 0.12, 0.90}, bgHover = {0.15, 0.25, 0.40, 0.4},
        border = {0.40, 0.50, 0.60, 1.0}, textNormal = {0.85, 0.90, 0.95},
        textTitle = {0.40, 0.80, 1.0}, accent = {0.30, 0.70, 0.95},
    },
}

addon.Themes.RUFModern = {
    name = "RUF Modern", key = "rufmodern", isPro = true, isEditable = true,
    colors = {
        bgPanel = {0.12, 0.12, 0.12, 0.95}, bgHover = {0.22, 0.22, 0.22, 1.0},
        border = {0.20, 0.20, 0.20, 1.0}, textNormal = {0.80, 0.80, 0.80},
        textTitle = {0.90, 0.90, 0.90}, accent = {0.60, 0.60, 0.60},
    },
}

addon.Themes.WarcraftLogs = {
    name = "Warcraft Logs", key = "warcraftlogs", isPro = true, isEditable = true,
    colors = {
        bgPanel = {0.05, 0.05, 0.07, 0.98}, bgHover = {0.12, 0.12, 0.15, 1.0},
        border = {0.15, 0.15, 0.18, 1.0}, textNormal = {0.75, 0.75, 0.80},
        textTitle = {0.64, 0.20, 0.93}, accent = {0.64, 0.20, 0.93},
    },
}

-- índice por clave de config, en orden de menú
addon.ThemeOrder = { "elvuidark", "minimaldark", "blizzardclassic", "dragonflight", "wrathclassic", "rufmodern", "warcraftlogs" }
addon.ThemesByKey = {}
for _, t in pairs(addon.Themes) do
    if type(t) == "table" and t.key then addon.ThemesByKey[t.key] = t end
end

-- ========================= MODO PRO =================================
function addon:IsProUnlocked()
    return SKquestsDB and SKquestsDB.config and SKquestsDB.config.proUnlocked
end

function addon:TryUnlockPro(code)
    code = (code or ""):upper():gsub("%s+", "")
    local codes = _G.SKQUESTS_PRO_CODES or {}
    if codes[code] then
        SKquestsDB.config.proUnlocked = true
        addon:Print("|cff33ff99Modo Pro activado.|r Temas premium y editor desbloqueados.")
        return true
    end
    addon:Print("Código no válido.")
    return false
end

-- ===================== ADAPTADOR DE PALETA ==========================
local function mul(col, f)
    return { math.min(col[1] * f, 1), math.min(col[2] * f, 1), math.min(col[3] * f, 1) }
end

function addon:GetCustomPalette(themeKey)
    local t = addon.ThemesByKey and addon.ThemesByKey[themeKey]
    if not t then return nil end

    local c = {}
    for k, v in pairs(t.colors) do c[k] = v end
    local ov = SKquestsDB and SKquestsDB.config and SKquestsDB.config.themeOverrides
    ov = ov and ov[themeKey]
    if ov then
        for k, v in pairs(ov) do c[k] = v end
    end

    -- temas claros oscurecen al seleccionar; oscuros aclaran
    local light = (c.bgPanel[1] + c.bgPanel[2] + c.bgPanel[3]) / 3 > 0.5
    local f1 = light and 0.96 or 1.18
    local f2 = light and 0.98 or 1.10
    local f3 = light and 0.94 or 1.25

    return {
        bg         = { c.bgPanel[1], c.bgPanel[2], c.bgPanel[3] },
        bgSide     = mul(c.bgPanel, f1),
        bgList     = mul(c.bgPanel, f2),
        bgDetail   = mul(c.bgPanel, f3),
        bgSelected = { c.accent[1] * 0.45, c.accent[2] * 0.45, c.accent[3] * 0.45 },
        bgHover    = { c.bgHover[1], c.bgHover[2], c.bgHover[3] },
        border     = { c.border[1], c.border[2], c.border[3] },
        borderDim  = mul(c.border, 0.8),
        gold       = { c.textTitle[1], c.textTitle[2], c.textTitle[3] },
        white      = { c.textNormal[1], c.textNormal[2], c.textNormal[3] },
        dim        = light and mul(c.textNormal, 2.2) or mul(c.textNormal, 0.62),
        sectionLbl = light and mul(c.textNormal, 1.6) or mul(c.textNormal, 0.80),
        green      = { 0.10, 0.65, 0.10 },
        objDone    = { 0.10, 0.65, 0.10 },
        objPending = { c.textNormal[1], c.textNormal[2], c.textNormal[3] },
        wowBlue    = { c.accent[1], c.accent[2], c.accent[3] },
    }
end
