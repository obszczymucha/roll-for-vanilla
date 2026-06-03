package.path = "./?.lua;" .. package.path .. ";../?.lua;../RollFor/?.lua;../RollFor/libs/bcc/?.lua"

require( "src/bcc/compat" )
local u = require( "test/utils" )
local lu, eq = u.luaunit( "assertEquals" )
local player, leader = u.player, u.raid_leader
local soft_res = u.soft_res
local sr = u.soft_res_item
local is_in_raid = u.is_in_raid
local sid = u.softres_item_data
local alid = u.awarded_loot_item_data

NetherVortexAwardedLootDecoratorSpec = {}

function NetherVortexAwardedLootDecoratorSpec:should_behave_normally_for_non_vortex_items()
  -- Given
  player( "Jogobobek" )
  is_in_raid( leader( "Jogobobek" ), "Obszczymucha" )
  local rf = soft_res( sr( "Jogobobek", 123 ), sr( "Obszczymucha", 123 ) )
  local softres = rf.softres
  rf.awarded_loot.award( "Jogobobek", alid( 123 ) )

  -- When
  local result = softres.get( sid( 123, 1 ) )

  -- Then
  eq( result, {
    { name = "Obszczymucha", rolls = 1, class = "Warrior", type = "Roller" }
  } )
end

function NetherVortexAwardedLootDecoratorSpec:should_exclude_player_from_single_after_single_awarded()
  -- Given
  player( "Jogobobek" )
  is_in_raid( leader( "Jogobobek" ), "Obszczymucha" )
  local rf = soft_res(
    sr( "Jogobobek", 30183 ), sr( "Jogobobek", 30183 ), sr( "Jogobobek", 30183 ),
    sr( "Obszczymucha", 30183 ), sr( "Obszczymucha", 30183 ), sr( "Obszczymucha", 30183 )
  )
  local softres = rf.softres
  rf.awarded_loot.award( "Jogobobek", alid( 30183, 1 ) )

  -- When
  local result = softres.get( sid( 30183, 1 ) )

  -- Then - Jogobobek should be excluded from single
  eq( result, {
    { name = "Obszczymucha", rolls = 1, class = "Warrior", type = "Roller" }
  } )
end

function NetherVortexAwardedLootDecoratorSpec:should_not_exclude_player_from_double_after_single_awarded()
  -- Given
  player( "Jogobobek" )
  is_in_raid( leader( "Jogobobek" ), "Obszczymucha" )
  local rf = soft_res(
    sr( "Jogobobek", 30183 ), sr( "Jogobobek", 30183 ), sr( "Jogobobek", 30183 ),
    sr( "Obszczymucha", 30183 ), sr( "Obszczymucha", 30183 ), sr( "Obszczymucha", 30183 )
  )
  local softres = rf.softres
  rf.awarded_loot.award( "Jogobobek", alid( 30183, 1 ) )

  -- When
  local result = softres.get( sid( 30183, 2 ) )

  -- Then - Jogobobek should still be eligible for double
  eq( result, {
    { name = "Jogobobek",    rolls = 1, class = "Warrior", type = "Roller" },
    { name = "Obszczymucha", rolls = 1, class = "Warrior", type = "Roller" }
  } )
end

function NetherVortexAwardedLootDecoratorSpec:should_exclude_player_from_double_after_double_awarded()
  -- Given
  player( "Jogobobek" )
  is_in_raid( leader( "Jogobobek" ), "Obszczymucha" )
  local rf = soft_res(
    sr( "Jogobobek", 30183 ), sr( "Jogobobek", 30183 ), sr( "Jogobobek", 30183 ),
    sr( "Obszczymucha", 30183 ), sr( "Obszczymucha", 30183 ), sr( "Obszczymucha", 30183 )
  )
  local softres = rf.softres
  rf.awarded_loot.award( "Jogobobek", alid( 30183, 2 ) )

  -- When
  local result = softres.get( sid( 30183, 2 ) )

  -- Then - Jogobobek should be excluded from double
  eq( result, {
    { name = "Obszczymucha", rolls = 1, class = "Warrior", type = "Roller" }
  } )
