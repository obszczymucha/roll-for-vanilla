RollFor = RollFor or {}
local m = RollFor

if m.RfTestLootFacade then return end

local M = {}

---@class RfTestLootFacade : LootFacade
---@field setup fun( items: DroppedItem[] )
---@field notify fun( event_name: LootEventName )

---@param real_facade LootFacade
function M.new( real_facade )
  local subscribers = {}
  local items = nil

  local function subscribe( event_name, callback )
    subscribers[ event_name ] = subscribers[ event_name ] or {}
    table.insert( subscribers[ event_name ], callback )

    if event_name == "LootOpened" then
      real_facade.subscribe( event_name, function( ... )
        items = nil
        callback( ... )
      end )
    else
      real_facade.subscribe( event_name, callback )
    end
  end

  local function notify( event_name, ... )
    for _, callback in ipairs( subscribers[ event_name ] or {} ) do
      callback( ... )
    end
  end

  local function setup( dropped_items )
    items = dropped_items
  end

  local function get_item_count()
    return items and #items or real_facade.get_item_count()
  end

  local function get_source_guid()
    return items and nil or real_facade.get_source_guid()
  end

  ---@param slot number
  ---@return ItemLink?
  local function get_link( slot )
    return items and items[ slot ] and items[ slot ].link or real_facade.get_link( slot )
  end

  ---@param slot number
  local function get_info( slot )
    if items then
      local item = items[ slot ]
      return { texture = item.texture, name = item.name, quantity = item.quantity, quality = item.quality }
    end

    return real_facade.get_info( slot )
  end

  local function is_item( slot )
    return items and items[ slot ] ~= nil or real_facade.is_item( slot )
  end

  local function is_coin( slot )
    return not items and real_facade.is_coin( slot )
  end

  local function loot_slot( slot )
    real_facade.loot_slot( slot )
  end

  ---@type RfTestLootFacade
  return {
    subscribe = subscribe,
    notify = notify,
    setup = setup,
    get_item_count = get_item_count,
    get_source_guid = get_source_guid,
    get_link = get_link,
    get_info = get_info,
    is_item = is_item,
    is_coin = is_coin,
    loot_slot = loot_slot
  }
end

m.RfTestLootFacade = M
return M
