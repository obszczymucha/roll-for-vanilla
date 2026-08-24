package.path = "./?.lua;" .. package.path .. ";../?.lua;../../?.lua;../../RollFor/?.lua;../../RollFor/libs/?.lua"

require( "src/bcc/compat" )
local u = require( "test/utils" )
local lu, eq = u.luaunit( "assertEquals" )
u.multi_require_src( "DebugBuffer", "Module", "Types" )
require( "src/modules" )
local Db = require( "src/Db" )
local popup_builder = require( "mocks/PopupBuilder" )
local frame_mock = require( "mocks/ResistanceBonusRollEligibilityFrame" )
local ResistanceRegistry = require( "src/resistances/ResistanceRegistry" )
local ResistanceBonusRollEligibility = require( "src/resistances/ResistanceBonusRollEligibility" )
local transformer = require( "src/resistances/ResistanceBonusRollEligibilityFrameContentTransformer" )

u.mock_wow_api()

local Shadow = ResistanceRegistry.ResistanceType.Shadow
local Fire = ResistanceRegistry.ResistanceType.Fire

-- The reason is colored by what it means: green when a scan found the gear, red
-- when a scan found it wanting, grey for the two reasons that aren't a
-- measurement.
local function passed( value ) return RollFor.colors.green( value ) end
local function short( value ) return RollFor.colors.red( value ) end
local function plain( value ) return RollFor.colors.grey( value ) end

local title = { type = "text", value = "Resistance Bonus Roll Eligibility", padding = 6 }

local header = {
  type = "eligibility_row",
  header = true,
  player = "Player",
  reason = "Reason",
  padding = 0
}

---@param infer_disabled boolean?
local function button_lines( infer_disabled )
  local result = {}

  for _, button_type in ipairs( { "Infer", "Reset", "Close" } ) do
    local definition = transformer.button_definitions[ button_type ]
    if not definition then error( string.format( "%s button definition was not found.", button_type ), 2 ) end

    table.insert( result, {
      type = definition.type,
      label = definition.label,
      width = definition.width,
      disabled = button_type == "Infer" and infer_disabled and true or false
    } )
  end

  return result
end

---@param name string
---@param class PlayerClass
---@param checked boolean
---@param reason string -- already colored
local function line( name, class, checked, reason )
  return {
    type = "eligibility_row",
    player = RollFor.colorize_player_by_class( name, class ),
    reason = reason,
    checked = checked
  }
end

-- The whole popup in the order the transformer emits it: title, column titles,
-- one line per player, buttons. The first player line sits a little further from
-- the column titles than the rest do.
---@param rows table[]
---@param infer_disabled boolean?
---@return table ...
local function popup( rows, infer_disabled )
  local content = { title, header }

  for i, row in ipairs( rows ) do
    row.padding = i == 1 and 4 or 2
    table.insert( content, row )
  end

  for _, button in ipairs( button_lines( infer_disabled ) ) do
    table.insert( content, button )
  end

  return unpack( content )
end

---@param name string
---@param class PlayerClass
local function player( name, class )
  return { name = name, class = class, unit = "raid1" }
end

local function mock_roster( players )
  local m_players = players or { player( "Psikutas", "Warrior" ) }

  return {
    get_group_players = function() return m_players end,
    set_players = function( new_players ) m_players = new_players end
  }
end

-- A scanned resistance row. personal is the reported school's number and
-- personal_by_type carries both, which is what the eligibility rule reads.
---@param name string
---@param fire number
---@param shadow number
local function scanned( name, fire, shadow )
  local resistance_type = fire > 150 and Fire or Shadow

  return {
    player_name = name,
    class = "Warrior",
    resistance_type = resistance_type,
    personal = resistance_type == Fire and fire or shadow,
    personal_by_type = { [ Fire ] = fire, [ Shadow ] = shadow },
    scanning = false,
    failed = false
  }
end

-- Only get_rows, is_scanning and subscribe are ever called on it, so that's all
-- it answers.
---@param rows ResistanceRow[]?
local function mock_resistance_check( rows )
  local m_rows = rows or {}
  local m_scanning = false
  local listeners = {}

  local check = {}

  check.get_rows = function() return m_rows end
  check.is_scanning = function() return m_scanning end
  check.subscribe = function( listener ) table.insert( listeners, listener ) end

  check.set_rows = function( new_rows ) m_rows = new_rows end
  check.set_scanning = function( value ) m_scanning = value end
  check.notify = function()
    for _, listener in ipairs( listeners ) do listener() end
  end

  return check
