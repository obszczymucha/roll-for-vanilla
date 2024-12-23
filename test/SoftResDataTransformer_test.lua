package.path = "./?.lua;" .. package.path .. ";../?.lua;../RollFor/?.lua;../RollFor/libs/?.lua"

local lu = require( "luaunit" )
local test_utils = require( "test/utils" )
test_utils.mock_wow_api()
require( "src/modules" )
local mod = require( "src/SoftResDataTransformer" )

local sr = test_utils.soft_res_item
local hr = test_utils.hard_res_item
local make_data = test_utils.create_softres_data

SoftResDataTransformerSpec = {}

function SoftResDataTransformerSpec:should_transform_soft_ressed_items()
  -- Given
  local data = make_data( sr( "Psikutas", 123 ), sr( "Psikutas", 123 ), sr( "Obszczymucha", 69, 2 ), sr( "Obszczymucha", 123 ) )

  -- When
  local result = mod.transform( data )

  -- Then
  lu.assertEquals( result,
    {
      [ 123 ] = { players = { { name = "Psikutas", rolls = 2 }, { name = "Obszczymucha", rolls = 1 } }, soft_ressed = true, quality = 4 },
      [ 69 ] = { players = { { name = "Obszczymucha", rolls = 1 } }, soft_ressed = true, quality = 2 }
    } )
end

function SoftResDataTransformerSpec:should_transform_hard_ressed_items()
  -- Given
  local data = make_data( hr( 123 ), hr( 123 ), hr( 69, 3 ), hr( 42 ) )

  -- When
  local result = mod.transform( data )

  -- Then
  lu.assertEquals( result,
    {
      [ 123 ] = { hard_ressed = true, quality = 4 },
      [ 69 ] = { hard_ressed = true, quality = 3 },
      [ 42 ] = { hard_ressed = true, quality = 4 }
    } )
end

function SoftResDataTransformerSpec:should_override_soft_ressed_items_with_hard_ressed()
  -- Given
  local data = make_data( sr( "Psikutas", 123 ), hr( 123 ), sr( "Obszczymucha", 69 ), hr( 42 ) )

  -- When
  local result = mod.transform( data )

  -- Then
  lu.assertEquals( result,
    {
      [ 123 ] = { hard_ressed = true, quality = 4 },
      [ 69 ] = { players = { { name = "Obszczymucha", rolls = 1 } }, soft_ressed = true, quality = 4 },
      [ 42 ] = { hard_ressed = true, quality = 4 }
    } )
end

os.exit( lu.LuaUnit.run() )
