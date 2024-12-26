RollFor = RollFor or {}
local m = RollFor

if m.LootEventFacade then return end

local M = {}

M.interface = {
  subscribe = "function",
  get_item_count = "function",
  get_source_guid = "function"
}

---@class LootEventFacade
---@field subscribe fun( event_name: LootEventName, callback: fun() )
---@field get_item_count fun(): number
---@field get_source_guid fun(): string

---@alias LootEventName
---| "LootOpened"
---| "LootClosed"
---| "LootSlotCleared"

---@return LootEventFacade
function M.new( event_frame, api )
  ---@param event_name LootEventName
  ---@param callback fun()
  local function subscribe( event_name, callback )
    local blizz_event =
        event_name == "LootOpened" and "LOOT_OPENED" or
        event_name == "LootClosed" and "LOOT_CLOSED" or
        event_name == "LootSlotCleared" and "LOOT_SLOT_CLEARED"

    if blizz_event then
      event_frame.subscribe( blizz_event, callback )
    end
  end

  local function get_item_count()
    return api.GetNumLootItems()
  end

  local function get_source_guid()
    return api.UnitName( "target" )
  end

  return {
    subscribe = subscribe,
    get_item_count = get_item_count,
    get_source_guid = get_source_guid
  }
end

m.LootEventFacade = M
return M
