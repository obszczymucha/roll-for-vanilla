RollFor = RollFor or {}
local m = RollFor
if m.LootListSoftresDecorator then return end

local M = {}

function M.new( loot_list, softres )
  local function get_items()
    local result = loot_list.get_items()

    m.map( result, function( item )
      item.softressing_players = softres.get( item.id )
      return item
    end )
  end

  local decorator = m.clone( loot_list )
  decorator.get_items = get_items

  return decorator
end

m.LootListSoftresDecorator = M
return M
