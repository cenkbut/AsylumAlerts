local _, AA = ...

local function MakeButton(parent, text, width, onClick)
    local button = CreateFrame("Button", nil, parent, "UIPanelButtonTemplate")
    button:SetSize(width or 120, 24)
    button:SetText(text)
    button:SetScript("OnClick", onClick)
    return button
end

local function MakeCheckbox(parent, text, onClick)
    local button = CreateFrame("Button", nil, parent)
    button:SetSize(350, 22)
    button:RegisterForClicks("LeftButtonUp")

    local box = button:CreateTexture(nil, "ARTWORK")
    box:SetSize(18, 18)
    box:SetPoint("LEFT")
    box:SetColorTexture(0.10, 0.10, 0.12, 1)
    local mark = button:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    mark:SetPoint("CENTER", box, "CENTER", 0, 1)
    mark:SetText("|cff9b7cffX|r")
    local label = button:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    label:SetPoint("LEFT", box, "RIGHT", 7, 0)
    label:SetText(text)

    button.checked = false
    function button:SetChecked(value)
        self.checked = value and true or false
        mark:SetShown(self.checked)
    end
    function button:GetChecked() return self.checked end
    button:SetScript("OnClick", function(self)
        self:SetChecked(not self:GetChecked())
        onClick(self:GetChecked())
    end)
    button:SetChecked(false)
    return button
end

local function FindEntryIndex(list, field, value)
    for index, entry in ipairs(list) do
        if entry[field] == value then return index end
    end
    return 1
end

