RollFor = RollFor or {}
local m = RollFor

if m.RollingLogicUtils then return end

local M = {}
local map = m.map

---@type MakeRollingPlayerFn
local make_rolling_player = m.Types.make_rolling_player

function M.can_roll( rollers, player_name )
  for _, v in ipairs( rollers ) do
    if v.name == player_name then return true end
  end

  return false
end

---@param roller RollingPlayer
function M.copy_roller( roller )
  return make_rolling_player( roller.name, roller.class, roller.online, roller.rolls )
end

---@param rollers RollingPlayer[]
function M.copy_rollers( rollers )
  local result = {}

  for k, v in pairs( rollers ) do
    result[ k ] = M.copy_roller( v )
  end

  return result
end

function M.one_roll( player_name )
  return { name = player_name, rolls = 1 }
end

function M.all_present_players( group_roster )
  local player_names = map( group_roster.get_all_players_in_my_group(), function( p ) return p.name end )
  return map( player_names, M.one_roll )
end

function M.have_all_players_rolled( rollers )
  if #rollers == 0 then return false end

  for _, v in pairs( rollers ) do
    if v.rolls > 0 then return false end
  end

  return true
end

function M.sort_rolls( rolls, roll_type )
  local function to_roll_map()
    local result = {}

    for _, roll in pairs( rolls ) do
      if not result[ roll ] then result[ roll ] = true end
    end

    return result
  end

  local function to_map( roll_map )
    local result = {}

    for player_name, roll in pairs( roll_map ) do
      if result[ roll ] then
        table.insert( result[ roll ].players, player_name )
      else
        result[ roll ] = { roll = roll, players = { player_name }, roll_type = roll_type }
      end
    end

    return result
  end

  local function f( l, r )
    if l > r then
      return true
    else
      return false
    end
  end

  local function to_sorted_rolls_array( rollmap )
    local result = {}

    for k in pairs( rollmap ) do
      table.insert( result, k )
    end

    table.sort( result, f )
    return result
  end

  local sorted_rolls = to_sorted_rolls_array( to_roll_map() )
  local rollmap = to_map( rolls )

  return map( sorted_rolls, function( v ) return rollmap[ v ] end )
end

function M.has_rolls_left( rollers, player_name )
  for _, v in pairs( rollers ) do
    if v.name == player_name then
      return v.rolls > 0
    end
  end

  return false
end

m.RollingLogicUtils = M
return M
