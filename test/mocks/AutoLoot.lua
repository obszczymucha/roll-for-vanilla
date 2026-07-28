RollFor = RollFor or {}
local m = RollFor

require( "src/Interface" )
local RealAutoLoot = require( "src/AutoLoot" )

local M = {}
local mock = m.Interface.mock

---@class AutoLootMock : AutoLoot

function M.new( loot_list, api, db, config, player_info, chat )
  _G[ "SlashCmdList" ] = {}

  local real_auto_loot = RealAutoLoot.new( loot_list, function() return api end, db, config, player_info, chat )

  local interface = mock( RealAutoLoot.interface )

  interface.is_auto_looted = real_auto_loot.is_auto_looted
  interface.add = real_auto_loot.add
  interface.remove = real_auto_loot.remove
  interface.add_category = real_auto_loot.add_category
  interface.disable_category = real_auto_loot.disable_category
  interface.on_loot_opened = real_auto_loot.on_loot_opened

  ---@type AutoLootMock
  return interface
end

m.AutoLoot = M
return M
