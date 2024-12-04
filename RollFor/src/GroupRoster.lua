---@diagnostic disable-next-line: undefined-global
local modules = LibStub( "RollFor-Modules" )
if modules.GroupRoster then return end

local M = {}

function M.new( api )
  local function my_name()
    return api().UnitName( "player" )
  end

  local function get_all_players_in_my_group( f )
    local result = {}

    if not api().IsInGroup() then
      local name = my_name() -- This breaks in game if we dont assign it to the variable.
      local class = api().UnitClass( "player" )
      table.insert( result, { name = name, class = class } )
      return result
    end

    if api().IsInRaid() then
      for i = 1, 40 do
        local name, _, _, _, class, _, location = api().GetRaidRosterInfo( i )
        local player = { name = name, class = class, online = location ~= "Offline" and true or false }
        if name and (not f or f( player )) then table.insert( result, player ) end
      end
    else
      local party = { "player", "party1", "party2", "party3", "party4" }
      for _, v in ipairs( party ) do
        local name = api().UnitName( v )
        local class = api().UnitClass( v )
        local online = api().UnitIsConnected( v ) and true or false
        local player = { name = name, class = class, online = online }
        if name and (not f or f( player )) and class then table.insert( result, player ) end
      end
    end

    return result
  end

  local function is_player_in_my_group( player_name )
    local players = get_all_players_in_my_group()

    for _, player in pairs( players ) do
      if string.lower( player.name ) == string.lower( player_name ) then return true end
    end

    return false
  end

  local function am_i_in_group()
    return api().IsInGroup()
  end

  local function am_i_in_party()
    return api().IsInGroup() and not api().IsInRaid()
  end

  local function am_i_in_raid()
    return api().IsInGroup() and api().IsInRaid()
  end

  local function find_player( player_name )
    local players = get_all_players_in_my_group()

    for _, player in pairs( players ) do
      if string.lower( player.name ) == string.lower( player_name ) then return player end
    end
  end

  return {
    my_name = my_name,
    get_all_players_in_my_group = get_all_players_in_my_group,
    is_player_in_my_group = is_player_in_my_group,
    am_i_in_group = am_i_in_group,
    am_i_in_party = am_i_in_party,
    am_i_in_raid = am_i_in_raid,
    find_player = find_player
  }
end

modules.GroupRoster = M
return M
