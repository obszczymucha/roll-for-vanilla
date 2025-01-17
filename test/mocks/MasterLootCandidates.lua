local M = {}

local Types = require( "src/Types" )
local make_item_candidate = Types.make_item_candidate

---@param group_roster
function M.new( group_roster )
  local function get()
    local result = {}
    local players = group_roster.get_all_players_in_my_group()

    for i, p in ipairs( players ) do
      table.insert( result, make_item_candidate( p.name, p.class, p.online ) )
    end

    return result
  end

  local function find( player_name )
    local candidates = get()
    for _, v in ipairs( candidates ) do
      if v.name == player_name then return v end
    end
  end

  ---@type MasterLootCandidates
  return {
    get = get,
    find = find,
    get_index = get_index,
  }
end
