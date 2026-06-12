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
    metrics = { borderSize = 1, padding = 4 },
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

-- índice por clave de config ("elvuidark" / "minimaldark")
addon.ThemesByKey = {
    elvuidark   = addon.Themes.ElvUIDark,
    minimaldark = addon.Themes.MinimalDark,
}

-- Orden de temas extra para el desplegable (esta build: solo los 2 libres)
addon.ThemeOrder = { "elvuidark", "minimaldark" }

-- Compatibilidad con la UI (sistema Pro): en esta build no hay temas Pro,
-- así que el desbloqueo es siempre verdadero y no se gatea nada.
function addon:IsProUnlocked() return true end
function addon:TryUnlockPro() return true end
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
        borderDim  = mul(c.border, 0.8),
        gold       = { c.textTitle[1], c.textTitle[2], c.textTitle[3] },
        white      = { c.textNormal[1], c.textNormal[2], c.textNormal[3] },
        dim        = mul(c.textNormal, 0.62),
        sectionLbl = mul(c.textNormal, 0.80),
        green      = { 0.20, 0.85, 0.20 },
        objDone    = { 0.20, 0.85, 0.20 },
        objPending = { c.textNormal[1], c.textNormal[2], c.textNormal[3] },
        wowBlue    = { c.accent[1], c.accent[2], c.accent[3] },
    }
end
