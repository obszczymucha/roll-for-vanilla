package.path = "./?.lua;" .. package.path .. ";../?.lua;../../?.lua;../../RollFor/?.lua;../../RollFor/libs/?.lua"

require( "src/bcc/compat" )
local u = require( "test/utils" )
local lu, eq = u.luaunit( "assertEquals" )
u.multi_require_src( "DebugBuffer", "Module", "Types" )
require( "src/modules" )
local Db = require( "src/Db" )
local popup_builder = require( "mocks/PopupBuilder" )
local resistance_frame_mock = require( "mocks/ResistanceFrame" )
local ResistanceRegistry = require( "src/resistances/ResistanceRegistry" )
local transformer = require( "src/resistances/ResistanceFrameContentTransformer" )

u.mock_wow_api()

local Shadow = ResistanceRegistry.ResistanceType.Shadow
local Fire = ResistanceRegistry.ResistanceType.Fire

-- The client's own school colors, so the column reads the way the rest of the
-- UI does.
local shadow = RollFor.colorize( "8080ff", "Shadow" )
local fire = RollFor.colorize( "ff8000", "Fire" )

-- Fire's minimum is 295, Shadow's is 174. Each number is judged on its own.
local function below( value ) return RollFor.colors.red( value ) end
local function at_least( value ) return RollFor.colors.green( value ) end

local header = {
  type = "resistance_row",
  header = true,
  player = "Player",
  resistance = "Resistance",
  personal = "Personal",
  total = "Total",
  padding = 0
}

local dash = "-"
local dots = "..."
local red_dash = RollFor.colors.red( "-" )

---@param scan_disabled boolean?
local function button_lines( scan_disabled )
  local result = {}

  for _, button_type in ipairs( { "Check", "Clear", "Close" } ) do
    local definition = transformer.button_definitions[ button_type ]
    if not definition then error( string.format( "%s button definition was not found.", button_type ), 2 ) end

    table.insert( result, {
      type = definition.type,
      label = definition.label,
      width = definition.width,
      disabled = button_type == "Check" and scan_disabled and true or false
    } )
  end

  return result
end

local placeholders = { [ dash ] = true, [ red_dash ] = true, [ dots ] = true }

---@param name string
---@param class PlayerClass
local function line( name, class, resistance, personal, total )
  return {
    type = "resistance_row",
    player = RollFor.colorize_player_by_class( name, class ),
    resistance = resistance,
    personal = personal,
    total = total,
    -- Only a row holding real numbers has anything to clear, so only that row
    -- shows the button.
    clearable = not placeholders[ personal ]
  }
end

-- The whole popup in the order the transformer emits it: column titles, one
-- line per player, buttons. The first player line sits a little further from
-- the column titles than the rest do.
---@param rows table[]
---@param scan_disabled boolean?
---@return table ...
local function popup( rows, scan_disabled )
  local content = { header }

  for i, row in ipairs( rows ) do
    row.padding = i == 1 and 4 or 2
    table.insert( content, row )
  end

  for _, button in ipairs( button_lines( scan_disabled ) ) do
    table.insert( content, button )
  end

  return unpack( content )
end

---@param name string
---@param class PlayerClass
local function unscanned( name, class )
  return { player_name = name, class = class, scanning = false, failed = false }
end

---@param name string
---@param class PlayerClass
local function scanning( name, class )
  return { player_name = name, class = class, scanning = true, failed = false }
end

---@param name string
---@param class PlayerClass
local function failed( name, class )
  return { player_name = name, class = class, scanning = false, failed = true }
end

---@param name string
---@param class PlayerClass
---@param food number? -- how much of personal came from a Well Fed buff
---@param missing_neck boolean? -- true when the required resistance neck isn't worn
local function scanned( name, class, resistance_type, personal, total, food, missing_neck )
  return {
    player_name = name,
    class = class,
    resistance_type = resistance_type,
    personal = personal,
    total = total,
    food = food,
    missing_neck = missing_neck,
    scanning = false,
    failed = false
  }
end

