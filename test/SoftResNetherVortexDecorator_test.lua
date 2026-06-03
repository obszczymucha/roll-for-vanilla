package.path = "./?.lua;" .. package.path .. ";../?.lua;../RollFor/?.lua;../RollFor/libs/bcc/?.lua"

require( "src/bcc/compat" )
local u = require( "test/utils" )
local lu, eq = u.luaunit( "assertEquals" )
local player, leader = u.player, u.raid_leader
local soft_res = u.soft_res
local sr = u.soft_res_item
local is_in_raid = u.is_in_raid
local sid = u.softres_item_data

SoftResNetherVortexDecoratorSpec = {}

function SoftResNetherVortexDecoratorSpec:should_pass_through_non_vortex_item_unchanged()
  -- Given
  player( "Jogobobek" )
  is_in_raid( leader( "Jogobobek" ), "Obszczymucha" )
  local rf = soft_res( sr( "Jogobobek", 123 ), sr( "Obszczymucha", 123 ), sr( "Obszczymucha", 123 ) )
  local softres = rf.softres

  -- When
  local result = softres.get( sid( 123, 1 ) )

  -- Then
  eq( result, {
    { name = "Jogobobek",    rolls = 1, class = "Warrior", type = "Roller" },
    { name = "Obszczymucha", rolls = 2, class = "Warrior", type = "Roller" }
  } )
end

function SoftResNetherVortexDecoratorSpec:should_return_player_with_1_sr_for_single_vortex()
  -- Given
  player( "Jogobobek" )
  is_in_raid( leader( "Jogobobek" ), "Obszczymucha" )
  local rf = soft_res( sr( "Jogobobek", 30183 ) )
  local softres = rf.softres

  -- When
  local result = softres.get( sid( 30183, 1 ) )

  -- Then
  eq( result, {
    { name = "Jogobobek", rolls = 1, class = "Warrior", type = "Roller" }
  } )
end

function SoftResNetherVortexDecoratorSpec:should_not_return_player_with_2_sr_for_single_vortex()
  -- Given
  player( "Jogobobek" )
  is_in_raid( leader( "Jogobobek" ), "Obszczymucha" )
  local rf = soft_res( sr( "Jogobobek", 30183 ), sr( "Jogobobek", 30183 ) )
  local softres = rf.softres

  -- When
  local result = softres.get( sid( 30183, 1 ) )

  -- Then
  eq( result, {} )
end

function SoftResNetherVortexDecoratorSpec:should_return_player_with_3_sr_for_single_vortex_with_1_roll()
  -- Given
  player( "Jogobobek" )
  is_in_raid( leader( "Jogobobek" ), "Obszczymucha" )
  local rf = soft_res( sr( "Jogobobek", 30183 ), sr( "Jogobobek", 30183 ), sr( "Jogobobek", 30183 ) )
  local softres = rf.softres

  -- When
  local result = softres.get( sid( 30183, 1 ) )

  -- Then
  eq( result, {
    { name = "Jogobobek", rolls = 1, class = "Warrior", type = "Roller" }
  } )
end

function SoftResNetherVortexDecoratorSpec:should_not_return_player_with_1_sr_for_double_vortex()
  -- Given
  player( "Jogobobek" )
  is_in_raid( leader( "Jogobobek" ), "Obszczymucha" )
  local rf = soft_res( sr( "Jogobobek", 30183 ) )
  local softres = rf.softres

  -- When
  local result = softres.get( sid( 30183, 2 ) )

  -- Then
  eq( result, {} )
end

function SoftResNetherVortexDecoratorSpec:should_return_player_with_2_sr_for_double_vortex_with_1_roll()
  -- Given
  player( "Jogobobek" )
  is_in_raid( leader( "Jogobobek" ), "Obszczymucha" )
  local rf = soft_res( sr( "Jogobobek", 30183 ), sr( "Jogobobek", 30183 ) )
  local softres = rf.softres

  -- When
  local result = softres.get( sid( 30183, 2 ) )

  -- Then
  eq( result, {
    { name = "Jogobobek", rolls = 1, class = "Warrior", type = "Roller" }
  } )
end

