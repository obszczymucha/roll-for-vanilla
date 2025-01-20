RollFor = RollFor or {}
local m = RollFor

local RealLootFacade = require( "src/LootFacade" )

local M = {}
local mock = m.Interface.mock

function M.new()
  local bus = require( "src/EventBus" ).new()
  M.notify = bus.notify

  local api = mock( RealLootFacade.interface )
  api.subscribe = bus.subscribe

  return api
end

m.LootFacade = M
return M
