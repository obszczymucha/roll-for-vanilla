RollFor = RollFor or {}
local m = RollFor

if m.DroppedLoot then return end

local M = {}
local getn = m.getn

-- What a loot window can be. A corpse and a chest are both loot the raid found and has to hand
-- out -- Zul'Aman's timed chests are exactly that -- while an Item is something a player opened
-- for themselves: a lockbox, or the disenchant window.
local DROP_SOURCES = {
  Creature = true,
  GameObject = true
}

---@class DroppedLoot
---@field get_dropped_item_id fun( item_name: string ): number
---@field get_dropped_item_name fun( item_id: number ): string
---@field add fun( item_id: number, item_name: string )
---@field on_loot_opened fun()
---@field clear fun()

---@param db table
---@param loot_list LootList
---@param player_info PlayerInfo
---@param boss_killed BossKilled
---@return DroppedLoot
function M.new( db, loot_list, player_info, boss_killed )
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
  -- quality/bind criteria of the loot announcement, but none of the reasons an
  -- item can be kept out of it: an item that dropped must be registered so that
  -- trading it later is recognised as awarding it, whoever took it and whether
  -- or not anybody was told.
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

  -- Whether this slot is loot the raid found, or something a player opened for
  -- themselves.
  --
  -- A loot window is a loot window: disenchanting and opening a lockbox raise
  -- the same events with the same slots as a corpse does, and neither dropped
  -- for anybody. Registering them would mean trading a shard to a guildmate
  -- counted as awarding them an item, and a boss credited with a kill for a
  -- disenchant. The source GUID's prefix is what separates them.
  ---@param slot number
  local function dropped_rather_than_opened( slot )
    local guid = loot_list.get_slot_source( slot )
    local source = guid and string.match( guid, "^(%a+)%-" )

    return source and DROP_SOURCES[ source ] and true or false
  end

  -- Registers every awardable item currently in the loot. Must run before anything
  -- clears the slots, so the loot is still present when we read it -- and so is the
  -- source, which is forgotten with the slot. That is what its position at the head
  -- of the LootOpened pipeline is for.
  local function on_loot_opened()
    if not player_info.is_master_looter() then return end

    for slot, item in pairs( loot_list.get_items_by_slot() ) do
      if dropped_rather_than_opened( slot ) and is_registerable( item ) then
        add( item.id, item.name )
        -- Told about every drop, not just the first: which of them names a boss
        -- and whether that boss is already on the list is its own business.
        boss_killed.on_item_dropped( item.id )
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
