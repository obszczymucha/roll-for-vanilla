package.path = "./?.lua;" .. package.path .. ";../?.lua;../RollFor/?.lua;../RollFor/libs/?.lua;../RollFor/libs/LibStub/?.lua"

local lu = require( "luaunit" )
local mocking = require( "test/mocking" )
local mock_api = mocking.mock_api
local mock = mocking.mock
local smart_table = mocking.smart_table
local packed_value = mocking.packed_value

require( "test/utils" ).load_libstub()
require( "src/modules" )
local gr = require( "src/GroupRoster" )

-- mock_api() checks if the type is a function and then ungroups the result.
-- This allows us mocking multiple functions at the same time.
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

MyNameSpec = {}

function MyNameSpec:should_return_my_name()
  -- Given
  local api = mock_api( player( "Psikutas" ) )
  local mod = gr.new( api )

  -- When
  local result = mod.my_name()

  -- Then
  lu.assertEquals( result, "Psikutas" )
end

GetAllPlayersInMyGroupSpec = {}

function GetAllPlayersInMyGroupSpec:should_return_my_name_if_not_in_group()
  -- Given
  local api = mock_api( player( "Psikutas" ) )
  local mod = gr.new( api )

  -- When
  local result = mod.get_all_players_in_my_group()

  -- Then
  lu.assertEquals( result, { { class = "Warrior", name = "Psikutas" } } )
end

function GetAllPlayersInMyGroupSpec:should_return_all_players_in_party()
  -- Given
  local api = mock_api( party( "Psikutas", "Obszczymucha" ) )
  local mod = gr.new( api )

  -- When
  local result = mod.get_all_players_in_my_group()

  -- Then
  lu.assertEquals( result, {
    { class = "Warrior", name = "Psikutas",     online = true },
    { class = "Warrior", name = "Obszczymucha", online = true }
  } )
end

function GetAllPlayersInMyGroupSpec:should_return_all_players_in_raid()
  -- Given
  local api = mock_api( raid( "Psikutas", "Obszczymucha" ) )
  local mod = gr.new( api )

  -- When
  local result = mod.get_all_players_in_my_group()

  -- Then
  lu.assertEquals( result, {
    { class = "Warrior", name = "Psikutas",     online = true },
    { class = "Warrior", name = "Obszczymucha", online = true }
  } )
end

IsPlayerInMyGroupSpec = {}

function IsPlayerInMyGroupSpec:should_return_true_for_myself()
  -- Given
  local api = mock_api( player( "Psikutas" ) )
  local mod = gr.new( api )

  -- When
  local result = mod.is_player_in_my_group( "Psikutas" )

  -- Then
  lu.assertEquals( result, true )
end

function IsPlayerInMyGroupSpec:should_return_false_for_someone_else_if_not_in_group()
  -- Given
  local api = mock_api( player( "Psikutas" ) )
  local mod = gr.new( api )

  -- When
  local result = mod.is_player_in_my_group( "Obszczymucha" )

  -- Then
  lu.assertEquals( result, false )
end

function IsPlayerInMyGroupSpec:should_return_true_for_myself_if_in_party()
  -- Given
  local api = mock_api( party( "Psikutas", "Obszczymucha" ) )
  local mod = gr.new( api )

  -- When
  local result = mod.is_player_in_my_group( "Psikutas" )

  -- Then
  lu.assertEquals( mod.my_name(), "Psikutas" )
  lu.assertEquals( result, true )
end

function IsPlayerInMyGroupSpec:should_return_true_for_myself_if_in_raid()
  -- Given
  local api = mock_api( raid( "Psikutas", "Obszczymucha" ) )
  local mod = gr.new( api )

  -- When
  local result = mod.is_player_in_my_group( "Psikutas" )

  -- Then
  lu.assertEquals( mod.my_name(), "Psikutas" )
  lu.assertEquals( result, true )
end

function IsPlayerInMyGroupSpec:should_return_true_for_someone_else_in_party()
  -- Given
  local api = mock_api( party( "Psikutas", "Obszczymucha" ) )
  local mod = gr.new( api )

  -- When
  local result = mod.is_player_in_my_group( "Obszczymucha" )

  -- Then
  lu.assertEquals( result, true )
end

function IsPlayerInMyGroupSpec:should_return_true_for_someone_else_in_raid()
  -- Given
  local api = mock_api( raid( "Psikutas", "Obszczymucha" ) )
  local mod = gr.new( api )

  -- When
  local result = mod.is_player_in_my_group( "Obszczymucha" )

  -- Then
  lu.assertEquals( result, true )
end

function IsPlayerInMyGroupSpec:should_return_true_for_someone_else_not_in_party()
  -- Given
  local api = mock_api( party( "Psikutas", "Obszczymucha" ) )
  local mod = gr.new( api )

  -- When
  local result = mod.is_player_in_my_group( "Ponpon" )

  -- Then
  lu.assertEquals( result, false )
end

function IsPlayerInMyGroupSpec:should_return_true_for_someone_else_not_in_raid()
  -- Given
  local api = mock_api( raid( "Psikutas", "Obszczymucha" ) )
  local mod = gr.new( api )

  -- When
  local result = mod.is_player_in_my_group( "Ponpon" )

  -- Then
  lu.assertEquals( result, false )
end

AmIInGroupSpec = {}

function AmIInGroupSpec:should_return_false_if_not_in_group()
  -- Given
  local api = mock_api( player( "Psikutas" ) )

  -- When
  local mod = gr.new( api )

  -- Then
  lu.assertEquals( mod.am_i_in_group(), false )
  lu.assertEquals( mod.am_i_in_party(), false )
  lu.assertEquals( mod.am_i_in_raid(), false )
end

function AmIInGroupSpec:should_return_true_if_in_party()
  -- Given
  local api = mock_api( party( "Psikutas", "Obszczymucha" ) )

  -- When
  local mod = gr.new( api )

  -- Then
  lu.assertEquals( mod.am_i_in_group(), true )
  lu.assertEquals( mod.am_i_in_party(), true )
  lu.assertEquals( mod.am_i_in_raid(), false )
end

function AmIInGroupSpec:should_return_true_if_in_raid()
  -- Given
  local api = mock_api( raid( "Psikutas", "Obszczymucha" ) )

  -- When
  local mod = gr.new( api )

  -- Then
  lu.assertEquals( mod.am_i_in_group(), true )
  lu.assertEquals( mod.am_i_in_party(), false )
  lu.assertEquals( mod.am_i_in_raid(), true )
end

os.exit( lu.LuaUnit.run() )
