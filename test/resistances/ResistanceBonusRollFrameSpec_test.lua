package.path = "./?.lua;" .. package.path .. ";../?.lua;../../?.lua;../../RollFor/?.lua;../../RollFor/libs/?.lua"

require( "src/bcc/compat" )
local u = require( "test/utils" )
local lu, eq = u.luaunit( "assertEquals" )
u.multi_require_src( "DebugBuffer", "Module", "Types" )
require( "src/modules" )
local Db = require( "src/Db" )
require( "src/AutoLootDb" ) -- use() resolves the item's boss through the catalogue
local popup_builder = require( "mocks/PopupBuilder" )
local frame_mock = require( "mocks/ResistanceBonusRollFrame" )
local ResistanceBonusRollRegistry = require( "src/resistances/ResistanceBonusRollRegistry" )

u.mock_wow_api()

local SHAHRAZ = "Mother Shahraz"
local COUNCIL = "The Illidari Council"
local ILLIDAN = "Illidan Stormrage"

local title = { type = "text", value = "Resistance Bonus Rolls", padding = 6 }
local empty_notice = { type = "text", value = "No bonus rolls granted yet.", padding = 10 }

local header = {
  type = "bonus_roll_row",
  header = true,
  player = "Player",
  rolls = "Rolls",
  padding = 0
}

local close_button = { type = "button", label = "Close", width = 70 }

---@param name string
---@param count number
---@param bosses string[] -- the tooltip's boss names, in kill order
local function line( name, count, bosses )
  return {
    type = "bonus_roll_row",
    player = RollFor.colorize_player_by_class( name, "Warrior" ),
    rolls = tostring( count ),
    tooltip_lines = bosses
  }
end

-- The whole popup in the order the transformer emits it: title, then either the empty
-- notice or the column titles and one line per player, then the buttons. The first
-- player line sits a little further from the column titles than the rest do.
---@param rows table[]?
---@return table ...
local function popup( rows )
  local content = { title }

  if not rows or #rows == 0 then
    table.insert( content, empty_notice )
  else
    table.insert( content, header )

    for i, row in ipairs( rows ) do
      row.padding = i == 1 and 4 or 2
      table.insert( content, row )
    end
  end

  table.insert( content, close_button )

  return unpack( content )
end

-- Stands in for BossKilled: the registry only ever subscribes to it.
local function mock_boss_killed()
  local listeners = {}

  return {
    subscribe = function( listener ) table.insert( listeners, listener ) end,
    kill = function( boss_name )
      for _, listener in ipairs( listeners ) do listener( boss_name ) end
    end
  }
end

---@param rows table[]?
local function mock_eligibility( rows )
  local m_rows = rows or {}

  return {
    get_rows = function() return m_rows end,
    set_rows = function( new_rows ) m_rows = new_rows end
  }
end

---@param name string
---@param eligible boolean
local function player( name, eligible )
  return { player_name = name, class = "Warrior", eligible = eligible, reason = "Manual" }
end

---@param names string[]
local function mock_roster( names )
  local m_players = {}

  for _, name in ipairs( names ) do
    table.insert( m_players, { name = name, class = "Warrior", unit = "raid1" } )
  end

  local roster = {}
  roster.get_group_players = function() return m_players end

  roster.set_players = function( new_names )
    m_players = {}

    for _, name in ipairs( new_names ) do
      table.insert( m_players, { name = name, class = "Warrior", unit = "raid1" } )
    end
  end

  return roster
end

