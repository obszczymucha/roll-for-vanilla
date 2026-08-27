RollFor = RollFor or {}
local m = RollFor

if m.EventBus then return end

local M = {}

---@class EventBus
---@field subscribe fun( event_name: string, callback: function )
---@field notify fun( event_name: string, data: any? ): number -- how many callbacks ran
---@field has_subscribers fun( event_name: string ): boolean

function M.new()
  local subscribers = {}

  ---@param event_name string
  ---@param callback fun()
  local function subscribe( event_name, callback )
    subscribers[ event_name ] = subscribers[ event_name ] or {}
    table.insert( subscribers[ event_name ], callback )
  end

  ---@param event_name string
  ---@param data any
  ---@return number
  local function notify( event_name, data )
    local count = 0

    for _, callback in ipairs( subscribers[ event_name ] or {} ) do
      callback( data )
      count = count + 1
    end

    return count
  end

  ---@param event_name string
  ---@return boolean
  local function has_subscribers( event_name )
    return subscribers[ event_name ] ~= nil and #subscribers[ event_name ] > 0
  end

  ---@type EventBus
  return {
    subscribe = subscribe,
    notify = notify,
    has_subscribers = has_subscribers
  }
end

m.EventBus = M
return M
