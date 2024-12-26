RollFor = RollFor or {}
local m = RollFor

if m.WowApi then return end

local M = {}

M.LootFrameApi = {
  GetLootSlotLink = "function",
  GetLootSlotInfo = "function"
}

m.WowApi = M
return M