-- The real registry, not a mock: half of what this frame does is show what a kill did
-- to it, and a mock would only ever show what the test told it to.
--
-- The roster defaults to the same names as the eligible players -- in the real game
-- eligibility.get_rows() is itself roster-scoped, so most tests don't need to name the
-- group twice. Tests about someone joining or leaving pass their own roster and move it
-- independently of eligibility.
---@param eligible_players table[]?
---@param roster_names string[]?
local function new_frame( eligible_players, roster_names )
  local db = Db.new( {} )
  local boss_killed = mock_boss_killed()
  local eligibility = mock_eligibility( eligible_players )

  local names = roster_names
  if not names then
    names = {}
    for _, p in ipairs( eligible_players or {} ) do table.insert( names, p.player_name ) end
  end

  local roster = mock_roster( names )
  local registry = ResistanceBonusRollRegistry.new( db( "registry" ), boss_killed, eligibility )

  local frame = frame_mock.new( popup_builder.new(), registry, roster, db( "bonus_roll_frame" ) )

  frame.registry = registry
  frame.boss_killed = boss_killed
  frame.eligibility = eligibility
  frame.roster = roster

  return frame
end

BonusRollFrameSpec = {}

function BonusRollFrameSpec:should_be_hidden_by_default()
  -- Given
  local frame = new_frame()

  -- Then
  frame.should_be_hidden()
end

function BonusRollFrameSpec:should_toggle_visibility()
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

function BonusRollFrameSpec:should_show_the_empty_notice_before_anything_is_granted()
  -- Given
  local frame = new_frame()

  -- When
  frame.show()

  -- Then
  frame.should_display( popup() )
end

function BonusRollFrameSpec:should_list_a_player_after_a_grant()
  -- Given
  local frame = new_frame( { player( "Psikutas", true ) } )
  frame.show()

  -- When
  frame.boss_killed.kill( ILLIDAN )

  -- Then
  frame.should_display( popup( { line( "Psikutas", 1, { ILLIDAN } ) } ) )
end

function BonusRollFrameSpec:should_count_more_than_one_roll()
  -- Given
  local frame = new_frame( { player( "Psikutas", true ) } )
  frame.show()

  -- When
  frame.boss_killed.kill( SHAHRAZ )
  frame.boss_killed.kill( ILLIDAN )

  -- Then
  frame.should_display( popup( { line( "Psikutas", 2, { SHAHRAZ, ILLIDAN } ) } ) )
end

function BonusRollFrameSpec:should_name_every_boss_that_paid_for_the_rolls_in_the_tooltip()
  -- Given
  local frame = new_frame( { player( "Psikutas", true ) } )
  frame.show()

  -- When
  frame.boss_killed.kill( SHAHRAZ )
  frame.boss_killed.kill( COUNCIL )
  frame.boss_killed.kill( ILLIDAN )

  -- Then
  frame.should_display( popup( { line( "Psikutas", 3, { SHAHRAZ, COUNCIL, ILLIDAN } ) } ) )
end

-- Marking a spent roll rather than deleting it is what makes this line possible, and this
-- line is the reason it's worth doing: it's what settles an argument about a roll after
-- the item has been handed out.
function BonusRollFrameSpec:should_say_what_a_spent_roll_went_on_in_the_tooltip()
  -- Given
  local frame = new_frame( { player( "Psikutas", true ) } )
  frame.show()
  frame.boss_killed.kill( SHAHRAZ )
  frame.boss_killed.kill( COUNCIL )

  -- When (spent on a Council item, which takes the earlier Mother roll)
  frame.registry.use( "Psikutas", 32331, "[Cloak of the Illidari Council]", 87 )

  -- Then (the count is the *unused* rolls; the spent one is greyed and says where it went)
  frame.should_display( popup( { line( "Psikutas", 1, {
    RollFor.colors.grey( "Mother Shahraz - spent on [Cloak of the Illidari Council] (87)" ),
    COUNCIL
  } ) } ) )
end

