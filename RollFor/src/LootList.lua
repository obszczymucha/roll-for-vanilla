RollFor = RollFor or {}
local m = RollFor
if m.LootList then return end

local M = m.Module.new( "LootList" )

local getn = m.getn
local interface = m.Interface
local clear = m.clear_table

---@class LootList
---@field get_items fun(): DroppedItem[]
---@field get_source_guid fun(): string
---@field get_slot fun( item_id: number|"Coin" ): number?
---@field is_looting fun(): boolean
---@field count fun( item_id: number ): number
---@field size fun(): number

---@param loot_facade LootFacade
---@param item_utils ItemUtils
---@param tooltip_reader TooltipReader
---@return LootList
function M.new( loot_facade, item_utils, tooltip_reader, dummy_items_fn )
  interface.validate( loot_facade, m.LootFacade.interface )
  interface.validate( item_utils, m.ItemUtils.interface )

  ---@alias Slot number
  ---@type table<Slot, Coin|DroppedItem>
  local items = {}
  local lf = loot_facade
  local looting = false
  local source_guid

  local function clear_items()
    clear( items )
    source_guid = nil
  end

  local function add_item( slot, item, item_count )
    local dummy_items = dummy_items_fn and dummy_items_fn() or {}
    local dummy_item_count = getn( dummy_items )
    local new_item = item_count > dummy_item_count and item or dummy_items[ item_count ]

    items[ slot ] = new_item
  end

  local function on_loot_opened()
    M.debug.add( "loot_opened" )
    clear_items()
    looting = true
    source_guid = lf.get_source_guid()

    local item_count = 1

    for slot = 1, lf.get_item_count() do
      if lf.is_coin( slot ) then
        local info = lf.get_info( slot )

        if info then
          items[ slot ] = item_utils.make_coin( info.texture, info.name )
        end
      else
        local link = lf.get_link( slot )
        local info = lf.get_info( slot )
        local item_id = link and item_utils.get_item_id( link )
        local item_name = link and item_utils.get_item_name( link )
        local tooltip_link = link and item_utils.get_tooltip_link( link )
        local bind_type = tooltip_reader.get_slot_bind_type( slot )

        if item_id and item_name then
          add_item( slot,
            item_utils.make_dropped_item(
              item_id,
              item_name,
              link,
              tooltip_link,
              info and info.quality,
              info and info.quantity,
              info and info.texture,
              bind_type
            ), item_count )

          item_count = item_count + 1
        end
      end
    end
  end

  local function on_loot_closed()
    M.debug.add( "loot_closed" )
    clear_items()
    looting = false
  end

  local function on_loot_slot_cleared( slot )
    M.debug.add( "loot_slot_cleared" )
    items[ slot ] = nil
  end

  local function get_items()
    local result = {}

    for _, item in pairs( items ) do
      table.insert( result, item )
    end

    return result
  end

  loot_facade.subscribe( "LootOpened", on_loot_opened )
  loot_facade.subscribe( "LootClosed", on_loot_closed )
  loot_facade.subscribe( "LootSlotCleared", on_loot_slot_cleared )

  ---@param item_id number|"Coin"
  ---@return number?
  local function get_slot( item_id )
    for slot, item in pairs( items ) do
      if item_id == "Coin" and item.type == "Coin" then
        return slot
      end

      if item.id == item_id then
        return slot
      end
    end
  end

  local function is_looting()
    return looting
  end

  local function count( item_id )
    local result = 0

    for _, item in pairs( items ) do
      if item.id == item_id then
        result = result + 1
      end
    end

    return result
  end

  local function size()
    local result = 0

    for _ in pairs( items ) do
      result = result + 1
    end

    return 0
  end

  ---@type LootList
  return {
    get_items = get_items,
    get_source_guid = function() return source_guid end,
    get_slot = get_slot,
    is_looting = is_looting,
    count = count,
    size = size
  }
end

m.LootList = M
return M
