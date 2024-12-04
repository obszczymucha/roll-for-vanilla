package.path = "./?.lua;" .. package.path .. ";../?.lua;../RollFor/?.lua;../RollFor/libs/?.lua;../RollFor/libs/LibStub/?.lua"

local lu = require( "luaunit" )
local test_utils = require( "test/utils" )
test_utils.mock_wow_api()
test_utils.load_libstub()
require( "src/modules" )
require( "src/SoftResDataTransformer" )
local mod = require( "src/SoftRes" )

local sr = test_utils.soft_res_item
local data = test_utils.create_softres_data

SoftResIntegrationSpec = {}

function SoftResIntegrationSpec.new_instances_should_have_empty_item_lists()
  -- Given
  local soft_res = mod.new()
  local soft_res2 = mod.new()

  -- Expect
  lu.assertEquals( soft_res.get( 123 ), nil )
  lu.assertEquals( soft_res2.get( 123 ), nil )
end

function SoftResIntegrationSpec:should_create_a_proper_object_and_add_an_item()
  -- Given
  local soft_res = mod.new()
  soft_res.import( data( sr( "Psikutas", 123 ) ) )
  local soft_res2 = mod.new()

  -- When
  local result = soft_res.get( 123 )
  local result2 = soft_res2.get( 123 )

  -- Then
  lu.assertEquals( result, {
    { name = "Psikutas", rolls = 1 }
  } )
  lu.assertEquals( result2, {} )
end

function SoftResIntegrationSpec:should_return_nil_for_untracked_item()
  -- Given
  local soft_res = mod.new()
  soft_res.import( data( sr( "Psikutas", 123 ) ) )

  -- When
  local result = soft_res.get( "111" )

  -- Then
  lu.assertEquals( result, {} )
end

function SoftResIntegrationSpec:should_add_multiple_players()
  -- Given
  local soft_res = mod.new()
  soft_res.import( data( sr( "Psikutas", 123 ), sr( "Obszczymucha", 123 ) ) )

  -- When
  local result = soft_res.get( 123 )

  -- Then
  lu.assertEquals( result, {
    { name = "Obszczymucha", rolls = 1 },
    { name = "Psikutas", rolls = 1 }
  } )
end

function SoftResIntegrationSpec:should_accumulate_rolls()
  -- Given
  local soft_res = mod.new()
  soft_res.import( data( sr( "Psikutas", 123 ), sr( "Psikutas", 123 ) ) )

  -- When
  local result = soft_res.get( 123 )

  -- Then
  lu.assertEquals( result, {
    { name = "Psikutas", rolls = 2 }
  } )
end

function SoftResIntegrationSpec:should_check_if_player_is_soft_ressing()
  -- When
  local soft_res = mod.new()
  soft_res.import( data( sr( "Psikutas", 123 ), sr( "Obszczymucha", 111 ) ) )

  -- Expect
  lu.assertEquals( soft_res.is_player_softressing( "Psiktuas", 123 ), false )
  lu.assertEquals( soft_res.is_player_softressing( "Psikutas", 123 ), true )
  lu.assertEquals( soft_res.is_player_softressing( "Psikutas", 333 ), false )
  lu.assertEquals( soft_res.is_player_softressing( "Psikutas", 111 ), false )
  lu.assertEquals( soft_res.is_player_softressing( "Obszczymucha", 111 ), true )
  lu.assertEquals( soft_res.is_player_softressing( "Obszczymucha", 123 ), false )
  lu.assertEquals( soft_res.is_player_softressing( "Obszczymucha", 124 ), false )
  lu.assertEquals( soft_res.is_player_softressing( "Ponpon", 123 ), false )
  lu.assertEquals( soft_res.is_player_softressing( "Ponpon", 111 ), false )
  lu.assertEquals( soft_res.is_player_softressing( "Ponpon", 333 ), false )
end

os.exit( lu.LuaUnit.run() )
