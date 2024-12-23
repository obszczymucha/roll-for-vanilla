RollFor = RollFor or {}
local m = RollFor

if m.SoftResPresentPlayersDecorator then return end

local M = {}

local filter = m.filter
local map = m.map
local clone = m.clone

-- I decorate given softres class with present players logic.
-- Example: "give me all players who soft-ressed and are in the group".
-- I also enrich the player data with class name.
function M.new( group_roster, softres )
  local f = group_roster.is_player_in_my_group
  local enrich_class = function( p )
    local player = group_roster.find_player( p.name )
    p.class = player and player.class
    return p
  end

  local function get( item_id )
    return map( filter( softres.get( item_id ), f, "name" ), enrich_class )
  end

  local function get_all_players()
    return map( filter( softres.get_all_players(), f, "name" ), enrich_class )
  end

  local decorator = clone( softres )
  decorator.get = get
  decorator.get_all_players = get_all_players

  return decorator
end

m.SoftResPresentPlayersDecorator = M
return M
