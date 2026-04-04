-- Locale/zhCN.lua
local ADDON_NAME, ns = ...
ns = ns or {}
ns.L = ns.L or {}

local L = ns.L
if GetLocale() ~= "zhCN" then return end

L["TITLE"] = "IcicleBars by NatYaphis"
L["SUBTITLE"] = "只在冰法专精显示"

L["BAR_WIDTH"]  = "条宽"
L["BAR_HEIGHT"] = "条高"
L["BAR_GAP"]    = "空隙"
L["BORDER"]     = "边框"
L["OFFSET_X"]   = "X偏移"
L["OFFSET_Y"]   = "Y偏移"
L["PARTIAL_COLOR"] = "未满颜色"
L["FULL_COLOR"] = "满层颜色"
L["EMPTY_COLOR"] = "背景颜色"
L["BAR_TEXTURE"] = "材质"
L["UNLOCK"] = "解锁"
L["LOCK"] = "锁定"

L["RESET"] = "默认"
L["CLOSE"] = "关闭"