end

-- The real eligibility module, not a mock: half of what this frame does is show
-- what a click did to it, and a mock would only ever show what the test told it
-- to.
---@param options table?
local function new_frame( options )
  options = options or {}
  local db = Db.new( {} )
  local roster = mock_roster( options.players )
  local resistance_check = options.resistance_check or mock_resistance_check( options.rows )

  local eligibility = ResistanceBonusRollEligibility.new(
    db( "eligibility" ), roster, resistance_check, ResistanceRegistry.new() )

  local frame = frame_mock.new( popup_builder.new(), eligibility, resistance_check, db( "eligibility_frame" ) )

  frame.eligibility = eligibility
  frame.roster = roster
  frame.resistance_check = resistance_check

  return frame
end

BonusRollEligibilityFrameSpec = {}

function BonusRollEligibilityFrameSpec:should_be_hidden_by_default()
  -- Given
  local frame = new_frame()

  -- Then
  frame.should_be_hidden()
end

function BonusRollEligibilityFrameSpec:should_toggle_visibility()
  -- Given
  local frame = new_frame()

  -- When
  frame.toggle()

  -- Then
  frame.should_be_visible()

  -- When
  frame.toggle()

  -- Then
  frame.should_be_hidden()
end

function BonusRollEligibilityFrameSpec:should_display_the_whole_group_unchecked_before_any_infer()
  -- Given
  local frame = new_frame( { players = { player( "Psikutas", "Warrior" ), player( "Obszczymucha", "Mage" ) } } )

  -- When
  frame.show()

  -- Then
  frame.should_display( popup( {
    line( "Obszczymucha", "Mage", false, plain( "Not scanned" ) ),
    line( "Psikutas", "Warrior", false, plain( "Not scanned" ) )
  } ) )
end

function BonusRollEligibilityFrameSpec:should_check_the_rows_infer_found_eligible()
  -- Eligible rows sort to the top, since the list is read to answer who gets
  -- one.
  -- Given
  local frame = new_frame( {
    players = { player( "Psikutas", "Warrior" ), player( "Obszczymucha", "Mage" ) },
    rows = { scanned( "Psikutas", 0, 100 ), scanned( "Obszczymucha", 302, 0 ) }
  } )
  frame.show()

  -- When
  frame.click( "Infer" )

  -- Then
  frame.should_display( popup( {
    line( "Obszczymucha", "Mage", true, passed( "Fire 302" ) ),
    line( "Psikutas", "Warrior", false, short( "Shadow 100" ) )
  } ) )
end

function BonusRollEligibilityFrameSpec:should_check_a_player_who_qualifies_on_the_school_the_list_doesnt_report()
  -- 160 fire is over the resistance list's 150, so it reports this player as
  -- Fire -- and they're well short of fire's 295. Their shadow gear clears
  -- shadow's 174 all the same.
  -- Given
  local frame = new_frame( { rows = { scanned( "Psikutas", 160, 180 ) } } )
  frame.show()

  -- When
  frame.click( "Infer" )

  -- Then
  frame.should_display( popup( { line( "Psikutas", "Warrior", true, passed( "Shadow 180" ) ) } ) )
end

function BonusRollEligibilityFrameSpec:should_clear_the_checkboxes_when_reset_is_clicked()
  -- Given
  local frame = new_frame( { rows = { scanned( "Psikutas", 302, 0 ) } } )
  frame.show()
  frame.click( "Infer" )

  -- When
  frame.click( "Reset" )

  -- Then
  eq( frame.eligibility.is_eligible( "Psikutas" ), false )
  frame.should_display( popup( { line( "Psikutas", "Warrior", false, plain( "Not scanned" ) ) } ) )
end

function BonusRollEligibilityFrameSpec:should_flip_a_player_when_their_own_checkbox_is_ticked()
  -- The GUI passes no reason, so the module stamps the row as hand-set.
  -- Given
  local frame = new_frame( { players = { player( "Psikutas", "Warrior" ), player( "Obszczymucha", "Mage" ) } } )
  frame.show()

  -- When
  frame.check_row( "Obszczymucha", true )

  -- Then
  eq( frame.eligibility.is_eligible( "Obszczymucha" ), true )
  eq( frame.eligibility.is_eligible( "Psikutas" ), false )
  frame.should_display( popup( {
    line( "Obszczymucha", "Mage", true, plain( "Manual" ) ),
    line( "Psikutas", "Warrior", false, plain( "Not scanned" ) )
  } ) )
