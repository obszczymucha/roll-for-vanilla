RollFor = RollFor or {}
local m = RollFor

if m.MasterLootCandidates then return end

local M = {}

local function get_dummy_candidates()
  return {
    { name = "Ohhaimark",    class = "Warrior", value = 1 },
    { name = "Obszczymucha", class = "Druid",   value = 2 },
    { name = "Jogobobek",    class = "Hunter",  value = 3 },
    { name = "Xiaorotflmao", class = "Shaman",  value = 4 },
    { name = "Kacprawcze",   class = "Priest",  value = 5 },
    { name = "Psikutas",     class = "Paladin", value = 6 },
    { name = "Motoko",       class = "Rogue",   value = 7 },
    { name = "Blanchot",     class = "Warrior", value = 8 },
    { name = "Adamsandler",  class = "Druid",   value = 9 },
    { name = "Johnstamos",   class = "Hunter",  value = 10 },
    { name = "Xiaolmao",     class = "Shaman",  value = 11 },
    { name = "Ronaldtramp",  class = "Priest",  value = 12 },
    { name = "Psikuta",      class = "Paladin", value = 13 },
    { name = "Kusanagi",     class = "Rogue",   value = 14 },
    { name = "Chuj",         class = "Priest",  value = 15 },
  }
end

function M.new( group_roster )
  local function sort( candidates )
    table.sort( candidates, function( lhs, rhs )
      if lhs.class < rhs.class then
        return true
      elseif lhs.class > rhs.class then
        return false
      end

      return lhs.name < rhs.name
    end )
  end

  local function get()
    if not group_roster then return get_dummy_candidates() end

    local result = {}
    local players = group_roster.get_all_players_in_my_group()

    for i = 1, 40 do
      local name = m.api.GetMasterLootCandidate( i )

      for _, p in ipairs( players ) do
        if name == p.name then
          table.insert( result, { name = name, class = p.class, value = i } )
        end
      end
    end

    sort( result )

    return result
  end

  local function find( player_name )
    local candidates = get()

    return m.find_value_in_table( candidates, player_name, function( v ) return v.name end )
  end

  return {
    get = get,
    find = find
  }
end

m.MasterLootCandidates = M
return M
