RollFor = RollFor or {}
local m = RollFor

if m.SoftResAwardedLootDecorator then return end

local M = {}

local filter = m.filter

-- I decorate given softres class with awarded loot logic.
-- Example: "give me players who soft-ressed, but didn't receive the loot yet".
function M.new( awarded_loot, softres )
  local function get( item_id )
    return filter( softres.get( item_id ), function( v )
      return not awarded_loot.has_item_been_awarded( v.name, item_id )
    end )
  end

  local decorator = m.clone( softres )
  decorator.get = get

  return decorator
end

m.SoftResAwardedLootDecorator = M
return M
