package.path = "./?.lua;" .. package.path .. ";../?.lua;../RollFor/?.lua;../RollFor/libs/?.lua"

require( "src/compat" )
local u = require( "test/utils" )
local lu, eq = u.luaunit( "assertEquals" ) ---@diagnostic disable-line: unused-local
u.multi_require_src( "DebugBuffer", "Module", "Types", "Chain", "Extensions" )
require( "src/modules" )
local Db = require( "src/Db" )
local Config = require( "src/Config" )
local Extensions = require( "src/Extensions" )
local EventBus = require( "src/EventBus" )
local popup_builder = require( "mocks/PopupBuilder" )
local options_frame_mock = require( "mocks/OptionsFrame" )
local gui = require( "test/gui_helpers" )
local checkbox, slider, editbox, dropdown = gui.checkbox, gui.slider, gui.editbox, gui.dropdown
local priority_row = gui.priority_row
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
    sr_roll_spacing = 24,
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

  return config, db
end

-- The registered award policies, in the order they run. Empty by default: the priority list
-- only appears once there are two of them to rank, so every page that is not about it is
-- drawn without one.
---@param names string[]?
local function mock_award_policies( names )
  local policies = {}
  local moves = {}

  for _, name in ipairs( names or {} ) do
    table.insert( policies, { name = string.lower( name ), title = name } )
  end

  return {
    all = function() return policies end,
    move = function( position, offset )
      table.insert( moves, { position = position, offset = offset } )

      local target = position + offset
      if not policies[ position ] or not policies[ target ] then return false end

      policies[ position ], policies[ target ] = policies[ target ], policies[ position ]
      return true
    end,
    moves = moves
  }
end

-- The settings panel canvas the options render into. A bare frame is enough: what the
-- options do with it is anchor to it and parent to it.
local function new_options( config, section, award_policies )
  local c = config or mock_config()
  return options_frame_mock.new( popup_builder.new(), c, award_policies or mock_award_policies(),
    RollFor.api.CreateFrame( "Frame" ), section )
end

local master_loot_threshold_options = {
  { value = ItemQuality.Uncommon, label = RollFor.colorize_item_by_quality( "Uncommon", ItemQuality.Uncommon ) },
  { value = ItemQuality.Rare, label = RollFor.colorize_item_by_quality( "Rare", ItemQuality.Rare ) },
  { value = ItemQuality.Epic, label = RollFor.colorize_item_by_quality( "Epic", ItemQuality.Epic ) },
}

-- Padding OptionsFrameContentTransformer gives a line: the first setting starts flush at
-- the top of the page, the rest are spaced by what kind of control they are.
local type_paddings = { checkbox = 5, editbox = 10, slider = 10, dropdown = 8, section_header = 13, paragraph = 9 }

-- Whatever follows a block of prose gets more room than the gap between two controls.
local after_paragraph_padding = 16

-- The full options page in the order OptionsFrame declares it: checkboxes, editboxes,
-- sliders, dropdown. No title and no buttons -- the settings window supplies its own
-- header, and there is nothing to close. `value_overrides` swaps in non-default editbox/
-- slider/dropdown values; trailing varargs are the checkbox lines to show, in declaration
-- order.
---@param value_overrides table<string, any>?
local function default_popup( value_overrides, ... )
  local v = default_setting_values()
  for key, value in pairs( value_overrides or {} ) do v[ key ] = value end

  -- Which RollFor this is, above everything it configures. First line on every general page,
  -- so every expectation here starts with it.
  local settings = { {
    type = "paragraph",
    value = string.format( "%s %s", RollFor.colors.blue( "RollFor" ), RollFor.colors.grey( "v2.6" ) )
  } }

  for _, line in ipairs( { ... } ) do table.insert( settings, line ) end

  table.insert( settings, editbox( "MS roll threshold", v.ms_roll_threshold, 0 ) )
  table.insert( settings, editbox( "OS roll threshold", v.os_roll_threshold, 0 ) )
  table.insert( settings, slider( "Default rolling time (seconds)", v.default_rolling_time_seconds, 4, 15, 0 ) )
  table.insert( settings, slider( "Master loot frame rows", v.master_loot_frame_rows, 5, 20, 0 ) )
  table.insert( settings, slider( "SR roll spacing", v.sr_roll_spacing, 16, 28, 1 ) )
  table.insert( settings, dropdown( "Master loot threshold", v.master_loot_threshold, master_loot_threshold_options ) )

  local content = {}

  for i, line in ipairs( settings ) do
    local previous = settings[ i - 1 ]

    line.padding = i == 1 and 0
        or previous and previous.type == "paragraph" and after_paragraph_padding
        or type_paddings[ line.type ]

    table.insert( content, line )
  end

  return unpack( content )
