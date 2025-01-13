RollFor = RollFor or {}
local m = RollFor
if m.LootList then return end

local M = m.Module.new( "LootList" )
local interface = m.Interface
local clear = m.clear_table
local getn = table.getn

---@class LootList
---@field get_items fun(): DistributableItem[]
---@field get_source_guid fun(): string
---@field find_item fun( item_id: number ): DistributableItem?
---@field is_looting fun(): boolean
---@field count fun( item_id: number ): number

---@param loot_facade LootFacade
---@param item_utils ItemUtils
---@return LootList
function M.new( loot_facade, item_utils, dummy_items_fn )
  interface.validate( loot_facade, m.LootFacade.interface )
  interface.validate( item_utils, m.ItemUtils.interface )

  local lf = loot_facade
  local items = {}
  local looting = false
  local source_guid

  local function clear_items()
    clear( items )
    items.n = 0
    source_guid = nil
  end

  local function add_item( item, i )
    local dummy_items = dummy_items_fn and dummy_items_fn() or {}
    local dummy_item_count = getn( dummy_items )
    local new_item = i > dummy_item_count and item or dummy_items[ i ]

    table.insert( items, new_item )
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
          table.insert( items, item_utils.make_coin( info.texture, info.name, slot ) )
        end
      else
        local link = lf.get_link( slot )
        local info = lf.get_info( slot )
        local item_id = link and item_utils.get_item_id( link )
        local item_name = link and item_utils.get_item_name( link )
        local tooltip_link = link and item_utils.get_tooltip_link( link )

        if item_id and item_name then
          add_item(
            item_utils.make_distributable_item(
              item_id,
              item_name,
              link,
              tooltip_link,
              info and info.quality,
              info and info.quantity,
              info and info.texture,
              slot
            ), item_count )

          item_count = item_count + 1
        end
      end
    end

    for i, item in ipairs( items ) do
      item.index = i
    end
  end

  local function on_loot_closed()
    M.debug.add( "loot_closed" )
    clear_items()
    looting = false
  end

  local function on_loot_slot_cleared( slot )
    M.debug.add( "loot_slot_cleared" )
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
    return items
  end

  loot_facade.subscribe( "LootOpened", on_loot_opened )
  loot_facade.subscribe( "LootClosed", on_loot_closed )
  loot_facade.subscribe( "LootSlotCleared", on_loot_slot_cleared )

  ---@return DistributableItem?
  local function find_item( item_id )
    for _, item in ipairs( items ) do
      if item.id == item_id then
        return item
      end
    end
  end

  local function is_looting()
    return looting
  end

  local function count( item_id )
    local result = 0

    for _, item in ipairs( items ) do
      if item.id == item_id then
        result = result + 1
      end
    end

    return result
  end

  return {
    get_items = get_items,
    get_source_guid = function() return source_guid end,
    find_item = find_item,
    is_looting = is_looting,
    count = count
  }
end

m.LootList = M
return M
