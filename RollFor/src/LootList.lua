RollFor = RollFor or {}
local m = RollFor
if m.LootList then return end

local M = {}
local LEF = m.LootEventFacade
local IU = m.ItemUtils
local interface = m.Interface
local clear = m.clear_table

---@class LootList
---@field get_items fun(): DistributableItem[]
---@field get_source_guid fun(): string

---@param loot_event_facade LootEventFacade
---@param item_utils ItemUtils
---@param api WowApi
---@return LootList
function M.new( loot_event_facade, item_utils, api )
  interface.validate( loot_event_facade, LEF.interface )
  interface.validate( item_utils, IU.interface )
  interface.validate( api, m.WowApi.LootFrameApi )

  local lef = loot_event_facade
  local items = {}
  local source_guid

  local function clear_items()
    clear( items )
    items.n = 0
    source_guid = nil
  end

  local function on_loot_opened()
    clear_items()
    source_guid = lef.get_source_guid()

    for slot = 1, lef.get_item_count() do
      local link = api.GetLootSlotLink( slot )
      local texture, _, _, quality = api.GetLootSlotInfo( slot )
      local item_id = link and item_utils.get_item_id( link )
      local item_name = link and item_utils.get_item_name( link )

      if item_id and item_name then
        table.insert( items, item_utils.make_distributable_item( item_id, item_name, link, quality, texture, slot ) )
      end
    end
  end

  local function on_loot_closed()
    clear_items()
  end

  local function on_loot_slot_cleared( slot )
    local index

    for i, item in ipairs( items ) do
      if item.slot == slot then
        index = i
        break
      end
    end

    if index then
      table.remove( items, index )
    end
  end

  local function get_items()
    m.dump( items )
    table.sort( items, function( a, b )
      if a.quality == b.quality then
        return a.name > b.name
      else
        return a.quality > b.quality
      end
    end )

    return items
  end

  loot_event_facade.subscribe( "LootOpened", on_loot_opened )
  loot_event_facade.subscribe( "LootClosed", on_loot_closed )
  loot_event_facade.subscribe( "LootSlotCleared", on_loot_slot_cleared )

  return {
    get_items = get_items,
    get_source_guid = function() return source_guid end
  }
end

m.LootList = M
return M
