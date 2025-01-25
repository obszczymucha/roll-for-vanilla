RollFor = RollFor or {}
local m = RollFor

require( "src/Interface" )
local RealLootFacade = require( "src/LootFacade" )

local M = {}
local mock = m.Interface.mock

---@class LootFacadeMock : LootFacade
---@field notify fun( event_name: LootEventName, arg: any? )

function M.new()
  local bus = require( "src/EventBus" ).new()
  M.notify = bus.notify

  local api = mock( RealLootFacade.interface )
  api.subscribe = bus.subscribe
  api.notify = bus.notify

  ---@type LootFacadeMock
  return api
end

m.LootFacade = M
return M
