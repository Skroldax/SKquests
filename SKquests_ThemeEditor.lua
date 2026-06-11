-- ====================================================================
-- SKquests - Editor de temas (Modo Pro)
-- Adaptado a WoW 3.3.5a. El desbloqueo se hace con un código Pro
-- introducido en la propia interfaz (popup).
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
    container:SetSize(380, 28)

    local lbl = container:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    lbl:SetPoint("LEFT", 0, 0)
    lbl:SetWidth(200)
    lbl:SetJustifyH("LEFT")
    lbl:SetText(labelText)

    local colorPreview = CreateFrame("Button", nil, container)
    colorPreview:SetSize(20, 20)
    colorPreview:SetPoint("LEFT", lbl, "RIGHT", 8, 0)
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
        ColorPickerFrame:SetFrameStrata("TOOLTIP")
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
    editorFrame:SetSize(440, 380)
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
    title:SetText("Editor de Temas |cff33ff99(Pro)|r")

    local close = CreateFrame("Button", nil, editorFrame, "UIPanelCloseButton")
    close:SetPoint("TOPRIGHT", -6, -6)

    local sub = editorFrame:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    sub:SetPoint("TOPLEFT", 16, -40)
    editorFrame.sub = sub

    editorFrame.widgets = {}
    return editorFrame
end

local function OpenEditor()
    local f = BuildEditor()

    local themeKey = SKquestsDB and SKquestsDB.config and SKquestsDB.config.theme
    local theme = addon.ThemesByKey and addon.ThemesByKey[themeKey]
    if not theme then
        addon:Print("Activa primero un tema personalizable (p. ej. ElvUI Dark) en Ajustes.")
        return
    end
    if theme.isEditable == false then
        addon:Print("El tema '" .. theme.name .. "' usa texturas prerenderizadas y no es editable.")
        return
    end

    f.sub:SetText("Editando: |cffffd100" .. theme.name .. "|r  — los cambios se aplican y guardan al instante")

    for _, w in ipairs(f.widgets) do w:Hide() end
    f.widgets = {}

    SKquestsDB.config.themeOverrides = SKquestsDB.config.themeOverrides or {}
    SKquestsDB.config.themeOverrides[themeKey] = SKquestsDB.config.themeOverrides[themeKey] or {}
    local overrides = SKquestsDB.config.themeOverrides[themeKey]

    local fields = {
        { "Fondo principal", "bgPanel" },
        { "Fondo al pasar el ratón", "bgHover" },
        { "Acento (selección)", "accent" },
        { "Títulos", "textTitle" },
        { "Bordes", "border" },
        { "Texto normal", "textNormal" },
    }

    local yOffset = -66
    for _, data in ipairs(fields) do
        local label, key = data[1], data[2]
        local current = overrides[key] or theme.colors[key] or { 1, 1, 1 }
        local widget, updater = TE:CreateColorPickerWidget(f, label, key, function(r, g, b)
            overrides[key] = { r, g, b }
            if addon.ApplyTheme then addon:ApplyTheme() end
        end)
        widget:SetPoint("TOPLEFT", 16, yOffset)
        updater(current[1], current[2], current[3])
        table.insert(f.widgets, widget)
        yOffset = yOffset - 34
    end

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
addon.OpenEditorInternal = OpenEditor

-- ===================== POPUP DE CÓDIGO PRO ==========================
-- pendingAction: qué hacer tras desbloquear ("editor" o clave de tema)
local pendingAction

StaticPopupDialogs["SKQUESTS_PRO_CODE"] = {
    text = "SKquests Modo Pro\n\nIntroduce tu código (SKPRO-XXXX-XXXX):",
    button1 = "Activar",
    button2 = "Cancelar",
    hasEditBox = true,
    maxLetters = 20,
    OnShow = function(self)
        self:SetFrameStrata("TOOLTIP")
        local eb = _G[self:GetName() .. "EditBox"]
        if eb then eb:SetText(""); eb:SetFocus() end
    end,
    OnAccept = function(self)
        local eb = _G[self:GetName() .. "EditBox"]
        local code = eb and eb:GetText() or ""
        if addon:TryUnlockPro(code) then
            addon:RunPendingProAction()
        end
    end,
    EditBoxOnEnterPressed = function(self)
        local parent = self:GetParent()
        local code = self:GetText()
        parent:Hide()
        if addon:TryUnlockPro(code) then
            addon:RunPendingProAction()
        end
    end,
    EditBoxOnEscapePressed = function(self) self:GetParent():Hide() end,
    timeout = 0,
    whileDead = true,
    hideOnEscape = true,
}

function addon:RunPendingProAction()
    local act = pendingAction
    pendingAction = nil
    if act == "editor" then
        OpenEditor()
    elseif act and addon.ThemesByKey and addon.ThemesByKey[act] then
        SKquests.config.theme = act
        SKquestsDB.config.theme = act
        if addon.ApplyTheme then addon:ApplyTheme() end
        if addon.RefreshThemeDropdown then addon:RefreshThemeDropdown() end
    end
end

-- Pide código Pro; action = "editor" o clave de tema a aplicar tras desbloquear
function addon:RequestProCode(action)
    pendingAction = action
    StaticPopup_Show("SKQUESTS_PRO_CODE")
end

-- Punto de entrada del editor desde Ajustes
function addon:OpenThemeEditor()
    if addon:IsProUnlocked() then
        OpenEditor()
    else
        addon:RequestProCode("editor")
    end
end