end

---@param extension_name string
local function new_extension_page( extension_name )
  local c = mock_config()
  return options_frame_mock.new( popup_builder.new(), c, mock_award_policies(),
    RollFor.api.CreateFrame( "Frame" ), "extension", extension_name )
end

---@param lines table[]
local function page_of( lines )
  local content = {}

  for i, line in ipairs( lines ) do
    local previous = lines[ i - 1 ]

    line.padding = i == 1 and 0
        or previous and previous.type == "paragraph" and after_paragraph_padding
        or type_paddings[ line.type ]

    table.insert( content, line )
  end

  return unpack( content )
end

OptionsFrameSpec = {}

-- Showing is what the settings window asks for when the page is displayed. There is no
-- hiding, closing or toggling to test any more: the window owns all three.
function OptionsFrameSpec:should_render_its_settings_when_shown()
  -- Given
  local options = new_options()

  -- When
  options.show()

  -- Then
  options.should_display( default_popup() )
  options.should_be_visible()
end

-- The settings window calls show() on every visit, so a value changed elsewhere since
-- the page was last built has to be picked up rather than remembered.
function OptionsFrameSpec:should_reread_the_config_every_time_it_is_shown()
  -- Given
  local config, db = mock_config( { auto_group_loot = true } )
  local options = new_options( config )
  options.show()

  -- When
  db.auto_group_loot = false
  options.show()

  -- Then
  options.should_display( default_popup( nil, checkbox( "auto_group_loot", false ) ) )
end

function OptionsFrameSpec:should_display_boolean_config_settings_as_checkboxes_in_declaration_order()
  -- Given
  local config = mock_config( { classic_look = true, auto_group_loot = false } )
  local options = new_options( config )

  -- When
  options.show()

  -- Then
  options.should_display( default_popup(
    nil,
    checkbox( "auto_group_loot", false ),
    checkbox( "classic_look", true )
  ) )
end

-- Against the real Config rather than the mock: the label and the default are Config's, and
-- a mock that is told both proves neither.
function OptionsFrameSpec:should_display_the_minimap_tooltip_commands_checkbox_disabled_by_default()
  -- Given
  local db = Db.new( {} )
  -- Config only ever notifies the bus (on a reload-requiring toggle), and nothing here
  -- flips one.
  ---@diagnostic disable-next-line: missing-fields
  local config = Config.new( db( "config" ), { notify = function() return 0 end } )
  local options = options_frame_mock.new( popup_builder.new(), config, mock_award_policies(), db( "options" ) )

  -- When
  options.show()

  -- Then
  local found

  for _, line in ipairs( options.content() ) do
    if line.type == "checkbox" and line.label == "Display slash commands in minimap tooltip" then found = line end
  end

  eq( found ~= nil, true )
  eq( found and found.value, false )
end

-- Which RollFor this is, above everything it configures. Same line the minimap tooltip shows:
-- it is what anyone is asked first when they report something, and it should not take a slash
-- command to find.
function OptionsFrameSpec:should_name_the_addon_and_its_version_first()
  -- Given
  local options = new_options()

  -- When
  options.show()

  -- Then
  local first = options.content()[ 1 ]

  eq( first.type, "paragraph" )
  eq( first.value, string.format( "%s %s",
    RollFor.colors.blue( "RollFor" ), RollFor.colors.grey( "v2.6" ) ) )
end

function OptionsFrameSpec:should_not_display_a_boolean_setting_the_config_does_not_define()
  -- Given
  local config = mock_config( { auto_group_loot = false, not_a_real_setting = true } )
  local options = new_options( config )

  -- When
  options.show()

  -- Then
  options.should_display( default_popup( nil, checkbox( "auto_group_loot", false ) ) )
end

