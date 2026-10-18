local addonName, AA = ...

_G.AsylumAlerts = AA

local defaults = {
    enabled = true,
    locked = true,
    position = { "CENTER", "CENTER", 0, -140 },
    alertPosition = { "CENTER", "CENTER", 0, 220 },
    alertDuration = 3,
    alertFont = "Fonts\\FRIZQT__.TTF",
    alertFontSize = 32,
    alertColor = { r = 0, g = 1, b = 0 },
    alertSound = "none",
    width = 260,
    height = 24,
    spacing = 5,
    growUp = false,
    maxBars = 20,
    minPersonalDuration = 8,
    minimapAngle = 225,
    showMinimapButton = true,
    showIcons = true,
    showWeapon = true,
    showTrinkets = true,
    showPotions = true,
    showSoulstone = true,
    showFlasks = true,
    showPersonal = true,
    showExternalBuffs = false,
    showAnnouncements = true,
    printChatAlerts = false,
    weaponNames = {},
    colors = {
        weapon = { 0.86, 0.58, 0.20 },
        trinket = { 0.96, 0.36, 0.28 },
        potion = { 0.30, 0.82, 0.48 },
        soulstone = { 0.55, 0.30, 0.78 },
        flask = { 0.42, 0.72, 0.95 },
        personal = { 0.61, 0.42, 0.91 },
        external = { 0.25, 0.78, 0.88 },
    },
}

AA.active = {}
AA.bars = {}
AA.elapsed = 0
AA.scanElapsed = 0
AA.initialized = false
AA.trinketState = {}
AA.trinketAuraKeys = {}
AA.potionState = { knownBySpell = {}, slots = {} }
AA.playerCastSpells = {}
AA.playerRequestedSpells = {}
AA.iconCache = {}
AA.soulstoneState = {}
AA.announcementQueue = {}

local _, _, _, clientInterface = GetBuildInfo()
local IS_RETAIL = type(clientInterface) == "number" and clientInterface >= 100000

AA.ALERT_FONTS = {
    { name = "Friz Quadrata", path = "Fonts\\FRIZQT__.TTF" },
    { name = "Arial Narrow", path = "Fonts\\ARIALN.TTF" },
    { name = "Morpheus", path = "Fonts\\MORPHEUS.TTF" },
    { name = "Skurri", path = "Fonts\\SKURRI.TTF" },
}

AA.ALERT_SOUNDS = {
    { key = "none", name = "None", id = nil },
    { key = "raid", name = "Raid Warning", id = 8960 },
    { key = "ready", name = "Ready Check", id = 8959 },
    { key = "alarm", name = "Alarm Clock", id = 12889 },
    { key = "ping", name = "Map Ping", id = 6674 },
    { key = "level", name = "Level Up", id = 11466 },
}

local BAR_KIND_ORDER = {
    personal = 1,
    flask = 1,
    weapon = 2,
    external = 3,
    potion = 4,
    trinket = 4,
    soulstone = 4,
}

local function CopyDefaults(source, target)
    for key, value in pairs(source) do
        if type(value) == "table" then
            if type(target[key]) ~= "table" then target[key] = {} end
            CopyDefaults(value, target[key])
        elseif target[key] == nil then
            target[key] = value
        end
    end
end

local function SafeNumber(value)
    local ok, result = pcall(function()
        if type(value) == "number" and value == value then return value end
    end)
    return ok and result or nil
end

local function SafeText(value)
    local ok, result = pcall(function()
        if type(value) == "string" and value ~= "" then return value end
    end)
    return ok and result or nil
end

local function SafeTrue(value)
    local ok, result = pcall(function() return value == true end)
    return ok and result or false
end

local function SafeTexture(value)
    local number = SafeNumber(value)
    if number and number > 0 then return number end
    local text = SafeText(value)
    if text then
        local numericText = tonumber(text)
        if numericText and numericText > 0 then return numericText end
        return text
    end
end

local function FormatTime(seconds)
    seconds = math.max(0, seconds or 0)
    if seconds >= 3600 then
        return string.format("%d:%02d:%02d", math.floor(seconds / 3600), math.floor((seconds % 3600) / 60), math.floor(seconds % 60))
    elseif seconds >= 60 then
        return string.format("%d:%02d", math.floor(seconds / 60), math.floor(seconds % 60))
    elseif seconds >= 10 then
        return string.format("%d", seconds)
    end
    return string.format("%.1f", seconds)
end

local function AuraValue(aura, field)
    local ok, value = pcall(function() return aura[field] end)
    return ok and value or nil
end

local function ResolveSpellTexture(spellID)
    if not spellID then return nil end
    if C_Spell and C_Spell.GetSpellTexture then
        local ok, texture = pcall(C_Spell.GetSpellTexture, spellID)
        if ok and SafeTexture(texture) then return SafeTexture(texture) end
    end
    if C_Spell and C_Spell.GetSpellInfo then
        local ok, info = pcall(C_Spell.GetSpellInfo, spellID)
        if ok and info then
            local texture = SafeTexture(AuraValue(info, "iconID"))
                or SafeTexture(AuraValue(info, "icon"))
            if texture then return texture end
        end
    end
    if GetSpellTexture then
        local ok, texture = pcall(GetSpellTexture, spellID)
        if ok then return SafeTexture(texture) end
    end
    if GetSpellInfo then
        local ok, _, _, texture = pcall(GetSpellInfo, spellID)
        if ok then return SafeTexture(texture) end
    end
end

local function ResolveAuraTexture(aura, spellID, cacheKey)
    local texture = SafeTexture(AuraValue(aura, "icon"))
        or SafeTexture(AuraValue(aura, "iconFileID"))
        or SafeTexture(AuraValue(aura, "iconTexture"))
        or ResolveSpellTexture(spellID)
        or (cacheKey and AA.iconCache[cacheKey])
    if texture and cacheKey then AA.iconCache[cacheKey] = texture end
    return texture or 134400
end

local function ResolveItemTexture(itemID, slot)
    if slot and GetInventoryItemTexture then
        local ok, texture = pcall(GetInventoryItemTexture, "player", slot)
        if ok and SafeTexture(texture) then return SafeTexture(texture) end
    end
    if itemID and C_Item and C_Item.GetItemIconByID then
        local ok, texture = pcall(C_Item.GetItemIconByID, itemID)
        if ok and SafeTexture(texture) then return SafeTexture(texture) end
    end
    if itemID and GetItemIcon then
        local ok, texture = pcall(GetItemIcon, itemID)
        if ok then return SafeTexture(texture) end
    end
end

local function ResolveItemName(itemID, fallback)
    if itemID and C_Item and C_Item.GetItemNameByID then
        local ok, name = pcall(C_Item.GetItemNameByID, itemID)
        name = ok and SafeText(name) or nil
        if name then return name end
    end
    if itemID and GetItemInfo then
        local ok, name = pcall(GetItemInfo, itemID)
        name = ok and SafeText(name) or nil
        if name then return name end
    end
    if itemID and C_Item and C_Item.RequestLoadItemDataByID then
        pcall(C_Item.RequestLoadItemDataByID, itemID)
    end
    return fallback
end

local function IsPlayerAura(aura, spellID)
    local source = SafeText(AuraValue(aura, "sourceUnit"))
    local isFromPlayerOrPet = SafeTrue(AuraValue(aura, "isFromPlayerOrPlayerPet"))
    local castByPlayer = spellID and AA.playerCastSpells[spellID]
    local known
    if spellID then
        local ok, result = pcall(function()
            return (IsPlayerSpell and IsPlayerSpell(spellID))
                or (IsSpellKnown and IsSpellKnown(spellID))
                or (IsSpellKnownOrOverridesKnown and IsSpellKnownOrOverridesKnown(spellID))
        end)
        if ok then known = SafeTrue(result) end
    end
    if source then
        if source == "pet" then return true end
        if source == "player" then
            -- Retail reliably identifies self-applied item and food auras as
            -- player-sourced even though their aura spells are not learned.
            if IS_RETAIL then return true end
            if castByPlayer or known then return true end
            if spellID then return false end
            return true
        end
        local ok, isPlayer = pcall(UnitIsPlayer, source)
        if ok and isPlayer then return false end -- another player cast it
        return nil -- NPC/environment aura; do not treat it as an external class buff
    end
    -- Forever can report isFromPlayerOrPlayerPet=true for an aura applied to the
    -- player by somebody else. If the caster token is unavailable, ownership is
    -- instead inferred from whether this character actually knows the spell.
    if IS_RETAIL and isFromPlayerOrPet then return true end
    if castByPlayer or known then return true end
    if spellID then return false end
    return nil