---@param rows ResistanceRow[]?
local function mock_resistance_check( rows )
  local m_rows = rows or {}
  local m_scanning = false
  local listeners = {}

  local check = {
    scans = 0,
    clear_alls = 0,
    cleared = {}
  }

  check.get_rows = function() return m_rows end
  check.scan = function() check.scans = check.scans + 1 end
  check.is_scanning = function() return m_scanning end
  check.clear = function( player_name ) table.insert( check.cleared, player_name ) end
  check.clear_all = function() check.clear_alls = check.clear_alls + 1 end
  check.subscribe = function( listener ) table.insert( listeners, listener ) end

  check.set_rows = function( rows_ ) m_rows = rows_ end
  check.set_scanning = function( value ) m_scanning = value end
  check.notify = function()
    for _, listener in ipairs( listeners ) do listener() end
  end

  return check
end

---@param resistance_check table
local function new_frame( resistance_check )
  local db = Db.new( {} )
  return resistance_frame_mock.new( popup_builder.new(), resistance_check, db( "resistance_frame" ) )
end

ResistanceFrameSpec = {}

function ResistanceFrameSpec:should_be_hidden_by_default()
  -- Given
  local frame = new_frame( mock_resistance_check() )

  -- Then
  frame.should_be_hidden()
end

function ResistanceFrameSpec:should_toggle_visibility()
  -- Given
  local frame = new_frame( mock_resistance_check() )

  -- When
  frame.toggle()

  -- Then
  frame.should_be_visible()

  -- When
  frame.toggle()

  -- Then
  frame.should_be_hidden()
end

function ResistanceFrameSpec:should_display_the_whole_group_with_dashes_before_any_scan()
  -- Given
  local frame = new_frame( mock_resistance_check( {
    unscanned( "Psikutas", "Warrior" ),
    unscanned( "Obszczymucha", "Mage" )
  } ) )

  -- When
  frame.show()

  -- Then
  frame.should_display( popup( {
    line( "Psikutas", "Warrior", dash, dash, dash ),
    line( "Obszczymucha", "Mage", dash, dash, dash )
  } ) )
end

function ResistanceFrameSpec:should_display_the_school_and_both_values_of_a_scanned_player()
  -- Given
  local frame = new_frame( mock_resistance_check( {
    scanned( "Psikutas", "Warrior", Shadow, 60, 130 ),
    scanned( "Obszczymucha", "Mage", Fire, 302, 327 )
  } ) )

  -- When
  frame.show()

  -- Then
  frame.should_display( popup( {
    line( "Psikutas", "Warrior", shadow, below( "60" ), below( "130" ) ),
    line( "Obszczymucha", "Mage", fire, at_least( "302" ), at_least( "327" ) )
  } ) )
end

function ResistanceFrameSpec:should_display_dots_for_a_player_being_scanned()
  -- Given
  local frame = new_frame( mock_resistance_check( { scanning( "Psikutas", "Warrior" ) } ) )

  -- When
  frame.show()

  -- Then
  frame.should_display( popup( { line( "Psikutas", "Warrior", dots, dots, dots ) } ) )
end

function ResistanceFrameSpec:should_display_a_red_dash_for_a_player_the_inspect_couldnt_reach()
  -- A plain dash means "not scanned yet". Out of range is a different thing and
  -- shouldn't look the same.
  -- Given
  local frame = new_frame( mock_resistance_check( {
    failed( "Psikutas", "Warrior" ),
    unscanned( "Obszczymucha", "Mage" )
  } ) )

  -- When
  frame.show()

  -- Then
  frame.should_display( popup( {
    line( "Psikutas", "Warrior", red_dash, red_dash, red_dash ),
    line( "Obszczymucha", "Mage", dash, dash, dash )
  } ) )
end

function ResistanceFrameSpec:should_scan_when_check_is_clicked()
  -- Given
  local resistance_check = mock_resistance_check( { unscanned( "Psikutas", "Warrior" ) } )
  local frame = new_frame( resistance_check )
  frame.show()

  -- When
  frame.click( "Check" )

  -- Then
  eq( resistance_check.scans, 1 )
end

function ResistanceFrameSpec:should_disable_the_check_button_while_a_scan_is_in_flight()
  -- Given
  local resistance_check = mock_resistance_check( { scanning( "Psikutas", "Warrior" ) } )
  resistance_check.set_scanning( true )
  local frame = new_frame( resistance_check )

  -- When
  frame.show()

  -- Then
  frame.should_display( popup( { line( "Psikutas", "Warrior", dots, dots, dots ) }, true ) )
end

