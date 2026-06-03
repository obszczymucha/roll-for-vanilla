RollFor = RollFor or {}
local m = RollFor

if m.AwardedLoot then return end

local M = m.Module.new( "AwardedLoot" )

local getn = m.getn

---@class AwardedLootItemData
---@field item_id ItemId
---@field item_quantity number

---@param item_id ItemId
---@param item_quantity number?
---@return AwardedLootItemData
function M.awarded_loot_item_data( item_id, item_quantity )
  return {
    item_id = item_id,
    item_quantity = item_quantity or 1
  }
end

---@class AwardedLoot
---@field award fun( player_name: string, item_data: AwardedLootItemData )
---@field unaward fun( player_name: string, item_data: AwardedLootItemData )
---@field has_item_been_awarded fun( player_name: string, item_data: AwardedLootItemData ): boolean
---@field has_item_been_awarded_to_any_player fun( item_data: AwardedLootItemData ): boolean
---@field clear fun()

function M.new( db )
  db.awarded_items = db.awarded_items or {}

  ---@param player_name string
  ---@param item_data AwardedLootItemData
  local function award( player_name, item_data )
    M.debug.add( "award" )
    table.insert( db.awarded_items, { player_name = player_name, item_id = item_data.item_id } )
  end

  ---@param player_name string
  ---@param item_data AwardedLootItemData
  ---@return boolean
  local function has_item_been_awarded( player_name, item_data )
    local item_id = item_data.item_id
    for _, item in pairs( db.awarded_items ) do
      if item.player_name == player_name and item.item_id == item_id then return true end
    end

    return false
  end

  ---@param item_data AwardedLootItemData
  ---@return boolean
  local function has_item_been_awarded_to_any_player( item_data )
    local item_id = item_data.item_id
    for _, item in pairs( db.awarded_items ) do
      if item.item_id == item_id then return true end
    end

    return false
  end

  local function clear()
    M.debug.add( "clear" )
    m.clear_table( db.awarded_items )
  end

  ---@param player_name string
  ---@param item_data AwardedLootItemData
  local function unaward( player_name, item_data )
    M.debug.add( "unaward" )
    local item_id = item_data.item_id
    for i = getn( db.awarded_items ), 1, -1 do
      local awarded_item = db.awarded_items[ i ]

      if awarded_item.player_name == player_name and awarded_item.item_id == item_id then
        table.remove( db.awarded_items, i )
        return
      end
    end
  end

  ---@type AwardedLoot
  return {
    award = award,
    unaward = unaward,
    has_item_been_awarded = has_item_been_awarded,
    has_item_been_awarded_to_any_player = has_item_been_awarded_to_any_player,
    clear = clear
  }
end

m.AwardedLoot = M
return M
