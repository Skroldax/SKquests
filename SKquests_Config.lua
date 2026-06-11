-- SKquests Configuration Panel
-- Enhanced with language selector

function SKquests:InitConfig()
    if self.configFrame then
        return
    end
    
    local config = self.config or {}
    
    local frame = CreateFrame("Frame", "SKquestsConfigFrame", UIParent, "BackdropTemplate")
    frame:SetSize(500, 600)
    frame:SetPoint("CENTER")
    frame:SetMovable(true)
    frame:EnableMouse(true)
    frame:RegisterForDrag("LeftButton")
    frame:SetScript("OnDragStart", frame.StartMoving)
    frame:SetScript("OnDragStop", frame.StopMovingOrSizing)
    frame:Hide()
    self.ConfigPanel = frame
    frame:SetBackdrop({
        bgFile = "Interface/ChatFrame/ChatFrameBackground",
        edgeFile = "Interface/Tooltips/UI-Tooltip-Border",
        tile = true,
        tileSize = 16,
        edgeSize = 16,
        insets = { left = 4, right = 4, top = 4, bottom = 4 },
    })
    frame:SetBackdropColor(0, 0, 0, 0.9)
    frame:Hide()

    -- Title
    local title = frame:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    title:SetPoint("TOPLEFT", 16, -16)
    title:SetText("SKquests - Settings")

    -- Close button
    local close = CreateFrame("Button", nil, frame, "UIPanelCloseButton")
    close:SetPoint("TOPRIGHT", -16, -16)
    close:SetScript("OnClick", function()
        SKquests:HideConfig()
    end)

    -- Create scrollable content area
    local scroll = CreateFrame("ScrollFrame", "SKquestsConfigScroll", frame, "UIPanelScrollFrameTemplate")
    scroll:SetPoint("TOPLEFT", 16, -50)
    scroll:SetPoint("BOTTOMRIGHT", -36, 60)

    local content = CreateFrame("Frame", nil, scroll)
    content:SetSize(450, 500)
    scroll:SetScrollChild(content)

    -- GENERAL SECTION
    local generalTitle = content:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    generalTitle:SetPoint("TOPLEFT", 10, 0)
    generalTitle:SetText("GENERAL")

    -- Language selector
    local langLabel = content:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    langLabel:SetPoint("TOPLEFT", 20, -30)
    langLabel:SetText("Language:")

    local langDropdown = CreateFrame("Button", "SKquestsLangDropdown", content, "UIDropDownMenuTemplate")
    langDropdown:SetPoint("LEFT", langLabel, "RIGHT", 10, 3)

    local function SetupLangDropdown()
        local languages = {
            {text = "English (enUS)", value = "enUS"},
            {text = "Espanol (esES)", value = "esES"}
        }

        UIDropDownMenu_Initialize(langDropdown, function(self, level)
            for _, lang in ipairs(languages) do
                local info = UIDropDownMenu_CreateInfo()
                info.text = lang.text
                info.value = lang.value
                info.func = function()
                    SKquests.db.language = lang.value
                    SKquestsDB.profile.language = lang.value
                    if SKquests_Localization then
                        SKquests_Localization:SetLanguage(lang.value)
                    end
                    UIDropDownMenu_SetSelectedValue(langDropdown, lang.value)
                    if SKquests.ApplyLanguage then SKquests:ApplyLanguage(lang.value) end
                    print("|cff33ff99SKquests|r: " .. (L and L("LANG_CHANGED") or "") .. lang.text)
                    SKquests:UpdateFrame()
                end
                UIDropDownMenu_AddButton(info, level)
            end
        end)
    end

    SetupLangDropdown()
    UIDropDownMenu_SetSelectedValue(langDropdown, SKquests.db.language or "enUS")

    -- Show Title Checkbox
    local showTitleCheck = CreateFrame("CheckButton", nil, content, "UICheckButtonTemplate")
    showTitleCheck:SetPoint("TOPLEFT", 20, -70)
    showTitleCheck:SetChecked(config.showTitle ~= false)
    showTitleCheck:SetScript("OnClick", function(self)
        SKquests.config.showTitle = self:GetChecked()
        SKquestsDB.config.showTitle = self:GetChecked()
        SKquests:UpdateFrame()
    end)
    local showTitleCheck_txt = showTitleCheck:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    showTitleCheck_txt:SetPoint("LEFT", showTitleCheck, "RIGHT", 5, 0)
    showTitleCheck_txt:SetText("Show quest title")

    -- Show Image Checkbox
    local showImageCheck = CreateFrame("CheckButton", nil, content, "UICheckButtonTemplate")
    showImageCheck:SetPoint("TOPLEFT", 20, -100)
    showImageCheck:SetChecked(config.showImage ~= false)
    showImageCheck:SetScript("OnClick", function(self)
        SKquests.config.showImage = self:GetChecked()
        SKquestsDB.config.showImage = self:GetChecked()
        SKquests:UpdateFrame()
    end)
    local showImageCheck_txt = showImageCheck:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    showImageCheck_txt:SetPoint("LEFT", showImageCheck, "RIGHT", 5, 0)
    showImageCheck_txt:SetText("Show map image")

    -- Auto Minimize Checkbox
    local autoMinCheck = CreateFrame("CheckButton", nil, content, "UICheckButtonTemplate")
    autoMinCheck:SetPoint("TOPLEFT", 20, -130)
    autoMinCheck:SetChecked(config.autoMinimize or false)
    autoMinCheck:SetScript("OnClick", function(self)
        SKquests.config.autoMinimize = self:GetChecked()
        SKquestsDB.config.autoMinimize = self:GetChecked()
    end)
    local autoMinCheck_txt = autoMinCheck:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    autoMinCheck_txt:SetPoint("LEFT", autoMinCheck, "RIGHT", 5, 0)
    autoMinCheck_txt:SetText("Auto minimize in combat")

    -- Questie Integration Checkbox
    local questieCheck = CreateFrame("CheckButton", nil, content, "UICheckButtonTemplate")
    questieCheck:SetPoint("TOPLEFT", 20, -160)
    questieCheck:SetChecked(config.questieIntegration ~= false)
    questieCheck:SetScript("OnClick", function(self)
        SKquests.config.questieIntegration = self:GetChecked()
        SKquestsDB.config.questieIntegration = self:GetChecked()
    end)
    local questieCheck_txt = questieCheck:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    questieCheck_txt:SetPoint("LEFT", questieCheck, "RIGHT", 5, 0)
    questieCheck_txt:SetText("Questie integration")

    -- APPEARANCE SECTION
    local appearanceTitle = content:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    appearanceTitle:SetPoint("TOPLEFT", 10, -200)
    appearanceTitle:SetText("APPEARANCE")

    -- Image Size Label
    local imageSizeLabel = content:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    imageSizeLabel:SetPoint("TOPLEFT", 20, -230)
    imageSizeLabel:SetText("Image size:")

    local imageSizeDropdown = CreateFrame("Button", "SKquestsImageSizeDropdown", content, "UIDropDownMenuTemplate")
    imageSizeDropdown:SetPoint("LEFT", imageSizeLabel, "RIGHT", 10, 3)

    local function SetupImageSizeDropdown()
        local sizes = {
            {text = "Small", value = "small"},
            {text = "Medium", value = "medium"},
            {text = "Large", value = "large"}
        }

        UIDropDownMenu_Initialize(imageSizeDropdown, function(self, level)
            for _, size in ipairs(sizes) do
                local info = UIDropDownMenu_CreateInfo()
                info.text = size.text
                info.value = size.value
                info.func = function()
                    SKquests.config.imageSize = size.value
                    SKquestsDB.config.imageSize = size.value
                    UIDropDownMenu_SetSelectedValue(imageSizeDropdown, size.value)
                    SKquests:UpdateFrame()
                end
                UIDropDownMenu_AddButton(info, level)
            end
        end)
    end

    SetupImageSizeDropdown()
    UIDropDownMenu_SetSelectedValue(imageSizeDropdown, config.imageSize or "medium")

    -- Text Size Label
    local textSizeLabel = content:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    textSizeLabel:SetPoint("TOPLEFT", 20, -260)
    textSizeLabel:SetText("Text size:")

    local textSizeDropdown = CreateFrame("Button", "SKquestsTextSizeDropdown", content, "UIDropDownMenuTemplate")
    textSizeDropdown:SetPoint("LEFT", textSizeLabel, "RIGHT", 10, 3)

    local function SetupTextSizeDropdown()
        local sizes = {
            {text = "Small", value = "small"},
            {text = "Normal", value = "normal"},
            {text = "Large", value = "large"}
        }

        UIDropDownMenu_Initialize(textSizeDropdown, function(self, level)
            for _, size in ipairs(sizes) do
                local info = UIDropDownMenu_CreateInfo()
                info.text = size.text
                info.value = size.value
                info.func = function()
                    SKquests.config.textSize = size.value
                    SKquestsDB.config.textSize = size.value
                    UIDropDownMenu_SetSelectedValue(textSizeDropdown, size.value)
                    SKquests:UpdateFrame()
                end
                UIDropDownMenu_AddButton(info, level)
            end
        end)
    end

    SetupTextSizeDropdown()
    UIDropDownMenu_SetSelectedValue(textSizeDropdown, config.textSize or "normal")

    -- Opacity Slider
    local opacityLabel = content:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    opacityLabel:SetPoint("TOPLEFT", 20, -290)
    opacityLabel:SetText("Opacity:")

    local opacitySlider = CreateFrame("Slider", "SKquestsOpacitySlider", content, "OptionsSliderTemplate")
    opacitySlider:SetPoint("TOPLEFT", 20, -310)
    opacitySlider:SetWidth(200)
    opacitySlider:SetMinMaxValues(0, 100)
    opacitySlider:SetValue((config.opacity or 0.9) * 100)
    opacitySlider:SetValueStep(5)
    opacitySlider:SetScript("OnValueChanged", function(self)
        local value = self:GetValue() / 100
        SKquests.config.opacity = value
        SKquestsDB.config.opacity = value
        if SKquests.frame then
            SKquests.frame:SetBackdropColor(0, 0, 0, value)
        end
    end)
    opacitySlider.Low:SetText("0%")
    opacitySlider.High:SetText("100%")
    opacitySlider.Text:SetText(("Opacity: %.0f%%"):format((config.opacity or 0.9) * 100))

    -- INFORMATION SECTION
    local infoTitle = content:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    infoTitle:SetPoint("TOPLEFT", 10, -380)
    infoTitle:SetText("INFORMATION")

    local infoText = content:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    infoText:SetPoint("TOPLEFT", 20, -410)
    infoText:SetPoint("TOPRIGHT", -20, -410)
    infoText:SetWordWrap(true)
    infoText:SetText("SKquests provides step-by-step leveling guides for 1-60 with Questie integration. Select your language and configure the display options above.")

    -- Accept Button
    local accept = CreateFrame("Button", nil, frame, "UIPanelButtonTemplate")
    accept:SetSize(100, 24)
    accept:SetPoint("BOTTOMRIGHT", -125, 16)
    accept:SetText("Accept")
    accept:SetScript("OnClick", function()
        SKquests:HideConfig()
    end)

    -- Close Button
    local closeBtn = CreateFrame("Button", nil, frame, "UIPanelButtonTemplate")
    closeBtn:SetSize(100, 24)
    closeBtn:SetPoint("BOTTOMRIGHT", -16, 16)
    closeBtn:SetText("Close")
    closeBtn:SetScript("OnClick", function()
        SKquests:HideConfig()
    end)

    self.configFrame = frame
end

function SKquests:ShowConfig()
    if not self.configFrame then
        self:InitConfig()
    end
    if self.configFrame then
        self.configFrame:Show()
    end
end

function SKquests:HideConfig()
    if self.configFrame then
        self.configFrame:Hide