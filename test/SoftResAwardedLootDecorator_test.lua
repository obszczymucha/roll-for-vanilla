package.path = "./?.lua;" .. package.path .. ";../?.lua;../RollFor/?.lua;../RollFor/libs/bcc/?.lua"

require( "src/bcc/compat" )
local u = require( "test/utils" )
local lu, eq = u.luaunit( "assertEquals" )
local player, leader = u.player, u.raid_leader
local soft_res = u.soft_res
local sr, hr = u.soft_res_item, u.hard_res_item
local is_in_raid = u.is_in_raid

SoftResAwardedLootDecoratorSpec = {}

function SoftResAwardedLootDecoratorSpec:should_return_true_if_the_item_is_hardressed()
  -- Given
  player( "Jogobobek" )
  is_in_raid( leader( "Jogobobek" ), "Obszczymucha" )
  local rf = soft_res( hr( 123 ), sr( "Jogobobek", 123 ), sr( "Obszczymucha", 123 ), sr( "Obszczymucha", 123 ) )
  local softres = rf.softres

  -- When
  local result = softres.is_item_hardressed( 123 )

  -- Then
  eq( result, true )
end

function SoftResAwardedLootDecoratorSpec:should_return_false_if_the_item_is_hardressed_but_was_awarded_to_any_player()
  -- Given
  player( "Jogobobek" )
  is_in_raid( leader( "Jogobobek" ), "Obszczymucha", "Johnny" )
  local rf = soft_res( hr( 123 ), sr( "Jogobobek", 123 ), sr( "Obszczymucha", 123 ), sr( "Obszczymucha", 123 ) )
  local softres = rf.softres
  rf.awarded_loot.award( "Johnny", 123 )

  -- When
  local result = softres.is_item_hardressed( 123 )

  -- Then
  eq( result, false )
end

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
    { name = "Jogobobek",    rolls = 1, class = "Warrior", type = "Roller" },
    { name = "Obszczymucha", rolls = 2, class = "Warrior", type = "Roller" }
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
    { name = "Obszczymucha", rolls = 2, class = "Warrior", type = "Roller" }
  } )
end

function SoftResAwardedLootDecoratorSpec:should_not_subtract_rolls()
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
    { name = "Obszczymucha", rolls = 2, class = "Warrior", type = "Roller" }
  } )
end

u.mock_libraries()
u.load_real_stuff( function( module_name )
  if module_name ~= "src/LootAwardPopup" then return require( module_name ) end

  return require( "mocks/LootAwardPopup" )
end )

os.exit( lu.LuaUnit.run() )
