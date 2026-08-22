package.path = "./?.lua;" .. package.path .. ";../?.lua;../RollFor/?.lua;../RollFor/libs/?.lua"

local u = require( "test/utils" )
local lu, eq = u.luaunit( "assertEquals" )
local mocking = require( "test/mocking" )
local mock, mock_api = mocking.mock, mocking.mock_api
local smart_table, packed_value = mocking.smart_table, mocking.packed_value

require( "test/utils" ) -- Need to load this before modules to load lua50 stuff.
require( "src/modules" )
require( "src/Types" )

local mock_player_info = require( "mocks/PlayerInfo" ).new
local gr = require( "src/GroupRoster" )

local function player( name )
  return function()
    return {
      mock( "UnitName", smart_table( { [ "player" ] = name } ) ),
      mock( "IsInGroup", false ),
      mock( "UnitClass", "Warrior" )
    }
  end
end

local function make_warriors( players )
  local result = {}

  for _, name in ipairs( players ) do
    table.insert( result, packed_value( { name, "Officer", 1, 60, "Warrior", "Stormwind", "Online" } ) )
  end

  return result
end

local function group( _player, is_in_raid, ... )
  local args = { ... }
  local all_players = { _player, table.unpack( args ) }

  return function()
    return {
      mock( "UnitName", smart_table( {
        [ "player" ] = _player,
        [ "party1" ] = args[ 1 ],
        [ "party2" ] = args[ 2 ],
        [ "party3" ] = args[ 3 ],
        [ "party4" ] = args[ 4 ]
      } ) ),
      mock( "IsInGroup", true ),
      mock( "IsInRaid", is_in_raid ),
      mock( "UnitClass", "Warrior" ), -- For simplicity everyone is a warrior.
      mock( "GetRaidRosterInfo", smart_table( make_warriors( all_players ) ) ),
      mock( "UnitIsConnected", true )
    }
  end
end

local function party( _player, ... )
  return group( _player, false, ... )
end

local function raid( _player, ... )
  return group( _player, true, ... )
end

local function raid_units( ... )
  local names = { ... }
  local unit_names = { [ "player" ] = names[ 1 ] }
  local exists = { [ "player" ] = packed_value( { 1 } ) }

  for i, name in ipairs( names ) do
    unit_names[ "raid" .. i ] = name
    exists[ "raid" .. i ] = packed_value( { 1 } )
  end

  return function()
    return {
      mock( "UnitName", smart_table( unit_names ) ),
      mock( "UnitExists", smart_table( exists ) ),
      mock( "IsInGroup", true ),
      mock( "IsInRaid", true )
    }
  end
end

local function party_units( _player, ... )
  local args = { ... }
  local unit_names = { [ "player" ] = _player }
  local exists = { [ "player" ] = packed_value( { 1 } ) }

  for i, name in ipairs( args ) do
    unit_names[ "party" .. i ] = name
    exists[ "party" .. i ] = packed_value( { 1 } )
  end

  return function()
    return {
      mock( "UnitName", smart_table( unit_names ) ),
      mock( "UnitExists", smart_table( exists ) ),
      mock( "IsInGroup", true ),
      mock( "IsInRaid", false )
    }
  end
end

GetAllPlayersInMyGroupSpec = {}

function GetAllPlayersInMyGroupSpec:should_return_my_name_if_not_in_group()
  -- Given
  local my_name = "Psikutas"
  local api = mock_api( player( my_name ) )
  local mod = gr.new( api(), mock_player_info( my_name ) )

  -- When
  local result = mod.get_all_players_in_my_group()

  -- Then
  eq( result, { { class = "Warrior", name = "Psikutas" } } )
end

function GetAllPlayersInMyGroupSpec:should_return_all_players_in_party_sorted()
  -- Given
  local api = mock_api( party( "Psikutas", "Obszczymucha" ) )
  local mod = gr.new( api(), mock_player_info() )

  -- When
  local result = mod.get_all_players_in_my_group()

  -- Then
  eq( result, {
    { class = "Warrior", name = "Obszczymucha", online = true, type = "Player" },
    { class = "Warrior", name = "Psikutas",     online = true, type = "Player" }
  } )
end

