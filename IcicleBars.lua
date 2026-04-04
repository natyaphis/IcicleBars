-- IcicleBars.lua (v1.0.2)
local ADDON_NAME, ns = ...
ns = ns or {}

local L = ns.L or {}
setmetatable(L, { __index = function(_, k) return k end }) 
local SPELL_ID = 205473 -- Icicles spell ID for tracking stacks
local MAX_STACKS = 5
local FROST_SPEC_ID = 64
local INVERTED_ALPHA = (WOW_PROJECT_ID ~= WOW_PROJECT_MAINLINE)

local FALLBACK_TEXTURES = {
    { name = "Blizzard", path = "Interface\\TargetingFrame\\UI-StatusBar" },
    { name = "Solid", path = "Interface\\Buttons\\WHITE8X8" },
    { name = "Raid", path = "Interface\\RaidFrame\\Raid-Bar-Hp-Fill" },
}

local defaults = {
    barWidth  = 57.0,
    barHeight = 8.0,
    barGap    = 1.2,
    border    = 1.5,
    offsetX   = 0.0,
    offsetY   = -200.0,
    partialColor = { r = 0.2, g = 0.6, b = 1.0, a = 1.0 },
    fullColor = { r = 1.0, g = 1.0, b = 1.0, a = 1.0 },
    emptyColor = { r = 0.2, g = 0.2, b = 0.2, a = 0.8 },
    barTexture = "Blizzard",
    unlocked  = false,
}

local function GetSharedMedia()
    if LibStub then
        local media = LibStub("LibSharedMedia-3.0", true)
        if media then
            return media
        end
    end

    if _G.ElvUI then
        local E = unpack(_G.ElvUI)
        if E and E.Libs and E.Libs.LSM then
            return E.Libs.LSM
        end
        if E and E.LSM then
            return E.LSM
        end
    end
end

local function BuildTextureMap()
    local map = {}
    for _, entry in ipairs(FALLBACK_TEXTURES) do
        map[entry.name] = entry.path
    end

    local media = GetSharedMedia()
    if media and media.HashTable then
        local hash = media:HashTable("statusbar")
        if hash then
            for name, path in pairs(hash) do
                map[name] = path
            end
        end
    end

    return map
end

local function GetTextureEntries()
    local map = BuildTextureMap()
    local entries = {}
    for name, path in pairs(map) do
        entries[#entries + 1] = {
            name = name,
            path = path,
        }
    end

    table.sort(entries, function(a, b)
        return a.name:lower() < b.name:lower()
    end)

    return entries
end

local function HasBarTexture(textureName)
    return BuildTextureMap()[textureName] ~= nil
end

local function GetBarTexturePath(textureName)
    local map = BuildTextureMap()
    return map[textureName] or map[defaults.barTexture] or FALLBACK_TEXTURES[1].path
end

local function NormalizeBarTexture(textureName)
    if HasBarTexture(textureName) then
        return textureName
    end
    return defaults.barTexture
end

local function CopyDefaults(dst, src)
    for k, v in pairs(src) do
        if type(v) == "table" then
            if type(dst[k]) ~= "table" then dst[k] = {} end
            CopyDefaults(dst[k], v)
        elseif dst[k] == nil then
            dst[k] = v
        end
    end
end

local function RoundTo(v, decimals)
    decimals = decimals or 0
    local p = 10 ^ decimals
    return math.floor(v * p + 0.5) / p
end

local function ClampNum(v, minV, maxV, decimals)
    v = tonumber(v)
    if not v then v = minV end
    if v < minV then v = minV end
    if v > maxV then v = maxV end
    if decimals then v = RoundTo(v, decimals) end
    return v
end

-- ----------------------------
-- Core (bars)
-- ----------------------------
local frame = CreateFrame("Frame", "IcicleBarsFrame", UIParent)
frame:Hide()

local bars = {}
local function EnsureBars()
    for i = 1, MAX_STACKS do
        if not bars[i] then
            local barFrame = CreateFrame("Frame", nil, frame)
            local fill = barFrame:CreateTexture(nil, "ARTWORK")
            fill:SetTexture(GetBarTexturePath(defaults.barTexture))
            fill:SetVertexColor(0.2, 0.2, 0.2, 0.8)

            local borders = {}
            for side = 1, 4 do
                local border = barFrame:CreateTexture(nil, "BORDER")
                border:SetColorTexture(0, 0, 0, 1)
                borders[side] = border
            end

            bars[i] = {
                frame = barFrame,
                fill = fill,
                borders = borders,
            }
        end
    end
end

local function IsFrostMage()
    local _, class = UnitClass("player")
    if class ~= "MAGE" then return false end
    local specIndex = GetSpecialization()
    if not specIndex then return false end
    local specID = select(1, GetSpecializationInfo(specIndex))
    return specID == FROST_SPEC_ID
end

