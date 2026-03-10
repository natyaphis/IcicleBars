-- IcicleBars.lua (v1.0.2)
local ADDON_NAME, ns = ...
ns = ns or {}

local L = ns.L or {}
setmetatable(L, { __index = function(_, k) return k end }) 
local SPELL_ID = 205473 -- Icicles spell ID for tracking stacks
local MAX_STACKS = 5
local FROST_SPEC_ID = 64

local defaults = {
    barWidth  = 57.0,
    barHeight = 8.0,
    barGap    = 1.2,
    border    = 1.5,
    offsetX   = 0.0,
    offsetY   = -200.0,
    unlocked  = false,
}

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
            fill:SetColorTexture(0.2, 0.2, 0.2, 0.8)

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

    local count = GetIcicleStacks()
    for i = 1, MAX_STACKS do
        local fill = bars[i].fill
        if i <= count then
            if count == MAX_STACKS then
                fill:SetColorTexture(1, 1, 1, 1) -- 5 stacks = full bright
            else
                fill:SetColorTexture(0.2, 0.6, 1, 1) -- 1-4 stacks = bright blue
            end
        else
            fill:SetColorTexture(0.2, 0.2, 0.2, 0.8) -- empty bar = dim gray
        end
    end
end

-- ----------------------------
-- Standalone Config UI
-- ----------------------------
local config = CreateFrame("Frame", "IcicleBarsConfigFrame", UIParent, "BasicFrameTemplateWithInset")
config:Hide()
config:SetSize(360, 360)
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

local function GetAddonVersion()
    if C_AddOns and C_AddOns.GetAddOnMetadata then
        return C_AddOns.GetAddOnMetadata(ADDON_NAME, "Version")
    end
    if GetAddOnMetadata then
        return GetAddOnMetadata(ADDON_NAME, "Version")
    end
    return nil
end

local versionText = config:CreateFontString(nil, "ARTWORK", "GameFontNormalSmall")
versionText:SetPoint("TOP", config.TitleText, "BOTTOM", 0, -6)
versionText:SetTextColor(1, 1, 1)
versionText:SetText(GetAddonVersion() or "0.0.0")

local subtitle = config:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
subtitle:SetPoint("TOP", versionText, "BOTTOM", 0, -10)
subtitle:SetWidth(300)
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

config.rowWidth, config.lblWidth, config.ebWidth = CreateLabeledInputRow(config, -108, L["BAR_WIDTH"], "barWidth", 4.0, 200.0)
config.rowHeight, config.lblHeight, config.ebHeight = CreateLabeledInputRow(config, -140, L["BAR_HEIGHT"], "barHeight", 2.0, 100.0)
config.rowGap, config.lblGap, config.ebGap = CreateLabeledInputRow(config, -172, L["BAR_GAP"], "barGap", 0.0, 100.0)
config.rowBorder, config.lblBorder, config.ebBorder = CreateLabeledInputRow(config, -204, L["BORDER"], "border", 0.0, 20.0)
config.rowX, config.lblX, config.ebX = CreateLabeledInputRow(config, -236, L["OFFSET_X"], "offsetX", -5000.0, 5000.0)
config.rowY, config.lblY, config.ebY = CreateLabeledInputRow(config, -268, L["OFFSET_Y"], "offsetY", -5000.0, 5000.0)

config.btnUnlock = CreateFrame("Button", nil, config, "UIPanelButtonTemplate")
config.btnUnlock:SetSize(96, 24)
config.btnUnlock:SetPoint("BOTTOMLEFT", 18, 18)

config.btnReset = CreateFrame("Button", nil, config, "UIPanelButtonTemplate")
config.btnReset:SetSize(96, 24)
config.btnReset:SetPoint("LEFT", config.btnUnlock, "RIGHT", 12, 0)
config.btnReset:SetText(L["RESET"])

config.btnClose = CreateFrame("Button", nil, config, "UIPanelButtonTemplate")
config.btnClose:SetSize(96, 24)
config.btnClose:SetPoint("LEFT", config.btnReset, "RIGHT", 12, 0)
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
