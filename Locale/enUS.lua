-- Locale/enUS.lua
local ADDON_NAME, ns = ...
ns = ns or {}
ns.L = ns.L or {}

local L = ns.L
if GetLocale() ~= "enUS" and GetLocale() ~= "enGB" then return end

L["TITLE"] = "IcicleBars by NatYaphis"
L["SUBTITLE"] = "Configure bar size and position\nshown only in Frost spec"

L["BAR_WIDTH"]  = "Width"
L["BAR_HEIGHT"] = "Height"
L["BAR_GAP"]    = "Gap"
L["BORDER"]     = "Border"
L["OFFSET_X"]   = "X Offset"
L["OFFSET_Y"]   = "Y Offset"

L["UNLOCK"] = "Unlock"
L["LOCK"] = "Lock"

L["RESET"] = "Default"
L["CLOSE"] = "Close"
