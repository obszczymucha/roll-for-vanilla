RollFor = RollFor or {}
local m = RollFor

if m.MasterLootCandidates then return end

local M = {}

---@type MakeItemCandidateFn
local make_item_candidate = m.Types.make_item_candidate
---@type MakeWinnerFn
local make_winner = m.Types.make_winner

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

---@class MasterLootCandidatesApi
---@field GetMasterLootCandidate fun( slot: number, index: number ): string

---@class MasterLootCandidates
---@field get fun( slot: number ): ItemCandidate[]
---@field find fun( slot: number, player_name: string ): ItemCandidate?
---@field get_index fun( slot: number, player_name: string ): number?
---@field transform_to_winner fun( player: RollingPlayer, item: Item|MasterLootDistributableItem, roll_type: RollType, winning_roll: number?, rerolling: boolean? ): Winner

---@param api MasterLootCandidatesApi
---@param group_roster GroupRoster
---@param loot_list LootList
function M.new( api, group_roster, loot_list )
  local function get( slot )
    if not group_roster then return get_dummy_candidates() end

    local result = {}
    local players = group_roster.get_all_players_in_my_group()

    for i = 1, 40 do
      local name = api.GetMasterLootCandidate( slot, i )

      for _, p in ipairs( players ) do
        if name == p.name then
          table.insert( result, make_item_candidate( name, p.class, p.online ) )
        end
      end
    end

    return result
  end

  local function find( slot, player_name )
    local candidates = get( slot )

    return m.find_value_in_table( candidates, player_name, function( v ) return v.name end )
  end

  ---@param player RollingPlayer
  ---@param item Item|MasterLootDistributableItem
  ---@param roll_type RollType
  ---@param winning_roll number?
  ---@param rerolling boolean?
  ---@return Winner
  local function transform_to_winner( player, item, roll_type, winning_roll, rerolling )
    local slot = loot_list.get_slot( item.id )
    local candidate = slot and find( slot, player.name )
    return make_winner( player.name, player.class, item, candidate and true or false, roll_type, winning_roll and winning_roll, rerolling )
  end

  local function get_index( slot, player_name )
    for i = 1, 40 do
      local name = api.GetMasterLootCandidate( slot, i )
      if name == player_name then return i end
    end
  end

  ---@type MasterLootCandidates
  return {
    get = get,
    find = find,
    get_index = get_index,
    transform_to_winner = transform_to_winner
  }
end

m.MasterLootCandidates = M
return M
