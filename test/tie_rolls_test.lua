package.path = "./?.lua;" .. package.path .. ";../?.lua;../RollFor/?.lua;../RollFor/libs/?.lua"

local lu = require( "luaunit" )
local u = require( "test/utils" )
local player, leader, is_in_raid = u.player, u.raid_leader, u.is_in_raid
local r, rw = u.raid_message, u.raid_warning
local c, cr = u.console_message, u.console_and_raid_message
local rolling_finished = u.rolling_finished
local roll_for, roll = u.roll_for, u.roll
local assert_messages = u.assert_messages
local tick, repeating_tick = u.tick, u.repeating_tick
local finish_rolling = u.finish_rolling

TieRollsSpec = {}

function TieRollsSpec:should_recognize_tie_rolls_when_all_players_tie()
  -- Given
  player( "Psikutas" )
  is_in_raid( leader( "Psikutas" ), "Obszczymucha" )

  -- When
  roll_for( "Hearthstone" )
  roll( "Obszczymucha", 69 )
  roll( "Psikutas", 69 )
  tick() -- Tick to trigger a reroll.
  roll( "Psikutas", 100 )
  roll( "Obszczymucha", 99 )

  -- Then
  assert_messages(
    rw( "Roll for [Hearthstone]: /roll (MS) or /roll 99 (OS) or /roll 98 (TMOG)" ),
    cr( "The highest roll was 69 by Obszczymucha and Psikutas." ),
    r( "Obszczymucha and Psikutas /roll for [Hearthstone] now." ),
    cr( "Psikutas re-rolled the highest (100) for [Hearthstone]." ),
    rolling_finished()
  )
end

function TieRollsSpec:should_recognize_tie_rolls_when_some_players_tie()
  -- Given
  player( "Psikutas" )
  is_in_raid( leader( "Psikutas" ), "Obszczymucha", "Ponpon" )

  -- When
  roll_for( "Hearthstone" )
  roll( "Obszczymucha", 69 )
  roll( "Psikutas", 69 )
  repeating_tick( 8 )
  tick() -- Tick to trigger a reroll.
  roll( "Psikutas", 100 )
  roll( "Obszczymucha", 99 )

  -- Then
  assert_messages(
    rw( "Roll for [Hearthstone]: /roll (MS) or /roll 99 (OS) or /roll 98 (TMOG)" ),
    r( "Stopping rolls in 3", "2", "1" ),
    cr( "The highest roll was 69 by Obszczymucha and Psikutas." ),
    r( "Obszczymucha and Psikutas /roll for [Hearthstone] now." ),
    cr( "Psikutas re-rolled the highest (100) for [Hearthstone]." ),
    rolling_finished()
  )
end

function TieRollsSpec:should_not_reroll_if_enough_items_dropped_for_players_that_tied_and_top_roll_is_not_a_tie()
  -- Given
  player( "Psikutas" )
  is_in_raid( leader( "Psikutas" ), "Obszczymucha", "Ponpon" )

  -- When
  roll_for( "Hearthstone", 3 )
  roll( "Obszczymucha", 69 )
  roll( "Psikutas", 42 )
  roll( "Ponpon", 42 )

  -- Then
  assert_messages(
    rw( "Roll for 3x[Hearthstone]: /roll (MS) or /roll 99 (OS) or /roll 98 (TMOG). 3 top rolls win." ),
    cr( "Obszczymucha rolled the highest (69) for [Hearthstone]." ),
    cr( "Ponpon and Psikutas rolled the next highest (42) for [Hearthstone]." ),
    rolling_finished()
  )
end

