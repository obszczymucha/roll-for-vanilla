---@diagnostic disable: inject-field
package.path = "./?.lua;" .. package.path .. ";../?.lua;../RollFor/?.lua;../RollFor/libs/?.lua"

require( "src/compat" )
local utils = require( "test/utils" )
local lu, eq = utils.luaunit( "assertEquals" )
require( "src/modules" )
local Extensions = require( "src/Extensions" )
local InterfaceOptions = require( "src/InterfaceOptions" )

-- A stand-in for the game's Settings API, recording what an addon asked it to do. The
-- real one is a black box from here: what we can check is that RollFor describes a canvas
-- category and then actually registers it, which are two separate calls and only the
-- second one puts the page in the AddOns list.
local function mock_api()
  local api = {
    registered = {},
    subcategories = {},
    opened = {},
    font_strings = {}
  }

  api.CreateFrame = function()
    local frame = {}

    frame.CreateFontString = function()
      local font_string = {}

      font_string.SetPoint = function() end
      font_string.SetJustifyH = function() end
      font_string.SetText = function( _, text ) font_string.text = text end

      table.insert( api.font_strings, font_string )

      return font_string
    end

    return frame
  end

  api.Settings = {
    RegisterCanvasLayoutCategory = function( frame, name )
      return { GetID = function() return string.format( "%s_id", name ) end, frame = frame, name = name }
    end,
    RegisterCanvasLayoutSubcategory = function( parent, frame, name )
      local subcategory = { GetID = function() return string.format( "%s_id", name ) end,
        frame = frame, name = name, parent = parent }
      table.insert( api.subcategories, subcategory )
      return subcategory
    end,
    RegisterAddOnCategory = function( category ) table.insert( api.registered, category ) end,
    OpenToCategory = function( category_id ) table.insert( api.opened, category_id ) end
  }

  return api
end

-- Stands in for the OptionsFrame the panel hosts. What the panel owes it is a parent
-- frame to render into and a show() every time the page is displayed.
local function mock_content()
  local content = { shown = 0 }

  content.show = function() content.shown = content.shown + 1 end

  return content
end

---@param api table
local function new_panel( api )
  local built = {}
  local options = InterfaceOptions.new( api, function( parent, section, extension_name )
    local content = mock_content()
    content.parent = parent
    built[ extension_name or section ] = content
    return content
  end )

  return options, built
end

---@param count number
local function register_extensions( count )
  for i = 1, count do
    Extensions.register( {
      name = string.format( "extension_%s", i ),
      title = string.format( "Extension %s", i ),
      api_version = Extensions.API_VERSION,
      on_enable = function() end
    } )
  end
end

---@param name string
local function subcategory( api, name )
  for _, entry in ipairs( api.subcategories ) do
    if entry.name == name then return entry end
  end
end

InterfaceOptionsSpec = {}

function InterfaceOptionsSpec:setUp() Extensions.clear() end
function InterfaceOptionsSpec:tearDown() Extensions.clear() end

function InterfaceOptionsSpec:should_register_a_canvas_category_called_rollfor()
  local api = mock_api()

  new_panel( api )

  eq( #api.registered, 1 )
  eq( api.registered[ 1 ].name, "RollFor" )
end

-- Describing the category is not the same as listing it. Registering the canvas layout
-- without the second call leaves the page built and unreachable.
function InterfaceOptionsSpec:should_register_the_frame_it_built()
  local api = mock_api()

  local options = new_panel( api )

  eq( api.registered[ 1 ].frame, options.get_frame() )
end

-- The options render into the canvas, so the panel has to hand its own frame over as
-- the parent rather than leaving the content to find one.
-- RollFor's own settings sit on the RollFor page, with a page per installed extension
-- under it. No grouping levels: every entry in the settings list is a button, so a
-- "General" or "Extensions" node would only be another page to click through.
function InterfaceOptionsSpec:should_register_a_page_per_extension_and_nothing_else()
  local api = mock_api()
  register_extensions( 2 )

  new_panel( api )

  eq( #api.subcategories, 2 )
  eq( api.subcategories[ 1 ].name, "Extension 1" )
  eq( api.subcategories[ 2 ].name, "Extension 2" )
  eq( subcategory( api, "General" ), nil )
  eq( subcategory( api, "Extensions" ), nil )
end

-- The RollFor page is the general settings, not a landing page.
function InterfaceOptionsSpec:should_build_the_general_settings_onto_the_rollfor_page()
  local api = mock_api()

  local options, built = new_panel( api )

  eq( built.general.parent, options.get_frame() )
  eq( api.registered[ 1 ].frame, options.get_frame() )
end

-- Named by its title, which is what a person reading the tree is looking for -- not the
-- db key the registry uses.
function InterfaceOptionsSpec:should_name_an_extension_page_by_its_title()
  local api = mock_api()
  Extensions.register( {
    name = "nether_vortex",
    title = "Nether Vortex",
    api_version = Extensions.API_VERSION,
    on_enable = function() end
  } )

  new_panel( api )

  eq( subcategory( api, "Nether Vortex" ) ~= nil, true )
  eq( subcategory( api, "nether_vortex" ), nil )
end

-- Each extension page is built for its own extension; otherwise every one of them would
-- show the first extension's summary and toggle the first extension's switch.
function InterfaceOptionsSpec:should_build_each_extension_page_for_its_own_extension()
  local api = mock_api()
  register_extensions( 2 )

  local _, built = new_panel( api )

  eq( built.extension_1.parent, subcategory( api, "Extension 1" ).frame )
  eq( built.extension_2.parent, subcategory( api, "Extension 2" ).frame )
end

-- An Extensions entry that opens onto an empty page tells you nothing except that you
-- clicked it. Plain RollFor should look like plain RollFor.
function InterfaceOptionsSpec:should_have_no_subcategories_when_nothing_is_installed()
  local api = mock_api()

  local _, built = new_panel( api )

  eq( #api.subcategories, 0 )
  eq( built.general ~= nil, true )
end

-- Subcategories are listed through their parent, so only the parent is registered as an
-- addon category. Registering a subcategory too would list it twice.
function InterfaceOptionsSpec:should_hang_every_extension_page_off_the_rollfor_category()
  local api = mock_api()
  register_extensions( 1 )

  new_panel( api )

  eq( #api.registered, 1 )

  for _, entry in ipairs( api.subcategories ) do
    eq( entry.parent, api.registered[ 1 ] )
  end
end

-- Each page renders into the canvas the panel registered for it, and each is built for
-- its own section -- otherwise both would show the same settings.
-- The settings window calls OnRefresh every time the page is displayed. Without this,
-- the controls would show the config as it was when the page was first built.
function InterfaceOptionsSpec:should_refresh_a_page_when_it_is_shown()
  local api = mock_api()
  register_extensions( 1 )
  local options, built = new_panel( api )

  eq( built.general.shown, 0 )

  options.get_frame().OnRefresh()
  options.get_frame().OnRefresh()

  eq( built.general.shown, 2 )
  eq( built.extension_1.shown, 0 )
end

function InterfaceOptionsSpec:should_not_open_the_panel_on_its_own()
  local api = mock_api()

  new_panel( api )

  eq( api.opened, {} )
end

-- What /rf does now: straight to the settings, no page to click through first.
function InterfaceOptionsSpec:should_open_to_the_rollfor_page()
  local api = mock_api()
  local options = new_panel( api )

  options.open()

  eq( api.opened, { "RollFor_id" } )
end

os.exit( lu.LuaUnit.run() )
