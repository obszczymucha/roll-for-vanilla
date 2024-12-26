RollFor = RollFor or {}
local m = RollFor

if m.LootEventFacade then return end

local M = {}

function M.new()
  local bus = require( "src/EventBus" ).new()
  M.notify = bus.notify

  return {
    subscribe = bus.subscribe,
    get_item_count = function() return 0 end,
    get_source_guid = function() return "PrincessKenny" end
  }
end

m.LootEventFacade = M
return M
