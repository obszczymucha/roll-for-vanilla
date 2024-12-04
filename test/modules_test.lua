package.path = "./?.lua;" .. package.path .. ";../?.lua;../RollFor/?.lua;../RollFor/libs/?.lua;../RollFor/libs/LibStub/?.lua"

local lu = require( "luaunit" )
local utils = require( "test/utils" )
utils.load_libstub()
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

os.exit( lu.LuaUnit.run() )