function GetAllPlayersInMyGroupSpec:should_return_all_players_in_raid_sorted()
  -- Given
  local api = mock_api( raid( "Psikutas", "Obszczymucha" ) )
  local mod = gr.new( api(), mock_player_info() )

  -- When
  local result = mod.get_all_players_in_my_group()

  -- Then
  eq( result, {
    { class = "Warrior", name = "Obszczymucha", online = true },
    { class = "Warrior", name = "Psikutas",     online = true }
  } )
end

function GetAllPlayersInMyGroupSpec:should_keep_raid_members_whose_class_is_not_populated_yet()
  -- During a group change GetRaidRosterInfo can momentarily return a member
  -- with a name but no class. The player must still be in the list (not
  -- dropped) and sort() must not crash comparing the nil class.
  local api = mock_api( function()
    return {
      mock( "IsInGroup", true ),
      mock( "IsInRaid", true ),
      mock( "UnitClass", "Warrior" ),
      mock( "GetRaidRosterInfo", smart_table( {
        packed_value( { "Psikutas", "Officer", 1, 60, "Warrior", "Stormwind", "Online" } ),
        packed_value( { "Obszczymucha", "Officer", 1, 60 } ) -- class not populated yet
      } ) ),
      mock( "UnitIsConnected", true )
    }
  end )
  local mod = gr.new( api(), mock_player_info() )

  -- When
  local result = mod.get_all_players_in_my_group()

  -- Then
  eq( result, {
    { name = "Obszczymucha", online = true },
    { class = "Warrior", name = "Psikutas", online = true }
  } )
end

IsPlayerInMyGroupSpec = {}

function IsPlayerInMyGroupSpec:should_return_true_for_myself()
  -- Given
  local my_name = "Psikutas"
  local api = mock_api( player( my_name ) )
  local mod = gr.new( api(), mock_player_info( my_name ) )

  -- When
  local result = mod.is_player_in_my_group( my_name )

  -- Then
  eq( result, true )
end

function IsPlayerInMyGroupSpec:should_return_false_for_someone_else_if_not_in_group()
  -- Given
  local api = mock_api( player( "Psikutas" ) )
  local mod = gr.new( api(), mock_player_info() )

  -- When
  local result = mod.is_player_in_my_group( "Obszczymucha" )

  -- Then
  eq( result, false )
end

function IsPlayerInMyGroupSpec:should_return_true_for_myself_if_in_party()
  -- Given
  local my_name = "Psikutas"
  local api = mock_api( party( my_name, "Obszczymucha" ) )
  local mod = gr.new( api(), mock_player_info( my_name ) )

  -- When
  local result = mod.is_player_in_my_group( my_name )

  -- Then
  eq( result, true )
end

function IsPlayerInMyGroupSpec:should_return_true_for_myself_if_in_raid()
  -- Given
  local my_name = "Psikutas"
  local api = mock_api( raid( my_name, "Obszczymucha" ) )
  local mod = gr.new( api(), mock_player_info( my_name ) )

  -- When
  local result = mod.is_player_in_my_group( my_name )

  -- Then
  eq( result, true )
end

function IsPlayerInMyGroupSpec:should_return_true_for_someone_else_in_party()
  -- Given
  local api = mock_api( party( "Psikutas", "Obszczymucha" ) )
  local mod = gr.new( api(), mock_player_info() )

  -- When
  local result = mod.is_player_in_my_group( "Obszczymucha" )

  -- Then
  eq( result, true )
end

function IsPlayerInMyGroupSpec:should_return_true_for_someone_else_in_raid()
  -- Given
  local api = mock_api( raid( "Psikutas", "Obszczymucha" ) )
  local mod = gr.new( api(), mock_player_info() )

  -- When
  local result = mod.is_player_in_my_group( "Obszczymucha" )

  -- Then
  eq( result, true )
end

function IsPlayerInMyGroupSpec:should_return_true_for_someone_else_not_in_party()
  -- Given
  local api = mock_api( party( "Psikutas", "Obszczymucha" ) )
  local mod = gr.new( api(), mock_player_info() )

  -- When
  local result = mod.is_player_in_my_group( "Ponpon" )

  -- Then
  eq( result, false )
end

