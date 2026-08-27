---@diagnostic disable: inject-field
package.path = "./?.lua;" .. package.path .. ";../?.lua;../RollFor/?.lua;../RollFor/libs/?.lua"

require( "src/compat" )
local utils = require( "test/utils" )
local lu, eq = utils.luaunit( "assertEquals" )

-- main.lua wires the settings panel to the options renderer, and that wiring is a lambda
-- rather than a named function, so nothing else covers it.
--
-- It shipped broken once: the lambda took ( parent, section ) while the panel called it
-- with ( parent, section, extension_name ), so every extension page was handed a nil
-- name, found no extension, and rendered nothing. Both sides were individually tested
-- and both were individually right.

local EXTENSION = "wiring_probe"

utils.mock_wow_api()
utils.mock_libraries()
utils.load_real_stuff()

-- Registered after the addon's files have loaded but before it builds its components,
-- which is the order the client produces: an extension addon runs at file scope, RollFor
-- builds at PLAYER_LOGIN.
local Extensions = RollFor.Extensions

-- Records what core handed the extension when it asked for its page.
local asked = { times = 0 }

Extensions.register( {
  name = EXTENSION,
  title = "Wiring Probe",
  api_version = Extensions.API_VERSION,
  on_enable = function() end,
  options_page = function( ctx, parent )
    asked.times = asked.times + 1
    asked.ctx = ctx
    asked.parent = parent

    return { show = function() asked.shown = (asked.shown or 0) + 1 end }
  end
} )

utils.player( "Psikutas" )

local rf = utils.load_roll_for()

ExtensionOptionsWiringSpec = {}

function ExtensionOptionsWiringSpec:should_build_a_page_for_the_registered_extension()
  eq( rf.extension_options[ EXTENSION ] ~= nil, true )
end

-- The settings window shows a page by calling OnRefresh on its canvas. If core did not
-- wire that to the extension's page, the page would be built once and then never told to
-- read anything again.
function ExtensionOptionsWiringSpec:should_refresh_the_extensions_page_when_it_is_shown()
  local before = asked.shown or 0

  rf.interface_options.get_page( "Wiring Probe" ).OnRefresh()

  eq( (asked.shown or 0), before + 1 )
end

function ExtensionOptionsWiringSpec:should_not_build_extension_pages_for_extensions_that_do_not_exist()
  eq( rf.extension_options.never_registered, nil )
end

function ExtensionOptionsWiringSpec:should_still_build_the_general_page()
  eq( rf.options ~= nil, true )
end

-- An extension owns its page: core asks for it rather than rendering one, and asks once,
-- when it registers the category.
function ExtensionOptionsWiringSpec:should_ask_the_extension_to_build_its_own_page()
  eq( asked.times, 1 )
  eq( rf.extension_options[ EXTENSION ].show ~= nil, true )
end

-- Without the canvas there is nothing to build into, and without the context there are no
-- builders to build with.
function ExtensionOptionsWiringSpec:should_hand_over_the_canvas_and_a_context()
  eq( asked.parent ~= nil, true )
  eq( type( asked.ctx.popup_builder ), "function" )
  eq( type( asked.ctx.gui_elements ), "table" )
  eq( type( asked.ctx.db ), "function" )
end

-- The Enabled checkbox is the extension's to draw, so the context has to carry its own
-- on/off state -- otherwise it would have to reach back into core's registry itself.
function ExtensionOptionsWiringSpec:should_give_the_extension_its_own_enabled_state()
  eq( asked.ctx.is_enabled(), true )
  eq( type( asked.ctx.set_enabled ), "function" )
  eq( asked.ctx.title, "Wiring Probe" )
end

os.exit( lu.LuaUnit.run() )
