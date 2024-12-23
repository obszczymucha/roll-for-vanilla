RollFor = RollFor or {}
local m = RollFor

if m.SoftResMatchedNameDecorator then return end

local M = {}

local map = m.map

-- I decorate given softres class with matched name logic.
-- Some players make typos in SoftRes.it and then their names don't match
-- their in-game names. NameMatcher fixes that.
function M.new( name_matcher, softres )
  local f = function( player )
    player.name = name_matcher.get_matched_name( player.name ) or player.name
    return player
  end

  local function get( item_id )
    return map( softres.get( item_id ), f )
  end

  local function get_all_players()
    return map( softres.get_all_players(), f )
  end

  local function is_player_softressing( player_name, item_id )
    local name = name_matcher.get_softres_name( player_name ) or player_name
    return softres.is_player_softressing( name, item_id )
  end

  local decorator = m.clone( softres )
  decorator.get = get
  decorator.get_all_players = get_all_players
  decorator.is_player_softressing = is_player_softressing

  return decorator
end

m.SoftResMatchedNameDecorator = M
return M
