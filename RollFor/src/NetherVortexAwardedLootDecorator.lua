RollFor = RollFor or {}
local m = RollFor

if m.NetherVortexAwardedLootDecorator then return end

local M = {}

local NETHER_VORTEX_ID = 30183

---@param awarded_loot AwardedLoot
function M.new( awarded_loot )
  local vortex_awards = {}

  ---@param player_name string
  ---@param item_data AwardedLootItemData
  local function award( player_name, item_data )
    if item_data.item_id == NETHER_VORTEX_ID then
      vortex_awards[ player_name ] = vortex_awards[ player_name ] or {}
      vortex_awards[ player_name ][ item_data.item_quantity ] = true
    end

    awarded_loot.award( player_name, item_data )
  end

  ---@param player_name string
  ---@param item_data AwardedLootItemData
  ---@return boolean
  local function has_item_been_awarded( player_name, item_data )
    if item_data.item_id ~= NETHER_VORTEX_ID then
      return awarded_loot.has_item_been_awarded( player_name, item_data )
    end

    local player_awards = vortex_awards[ player_name ]
    if not player_awards then return false end

    return player_awards[ item_data.item_quantity ] == true
  end

  ---@param item_data AwardedLootItemData
  ---@return boolean
  local function has_item_been_awarded_to_any_player( item_data )
    if item_data.item_id ~= NETHER_VORTEX_ID then
      return awarded_loot.has_item_been_awarded_to_any_player( item_data )
    end

    for _, player_awards in pairs( vortex_awards ) do
      if player_awards[ item_data.item_quantity ] then return true end
    end

    return false
  end

  ---@param player_name string
  ---@param item_data AwardedLootItemData
  local function unaward( player_name, item_data )
    if item_data.item_id == NETHER_VORTEX_ID then
      local player_awards = vortex_awards[ player_name ]
      if player_awards then
        player_awards[ item_data.item_quantity ] = nil
      end
    end

    awarded_loot.unaward( player_name, item_data )
  end

  local function clear()
    vortex_awards = {}
    awarded_loot.clear()
  end

  return {
    award = award,
    unaward = unaward,
    has_item_been_awarded = has_item_been_awarded,
    has_item_been_awarded_to_any_player = has_item_been_awarded_to_any_player,
    clear = clear
  }
end

m.NetherVortexAwardedLootDecorator = M
return M
