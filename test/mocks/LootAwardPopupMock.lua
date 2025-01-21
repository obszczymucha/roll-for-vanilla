RollFor = RollFor or {}
local m = RollFor

if m.LootAwardPopup then return end

local M = {}

function M.new()
  return {
    show = function() end,
    hide = function() end,
  }
end

m.LootAwardPopup = M
return M
