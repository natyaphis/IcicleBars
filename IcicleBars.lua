-- IcicleBars.lua (v1.0.1)
local ADDON_NAME, ns = ...
ns = ns or {}

local L = ns.L or {}
setmetatable(L, { __index = function(_, k) return k end }) 
local SPELL_ID = 205473 -- Icicles spell ID for tracking stacks
local MAX_STACKS = 5
local FROST_SPEC_ID = 64

local defaults = {
    barWidth  = 28.0,
    barHeight = 12.0,
    barGap    = 4.0,
    offsetX   = 0.0,
    offsetY   = -150.0,
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
            local bar = frame:CreateTexture(nil, "ARTWORK")
            bar:SetColorTexture(0.2, 0.2, 0.2, 0.8)
            bars[i] = bar
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
    local w, h, gap = db.barWidth, db.barHeight, db.barGap

    local totalW = (w * MAX_STACKS) + (gap * (MAX_STACKS - 1))
    frame:SetSize(totalW, h)

    frame:ClearAllPoints()
    frame:SetPoint("CENTER", UIParent, "CENTER", db.offsetX, db.offsetY)

    for i = 1, MAX_STACKS do
        local bar = bars[i]
        bar:SetSize(w, h)
        bar:ClearAllPoints()
        bar:SetPoint("LEFT", frame, "LEFT", (i - 1) * (w + gap), 0)
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
        if i <= count then
            if count == MAX_STACKS then
                bars[i]:SetColorTexture(1, 1, 1, 1) -- 5 stacks = full bright
            else
                bars[i]:SetColorTexture(0.2, 0.6, 1, 1) -- 1-4 stacks = bright blue
            end
        else
            bars[i]:SetColorTexture(0.2, 0.2, 0.2, 0.8) -- empty bar = dim gray
        end
    end
end

-- ----------------------------
-- Standalone Config UI
-- ----------------------------
local config = CreateFrame("Frame", "IcicleBarsConfigFrame", UIParent, "BackdropTemplate")
config:Hide()
config:SetSize(360, 270)
config:SetPoint("CENTER")
config:SetFrameStrata("DIALOG")
config:SetClampedToScreen(true)
config:SetMovable(true)
config:EnableMouse(true)
config:RegisterForDrag("LeftButton")
config:SetScript("OnDragStart", config.StartMoving)
config:SetScript("OnDragStop", config.StopMovingOrSizing)
config:SetBackdrop({
    bgFile = "Interface\\DialogFrame\\UI-DialogBox-Background",
    edgeFile = "Interface\\DialogFrame\\UI-DialogBox-Border",
    tile = true, tileSize = 32, edgeSize = 32,
    insets = { left = 11, right = 12, top = 12, bottom = 11 }
})
config:SetBackdropColor(1, 1, 1, 1)

local title = config:CreateFontString(nil, "ARTWORK", "GameFontNormalLarge")
title:SetPoint("TOPLEFT", 18, -16)
title:SetText(L["TITLE"])

local subtitle = config:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
subtitle:SetPoint("TOPLEFT", title, "BOTTOMLEFT", 0, -8)
subtitle:SetText(L["SUBTITLE"])

local function CreateLabel(parent, text, x, y)
    local fs = parent:CreateFontString(nil, "ARTWORK", "GameFontNormal")
    fs:SetPoint("TOPLEFT", x, y)
    fs:SetText(text)
    return fs
end

local function CreateEditBox(parent, x, y)
    local eb = CreateFrame("EditBox", nil, parent, "InputBoxTemplate")
    eb:SetSize(90, 20)
    eb:SetAutoFocus(false)
    eb:SetNumeric(false)
    eb:SetJustifyH("LEFT")
    eb:SetPoint("TOPLEFT", x, y)
    eb:SetScript("OnEscapePressed", eb.ClearFocus)
    eb:SetScript("OnEnterPressed", function(self) self:ClearFocus() end)
    eb:SetScript("OnTextChanged", function(self, userInput)
        if not userInput then return end
        local t = (self:GetText() or ""):gsub("[^%d%-%.,]", ""):gsub(",", ".")
        t = t:gsub("%-+", "-")
        if t:sub(1,1) ~= "-" then t = t:gsub("%-", "") end
        local firstDot = t:find("%.")
        if firstDot then
            local before = t:sub(1, firstDot)
            local after = t:sub(firstDot + 1):gsub("%.", "")
            t = before .. after
        end
        if t ~= self:GetText() then
            local cursor = self:GetCursorPosition()
            self:SetText(t)
            self:SetCursorPosition(math.min(cursor, #t))
        end
    end)
    return eb
end

local function CreateCheckBox(parent, labelText, x, y)
    local cb = CreateFrame("CheckButton", nil, parent, "ChatConfigCheckButtonTemplate")
    cb:SetPoint("TOPLEFT", x, y)
    cb.Text:SetText(labelText)
    return cb
end

-- Layout tuning: move edit boxes left and keep right edge inside frame
local LEFT_LABEL_X  = 35
local LEFT_BOX_X    = 80
local RIGHT_LABEL_X = 190
local RIGHT_BOX_X   = 240

CreateLabel(config, L["BAR_WIDTH"], LEFT_LABEL_X, -70)
config.ebWidth = CreateEditBox(config, LEFT_BOX_X, -68)

CreateLabel(config, L["BAR_HEIGHT"], LEFT_LABEL_X, -110)
config.ebHeight = CreateEditBox(config, LEFT_BOX_X, -108)

CreateLabel(config, L["BAR_GAP"], LEFT_LABEL_X, -150)
config.ebGap = CreateEditBox(config, LEFT_BOX_X, -148)

CreateLabel(config, L["OFFSET_X"], RIGHT_LABEL_X, -70)
config.ebX = CreateEditBox(config, RIGHT_BOX_X, -68)

CreateLabel(config, L["OFFSET_Y"], RIGHT_LABEL_X, -110)
config.ebY = CreateEditBox(config, RIGHT_BOX_X, -108)

config.cbUnlock = CreateCheckBox(config, L["UNLOCK_MOVE"], 18, -195)

config.btnApply = CreateFrame("Button", nil, config, "UIPanelButtonTemplate")
config.btnApply:SetSize(100, 22)
config.btnApply:SetPoint("BOTTOMLEFT", 18, 18)
config.btnApply:SetText(L["APPLY"])

config.btnReset = CreateFrame("Button", nil, config, "UIPanelButtonTemplate")
config.btnReset:SetSize(100, 22)
config.btnReset:SetPoint("LEFT", config.btnApply, "RIGHT", 10, 0)
config.btnReset:SetText(L["RESET"])

config.btnClose = CreateFrame("Button", nil, config, "UIPanelButtonTemplate")
config.btnClose:SetSize(100, 22)
config.btnClose:SetPoint("LEFT", config.btnReset, "RIGHT", 10, 0)
config.btnClose:SetText(L["CLOSE"])

function config:Refresh()
    local db = IcicleBarsDB
    self.ebWidth:SetText(string.format("%.1f", db.barWidth))
    self.ebHeight:SetText(string.format("%.1f", db.barHeight))
    self.ebGap:SetText(string.format("%.1f", db.barGap))
    self.ebX:SetText(string.format("%.1f", db.offsetX))
    self.ebY:SetText(string.format("%.1f", db.offsetY))
    self.cbUnlock:SetChecked(db.unlocked)
end

local function ApplyFromConfig()
    local db = IcicleBarsDB
    db.barWidth  = ClampNum(config.ebWidth:GetText(), 4.0, 200.0, 1)
    db.barHeight = ClampNum(config.ebHeight:GetText(), 2.0, 100.0, 1)
    db.barGap    = ClampNum(config.ebGap:GetText(), 0.0, 100.0, 1)
    db.offsetX   = ClampNum(config.ebX:GetText(), -5000.0, 5000.0, 1)
    db.offsetY   = ClampNum(config.ebY:GetText(), -5000.0, 5000.0, 1)
    db.unlocked  = config.cbUnlock:GetChecked() and true or false

    ApplyLayout()
    UpdateBars()
    config:Refresh()
end

config.btnApply:SetScript("OnClick", ApplyFromConfig)
config.btnReset:SetScript("OnClick", function()
    IcicleBarsDB = {}
    CopyDefaults(IcicleBarsDB, defaults)
    ApplyLayout()
    UpdateBars()
    config:Refresh()
end)
config.btnClose:SetScript("OnClick", function() config:Hide() end)

function IcicleBars_OpenConfig()
    if not IcicleBarsDB then return end
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
        ApplyLayout()
        UpdateBars()
    elseif event == "PLAYER_SPECIALIZATION_CHANGED" then
        UpdateBars()
    elseif event == "UNIT_AURA" then
        UpdateBars()
    end
end)