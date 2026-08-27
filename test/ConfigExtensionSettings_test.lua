---@diagnostic disable: inject-field
package.path = "./?.lua;" .. package.path .. ";../?.lua;../RollFor/?.lua;../RollFor/libs/?.lua"

require( "src/compat" )
local utils = require( "test/utils" )
local lu, eq = utils.luaunit( "assertEquals" )
utils.multi_require_src( "DebugBuffer", "Module", "Types" )
require( "src/modules" )
local EventBus = require( "src/EventBus" )
local Config = require( "src/Config" )

utils.mock_wow_api()

-- A setting an extension contributes has to be indistinguishable from one of core's own:
-- same getter, same setter, same `toggles` entry -- because that entry is what the
-- options window renders from and what /rf config reads.

local function new_config( db )
  return Config.new( db or {}, EventBus.new() )
end

ExtensionToggleSpec = {}

function ExtensionToggleSpec:should_add_a_getter_and_a_setter()
  local config = new_config()

  config.register_toggle( "vortex_announce", { cmd = "nv-announce", display = "Vortex announcements" }, true )

  eq( type( config.vortex_announce ), "function" )
  eq( type( config.set_vortex_announce ), "function" )
  eq( config.vortex_announce(), true )
end

function ExtensionToggleSpec:should_write_the_default_into_the_db()
  local db = {}
  local config = new_config( db )

  config.register_toggle( "vortex_announce", { cmd = "nv-announce", display = "Vortex announcements" }, false )

  eq( db.vortex_announce, false )
  eq( config.vortex_announce(), false )
end

-- The stored value is the player's decision from a previous session; a default must not
-- overwrite it on the next login.
function ExtensionToggleSpec:should_not_overwrite_a_stored_value()
  local db = { vortex_announce = false }
  local config = new_config( db )

  config.register_toggle( "vortex_announce", { cmd = "nv-announce", display = "Vortex announcements" }, true )

  eq( config.vortex_announce(), false )
end

function ExtensionToggleSpec:should_persist_a_change_through_the_setter()
  local db = {}
  local config = new_config( db )
  config.register_toggle( "vortex_announce", { cmd = "nv-announce", display = "Vortex announcements" }, true )

  config.set_vortex_announce( false )

  eq( db.vortex_announce, false )
  eq( config.vortex_announce(), false )
end

-- What the options window and the slash command both read.
function ExtensionToggleSpec:should_appear_among_the_toggles()
  local config = new_config()

  config.register_toggle( "vortex_announce", { cmd = "nv-announce", display = "Vortex announcements" }, true )

  eq( config.toggles.vortex_announce.display, "Vortex announcements" )
  eq( config.toggles.vortex_announce.cmd, "nv-announce" )
end

function ExtensionToggleSpec:should_refuse_to_shadow_an_existing_setting()
  local config = new_config()
  local original = config.toggles.auto_loot

  config.register_toggle( "auto_loot", { cmd = "hijack", display = "Hijacked" }, false )

  eq( config.toggles.auto_loot, original )
end

function ExtensionToggleSpec:should_ignore_a_registration_without_a_key()
  local config = new_config()

  config.register_toggle( "", { cmd = "nope", display = "Nope" }, true )

  eq( config.toggles[ "" ], nil )
end

os.exit( lu.LuaUnit.run() )
