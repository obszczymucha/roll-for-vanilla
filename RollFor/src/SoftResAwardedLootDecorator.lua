RollFor = RollFor or {}
local m = RollFor

if m.SoftResAwardedLootDecorator then return end

local M = {}

local filter = m.filter
local alid = m.AwardedLoot.awarded_loot_item_data

-- I decorate given softres class with awarded loot logic.
-- Example: "give me players who soft-ressed, but didn't receive the loot yet".
---@param awarded_loot AwardedLoot
---@param softres SoftRes
function M.new( awarded_loot, softres )
  local function get( item_data )
    return filter( softres.get( item_data ), function( v )
      local al_item = alid( item_data.item_id, item_data.item_quantity )
      return not awarded_loot.has_item_been_awarded( v.name, al_item )
    end )
  end

  local decorator = m.clone( softres )
  decorator.get = get

  local original_is_item_hardressed = decorator.is_item_hardressed

  ---@param item_id ItemId
  local function is_item_hardressed( item_id )
    local al_item = alid( item_id, 1 )
    return original_is_item_hardressed( item_id ) and not awarded_loot.has_item_been_awarded_to_any_player( al_item )
  end

  decorator.is_item_hardressed = is_item_hardressed

  return decorator
end

m.SoftResAwardedLootDecorator = M
return M
