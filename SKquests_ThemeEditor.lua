-- ====================================================================
-- SKquests - Editor de temas (requiere contraseña de administrador)
-- Adaptado a WoW 3.3.5a (SetTexture en lugar de SetColorTexture).
-- ====================================================================

local addon = SKquests
addon.ThemeEditor = {}
local TE = addon.ThemeEditor

-- ============================ UTILIDADES ============================
local function HexToRGB(hex)
    hex = hex:gsub("#", "")
    if string.len(hex) ~= 6 then return 1, 1, 1 end
    local r = (tonumber("0x" .. hex:sub(1, 2)) or 255) / 255
    local g = (tonumber("0x" .. hex:sub(3, 4)) or 255) / 255
    local b = (tonumber("0x" .. hex:sub(5, 6)) or 255) / 255
    return r, g, b
end

local function RGBToHex(r, g, b)
    return string.format("#%02X%02X%02X",
        math.floor(r * 255 + 0.5), math.floor(g * 255 + 0.5), math.floor(b * 255 + 0.5))
end

-- ===================== WIDGET DE COLOR ==============================
function TE:CreateColorPickerWidget(parent, labelText, key, callback)
    local container = CreateFrame("Frame", nil, parent)
    container:SetSize(360, 30)

    local lbl = container:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    lbl:SetPoint("LEFT", 0, 0)
    lbl:SetWidth(190)
    lbl:SetJustifyH("LEFT")
    lbl:SetText(labelText)

    local colorPreview = CreateFrame("Button", nil, container)
    colorPreview:SetSize(20, 20)
    colorPreview:SetPoint("LEFT", lbl, "RIGHT", 10, 0)
    local tex = colorPreview:CreateTexture(nil, "BACKGROUND")
    tex:SetAllPoints()
    tex:SetTexture(1, 1, 1, 1)
    colorPreview.tex = tex

    local hexInput = CreateFrame("EditBox", nil, container, "InputBoxTemplate")
    hexInput:SetSize(80, 20)
    hexInput:SetPoint("LEFT", colorPreview, "RIGHT", 12, 0)
    hexInput:SetAutoFocus(false)

    local function UpdateWidget(r, g, b)
        tex:SetTexture(r, g, b, 1)
        hexInput:SetText(RGBToHex(r, g, b))
        if callback then callback(r, g, b) end
    end

    hexInput:SetScript("OnEnterPressed", function(self)
        local r, g, b = HexToRGB(self:GetText())
        UpdateWidget(r, g, b)
        self:ClearFocus()
    end)
    hexInput:SetScript("OnEscapePressed", function(self) self:ClearFocus() end)

    colorPreview:SetScript("OnClick", function()
        local r, g, b = HexToRGB(hexInput:GetText())
        ColorPickerFrame:SetColorRGB(r, g, b)
        ColorPickerFrame.hasOpacity = false
        ColorPickerFrame.previousValues = { r, g, b }
        ColorPickerFrame.func = function()
            local pr, pg, pb = ColorPickerFrame:GetColorRGB()
            UpdateWidget(pr, pg, pb)
        end
        ColorPickerFrame.cancelFunc = function(prev)
            UpdateWidget(prev[1], prev[2], prev[3])
        end
        ColorPickerFrame:Show()
    end)

    return container, UpdateWidget
end

-- ===================== VENTANA DEL EDITOR ===========================
local editorFrame

local function BuildEditor()
    if editorFrame then return editorFrame end

    editorFrame = CreateFrame("Frame", "SKquestsThemeEditorFrame", UIParent)
    editorFrame:SetSize(420, 320)
    editorFrame:SetPoint("CENTER")
    editorFrame:SetFrameStrata("FULLSCREEN_DIALOG")
    editorFrame:SetMovable(true)
    editorFrame:EnableMouse(true)
    editorFrame:RegisterForDrag("LeftButton")
    editorFrame:SetScript("OnDragStart", editorFrame.StartMoving)
    editorFrame:SetScript("OnDragStop", editorFrame.StopMovingOrSizing)
    editorFrame:SetBackdrop({
        bgFile = "Interface\\ChatFrame\\ChatFrameBackground",
        edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
        edgeSize = 12, insets = { left = 3, right = 3, top = 3, bottom = 3 },
    })
    editorFrame:SetBackdropColor(0.06, 0.06, 0.06, 0.97)
    editorFrame:SetBackdropBorderColor(0.4, 0.35, 0.25, 1)
    tinsert(UISpecialFrames, "SKquestsThemeEditorFrame")

    local title = editorFrame:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    title:SetPoint("TOPLEFT", 16, -14)
    title:SetText("Editor de Temas (Admin)")
    title:SetTextColor(0.9, 0.75, 0.3)

    local close = CreateFrame("Button", nil, editorFrame, "UIPanelCloseButton")
    close:SetPoint("TOPRIGHT", -6, -6)

    local sub = editorFrame:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    sub:SetPoint("TOPLEFT", 16, -38)
    editorFrame.sub = sub

    editorFrame.widgets = {}
    return editorFrame