function TieRollsSpec:should_not_reroll_if_enough_items_dropped_for_players_that_tied_and_top_roll_is_a_tie()
  -- Given
  player( "Psikutas" )
  is_in_raid( leader( "Psikutas" ), "Obszczymucha", "Ponpon" )

  -- When
  roll_for( "Hearthstone", 3 )
  roll( "Obszczymucha", 69 )
  roll( "Psikutas", 42 )
  roll( "Ponpon", 69 )

  -- Then
  assert_messages(
    rw( "Roll for 3x[Hearthstone]: /roll (MS) or /roll 99 (OS) or /roll 98 (TMOG). 3 top rolls win." ),
    cr( "Obszczymucha and Ponpon rolled the highest (69) for [Hearthstone]." ),
    cr( "Psikutas rolled the next highest (42) for [Hearthstone]." ),
    rolling_finished()
  )
end

function TieRollsSpec:should_reroll_if_not_enough_items_dropped_for_players_that_tied()
  -- Given
  player( "Psikutas" )
  is_in_raid( leader( "Psikutas" ), "Obszczymucha", "Ponpon", "Chuj" )

  -- When
  roll_for( "Hearthstone", 2 )
  roll( "Obszczymucha", 69 )
  roll( "Psikutas", 42 )
  roll( "Chuj", 13 )
  roll( "Ponpon", 42 )
  tick() -- Tick to trigger a reroll.
  roll( "Psikutas", 100 )
  roll( "Ponpon", 99 )

  -- Then
  assert_messages(
    rw( "Roll for 2x[Hearthstone]: /roll (MS) or /roll 99 (OS) or /roll 98 (TMOG). 2 top rolls win." ),
    cr( "Obszczymucha rolled the highest (69) for [Hearthstone]." ),
    cr( "The next highest roll was 42 by Ponpon and Psikutas." ),
    r( "Ponpon and Psikutas /roll for [Hearthstone] now." ),
    cr( "Psikutas re-rolled the highest (100) for [Hearthstone]." ),
    rolling_finished()
  )
end

function TieRollsSpec:should_reroll_if_two_items_dropped_and_three_players_tied()
  -- Given
  player( "Psikutas" )
  is_in_raid( leader( "Psikutas" ), "Obszczymucha", "Ponpon", "Chuj" )

  -- When
  roll_for( "Hearthstone", 2 )
  roll( "Obszczymucha", 69 )
  roll( "Psikutas", 69 )
  roll( "Chuj", 69 )
  roll( "Ponpon", 42 )
  tick() -- Tick to trigger a reroll.
  roll( "Psikutas", 100 )
  roll( "Chuj", 99 )
  roll( "Obszczymucha", 98 )

  -- Then
  assert_messages(
    rw( "Roll for 2x[Hearthstone]: /roll (MS) or /roll 99 (OS) or /roll 98 (TMOG). 2 top rolls win." ),
    cr( "The highest roll was 69 by Chuj, Obszczymucha and Psikutas." ),
    r( "Chuj, Obszczymucha and Psikutas /roll for 2x[Hearthstone] now. 2 top rolls win." ),
    cr( "Psikutas re-rolled the highest (100) for [Hearthstone]." ),
    cr( "Chuj re-rolled the next highest (99) for [Hearthstone]." ),
    rolling_finished()
  )
end

function TieRollsSpec:should_not_allow_the_winner_to_reroll_a_tie_of_other_players()
  -- Given
  player( "Ohhaimark" )
  is_in_raid( leader( "Ohhaimark" ), "Obszczymucha", "Jogobobek" )

  -- When
  roll_for( "Hearthstone", 2 )
  roll( "Obszczymucha", 69 )
  roll( "Jogobobek", 69 )
  roll( "Ohhaimark", 99 )
  tick() -- Tick to trigger a reroll.
  roll( "Ohhaimark", 23 )

  -- Then
  assert_messages(
    rw( "Roll for 2x[Hearthstone]: /roll (MS) or /roll 99 (OS) or /roll 98 (TMOG). 2 top rolls win." ),
    cr( "Ohhaimark rolled the highest (99) for [Hearthstone]." ),
    cr( "The next highest roll was 69 by Jogobobek and Obszczymucha." ),
    r( "Jogobobek and Obszczymucha /roll for [Hearthstone] now." ),
    c( "RollFor: Ohhaimark is not allowed to re-roll. This roll (23) is ignored." )
  )