function OptionsFrameSpec:should_toggle_a_boolean_config_setting_when_its_checkbox_is_clicked()
  -- Given
  local config = mock_config( { auto_group_loot = false } )
  local options = new_options( config )
  options.show()

  -- Then
  eq( config.auto_group_loot(), false )

  -- When
  options.toggle_setting( "auto_group_loot" )

  -- Then
  eq( config.auto_group_loot(), true )
end

-- An extension's settings go in core's config -- that is what register_toggle does, so /rf
-- config answers for them -- but this page renders an explicit list of core's own and nothing
-- else. That is the whole reason an extension carries an options page: it is the only place
-- its settings are actually visible.
function OptionsFrameSpec:should_not_display_a_setting_an_extension_registered()
  -- Given
  local config = mock_config( { auto_loot = true, auto_group_loot = false } )
  local options = new_options( config )

  -- When
  options.show()

  -- Then
  options.should_display( default_popup( nil, checkbox( "auto_group_loot", false ) ) )
end

function OptionsFrameSpec:should_display_slider_settings_with_their_bounds()
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
  options.change_slider( "Master loot frame rows", 12 )

  -- Then
  eq( db.master_loot_frame_rows, 12 )
end

function OptionsFrameSpec:should_display_editbox_settings()
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
  options.change_editbox( "MS roll threshold", 95 )

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
  options.change_dropdown( "Master loot threshold", ItemQuality.Epic )

  -- Then
  eq( db.master_loot_threshold, ItemQuality.Epic )
end

ExtensionPageSpec = {}

function ExtensionPageSpec:tearDown() Extensions.clear() end

-- Extensions get pages of their own; the general page must not grow a list of them.
function ExtensionPageSpec:should_not_list_extensions_on_the_general_page()
  Extensions.attach( {}, EventBus.new() )
  Extensions.register( {
    name = "nether_vortex",
    title = "Nether Vortex",
    api_version = Extensions.API_VERSION,
    on_enable = function() end
  } )

  local options = new_options()
  options.show()

  options.should_display( default_popup() )
end

---@param overrides table?
local function register_nether_vortex( overrides )
  local spec = {
    name = "nether_vortex",
    title = "Nether Vortex",
    api_version = Extensions.API_VERSION,
    on_enable = function() end
  }

  for key, value in pairs( overrides or {} ) do spec[ key ] = value end

  Extensions.attach( {}, EventBus.new() )
  Extensions.register( spec )
end

-- The page core falls back to when an extension supplies none of its own: the switch,
-- and nothing else. What the extension does is the extension's to describe, on the page
-- it builds itself.
function ExtensionPageSpec:should_show_only_an_enabled_checkbox()
  register_nether_vortex()

  local options = new_extension_page( "nether_vortex" )
  options.show()

  options.should_display( page_of( { checkbox( "Enabled", true ) } ) )
end

-- The version line belongs to the general page. An extension's page is the extension's, and
-- core's version is not what it is about.
function ExtensionPageSpec:should_not_put_cores_version_on_an_extensions_page()
  register_nether_vortex()

  local options = new_extension_page( "nether_vortex" )
  options.show()

  for _, line in ipairs( options.content() ) do
    -- A checkbox's `value` is its state, so only the lines that carry text are worth reading.
    if type( line.value ) == "string" then
      eq( string.find( line.value, "RollFor", 1, true ), nil )
    end
  end
end

function ExtensionPageSpec:should_reflect_a_disabled_extension()
  local db = {}
  Extensions.attach( db, EventBus.new() )
  Extensions.register( {
    name = "nether_vortex",
    title = "Nether Vortex",
    api_version = Extensions.API_VERSION,
    on_enable = function() end
  } )
  db.nether_vortex = false

  local options = new_extension_page( "nether_vortex" )
  options.show()

  options.should_display( page_of( { checkbox( "Enabled", false ) } ) )
end

function ExtensionPageSpec:should_toggle_the_extension_from_its_own_page()
  local db = {}
  Extensions.attach( db, EventBus.new() )
  Extensions.register( {
    name = "nether_vortex",
    title = "Nether Vortex",
    api_version = Extensions.API_VERSION,
    on_enable = function() end
  } )

  local options = new_extension_page( "nether_vortex" )
  options.show()

  options.toggle_setting( "Enabled" )

  eq( db.nether_vortex, false )
end

