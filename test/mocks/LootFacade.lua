RollFor = RollFor or {}
local m = RollFor

require( "src/Interface" )
local RealLootFacade = require( "src/LootFacade" )

local M = {}
local mock = m.Interface.mock

---@class LootFacadeMock : LootFacade
---@field notify fun( event_name: LootEventName, ...: any )

function M.new()
  local subscribers = {}

  ---@param event_name string
  ---@param callback fun()
  local function subscribe( event_name, callback )
    subscribers[ event_name ] = subscribers[ event_name ] or {}
    table.insert( subscribers[ event_name ], callback )
  end

  ---@param event_name LootEventName
  ---@param ... any
  local function notify( event_name, ... )
    for _, callback in ipairs( subscribers[ event_name ] or {} ) do
      callback( ... )
    end
  end

  M.notify = notify

  local api = mock( RealLootFacade.interface )
  api.loot_slot = function( slot ) notify( "LootSlotCleared", slot ) end
  api.subscribe = subscribe
  api.notify = notify

  ---@type LootFacadeMock
  return api
end

m.LootFacade = M
return M