end

local function IsEquippedTrinketAura(spellID, auraName)
    if not GetItemSpell then return false end
    for _, slot in ipairs({ 13, 14 }) do
        local itemID = GetInventoryItemID("player", slot)
        if itemID then
            local ok, spellName, itemSpellID = pcall(GetItemSpell, itemID)
            if ok then
                itemSpellID = SafeNumber(itemSpellID)
                spellName = SafeText(spellName)
                if (spellID and itemSpellID == spellID) or (auraName and spellName == auraName) then
                    return true
                end
            end
        end
    end
    return false
end

local function IsLongConsumable(name, duration)
    -- Keep class buffs such as Fortitude and Blessings out of the flask group.
    -- On non-English clients these still appear as ordinary personal/external bars.
    local lower = name:lower()
    return lower:find("flask", 1, true)
        or lower:find("phial", 1, true)
        or lower:find("elixir", 1, true)
end

local function IsSelfAppliedConsumable(name)
    -- Forever does not reliably expose the caster for item-created auras. Keep
    -- this list narrow so genuine buffs from other players remain external.
    return name:lower() == "well fed"
end

local function NormalizeMaintenanceName(name)
    if type(name) ~= "string" then return name end
    local base, rank = name:match("^(.-)%s+(%d+)$")
    if base and rank then
        local lowerBase = base:lower()
        if lowerBase:find("firestone$", 1) or lowerBase:find("spellstone$", 1) then
            return base .. " (Rank " .. rank .. ")"
        end
    end
    return name
end

local function Atan2(y, x)
    if math.atan2 then return math.atan2(y, x) end
    if x > 0 then return math.atan(y / x) end
    if x < 0 and y >= 0 then return math.atan(y / x) + math.pi end
    if x < 0 then return math.atan(y / x) - math.pi end
    if y > 0 then return math.pi / 2 end
    if y < 0 then return -math.pi / 2 end
    return 0
end

function AA:UpdateMinimapButtonPosition()
    if not self.minimapButton or not Minimap then return end
    local angle = math.rad(self.db.minimapAngle or defaults.minimapAngle)
    local radius = 80
    self.minimapButton:ClearAllPoints()
    self.minimapButton:SetPoint("CENTER", Minimap, "CENTER", math.cos(angle) * radius, math.sin(angle) * radius)
end

function AA:UpdateMinimapButtonVisibility()
    if not self.minimapButton then
        if self.db and self.db.showMinimapButton then self:CreateMinimapButton() end
        return
    end
    self.minimapButton:SetShown(self.db.showMinimapButton)
end

function AA:CreateMinimapButton()
    if self.minimapButton or not Minimap then return end
    local button = CreateFrame("Button", "AsylumAlertsMinimapButton", Minimap)
    button:SetSize(32, 32)
    button:SetFrameStrata("MEDIUM")
    button:SetFrameLevel((Minimap:GetFrameLevel() or 0) + 8)
    button:RegisterForClicks("LeftButtonUp", "RightButtonUp")
    button:RegisterForDrag("LeftButton")

    local icon = button:CreateTexture(nil, "ARTWORK")
    icon:SetAllPoints()
    icon:SetTexture("Interface\\AddOns\\AsylumAlerts\\Media\\AsylumAlertsIcon.tga")
    button.icon = icon
    button:SetHighlightTexture("Interface\\Minimap\\UI-Minimap-ZoomButton-Highlight", "ADD")

    button:SetScript("OnClick", function(_, mouseButton)
        if mouseButton == "RightButton" then
            AA:ToggleLocked()
        elseif AA.ToggleConfig then
            AA:ToggleConfig()
        end
    end)
    button:SetScript("OnEnter", function(frame)
        GameTooltip:SetOwner(frame, "ANCHOR_LEFT")
        GameTooltip:AddLine("AsylumAlerts", 0.61, 0.48, 1)
        GameTooltip:AddLine("Left-click: Open settings", 1, 1, 1)
        GameTooltip:AddLine("Right-click: Lock or unlock bars", 1, 1, 1)
        GameTooltip:AddLine("Drag: Move minimap button", 0.75, 0.75, 0.75)
        GameTooltip:Show()
    end)
    button:SetScript("OnLeave", function() GameTooltip:Hide() end)
    button:SetScript("OnDragStart", function(frame)
        frame:SetScript("OnUpdate", function()
            local centerX, centerY = Minimap:GetCenter()
            local cursorX, cursorY = GetCursorPosition()
            local scale = UIParent:GetEffectiveScale()
            cursorX, cursorY = cursorX / scale, cursorY / scale
            AA.db.minimapAngle = math.deg(Atan2(cursorY - centerY, cursorX - centerX))
            AA:UpdateMinimapButtonPosition()
        end)
    end)
    button:SetScript("OnDragStop", function(frame) frame:SetScript("OnUpdate", nil) end)

    self.minimapButton = button
    self:UpdateMinimapButtonPosition()
    self:UpdateMinimapButtonVisibility()
end

function AA:CreateAnchor()
    if self.anchor then return end

    local anchor = CreateFrame("Frame", "AsylumAlertsAnchor", UIParent, "BackdropTemplate")
    anchor:SetSize(self.db.width, 28)
    anchor:SetFrameStrata("DIALOG")
    anchor:SetClampedToScreen(true)
    anchor:SetMovable(true)
    anchor:RegisterForDrag("LeftButton")
    anchor:SetBackdrop({
        bgFile = "Interface/Buttons/WHITE8X8",
        edgeFile = "Interface/Buttons/WHITE8X8",
        edgeSize = 1,
    })
    anchor:SetBackdropColor(0.08, 0.08, 0.10, 0.92)
    anchor:SetBackdropBorderColor(0.61, 0.48, 1, 1)

    local label = anchor:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    label:SetPoint("CENTER")
    label:SetText("AsylumAlerts - drag to move")
    anchor.label = label

    anchor:SetScript("OnDragStart", function(frame)
        if not AA.db.locked then frame:StartMoving() end
    end)
    anchor:SetScript("OnDragStop", function(frame)
        frame:StopMovingOrSizing()
        local point, _, relPoint, x, y = frame:GetPoint(1)
        AA.db.position = { point or "CENTER", relPoint or "CENTER", x or 0, y or 0 }
        AA:LayoutBars()
    end)

    self.anchor = anchor
    self:ApplyAnchorPosition()
    self:SetLocked(self.db.locked, true)
end

function AA:CreateAnnouncementFrame()
    if self.announcement then return end
    local frame = CreateFrame("Frame", "AsylumAlertsAnnouncement", UIParent, "BackdropTemplate")
    frame:SetSize(680, 70)
    frame:SetFrameStrata("HIGH")
    frame:SetClampedToScreen(true)
    frame:SetMovable(true)
    frame:RegisterForDrag("LeftButton")
    frame:SetBackdrop({
        bgFile = "Interface/Buttons/WHITE8X8",
        edgeFile = "Interface/Buttons/WHITE8X8",
        edgeSize = 1,
    })
    frame:SetBackdropColor(0.04, 0.04, 0.06, 0.72)
    frame:SetBackdropBorderColor(0.61, 0.48, 1, 1)

    local text = frame:CreateFontString(nil, "OVERLAY")
    text:SetFont(self.db.alertFont, self.db.alertFontSize, "THICKOUTLINE")
    text:SetPoint("CENTER")
    text:SetJustifyH("CENTER")
    local color = self.db.alertColor
    text:SetTextColor(color.r, color.g, color.b)
    frame.text = text

    frame:SetScript("OnDragStart", function(self)
        if not AA.db.locked then self:StartMoving() end
    end)
    frame:SetScript("OnDragStop", function(self)
        self:StopMovingOrSizing()
        local point, _, relPoint, x, y = self:GetPoint(1)
        AA.db.alertPosition = { point or "CENTER", relPoint or "CENTER", x or 0, y or 0 }
    end)
    frame:SetScript("OnUpdate", function(self)
        if not self.alertUntil or not AA.db.locked then return end
        local left = self.alertUntil - GetTime()
        if left <= 0 then
            self.alertUntil = nil
            self:SetAlpha(1)
            self:Hide()
            AA:PlayNextAnnouncement()
        elseif left < 0.5 then
            self:SetAlpha(left / 0.5)
        end
    end)

    self.announcement = frame
    self:ApplyAnnouncementPosition()
    frame:Hide()
end

