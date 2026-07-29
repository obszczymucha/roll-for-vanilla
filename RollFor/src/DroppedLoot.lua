RollFor = RollFor or {}
local m = RollFor

if m.DroppedLoot then return end

local M = {}
local getn = m.getn

---@class DroppedLoot
---@field get_dropped_item_id fun( item_name: string ): number
---@field get_dropped_item_name fun( item_id: number ): string
---@field add fun( item_id: number, item_name: string )
---@field on_loot_opened fun()
---@field clear fun()

---@param db table
---@param loot_list LootList
---@param player_info PlayerInfo
---@return DroppedLoot
function M.new( db, loot_list, player_info )
  db.dropped_items = db.dropped_items or {}

  local function get_dropped_item_id( item_name )
    for _, item in pairs( db.dropped_items ) do
      if item.name == item_name then return item.id end
    end

    return nil
  end

  local function get_dropped_item_name( item_id )
    for _, item in pairs( db.dropped_items ) do
      if item.id == item_id then return item.name end
    end

    return nil
  end

  local function add( item_id, item_name )
    for _, item in pairs( db.dropped_items ) do
      if item.id == item_id then return end -- Already registered.
    end

    table.insert( db.dropped_items, { id = item_id, name = item_name } )
  end

  -- Whether an item is worth registering as dropped loot. Mirrors the
  -- quality/bind criteria of the loot announcement, but NOT its auto-loot or
  -- announce exclusions: an item that dropped must be registered so that
  -- trading it later is recognised as awarding it, regardless of whether it was
  -- auto-looted or announcements are turned off.
  ---@param item DroppedItem|Coin
  local function is_registerable( item )
    local BindType = m.ItemUtils.BindType
    local ItemQuality = m.Types.ItemQuality

    if not item.id or item.id == 29434 then return false end -- Badge of Justice is never awarded.

    local quality = item.quality or 0

    if item.bind == BindType.BindOnPickup and quality >= ItemQuality.Uncommon then
      return true
    end

    return quality >= m.api.GetLootThreshold()
  end

  -- Registers every awardable item currently in the loot. Must run before
  -- auto-loot clears the slots, so the loot is still present when we read it.
  local function on_loot_opened()
    if not player_info.is_master_looter() then return end

    for _, item in ipairs( loot_list.get_items() ) do
      if is_registerable( item ) then
        add( item.id, item.name )
      end
    end
  end

  local function clear()
    if getn( db.dropped_items ) == 0 then return end
    m.clear_table( db.dropped_items )
  end

  return {
    get_dropped_item_id = get_dropped_item_id,
    get_dropped_item_name = get_dropped_item_name,
    add = add,
    on_loot_opened = on_loot_opened,
    clear = clear
  }
end

m.DroppedLoot = M
return M
