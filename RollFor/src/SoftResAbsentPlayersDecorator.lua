---@diagnostic disable-next-line: undefined-global
local modules = LibStub( "RollFor-Modules" )
if modules.SoftResAbsentPlayersDecorator then return end

local M = {}

local filter = modules.filter
local negate = modules.negate
local clone = modules.clone

-- I decorate given softres class with absent players logic.
-- Example: "give me all players who soft-ressed but are not in the group".
function M.new( group_roster, softres )
  local f = negate( group_roster.is_player_in_my_group )

  local function get( item_id )
    return filter( softres.get( item_id ), f, "name" )
  end

  local function get_all_players()
    return filter( softres.get_all_players(), f, "name" )
  end

  local decorator = clone( softres )
  decorator.get = get
  decorator.get_all_players = get_all_players

  return decorator
end

modules.SoftResAbsentPlayersDecorator = M
return M