end

local function OpenEditor()
    local f = BuildEditor()

    -- tema activo: solo los editables
    local themeKey = SKquestsDB and SKquestsDB.config and SKquestsDB.config.theme
    local theme = addon.ThemesByKey and addon.ThemesByKey[themeKey]
    if not theme or not theme.isEditable then
        addon:Print("El editor no funciona con los temas por defecto. Elige otro tema (ej. ElvUI Dark) en Ajustes primero.")
        return
    end

    f.sub:SetText("Editando: " .. theme.name .. "  (los cambios se guardan al instante)")

    -- limpiar widgets previos
    for _, w in ipairs(f.widgets) do w:Hide() end
    f.widgets = {}

    SKquestsDB.config.themeOverrides = SKquestsDB.config.themeOverrides or {}
    SKquestsDB.config.themeOverrides[themeKey] = SKquestsDB.config.themeOverrides[themeKey] or {}
    local overrides = SKquestsDB.config.themeOverrides[themeKey]

    local fields = {
        { "Color de fondo principal", "bgPanel" },
        { "Color de acento / títulos", "accent" },
        { "Bordes de las ventanas", "border" },
        { "Color del texto", "textNormal" },
    }

    local yOffset = -64
    for _, data in ipairs(fields) do
        local label, key = data[1], data[2]
        local current = overrides[key] or theme.colors[key] or { 1, 1, 1 }
        local widget, updater = TE:CreateColorPickerWidget(f, label, key, function(r, g, b)
            overrides[key] = { r, g, b }
            if key == "accent" then overrides.textTitle = { r, g, b } end
            if addon.ApplyTheme then addon:ApplyTheme() end
        end)
        widget:SetPoint("TOPLEFT", 16, yOffset)
        updater(current[1], current[2], current[3])
        table.insert(f.widgets, widget)
        yOffset = yOffset - 36
    end

    -- botón de restablecer
    local resetBtn = CreateFrame("Button", nil, f, "UIPanelButtonTemplate")
    resetBtn:SetSize(160, 24)
    resetBtn:SetPoint("BOTTOMLEFT", 16, 14)
    resetBtn:SetText("Restablecer tema")
    resetBtn:SetScript("OnClick", function()
        SKquestsDB.config.themeOverrides[themeKey] = {}
        if addon.ApplyTheme then addon:ApplyTheme() end
        f:Hide()
        OpenEditor()
    end)
    table.insert(f.widgets, resetBtn)

    f:Show()
end

-- ===================== CONTRASEÑA DE ADMIN ==========================
StaticPopupDialogs["SKQUESTS_ADMIN_PASS"] = {
    text = "Editor de temas: introduce la contraseña de administrador",
    button1 = "Aceptar",
    button2 = "Cancelar",
    hasEditBox = true,
    maxLetters = 32,
    OnAccept = function(self)
        local pass = self.editBox and self.editBox:GetText() or _G[self:GetName() .. "EditBox"]:GetText()
        if pass == SKQUESTS_ADMIN_PASSWORD then
            SKquestsDB.config.adminUnlocked = true
            OpenEditor()
        else
            addon:Print("Contraseña incorrecta.")
        end
    end,
    EditBoxOnEnterPressed = function(self)
        local parent = self:GetParent()
        local pass = self:GetText()
        if pass == SKQUESTS_ADMIN_PASSWORD then
            SKquestsDB.config.adminUnlocked = true
            parent:Hide()
            OpenEditor()
        else
            addon:Print("Contraseña incorrecta.")
            parent:Hide()
        end
    end,
    EditBoxOnEscapePressed = function(self) self:GetParent():Hide() end,
    timeout = 0,
    whileDead = true,
    hideOnEscape = true,
}

-- Punto de entrada desde Ajustes
function addon:OpenThemeEditor()
    OpenEditor()
end