-- An extension that is the feature -- whose own settings already say whether it does anything --
-- declares hide_enabled_option, and core's fallback page has nothing left to draw. Rare on this
-- page, since such an extension almost certainly has settings of its own and therefore a page of
-- its own; core answers the same way regardless of which page is asking.
function ExtensionPageSpec:should_offer_no_switch_when_the_extension_hides_it()
  register_nether_vortex( { hide_enabled_option = true } )

  local options = new_extension_page( "nether_vortex" )
  options.show()

  options.should_display( page_of( {} ) )
end

-- An extension built for a newer RollFor cannot be switched on, so it gets the reason
-- instead of a checkbox that would refuse to do anything.
function ExtensionPageSpec:should_explain_itself_instead_of_offering_a_switch_when_incompatible()
  register_nether_vortex( { api_version = Extensions.API_VERSION + 1 } )

  local options = new_extension_page( "nether_vortex" )
  options.show()

  local content = options.content()
  eq( content[ #content ].type, "paragraph" )
  eq( string.find( content[ #content ].value, "cannot be enabled", 1, true ) ~= nil, true )
end

PrioritySpec = {}

-- Which automatic claimant outranks which, as a list the user arranges. It is the one thing
-- phases deliberately cannot decide: two policies competing for one slot are both in the Award
-- phase, and ranking them is a judgement about what the user wants rather than about when
-- anything runs. It used to be a line inside one extension saying it lost to another by name.
function PrioritySpec:should_list_the_registered_policies_in_the_order_they_run()
  local options = new_options( nil, nil, mock_award_policies( { "Auto-loot", "Round robin" } ) )
  options.show()

  local content = options.content()

  eq( content[ #content - 2 ], { type = "section_header", value = "Loot priority", padding = 13 } )
  eq( content[ #content - 1 ], priority_row( "Auto-loot", false, true, 3 ) )
  eq( content[ #content ], priority_row( "Round robin", true, false, 3 ) )
end

-- With one policy there is no question to answer, so there is nothing to draw.
function PrioritySpec:should_draw_nothing_with_only_one_policy()
  local options = new_options( nil, nil, mock_award_policies( { "Auto-loot" } ) )
  options.show()

  for _, line in ipairs( options.content() ) do
    eq( line.type ~= "priority_row", true, "A one-policy page should have no priority rows." )
  end
end

function PrioritySpec:should_draw_nothing_with_no_policies_at_all()
  local options = new_options()
  options.show()

  for _, line in ipairs( options.content() ) do
    eq( line.type ~= "priority_row", true, "A page with no policies should have no priority rows." )
  end
end

-- A row reports the position it is at and the direction, which is what the ordering itself
-- takes -- so the page never has to work out what the new order should be.
function PrioritySpec:should_report_a_move_as_a_position_and_a_direction()
  local policies = mock_award_policies( { "Auto-loot", "Round robin" } )
  local options = new_options( nil, nil, policies )
  options.show()

  options.move_priority( "Round robin", -1 )

  eq( policies.moves, { { position = 2, offset = -1 } } )
end

-- Applied immediately: no apply button, no reload. The page is redrawn from the new order, so
-- the arrows at the ends are right again rather than pointing off the list.
function PrioritySpec:should_redraw_the_list_from_the_new_order()
  local options = new_options( nil, nil, mock_award_policies( { "Auto-loot", "Round robin" } ) )
  options.show()

  options.move_priority( "Round robin", -1 )

  local content = options.content()

  eq( content[ #content - 1 ], priority_row( "Round robin", false, true, 3 ) )
  eq( content[ #content ], priority_row( "Auto-loot", true, false, 3 ) )
end

-- Deliberately no wrapping, so an arrow at the end of the list is drawn unavailable and a
-- refused move changes nothing on screen.
function PrioritySpec:should_leave_the_list_alone_when_a_move_is_refused()
  local options = new_options( nil, nil, mock_award_policies( { "Auto-loot", "Round robin" } ) )
  options.show()

  options.move_priority( "Auto-loot", -1 )

  local content = options.content()

  eq( content[ #content - 1 ], priority_row( "Auto-loot", false, true, 3 ) )
  eq( content[ #content ], priority_row( "Round robin", true, false, 3 ) )
end

os.exit( lu.LuaUnit.run() )