function SoftResNetherVortexDecoratorSpec:should_return_player_with_3_sr_for_double_vortex_with_1_roll()
  -- Given
  player( "Jogobobek" )
  is_in_raid( leader( "Jogobobek" ), "Obszczymucha" )
  local rf = soft_res( sr( "Jogobobek", 30183 ), sr( "Jogobobek", 30183 ), sr( "Jogobobek", 30183 ) )
  local softres = rf.softres

  -- When
  local result = softres.get( sid( 30183, 2 ) )

  -- Then
  eq( result, {
    { name = "Jogobobek", rolls = 1, class = "Warrior", type = "Roller" }
  } )
end

function SoftResNetherVortexDecoratorSpec:should_filter_correctly_with_mixed_sr_counts()
  -- Given
  player( "Jogobobek" )
  is_in_raid( leader( "Jogobobek" ), "Obszczymucha" )
  -- Jogobobek has 1 SR, Obszczymucha has 2 SR
  local rf = soft_res( sr( "Jogobobek", 30183 ), sr( "Obszczymucha", 30183 ), sr( "Obszczymucha", 30183 ) )
  local softres = rf.softres

  -- When - single vortex
  local single_result = softres.get( sid( 30183, 1 ) )

  -- Then - only Jogobobek (1 SR) is eligible for single
  eq( single_result, {
    { name = "Jogobobek", rolls = 1, class = "Warrior", type = "Roller" }
  } )

  -- When - double vortex
  local double_result = softres.get( sid( 30183, 2 ) )

  -- Then - only Obszczymucha (2 SR) is eligible for double
  eq( double_result, {
    { name = "Obszczymucha", rolls = 1, class = "Warrior", type = "Roller" }
  } )
end

function SoftResNetherVortexDecoratorSpec:should_pass_through_non_vortex_get_items()
  -- Given
  player( "Jogobobek" )
  is_in_raid( leader( "Jogobobek" ), "Obszczymucha" )
  local rf = soft_res( sr( "Jogobobek", 123 ) )
  local softres = rf.softres

  -- When
  local result = softres.get_items()

  -- Then
  eq( result, { sid( 123, 1 ) } )
end

function SoftResNetherVortexDecoratorSpec:should_return_single_vortex_for_1_sr_rollers_only()
  -- Given
  player( "Jogobobek" )
  is_in_raid( leader( "Jogobobek" ), "Obszczymucha" )
  local rf = soft_res( sr( "Jogobobek", 30183 ) )
  local softres = rf.softres

  -- When
  local result = softres.get_items()

  -- Then
  eq( result, { sid( 30183, 1 ) } )
end

function SoftResNetherVortexDecoratorSpec:should_return_double_vortex_for_2_sr_rollers_only()
  -- Given
  player( "Jogobobek" )
  is_in_raid( leader( "Jogobobek" ), "Obszczymucha" )
  local rf = soft_res( sr( "Jogobobek", 30183 ), sr( "Jogobobek", 30183 ) )
  local softres = rf.softres

  -- When
  local result = softres.get_items()

  -- Then
  eq( result, { sid( 30183, 2 ) } )
end

function SoftResNetherVortexDecoratorSpec:should_return_both_single_and_double_for_3_sr_roller()
  -- Given
  player( "Jogobobek" )
  is_in_raid( leader( "Jogobobek" ), "Obszczymucha" )
  local rf = soft_res( sr( "Jogobobek", 30183 ), sr( "Jogobobek", 30183 ), sr( "Jogobobek", 30183 ) )
  local softres = rf.softres

  -- When
  local result = softres.get_items()

  -- Then
  eq( result, { sid( 30183, 1 ), sid( 30183, 2 ) } )
end

function SoftResNetherVortexDecoratorSpec:should_return_both_single_and_double_for_mixed_sr_counts()
  -- Given
  player( "Jogobobek" )
  is_in_raid( leader( "Jogobobek" ), "Obszczymucha" )
  -- Jogobobek has 1 SR, Obszczymucha has 2 SR
  local rf = soft_res( sr( "Jogobobek", 30183 ), sr( "Obszczymucha", 30183 ), sr( "Obszczymucha", 30183 ) )
  local softres = rf.softres

  -- When
  local result = softres.get_items()

  -- Then
  eq( result, { sid( 30183, 1 ), sid( 30183, 2 ) } )
end

u.mock_libraries()
u.load_real_stuff( function( module_name )
  if module_name ~= "src/LootAwardPopup" then return require( module_name ) end

  return require( "mocks/LootAwardPopup" )
end )

os.exit( lu.LuaUnit.run() )
