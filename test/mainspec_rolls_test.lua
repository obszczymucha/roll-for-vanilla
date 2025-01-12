package.path = "./?.lua;" .. package.path .. ";../?.lua;../RollFor/?.lua;../RollFor/libs/?.lua"

local lu = require( "luaunit" )
local utils = require( "test/utils" )
local player = utils.player
local leader = utils.raid_leader
local is_in_raid = utils.is_in_raid
local c = utils.console_message
local r = utils.raid_message
local cr = utils.console_and_raid_message
local rw = utils.raid_warning
local rolling_finished = utils.rolling_finished
local rolling_not_in_progress = utils.rolling_not_in_progress
local roll_for = utils.roll_for
local finish_rolling = utils.finish_rolling
local roll = utils.roll
local assert_messages = utils.assert_messages
local repeating_tick = utils.repeating_tick

MainspecRollsSpec = {}

function MainspecRollsSpec:should_finish_rolling_automatically_if_all_players_rolled()
  -- Given
  player( "Psikutas" )
  is_in_raid( leader( "Psikutas" ), "Obszczymucha" )

  -- When
  roll_for( "Hearthstone" )
  roll( "Psikutas", 69 )
  roll( "Obszczymucha", 42 )
  finish_rolling()

  -- Then
  assert_messages(
    rw( "Roll for [Hearthstone]: /roll (MS) or /roll 99 (OS) or /roll 98 (TMOG)" ),
    cr( "Psikutas rolled the highest (69) for [Hearthstone]." ),
    rolling_finished(),
    rolling_not_in_progress()
  )
end

function MainspecRollsSpec:should_finish_rolling_after_the_timer_if_not_all_players_rolled()
  -- Given
  player( "Psikutas" )
  is_in_raid( leader( "Psikutas" ), "Obszczymucha" )

  -- When
  roll_for( "Hearthstone" )
  roll( "Psikutas", 69 )
  repeating_tick( 8 )
  finish_rolling()

  -- Then
  assert_messages(
    rw( "Roll for [Hearthstone]: /roll (MS) or /roll 99 (OS) or /roll 98 (TMOG)" ),
    r( "Stopping rolls in 3", "2", "1" ),
    cr( "Psikutas rolled the highest (69) for [Hearthstone]." ),
    rolling_finished(),
    rolling_not_in_progress()
  )
end

function MainspecRollsSpec:should_detect_and_ignore_double_rolls()
  -- Given
  player( "Psikutas" )
  is_in_raid( leader( "Psikutas" ), "Obszczymucha" )

  -- When
  roll_for( "Hearthstone" )
  roll( "Obszczymucha", 13 )
  repeating_tick( 6 )
  roll( "Obszczymucha", 100 )
  roll( "Psikutas", 69 )

  -- Then
  assert_messages(
    rw( "Roll for [Hearthstone]: /roll (MS) or /roll 99 (OS) or /roll 98 (TMOG)" ),
    r( "Stopping rolls in 3", "2" ),
    c( "RollFor: Obszczymucha exhausted their rolls. This roll (100) is ignored." ),
    cr( "Psikutas rolled the highest (69) for [Hearthstone]." ),
    rolling_finished()
  )
end

function MainspecRollsSpec:should_recognize_multiple_rollers_for_multiple_items_when_all_players_rolled()
  -- Given
  player( "Psikutas" )
  is_in_raid( leader( "Psikutas" ), "Obszczymucha" )

  -- When
  roll_for( "Hearthstone", 2 )
  roll( "Psikutas", 69 )
  roll( "Obszczymucha", 100 )

  -- Then
  assert_messages(
    rw( "Roll for 2x[Hearthstone]: /roll (MS) or /roll 99 (OS) or /roll 98 (TMOG). 2 top rolls win." ),
    cr( "Obszczymucha rolled the highest (100) for [Hearthstone]." ),
    cr( "Psikutas rolled the next highest (69) for [Hearthstone]." ),
    rolling_finished()
  )
end

function MainspecRollsSpec:should_recognize_multiple_rollers_for_multiple_items_when_not_all_players_rolled()
  -- Given
  player( "Psikutas" )
  is_in_raid( leader( "Psikutas" ), "Obszczymucha", "Ponpon" )

  -- When
  roll_for( "Hearthstone", 2 )
  roll( "Psikutas", 69 )
  repeating_tick( 6 )
  roll( "Obszczymucha", 100 )
  repeating_tick( 2 )

  -- Then
  assert_messages(
    rw( "Roll for 2x[Hearthstone]: /roll (MS) or /roll 99 (OS) or /roll 98 (TMOG). 2 top rolls win." ),
    r( "Stopping rolls in 3", "2", "1" ),
    cr( "Obszczymucha rolled the highest (100) for [Hearthstone]." ),
    cr( "Psikutas rolled the next highest (69) for [Hearthstone]." ),
    rolling_finished()
  )
end

utils.mock_libraries()
utils.load_real_stuff()

os.exit( lu.LuaUnit.run() )
