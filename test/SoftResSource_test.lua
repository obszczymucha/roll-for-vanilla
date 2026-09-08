---@diagnostic disable: inject-field
package.path = "./?.lua;" .. package.path .. ";../?.lua;../RollFor/?.lua;../RollFor/libs/?.lua"

require( "src/compat" )
local utils = require( "test/utils" )
local lu, eq = utils.luaunit( "assertEquals" )
require( "src/modules" )
require( "src/Types" )
require( "src/SoftRes" )
local SoftResSource = require( "src/SoftResSource" )

utils.mock_wow_api()

---@type string[]
local printed = {}

RollFor.api.DEFAULT_CHAT_FRAME = {
  AddMessage = function( _, message ) table.insert( printed, message ) end
}

-- A spec with the mandatory fields filled in, so each test only has to say what it is
-- actually about.
---@param id string
---@param overrides table?
local function spec( id, overrides )
  local result = {
    id = id,
    title = id,
    base = function() return {} end,
    has_data = function() return false end
  }

  for key, value in pairs( overrides or {} ) do result[ key ] = value end

  return result
end

-- A value that is deliberately not a SoftResSourceSpec. Typed as `any` because that is
-- exactly what register() accepts: it takes whatever a source hands it and decides.
---@param value any
---@return any
local function malformed( value )
  return value
end

SourceRegistrationSpec = {}

function SourceRegistrationSpec:setUp() SoftResSource.clear() end

function SourceRegistrationSpec:should_register_a_source()
  eq( SoftResSource.register( spec( "softres_it" ) ), true )
  eq( SoftResSource.get().id, "softres_it" )
end

function SourceRegistrationSpec:should_refuse_a_second_registration_and_keep_the_first()
  eq( SoftResSource.register( spec( "softres_it" ) ), true )
  eq( SoftResSource.register( spec( "raidres" ) ), false )
  eq( SoftResSource.get().id, "softres_it" )
end

function SourceRegistrationSpec:should_refuse_a_spec_that_is_not_a_table()
  eq( SoftResSource.register( malformed( "softres_it" ) ), false )
  eq( SoftResSource.get(), nil )
end

function SourceRegistrationSpec:should_refuse_a_nameless_source()
  eq( SoftResSource.register( spec( "", {} ) ), false )
  eq( SoftResSource.get(), nil )
end

function SourceRegistrationSpec:should_refuse_a_titleless_source()
  eq( SoftResSource.register( malformed( { id = "softres_it", base = function() end, has_data = function() end } ) ), false )
  eq( SoftResSource.get(), nil )
end

function SourceRegistrationSpec:should_refuse_a_source_without_a_base_function()
  eq( SoftResSource.register( spec( "softres_it", { base = "nope" } ) ), false )
  eq( SoftResSource.get(), nil )
end

function SourceRegistrationSpec:should_refuse_a_source_without_a_has_data_function()
  eq( SoftResSource.register( spec( "softres_it", { has_data = "nope" } ) ), false )
  eq( SoftResSource.get(), nil )
end

NullFallbackSpec = {}

function NullFallbackSpec:setUp() SoftResSource.clear() end

function NullFallbackSpec:should_return_a_working_null_when_nothing_is_registered()
  local softres = SoftResSource.base()

  eq( softres.get( RollFor.SoftRes.softres_item_data( 123, 1 ) ), {} )
  eq( softres.get_all_rollers(), {} )
  eq( softres.is_player_softressing( "Drutree" ), false )
  eq( softres.get_items(), {} )
  eq( softres.get_hr_item_ids(), {} )
  eq( softres.is_item_hardressed( 123 ), false )
end

function NullFallbackSpec:should_report_no_data_when_nothing_is_registered()
  eq( SoftResSource.has_data(), false )
end

function NullFallbackSpec:should_report_no_import_string_when_nothing_is_registered()
  eq( SoftResSource.get_import_string(), nil )
end

function NullFallbackSpec:should_use_the_registered_sources_base_once_one_exists()
  local store = { marker = true }
  SoftResSource.register( spec( "softres_it", { base = function() return store end } ) )

  eq( SoftResSource.base(), store )
end

function NullFallbackSpec:should_use_the_registered_sources_has_data()
  SoftResSource.register( spec( "softres_it", { has_data = function() return true end } ) )

  eq( SoftResSource.has_data(), true )
end

function NullFallbackSpec:should_return_nil_for_an_import_string_the_source_does_not_supply()
  SoftResSource.register( spec( "softres_it" ) )

  eq( SoftResSource.get_import_string(), nil )
end

function NullFallbackSpec:should_return_the_registered_sources_import_string()
  SoftResSource.register( spec( "softres_it", { get_import_string = function() return "encoded" end } ) )

  eq( SoftResSource.get_import_string(), "encoded" )
end

os.exit( lu.LuaUnit.run() )
