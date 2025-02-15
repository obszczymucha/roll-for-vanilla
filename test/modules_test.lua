package.path = "./?.lua;" .. package.path .. ";../?.lua;../RollFor/?.lua;../RollFor/libs/?.lua"

require( "src/bcc/compat" )
local lu = require( "luaunit" )
require( "test/utils" ) -- Need to load this before modules to load lua50 stuff.
local mod = require( "src/modules" )
local eq = lu.assertEquals

MapSpec = {}

function MapSpec:should_map_simple_array()
  -- Given
  local map = mod.map
  local f = string.upper

  -- Expect
  eq( map( { "abc", "def" }, f ), { "ABC", "DEF" } )
  eq( map( {}, f ), {} )
end

function MapSpec:should_map_an_array_of_objects()
  -- Given
  local map = mod.map
  local f = string.upper

  -- Expect
  eq( map( {
    { name = "abc", roll = 69 },
    { name = "def", roll = 100 }
  }, f, "name" ), {
    { name = "ABC", roll = 69 },
    { name = "DEF", roll = 100 }
  } )
end

FilterSpec = {}

function FilterSpec:should_filter_simple_array()
  -- Given
  local filter = mod.filter
  local f = function( x ) return x > 3 end

  -- Expect
  eq( filter( { 1, 2, 3, 4, 5, 6 }, f ), { 4, 5, 6 } )
  eq( filter( {}, f ), {} )
end

function FilterSpec:should_filter_an_array_of_objects()
  -- Given
  local filter = mod.filter
  local f = function( x ) return x > 70 end

  -- Expect
  eq( filter( {
    { name = "abc", roll = 69 },
    { name = "def", roll = 100 },
    { name = "ghi", roll = 88 }
  }, f, "roll" ), {
    { name = "def", roll = 100 },
    { name = "ghi", roll = 88 }
  } )
end

MergeSpec = {}

function MergeSpec:should_merge_tables()
  eq( mod.merge( {}, {} ), {} )
  eq( mod.merge( {}, {}, {} ), {} )
  eq( mod.merge( {}, { "a" }, {} ), { "a" } )
  eq( mod.merge( {}, {}, { "a" } ), { "a" } )
  eq( mod.merge( {}, { "a" }, { "b" } ), { "a", "b" } )
  eq( mod.merge( { "a" }, { "b" }, { "c" } ), { "a", "b", "c" } )
end

TakeSpec = {}

function TakeSpec:should_take_n_elements_from_a_table()
  eq( mod.take( { "a", "b", "c" }, 0 ), {} )
  eq( mod.take( { "a", "b", "c" }, 1 ), { "a" } )
  eq( mod.take( { "a", "b", "c" }, 2 ), { "a", "b" } )
  eq( mod.take( { "a", "b", "c" }, 3 ), { "a", "b", "c" } )
  eq( mod.take( { "a", "b", "c" }, 4 ), { "a", "b", "c" } )
  eq( mod.take( { "a", "b", "c" }, -1 ), {} )
end

Base64Spec = {}

function Base64Spec:should_decode_and_encode()
  local encoded = mod.encode_base64( "Princess Kenny" )
  local decoded = mod.decode_base64( encoded )

  eq( decoded, "Princess Kenny" )
end

CoinSpec = {}

function CoinSpec:should_one_line_coin_name()
  eq( mod.one_line_coin_name( nil ), "" )
  eq( mod.one_line_coin_name( "5 gold\n37 silver\n69 copper" ), "5 gold, 37 silver, 69 copper" )
  eq( mod.one_line_coin_name( "37 silver\n69 copper" ), "37 silver, 69 copper" )
  eq( mod.one_line_coin_name( "69 copper" ), "69 copper" )
end

os.exit( lu.LuaUnit.run() )
