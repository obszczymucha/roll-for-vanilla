RollFor = RollFor or {}
local m = RollFor

require( "src/Interface" )
require( "src/ItemCatalogue" ) -- the catalogue helpers AutoLootDb delegates its seeding and queries to
require( "src/AutoLootDb" ) -- AutoLoot reads the predefined list through it, so it must load first.
local RealAutoLoot = require( "src/AutoLoot" )

local M = {}
local mock = m.Interface.mock

---@class AutoLootMock : AutoLoot

function M.new( loot_list, api, autoloot_db, config, player_info, chat )
  local real_auto_loot = RealAutoLoot.new( loot_list, function() return api end, autoloot_db, config, player_info, chat )

  local interface = mock( RealAutoLoot.interface )

  interface.is_auto_looted = real_auto_loot.is_auto_looted
  interface.is_on_predefined_list = real_auto_loot.is_on_predefined_list
  interface.on_loot_opened = real_auto_loot.on_loot_opened

  ---@type AutoLootMock
  return interface
end

m.AutoLoot = M
return M
