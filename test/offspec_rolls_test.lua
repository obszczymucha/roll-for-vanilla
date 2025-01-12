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
local roll_for = utils.roll_for
local roll_os = utils.roll_os
local assert_messages = utils.assert_messages
local tick = utils.repeating_tick

OffspecRollsSpec = {}

-- This gives players a chance to still roll MS if they rolled OS by mistake.
function OffspecRollsSpec:should_not_finish_rolling_automatically_if_all_players_rolled()
  -- Given
  player( "Psikutas" )
  is_in_raid( leader( "Psikutas" ), "Obszczymucha" )

  -- When
  roll_for( "Hearthstone" )
  roll_os( "Obszczymucha", 42 )
  roll_os( "Psikutas", 69 )
  tick( 8 )

  -- Then
  assert_messages(
    rw( "Roll for [Hearthstone]: /roll (MS) or /roll 99 (OS) or /roll 98 (TMOG)" ),
    r( "Stopping rolls in 3", "2", "1" ),
    cr( "Psikutas rolled the highest (69) for [Hearthstone] (OS)." ),
    rolling_finished()
  )
end

function OffspecRollsSpec:should_finish_rolling_automatically_if_number_of_items_is_equal_to_the_size_of_the_group()
  -- Given
  player( "Psikutas" )
  is_in_raid( leader( "Psikutas" ), "Obszczymucha" )

  -- When
  roll_for( "Hearthstone", 2 )
  roll_os( "Psikutas", 69 )
  roll_os( "Obszczymucha", 100 )

  -- Then
  assert_messages(
    rw( "Roll for 2x[Hearthstone]: /roll (MS) or /roll 99 (OS) or /roll 98 (TMOG). 2 top rolls win." ),
    cr( "Obszczymucha rolled the highest (100) for [Hearthstone] (OS)." ),
    cr( "Psikutas rolled the next highest (69) for [Hearthstone] (OS)." ),
    rolling_finished()
  )
end

function OffspecRollsSpec:should_not_finish_rolling_automatically_if_number_of_items_is_less_than_the_size_of_the_group()
  -- Given
  player( "Psikutas" )
  is_in_raid( leader( "Psikutas" ), "Obszczymucha", "Chuj" )

  -- When
  roll_for( "Hearthstone", 2 )
  roll_os( "Psikutas", 69 )
  roll_os( "Obszczymucha", 100 )
  tick( 6 )
  roll_os( "Chuj", 42 )
  tick( 2 )

  -- Then
  assert_messages(
    rw( "Roll for 2x[Hearthstone]: /roll (MS) or /roll 99 (OS) or /roll 98 (TMOG). 2 top rolls win." ),
    r( "Stopping rolls in 3", "2", "1" ),
    cr( "Obszczymucha rolled the highest (100) for [Hearthstone] (OS)." ),
    cr( "Psikutas rolled the next highest (69) for [Hearthstone] (OS)." ),
    rolling_finished()
  )
end

function OffspecRollsSpec:should_detect_and_ignore_double_rolls()
  -- Given
  player( "Psikutas" )
  is_in_raid( leader( "Psikutas" ), "Obszczymucha" )

  -- When
  roll_for( "Hearthstone" )
  roll_os( "Obszczymucha", 13 )
  tick( 6 )
  roll_os( "Obszczymucha", 100 )
  roll_os( "Psikutas", 69 )
  tick( 2 )

  -- Then
  assert_messages(
    rw( "Roll for [Hearthstone]: /roll (MS) or /roll 99 (OS) or /roll 98 (TMOG)" ),
    r( "Stopping rolls in 3", "2" ),
    c( "RollFor: Obszczymucha exhausted their rolls. This roll (100) is ignored." ),
    r( "1" ),
    cr( "Psikutas rolled the highest (69) for [Hearthstone] (OS)." ),
    rolling_finished()
  )
end

utils.mock_libraries()
utils.load_real_stuff()

os.exit( lu.LuaUnit.run() )