function BonusRollFrameSpec:should_sort_most_rolls_first_then_by_name()
  -- Alphabetically these are Bomanz, Obszczymucha, Psikutas -- a different name at
  -- every position below, so nothing here can pass on a name sort alone.
  -- Given
  local frame = new_frame(
    { player( "Psikutas", true ), player( "Obszczymucha", true ), player( "Bomanz", true ) },
    { "Psikutas", "Obszczymucha", "Bomanz" }
  )
  frame.show()
  frame.boss_killed.kill( SHAHRAZ )

  frame.eligibility.set_rows( { player( "Psikutas", true ), player( "Obszczymucha", true ) } )
  frame.boss_killed.kill( COUNCIL )

  frame.eligibility.set_rows( { player( "Psikutas", true ) } )
  frame.boss_killed.kill( ILLIDAN )

  -- Then
  frame.should_display( popup( {
    line( "Psikutas", 3, { SHAHRAZ, COUNCIL, ILLIDAN } ),
    line( "Obszczymucha", 2, { SHAHRAZ, COUNCIL } ),
    line( "Bomanz", 1, { SHAHRAZ } )
  } ) )
end

function BonusRollFrameSpec:should_drop_a_player_who_left_the_group()
  -- The registry keeps the record regardless of who's still grouped -- that's what
  -- lets a lockout-wipe summary count a roll earned by someone who has since stepped
  -- out. This window only shows who's actually here to see it.
  -- Given
  local frame = new_frame( { player( "Psikutas", true ), player( "Obszczymucha", true ) } )
  frame.show()
  frame.boss_killed.kill( ILLIDAN )

  -- When
  frame.roster.set_players( { "Psikutas" } )
  frame.on_group_changed()

  -- Then
  frame.should_display( popup( { line( "Psikutas", 1, { ILLIDAN } ) } ) )
  -- The record itself is untouched.
  eq( frame.registry.count( "Obszczymucha" ), 1 )
end

function BonusRollFrameSpec:should_list_a_player_who_joined_the_group()
  -- Given
  local frame = new_frame( { player( "Psikutas", true ) }, { "Psikutas" } )
  frame.show()
  frame.boss_killed.kill( ILLIDAN )
  frame.eligibility.set_rows( { player( "Psikutas", true ), player( "Obszczymucha", true ) } )
  frame.roster.set_players( { "Psikutas", "Obszczymucha" } )
  frame.boss_killed.kill( SHAHRAZ )

  -- When
  frame.on_group_changed()

  -- Then
  frame.should_display( popup( {
    line( "Psikutas", 2, { ILLIDAN, SHAHRAZ } ),
    line( "Obszczymucha", 1, { SHAHRAZ } )
  } ) )
end

function BonusRollFrameSpec:should_not_redraw_on_a_group_change_while_hidden()
  -- Given
  local frame = new_frame( { player( "Psikutas", true ) } )
  frame.show()
  frame.hide()
  local renders = frame.render_count()

  -- When
  frame.roster.set_players( {} )
  frame.on_group_changed()

  -- Then
  eq( frame.render_count(), renders )
end

function BonusRollFrameSpec:should_hide_when_close_is_clicked()
  -- Given
  local frame = new_frame()
  frame.show()

  -- When
  frame.click( "Close" )

  -- Then
  frame.should_be_hidden()
end

function BonusRollFrameSpec:should_redraw_once_for_a_kill_that_pays_out_to_several_players()
  -- Given
  local frame = new_frame( { player( "Psikutas", true ), player( "Obszczymucha", true ) } )
  frame.show()
  local renders = frame.render_count()

  -- When
  frame.boss_killed.kill( ILLIDAN )

  -- Then
  eq( frame.render_count(), renders + 1 )
end

function BonusRollFrameSpec:should_redraw_on_reset()
  -- Given
  local frame = new_frame( { player( "Psikutas", true ) } )
  frame.show()
  frame.boss_killed.kill( ILLIDAN )

  -- When
  frame.registry.reset()

  -- Then
  frame.should_display( popup() )
end

function BonusRollFrameSpec:should_not_redraw_while_hidden()
  -- Given
  local frame = new_frame( { player( "Psikutas", true ) } )
  frame.show()
  frame.hide()
  local renders = frame.render_count()

  -- When
  frame.boss_killed.kill( ILLIDAN )

  -- Then
  eq( frame.render_count(), renders )
end

os.exit( lu.LuaUnit.run() )