end

function TieRollsSpec:should_resolve_a_tie_if_it_was_the_second_top_roll()
  -- Given
  player( "Ohhaimark" )
  is_in_raid( leader( "Ohhaimark" ), "Obszczymucha", "Jogobobek" )

  -- When
  roll_for( "Hearthstone", 2 )
  roll( "Obszczymucha", 69 )
  roll( "Jogobobek", 69 )
  roll( "Ohhaimark", 99 )
  tick() -- Tick to trigger a reroll.
  roll( "Jogobobek", 68 )
  roll( "Obszczymucha", 67 )

  -- Then
  assert_messages(
    rw( "Roll for 2x[Hearthstone]: /roll (MS) or /roll 99 (OS) or /roll 98 (TMOG). 2 top rolls win." ),
    cr( "Ohhaimark rolled the highest (99) for [Hearthstone]." ),
    cr( "The next highest roll was 69 by Jogobobek and Obszczymucha." ),
    r( "Jogobobek and Obszczymucha /roll for [Hearthstone] now." ),
    cr( "Jogobobek re-rolled the highest (68) for [Hearthstone]." ),
    rolling_finished()
  )
end

function TieRollsSpec:should_resolve_a_second_tie_if_it_was_the_top_roll()
  -- Given
  player( "Ohhaimark" )
  is_in_raid( leader( "Ohhaimark" ), "Obszczymucha", "Jogobobek" )

  -- When
  roll_for( "Hearthstone", 1 )
  roll( "Obszczymucha", 69 )
  roll( "Jogobobek", 69 )
  roll( "Ohhaimark", 1 )
  tick() -- Tick to trigger a reroll.
  roll( "Jogobobek", 68 )
  roll( "Obszczymucha", 68 )
  tick() -- Tick to trigger a reroll.
  roll( "Obszczymucha", 2 )
  roll( "Jogobobek", 1 )

  -- Then
  assert_messages(
    rw( "Roll for [Hearthstone]: /roll (MS) or /roll 99 (OS) or /roll 98 (TMOG)" ),
    cr( "The highest roll was 69 by Jogobobek and Obszczymucha." ),
    r( "Jogobobek and Obszczymucha /roll for [Hearthstone] now." ),
    cr( "The highest re-roll was 68 by Jogobobek and Obszczymucha." ),
    r( "Jogobobek and Obszczymucha /roll for [Hearthstone] now." ),
    cr( "Obszczymucha re-rolled the highest (2) for [Hearthstone]." ),
    rolling_finished()
  )
end

function TieRollsSpec:should_resolve_a_second_tie_if_it_was_the_second_top_roll()
  -- Given
  player( "Ohhaimark" )
  is_in_raid( leader( "Ohhaimark" ), "Obszczymucha", "Jogobobek" )

  -- When
  roll_for( "Hearthstone", 2 )
  roll( "Obszczymucha", 69 )
  roll( "Jogobobek", 69 )
  roll( "Ohhaimark", 99 )
  tick() -- Tick to trigger a reroll.
  roll( "Jogobobek", 68 )
  roll( "Obszczymucha", 68 )
  tick() -- Tick to trigger a reroll.
  roll( "Obszczymucha", 2 )
  roll( "Jogobobek", 1 )

  -- Then
  assert_messages(
    rw( "Roll for 2x[Hearthstone]: /roll (MS) or /roll 99 (OS) or /roll 98 (TMOG). 2 top rolls win." ),
    cr( "Ohhaimark rolled the highest (99) for [Hearthstone]." ),
    cr( "The next highest roll was 69 by Jogobobek and Obszczymucha." ),
    r( "Jogobobek and Obszczymucha /roll for [Hearthstone] now." ),
    cr( "The highest re-roll was 68 by Jogobobek and Obszczymucha." ),
    r( "Jogobobek and Obszczymucha /roll for [Hearthstone] now." ),
    cr( "Obszczymucha re-rolled the highest (2) for [Hearthstone]." ),
    rolling_finished()
  )
