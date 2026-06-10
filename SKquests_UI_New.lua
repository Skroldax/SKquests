-- ==========================================
-- SKquests UI
-- Reemplazo completo de interfaz
-- ==========================================

local addon = SKquests

function addon:CreateModernUI()

    if self.MainFrame then
        return
    end

    ----------------------------------------------------
    -- FRAME PRINCIPAL
    ----------------------------------------------------

    local frame = CreateFrame(
        "Frame",
        "SKquestsMainFrame",
        UIParent,
        "BackdropTemplate"
    )

    frame:SetSize(1100, 700)
    frame:SetPoint("CENTER")
    frame:SetMovable(true)
    frame:EnableMouse(true)
    frame:RegisterForDrag("LeftButton")

    frame:SetScript("OnDragStart", frame.StartMoving)
    frame:SetScript("OnDragStop", frame.StopMovingOrSizing)

    frame:SetBackdrop({
        bgFile = "Interface\\Buttons\\WHITE8X8",
        edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
        tile = false,
        edgeSize = 12,
        insets = {
            left = 3,
            right = 3,
            top = 3,
            bottom = 3
        }
    })

    frame:SetBackdropColor(
        0.05,
        0.05,
        0.05,
        0.95
    )

    frame:Hide()

    self.MainFrame = frame

    ----------------------------------------------------
    -- HEADER
    ----------------------------------------------------

    local header = CreateFrame(
        "Frame",
        nil,
        frame,
        "BackdropTemplate"
    )

    header:SetPoint("TOPLEFT")
    header:SetPoint("TOPRIGHT")
    header:SetHeight(70)

    header:SetBackdrop({
        bgFile = "Interface\\Buttons\\WHITE8X8"
    })

    header:SetBackdropColor(
        0.10,
        0.10,
        0.10,
        1
    )

    ----------------------------------------------------
    -- LOGO
    ----------------------------------------------------

        local logo = header:CreateTexture(nil,"ARTWORK")
        logo:SetSize(180,50)
        logo:SetTexture(
            "Interface\\AddOns\\SKquests\\Media\\logo.blp"
        )

    ----------------------------------------------------
    -- SEARCH
    ----------------------------------------------------

    local searchBox = CreateFrame(
        "EditBox",
        nil,
        header,
        "InputBoxTemplate"
    )

    searchBox:SetSize(250,30)

    searchBox:SetPoint(
        "LEFT",
        logo,
        "RIGHT",
        40,
        0
    )

    searchBox:SetAutoFocus(false)

    searchBox:SetText("Search quest...")

    frame.SearchBox = searchBox

    ----------------------------------------------------
    -- CLOSE
    ----------------------------------------------------

    local close = CreateFrame(
        "Button",
        nil,
        header,
        "UIPanelCloseButton"
    )

    close:SetPoint(
        "RIGHT",
        -5,
        0
    )

    ----------------------------------------------------
    -- SIDEBAR
    ----------------------------------------------------

    local sidebar = CreateFrame(
        "Frame",
        nil,
        frame,
        "BackdropTemplate"
    )

    sidebar:SetPoint("TOPLEFT",0,-70)
    sidebar:SetPoint("BOTTOMLEFT",0,0)

    sidebar:SetWidth(220)

    sidebar:SetBackdrop({
        bgFile = "Interface\\Buttons\\WHITE8X8"
    })

    sidebar:SetBackdropColor(
        0.08,
        0.08,
        0.08,
        1
    )

    ----------------------------------------------------
    -- BOTONES SIDEBAR
    ----------------------------------------------------

    local buttons = {
        "Dashboard",
        "Quest Search",
        "Alliance",
        "Horde",
        "Settings"
    }

    local previous

    for _,text in ipairs(buttons) do

        local btn = CreateFrame(
            "Button",
            nil,
            sidebar,
            "UIPanelButtonTemplate"
        )

        btn:SetSize(180,32)

        if not previous then
            btn:SetPoint("TOP",0,-20)
        else
            btn:SetPoint(
                "TOP",
                previous,
                "BOTTOM",
                0,
                -10
            )
        end

        btn:SetText(text)

        previous = btn
    end

    ----------------------------------------------------
    -- QUEST LIST PANEL
    ----------------------------------------------------

    local listPanel = CreateFrame(
        "Frame",
        nil,
        frame,
        "BackdropTemplate"
    )

    listPanel:SetPoint(
        "TOPLEFT",
        sidebar,
        "TOPRIGHT",
        10,
        0
    )

    listPanel:SetSize(
        300,
        600
    )

    listPanel:SetBackdrop({
        bgFile = "Interface\\Buttons\\WHITE8X8"
    })

    listPanel:SetBackdropColor(
        0.12,
        0.12,
        0.12,
        1
    )

    ----------------------------------------------------
    -- SCROLL QUESTS
    ----------------------------------------------------

    local scroll = CreateFrame(
        "ScrollFrame",
        nil,
        listPanel,
        "UIPanelScrollFrameTemplate"
    )

    scroll:SetPoint("TOPLEFT",10,-10)
    scroll:SetPoint("BOTTOMRIGHT",-30,10)

    local content = CreateFrame(
        "Frame",
        nil,
        scroll
    )

    content:SetSize(250,2000)

    scroll:SetScrollChild(content)

    frame.QuestListContent = content

    ----------------------------------------------------
    -- QUEST DETAIL PANEL
    ----------------------------------------------------

    local detail = CreateFrame(
        "Frame",
        nil,
        frame,
        "BackdropTemplate"
    )

    detail:SetPoint(
        "TOPLEFT",
        listPanel,
        "TOPRIGHT",
        10,
        0
    )

    detail:SetPoint(
        "BOTTOMRIGHT",
        -10,
        10
    )

    detail:SetBackdrop({
        bgFile = "Interface\\Buttons\\WHITE8X8"
    })

    detail:SetBackdropColor(
        0.15,
        0.15,
        0.15,
        1
    )

    ----------------------------------------------------
    -- QUEST TITLE
    ----------------------------------------------------

    local questTitle = detail:CreateFontString(
        nil,
        "OVERLAY",
        "GameFontNormalLarge"
    )

    questTitle:SetPoint(
        "TOPLEFT",
        20,
        -20
    )

    questTitle:SetText(
        "Select a Quest"
    )

    frame.QuestTitle = questTitle

    ----------------------------------------------------
    -- WOWHEAD BUTTON
    ----------------------------------------------------

    local wowheadBtn = CreateFrame(
        "Button",
        nil,
        detail,
        "UIPanelButtonTemplate"
    )

    wowheadBtn:SetSize(
        120,
        28
    )

    wowheadBtn:SetPoint(
        "TOPRIGHT",
        -20,
        -15
    )

    wowheadBtn:SetText(
        "Wowhead"
    )

    frame.WowheadButton = wowheadBtn

    ----------------------------------------------------
    -- DESCRIPTION
    ----------------------------------------------------

    local description = detail:CreateFontString(
        nil,
        "OVERLAY",
        "GameFontHighlight"
    )

    description:SetPoint(
        "TOPLEFT",
        20,
        -70
    )

    description:SetWidth(500)

    description:SetJustifyH("LEFT")
    description:SetJustifyV("TOP")

    description:SetText(
        "Quest information will appear here."
    )

    frame.Description = description

    ----------------------------------------------------
    -- IMAGE
    ----------------------------------------------------

    local image = detail:CreateTexture(
        nil,
        "ARTWORK"
    )

    image:SetSize(
        450,
        250
    )

    image:SetPoint(
        "BOTTOM",
        0,
        30
    )

    image:SetTexture(
        "Interface\\Icons\\INV_Misc_Map_01"
    )

    frame.QuestImage = image

    ----------------------------------------------------
    -- RESIZE
    ----------------------------------------------------

    local resize = CreateFrame(
        "Button",
        nil,
        frame
    )

    resize:SetPoint(
        "BOTTOMRIGHT"
    )

    resize:SetSize(
        16,
        16
    )

    resize:SetNormalTexture(
        "Interface\\ChatFrame\\UI-ChatIM-SizeGrabber-Up"
    )

    resize:SetHighlightTexture(
        "Interface\\ChatFrame\\UI-ChatIM-SizeGrabber-Highlight"
    )

    resize:SetPushedTexture(
        "Interface\\ChatFrame\\UI-ChatIM-SizeGrabber-Down"
    )

    frame:SetResizable(true)

    resize:SetScript(
        "OnMouseDown",
        function()
            frame:StartSizing("BOTTOMRIGHT")
        end
    )

    resize:SetScript(
        "OnMouseUp",
        function()
            frame:StopMovingOrSizing()
        end
    )

end

----------------------------------------------------
-- OPEN/CLOSE
----------------------------------------------------

function addon:ToggleUI()

    if not self.MainFrame then
        self:CreateModernUI()
    end

    if self.MainFrame:IsShown() then
        self.MainFrame:Hide()
    else
        self.MainFrame:Show()
    end
end