end

function NetherVortexAwardedLootDecoratorSpec:should_not_exclude_player_from_single_after_double_awarded()
  -- Given
  player( "Jogobobek" )
  is_in_raid( leader( "Jogobobek" ), "Obszczymucha" )
  local rf = soft_res(
    sr( "Jogobobek", 30183 ), sr( "Jogobobek", 30183 ), sr( "Jogobobek", 30183 ),
    sr( "Obszczymucha", 30183 ), sr( "Obszczymucha", 30183 ), sr( "Obszczymucha", 30183 )
  )
  local softres = rf.softres
  rf.awarded_loot.award( "Jogobobek", alid( 30183, 2 ) )

  -- When
  local result = softres.get( sid( 30183, 1 ) )

  -- Then - Jogobobek should still be eligible for single
  eq( result, {
    { name = "Jogobobek",    rolls = 1, class = "Warrior", type = "Roller" },
    { name = "Obszczymucha", rolls = 1, class = "Warrior", type = "Roller" }
  } )
end

function NetherVortexAwardedLootDecoratorSpec:should_allow_player_to_roll_on_double_after_winning_single()
  -- Given
  player( "Jogobobek" )
  is_in_raid( leader( "Jogobobek" ), "Obszczymucha" )
  local rf = soft_res(
    sr( "Jogobobek", 30183 ), sr( "Jogobobek", 30183 ), sr( "Jogobobek", 30183 ),
    sr( "Obszczymucha", 30183 ), sr( "Obszczymucha", 30183 ), sr( "Obszczymucha", 30183 )
  )
  local softres = rf.softres

  -- When single vortex drops
  local single_rollers = softres.get( sid( 30183, 1 ) )

  -- Then both players are eligible for single
  eq( single_rollers, {
    { name = "Jogobobek",    rolls = 1, class = "Warrior", type = "Roller" },
    { name = "Obszczymucha", rolls = 1, class = "Warrior", type = "Roller" }
  } )

  -- When Jogobobek wins and is awarded the single vortex
  rf.awarded_loot.award( "Jogobobek", alid( 30183, 1 ) )

  -- Then Jogobobek is no longer eligible for single
  eq( softres.get( sid( 30183, 1 ) ), {
    { name = "Obszczymucha", rolls = 1, class = "Warrior", type = "Roller" }
  } )

  -- When double vortex drops
  local double_rollers = softres.get( sid( 30183, 2 ) )

  -- Then Jogobobek is still eligible for double
  eq( double_rollers, {
    { name = "Jogobobek",    rolls = 1, class = "Warrior", type = "Roller" },
    { name = "Obszczymucha", rolls = 1, class = "Warrior", type = "Roller" }
  } )
end

function NetherVortexAwardedLootDecoratorSpec:should_exclude_player_from_both_after_both_awarded()
  -- Given
  player( "Jogobobek" )
  is_in_raid( leader( "Jogobobek" ), "Obszczymucha" )
  local rf = soft_res(
    sr( "Jogobobek", 30183 ), sr( "Jogobobek", 30183 ), sr( "Jogobobek", 30183 ),
    sr( "Obszczymucha", 30183 ), sr( "Obszczymucha", 30183 ), sr( "Obszczymucha", 30183 )
  )
  local softres = rf.softres
  rf.awarded_loot.award( "Jogobobek", alid( 30183, 1 ) )
  rf.awarded_loot.award( "Jogobobek", alid( 30183, 2 ) )

  -- When
  local single_result = softres.get( sid( 30183, 1 ) )
  local double_result = softres.get( sid( 30183, 2 ) )

  -- Then
  eq( single_result, {
    { name = "Obszczymucha", rolls = 1, class = "Warrior", type = "Roller" }
  } )
  eq( double_result, {
    { name = "Obszczymucha", rolls = 1, class = "Warrior", type = "Roller" }
  } )
end

u.mock_libraries()
u.load_real_stuff( function( module_name )
  if module_name ~= "src/LootAwardPopup" then return require( module_name ) end

  return require( "mocks/LootAwardPopup" )
end )

os.exit( lu.LuaUnit.run() )