local function GetIcicleStacks()
    local aura
    if C_UnitAuras and C_UnitAuras.GetPlayerAuraBySpellID then
        aura = C_UnitAuras.GetPlayerAuraBySpellID(SPELL_ID)
    end
    if not aura and AuraUtil and AuraUtil.FindAuraBySpellID then
        aura = AuraUtil.FindAuraBySpellID(SPELL_ID, "player", "HELPFUL")
    end
    if not aura then return 0 end

    local count = aura.applications or aura.stacks or aura.charges or aura.count or 0
    if type(count) ~= "number" then count = 0 end
    if count < 0 then count = 0 end
    if count > MAX_STACKS then count = MAX_STACKS end
    return count
end

local function ApplyLayout()
    EnsureBars()

    local db = IcicleBarsDB
    local w, h, gap, border = db.barWidth, db.barHeight, db.barGap, db.border
    local texturePath = GetBarTexturePath(db.barTexture)
    local segmentW = w
    local segmentH = h
    local innerW = math.max(1, w - (border * 2))
    local innerH = math.max(1, h - (border * 2))

    local totalW = (segmentW * MAX_STACKS) + (gap * (MAX_STACKS - 1))
    frame:SetSize(totalW, segmentH)

    frame:ClearAllPoints()
    frame:SetPoint("CENTER", UIParent, "CENTER", db.offsetX, db.offsetY)

    for i = 1, MAX_STACKS do
        local bar = bars[i]
        bar.frame:SetSize(segmentW, segmentH)
        bar.frame:ClearAllPoints()
        bar.frame:SetPoint("LEFT", frame, "LEFT", (i - 1) * (segmentW + gap), 0)

        bar.fill:SetSize(innerW, innerH)
        bar.fill:ClearAllPoints()
        bar.fill:SetPoint("TOPLEFT", bar.frame, "TOPLEFT", border, -border)
        bar.fill:SetTexture(texturePath)
        bar.fill:SetHorizTile(false)
        bar.fill:SetVertTile(false)

        local top, bottom, left, right = unpack(bar.borders)
        if border > 0 then
            top:SetPoint("TOPLEFT", bar.frame, "TOPLEFT", 0, 0)
            top:SetPoint("TOPRIGHT", bar.frame, "TOPRIGHT", 0, 0)
            top:SetHeight(border)

            bottom:SetPoint("BOTTOMLEFT", bar.frame, "BOTTOMLEFT", 0, 0)
            bottom:SetPoint("BOTTOMRIGHT", bar.frame, "BOTTOMRIGHT", 0, 0)
            bottom:SetHeight(border)

            left:SetPoint("TOPLEFT", bar.frame, "TOPLEFT", 0, 0)
            left:SetPoint("BOTTOMLEFT", bar.frame, "BOTTOMLEFT", 0, 0)
            left:SetWidth(border)

            right:SetPoint("TOPRIGHT", bar.frame, "TOPRIGHT", 0, 0)
            right:SetPoint("BOTTOMRIGHT", bar.frame, "BOTTOMRIGHT", 0, 0)
            right:SetWidth(border)

            top:Show()
            bottom:Show()
            left:Show()
            right:Show()
        else
            top:Hide()
            bottom:Hide()
            left:Hide()
            right:Hide()
        end
    end

    if db.unlocked then
        frame:EnableMouse(true)
        frame:SetMovable(true)
        frame:RegisterForDrag("LeftButton")
        frame:SetScript("OnDragStart", frame.StartMoving)
        frame:SetScript("OnDragStop", function(self)
            self:StopMovingOrSizing()
            local centerX, centerY = UIParent:GetCenter()
            local myX, myY = self:GetCenter()
            if centerX and centerY and myX and myY then
                db.offsetX = RoundTo(myX - centerX, 1)
                db.offsetY = RoundTo(myY - centerY, 1)
            end
            if IcicleBarsConfigFrame and IcicleBarsConfigFrame.Refresh then
                IcicleBarsConfigFrame:Refresh()
            end
        end)
        if not frame.bg then
            frame.bg = frame:CreateTexture(nil, "BACKGROUND")
            frame.bg:SetAllPoints(frame)
            frame.bg:SetColorTexture(1, 1, 1, 0.06)
        end
        frame.bg:Show()
    else
        frame:EnableMouse(false)
        frame:SetMovable(false)
        frame:RegisterForDrag()
        frame:SetScript("OnDragStart", nil)
        frame:SetScript("OnDragStop", nil)
        if frame.bg then frame.bg:Hide() end
    end
end

local function UpdateBars()
    if not IsFrostMage() then
        frame:Hide()
        return
    end

    frame:Show()

    local db = IcicleBarsDB
    local count = GetIcicleStacks()
    for i = 1, MAX_STACKS do
        local fill = bars[i].fill
        if i <= count then
            if count == MAX_STACKS then
                fill:SetVertexColor(db.fullColor.r, db.fullColor.g, db.fullColor.b, db.fullColor.a)
            else
                fill:SetVertexColor(db.partialColor.r, db.partialColor.g, db.partialColor.b, db.partialColor.a)
            end
        else
            fill:SetVertexColor(db.emptyColor.r, db.emptyColor.g, db.emptyColor.b, db.emptyColor.a)
        end
    end
