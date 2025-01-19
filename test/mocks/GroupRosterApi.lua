local M = {}

local getn = table.getn

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
  local function count_players() return players and getn( players ) or 0 end

  local function is_in_party()
    local count = count_players()
    if count > 1 and not in_raid then return 1 end
  end

  local function is_in_raid()
    local count = count_players()
    if count > 1 and in_raid or count > 5 then return 1 end
  end

  local function unit_class( unit )
    local count = count_players()
    if not unit or not players or count == 0 then return end
  end

  local function get_raid_roster_info()
  end

  local function unit_name( unit )
    local count = count_players()
    if not players or count == 0 then return end

    if unit == M.player_unit then return players[ 1 ].name end

    if is_in_party() then
      for u, i in pairs( M.party_units ) do
        if unit == u and i <= count then return players[ i ].name end
      end

      return
    end

    for i = 1, 40 do
      if unit == "raid" .. i and i <= count then return players[ i ].name end
    end
  end

  local function get_player_by_unit( unit )
    if is_in_party() then
      local inde
    end
  end

  local function unit_is_connected( unit )
  end

  ---@type GroupRosterApi
  return {
    IsInGroup = function() return is_in_party() or is_in_raid() end,
    IsInParty = is_in_party,
    IsInRaid = is_in_raid,
    UnitClass = unit_class,
    GetRaidRosterInfo = get_raid_roster_info,
    UnitName = unit_name,
    UnitIsConnected = unit_is_connected
  }
end

return M