end

function BonusRollEligibilityFrameSpec:should_flip_a_player_back_when_their_checkbox_is_unticked()
  -- Given
  local frame = new_frame( { rows = { scanned( "Psikutas", 302, 0 ) } } )
  frame.show()
  frame.click( "Infer" )

  -- When
  frame.check_row( "Psikutas", false )

  -- Then
  eq( frame.eligibility.is_eligible( "Psikutas" ), false )
  frame.should_display( popup( { line( "Psikutas", "Warrior", false, plain( "Manual" ) ) } ) )
end

function BonusRollEligibilityFrameSpec:should_disable_infer_while_a_scan_is_in_flight()
  -- Inferring off a half-filled cache would write "Not scanned" rows that a
  -- second click would immediately correct.
  -- Given
  local resistance_check = mock_resistance_check()
  resistance_check.set_scanning( true )
  local frame = new_frame( { resistance_check = resistance_check } )

  -- When
  frame.show()

  -- Then
  frame.should_display( popup( { line( "Psikutas", "Warrior", false, plain( "Not scanned" ) ) }, true ) )
end

function BonusRollEligibilityFrameSpec:should_hide_when_close_is_clicked()
  -- Given
  local frame = new_frame()
  frame.show()

  -- When
  frame.click( "Close" )

  -- Then
  frame.should_be_hidden()
end

function BonusRollEligibilityFrameSpec:should_redraw_when_the_eligibility_database_changes_underneath_it()
  -- Given
  local frame = new_frame()
  frame.show()

  -- When
  frame.eligibility.set( "Psikutas", true )

  -- Then
  frame.should_display( popup( { line( "Psikutas", "Warrior", true, plain( "Manual" ) ) } ) )
end

function BonusRollEligibilityFrameSpec:should_redraw_when_a_scan_result_arrives()
  -- A scan landing changes what Infer would produce, so the button's state has
  -- to be redrawn even though no row changed.
  -- Given
  local resistance_check = mock_resistance_check()
  resistance_check.set_scanning( true )
  local frame = new_frame( { resistance_check = resistance_check } )
  frame.show()
  frame.should_display( popup( { line( "Psikutas", "Warrior", false, plain( "Not scanned" ) ) }, true ) )

  -- When
  resistance_check.set_scanning( false )
  resistance_check.notify()

  -- Then
  frame.should_display( popup( { line( "Psikutas", "Warrior", false, plain( "Not scanned" ) ) } ) )
end

function BonusRollEligibilityFrameSpec:should_not_redraw_while_hidden()
  -- Scanning keeps running after Close, and there's nothing to draw it on.
  -- Given
  local resistance_check = mock_resistance_check()
  local frame = new_frame( { resistance_check = resistance_check } )
  frame.show()
  frame.hide()
  local renders = frame.render_count()

  -- When
  resistance_check.notify()
  frame.eligibility.set( "Psikutas", true )

  -- Then
  eq( frame.render_count(), renders )
end

function BonusRollEligibilityFrameSpec:should_list_a_player_who_joined_the_group()
  -- Given
  local frame = new_frame()
  frame.show()

  -- When
  frame.roster.set_players( { player( "Psikutas", "Warrior" ), player( "Obszczymucha", "Mage" ) } )
  frame.on_group_changed()

  -- Then
  frame.should_display( popup( {
    line( "Obszczymucha", "Mage", false, plain( "Not scanned" ) ),
    line( "Psikutas", "Warrior", false, plain( "Not scanned" ) )
  } ) )
end

function BonusRollEligibilityFrameSpec:should_drop_a_player_who_left_the_group()
  -- Given
  local frame = new_frame( { players = { player( "Psikutas", "Warrior" ), player( "Obszczymucha", "Mage" ) } } )
  frame.show()

  -- When
  frame.roster.set_players( { player( "Psikutas", "Warrior" ) } )
  frame.on_group_changed()

  -- Then
  frame.should_display( popup( { line( "Psikutas", "Warrior", false, plain( "Not scanned" ) ) } ) )
end

function BonusRollEligibilityFrameSpec:should_not_redraw_on_a_group_change_while_hidden()
  -- Given
  local frame = new_frame()
  frame.show()
  frame.hide()
  local renders = frame.render_count()

  -- When
  frame.on_group_changed()

  -- Then
  eq( frame.render_count(), renders )
end

os.exit( lu.LuaUnit.run() )
