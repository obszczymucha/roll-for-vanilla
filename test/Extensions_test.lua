---@diagnostic disable: inject-field
package.path = "./?.lua;" .. package.path .. ";../?.lua;../RollFor/?.lua;../RollFor/libs/?.lua"

require( "src/compat" )
local utils = require( "test/utils" )
local lu, eq = utils.luaunit( "assertEquals" )
require( "src/modules" )
local EventBus = require( "src/EventBus" )
local Extensions = require( "src/Extensions" )

utils.mock_wow_api()

---@type string[]
local printed = {}

RollFor.api.DEFAULT_CHAT_FRAME = {
  AddMessage = function( _, message ) table.insert( printed, message ) end
}

---@return string?
local function last_printed()
  -- Parenthesised because decolorize is a gsub underneath, and gsub also returns the
  -- number of replacements it made.
  return (utils.decolorize( printed[ #printed ] ))
end

-- A spec with the mandatory fields filled in, so each test only has to say what it is
-- actually about.
---@param name string
---@param overrides table?
local function spec( name, overrides )
  local result = {
    name = name,
    title = name,
    api_version = Extensions.API_VERSION,
    on_enable = function() end
  }

  for key, value in pairs( overrides or {} ) do result[ key ] = value end

  return result
end

-- A value that is deliberately not an ExtensionSpec -- a table missing required fields,
-- or not a table at all. Typed as `any` because that is exactly what register() accepts:
-- it takes whatever an addon hands it and decides. The name says why the checker has
-- nothing to flag here.
---@param value any
---@return any
local function malformed( value )
  return value
end

local function context() return { name = "ctx" } end

---@return table -- the db proxy Extensions.attach expects
---@return table -- reload requests seen on the bus
local function attach()
  local db = {}
  local event_bus = EventBus.new()
  local reloads = {}

  event_bus.subscribe( "config_change_requires_ui_reload", function( data ) table.insert( reloads, data ) end )
  Extensions.attach( db, event_bus )

  return db, reloads
end

RegistrationSpec = {}

function RegistrationSpec:setUp() Extensions.clear() end

function RegistrationSpec:should_register_an_extension()
  eq( Extensions.register( spec( "nether_vortex" ) ), true )
  eq( #Extensions.all(), 1 )
  eq( Extensions.all()[ 1 ].name, "nether_vortex" )
end

function RegistrationSpec:should_default_the_title_to_the_name()
  Extensions.register( spec( "nether_vortex", { title = nil } ) )

  eq( Extensions.all()[ 1 ].title, "nether_vortex" )
end

function RegistrationSpec:should_keep_registration_order()
  Extensions.register( spec( "one" ) )
  Extensions.register( spec( "two" ) )

  eq( Extensions.all()[ 1 ].name, "one" )
  eq( Extensions.all()[ 2 ].name, "two" )
end

function RegistrationSpec:should_refuse_a_second_registration_of_the_same_name()
  eq( Extensions.register( spec( "nether_vortex" ) ), true )
  eq( Extensions.register( spec( "nether_vortex" ) ), false )
  eq( #Extensions.all(), 1 )
end

function RegistrationSpec:should_refuse_a_spec_that_is_not_a_table()
  eq( Extensions.register( malformed( "nether_vortex" ) ), false )
  eq( #Extensions.all(), 0 )
end

function RegistrationSpec:should_refuse_a_nameless_extension()
  eq( Extensions.register( spec( "", {} ) ), false )
  eq( Extensions.register( malformed( { api_version = 1, on_enable = function() end } ) ), false )
  eq( #Extensions.all(), 0 )
end

function RegistrationSpec:should_refuse_an_extension_with_no_hooks_at_all()
  eq( Extensions.register( malformed( { name = "nether_vortex", api_version = Extensions.API_VERSION } ) ), false )
  eq( #Extensions.all(), 0 )
end

function RegistrationSpec:should_refuse_an_on_ready_that_is_not_a_function()
  eq( Extensions.register( spec( "nether_vortex", { on_ready = "nope" } ) ), false )
  eq( #Extensions.all(), 0 )
end

CompatibilitySpec = {}

function CompatibilitySpec:setUp() Extensions.clear() end

-- Registered, listed, and permanently off: the options window can say why, which beats
-- half-loading and failing somewhere less obvious later.
function CompatibilitySpec:should_register_but_never_enable_an_extension_from_the_future()
  eq( Extensions.register( spec( "future", { api_version = Extensions.API_VERSION + 1 } ) ), true )

  eq( #Extensions.all(), 1 )
  eq( Extensions.all()[ 1 ].incompatible, true )
  eq( Extensions.is_enabled( "future" ), false )
end

-- An extension with nothing to declare is a real thing: one whose whole job needs a component
-- core has not built yet has no use for the declaration phase, and an empty on_enable to say
-- so taught nobody anything.
function RegistrationSpec:should_accept_an_extension_with_no_on_enable()
  eq( Extensions.register( {
    name = "ready_only",
    title = "Ready Only",
    api_version = Extensions.API_VERSION,
    on_ready = function() end
  } ), true )

  eq( Extensions.all()[ 1 ].name, "ready_only" )
end

-- Still refused when it is there and is not a function -- a typo'd hook that silently never
-- runs is the outcome worth failing on.
function RegistrationSpec:should_refuse_an_on_enable_that_is_not_a_function()
  eq( Extensions.register( spec( "nether_vortex", { on_enable = "nope" } ) ), false )
  eq( #Extensions.all(), 0 )
end

function CompatibilitySpec:should_treat_a_missing_api_version_as_incompatible()
  Extensions.register( malformed( { name = "vague", on_enable = function() end } ) )

  eq( Extensions.all()[ 1 ].incompatible, true )
  eq( Extensions.is_enabled( "vague" ), false )
end

-- Context is now v4 (v2 added api, softres_source, softres_tap and minimap for the
-- soft-res extraction; v3 added on_loot and on_dropped_item for the loot pipeline; v4 added
-- roll_modifier), but an extension built against v1 -- RollForNetherVortex among them --
-- must keep loading unchanged: the check only rejects a spec declaring a version *greater*
-- than the host's.
function CompatibilitySpec:should_keep_accepting_an_extension_built_against_api_version_1()
  eq( Extensions.API_VERSION, 4 )
  eq( Extensions.register( spec( "nether_vortex", { api_version = 1 } ) ), true )

  eq( Extensions.all()[ 1 ].incompatible, nil )
  eq( Extensions.is_enabled( "nether_vortex" ), true )
end

-- The version this host publishes is always accepted; an extension that asks for more than
-- the host has is the only rejection.
function CompatibilitySpec:should_accept_an_extension_built_against_the_current_api_version()
  eq( Extensions.register( spec( "auto_robin", { api_version = 3 } ) ), true )

  eq( Extensions.all()[ 1 ].incompatible, nil )
  eq( Extensions.is_enabled( "auto_robin" ), true )
end

function CompatibilitySpec:should_not_enable_an_incompatible_extension_even_when_the_db_says_on()
  local db = attach()
  Extensions.register( spec( "future", { api_version = Extensions.API_VERSION + 1 } ) )
  db.future = true

  local enabled = false
  Extensions.clear()
  attach()
  Extensions.register( spec( "future", {
    api_version = Extensions.API_VERSION + 1,
    on_enable = function() enabled = true end
  } ) )
  Extensions.enable( context )

  eq( enabled, false )
end

function CompatibilitySpec:should_refuse_to_turn_an_incompatible_extension_on()
  local db = attach()
  Extensions.register( spec( "future", { api_version = Extensions.API_VERSION + 1 } ) )

  Extensions.set_enabled( "future", true )

  eq( db.future, nil )
  eq( Extensions.is_enabled( "future" ), false )
end

EnabledStateSpec = {}

function EnabledStateSpec:setUp() Extensions.clear() end

function EnabledStateSpec:should_be_on_by_default()
  attach()
  Extensions.register( spec( "nether_vortex" ) )

  eq( Extensions.is_enabled( "nether_vortex" ), true )
end

function EnabledStateSpec:should_honour_an_opt_in_default()
  attach()
  Extensions.register( spec( "quiet", { default_enabled = false } ) )

  eq( Extensions.is_enabled( "quiet" ), false )
end

function EnabledStateSpec:should_read_the_db_over_the_default()
  local db = attach()
  Extensions.register( spec( "nether_vortex" ) )
  Extensions.register( spec( "quiet", { default_enabled = false } ) )

  db.nether_vortex = false
  db.quiet = true

  eq( Extensions.is_enabled( "nether_vortex" ), false )
  eq( Extensions.is_enabled( "quiet" ), true )
end

function EnabledStateSpec:should_report_an_unknown_extension_as_off()
  attach()

  eq( Extensions.is_enabled( "never_installed" ), false )
end

function EnabledStateSpec:should_fall_back_to_the_default_before_a_db_is_attached()
  Extensions.register( spec( "nether_vortex" ) )

  eq( Extensions.is_enabled( "nether_vortex" ), true )
end

-- Named by its title rather than its db key: "nether_vortex extension is enabled" is not
-- a sentence anybody wants to read in their chat frame.
function EnabledStateSpec:should_say_which_extension_was_toggled()
  attach()
  Extensions.register( spec( "nether_vortex", { title = "Nether Vortex" } ) )

  Extensions.set_enabled( "nether_vortex", false )
  eq( last_printed(), "RollFor: Nether Vortex extension is disabled." )

  Extensions.set_enabled( "nether_vortex", true )
  eq( last_printed(), "RollFor: Nether Vortex extension is enabled." )
end

function EnabledStateSpec:should_persist_a_change()
  local db = attach()
  Extensions.register( spec( "nether_vortex" ) )

  Extensions.set_enabled( "nether_vortex", false )

  eq( db.nether_vortex, false )
  eq( Extensions.is_enabled( "nether_vortex" ), false )
end

-- Everything downstream captured its collaborators when the chains were built, so the
-- toggle cannot take effect until they are built again.
function EnabledStateSpec:should_ask_for_a_ui_reload_when_toggled()
  local _, reloads = attach()
  Extensions.register( spec( "nether_vortex" ) )

  Extensions.set_enabled( "nether_vortex", false )

  eq( #reloads, 1 )
  eq( reloads[ 1 ].extension, "nether_vortex" )
end

function EnabledStateSpec:should_ignore_a_toggle_for_an_unknown_extension()
  local db, reloads = attach()

  Extensions.set_enabled( "never_installed", true )

  eq( db.never_installed, nil )
  eq( #reloads, 0 )
end

PhaseSpec = {}

function PhaseSpec:setUp() Extensions.clear() end

function PhaseSpec:should_run_on_enable_for_enabled_extensions_only()
  local db = attach()
  local enabled = {}

  Extensions.register( spec( "on", { on_enable = function() table.insert( enabled, "on" ) end } ) )
  Extensions.register( spec( "off", { on_enable = function() table.insert( enabled, "off" ) end } ) )
  db.off = false

  Extensions.enable( context )

  eq( enabled, { "on" } )
end

function PhaseSpec:should_run_the_phases_in_registration_order()
  attach()
  local calls = {}

  Extensions.register( spec( "one", { on_enable = function() table.insert( calls, "one" ) end } ) )
  Extensions.register( spec( "two", { on_enable = function() table.insert( calls, "two" ) end } ) )

  Extensions.enable( context )

  eq( calls, { "one", "two" } )
end

function PhaseSpec:should_hand_each_extension_a_context_built_for_its_own_name()
  attach()
  local seen = {}

  local function record( name )
    return function( ctx ) seen[ name ] = ctx.name end
  end

  Extensions.register( spec( "one", { on_enable = record( "one" ) } ) )
  Extensions.register( spec( "two", { on_enable = record( "two" ) } ) )

  Extensions.enable( function( name ) return { name = name } end )

  eq( seen, { one = "one", two = "two" } )
end

function PhaseSpec:should_only_run_on_ready_for_extensions_that_were_enabled()
  local db = attach()
  local ready = {}

  Extensions.register( spec( "on", { on_ready = function() table.insert( ready, "on" ) end } ) )
  Extensions.register( spec( "off", { on_ready = function() table.insert( ready, "off" ) end } ) )
  db.off = false

  Extensions.enable( context )
  Extensions.ready( context )

  eq( ready, { "on" } )
  eq( #Extensions.enabled(), 1 )
end

function PhaseSpec:should_cope_with_an_extension_that_has_no_on_ready()
  attach()
  Extensions.register( spec( "nether_vortex" ) )

  Extensions.enable( context )
  Extensions.ready( context )

  eq( #Extensions.enabled(), 1 )
end

function PhaseSpec:should_re_evaluate_enabled_state_on_every_enable()
  local db = attach()
  local calls = 0

  Extensions.register( spec( "nether_vortex", { on_enable = function() calls = calls + 1 end } ) )

  Extensions.enable( context )
  eq( calls, 1 )

  db.nether_vortex = false
  Extensions.enable( context )

  eq( calls, 1 )
  eq( #Extensions.enabled(), 0 )
end

FailureSpec = {}

function FailureSpec:setUp() Extensions.clear() end

-- A raid with a degraded addon beats a raid with no addon: a broken extension must not
-- take RollFor's login down with it.
function FailureSpec:should_survive_an_extension_that_throws_during_on_enable()
  attach()
  local other_ran = false

  Extensions.register( spec( "broken", { on_enable = function() error( "boom" ) end } ) )
  Extensions.register( spec( "fine", { on_enable = function() other_ran = true end } ) )

  Extensions.enable( context )

  eq( other_ran, true )
  eq( Extensions.all()[ 1 ].failed, true )
end

function FailureSpec:should_not_run_on_ready_for_an_extension_that_failed_to_enable()
  attach()
  local ready = false

  Extensions.register( spec( "broken", {
    on_enable = function() error( "boom" ) end,
    on_ready = function() ready = true end
  } ) )

  Extensions.enable( context )
  Extensions.ready( context )

  eq( ready, false )
end

function FailureSpec:should_survive_an_extension_that_throws_during_on_ready()
  attach()
  local other_ran = false

  Extensions.register( spec( "broken", { on_ready = function() error( "boom" ) end } ) )
  Extensions.register( spec( "fine", { on_ready = function() other_ran = true end } ) )

  Extensions.enable( context )
  Extensions.ready( context )

  eq( other_ran, true )
end

function FailureSpec:should_clear_a_previous_failure_when_enabling_again()
  attach()
  local explode = true

  Extensions.register( spec( "flaky", { on_enable = function() if explode then error( "boom" ) end end } ) )

  Extensions.enable( context )
  eq( Extensions.all()[ 1 ].failed, true )

  explode = false
  Extensions.enable( context )

  eq( Extensions.all()[ 1 ].failed, nil )
end

os.exit( lu.LuaUnit.run() )