function ResistanceFrameSpec:should_clear_everything_when_clear_is_clicked()
  -- Given
  local resistance_check = mock_resistance_check( { scanned( "Psikutas", "Warrior", Shadow, 60, 130 ) } )
  local frame = new_frame( resistance_check )
  frame.show()

  -- When
  frame.click( "Clear" )

  -- Then
  eq( resistance_check.clear_alls, 1 )
  eq( resistance_check.scans, 0 )
end

function ResistanceFrameSpec:should_clear_only_that_player_when_their_own_button_is_clicked()
  -- Given
  local resistance_check = mock_resistance_check( {
    scanned( "Psikutas", "Warrior", Shadow, 60, 130 ),
    scanned( "Obszczymucha", "Mage", Fire, 302, 327 )
  } )
  local frame = new_frame( resistance_check )
  frame.show()

  -- When
  frame.clear_row( "Obszczymucha" )

  -- Then
  eq( resistance_check.cleared, { "Obszczymucha" } )
  eq( resistance_check.clear_alls, 0 )
  eq( resistance_check.scans, 0 )
end

function ResistanceFrameSpec:should_hide_when_close_is_clicked()
  -- Given
  local frame = new_frame( mock_resistance_check( { unscanned( "Psikutas", "Warrior" ) } ) )
  frame.show()

  -- When
  frame.click( "Close" )

  -- Then
  frame.should_be_hidden()
end

function ResistanceFrameSpec:should_redraw_when_a_scan_result_arrives()
  -- Given
  local resistance_check = mock_resistance_check( { scanning( "Psikutas", "Warrior" ) } )
  local frame = new_frame( resistance_check )
  frame.show()

  -- When
  resistance_check.set_rows( { scanned( "Psikutas", "Warrior", Shadow, 60, 130 ) } )
  resistance_check.notify()

  -- Then
  frame.should_display( popup( { line( "Psikutas", "Warrior", shadow, below( "60" ), below( "130" ) ) } ) )
end

function ResistanceFrameSpec:should_not_redraw_while_hidden()
  -- Scanning keeps running after Close, and there's nothing to draw it on.
  -- Given
  local resistance_check = mock_resistance_check( { scanning( "Psikutas", "Warrior" ) } )
  local frame = new_frame( resistance_check )
  frame.show()
  frame.hide()
  local renders = frame.render_count()

  -- When
  resistance_check.notify()

  -- Then
  eq( frame.render_count(), renders )
end

function ResistanceFrameSpec:should_colour_a_value_green_the_moment_it_reaches_the_minimum()
  -- Shadow's minimum is 174, so 173 falls short and 174 doesn't.
  -- Given
  local frame = new_frame( mock_resistance_check( {
    scanned( "Psikutas", "Warrior", Shadow, 174, 174 ),
    scanned( "Obszczymucha", "Mage", Shadow, 173, 173 )
  } ) )

  -- When
  frame.show()

  -- Then
  frame.should_display( popup( {
    line( "Psikutas", "Warrior", shadow, at_least( "174" ), at_least( "174" ) ),
    line( "Obszczymucha", "Mage", shadow, below( "173" ), below( "173" ) )
  } ) )
end

function ResistanceFrameSpec:should_judge_each_school_against_its_own_minimum()
  -- 295 clears fire's minimum; the same number would clear shadow's too, but
  -- 200 clears neither.
  -- Given
  local frame = new_frame( mock_resistance_check( {
    scanned( "Psikutas", "Warrior", Fire, 295, 295 ),
    scanned( "Obszczymucha", "Mage", Fire, 200, 200 )
  } ) )

  -- When
  frame.show()

  -- Then
  frame.should_display( popup( {
    line( "Psikutas", "Warrior", fire, at_least( "295" ), at_least( "295" ) ),
    line( "Obszczymucha", "Mage", fire, below( "200" ), below( "200" ) )
  } ) )
end

function ResistanceFrameSpec:should_colour_gear_and_total_independently()
  -- Gear alone falls short of shadow's 174; the raid buff carries it over.
  -- Given
  local frame = new_frame( mock_resistance_check( { scanned( "Psikutas", "Warrior", Shadow, 130, 200 ) } ) )

  -- When
  frame.show()

  -- Then
  frame.should_display( popup( { line( "Psikutas", "Warrior", shadow, below( "130" ), at_least( "200" ) ) } ) )
end

