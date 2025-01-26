RollFor = RollFor or {}
local m = RollFor

if m.LootAwardCallback then return end

local M = m.Module.new( "LootAwardCallback" )

---@class LootAwardCallback
---@field on_loot_awarded fun( player_name: string, item_id: number, item_link: string )

---@param awarded_loot AwardedLoot
---@param roll_controller RollController
---@param winner_tracker WinnerTracker
function M.new( awarded_loot, roll_controller, winner_tracker )
  ---@param player_name string
  ---@param item_id number
  ---@param item_link string
  local function on_loot_awarded( player_name, item_id, item_link )
    M.debug.add( string.format( "on_loot_awarded(%s, %s, %s)", player_name, item_id, item_link ) )
    awarded_loot.award( player_name, item_id )
    roll_controller.loot_awarded( player_name, item_id, item_link )
    winner_tracker.untrack( player_name, item_link )
  end

  ---@type LootAwardCallback
  return {
    on_loot_awarded = on_loot_awarded,
  }
end

m.LootAwardCallback = M
return M
