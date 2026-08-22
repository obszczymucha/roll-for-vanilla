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
---@field UnitExists fun( unit: string ): number?
---@field GetRaidRosterInfo fun( index: number ): string?, string, number, number, PlayerClass, string, string

---@class GroupPlayer
---@field name string
---@field class PlayerClass?
---@field online boolean?
---@field unit string -- the token the inspect and tooltip APIs take

---@class GroupRoster
---@field get_all_players_in_my_group fun( f: (fun( player: Player ): boolean)? ): Player[]
---@field get_group_players fun(): GroupPlayer[]
---@field is_player_in_my_group fun( player_name: string ): boolean
---@field am_i_in_group fun(): boolean
---@field am_i_in_party fun(): boolean
---@field am_i_in_raid fun(): boolean
---@field find_player fun( player_name: string ): Player?
---@field get_group_unit_tokens fun(): string[]

---@param api GroupRosterApi
---@param player_info PlayerInfo
function M.new( api, player_info )
  local function sort( candidates )
    table.sort( candidates, function( lhs, rhs )
      -- class can be transiently nil during a group change; keep the player in
      -- the list and just order nil consistently instead of crashing.
      local lclass, rclass = lhs.class or "", rhs.class or ""

      if lclass ~= rclass then
        return lclass < rclass
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

  -- The same members in the same order as get_all_players_in_my_group, but with
  -- each player's unit token attached. Names are no good to the inspect and
  -- tooltip APIs, and unit tokens carry no class, so callers that need both
  -- would otherwise have to join the two lists themselves.
  ---@return GroupPlayer[]
  local function get_group_players()
    if not api.IsInGroup() then
      return { { name = player_info.get_name(), class = api.UnitClass( "player" ), unit = "player" } }
    end

    local result = {}

    if api.IsInRaid() then
      for i = 1, 40 do
        local name, _, _, _, class, _, location = api.GetRaidRosterInfo( i )

        if name then
          table.insert( result, {
            name = name,
            class = class,
            online = location ~= "Offline" and true or false,
            unit = "raid" .. i
          } )
        end
      end

      sort( result )
      return result
    end

    local party = { "player", "party1", "party2", "party3", "party4" }

    for _, unit in ipairs( party ) do
      local name = api.UnitName( unit )
      local class = api.UnitClass( unit )

      if name and class then
        table.insert( result, {
          name = name,
          class = class,
          online = api.UnitIsConnected( unit ) and true or false,
          unit = unit
        } )
      end
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

  -- Unit tokens are what the inspect and tooltip APIs take. Player names aren't.
  ---@return string[]
  local function get_group_unit_tokens()
    if not api.IsInGroup() then return { "player" } end

    local result = {}

    if api.IsInRaid() then
      for i = 1, 40 do
        local unit = "raid" .. i
        if api.UnitExists( unit ) then table.insert( result, unit ) end
      end

      return result
    end

    table.insert( result, "player" )

    for i = 1, 4 do
      local unit = "party" .. i
      if api.UnitExists( unit ) then table.insert( result, unit ) end
    end

    return result
  end

  ---@type GroupRoster
  return {
    get_all_players_in_my_group = get_all_players_in_my_group,
    get_group_players = get_group_players,
    is_player_in_my_group = is_player_in_my_group,
    am_i_in_group = am_i_in_group,
    am_i_in_party = am_i_in_party,
    am_i_in_raid = am_i_in_raid,
    find_player = find_player,
    get_group_unit_tokens = get_group_unit_tokens
  }
end

m.GroupRoster = M
return M