function ResistanceFrameSpec:should_list_a_player_who_joined_the_group()
  -- Given
  local resistance_check = mock_resistance_check( { unscanned( "Psikutas", "Warrior" ) } )
  local frame = new_frame( resistance_check )
  frame.show()

  -- When
  resistance_check.set_rows( { unscanned( "Psikutas", "Warrior" ), unscanned( "Obszczymucha", "Mage" ) } )
  frame.on_group_changed()

  -- Then
  frame.should_display( popup( {
    line( "Psikutas", "Warrior", dash, dash, dash ),
    line( "Obszczymucha", "Mage", dash, dash, dash )
  } ) )
end

function ResistanceFrameSpec:should_drop_a_player_who_left_the_group()
  -- Given
  local resistance_check = mock_resistance_check( {
    scanned( "Psikutas", "Warrior", Shadow, 60, 130 ),
    scanned( "Obszczymucha", "Mage", Fire, 302, 327 )
  } )
  local frame = new_frame( resistance_check )
  frame.show()

  -- When
  resistance_check.set_rows( { scanned( "Psikutas", "Warrior", Shadow, 60, 130 ) } )
  frame.on_group_changed()

  -- Then
  frame.should_display( popup( { line( "Psikutas", "Warrior", shadow, below( "60" ), below( "130" ) ) } ) )
end

function ResistanceFrameSpec:should_not_redraw_on_a_group_change_while_hidden()
  -- Given
  local resistance_check = mock_resistance_check( { unscanned( "Psikutas", "Warrior" ) } )
  local frame = new_frame( resistance_check )
  frame.show()
  frame.hide()
  local renders = frame.render_count()

  -- When
  frame.on_group_changed()

  -- Then
  eq( frame.render_count(), renders )
end

function ResistanceFrameSpec:should_star_the_gear_of_a_player_carrying_food()
  -- Personal already includes the food; the star only says part of it isn't
  -- gear. 130 is still short of shadow's 174, so it stays red.
  -- Given
  local frame = new_frame( mock_resistance_check( { scanned( "Psikutas", "Warrior", Shadow, 130, 200, 8 ) } ) )

  -- When
  frame.show()

  -- Then
  frame.should_display( popup( { line( "Psikutas", "Warrior", shadow, below( "130*" ), at_least( "200" ) ) } ) )
end

function ResistanceFrameSpec:should_star_the_gear_without_disturbing_its_colour()
  -- Given
  local frame = new_frame( mock_resistance_check( { scanned( "Obszczymucha", "Mage", Fire, 302, 327, 8 ) } ) )

  -- When
  frame.show()

  -- Then
  frame.should_display( popup( { line( "Obszczymucha", "Mage", fire, at_least( "302*" ), at_least( "327" ) ) } ) )
end

function ResistanceFrameSpec:should_dash_the_gear_of_a_player_without_the_resistance_neck()
  -- The dash is about the neck, not the number: 302 clears fire's 295 and still
  -- gets marked.
  -- Given
  local frame = new_frame( mock_resistance_check( { scanned( "Obszczymucha", "Mage", Fire, 302, 327, nil, true ) } ) )

  -- When
  frame.show()

  -- Then
  frame.should_display( popup( { line( "Obszczymucha", "Mage", fire, at_least( "302-" ), at_least( "327" ) ) } ) )
end

function ResistanceFrameSpec:should_mark_food_and_a_missing_neck_together()
  -- Given
  local frame = new_frame( mock_resistance_check( { scanned( "Psikutas", "Warrior", Shadow, 130, 200, 8, true ) } ) )

  -- When
  frame.show()

  -- Then
  frame.should_display( popup( { line( "Psikutas", "Warrior", shadow, below( "130*-" ), at_least( "200" ) ) } ) )
end

function ResistanceFrameSpec:should_leave_the_total_unmarked()
  -- Both markers are about what the player brought themselves, so neither
  -- follows the buffed total.
  -- Given
  local frame = new_frame( mock_resistance_check( { scanned( "Psikutas", "Warrior", Shadow, 180, 240, 8, true ) } ) )

  -- When
  frame.show()

  -- Then
  frame.should_display( popup( { line( "Psikutas", "Warrior", shadow, at_least( "180*-" ), at_least( "240" ) ) } ) )
end

os.exit( lu.LuaUnit.run() )
