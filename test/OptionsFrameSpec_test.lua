package.path = "./?.lua;" .. package.path .. ";../?.lua;../RollFor/?.lua;../RollFor/libs/?.lua"

require( "src/bcc/compat" )
local u = require( "test/utils" )
local lu, eq = u.luaunit( "assertEquals" ) ---@diagnostic disable-line: unused-local
u.multi_require_src( "DebugBuffer", "Module", "Types" )
require( "src/modules" )
local Db = require( "src/Db" )
local popup_builder = require( "mocks/PopupBuilder" )
local options_frame_mock = require( "mocks/OptionsFrame" )
local gui = require( "test/gui_helpers" )
local options_buttons, checkbox, text = gui.options_buttons, gui.checkbox, gui.text
local title = text( "RollFor Options", 6 )

u.mock_wow_api()

local function mock_config()
  return {
    classic_look = function() return false end
  }
end

---@param settings table<string, boolean>
local function mock_config_with_toggles( settings )
  local db = {}
  local toggles = {}

  for key, value in pairs( settings ) do
    db[ key ] = value
    toggles[ key ] = { display = key }
  end

  local config = mock_config()
  config.toggles = toggles

  for key in pairs( settings ) do
    config[ key ] = function() return db[ key ] end
    config[ "toggle_" .. key ] = function() db[ key ] = not db[ key ] end
  end

  return config
end

local function new_options( config )
  local db = Db.new( {} )
  return options_frame_mock.new( popup_builder.new(), config or mock_config(), db( "options" ) )
end

OptionsFrameSpec = {}

function OptionsFrameSpec:should_be_hidden_by_default()
  -- Given
  local options = new_options()

  -- Then
  options.should_be_hidden()
end

function OptionsFrameSpec:should_display_close_button_that_hides_the_frame()
  -- Given
  local options = new_options()

  -- When
  options.show()

  -- Then
  options.should_display(
    title,
    options_buttons( "Close" )
  )

  -- When
  options.click( "Close" )

  -- Then
  options.should_be_hidden()
end

function OptionsFrameSpec:should_toggle_visibility()
  -- Given
  local options = new_options()
  options.should_be_hidden()

  -- When
  options.toggle()

  -- Then
  options.should_be_visible()

  -- When
  options.toggle()

  -- Then
  options.should_be_hidden()
end

function OptionsFrameSpec:should_display_boolean_config_settings_as_checkboxes_sorted_by_label()
  -- Given
  local config = mock_config_with_toggles( { zeta_setting = true, alpha_setting = false } )
  local options = new_options( config )

  -- When
  options.show()

  -- Then
  options.should_display(
    title,
    checkbox( "alpha_setting", false, 10 ),
    checkbox( "zeta_setting", true, 2 ),
    options_buttons( "Close" )
  )
end

function OptionsFrameSpec:should_toggle_a_boolean_config_setting_when_its_checkbox_is_clicked()
  -- Given
  local config = mock_config_with_toggles( { auto_loot = false } )
  local options = new_options( config )
  options.show()

  -- Then
  eq( config.auto_loot(), false )
  options.should_display(
    title,
    checkbox( "auto_loot", false, 10 ),
    options_buttons( "Close" )
  )

  -- When
  options.toggle_setting( "auto_loot" )

  -- Then
  eq( config.auto_loot(), true )

  -- When
  options.show()

  -- Then
  options.should_display(
    title,
    checkbox( "auto_loot", true, 10 ),
    options_buttons( "Close" )
  )
end

function OptionsFrameSpec:should_not_display_superwow_auto_loot_coins_setting()
  -- Given
  local config = mock_config_with_toggles( { superwow_auto_loot_coins = true, auto_loot = false } )
  local options = new_options( config )

  -- When
  options.show()

  -- Then
  options.should_display(
    title,
    checkbox( "auto_loot", false, 10 ),
    options_buttons( "Close" )
  )
end

os.exit( lu.LuaUnit.run() )