end

-- ----------------------------
-- Standalone Config UI
-- ----------------------------
local config = CreateFrame("Frame", "IcicleBarsConfigFrame", UIParent, "BasicFrameTemplateWithInset")
config:Hide()
config:SetSize(300, 420)
config:SetPoint("CENTER")
config:SetFrameStrata("DIALOG")
config:SetClampedToScreen(true)
config:SetMovable(true)
config:EnableMouse(true)
config:RegisterForDrag("LeftButton")
config:SetScript("OnDragStart", config.StartMoving)
config:SetScript("OnDragStop", config.StopMovingOrSizing)
config.TitleText:SetText(L["TITLE"])
config.TitleText:ClearAllPoints()
config.TitleText:SetPoint("TOP", 0, -10)

local subtitle = config:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
subtitle:SetPoint("TOP", config.TitleText, "BOTTOM", 0, -5)
subtitle:SetWidth(260)
subtitle:SetJustifyH("CENTER")
subtitle:SetJustifyV("TOP")
subtitle:SetWordWrap(true)
subtitle:SetText(L["SUBTITLE"])

local function CreateLabel(parent, text)
    local fs = parent:CreateFontString(nil, "ARTWORK", "GameFontNormal")
    fs:SetText(text)
    fs:SetJustifyH("RIGHT")
    return fs
end

local function SetSingleLineEllipsizedText(fontString, text, maxWidth)
    fontString:SetWordWrap(false)
    fontString:SetMaxLines(1)
    fontString:SetText(text or "")
    if not maxWidth or fontString:GetStringWidth() <= maxWidth then
        return
    end

    local source = text or ""
    local low, high = 0, #source
    local best = "..."
    while low <= high do
        local mid = math.floor((low + high) / 2)
        local candidate = source:sub(1, mid) .. "..."
        fontString:SetText(candidate)
        if fontString:GetStringWidth() <= maxWidth then
            best = candidate
            low = mid + 1
        else
            high = mid - 1
        end
    end

    fontString:SetText(best)
end

local function ApplyConfigChange()
    ApplyLayout()
    UpdateBars()
end

local function NormalizeNumericInput(text)
    local t = (text or ""):gsub("[^%d%-%.,]", ""):gsub(",", ".")
    t = t:gsub("%-+", "-")
    if t:sub(1, 1) ~= "-" then
        t = t:gsub("%-", "")
    end
    local firstDot = t:find("%.")
    if firstDot then
        local before = t:sub(1, firstDot)
        local after = t:sub(firstDot + 1):gsub("%.", "")
        t = before .. after
    end
    return t
end

local function CommitEditBoxValue(editBox)
    local value = tonumber(editBox:GetText())
    if not value then
        return false
    end

    local clamped = ClampNum(value, editBox.minValue, editBox.maxValue, 1)
    if IcicleBarsDB[editBox.dbKey] ~= clamped then
        IcicleBarsDB[editBox.dbKey] = clamped
        ApplyConfigChange()
    end
    return true
end

