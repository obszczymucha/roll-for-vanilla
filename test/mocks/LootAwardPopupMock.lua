RollFor = RollFor or {}
local m = RollFor

if m.LootAwardPopup then return end

local utils = require( "test/utils" )

local M = {}

function M.new( _, _, callback )
  utils.register_loot_confirm_callback( callback )

  return {
    show = function() end,
    hide = function() end,
  }
end

m.LootAwardPopup = M
return M
