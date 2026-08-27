---@diagnostic disable: inject-field
package.path = "./?.lua;" .. package.path .. ";../../?.lua;../../RollFor/?.lua;../../RollFor/libs/?.lua"

require( "src/compat" )
local utils = require( "test/utils" )
local lu, eq = utils.luaunit( "assertEquals" )
require( "src/modules" )
require( "src/DebugBuffer" )
require( "src/Module" )
local BuffScanner = require( "src/resistances/BuffScanner" )

---@param unit_buffs table<string, string[]>
---@param tooltips table<string, string[]>? -- by buff name
local function scanner( unit_buffs, tooltips )
  local read = {}

  local tooltip_reader = {
    get_unit_buff_lines = function( unit, index )
      local name = unit_buffs[ unit ] and unit_buffs[ unit ][ index ]
      table.insert( read, name )

      return tooltips and tooltips[ name ]
    end
  }

  local sut = BuffScanner.new( {
    UnitBuff = function( unit, index )
      local buffs = unit_buffs[ unit ]
      return buffs and buffs[ index ]
    end
  }, tooltip_reader )

  sut.tooltips_read = function() return read end

  return sut
end

---@param name string
local function buff( name )
  return { name = name }
end

---@param name string
---@param lines string[]
local function buff_with_tooltip( name, lines )
  return { name = name, tooltip_data = lines }
end

BuffScannerSpec = {}

function BuffScannerSpec:should_return_the_buff_names()
  -- Given
  local sut = scanner( { [ "raid1" ] = { "Power Word: Fortitude", "Shadow Protection", "Mark of the Wild" } } )

  -- When
  local result = sut.get_buffs( "raid1" )

  -- Then
  eq( result, { buff( "Power Word: Fortitude" ), buff( "Shadow Protection" ), buff( "Mark of the Wild" ) } )
end

function BuffScannerSpec:should_return_nothing_for_an_unbuffed_unit()
  -- Given
  local sut = scanner( {} )

  -- When
  local result = sut.get_buffs( "raid1" )

  -- Then
  eq( result, {} )
end

function BuffScannerSpec:should_stop_at_the_first_empty_slot()
  -- Given
  local buffs = { "Shadow Protection" }
  buffs[ 3 ] = "Mark of the Wild"
  local sut = scanner( { [ "raid1" ] = buffs } )

  -- When
  local result = sut.get_buffs( "raid1" )

  -- Then
  eq( result, { buff( "Shadow Protection" ) } )
end

function BuffScannerSpec:should_read_the_tooltip_of_a_requested_buff()
  -- Given
  local well_fed = { "Well Fed", "Resistance to all schools of magic increased by 8." }
  local sut = scanner(
    { [ "raid1" ] = { "Shadow Protection", "Well Fed" } },
    { [ "Well Fed" ] = well_fed }
  )

  -- When
  local result = sut.get_buffs( "raid1", { [ "Well Fed" ] = true } )

  -- Then
  eq( result, { buff( "Shadow Protection" ), buff_with_tooltip( "Well Fed", well_fed ) } )
end

function BuffScannerSpec:should_only_read_tooltips_it_was_asked_for()
  -- Reading a tooltip is expensive next to reading a name, so the ones nobody
  -- asked about are never touched.
  -- Given
  local sut = scanner( { [ "raid1" ] = { "Shadow Protection", "Well Fed", "Mark of the Wild" } } )

  -- When
  sut.get_buffs( "raid1", { [ "Well Fed" ] = true } )

  -- Then
  eq( sut.tooltips_read(), { "Well Fed" } )
end

function BuffScannerSpec:should_read_no_tooltips_when_none_were_requested()
  -- Given
  local sut = scanner( { [ "raid1" ] = { "Well Fed" } } )

  -- When
  local result = sut.get_buffs( "raid1" )

  -- Then
  eq( result, { buff( "Well Fed" ) } )
  eq( sut.tooltips_read(), {} )
end

os.exit( lu.LuaUnit.run() )
