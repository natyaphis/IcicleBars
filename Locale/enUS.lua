-- Locale/enUS.lua
local ADDON_NAME, ns = ...
ns = ns or {}
ns.L = ns.L or {}

local L = ns.L
if GetLocale() ~= "enUS" and GetLocale() ~= "enGB" then return end

L["TITLE"] = "IcicleBars"
L["SUBTITLE"] = "Configure bar size and position (shown only in Frost spec)"

L["BAR_WIDTH"]  = "Width"
L["BAR_HEIGHT"] = "Height"
L["BAR_GAP"]    = "Gap"
L["OFFSET_X"]   = "X Offset"
L["OFFSET_Y"]   = "Y Offset"

L["UNLOCK_MOVE"] = "Unlock to move (drag bars when unlocked)"

L["APPLY"] = "Apply"
L["RESET"] = "Default"
L["CLOSE"] = "Close"