function IsPlayerInMyGroupSpec:should_return_true_for_someone_else_not_in_raid()
  -- Given
  local api = mock_api( raid( "Psikutas", "Obszczymucha" ) )
  local mod = gr.new( api(), mock_player_info() )

  -- When
  local result = mod.is_player_in_my_group( "Ponpon" )

  -- Then
  eq( result, false )
end

AmIInGroupSpec = {}

function AmIInGroupSpec:should_return_false_if_not_in_group()
  -- Given
  local api = mock_api( player( "Psikutas" ) )

  -- When
  local mod = gr.new( api(), mock_player_info() )

  -- Then
  eq( mod.am_i_in_group(), false )
  eq( mod.am_i_in_party(), false )
  eq( mod.am_i_in_raid(), false )
end

function AmIInGroupSpec:should_return_true_if_in_party()
  -- Given
  local api = mock_api( party( "Psikutas", "Obszczymucha" ) )

  -- When
  local mod = gr.new( api(), mock_player_info() )

  -- Then
  eq( mod.am_i_in_group(), true )
  eq( mod.am_i_in_party(), true )
  eq( mod.am_i_in_raid(), false )
end

function AmIInGroupSpec:should_return_true_if_in_raid()
  -- Given
  local api = mock_api( raid( "Psikutas", "Obszczymucha" ) )

  -- When
  local mod = gr.new( api(), mock_player_info() )

  -- Then
  eq( mod.am_i_in_group(), true )
  eq( mod.am_i_in_party(), false )
  eq( mod.am_i_in_raid(), true )
end

GetGroupUnitTokensSpec = {}

function GetGroupUnitTokensSpec:should_return_the_player_when_solo()
  -- Given
  local api = mock_api( player( "Psikutas" ) )
  local mod = gr.new( api(), mock_player_info( "Psikutas" ) )

  -- When / Then
  eq( mod.get_group_unit_tokens(), { "player" } )
end

function GetGroupUnitTokensSpec:should_return_party_tokens()
  -- Given
  local api = mock_api( party_units( "Psikutas", "Obszczymucha", "Ohhaimark" ) )
  local mod = gr.new( api(), mock_player_info( "Psikutas" ) )

  -- When / Then
  eq( mod.get_group_unit_tokens(), { "player", "party1", "party2" } )
end

function GetGroupUnitTokensSpec:should_return_raid_tokens()
  -- Given
  local api = mock_api( raid_units( "Psikutas", "Obszczymucha", "Ohhaimark" ) )
  local mod = gr.new( api(), mock_player_info( "Psikutas" ) )

  -- When / Then
  eq( mod.get_group_unit_tokens(), { "raid1", "raid2", "raid3" } )
end

GetGroupPlayersSpec = {}

function GetGroupPlayersSpec:should_return_me_with_the_player_token_if_not_in_group()
  -- Given
  local api = mock_api( player( "Psikutas" ) )
  local mod = gr.new( api(), mock_player_info( "Psikutas" ) )

  -- When / Then
  eq( mod.get_group_players(), { { name = "Psikutas", class = "Warrior", unit = "player" } } )
end

function GetGroupPlayersSpec:should_return_party_members_with_their_tokens_sorted()
  -- Given
  local api = mock_api( party( "Psikutas", "Obszczymucha" ) )
  local mod = gr.new( api(), mock_player_info( "Psikutas" ) )

  -- When / Then
  eq( mod.get_group_players(), {
    { name = "Obszczymucha", class = "Warrior", online = true, unit = "party1" },
    { name = "Psikutas",     class = "Warrior", online = true, unit = "player" }
  } )
end

function GetGroupPlayersSpec:should_return_raid_members_with_their_tokens_sorted()
  -- The sort is by class then name, so a member's token is not their raid index.
  -- Given
  local api = mock_api( raid( "Psikutas", "Obszczymucha" ) )
  local mod = gr.new( api(), mock_player_info( "Psikutas" ) )

  -- When / Then
  eq( mod.get_group_players(), {
    { name = "Obszczymucha", class = "Warrior", online = true, unit = "raid2" },
    { name = "Psikutas",     class = "Warrior", online = true, unit = "raid1" }
  } )
end

os.exit( lu.LuaUnit.run() )
