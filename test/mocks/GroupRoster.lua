local M = {}

local getn = table.getn

---@param players Player[]?
---@param in_party boolean?
---@param in_raid boolean?
function M.new( players, in_party, in_raid )
  local function get_all_players()
    return players or {}
  end

  local function find_player( player_name )
    for _, player in ipairs( get_all_players() ) do
      if player.name == player_name then return player end
    end
  end

  local function am_i_in_party()
    return in_party and true or false
  end

  local function am_i_in_raid()
    return in_raid and true or getn( get_all_players() ) > 0 and true or false
  end

  ---@type GroupRoster
  return {
    get_all_players_in_my_group = function() return players or {} end,
    is_player_in_my_group = function( player_name ) return find_player( player_name ) and true or false end,
    get_all_players = get_all_players,
    am_i_in_group = function() return am_i_in_party() or am_i_in_raid() end,
    am_i_in_party = am_i_in_party,
    am_i_in_raid = am_i_in_raid,
    find_player = find_player,
  }
end

return M
