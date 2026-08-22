package.path = "./?.lua;" .. package.path .. ";../../?.lua;../../RollFor/?.lua;../../RollFor/libs/?.lua"

require( "src/bcc/compat" )
local utils = require( "test/utils" )
local lu, eq = utils.luaunit( "assertEquals" )
require( "src/modules" )
require( "src/DebugBuffer" )
require( "src/Module" )
require( "src/resistances/ResistanceRegistry" )
local GearScanner = require( "src/resistances/GearScanner" )

local function mock_tooltip_reader( gear )
  local reads = 0

  return {
    get_inventory_item_lines = function( _, slot )
      reads = reads + 1
      return gear[ slot ]
    end,
    read_count = function() return reads end
  }
end

local function mock_inspector( error_type )
  local inspected = {}

  return {
    inspect = function( unit, callback )
      table.insert( inspected, unit )

      if error_type then
        callback( nil, "guid-" .. unit, error_type )
      else
        callback( unit, "guid-" .. unit )
      end
    end,
    inspected = inspected
  }
end

local function scanner( gear, inspector )
  local tooltip_reader = mock_tooltip_reader( gear or {} )
  local api = { UnitIsUnit = function( lhs, rhs ) return lhs == rhs end }
  local sut = GearScanner.new( api, tooltip_reader, inspector or mock_inspector() )
  sut.read_count = tooltip_reader.read_count

  return sut
end

GearScannerSpec = {}

function GearScannerSpec:should_return_the_tooltip_lines_by_slot()
  -- Given
  local sut = scanner( {
    [ 5 ] = { "Robe of the Void", "+15 Shadow Resistance" },
    [ 15 ] = { "Cloak of Warding" }
  } )

  -- When
  local result = sut.get_gear_lines( "player" )

  -- Then
  eq( result, {
    [ 5 ] = { "Robe of the Void", "+15 Shadow Resistance" },
    [ 15 ] = { "Cloak of Warding" }
  } )
end

function GearScannerSpec:should_read_every_slot_once()
  -- Given
  local sut = scanner( {} )

  -- When
  sut.get_gear_lines( "player" )

  -- Then: 17 slots, shirt and tabard skipped
  eq( sut.read_count(), 17 )
end

function GearScannerSpec:should_skip_empty_slots()
  -- Given
  local sut = scanner( { [ 5 ] = { "Robe of the Void" } } )

  -- When
  local result = sut.get_gear_lines( "player" )

  -- Then
  eq( result, { [ 5 ] = { "Robe of the Void" } } )
end

function GearScannerSpec:should_not_inspect_the_player()
  -- Given
  local inspector = mock_inspector()
  local sut = scanner( { [ 5 ] = { "Robe of the Void" } }, inspector )
  local result

  -- When
  sut.scan_unit( "player", function( gear ) result = gear end )

  -- Then
  eq( result, { [ 5 ] = { "Robe of the Void" } } )
  eq( inspector.inspected, {} )
end

function GearScannerSpec:should_inspect_other_units_first()
  -- Given
  local inspector = mock_inspector()
  local sut = scanner( { [ 5 ] = { "Robe of the Void" } }, inspector )
  local result

  -- When
  sut.scan_unit( "raid1", function( gear ) result = gear end )

  -- Then
  eq( result, { [ 5 ] = { "Robe of the Void" } } )
  eq( inspector.inspected, { "raid1" } )
end

function GearScannerSpec:should_inspect_again_on_every_call()
  -- Nothing is cached: people swap resistance gear between pulls.
  -- Given
  local inspector = mock_inspector()
  local sut = scanner( {}, inspector )

  -- When
  sut.scan_unit( "raid1", function() end )
  sut.scan_unit( "raid1", function() end )

  -- Then
  eq( inspector.inspected, { "raid1", "raid1" } )
end

function GearScannerSpec:should_report_inspect_errors()
  -- Given
  local sut = scanner( {}, mock_inspector( "timeout" ) )
  local gear, error_type = "not set", nil

  -- When
  sut.scan_unit( "raid1", function( g, e ) gear, error_type = g, e end )

  -- Then
  eq( gear, nil )
  eq( error_type, "timeout" )
end

os.exit( lu.LuaUnit.run() )
