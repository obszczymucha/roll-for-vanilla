RollFor = RollFor or {}
local m = RollFor

if m.LootAwardCallback then return end

local M = m.Module.new( "LootAwardCallback" )

---@class LootAwardCallback
---@field on_loot_awarded fun( item_id: number, item_link: string, player_name: string, player_class: string?, item_quantity: number? )

local alid = m.AwardedLoot.awarded_loot_item_data

---@param awarded_loot AwardedLoot
---@param roll_controller RollController
---@param winner_tracker WinnerTracker
---@param group_roster GroupRoster
function M.new( awarded_loot, roll_controller, winner_tracker, group_roster )
  ---@param item_id number
  ---@param item_link string
  ---@param player_name string
  ---@param player_class PlayerClass?
  ---@param item_quantity number?
  local function on_loot_awarded( item_id, item_link, player_name, player_class, item_quantity )
    M.debug.add( string.format( "on_loot_awarded( %s, %s, %s, %s )", item_id, item_link, player_name, player_class or "nil" ) )
    local al_item = alid( item_id, item_quantity )
    awarded_loot.award( player_name, al_item )

    if player_class then
      roll_controller.loot_awarded( item_id, item_link, player_name, player_class )
    else
      local player = group_roster.find_player( player_name )
      local class = player and player.class or nil
      roll_controller.loot_awarded( item_id, item_link, player_name, class )
    end

    winner_tracker.untrack( player_name, item_link )
  end

  ---@type LootAwardCallback
  return {
    on_loot_awarded = on_loot_awarded,
  }
end

m.LootAwardCallback = M
return M
