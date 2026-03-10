-- Locale/zhCN.lua
local ADDON_NAME, ns = ...
ns = ns or {}
ns.L = ns.L or {}

local L = ns.L
if GetLocale() ~= "zhCN" then return end

L["TITLE"] = "IcicleBars by NatYaphis"
L["SUBTITLE"] = "设置条尺寸与位置\n只在冰法专精显示"

L["BAR_WIDTH"]  = "条宽"
L["BAR_HEIGHT"] = "条高"
L["BAR_GAP"]    = "空隙"
L["BORDER"]     = "边框"
L["OFFSET_X"]   = "X偏移"
L["OFFSET_Y"]   = "Y偏移"

L["UNLOCK"] = "解锁"
L["LOCK"] = "锁定"

L["RESET"] = "默认"
L["CLOSE"] = "关闭"
