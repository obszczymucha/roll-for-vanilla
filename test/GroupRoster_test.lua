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
    table.insert( result, packed_value( { name, nil, nil, nil, "Warrior" } ) )
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

os.exit( lu.LuaUnit.run() )
