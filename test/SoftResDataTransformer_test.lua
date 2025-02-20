package.path = "./?.lua;" .. package.path .. ";../?.lua;../RollFor/?.lua;../RollFor/libs/?.lua"

local u = require( "test/utils" )
local lu, eq = u.luaunit( "assertEquals" )
local sr, hr, make_data = u.soft_res_item, u.hard_res_item, u.create_softres_data
u.mock_wow_api()
require( "src/modules" )
require( "src/Types" )
local mod = require( "src/SoftResDataTransformer" )

SoftResDataTransformerSpec = {}

function SoftResDataTransformerSpec:should_transform_soft_ressed_items()
  -- Given
  local data = make_data( sr( "Psikutas", 123 ), sr( "Psikutas", 123 ), sr( "Obszczymucha", 69, 2 ), sr( "Obszczymucha", 123 ) )

  -- When
  local sr_result, hr_result = mod.transform( data )

  -- Then
  eq( sr_result,
    {
      [ 123 ] = {
        rollers = {
          { name = "Psikutas",     rolls = 2, type = "Roller" },
          { name = "Obszczymucha", rolls = 1, type = "Roller" }
        },
        quality = 4
      },
      [ 69 ] = {
        rollers = {
          { name = "Obszczymucha", rolls = 1, type = "Roller" }
        },
        quality = 2
      }
    } )
  eq( hr_result, {} )
end

function SoftResDataTransformerSpec:should_transform_hard_ressed_items()
  -- Given
  local data = make_data( hr( 123 ), hr( 123 ), hr( 69, 3 ), hr( 42 ) )

  -- When
  local sr_result, hr_result = mod.transform( data )

  -- Then
  eq( sr_result, {} )
  eq( hr_result,
    {
      [ 123 ] = { quality = 4 },
      [ 69 ] = { quality = 3 },
      [ 42 ] = { quality = 4 }
    } )
end

function SoftResDataTransformerSpec:should_split_sr_and_hr_items()
  -- Given
  local data = make_data( sr( "Psikutas", 123 ), hr( 123 ), sr( "Obszczymucha", 69 ), hr( 42 ) )

  -- When
  local sr_result, hr_result = mod.transform( data )

  -- Then
  eq( sr_result,
    {
      [ 123 ] = {
        rollers = { { name = "Psikutas", rolls = 1, type = "Roller" } },
        quality = 4
      },
      [ 69 ] = {
        rollers = { { name = "Obszczymucha", rolls = 1, type = "Roller" } },
        quality = 4
      }
    } )
  eq( hr_result, {
    [ 123 ] = { quality = 4 },
    [ 42 ] = { quality = 4 }
  } )
end

function SoftResDataTransformerSpec:should_transform_soft_ressed_plus_values()
  -- Given
  local data = make_data( sr( "Psikutas", 123, nil, "40" ), sr( "Psikutas", 123 ), sr( "Obszczymucha", 69, 2, 50 ), sr( "Obszczymucha", 123, nil, 60 ) )

  -- When
  local sr_result, hr_result = mod.transform( data )

  -- Then
  eq( sr_result,
    {
      [ 123 ] = {
        rollers = {
          { name = "Psikutas",     rolls = 2, type = "Roller", sr_plus = 40 },
          { name = "Obszczymucha", rolls = 1, type = "Roller", sr_plus = 60 }
        },
        quality = 4
      },
      [ 69 ] = {
        rollers = {
          { name = "Obszczymucha", rolls = 1, type = "Roller", sr_plus = 50 }
        },
        quality = 2
      }
    } )
  eq( hr_result, {} )
end


os.exit( lu.LuaUnit.run() )
