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
local options_buttons, checkbox, slider, editbox, dropdown, text = gui.options_buttons, gui.checkbox, gui.slider, gui.editbox, gui.dropdown, gui.text
local title = text( "RollFor Options", 6 )
local ItemQuality = RollFor.Types.ItemQuality

u.mock_wow_api()

-- OptionsFrame hardcodes which real settings it shows (and which widget renders each), so every
-- test that calls show() needs a getter/setter for all of them, not just the one under test.
---@return table<string, any>
local function default_setting_values()
  return {
    default_rolling_time_seconds = 8,
    master_loot_frame_rows = 5,
    ms_roll_threshold = 100,
    os_roll_threshold = 99,
    tmog_roll_threshold = 98,
    master_loot_threshold = ItemQuality.Rare,
  }
end

---@param toggles table<string, boolean>?
---@param setting_overrides table<string, any>?
local function mock_config( toggles, setting_overrides )
  local db = default_setting_values()
  for key, value in pairs( setting_overrides or {} ) do db[ key ] = value end

  local toggle_definitions = {}
  for key, value in pairs( toggles or {} ) do
    db[ key ] = value
    toggle_definitions[ key ] = { display = key }
  end

  local config = {
    classic_look = function() return false end,
    toggles = toggle_definitions,
  }

  for key in pairs( db ) do
    config[ key ] = function() return db[ key ] end
    config[ "set_" .. key ] = function( value ) db[ key ] = value; return true end
  end

  for key in pairs( toggle_definitions ) do
    config[ "toggle_" .. key ] = function() db[ key ] = not db[ key ] end
  end

  return config, db
end

local function new_options( config )
  local db = Db.new( {} )
  local c = config or mock_config()
  return options_frame_mock.new( popup_builder.new(), c, db( "options" ) )
end

local master_loot_threshold_options = {
  { value = ItemQuality.Uncommon, label = RollFor.colorize_item_by_quality( "Uncommon", ItemQuality.Uncommon ) },
  { value = ItemQuality.Rare, label = RollFor.colorize_item_by_quality( "Rare", ItemQuality.Rare ) },
  { value = ItemQuality.Epic, label = RollFor.colorize_item_by_quality( "Epic", ItemQuality.Epic ) },
}

-- The full options popup content in the order OptionsFrameContentTransformer emits it: title,
-- checkboxes, editboxes, sliders, dropdown, buttons. `value_overrides` swaps in non-default
-- editbox/slider/dropdown values; trailing varargs are extra checkbox lines to show.
---@param value_overrides table<string, any>?
local function default_popup( value_overrides, ... )
  local v = default_setting_values()
  for key, value in pairs( value_overrides or {} ) do v[ key ] = value end

  local content = { title }
  for _, line in ipairs( { ... } ) do table.insert( content, line ) end

  table.insert( content, editbox( "MS roll threshold", v.ms_roll_threshold, 10 ) )
  table.insert( content, editbox( "OS roll threshold", v.os_roll_threshold, 4 ) )
  table.insert( content, slider( "Default rolling time (seconds)", v.default_rolling_time_seconds, 4, 15, 10 ) )
  table.insert( content, slider( "Master loot frame rows", v.master_loot_frame_rows, 5, 20, 4 ) )
  table.insert( content, dropdown( "Master loot threshold", v.master_loot_threshold, master_loot_threshold_options, 10 ) )
  table.insert( content, options_buttons( "Close" ) )

  return unpack( content )
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
  options.should_display( default_popup() )

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
  local config = mock_config( { zeta_setting = true, alpha_setting = false } )
  local options = new_options( config )

  -- When
  options.show()

  -- Then
  options.should_display( default_popup(
    nil,
    checkbox( "alpha_setting", false, 10 ),
    checkbox( "zeta_setting", true, 2 )
  ) )
end

function OptionsFrameSpec:should_toggle_a_boolean_config_setting_when_its_checkbox_is_clicked()
  -- Given
  local config = mock_config( { auto_loot = false } )
  local options = new_options( config )
  options.show()

  -- Then
  eq( config.auto_loot(), false )

  -- When
  options.toggle_setting( "auto_loot" )

  -- Then
  eq( config.auto_loot(), true )
end

function OptionsFrameSpec:should_not_display_superwow_auto_loot_coins_setting()
  -- Given
  local config = mock_config( { superwow_auto_loot_coins = true, auto_loot = false } )
  local options = new_options( config )

  -- When
  options.show()

  -- Then
  options.should_display( default_popup(
    nil,
    checkbox( "auto_loot", false, 10 )
  ) )
end

function OptionsFrameSpec:should_display_slider_settings_with_their_bounds_sorted_by_label()
  -- Given
  local config = mock_config( nil, { default_rolling_time_seconds = 12, master_loot_frame_rows = 8 } )
  local options = new_options( config )

  -- When
  options.show()

  -- Then
  options.should_display( default_popup( { default_rolling_time_seconds = 12, master_loot_frame_rows = 8 } ) )
end

function OptionsFrameSpec:should_change_a_slider_config_setting_when_its_value_changes()
  -- Given
  local config, db = mock_config()
  local options = new_options( config )
  options.show()

  -- When
  options.change_slider( "master_loot_frame_rows", 12 )

  -- Then
  eq( db.master_loot_frame_rows, 12 )
end

function OptionsFrameSpec:should_display_editbox_settings_sorted_by_label()
  -- Given
  local config = mock_config( nil, { ms_roll_threshold = 95, os_roll_threshold = 90 } )
  local options = new_options( config )

  -- When
  options.show()

  -- Then
  options.should_display( default_popup( { ms_roll_threshold = 95, os_roll_threshold = 90 } ) )
end

function OptionsFrameSpec:should_change_an_editbox_config_setting_when_a_valid_value_is_committed()
  -- Given
  local config, db = mock_config()
  local options = new_options( config )
  options.show()

  -- When
  options.change_editbox( "ms_roll_threshold", 95 )

  -- Then
  eq( db.ms_roll_threshold, 95 )
end

function OptionsFrameSpec:should_display_the_master_loot_threshold_dropdown_with_colored_options()
  -- Given
  local config = mock_config( nil, { master_loot_threshold = ItemQuality.Epic } )
  local options = new_options( config )

  -- When
  options.show()

  -- Then
  options.should_display( default_popup( { master_loot_threshold = ItemQuality.Epic } ) )
end

function OptionsFrameSpec:should_change_a_dropdown_config_setting_when_an_option_is_selected()
  -- Given
  local config, db = mock_config()
  local options = new_options( config )
  options.show()

  -- When
  options.change_dropdown( "master_loot_threshold", ItemQuality.Epic )

  -- Then
  eq( db.master_loot_threshold, ItemQuality.Epic )
end

os.exit( lu.LuaUnit.run() )