function AA:CreateConfig()
    if self.config then return end
    local frame = CreateFrame("Frame", "AsylumAlertsConfig", UIParent, "BackdropTemplate")
    frame:SetSize(430, 750)
    frame:SetPoint("CENTER")
    frame:SetFrameStrata("DIALOG")
    frame:SetMovable(true)
    frame:EnableMouse(true)
    frame:RegisterForDrag("LeftButton")
    frame:SetClampedToScreen(true)
    frame:SetBackdrop({
        bgFile = "Interface/DialogFrame/UI-DialogBox-Background",
        edgeFile = "Interface/DialogFrame/UI-DialogBox-Border",
        tile = true, tileSize = 32, edgeSize = 32,
        insets = { left = 11, right = 12, top = 12, bottom = 11 },
    })
    frame:SetScript("OnDragStart", frame.StartMoving)
    frame:SetScript("OnDragStop", frame.StopMovingOrSizing)
    frame:SetScript("OnHide", function()
        if AA.db and not AA.db.locked then AA:SetLocked(true) end
    end)

    local title = frame:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    title:SetPoint("TOPLEFT", 22, -20)
    title:SetText("|cff9b7cffAsylum|rAlerts")

    local subtitle = frame:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    subtitle:SetPoint("TOPLEFT", title, "BOTTOMLEFT", 0, -6)
    subtitle:SetText("Visual alerts by default, with optional alert sounds.")

    local close = CreateFrame("Button", nil, frame, "UIPanelCloseButton")
    close:SetPoint("TOPRIGHT", -5, -5)

    local y = -74
    local enabled = MakeCheckbox(frame, "Enable AsylumAlerts", function(value)
        AA.db.enabled = value
        AA.suppressAnnouncementsUntil = GetTime() + 2
        if not value and AA.announcement then
            AA.announcement.alertUntil = nil
            wipe(AA.announcementQueue)
            AA.announcement:Hide()
        end
        AA:Refresh()
    end)
    enabled:SetPoint("TOPLEFT", 20, y)
    frame.enabled = enabled

    y = y - 34
    local weapon = MakeCheckbox(frame, "Weapon enchants, oils, poisons and stones", function(value)
        AA.db.showWeapon = value
        AA:Refresh()
    end)
    weapon:SetPoint("TOPLEFT", 20, y)
    frame.weapon = weapon

    y = y - 30
    local trinkets = MakeCheckbox(frame, "Trinket cooldowns", function(value)
        AA.db.showTrinkets = value
        AA:Refresh()
    end)
    trinkets:SetPoint("TOPLEFT", 20, y)
    frame.trinkets = trinkets

    y = y - 30
    local soulstone = MakeCheckbox(frame, "Soulstone cooldown (Warlock)", function(value)
        AA.db.showSoulstone = value
        AA.soulstoneState = {}
        AA:Refresh()
    end)
    soulstone:SetPoint("TOPLEFT", 20, y)
    frame.soulstone = soulstone

    y = y - 30
    local flasks = MakeCheckbox(frame, "Flasks, phials and long consumable buffs", function(value)
        AA.db.showFlasks = value
        AA:Refresh()
    end)
    flasks:SetPoint("TOPLEFT", 20, y)
    frame.flasks = flasks

    y = y - 30
    local personal = MakeCheckbox(frame, "Personal timed buffs cast by you", function(value)
        AA.db.showPersonal = value
        AA:Refresh()
    end)
    personal:SetPoint("TOPLEFT", 20, y)
    frame.personal = personal

    y = y - 30
    local external = MakeCheckbox(frame, "Buffs cast on you by other players", function(value)
        AA.db.showExternalBuffs = value
        AA.suppressAnnouncementsUntil = GetTime() + 1
        AA:Refresh()
    end)
    external:SetPoint("TOPLEFT", 20, y)
    frame.external = external

    y = y - 30
    local announcements = MakeCheckbox(frame, "Show ready / expired announcements", function(value)
        AA.db.showAnnouncements = value
        if not value and AA.announcement then
            AA.announcement.alertUntil = nil
            wipe(AA.announcementQueue)
            AA.announcement:Hide()
        elseif value and not AA.db.locked then
            AA:ShowPositionPreviews()
        end
    end)
    announcements:SetPoint("TOPLEFT", 20, y)
    frame.announcements = announcements

    y = y - 30
    local chatAlerts = MakeCheckbox(frame, "Print alerts in chat", function(value)
        AA.db.printChatAlerts = value
    end)
    chatAlerts:SetPoint("TOPLEFT", 20, y)
    frame.chatAlerts = chatAlerts

    y = y - 30
    local icons = MakeCheckbox(frame, "Show icons", function(value)
        AA.db.showIcons = value
        AA:RenderBars()
    end)
    icons:SetPoint("TOPLEFT", 20, y)
    frame.icons = icons

    y = y - 30
    local minimapButton = MakeCheckbox(frame, "Show minimap button", function(value)
        AA.db.showMinimapButton = value
        AA:UpdateMinimapButtonVisibility()
    end)
    minimapButton:SetPoint("TOPLEFT", 20, y)
    frame.minimapButton = minimapButton

    local lock = MakeButton(frame, "Unlock positions", 125, function() AA:ToggleLocked() end)
    lock:SetPoint("TOPLEFT", 22, -430)
    frame.lock = lock

    local reset = MakeButton(frame, "Reset positions", 125, function() AA:ResetPosition() end)
    reset:SetPoint("LEFT", lock, "RIGHT", 10, 0)

    local test = MakeButton(frame, "Test alert", 105, function()
        AA:ShowAnnouncement(AA:GetTrinketName(1) .. " is ready!", true)
    end)
    test:SetPoint("LEFT", reset, "RIGHT", 10, 0)

    local widthLabel = frame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    widthLabel:SetPoint("TOPLEFT", 22, -476)
    widthLabel:SetText("Bar width")
    local width = CreateFrame("Slider", nil, frame, "OptionsSliderTemplate")
    width:SetPoint("TOPLEFT", widthLabel, "BOTTOMLEFT", 5, -12)
    width:SetWidth(230)
    width:SetMinMaxValues(160, 420)
    width:SetValueStep(5)
    width:SetObeyStepOnDrag(true)
    width.Low:SetText("160")
    width.High:SetText("420")
    width:SetScript("OnValueChanged", function(_, value)
        if not AA.db then return end
        AA.db.width = math.floor(value + 0.5)
        widthLabel:SetText("Bar width: " .. AA.db.width)
        if AA.anchor then AA.anchor:SetWidth(AA.db.width) end
        AA:LayoutBars()
    end)
    frame.widthSlider = width

    local grow = MakeCheckbox(frame, "Grow upward", function(value)
        AA.db.growUp = value
        AA:LayoutBars()
    end)
    grow:SetPoint("TOPLEFT", 285, -482)
    frame.grow = grow

    local appearanceTitle = frame:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    appearanceTitle:SetPoint("TOPLEFT", 22, -555)
    appearanceTitle:SetText("Announcement appearance")

    local fontButton = MakeButton(frame, "Font", 190, function()
        local index = FindEntryIndex(AA.ALERT_FONTS, "path", AA.db.alertFont)
        index = (index % #AA.ALERT_FONTS) + 1
        AA.db.alertFont = AA.ALERT_FONTS[index].path
        AA:ApplyAlertAppearance()
        AA:UpdateConfig()
    end)
    fontButton:SetPoint("TOPLEFT", 22, -588)
    frame.fontButton = fontButton

    local colorLabel = frame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    colorLabel:SetPoint("LEFT", fontButton, "RIGHT", 18, 0)
    colorLabel:SetText("Colour")

    local colorSwatch = CreateFrame("Button", nil, frame)
    colorSwatch:SetSize(30, 24)
    colorSwatch:SetPoint("LEFT", colorLabel, "RIGHT", 8, 0)
    local swatchBorder = colorSwatch:CreateTexture(nil, "BACKGROUND")
    swatchBorder:SetAllPoints()
    swatchBorder:SetColorTexture(0.75, 0.75, 0.75, 1)
    local swatch = colorSwatch:CreateTexture(nil, "ARTWORK")
    swatch:SetPoint("TOPLEFT", 2, -2)
    swatch:SetPoint("BOTTOMRIGHT", -2, 2)
    frame.colorSwatch = swatch
    colorSwatch:SetScript("OnClick", function()
        local old = AA.db.alertColor
        local previous = { r = old.r, g = old.g, b = old.b }
        local function ApplyColor()
            local r, g, b = ColorPickerFrame:GetColorRGB()
            AA.db.alertColor = { r = r, g = g, b = b }
            swatch:SetColorTexture(r, g, b, 1)
            AA:ApplyAlertAppearance()
        end
        local function CancelColor(value)
            local restore = value or previous
            AA.db.alertColor = { r = restore.r, g = restore.g, b = restore.b }
            swatch:SetColorTexture(restore.r, restore.g, restore.b, 1)
            AA:ApplyAlertAppearance()
        end
        if ColorPickerFrame.SetupColorPickerAndShow then
            ColorPickerFrame:SetupColorPickerAndShow({
                r = previous.r, g = previous.g, b = previous.b,
                swatchFunc = ApplyColor,
                cancelFunc = CancelColor,
                hasOpacity = false,
            })
        else
            ColorPickerFrame.func = ApplyColor
            ColorPickerFrame.cancelFunc = function() CancelColor(previous) end
            ColorPickerFrame.hasOpacity = false
            ColorPickerFrame:SetColorRGB(previous.r, previous.g, previous.b)
            ColorPickerFrame:Show()
        end
    end)

    local sizeLabel = frame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    sizeLabel:SetPoint("TOPLEFT", 22, -635)
    sizeLabel:SetText("Font size")
    frame.sizeLabel = sizeLabel
    local sizeSlider = CreateFrame("Slider", nil, frame, "OptionsSliderTemplate")
    sizeSlider:SetPoint("TOPLEFT", sizeLabel, "BOTTOMLEFT", 5, -12)
    sizeSlider:SetWidth(230)
    sizeSlider:SetMinMaxValues(18, 52)
    sizeSlider:SetValueStep(1)
    sizeSlider:SetObeyStepOnDrag(true)
    sizeSlider.Low:SetText("18")
    sizeSlider.High:SetText("52")
    sizeSlider:SetScript("OnValueChanged", function(_, value)
        if not AA.db then return end
        AA.db.alertFontSize = math.floor(value + 0.5)
        sizeLabel:SetText("Font size: " .. AA.db.alertFontSize)
        AA:ApplyAlertAppearance()
    end)
    frame.sizeSlider = sizeSlider

    local soundButton = MakeButton(frame, "Sound: None", 230, function()
        local index = FindEntryIndex(AA.ALERT_SOUNDS, "key", AA.db.alertSound)
        index = (index % #AA.ALERT_SOUNDS) + 1
        AA.db.alertSound = AA.ALERT_SOUNDS[index].key
        AA:UpdateConfig()
    end)
    soundButton:SetPoint("TOPLEFT", 22, -715)
    frame.soundButton = soundButton

    local soundHelp = frame:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    soundHelp:SetPoint("LEFT", soundButton, "RIGHT", 10, 0)
    soundHelp:SetText("Use Test alert to preview")
    soundHelp:SetWidth(145)
    soundHelp:SetJustifyH("LEFT")

    self.config = frame
    frame:Hide()
end

function AA:UpdateConfig()
    if not self.config or not self.db then return end
    local frame = self.config
    frame.enabled:SetChecked(self.db.enabled)
    frame.weapon:SetChecked(self.db.showWeapon)
    frame.trinkets:SetChecked(self.db.showTrinkets)
    frame.soulstone:SetChecked(self.db.showSoulstone)
    frame.flasks:SetChecked(self.db.showFlasks)
    frame.personal:SetChecked(self.db.showPersonal)
    frame.external:SetChecked(self.db.showExternalBuffs)
    frame.announcements:SetChecked(self.db.showAnnouncements)
    frame.chatAlerts:SetChecked(self.db.printChatAlerts)
    frame.icons:SetChecked(self.db.showIcons)
    frame.minimapButton:SetChecked(self.db.showMinimapButton)
    frame.grow:SetChecked(self.db.growUp)
    frame.lock:SetText(self.db.locked and "Unlock positions" or "Lock positions")
    frame.widthSlider:SetValue(self.db.width)
    local fontIndex = FindEntryIndex(self.ALERT_FONTS, "path", self.db.alertFont)
    frame.fontButton:SetText("Font: " .. self.ALERT_FONTS[fontIndex].name)
    frame.sizeSlider:SetValue(self.db.alertFontSize)
    local soundIndex = FindEntryIndex(self.ALERT_SOUNDS, "key", self.db.alertSound)
    frame.soundButton:SetText("Sound: " .. self.ALERT_SOUNDS[soundIndex].name)
    local color = self.db.alertColor
    frame.colorSwatch:SetColorTexture(color.r, color.g, color.b, 1)
end

function AA:ToggleConfig()
    self:CreateConfig()
    if self.config:IsShown() then
        self.config:Hide()
    else
        self:UpdateConfig()
        self.config:Show()
    end
end

local function RegisterSettingsPanel()
    if not (Settings and Settings.RegisterCanvasLayoutCategory) then return end
    local panel = CreateFrame("Frame")
    panel.name = "AsylumAlerts"
    local title = panel:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    title:SetPoint("TOPLEFT", 18, -18)
    title:SetText("|cff9b7cffAsylum|rAlerts")
    local description = panel:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    description:SetPoint("TOPLEFT", title, "BOTTOMLEFT", 0, -12)
    description:SetText("Movable visual bars for your weapon enchants and timed buffs.")
    local open = MakeButton(panel, "Open AsylumAlerts", 180, function() AA:ToggleConfig() end)
    open:SetPoint("TOPLEFT", description, "BOTTOMLEFT", 0, -18)
    local category = Settings.RegisterCanvasLayoutCategory(panel, "AsylumAlerts")
    category.ID = "AsylumAlerts"
    Settings.RegisterAddOnCategory(category)
end

C_Timer.After(0, RegisterSettingsPanel)
