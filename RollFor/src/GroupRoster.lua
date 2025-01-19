RollFor = RollFor or {}
local m = RollFor

if m.GroupRoster then return end

local M = {}

---@type MakePlayerFn
local make_player = m.Types.make_player

---@class GroupRosterApi
---@field IsInParty fun(): number?
---@field IsInRaid fun(): number?
---@field IsInGroup fun(): number?
---@field UnitName fun( unit: string ): string?
---@field UnitClass fun( unit: string ): string?
---@field UnitIsConnected fun( unit: string ): number?
---@field GetRaidRosterInfo fun( index: number ): string?, string, number, number, PlayerClass, string, string

---@class GroupRoster
---@field get_all_players_in_my_group fun( f: (fun( player: Player ): boolean)? ): Player[]
---@field is_player_in_my_group fun( player_name: string ): boolean
---@field am_i_in_group fun(): boolean
---@field am_i_in_party fun(): boolean
---@field am_i_in_raid fun(): boolean
---@field find_player fun( player_name: string ): Player?

---@param api GroupRosterApi
---@param player_info PlayerInfo
function M.new( api, player_info )
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

  local function get_all_players_in_my_group( f )
    local result = {}

    if not api.IsInGroup() then
      local name = player_info.get_name()
      local class = api.UnitClass( "player" )
      table.insert( result, { name = name, class = class } )

      return result
    end

    if api.IsInRaid() then
      for i = 1, 40 do
        local name, _, _, _, class, _, location = api.GetRaidRosterInfo( i )
        local player = { name = name, class = class, online = location ~= "Offline" and true or false }
        if name and (not f or f( player )) then table.insert( result, player ) end
      end

      sort( result )
      return result
    end

    local party = { "player", "party1", "party2", "party3", "party4" }

    for _, v in ipairs( party ) do
      local name = api.UnitName( v )
      local class = api.UnitClass( v )
      local online = api.UnitIsConnected( v ) and true or false
      local player = name and class and make_player( name, class, online )
      if player and (not f or f( player )) then table.insert( result, player ) end
    end

    sort( result )
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
    return api.IsInGroup()
  end

  local function am_i_in_party()
    return api.IsInGroup() and not api.IsInRaid()
  end

  local function am_i_in_raid()
    return api.IsInGroup() and api.IsInRaid()
  end

  local function find_player( player_name )
    local players = get_all_players_in_my_group()

    for _, player in pairs( players ) do
      if string.lower( player.name ) == string.lower( player_name ) then return player end
    end
  end

  ---@type GroupRoster
  return {
    get_all_players_in_my_group = get_all_players_in_my_group,
    is_player_in_my_group = is_player_in_my_group,
    am_i_in_group = am_i_in_group,
    am_i_in_party = am_i_in_party,
    am_i_in_raid = am_i_in_raid,
    find_player = find_player
  }
end

m.GroupRoster = M
return M
