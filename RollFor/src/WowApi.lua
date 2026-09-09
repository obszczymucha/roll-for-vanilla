RollFor = RollFor or {}
local m = RollFor

if m.WowApi then return end

local M = {}

M.LootInterface = {
  GetNumLootItems = "function",
  UnitName = "function",
  GetLootSlotLink = "function",
  GetLootSlotInfo = "function",
  GetLootSlotType = "function",
  GetLootSourceInfo = "function"
}

m.WowApi = M
return M