local function CreateEditBox(parent, dbKey, minValue, maxValue)
    local eb = CreateFrame("EditBox", nil, parent, "InputBoxTemplate")
    eb:SetSize(126, 24)
    eb:SetAutoFocus(false)
    eb:SetNumeric(false)
    eb:SetJustifyH("LEFT")
    eb:SetTextInsets(6, 6, 0, 0)
    eb.dbKey = dbKey
    eb.minValue = minValue
    eb.maxValue = maxValue
    eb:SetScript("OnEscapePressed", function(self)
        self:ClearFocus()
        config:Refresh()
    end)
    eb:SetScript("OnEnterPressed", function(self)
        CommitEditBoxValue(self)
        self:ClearFocus()
        config:Refresh()
    end)
    eb:SetScript("OnTextChanged", function(self, userInput)
        if not userInput then return end
        local t = NormalizeNumericInput(self:GetText())
        if t ~= self:GetText() then
            local cursor = self:GetCursorPosition()
            self:SetText(t)
            self:SetCursorPosition(math.min(cursor, #t))
        end

        if tonumber(t) then
            CommitEditBoxValue(self)
        end
    end)
    eb:SetScript("OnEditFocusLost", function(self)
        CommitEditBoxValue(self)
        config:Refresh()
    end)
    return eb
end

local function CreateLabeledInputRow(parent, offsetY, labelText, dbKey, minValue, maxValue)
    local row = CreateFrame("Frame", nil, parent)
    row:SetSize(230, 24)
    row:SetPoint("TOP", 0, offsetY)

    local label = CreateLabel(parent, labelText)
    label:SetPoint("LEFT", row, "LEFT", 0, 0)
    label:SetWidth(88)

    local box = CreateEditBox(parent, dbKey, minValue, maxValue)
    box:SetPoint("LEFT", label, "RIGHT", 16, 0)

    return row, label, box
end

local function UpdateColorSwatch(button, color)
    button.swatch:SetColorTexture(color.r, color.g, color.b, color.a or 1)
end

local function OpenColorPicker(initialColor, onChanged)
    local initialR = initialColor.r
    local initialG = initialColor.g
    local initialB = initialColor.b
    local initialAlpha = initialColor.a or 1
    if ColorPickerFrame and ColorPickerFrame.SetupColorPickerAndShow then
        local pickerAlpha = initialAlpha
        if INVERTED_ALPHA then
            pickerAlpha = 1 - pickerAlpha
        end

        ColorPickerFrame:SetupColorPickerAndShow({
            r = initialR,
            g = initialG,
            b = initialB,
            opacity = pickerAlpha,
            hasOpacity = true,
            swatchFunc = function()
                local r, g, b = ColorPickerFrame:GetColorRGB()
                local a = ColorPickerFrame:GetColorAlpha()
                if INVERTED_ALPHA then
                    a = 1 - a
                end
                onChanged(r, g, b, a)
            end,
            opacityFunc = function()
                local r, g, b = ColorPickerFrame:GetColorRGB()
                local a = ColorPickerFrame:GetColorAlpha()
                if INVERTED_ALPHA then
                    a = 1 - a
                end
                onChanged(r, g, b, a)
            end,
            cancelFunc = function()
                onChanged(initialR, initialG, initialB, initialAlpha)
            end,
            previousValues = {
                r = initialR,
                g = initialG,
                b = initialB,
                a = pickerAlpha,
            },
        })
        return
    end

    if not ColorPickerFrame then
        return
    end

    ColorPickerFrame.hasOpacity = true
    ColorPickerFrame.previousValues = {
        r = initialR,
        g = initialG,
        b = initialB,
    }
    ColorPickerFrame.func = function()
        local r, g, b = ColorPickerFrame:GetColorRGB()
        local a = 1 - OpacitySliderFrame:GetValue()
        onChanged(r, g, b, a)
    end
    ColorPickerFrame.opacityFunc = function()
        local r, g, b = ColorPickerFrame:GetColorRGB()
        local a = 1 - OpacitySliderFrame:GetValue()
        onChanged(r, g, b, a)
    end
    ColorPickerFrame.opacity = 1 - initialAlpha
    ColorPickerFrame.cancelFunc = function()
        onChanged(initialR, initialG, initialB, initialAlpha)
    end
    ColorPickerFrame:SetColorRGB(initialR, initialG, initialB)
    ColorPickerFrame:Hide()
    ColorPickerFrame:Show()
end

local function CreateColorPickerRow(parent, offsetY, labelText, dbKey)
    local row = CreateFrame("Frame", nil, parent)
    row:SetSize(230, 24)
    row:SetPoint("TOP", 0, offsetY)

    local label = CreateLabel(parent, labelText)
    label:SetPoint("LEFT", row, "LEFT", 0, 0)
    label:SetWidth(88)

    local button = CreateFrame("Button", nil, parent)
    button:SetSize(24, 24)
    button:SetPoint("LEFT", label, "RIGHT", 16, 0)
    button.dbKey = dbKey

    local bg = button:CreateTexture(nil, "BACKGROUND")
    bg:SetAllPoints(button)
    bg:SetColorTexture(0, 0, 0, 0.35)
    button.bg = bg

    local swatch = button:CreateTexture(nil, "ARTWORK")
    swatch:SetPoint("TOPLEFT", button, "TOPLEFT", 2, -2)
    swatch:SetPoint("BOTTOMRIGHT", button, "BOTTOMRIGHT", -2, 2)
    button.swatch = swatch

    local borders = {}
    local borderColor = { 0, 0, 0, 0.9 }
    for i = 1, 4 do
        local border = button:CreateTexture(nil, "BORDER")
        border:SetColorTexture(unpack(borderColor))
        borders[i] = border
    end
    borders[1]:SetPoint("TOPLEFT", button, "TOPLEFT", 0, 0)
    borders[1]:SetPoint("TOPRIGHT", button, "TOPRIGHT", 0, 0)
    borders[1]:SetHeight(1)
    borders[2]:SetPoint("BOTTOMLEFT", button, "BOTTOMLEFT", 0, 0)
    borders[2]:SetPoint("BOTTOMRIGHT", button, "BOTTOMRIGHT", 0, 0)
    borders[2]:SetHeight(1)
    borders[3]:SetPoint("TOPLEFT", button, "TOPLEFT", 0, 0)
    borders[3]:SetPoint("BOTTOMLEFT", button, "BOTTOMLEFT", 0, 0)
    borders[3]:SetWidth(1)
    borders[4]:SetPoint("TOPRIGHT", button, "TOPRIGHT", 0, 0)
    borders[4]:SetPoint("BOTTOMRIGHT", button, "BOTTOMRIGHT", 0, 0)
    borders[4]:SetWidth(1)
    button.borders = borders

    button:SetScript("OnEnter", function(self)
        for _, border in ipairs(self.borders) do
            border:SetColorTexture(1, 1, 1, 0.9)
        end
    end)
    button:SetScript("OnLeave", function(self)
        for _, border in ipairs(self.borders) do
            border:SetColorTexture(0, 0, 0, 0.9)
        end
    end)

    button:SetScript("OnClick", function(self)
        local color = IcicleBarsDB[self.dbKey]
        OpenColorPicker(color, function(r, g, b, a)
            color.r = RoundTo(r, 3)
            color.g = RoundTo(g, 3)
            color.b = RoundTo(b, 3)
            color.a = RoundTo(a or 1, 3)
            UpdateColorSwatch(self, color)
            UpdateBars()
        end)
    end)

    return row, label, button
end

local function UpdateTextureDropdownPreview(dropdown)
    local texturePath = GetBarTexturePath(IcicleBarsDB.barTexture)
    dropdown.preview:SetTexture(texturePath)
    SetSingleLineEllipsizedText(dropdown.text, IcicleBarsDB.barTexture, 104)

    for _, button in ipairs(dropdown.optionButtons) do
        local isSelected = (button.value == IcicleBarsDB.barTexture)
        button.selected:SetShown(isSelected)
    end
end

local function UpdateTextureDropdownScroll(dropdown)
    local maxScroll = math.max(0, dropdown.content:GetHeight() - dropdown.scrollFrame:GetHeight())
    dropdown.scrollBar:SetMinMaxValues(0, maxScroll)
    dropdown.scrollBar:SetValue(math.min(dropdown.scrollBar:GetValue(), maxScroll))
    dropdown.scrollBar:SetShown(maxScroll > 0)
    dropdown.scrollFrame:SetVerticalScroll(dropdown.scrollBar:GetValue())
end

local function SetTextureDropdownOpen(dropdown, isOpen)
    dropdown.isOpen = isOpen and true or false
    dropdown.popup:SetShown(dropdown.isOpen)
    if dropdown.isOpen then
        UpdateTextureDropdownScroll(dropdown)
    end
end

local function AdjustTextureDropdownScroll(dropdown, delta)
    local minValue, maxValue = dropdown.scrollBar:GetMinMaxValues()
    if maxValue <= minValue then
        return
    end

    local step = 18 * 3
    local newValue = dropdown.scrollBar:GetValue() - (delta * step)
    if newValue < minValue then newValue = minValue end
    if newValue > maxValue then newValue = maxValue end
    dropdown.scrollBar:SetValue(newValue)
end

local function RebuildTextureDropdownOptions(dropdown)
    for _, button in ipairs(dropdown.optionButtons) do
        button:Hide()
        button:SetParent(nil)
    end
    wipe(dropdown.optionButtons)

    local previous
    local entries = GetTextureEntries()
    for _, entry in ipairs(entries) do
        local option = CreateFrame("Button", nil, dropdown.content)
        option:SetSize(120, 18)
        if previous then
            option:SetPoint("TOPLEFT", previous, "BOTTOMLEFT", 0, 0)
        else
            option:SetPoint("TOPLEFT", dropdown.content, "TOPLEFT", 0, 0)
        end
        option.value = entry.name

        option.preview = option:CreateTexture(nil, "BACKGROUND")
        option.preview:SetAllPoints(option)
        option.preview:SetTexture(entry.path)
        option.preview:SetVertexColor(1, 1, 1, 0.95)

        option.selected = option:CreateTexture(nil, "ARTWORK")
        option.selected:SetAllPoints(option)
        option.selected:SetColorTexture(1, 1, 1, 0.16)
        option.selected:Hide()

        option.text = option:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
        option.text:SetPoint("LEFT", option, "LEFT", 6, 0)
        option.text:SetPoint("RIGHT", option, "RIGHT", -6, 0)
        option.text:SetJustifyH("LEFT")
        SetSingleLineEllipsizedText(option.text, entry.name, 94)

        option.highlight = option:CreateTexture(nil, "HIGHLIGHT")
        option.highlight:SetAllPoints(option)
        option.highlight:SetColorTexture(1, 1, 1, 0.08)

        option:SetScript("OnClick", function(self)
            if IcicleBarsDB.barTexture ~= self.value then
                IcicleBarsDB.barTexture = self.value
                ApplyConfigChange()
                config:Refresh()
            end
            SetTextureDropdownOpen(dropdown, false)
        end)

        dropdown.optionButtons[#dropdown.optionButtons + 1] = option
        previous = option
    end

    dropdown.content:SetHeight(#entries * 18)
end

local function CreateTextureDropdownRow(parent, offsetY, labelText)
    local row = CreateFrame("Frame", nil, parent)
    row:SetSize(230, 24)
    row:SetPoint("TOP", 0, offsetY)

    local label = CreateLabel(parent, labelText)
    label:SetPoint("LEFT", row, "LEFT", 0, 0)
    label:SetWidth(88)

    local dropdown = CreateFrame("Button", "IcicleBarsTextureDropdown", parent)
    dropdown:SetSize(140, 24)
    dropdown:SetPoint("LEFT", label, "RIGHT", 16, 0)
    dropdown:SetFrameStrata(parent:GetFrameStrata())
    dropdown:SetFrameLevel(parent:GetFrameLevel() + 2)
    dropdown.optionButtons = {}

    dropdown.bg = dropdown:CreateTexture(nil, "BACKGROUND")
    dropdown.bg:SetAllPoints(dropdown)
    dropdown.bg:SetColorTexture(0, 0, 0, 0.2)

    dropdown.preview = dropdown:CreateTexture(nil, "BACKGROUND")
    dropdown.preview:SetPoint("TOPLEFT", dropdown, "TOPLEFT", 4, -4)
    dropdown.preview:SetPoint("BOTTOMRIGHT", dropdown, "BOTTOMRIGHT", -10, 4)

    dropdown.text = dropdown:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
    dropdown.text:SetPoint("LEFT", dropdown, "LEFT", 8, 0)
    dropdown.text:SetPoint("RIGHT", dropdown, "RIGHT", -24, 0)
    dropdown.text:SetJustifyH("LEFT")

    dropdown.arrow = dropdown:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    dropdown.arrow:SetPoint("RIGHT", dropdown, "RIGHT", -7, 0)
    dropdown.arrow:SetText("v")

    local borders = {}
    for i = 1, 4 do
        borders[i] = dropdown:CreateTexture(nil, "BORDER")
        borders[i]:SetColorTexture(0, 0, 0, 0.9)
    end
    borders[1]:SetPoint("TOPLEFT", dropdown, "TOPLEFT", 0, 0)
    borders[1]:SetPoint("TOPRIGHT", dropdown, "TOPRIGHT", 0, 0)
    borders[1]:SetHeight(1)
    borders[2]:SetPoint("BOTTOMLEFT", dropdown, "BOTTOMLEFT", 0, 0)
    borders[2]:SetPoint("BOTTOMRIGHT", dropdown, "BOTTOMRIGHT", 0, 0)
    borders[2]:SetHeight(1)
    borders[3]:SetPoint("TOPLEFT", dropdown, "TOPLEFT", 0, 0)
    borders[3]:SetPoint("BOTTOMLEFT", dropdown, "BOTTOMLEFT", 0, 0)
    borders[3]:SetWidth(1)
    borders[4]:SetPoint("TOPRIGHT", dropdown, "TOPRIGHT", 0, 0)
    borders[4]:SetPoint("BOTTOMRIGHT", dropdown, "BOTTOMRIGHT", 0, 0)
    borders[4]:SetWidth(1)
    dropdown.borders = borders

    dropdown.popup = CreateFrame("Frame", nil, parent)
    dropdown.popup:SetSize(140, (15 * 18) + 8)
    dropdown.popup:SetPoint("BOTTOMLEFT", dropdown, "TOPLEFT", 0, 4)
    dropdown.popup:SetFrameStrata("DIALOG")
    dropdown.popup:SetFrameLevel(dropdown:GetFrameLevel() + 10)
    dropdown.popup:Hide()

    dropdown.popup.bg = dropdown.popup:CreateTexture(nil, "BACKGROUND")
    dropdown.popup.bg:SetAllPoints(dropdown.popup)
    dropdown.popup.bg:SetColorTexture(0.05, 0.05, 0.05, 0.98)

    dropdown.popup.borders = {}
    for i = 1, 4 do
        dropdown.popup.borders[i] = dropdown.popup:CreateTexture(nil, "BORDER")
        dropdown.popup.borders[i]:SetColorTexture(0, 0, 0, 0.95)
    end
    dropdown.popup.borders[1]:SetPoint("TOPLEFT", dropdown.popup, "TOPLEFT", 0, 0)
    dropdown.popup.borders[1]:SetPoint("TOPRIGHT", dropdown.popup, "TOPRIGHT", 0, 0)
    dropdown.popup.borders[1]:SetHeight(1)
    dropdown.popup.borders[2]:SetPoint("BOTTOMLEFT", dropdown.popup, "BOTTOMLEFT", 0, 0)
    dropdown.popup.borders[2]:SetPoint("BOTTOMRIGHT", dropdown.popup, "BOTTOMRIGHT", 0, 0)
    dropdown.popup.borders[2]:SetHeight(1)
    dropdown.popup.borders[3]:SetPoint("TOPLEFT", dropdown.popup, "TOPLEFT", 0, 0)
    dropdown.popup.borders[3]:SetPoint("BOTTOMLEFT", dropdown.popup, "BOTTOMLEFT", 0, 0)
    dropdown.popup.borders[3]:SetWidth(1)
    dropdown.popup.borders[4]:SetPoint("TOPRIGHT", dropdown.popup, "TOPRIGHT", 0, 0)
    dropdown.popup.borders[4]:SetPoint("BOTTOMRIGHT", dropdown.popup, "BOTTOMRIGHT", 0, 0)
    dropdown.popup.borders[4]:SetWidth(1)

    dropdown.scrollFrame = CreateFrame("ScrollFrame", nil, dropdown.popup)
    dropdown.scrollFrame:SetPoint("TOPLEFT", dropdown.popup, "TOPLEFT", 2, -2)
    dropdown.scrollFrame:SetPoint("BOTTOMRIGHT", dropdown.popup, "BOTTOMRIGHT", -18, 2)
    dropdown.scrollFrame:EnableMouseWheel(true)

    dropdown.content = CreateFrame("Frame", nil, dropdown.scrollFrame)
    dropdown.content:SetSize(120, 1)
    dropdown.scrollFrame:SetScrollChild(dropdown.content)

    dropdown.scrollBar = CreateFrame("Slider", nil, dropdown.popup, "UIPanelScrollBarTemplate")
    dropdown.scrollBar:SetPoint("TOPRIGHT", dropdown.popup, "TOPRIGHT", -2, -18)
    dropdown.scrollBar:SetPoint("BOTTOMRIGHT", dropdown.popup, "BOTTOMRIGHT", -2, 18)
    dropdown.scrollBar:SetMinMaxValues(0, 0)
    dropdown.scrollBar:SetValueStep(18)
    dropdown.scrollBar:SetObeyStepOnDrag(true)
    dropdown.scrollBar:SetScript("OnValueChanged", function(self, value)
        dropdown.scrollFrame:SetVerticalScroll(value)
    end)

    dropdown.scrollFrame:SetScript("OnMouseWheel", function(_, delta)
        AdjustTextureDropdownScroll(dropdown, delta)
    end)
    dropdown.popup:SetScript("OnMouseWheel", function(_, delta)
        AdjustTextureDropdownScroll(dropdown, delta)
    end)

    RebuildTextureDropdownOptions(dropdown)

    dropdown:SetScript("OnClick", function()
        RebuildTextureDropdownOptions(dropdown)
        SetTextureDropdownOpen(dropdown, not dropdown.isOpen)
    end)
    dropdown:SetScript("OnEnter", function(self)
        for _, border in ipairs(self.borders) do
            border:SetColorTexture(1, 1, 1, 0.9)
        end
    end)
    dropdown:SetScript("OnLeave", function(self)
        for _, border in ipairs(self.borders) do
            border:SetColorTexture(0, 0, 0, 0.9)
        end
    end)

    return row, label, dropdown
end

config.rowWidth, config.lblWidth, config.ebWidth = CreateLabeledInputRow(config, -58, L["BAR_WIDTH"], "barWidth", 4.0, 200.0)
config.rowHeight, config.lblHeight, config.ebHeight = CreateLabeledInputRow(config, -87, L["BAR_HEIGHT"], "barHeight", 2.0, 100.0)
config.rowGap, config.lblGap, config.ebGap = CreateLabeledInputRow(config, -116, L["BAR_GAP"], "barGap", 0.0, 100.0)
config.rowBorder, config.lblBorder, config.ebBorder = CreateLabeledInputRow(config, -145, L["BORDER"], "border", 0.0, 20.0)
config.rowX, config.lblX, config.ebX = CreateLabeledInputRow(config, -174, L["OFFSET_X"], "offsetX", -5000.0, 5000.0)
config.rowY, config.lblY, config.ebY = CreateLabeledInputRow(config, -203, L["OFFSET_Y"], "offsetY", -5000.0, 5000.0)
config.rowPartialColor, config.lblPartialColor, config.btnPartialColor = CreateColorPickerRow(config, -232, L["PARTIAL_COLOR"], "partialColor")
config.rowFullColor, config.lblFullColor, config.btnFullColor = CreateColorPickerRow(config, -261, L["FULL_COLOR"], "fullColor")
config.rowEmptyColor, config.lblEmptyColor, config.btnEmptyColor = CreateColorPickerRow(config, -290, L["EMPTY_COLOR"], "emptyColor")
config.rowTexture, config.lblTexture, config.ddTexture = CreateTextureDropdownRow(config, -319, L["BAR_TEXTURE"])

config.btnUnlock = CreateFrame("Button", nil, config, "UIPanelButtonTemplate")
config.btnUnlock:SetHeight(24)
config.btnUnlock:SetPoint("BOTTOMLEFT", config, "BOTTOMLEFT", 20, 46)
config.btnUnlock:SetPoint("RIGHT", config, "CENTER", -2.5, 0)

config.btnReset = CreateFrame("Button", nil, config, "UIPanelButtonTemplate")
config.btnReset:SetHeight(24)
config.btnReset:SetPoint("BOTTOMRIGHT", config, "BOTTOMRIGHT", -20, 46)
config.btnReset:SetPoint("LEFT", config, "CENTER", 2.5, 0)
config.btnReset:SetText(L["RESET"])

config.btnClose = CreateFrame("Button", nil, config, "UIPanelButtonTemplate")
config.btnClose:SetHeight(24)
config.btnClose:SetPoint("BOTTOMLEFT", config, "BOTTOMLEFT", 20, 17)
config.btnClose:SetPoint("BOTTOMRIGHT", config, "BOTTOMRIGHT", -20, 17)
config.btnClose:SetText(L["CLOSE"])

local function ApplyElvUISkin()
    if config.isElvUISkinned then
        return
    end

    local E = _G.ElvUI and unpack(_G.ElvUI)
    if not E or not E.private or not E.private.skins or not E.private.skins.blizzard then
        return
    end

    local S = E.GetModule and E:GetModule("Skins", true)
    if not S then
        return
    end

    if S.HandleFrame then
        S:HandleFrame(config)
    end
    if S.HandleEditBox then
        S:HandleEditBox(config.ebWidth)
        S:HandleEditBox(config.ebHeight)
        S:HandleEditBox(config.ebGap)
        S:HandleEditBox(config.ebBorder)
        S:HandleEditBox(config.ebX)
        S:HandleEditBox(config.ebY)
    end
    if S.HandleButton then
        S:HandleButton(config.btnUnlock)
        S:HandleButton(config.btnReset)
        S:HandleButton(config.btnClose)
    end
    if S.HandleFrame then
        S:HandleFrame(config.ddTexture.popup)
    end
    if S.HandleScrollBar then
        S:HandleScrollBar(config.ddTexture.scrollBar)
    end

    config.isElvUISkinned = true
end

function config:Refresh()
    local db = IcicleBarsDB
    self.ebWidth:SetText(string.format("%.1f", db.barWidth))
    self.ebHeight:SetText(string.format("%.1f", db.barHeight))
    self.ebGap:SetText(string.format("%.1f", db.barGap))
    self.ebBorder:SetText(string.format("%.1f", db.border))
    self.ebX:SetText(string.format("%.1f", db.offsetX))
    self.ebY:SetText(string.format("%.1f", db.offsetY))
    UpdateColorSwatch(self.btnPartialColor, db.partialColor)
    UpdateColorSwatch(self.btnFullColor, db.fullColor)
    UpdateColorSwatch(self.btnEmptyColor, db.emptyColor)
    UpdateTextureDropdownPreview(self.ddTexture)
    self.btnUnlock:SetText(db.unlocked and "|cff7dd3ff" .. L["LOCK"] .. "|r" or L["UNLOCK"])
end

config.btnUnlock:SetScript("OnClick", function()
    IcicleBarsDB.unlocked = not IcicleBarsDB.unlocked
    ApplyConfigChange()
    config:Refresh()
end)
config.btnReset:SetScript("OnClick", function()
    IcicleBarsDB = {}
    CopyDefaults(IcicleBarsDB, defaults)
    ApplyConfigChange()
    config:Refresh()
end)
config.btnClose:SetScript("OnClick", function() config:Hide() end)

function IcicleBars_OpenConfig()
    if not IcicleBarsDB then return end
    ApplyElvUISkin()
    config:Refresh()
    config:Show()
end

SLASH_ICICLEBARS1 = "/iciclebars"
SLASH_ICICLEBARS2 = "/icicle"
SLASH_ICICLEBARS3 = "/ib"
SlashCmdList.ICICLEBARS = function()
    IcicleBars_OpenConfig()
end

frame:RegisterEvent("ADDON_LOADED")
frame:RegisterEvent("PLAYER_LOGIN")
frame:RegisterEvent("PLAYER_SPECIALIZATION_CHANGED")
frame:RegisterUnitEvent("UNIT_AURA", "player")

frame:SetScript("OnEvent", function(self, event, arg1)
    if event == "ADDON_LOADED" and arg1 == ADDON_NAME then
        IcicleBarsDB = IcicleBarsDB or {}
        CopyDefaults(IcicleBarsDB, defaults)
        IcicleBarsDB.barTexture = NormalizeBarTexture(IcicleBarsDB.barTexture)
        ApplyLayout()
        UpdateBars()
    elseif event == "PLAYER_LOGIN" then
        ApplyElvUISkin()
        ApplyLayout()
        UpdateBars()
    elseif event == "PLAYER_SPECIALIZATION_CHANGED" then
        UpdateBars()
    elseif event == "UNIT_AURA" then
        UpdateBars()
    end
end)
