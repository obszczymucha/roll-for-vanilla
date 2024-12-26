package.path = "./?.lua;" .. package.path .. ";../?.lua;../RollFor/?.lua;../RollFor/libs/?.lua"

local lu = require( "luaunit" )
local eq = lu.assertEquals
local utils = require( "test/utils" )

local player = utils.player
local soft_res = utils.soft_res
local sr = utils.soft_res_item
local is_in_raid = utils.is_in_raid
local leader = utils.raid_leader

SoftResAwardedLootDecoratorSpec = {}

function SoftResAwardedLootDecoratorSpec:should_return_all_softressing_players()
  -- Given
  player( "Jogobobek" )
  is_in_raid( leader( "Jogobobek" ), "Obszczymucha" )
  local rf = soft_res( sr( "Jogobobek", 123 ), sr( "Obszczymucha", 123 ), sr( "Obszczymucha", 123 ) )
  local softres = rf.softres

  -- When
  local result = softres.get( 123 )

  -- Then
  eq( result, {
    { name = "Jogobobek",    rolls = 1, class = "Warrior" },
    { name = "Obszczymucha", rolls = 2, class = "Warrior" }
  } )
end

function SoftResAwardedLootDecoratorSpec:should_not_return_players_that_received_loot()
  -- Given
  player( "Jogobobek" )
  is_in_raid( leader( "Jogobobek" ), "Obszczymucha" )
  local rf = soft_res( sr( "Jogobobek", 123 ), sr( "Obszczymucha", 123 ), sr( "Obszczymucha", 123 ) )
  local softres = rf.softres
  rf.awarded_loot.award( "Jogobobek", 123 )

  -- When
  local result = softres.get( 123 )

  -- Then
  eq( result, {
    { name = "Obszczymucha", rolls = 2, class = "Warrior" }
  } )
end

function SoftResAwardedLootDecoratorSpec:should_not_subtract_rolls()
  -- Given
  local m = require( "src/modules" ).RollingLogicUtils
  player( "Jogobobek" )
  is_in_raid( leader( "Jogobobek" ), "Obszczymucha" )
  local rf = soft_res( sr( "Jogobobek", 123 ), sr( "Obszczymucha", 123 ), sr( "Obszczymucha", 123 ) )
  local softres = rf.softres
  rf.awarded_loot.award( "Jogobobek", 123 )

  -- When
  local result = softres.get( 123 )
  m.subtract_roll( result, "Jogobobek" )

  -- Then
  eq( result, {
    { name = "Obszczymucha", rolls = 2, class = "Warrior" }
  } )
end

utils.mock_libraries()
utils.load_real_stuff( function( module_name )
  if module_name ~= "src/LootAwardPopup" then return require( module_name ) end

  return require( "mocks/LootAwardPopupMock" )
end )

os.exit( lu.LuaUnit.run() )
