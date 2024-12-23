package.path = "./?.lua;" .. package.path .. ";../?.lua;../RollFor/?.lua;../RollFor/libs/?.lua"

local lu = require( "luaunit" )
local utils = require( "test/utils" )
utils.mock_wow_api()
local modules = require( "src/modules" )
local map = modules.map

TestUtilsSpec = {}

function TestUtilsSpec:should_decolorize_text()
  -- Given
  local f = utils.decolorize

  -- Expect
  lu.assertEquals( f( "|cff209ff9RollFor|r: Loaded (|cffff9f69v1.12|r)." ), "RollFor: Loaded (v1.12)." )
  lu.assertEquals( f( "|cffa334eeBlessed Tanzanite|r" ), "Blessed Tanzanite" )
end

function TestUtilsSpec:should_parse_item_link()
  -- Given
  local input = utils.item_link( "Hearthstone" )

  -- When
  local result = utils.parse_item_link( input )

  -- Then
  lu.assertEquals( result, "[Hearthstone]" )
end

function TestUtilsSpec:should_flatten_a_table_into_another_table()
  -- Given
  local function f( a, b ) return function() return a, b end end

  local input = { "a", { "b", "d" }, f( { "e" }, "f" ), "c" }
  local result = {}

  -- When
  utils.flatten( result, input )

  -- Then
  lu.assertEquals( result, { "a", { "b", "d" }, { "e" }, "f", "c" } )
end

function TestUtilsSpec:should_map_a_table()
  -- Given
  local input = {
    { name = "Princess", id = 1 },
    { name = "Kenny",    id = 2 }
  }

  -- When
  local result = map( input, function( v ) return v.id end )

  -- Then
  lu.assertEquals( result, { 1, 2 } )
end

function TestUtilsSpec:should_read_a_fixture()
  -- When
  local result = utils.read_file( "fixtures/princess-kenny.txt" )

  -- Then
  lu.assertEquals( result, "Princess\nKenny\n" )
end

os.exit( lu.LuaUnit.run() )