end

function TieRollsSpec:should_wait_for_the_rerollers_forever()
  -- Given
  player( "Ohhaimark" )
  is_in_raid( leader( "Ohhaimark" ), "Obszczymucha", "Jogobobek" )

  -- When
  roll_for( "Hearthstone", 2 )
  roll( "Obszczymucha", 69 )
  roll( "Jogobobek", 69 )
  roll( "Ohhaimark", 99 )
  tick() -- Tick to trigger a reroll.
  repeating_tick( 9000 )

  -- Then
  assert_messages(
    rw( "Roll for 2x[Hearthstone]: /roll (MS) or /roll 99 (OS) or /roll 98 (TMOG). 2 top rolls win." ),
    cr( "Ohhaimark rolled the highest (99) for [Hearthstone]." ),
    cr( "The next highest roll was 69 by Jogobobek and Obszczymucha." ),
    r( "Jogobobek and Obszczymucha /roll for [Hearthstone] now." )
  )
end

function TieRollsSpec:should_take_the_tie_roller_as_a_winner_if_the_other_tie_roller_is_retarded_and_doesnt_want_to_roll()
  -- Given
  player( "Ohhaimark" )
  is_in_raid( leader( "Ohhaimark" ), "Obszczymucha", "Jogobobek" )

  -- When
  roll_for( "Hearthstone", 2 )
  roll( "Obszczymucha", 69 )
  roll( "Jogobobek", 69 )
  roll( "Ohhaimark", 99 )
  tick() -- Tick to trigger a reroll.
  roll( "Jogobobek", 1 )
  finish_rolling()

  -- Then
  assert_messages(
    rw( "Roll for 2x[Hearthstone]: /roll (MS) or /roll 99 (OS) or /roll 98 (TMOG). 2 top rolls win." ),
    cr( "Ohhaimark rolled the highest (99) for [Hearthstone]." ),
    cr( "The next highest roll was 69 by Jogobobek and Obszczymucha." ),
    r( "Jogobobek and Obszczymucha /roll for [Hearthstone] now." ),
    cr( "Jogobobek re-rolled the highest (1) for [Hearthstone]." ),
    rolling_finished()
  )
end

function TieRollsSpec:should_take_the_tie_roller_winner_if_one_tie_roller_is_retarded_and_doesnt_want_to_roll()
  -- Given
  player( "Ohhaimark" )
  is_in_raid( leader( "Ohhaimark" ), "Obszczymucha", "Jogobobek" )

  -- When
  roll_for( "Hearthstone", 2 )
  roll( "Obszczymucha", 69 )
  roll( "Jogobobek", 69 )
  roll( "Ohhaimark", 69 )
  tick() -- Tick to trigger a reroll.
  roll( "Jogobobek", 1 )
  roll( "Ohhaimark", 2 )
  finish_rolling()

  -- Then
  assert_messages(
    rw( "Roll for 2x[Hearthstone]: /roll (MS) or /roll 99 (OS) or /roll 98 (TMOG). 2 top rolls win." ),
    cr( "The highest roll was 69 by Jogobobek, Obszczymucha and Ohhaimark." ),
    r( "Jogobobek, Obszczymucha and Ohhaimark /roll for 2x[Hearthstone] now. 2 top rolls win." ),
    cr( "Ohhaimark re-rolled the highest (2) for [Hearthstone]." ),
    cr( "Jogobobek re-rolled the next highest (1) for [Hearthstone]." ),
    rolling_finished()
  )
end

u.mock_libraries()
u.load_real_stuff()

os.exit( lu.LuaUnit.run() )