local M = {}

M.player_unit = "player"
M.party_units = {
  [ M.player_unit ] = 1,
  [ "party1" ] = 2,
  [ "party2" ] = 3,
  [ "party3" ] = 4,
  [ "party4" ] = 5
}

---@param players Player[]?
---@param in_raid boolean?
function M.new( players, in_raid )
  local function count_players() return players and #players or 0 end

  local function is_in_party()
    local count = count_players()
    if count > 1 and not in_raid then return 1 end
  end

  local function is_in_raid()
    local count = count_players()
    if count > 1 and in_raid or count > 5 then return 1 end
  end

  local function get_player_by_unit( unit )
    local count = count_players()
    if not players or count == 0 then return end
    if unit == M.player_unit then return players[ 1 ] end

    if is_in_party() then
      local index = M.party_units[ unit ]
      if index and index <= count then return players[ index ] end
      return
    end

    for index in string.gmatch( unit, "raid(%d+)" ) do
      local i = tonumber( index )
      if i <= count then return players[ i ] end
    end
  end

  local function unit_name( unit )
    local player = get_player_by_unit( unit )
    return player and player.name
  end

  local function unit_class( unit )
    local player = get_player_by_unit( unit )
    return player and player.class
  end

  local function unit_is_connected( unit )
    local player = get_player_by_unit( unit )
    return player and player.online
  end

  local function get_raid_roster_info( index )
    if not is_in_raid() then return end

    local player = players and players[ tonumber( index ) ]
    if not player then return end

    return player.name, nil, nil, nil, player.class, nil, player.online and "PrincessKenny's Castle" or "Offline"
  end

  ---@type GroupRosterApi
  return {
    IsInParty = is_in_party,
    IsInRaid = is_in_raid,
    IsInGroup = function() return is_in_party() or is_in_raid() end,
    UnitName = unit_name,
    UnitClass = unit_class,
    UnitIsConnected = unit_is_connected,
    GetRaidRosterInfo = get_raid_roster_info
  }
end

return M
