RollFor = RollFor or {}
local m = RollFor

require( "src/Interface" )
local RealAutoLoot = require( "src/AutoLoot" )

local M = {}
local mock = m.Interface.mock

local u = require( "test/utils" )

---@class AutoLootMock : AutoLoot

function M.new( loot_list, api, db, config, player_info )
  _G[ "SlashCmdList" ] = {}

  local real_auto_loot = RealAutoLoot.new( loot_list, function() return api end, db, config, player_info )

  local interface = mock( RealAutoLoot.interface )

  interface.is_auto_looted = real_auto_loot.is_auto_looted
  interface.add = real_auto_loot.add
  interface.remove = real_auto_loot.remove

  ---@type AutoLootMock
  return interface
end

m.AutoLoot = M
return M