function AA:ApplyAlertAppearance()
    if not self.announcement or not self.db then return end
    local color = self.db.alertColor or defaults.alertColor
    local ok = self.announcement.text:SetFont(
        self.db.alertFont or defaults.alertFont,
        self.db.alertFontSize or defaults.alertFontSize,
        "THICKOUTLINE"
    )
    if not ok then
        self.db.alertFont = defaults.alertFont
        self.announcement.text:SetFont(defaults.alertFont, self.db.alertFontSize or defaults.alertFontSize, "THICKOUTLINE")
    end
    self.announcement.text:SetTextColor(color.r or 0, color.g or 1, color.b or 0)
end

function AA:PlayAlertSound()
    local selected = self.db and self.db.alertSound or "none"
    if selected == "none" then return end
    for _, sound in ipairs(self.ALERT_SOUNDS) do
        if sound.key == selected and sound.id then
            pcall(PlaySound, sound.id, "Master")
            return
        end
    end
end

function AA:ApplyAnnouncementPosition()
    if not self.announcement then return end
    local pos = self.db.alertPosition or defaults.alertPosition
    self.announcement:ClearAllPoints()
    self.announcement:SetPoint(pos[1], UIParent, pos[2], pos[3], pos[4])
end

function AA:ShowAnnouncement(message, immediate, chatAlreadyPrinted)
    if not self.db.enabled or not message then return end
    if self.db.printChatAlerts and not chatAlreadyPrinted then
        print("|cff9b7cffAsylumAlerts:|r " .. message)
    end
    if not self.db.showAnnouncements then return end
    self:CreateAnnouncementFrame()
    if self.announcement.alertUntil and not immediate then
        self.announcementQueue[#self.announcementQueue + 1] = message
        return
    end
    self.announcement.text:SetText(message)
    self:ApplyAlertAppearance()
    self.announcement:SetBackdropColor(0, 0, 0, 0)
    self.announcement:SetBackdropBorderColor(0, 0, 0, 0)
    self.announcement:SetAlpha(1)
    self.announcement.alertUntil = GetTime() + (self.db.alertDuration or 3)
    self.announcement:Show()
    self:PlayAlertSound()
end

function AA:PlayNextAnnouncement()
    if #self.announcementQueue == 0 then return end
    local message = table.remove(self.announcementQueue, 1)
    self:ShowAnnouncement(message, true, true)
end

function AA:ShowPositionPreviews()
    if not self.announcement then return end
    self.announcement.alertUntil = nil
    wipe(self.announcementQueue)
    self.announcement.text:SetText("Ready alert - drag to move")
    self.announcement:SetBackdropColor(0.04, 0.04, 0.06, 0.72)
    self.announcement:SetBackdropBorderColor(0.61, 0.48, 1, 1)
    self.announcement:SetAlpha(1)
    self.announcement:EnableMouse(true)
    self.announcement:Show()
end

function AA:ApplyAnchorPosition()
    if not self.anchor then return end
    local pos = self.db.position or defaults.position
    self.anchor:ClearAllPoints()
    self.anchor:SetPoint(pos[1], UIParent, pos[2], pos[3], pos[4])
end

function AA:ResetPosition()
    self.db.position = { "CENTER", "CENTER", 0, -140 }
    self.db.alertPosition = { "CENTER", "CENTER", 0, 220 }
    self:ApplyAnchorPosition()
    self:ApplyAnnouncementPosition()
    self:LayoutBars()
end

function AA:SetLocked(locked, initializing)
    self.db.locked = locked and true or false
    if not self.anchor then return end
    self.anchor:EnableMouse(not self.db.locked)
    self.anchor:SetShown(not self.db.locked)
    if self.announcement then
        self.announcement:EnableMouse(not self.db.locked)
        if self.db.locked then
            self.announcement.alertUntil = nil
            wipe(self.announcementQueue)
            self.announcement:SetAlpha(1)
            self.announcement:Hide()
        elseif self.db.showAnnouncements then
            self:ShowPositionPreviews()
        else
            self.announcement:Hide()
        end
    end
    if not initializing then self:Refresh() end
    if self.UpdateConfig then self:UpdateConfig() end
end

function AA:ToggleLocked()
    self:SetLocked(not self.db.locked)
end

function AA:CreateBar(index)
    local bar = CreateFrame("StatusBar", nil, UIParent, "BackdropTemplate")
    bar:SetStatusBarTexture("Interface/TargetingFrame/UI-StatusBar")
    bar:SetMinMaxValues(0, 1)
    bar:SetFrameStrata("MEDIUM")
    bar:SetBackdrop({
        bgFile = "Interface/Buttons/WHITE8X8",
        edgeFile = "Interface/Buttons/WHITE8X8",
        edgeSize = 1,
    })
    bar:SetBackdropColor(0.03, 0.03, 0.04, 0.88)
    bar:SetBackdropBorderColor(0, 0, 0, 1)

    local background = bar:CreateTexture(nil, "BACKGROUND")
    background:SetAllPoints()
    background:SetColorTexture(0.07, 0.07, 0.08, 0.9)

    -- Keep the icon above the StatusBar's internally-created fill texture.
    -- On Forever the fill can otherwise be rebuilt after /reload and cover an
    -- ARTWORK-layer icon even though the texture itself resolved correctly.
    local icon = bar:CreateTexture(nil, "OVERLAY", nil, 7)
    icon:SetPoint("TOPLEFT", bar, "TOPLEFT", 1, -1)
    icon:SetPoint("BOTTOMLEFT", bar, "BOTTOMLEFT", 1, 1)
    icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
    bar.icon = icon

    local name = bar:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    name:SetJustifyH("LEFT")
    name:SetPoint("LEFT", icon, "RIGHT", 5, 0)
    name:SetPoint("RIGHT", bar, "RIGHT", -48, 0)
    bar.nameText = name

    local time = bar:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    time:SetJustifyH("RIGHT")
    time:SetPoint("RIGHT", bar, "RIGHT", -5, 0)
    bar.timeText = time
    bar.index = index
    bar:Hide()
    self.bars[index] = bar
    return bar
end

function AA:LayoutBars()
    if not self.anchor then return end
    local previous
    for _, bar in ipairs(self.bars) do
        bar:SetSize(self.db.width, self.db.height)
        bar:ClearAllPoints()
        if previous then
            if self.db.growUp then
                bar:SetPoint("BOTTOM", previous, "TOP", 0, self.db.spacing)
            else
                bar:SetPoint("TOP", previous, "BOTTOM", 0, -self.db.spacing)
            end
        elseif self.db.growUp then
            bar:SetPoint("BOTTOM", self.anchor, "TOP", 0, self.db.spacing)
        else
            bar:SetPoint("TOP", self.anchor, "BOTTOM", 0, -self.db.spacing)
        end
        bar.icon:SetWidth(math.max(1, self.db.height - 2))
        previous = bar
    end
end

function AA:CollectAuras(found)
    if not (self.db.showFlasks or self.db.showPersonal or self.db.showExternalBuffs
        or self.db.showTrinkets or self.db.showWeapon)
    then
        return true
    end
    if not C_UnitAuras then return false end

    local getter = C_UnitAuras.GetBuffDataByIndex
    local useGeneric = false
    if not getter then
        getter = C_UnitAuras.GetAuraDataByIndex
        useGeneric = true
    end
    if not getter then return false end

    local now = GetTime()
    local completed = true
    for index = 1, 80 do
        local ok, aura
        if useGeneric then
            ok, aura = pcall(getter, "player", index, "HELPFUL")
        else
            ok, aura = pcall(getter, "player", index)
        end
        if not ok then completed = false; break end
        if not aura then break end

        local name = SafeText(AuraValue(aura, "name"))
        local spellID = SafeNumber(AuraValue(aura, "spellId"))
        local duration = SafeNumber(AuraValue(aura, "duration"))
        local expires = SafeNumber(AuraValue(aura, "expirationTime"))
        local isOwn = IsPlayerAura(aura, spellID)
        local lowerName = name and name:lower()
        local isWeaponAura = lowerName and (
            lowerName:find("firestone", 1, true)
            or lowerName:find("spellstone", 1, true)
        )
        local isFlask = name and IsLongConsumable(name, duration or 0)
        local isSelfConsumable = name and IsSelfAppliedConsumable(name)
        if isWeaponAura or isFlask or isSelfConsumable then isOwn = true end
        if InCombatLockdown() and (not name or not duration or not expires or isOwn == nil) then
            completed = false
        end
        local casterAllowed = isOwn == true or (self.db.showExternalBuffs and isOwn == false)
        if name and duration and expires and duration > 0 and expires > now and casterAllowed then
            local isExternal = isOwn == false
            local keyID = spellID or index
            local auraKey = "aura:" .. tostring(keyID)
            local previousEntry = self.active[auraKey]
            local auraAge = math.max(0, duration - (expires - now))
            local castAt = spellID and self.playerRequestedSpells[spellID]
            local recentlyCast = type(castAt) == "number" and now - castAt <= 6
            local knownPotion = spellID and self.potionState.knownBySpell[spellID]
            local potionAura = knownPotion and not knownPotion.excluded
            if not potionAura and self.potionState.name and name then
                potionAura = self.potionState.onCooldown and name == self.potionState.name
            end
            local trinketAura = self.trinketAuraKeys[auraKey]
                or IsEquippedTrinketAura(spellID, name)
                or (isOwn == true and not isWeaponAura and not isFlask
                    and GetTime() <= (self.trinketActivationUntil or 0)
                    and (not previousEntry or auraAge <= 6))
            if trinketAura then self.trinketAuraKeys[auraKey] = true end
            local include
            if trinketAura then
                -- Trinket proc auras are useful duration bars, but they are not
                -- maintenance buffs and must never request a recast on expiry.
                include = self.db.showTrinkets
            elseif isWeaponAura then
                include = self.db.showWeapon
            else
                include = (not isExternal and isFlask and self.db.showFlasks)
                    or (not isExternal and not isFlask and self.db.showPersonal and duration >= self.db.minPersonalDuration)
                    or (isExternal and self.db.showExternalBuffs and duration >= self.db.minPersonalDuration)
            end
            if include then
                local kind = isWeaponAura and "weapon"
                    or (isExternal and "external" or (isFlask and "flask" or "personal"))
                local maintenanceAlert = (previousEntry and previousEntry.maintenanceAlert)
                    or recentlyCast or isFlask or isSelfConsumable
                local icon = ResolveAuraTexture(aura, spellID, auraKey)
                found[auraKey] = {
                    key = auraKey,
                    kind = kind,
                    name = NormalizeMaintenanceName(name),
                    icon = icon,
                    duration = duration,
                    expires = expires,
                    firstSeen = (previousEntry and previousEntry.firstSeen) or now,
                    maintenanceAlert = maintenanceAlert and true or nil,
                    suppressExpiryAlert = (trinketAura or potionAura
                        or (IS_RETAIL and kind == "personal" and not maintenanceAlert)) and true or nil,
                }
            end
        end
    end
    return completed
end

local scanTooltip
local function ExpectedWeaponDuration(name)
    local lower = type(name) == "string" and name:lower() or ""
    if lower:find("firestone", 1, true) or lower:find("spellstone", 1, true) then
        return 2 * 60 * 60
    end
    if lower:find("oil", 1, true) then return 30 * 60 end
end

local function EpochNow()
    if GetServerTime then
        local ok, value = pcall(GetServerTime)
        if ok and type(value) == "number" and value > 0 then return value end
    end
    if time then
        local ok, value = pcall(time)
        if ok and type(value) == "number" and value > 0 then return value end
    end
end

local function FindMatchingWeaponAura(found, name)
    if type(name) ~= "string" then return nil end
    local wanted = NormalizeMaintenanceName(name):lower()
    local wantedFamily = wanted:find("firestone", 1, true) and "firestone"
        or (wanted:find("spellstone", 1, true) and "spellstone")
    for _, entry in pairs(found) do
        if entry.kind == "weapon" and type(entry.name) == "string" then
            local candidate = NormalizeMaintenanceName(entry.name):lower()
            if candidate == wanted
                or (wantedFamily and candidate:find(wantedFamily, 1, true))
            then
                return entry
            end
        end
    end
end

local function ScanWeaponEnchants(slot)
    local enchants, seen = {}, {}
    local function AddLine(text)
        if type(text) ~= "string" or text == "" then return end
        local name, timeText = text:match("^(.-)%s*%((.-)%)")
        local seconds
        local hasMinutes = false
        local hasSeconds = false
        local hasLongUnit = false
        if name and timeText then
            for amount, unit in timeText:gmatch("(%d+)%s*(%a+)") do
                unit = unit:lower()
                if unit:find("^hour") or unit:find("^hr") or unit == "h" then
                    seconds = (seconds or 0) + (tonumber(amount) * 3600)
                    hasLongUnit = true
                elseif unit:find("^min") or unit == "m" then
                    seconds = (seconds or 0) + (tonumber(amount) * 60)
                    hasMinutes = true
                    hasLongUnit = true
                elseif unit:find("^sec") or unit == "s" then
                    seconds = (seconds or 0) + tonumber(amount)
                    hasSeconds = true
                end
            end
        end
        if not name or not seconds or seconds <= 0 then
            -- Forever can list stacked Firestone/Spellstone effects without a
            -- parenthesized timer. Keep the name; the weapon API supplies time.
            local stone, rank = text:match("([Ff]irestone)%s*(%d*)")
            if not stone then stone, rank = text:match("([Ss]pellstone)%s*(%d*)") end
            if not stone then return end
            name = rank and rank ~= "" and (stone .. " " .. rank) or stone
            name = NormalizeMaintenanceName(name)
            local key = name:lower()
            if not seen[key] then
                enchants[#enchants + 1] = { name = name, isStone = true }
                seen[key] = #enchants
            end
            return
        end
        name = strtrim(name)
        name = NormalizeMaintenanceName(name)
        local key = name:lower()
        local isStone = key:find("firestone", 1, true) or key:find("spellstone", 1, true)
        -- Seconds-only tooltip lines are often unrelated short procs. Accept
        -- them only for the explicitly tracked stones; compound durations such
        -- as "2 min 40 sec" remain valid for every recognized enchant line.
        if hasSeconds and not hasLongUnit and not isStone then return end
        if seconds and name ~= "" then
            local existing = seen[key] and enchants[seen[key]]
            if existing then
                -- Some Forever tooltips contain both a descriptive stone line
                -- and the live enchant line. The shorter value is the remaining
                -- enchant time; the longer one is the effect's descriptive text.
                if not existing.left or seconds < existing.left then
                    existing.left = seconds
                    existing.hasMinutes = hasMinutes
                    existing.hasSeconds = hasSeconds
                elseif seconds == existing.left and hasMinutes then
                    existing.hasMinutes = true
                end
                if seconds == existing.left and hasSeconds then existing.hasSeconds = true end
                if isStone then existing.isStone = true end
            else
                enchants[#enchants + 1] = {
                    name = name,
                    left = seconds,
                    isStone = isStone and true or nil,
                    hasMinutes = hasMinutes,
                    hasSeconds = hasSeconds,
                }
                seen[key] = #enchants
            end
        end
    end

    if C_TooltipInfo and C_TooltipInfo.GetInventoryItem then
        local ok, data = pcall(C_TooltipInfo.GetInventoryItem, "player", slot)
        if ok and data and data.lines then
            for _, line in ipairs(data.lines) do
                if TooltipUtil and TooltipUtil.SurfaceArgs then pcall(TooltipUtil.SurfaceArgs, line) end
                AddLine(line.leftText)
            end
        end
    end

    if #enchants > 0 then return enchants end
    if not scanTooltip then
        scanTooltip = CreateFrame("GameTooltip", "AsylumAlertsScanTooltip", nil, "GameTooltipTemplate")
        scanTooltip:SetOwner(UIParent, "ANCHOR_NONE")
    end
    scanTooltip:ClearLines()
    local ok = pcall(scanTooltip.SetInventoryItem, scanTooltip, "player", slot)
    if not ok then return enchants end
    for line = 2, scanTooltip:NumLines() do
        local region = _G["AsylumAlertsScanTooltipTextLeft" .. line]
        AddLine(region and region:GetText())
    end
    return enchants
end

function AA:CollectWeaponEnchants(found)
    if not self.db.showWeapon then return true end
    if not GetWeaponEnchantInfo then return false end
    if InCombatLockdown() then return false end
    local ok, hasMH, mhMS, _, _, hasOH, ohMS = pcall(GetWeaponEnchantInfo)
    if not ok then return false end
    local now = GetTime()
    local complete = true
    local slots = {
        { key = "weapon:main", slot = 16, has = hasMH, ms = mhMS, fallback = "Main-hand weapon buff" },
        { key = "weapon:off", slot = 17, has = hasOH, ms = ohMS, fallback = "Off-hand weapon buff" },
    }
    for _, info in ipairs(slots) do
        local milliseconds = SafeNumber(info.ms)
        local hasEnchant = SafeTrue(info.has)
        local scanned = ScanWeaponEnchants(info.slot)
        local weaponItemID = GetInventoryItemID("player", info.slot)
        local icon = ResolveItemTexture(weaponItemID, info.slot) or 135249
        local slotCache = self.db.weaponNames[info.key]
        if type(slotCache) ~= "table" then slotCache = {} end
        if type(slotCache.stones) ~= "table" then slotCache.stones = {} end
        self.db.weaponNames[info.key] = slotCache

        -- Forever exposes one exact millisecond timer per weapon slot even when
        -- several enchants are stacked. Match it to the nearest non-stone tooltip
        -- duration (normally an oil or poison); stones keep their own tracking.
        local apiSeconds = hasEnchant and milliseconds and milliseconds > 0 and (milliseconds / 1000) or nil
        local apiKey, apiName
        if apiSeconds and #scanned > 0 then
            local bestDifference
            for _, enchant in ipairs(scanned) do
                if not enchant.isStone and SafeNumber(enchant.left) then
                    local difference = math.abs(enchant.left - apiSeconds)
                    if not bestDifference or difference < bestDifference then
                        bestDifference = difference
                        apiKey = info.key .. ":" .. enchant.name:lower()
                        apiName = enchant.name
                    end
                end
            end
            -- Whole-minute tooltip values can differ from the exact API by up
            -- to about a minute. Reject distant matches such as a two-hour stone.
            if bestDifference and bestDifference > 120 then
                apiKey, apiName = nil, nil
            end
        end
        if apiKey then
            slotCache.apiKey = apiKey
            slotCache.apiName = apiName
        elseif apiSeconds then
            apiKey, apiName = slotCache.apiKey, slotCache.apiName
        end

        if #scanned > 0 then
            for _, enchant in ipairs(scanned) do
                -- Firestone/Spellstone can also be exposed as a player aura. Its
                -- expiration is exact, unlike the descriptive weapon tooltip.
                local auraEntry = enchant.isStone and FindMatchingWeaponAura(found, enchant.name)
                local key = (auraEntry and auraEntry.key) or (info.key .. ":" .. enchant.name:lower())
                local old = self.active[key]
                local coarse = SafeNumber(enchant.left)
                local expectedDuration = ExpectedWeaponDuration(enchant.name)
                local isApiEnchant = not enchant.isStone and apiKey == key
                local epochNow = EpochNow()
                local stoneCache
                local cachedExpiry
                if enchant.isStone then
                    local saved = slotCache.stones[key]
                    if type(saved) == "table" then
                        stoneCache = saved
                    else
                        stoneCache = { name = type(saved) == "string" and saved or enchant.name }
                    end
                    stoneCache.name = enchant.name
                    slotCache.stones[key] = stoneCache
                    local expiresAt = SafeNumber(stoneCache.expiresAt)
                    if epochNow and expiresAt then
                        local remaining = expiresAt - epochNow
                        if remaining > 0 and (not expectedDuration or remaining <= expectedDuration + 65) then
                            cachedExpiry = now + remaining
                        end
                    end
                end
                if auraEntry and auraEntry.expires then
                    coarse = math.max(0, auraEntry.expires - now)
                elseif coarse and expectedDuration then
                    coarse = math.min(coarse, expectedDuration)
                end
                -- A stacked stone's own tooltip duration is authoritative. The
                -- weapon API exposes only one slot timer, often the oil's timer.
                local precise = ((isApiEnchant or (#scanned == 1 and not enchant.isStone)
                    or (enchant.isStone and not coarse)) and apiSeconds) or nil
                local expires
                if auraEntry and auraEntry.expires then
                    expires = auraEntry.expires
                elseif isApiEnchant and precise then
                    -- Oils and API-backed poisons use the exact slot timer. The
                    -- tooltip supplies their name, not their expiration.
                    expires = now + precise
                elseif enchant.hasSeconds and coarse then
                    -- At the end of a stone duration Forever exposes seconds.
                    -- This value is exact and corrects any earlier rounded cache.
                    expires = now + coarse
                elseif enchant.hasMinutes and coarse then
                    -- Once Forever switches from the rounded "2 hours" bucket to
                    -- minutes, use it to correct a bad estimate. If the saved
                    -- value is already within the one-minute rounding window,
                    -- retain its seconds component across reloads.
                    local referenceExpiry = (old and old.expires and old.expires > now and old.expires)
                        or cachedExpiry
                    if referenceExpiry and math.abs(coarse - (referenceExpiry - now)) <= 65 then
                        expires = referenceExpiry
                    else
                        expires = now + coarse
                    end
                elseif cachedExpiry then
                    -- The tooltip reports only "2 hours" until the next whole-hour
                    -- boundary. Restore our saved countdown instead of resetting it.
                    expires = cachedExpiry
                elseif precise then
                    expires = now + precise
                elseif coarse and old and old.expires
                    and (not expectedDuration or (old.expires - now) <= expectedDuration + 65)
                    and coarse <= (old.expires - now) + (enchant.isStone and 3605 or 65)
                then
                    -- Tooltip minutes are rounded. Preserve the ticking timestamp
                    -- until the displayed minute rises enough to indicate a refresh.
                    expires = old.expires
                elseif coarse then
                    expires = now + coarse
                elseif old and old.expires and old.expires > now then
                    expires = old.expires
                end
                if expires then
                    local duration = expectedDuration or (auraEntry and auraEntry.duration)
                        or math.max(coarse or 0, precise or 0, (old and old.duration) or 0, expires - now)
                    found[key] = {
                        key = key,
                        kind = "weapon",
                        name = enchant.name,
                        icon = icon,
                        duration = duration,
                        expires = expires,
                    }
                    if stoneCache and epochNow then
                        stoneCache.expiresAt = epochNow + math.max(0, expires - now)
                        stoneCache.duration = duration
                    end
                end
                -- Remember the tooltip name and its key because some clients stop
                -- returning the enchant line shortly before the enchant expires.
                if enchant.isStone then
                    stoneCache.name = enchant.name
                elseif #scanned == 1 then
                    slotCache.name, slotCache.key = enchant.name, key
                end
            end
            -- Near expiry, Forever may remove an oil/poison tooltip line while
            -- GetWeaponEnchantInfo still reports its exact remaining time. Keep
            -- the matched entry until that API timer genuinely reaches zero.
            if apiSeconds and apiKey and not found[apiKey] then
                local oldApi = self.active[apiKey]
                local cachedDuration = SafeNumber(slotCache.apiDuration)
                    or (oldApi and oldApi.duration)
                    or ExpectedWeaponDuration(apiName)
                local plausible = cachedDuration and apiSeconds <= cachedDuration + 120
                if plausible and (oldApi or apiName) then
                    local name = (oldApi and oldApi.name) or apiName
                    local duration = ExpectedWeaponDuration(name)
                        or math.max(cachedDuration, apiSeconds)
                    found[apiKey] = {
                        key = apiKey,
                        kind = "weapon",
                        name = name,
                        icon = icon,
                        duration = duration,
                        expires = now + apiSeconds,
                    }
                end
            end
            if apiKey and found[apiKey] then
                slotCache.apiName = found[apiKey].name
                slotCache.apiDuration = found[apiKey].duration
            end
            -- If one stacked tooltip line temporarily disappears, retain its
            -- existing stone timer instead of dropping the bar immediately.
            for stoneKey in pairs(slotCache.stones) do
                local oldStone = self.active[stoneKey]
                if not found[stoneKey] and oldStone and oldStone.expires and oldStone.expires > now then
                    found[stoneKey] = oldStone
                end
            end
        elseif hasEnchant and milliseconds and milliseconds > 0 then
            local seconds = milliseconds / 1000
            local cached = slotCache
            local preservedKey = cached and cached.key or info.key
            local old = self.active[preservedKey]
            if not old then
                -- Compatibility with timers created before the persistent cache.
                local prefix = info.key .. ":"
                for activeKey, activeEntry in pairs(self.active) do
                    if activeKey:sub(1, #prefix) == prefix then
                        preservedKey, old = activeKey, activeEntry
                        break
                    end
                end
            end
            local preservedName = (old and old.name) or (cached and cached.name) or info.fallback
            local expectedDuration = ExpectedWeaponDuration(preservedName)
            cached.name, cached.key = preservedName, preservedKey
            found[preservedKey] = {
                key = preservedKey,
                kind = "weapon",
                name = preservedName,
                icon = icon,
                duration = expectedDuration or math.max(seconds, (old and old.duration) or seconds),
                expires = now + seconds,
            }
            -- A slot may carry a stone alongside another temporary enchant on
            -- Forever. Restore every remembered stone instead of replacing it.
            for stoneKey, stoneSaved in pairs(cached.stones) do
                if stoneKey ~= preservedKey then
                    local oldStone = self.active[stoneKey]
                    local stoneName = type(stoneSaved) == "table" and stoneSaved.name or stoneSaved
                    local stoneDuration = ExpectedWeaponDuration(stoneName) or seconds
                    local stoneExpires = oldStone and oldStone.expires
                    local epochNow = EpochNow()
                    local expiresAt = type(stoneSaved) == "table" and SafeNumber(stoneSaved.expiresAt)
                    if (not stoneExpires or stoneExpires <= now) and epochNow and expiresAt and expiresAt > epochNow then
                        stoneExpires = now + (expiresAt - epochNow)
                    end
                    if stoneName and stoneExpires and stoneExpires > now then
                        found[stoneKey] = {
                            key = stoneKey,
                            kind = "weapon",
                            name = stoneName,
                            icon = icon,
                            duration = stoneDuration,
                            expires = stoneExpires,
                        }
                    end
                end
            end
        elseif hasEnchant and not milliseconds then
            complete = false
        else
            self.db.weaponNames[info.key] = nil
        end
    end
    return complete
end

local function GetBagSlotCount(bag)
    local getter = C_Container and C_Container.GetContainerNumSlots or GetContainerNumSlots
    if not getter then return 0 end
    local ok, count = pcall(getter, bag)
    count = ok and SafeNumber(count) or nil
    return count and math.max(0, math.floor(count)) or 0
end

local function GetBagItemID(bag, slot)
    local getter = C_Container and C_Container.GetContainerItemID or GetContainerItemID
    if not getter then return nil end
    local ok, itemID = pcall(getter, bag, slot)
    return ok and SafeNumber(itemID) or nil
end

local function GetBagItemCooldown(bag, slot)
    local getter = C_Container and C_Container.GetContainerItemCooldown or GetContainerItemCooldown
    if not getter then return nil end
    local ok, startTime, duration, enabled = pcall(getter, bag, slot)
    if not ok then return nil end
    return SafeNumber(startTime), SafeNumber(duration), enabled
end

local function GetCooldownForItem(itemID)
    if not itemID then return nil end
    if C_Item and C_Item.GetItemCooldown then
        local ok, startTime, duration, enabled = pcall(C_Item.GetItemCooldown, itemID)
        if ok then
            if type(startTime) == "table" then
                local info = startTime
                return SafeNumber(AuraValue(info, "startTime")),
                    SafeNumber(AuraValue(info, "duration")),
                    AuraValue(info, "isEnabled")
            end
            return SafeNumber(startTime), SafeNumber(duration), enabled
        end
    end
    if GetItemCooldown then
        local ok, startTime, duration, enabled = pcall(GetItemCooldown, itemID)
        if ok then return SafeNumber(startTime), SafeNumber(duration), enabled end
    end
end

local function IsPotionItem(itemID)
    local getter = C_Item and C_Item.GetItemInfoInstant or GetItemInfoInstant
    if not itemID or not getter then return false end
    local ok, _, _, _, _, _, classID, subclassID = pcall(getter, itemID)
    if not ok then return false end
    local consumableClass = Enum and Enum.ItemClass and Enum.ItemClass.Consumable or 0
    local potionSubclass = Enum and Enum.ItemConsumableSubclass and Enum.ItemConsumableSubclass.Potion or 1
    return classID == consumableClass and subclassID == potionSubclass
end

local function IsExcludedPotion(name)
    if type(name) ~= "string" then return true end
    local lower = name:lower()
    return lower:find("healing", 1, true)
        or lower:find("health", 1, true)
        or lower:find("rejuvenation", 1, true)
        or lower:find("swiftness", 1, true)
end

function AA:CachePotionItems()
    local state = self.potionState
    state.slots = {}
    local lastBag = NUM_BAG_SLOTS or 4
    for bag = 0, lastBag do
        for slot = 1, GetBagSlotCount(bag) do
            local itemID = GetBagItemID(bag, slot)
            if itemID and IsPotionItem(itemID) then
                local name = ResolveItemName(itemID)
                local spellGetter = C_Item and C_Item.GetItemSpell or GetItemSpell
                local ok, _, spellID
                if spellGetter then ok, _, spellID = pcall(spellGetter, itemID) end
                spellID = ok and SafeNumber(spellID) or nil
                local potion = {
                    itemID = itemID,
                    spellID = spellID,
                    name = name,
                    icon = ResolveItemTexture(itemID) or 134712,
                    bag = bag,
                    slot = slot,
                    excluded = IsExcludedPotion(name),
                }
                state.slots[#state.slots + 1] = potion
                -- Retain previously seen entries so using the final item in a
                -- stack can still be matched after it disappears from the bag.
                if spellID and name then state.knownBySpell[spellID] = potion end
            end
        end
    end
end

function AA:OnPossiblePotionUse(spellID)
    if not self.db.showPotions or not spellID then return end
    local potion = self.potionState.knownBySpell[spellID]
    if not potion or potion.excluded then return end
    self.potionState.pending = {
        itemID = potion.itemID,
        spellID = potion.spellID,
        name = potion.name,
        icon = potion.icon,
        usedAt = GetTime(),
    }
end

function AA:CollectPotions(found)
    local state = self.potionState
    if not self.db.showPotions then
        state.pending = nil
        state.onCooldown = false
        state.armed = false
        state.expires = nil
        return
    end

    local now = GetTime()
    local pending = state.pending
    if pending and now - pending.usedAt <= 8 then
        local startTime, duration = GetCooldownForItem(pending.itemID)
        if not (startTime and duration and duration > 1.5 and startTime > 0) then
            for _, potion in ipairs(state.slots) do
                if potion.itemID == pending.itemID then
                    startTime, duration = GetBagItemCooldown(potion.bag, potion.slot)
                    if startTime and duration and duration > 1.5 and startTime > 0 then break end
                end
            end
        end
        if startTime and duration and duration > 1.5 and startTime > 0
            and startTime + duration > now + 0.05
            and now - startTime <= 8
        then
            state.itemID = pending.itemID
            state.spellID = pending.spellID
            state.name = pending.name or "Potion"
            state.icon = pending.icon or 134712
            state.duration = duration
            state.expires = startTime + duration
            state.onCooldown = true
            state.armed = true
            state.pending = nil
        end
    elseif pending then
        state.pending = nil
    end

    if state.onCooldown and state.expires and state.expires <= now then
        if state.armed and now >= (self.suppressAnnouncementsUntil or 0) then
            self:ShowAnnouncement((state.name or "Potion") .. " is ready!")
        end
        state.onCooldown = false
        state.armed = false
        state.expires = nil
        state.duration = nil
    end

    if state.onCooldown and state.expires and state.expires > now then
        found["potion:shared"] = {
            key = "potion:shared",
            kind = "potion",
            name = state.name or "Potion",
            icon = state.icon or 134712,
            duration = state.duration or math.max(1, state.expires - now),
            expires = state.expires,
        }
    end
end

local function GetEquippedCooldown(slot, itemID)
    if GetInventoryItemCooldown then
        local ok, startTime, duration, enabled = pcall(GetInventoryItemCooldown, "player", slot)
        if ok then
            local safeStart, safeDuration = SafeNumber(startTime), SafeNumber(duration)
            if safeStart ~= nil and safeDuration ~= nil then return safeStart, safeDuration, enabled end
        end
    end
    local getter = C_Container and C_Container.GetItemCooldown or GetItemCooldown
    if getter and itemID then
        local ok, startTime, duration, enabled = pcall(getter, itemID)
        if ok then return SafeNumber(startTime), SafeNumber(duration), enabled end
    end
end

function AA:GetTrinketName(index)
    local slot = index == 2 and 14 or 13
    local itemID = GetInventoryItemID("player", slot)
    return ResolveItemName(itemID, "Trinket " .. index)
end

function AA:CollectTrinkets(found)
    if not self.db.showTrinkets then return end
    local now = GetTime()
    for index, slot in ipairs({ 13, 14 }) do
        local state = self.trinketState[slot] or {}
        self.trinketState[slot] = state
        local itemID = GetInventoryItemID("player", slot)
        if state.itemID ~= itemID then
            state.itemID = itemID
            state.itemName = nil
            state.onCooldown = nil
            state.armed = false
            state.expires = nil
            state.duration = nil
            state.initialized = false
        end
        if itemID then
            state.itemName = ResolveItemName(itemID, state.itemName or ("Trinket " .. index))
            local startTime, duration = GetEquippedCooldown(slot, itemID)
            local readable = startTime ~= nil and duration ~= nil
            local onCooldown = readable and duration > 1.5 and startTime > 0 and (startTime + duration) > now + 0.05
            if onCooldown then
                if state.onCooldown ~= true then
                    local recentStart = (now - startTime) <= 6
                    if state.initialized or recentStart then
                        self.trinketActivationUntil = math.max(self.trinketActivationUntil or 0, now + 6)
                        -- UNIT_AURA can arrive just before the item cooldown event.
                        -- Retroactively tag any personal aura first seen moments ago.
                        for key, entry in pairs(self.active) do
                            if entry.kind == "personal" and entry.firstSeen
                                and (now - entry.firstSeen) <= 6
                            then
                                self.trinketAuraKeys[key] = true
                            end
                        end
                    end
                end
                state.onCooldown = true
                state.armed = true
                state.expires = startTime + duration
                state.duration = duration
            elseif readable then
                if state.onCooldown == true and state.armed and now >= (self.suppressAnnouncementsUntil or 0) then
                    self:ShowAnnouncement(state.itemName .. " is ready!")
                end
                state.onCooldown = false
                state.armed = false
                state.expires = nil
                state.duration = nil
            elseif state.onCooldown and state.expires and state.expires <= now then
                if state.armed and now >= (self.suppressAnnouncementsUntil or 0) then
                    self:ShowAnnouncement(state.itemName .. " is ready!")
                end
                state.onCooldown = false
                state.armed = false
                state.expires = nil
            end

            if state.onCooldown and state.expires and state.expires > now then
                found["trinket:" .. slot] = {
                    key = "trinket:" .. slot,
                    kind = "trinket",
                    name = state.itemName,
                    icon = ResolveItemTexture(itemID, slot) or 134400,
                    duration = state.duration or math.max(1, state.expires - now),
                    expires = state.expires,
                }
            end
            state.initialized = true
        end
    end
end

local SOULSTONE_IDS = { 20707, 20762, 20763, 20764, 20765, 27239, 47883 }

local function FindKnownSoulstone()
    for _, spellID in ipairs(SOULSTONE_IDS) do
        local ok, known = pcall(function()
            return (IsPlayerSpell and IsPlayerSpell(spellID))
                or (IsSpellKnown and IsSpellKnown(spellID))
                or (IsSpellKnownOrOverridesKnown and IsSpellKnownOrOverridesKnown(spellID))
        end)
        if ok and known then return spellID end
    end
end

function AA:CollectSoulstone(found)
    if not self.db.showSoulstone or not C_Spell or not C_Spell.GetSpellCooldown then return end
    local state = self.soulstoneState
    local spellID = FindKnownSoulstone()
    if not spellID then
        state.spellID = nil
        state.onCooldown = nil
        return
    end
    if state.spellID ~= spellID then
        state.spellID = spellID
        state.onCooldown = nil
        state.armed = false
        state.expires = nil
    end

    local activeID = spellID
    if C_Spell.GetOverrideSpell then
        local ok, overrideID = pcall(C_Spell.GetOverrideSpell, spellID)
        if ok and type(overrideID) == "number" and overrideID > 0 then activeID = overrideID end
    end
    local ok, info = pcall(C_Spell.GetSpellCooldown, activeID)
    if not ok or not info then return end
    local isActive = SafeTrue(AuraValue(info, "isActive"))
    local startTime = SafeNumber(AuraValue(info, "startTime"))
    local duration = SafeNumber(AuraValue(info, "duration"))
    local now = GetTime()

    -- Ignore the global cooldown. If timing is hidden in combat, only trust the
    -- active flag after a Soulstone cast (or an already established real CD).
    if duration and duration <= 1.5 then
        isActive = false
    elseif not duration and not state.armed and state.onCooldown ~= true then
        return
    end
    if not isActive and state.castAt and (now - state.castAt) < 1 then
        isActive = true
    end

    if isActive then
        state.onCooldown = true
        state.armed = true
        if startTime and duration and duration > 1.5 then
            state.expires = startTime + duration
            state.duration = duration
        end
    elseif state.onCooldown == true then
        if state.armed and now >= (self.suppressAnnouncementsUntil or 0) then
            self:ShowAnnouncement("Soulstone is ready!")
        end
        state.onCooldown = false
        state.armed = false
        state.expires = nil
    end

    if state.onCooldown and state.expires and state.expires > now then
        found["spell:soulstone"] = {
            key = "spell:soulstone",
            kind = "soulstone",
            name = "Soulstone",
            icon = ResolveSpellTexture(activeID) or 136210,
            duration = state.duration or math.max(1, state.expires - now),
            expires = state.expires,
        }
    end
end

function AA:OnPossibleSoulstoneCast(spellID)
    if not self.db.showSoulstone or not spellID then return end
    local knownID = FindKnownSoulstone()
    if not knownID then return end
    local matches = spellID == knownID
    if not matches and C_Spell and C_Spell.GetSpellName then
        local castName = C_Spell.GetSpellName(spellID)
        local knownName = C_Spell.GetSpellName(knownID)
        matches = castName and knownName and castName == knownName
    end
    if matches then
        self.soulstoneState.spellID = knownID
        self.soulstoneState.onCooldown = true
        self.soulstoneState.armed = true
        self.soulstoneState.castAt = GetTime()
        self.soulstoneState.duration = self.soulstoneState.duration or 600
        self.soulstoneState.expires = GetTime() + self.soulstoneState.duration
        C_Timer.After(0.1, function() AA:Refresh() end)
    end
end

function AA:AnnounceEndedEntries(previous, current, auraScanComplete, weaponScanComplete)
    if not (self.db.showAnnouncements or self.db.printChatAlerts)
        or GetTime() < (self.suppressAnnouncementsUntil or 0)
    then
        return
    end
    local now = GetTime()
    for key, entry in pairs(previous) do
        if not current[key] and not entry.preview
            and not entry.suppressExpiryAlert and not self.trinketAuraKeys[key]
        then
            local finished = entry.expires and entry.expires <= now + 0.25
            -- Retail can briefly return an empty-but-successful aura scan while
            -- zoning via a hearthstone or portal. Only its real timer is safe
            -- evidence of expiry; Forever retains early-removal detection.
            local auraEnded = finished or (not IS_RETAIL and auraScanComplete)
            if entry.kind == "flask" and self.db.showFlasks and auraEnded then
                self:ShowAnnouncement(entry.name .. " has expired - refresh your flask!")
            elseif entry.kind == "personal" and self.db.showPersonal and auraEnded then
                self:ShowAnnouncement(entry.name .. " has expired - recast it!")
            elseif entry.kind == "external" and self.db.showExternalBuffs and auraEnded then
                self:ShowAnnouncement(entry.name .. " has expired!")
            elseif entry.kind == "weapon" and self.db.showWeapon and (finished or weaponScanComplete) then
                self:ShowAnnouncement(entry.name .. " has expired - reapply it!")
            end
        end
    end
end

function AA:Refresh()
    if not self.initialized or not self.db.enabled then
        for _, bar in ipairs(self.bars) do bar:Hide() end
        return
    end

    local previous = self.active
    local found = {}
    -- Detect a newly activated trinket before scanning auras. This lets the aura
    -- pass suppress the trinket's temporary proc buff from maintenance warnings.
    self:CollectTrinkets(found)
    self:CollectPotions(found)
    local auraScanComplete = self:CollectAuras(found)
    local weaponScanComplete = self:CollectWeaponEnchants(found)
    self:CollectSoulstone(found)

    -- During combat, modern clients can hide aura values. Keep the last safe aura
    -- snapshot until it expires instead of making every bar disappear at once.
    if not auraScanComplete then
        local now = GetTime()
        for key, entry in pairs(previous) do
            local shouldPreserve = entry.kind == "flask"
                or entry.kind == "personal"
                or (entry.kind == "external" and self.db.showExternalBuffs)
            if shouldPreserve and entry.expires > now then
                found[key] = entry
            end
        end
    end
    if not weaponScanComplete then
        local now = GetTime()
        for key, entry in pairs(previous) do
            if entry.kind == "weapon" and entry.expires > now then found[key] = entry end
        end
    end
    self:AnnounceEndedEntries(previous, found, auraScanComplete, weaponScanComplete)
    self.active = found
    self:RenderBars()
end

function AA:RenderBars()
    local list = {}
    local now = GetTime()
    for _, entry in pairs(self.active) do
        if entry.expires and entry.expires > now then list[#list + 1] = entry end
    end
    table.sort(list, function(a, b)
        local aOrder = BAR_KIND_ORDER[a.kind] or 5
        local bOrder = BAR_KIND_ORDER[b.kind] or 5
        if aOrder ~= bOrder then return aOrder < bOrder end
        if a.expires == b.expires then return a.name < b.name end
        return a.expires < b.expires
    end)

    if not self.db.locked and #list == 0 then
        list = {
            { kind = "trinket", name = self:GetTrinketName(1), icon = ResolveItemTexture(GetInventoryItemID("player", 13), 13) or 132142, duration = 120, expires = now + 94, preview = true },
            { kind = "potion", name = "Potion cooldown", icon = 134712, duration = 120, expires = now + 66, preview = true },
            { kind = "soulstone", name = "Soulstone", icon = 136210, duration = 600, expires = now + 420, preview = true },
            { kind = "weapon", name = "Weapon buff / oil", icon = 135249, duration = 3600, expires = now + 2840, preview = true },
            { kind = "flask", name = "Flask / phial", icon = 134719, duration = 3600, expires = now + 1920, preview = true },
            { kind = "personal", name = "Personal buff", icon = 136116, duration = 120, expires = now + 78, preview = true },
            { kind = "external", name = "External class buff", icon = 135987, duration = 3600, expires = now + 2700, preview = true },
        }
    end

    local shown = math.min(#list, self.db.maxBars)
    for index = 1, shown do
        local bar = self.bars[index] or self:CreateBar(index)
        local entry = list[index]
        bar.entry = entry
        bar.icon:SetDrawLayer("OVERLAY", 7)
        bar.icon:SetShown(self.db.showIcons)
        bar.nameText:ClearAllPoints()
        if self.db.showIcons then
            bar.nameText:SetPoint("LEFT", bar.icon, "RIGHT", 5, 0)
        else
            bar.nameText:SetPoint("LEFT", bar, "LEFT", 5, 0)
        end
        bar.nameText:SetPoint("RIGHT", bar, "RIGHT", -48, 0)
        bar.icon:SetTexture(SafeTexture(entry.icon) or 134400)
        bar.nameText:SetText(entry.name)
        local color = self.db.colors[entry.kind] or self.db.colors.personal
        bar:SetStatusBarColor(color[1], color[2], color[3], 0.92)
        bar:SetMinMaxValues(0, math.max(0.1, entry.duration or 1))
        bar:SetValue(math.max(0, entry.expires - now))
        bar.timeText:SetText(FormatTime(entry.expires - now))
        bar:Show()
    end
    for index = shown + 1, #self.bars do
        self.bars[index].entry = nil
        self.bars[index]:Hide()
    end
    self:LayoutBars()
end

function AA:UpdateTimers()
    local now = GetTime()
    local expired
    for _, bar in ipairs(self.bars) do
        if bar:IsShown() and bar.entry then
            local left = bar.entry.expires - now
            if left <= 0 then
                expired = true
            else
                bar:SetValue(left)
                bar.timeText:SetText(FormatTime(left))
            end
        end
    end
    if expired then self:Refresh() end
end

local events = CreateFrame("Frame")
events:RegisterEvent("ADDON_LOADED")
events:RegisterEvent("PLAYER_LOGIN")
events:RegisterEvent("UNIT_AURA")
events:RegisterEvent("UNIT_INVENTORY_CHANGED")
events:RegisterEvent("PLAYER_EQUIPMENT_CHANGED")
events:RegisterEvent("PLAYER_ENTERING_WORLD")
events:RegisterEvent("BAG_UPDATE_DELAYED")
events:RegisterEvent("BAG_UPDATE_COOLDOWN")
events:RegisterEvent("ACTIONBAR_UPDATE_COOLDOWN")
events:RegisterEvent("SPELL_UPDATE_COOLDOWN")
events:RegisterEvent("UNIT_SPELLCAST_SENT")
events:RegisterEvent("UNIT_SPELLCAST_SUCCEEDED")

events:SetScript("OnEvent", function(_, event, ...)
    if event == "ADDON_LOADED" then
        if ... ~= addonName then return end
        AsylumAlertsDB = AsylumAlertsDB or {}
        CopyDefaults(defaults, AsylumAlertsDB)
        AA.db = AsylumAlertsDB
        events:UnregisterEvent("ADDON_LOADED")
    elseif event == "PLAYER_LOGIN" then
        AA.initialized = true
        AA.suppressAnnouncementsUntil = GetTime() + 3
        AA:CreateAnchor()
        AA:CreateAnnouncementFrame()
        AA:CreateMinimapButton()
        AA:SetLocked(AA.db.locked, true)
        AA:CachePotionItems()
        AA:Refresh()
        C_Timer.After(2, function() AA:Refresh() end)
        print("|cff9b7cffAsylumAlerts|r loaded. Type |cffffffff/aa|r for settings.")
    elseif event == "UNIT_AURA" then
        local unit = ...
        if unit == "player" and AA.initialized then AA:Refresh() end
    elseif event == "UNIT_INVENTORY_CHANGED" then
        local unit = ...
        if unit == "player" and AA.initialized then AA:Refresh() end
    elseif event == "BAG_UPDATE_DELAYED" then
        if AA.initialized then
            AA:CachePotionItems()
            AA:Refresh()
        end
    elseif event == "UNIT_SPELLCAST_SENT" then
        local unit, _, _, spellID = ...
        if unit == "player" and type(spellID) == "number" then
            AA.playerRequestedSpells[spellID] = GetTime()
        end
    elseif event == "UNIT_SPELLCAST_SUCCEEDED" then
        local unit, arg2, arg3 = ...
        local spellID = type(arg3) == "number" and arg3 or (type(arg2) == "number" and arg2 or nil)
        if unit == "player" and AA.initialized then
            if spellID then AA.playerCastSpells[spellID] = GetTime() end
            AA:OnPossiblePotionUse(spellID)
            AA:OnPossibleSoulstoneCast(spellID)
        end
    elseif event == "PLAYER_ENTERING_WORLD" then
        AA.suppressAnnouncementsUntil = GetTime() + 3
        if AA.initialized then AA:Refresh() end
    elseif AA.initialized then
        AA:Refresh()
    end
end)

events:SetScript("OnUpdate", function(_, elapsed)
    if not AA.initialized then return end
    AA.elapsed = AA.elapsed + elapsed
    AA.scanElapsed = AA.scanElapsed + elapsed
    if AA.scanElapsed >= 1 then
        AA.scanElapsed = AA.scanElapsed % 1
        AA:Refresh()
    end
    if AA.elapsed < 0.1 then return end
    AA.elapsed = 0
    AA:UpdateTimers()
end)

SLASH_ASYLUMALERTS1 = "/asylumalerts"
SLASH_ASYLUMALERTS2 = "/aa"
SlashCmdList.ASYLUMALERTS = function(message)
    local command = strtrim(message or ""):lower()
    if command == "unlock" then
        AA:SetLocked(false)
    elseif command == "lock" then
        AA:SetLocked(true)
    elseif command == "reset" then
        AA:ResetPosition()
    elseif command == "toggle" then
        AA:ToggleLocked()
    elseif command == "refresh" then
        AA:Refresh()
    elseif command == "resync" then
        -- Use immediately after applying a fresh Firestone/Spellstone. Forever
        -- exposes only a rounded tooltip bucket, so this establishes a clean
        -- starting point that can then be persisted across reloads and logins.
        for _, slotCache in pairs(AA.db.weaponNames or {}) do
            if type(slotCache) == "table" and type(slotCache.stones) == "table" then
                for _, stoneCache in pairs(slotCache.stones) do
                    if type(stoneCache) == "table" then stoneCache.expiresAt = nil end
                end
            end
        end
        local remove = {}
        for key, entry in pairs(AA.active) do
            local lower = type(entry.name) == "string" and entry.name:lower() or ""
            if lower:find("firestone", 1, true) or lower:find("spellstone", 1, true) then
                remove[#remove + 1] = key
            end
        end
        for _, key in ipairs(remove) do AA.active[key] = nil end
        AA:Refresh()
        print("|cff9b7cffAsylumAlerts:|r Firestone/Spellstone timer resynced.")
    elseif command == "test" then
        AA:ShowAnnouncement(AA:GetTrinketName(1) .. " is ready!", true)
    elseif command == "config" or command == "options" or command == "" then
        AA:ToggleConfig()
    else
        print("|cff9b7cffAsylumAlerts:|r /aa, /aa lock, /aa unlock, /aa toggle, /aa reset, /aa refresh, /aa resync, /aa test")
    end
end
