package.path = "./?.lua;" .. package.path .. ";../?.lua;../RollFor/?.lua;../RollFor/libs/?.lua"

require( "src/compat" )
local u = require( "test/utils" )
local lu, eq = u.luaunit( "assertEquals" )
u.multi_require_src( "DebugBuffer", "Module", "Types" )
require( "src/modules" )
u.mock_wow_api()
require( "src/AutoRoundRobinDb" )
local AutoRoundRobin = require( "src/AutoRoundRobin" )

-- The queue operations on their own: a plain ordered list in, a plain ordered list out. No loot
-- window, no roster, no WoW API. Everything the award pass adds on top of these (which category's
-- queue, paying the winner, announcing it) is covered in AutoRoundRobinSpec_test.

-- serve returns nil only for a queue nobody can be served from, which these cases never hand it,
-- so the assertions read the player straight off it.
---@diagnostic disable: need-check-nil

-- A name with a * is core. The flag is the only thing a player carries besides their name and
-- class, so spelling it into the name keeps these cases readable as lists.
---@param ... string
---@return RoundRobinQueue
local function queue( ... )
  local result = {}

  for _, name in ipairs( { ... } ) do
    local core = string.sub( name, -1 ) == "*"

    table.insert( result, { name = core and string.sub( name, 1, -2 ) or name, core = core } )
  end

  return result
end

---@param q RoundRobinQueue
---@return string[]
local function marked( q )
  local result = {}

  for _, player in ipairs( q ) do
    table.insert( result, player.core and player.name .. "*" or player.name )
  end

  return result
end

---@param q RoundRobinQueue
---@return string[]
local function names( q )
  local result = {}

  for _, player in ipairs( q ) do table.insert( result, player.name ) end

  return result
end

---@param ... string
---@return table<string, boolean>
local function only( ... )
  local result = {}

  for _, name in ipairs( { ... } ) do result[ name ] = true end

  return result
end

-- The group as serve wants it: lowercased, the way in_the_group builds it. Deliberately not the
-- same shape as `only` above -- that one is the master loot candidate list, which serve does not
-- get a say in.
local function grouped( ... )
  local result = {}

  for _, name in ipairs( { ... } ) do result[ string.lower( name ) ] = true end

  return result
end

AutoRoundRobinSyncSpec = {}

function AutoRoundRobinSyncSpec:should_seed_an_empty_queue_from_the_roster_in_order()
  -- Given
  local q = {}

  -- When
  AutoRoundRobin.sync( q, { { name = "Ann" }, { name = "Bob" } } )

  -- Then
  eq( names( q ), { "Ann", "Bob" } )
end

function AutoRoundRobinSyncSpec:should_append_a_joiner_at_the_back()
  -- Given
  local q = queue( "Ann", "Bob" )

  -- When
  AutoRoundRobin.sync( q, { { name = "Bob" }, { name = "Dee" } } )

  -- Then
  eq( names( q ), { "Ann", "Bob", "Dee" } )
end

-- Leaving must not cost your place: dropping out for a wipe or a disconnect is not a reason to
-- go to the back, and taking somebody out is a deliberate act.
function AutoRoundRobinSyncSpec:should_not_remove_somebody_who_is_no_longer_in_the_group()
  -- Given
  local q = queue( "Ann", "Bob", "Cid" )

  -- When
  AutoRoundRobin.sync( q, { { name = "Bob" } } )

  -- Then
  eq( names( q ), { "Ann", "Bob", "Cid" } )
end

function AutoRoundRobinSyncSpec:should_not_move_somebody_who_is_already_in_the_queue()
  -- Given
  local q = queue( "Cid", "Ann", "Bob" )

  -- When
  AutoRoundRobin.sync( q, { { name = "Ann" }, { name = "Bob" }, { name = "Cid" } } )

  -- Then
  eq( names( q ), { "Cid", "Ann", "Bob" } )
end

function AutoRoundRobinSyncSpec:should_keep_the_class_a_joiner_arrived_with()
  -- Given
  local q = {}

  -- When
  AutoRoundRobin.sync( q, { { name = "Ann", class = "Druid" } } )

  -- Then
  eq( q[ 1 ].class, "Druid" )
end

AutoRoundRobinServeSpec = {}

function AutoRoundRobinServeSpec:should_serve_the_head_and_send_them_to_the_back()
  -- Given
  local q = queue( "Ann", "Bob", "Cid" )

  -- When
  local served = AutoRoundRobin.serve( q, AutoRoundRobin.next_position( q ) )

  -- Then
  eq( served.name, "Ann" )
  eq( names( q ), { "Bob", "Cid", "Ann" } )
end

function AutoRoundRobinServeSpec:should_go_round_in_order()
  -- Given
  local q = queue( "Ann", "Bob", "Cid" )
  local winners = {}

  -- When
  for _ = 1, 4 do
    table.insert( winners, AutoRoundRobin.serve( q, AutoRoundRobin.next_position( q ) ).name )
  end

  -- Then -- the fourth is the start of the next lap, not a second helping in this one
  eq( winners, { "Ann", "Bob", "Cid", "Ann" } )
end

function AutoRoundRobinServeSpec:should_serve_nobody_from_an_empty_queue()
  eq( AutoRoundRobin.next_position( {} ), nil )
  eq( AutoRoundRobin.serve( {}, 1 ), nil )
end

-- Only the players in the group shuffle. The winner goes to the last slot one of them occupies,
-- not to the back of the queue, so the two absent players are exactly where they were.
function AutoRoundRobinServeSpec:should_send_the_winner_to_the_back_of_the_group()
  -- Given -- Ghosta and Ghostb are in the queue but not in the group
  local q = queue( "Ann", "Ghosta", "Bob", "Cid", "Ghostb" )

  -- When
  local served = AutoRoundRobin.serve( q, 1, grouped( "Ann", "Bob", "Cid" ) )

  -- Then
  eq( served.name, "Ann" )
  eq( names( q ), { "Bob", "Ghosta", "Cid", "Ann", "Ghostb" } )
end

-- Being away neither earns priority nor costs it: a full lap of the group leaves the absent
-- players on the exact rank they started on, so they take their turn when they come back.
function AutoRoundRobinServeSpec:should_leave_an_absent_players_rank_alone_across_a_full_lap()
  -- Given
  local q = queue( "Ann", "Ghosta", "Bob", "Cid", "Ghostb" )
  local present = grouped( "Ann", "Bob", "Cid" )

  -- When -- one drop each for the three who are here
  for _ = 1, 3 do
    AutoRoundRobin.serve( q, AutoRoundRobin.next_position( q, only( "Ann", "Bob", "Cid" ) ), present )
  end

  -- Then
  eq( names( q ), { "Ann", "Ghosta", "Bob", "Cid", "Ghostb" } )
end

-- Nobody has said who is in the group, so there is nobody to be absent from: the whole queue
-- shuffles and the winner goes to the very back.
function AutoRoundRobinServeSpec:should_send_the_winner_to_the_back_of_the_queue_without_a_group()
  -- Given
  local q = queue( "Ann", "Bob", "Cid" )

  -- When
  AutoRoundRobin.serve( q, 1, nil )

  -- Then
  eq( names( q ), { "Bob", "Cid", "Ann" } )
end

-- The roster changed between the loot window opening and the award landing, so the winner is no
-- longer in the group serve was handed. The back of the queue is the answer that was right before
-- any of this, and it is still an answer.
function AutoRoundRobinServeSpec:should_fall_back_to_the_back_of_the_queue_for_a_winner_who_left()
  -- Given
  local q = queue( "Ann", "Bob", "Cid" )

  -- When
  local served = AutoRoundRobin.serve( q, 1, grouped( "Bob", "Cid" ) )

  -- Then
  eq( served.name, "Ann" )
  eq( names( q ), { "Bob", "Cid", "Ann" } )
end

AutoRoundRobinEligibilitySpec = {}

-- The design's whole point: the drop goes to the first player who can actually receive it, and
-- whoever it walks past keeps their place at the front.
function AutoRoundRobinEligibilitySpec:should_walk_past_a_head_who_cannot_receive()
  -- Given
  local q = queue( "Ann", "Bob", "Cid" )

  -- When
  local served = AutoRoundRobin.serve( q, AutoRoundRobin.next_position( q, only( "Bob", "Cid" ) ) )

  -- Then
  eq( served.name, "Bob" )
  eq( names( q ), { "Ann", "Cid", "Bob" } )
end

function AutoRoundRobinEligibilitySpec:should_let_a_passed_over_player_take_the_very_next_drop()
  -- Given
  local q = queue( "Ann", "Bob", "Cid" )
  AutoRoundRobin.serve( q, AutoRoundRobin.next_position( q, only( "Bob", "Cid" ) ) )

  -- When -- Ann walks back in
  local served = AutoRoundRobin.serve( q, AutoRoundRobin.next_position( q, only( "Ann", "Bob", "Cid" ) ) )

  -- Then
  eq( served.name, "Ann" )
end

function AutoRoundRobinEligibilitySpec:should_pick_nobody_when_nobody_in_the_queue_can_receive()
  -- Given
  local q = queue( "Ann", "Bob" )

  -- When / Then
  eq( AutoRoundRobin.next_position( q, only( "Somebody else" ) ), nil )
  eq( names( q ), { "Ann", "Bob" } )
end

-- No loot window means nobody has said who can receive, so the head is the answer -- which is
-- what the Queues window shows as next up.
function AutoRoundRobinEligibilitySpec:should_take_the_head_when_nothing_is_known_about_eligibility()
  eq( AutoRoundRobin.next_position( queue( "Ann", "Bob" ), nil ), 1 )
end

AutoRoundRobinCycleSpec = {}

function AutoRoundRobinCycleSpec:should_send_the_head_to_the_back_on_a_positive_offset()
  local q = queue( "Ann", "Bob", "Cid" )

  AutoRoundRobin.cycle( q, 1 )

  eq( names( q ), { "Bob", "Cid", "Ann" } )
end

function AutoRoundRobinCycleSpec:should_bring_the_last_player_to_the_front_on_a_negative_offset()
  local q = queue( "Ann", "Bob", "Cid" )

  AutoRoundRobin.cycle( q, -1 )

  eq( names( q ), { "Cid", "Ann", "Bob" } )
end

function AutoRoundRobinCycleSpec:should_do_nothing_to_a_queue_too_short_to_rotate()
  local q = queue( "Ann" )

  AutoRoundRobin.cycle( q, 1 )
  AutoRoundRobin.cycle( q, -1 )

  eq( names( q ), { "Ann" } )
end

-- Bounded, it rotates the two ends of the stretch and leaves everybody between them alone. This
-- is what the Queues window asks for: the players it does not draw keep their place.
function AutoRoundRobinCycleSpec:should_rotate_only_between_the_bounds_on_a_positive_offset()
  local q = queue( "Ann", "Bob", "Cid", "Dee" )

  AutoRoundRobin.cycle( q, 1, 1, 3 )

  eq( names( q ), { "Bob", "Cid", "Ann", "Dee" } )
end

function AutoRoundRobinCycleSpec:should_rotate_only_between_the_bounds_on_a_negative_offset()
  local q = queue( "Ann", "Bob", "Cid", "Dee" )

  AutoRoundRobin.cycle( q, -1, 2, 4 )

  eq( names( q ), { "Ann", "Dee", "Bob", "Cid" } )
end

function AutoRoundRobinCycleSpec:should_do_nothing_between_bounds_too_close_to_rotate()
  local q = queue( "Ann", "Bob", "Cid" )

  AutoRoundRobin.cycle( q, 1, 2, 2 )
  AutoRoundRobin.cycle( q, -1, 2, 2 )

  eq( names( q ), { "Ann", "Bob", "Cid" } )
end

function AutoRoundRobinCycleSpec:should_ignore_bounds_that_are_not_in_the_queue()
  local q = queue( "Ann", "Bob" )

  AutoRoundRobin.cycle( q, 1, 1, 9 )

  eq( names( q ), { "Ann", "Bob" } )
end

AutoRoundRobinMoveSpec = {}

function AutoRoundRobinMoveSpec:should_swap_a_player_with_the_one_above()
  local q = queue( "Ann", "Bob", "Cid" )

  AutoRoundRobin.move( q, 3, -1 )

  eq( names( q ), { "Ann", "Cid", "Bob" } )
end

function AutoRoundRobinMoveSpec:should_swap_a_player_with_the_one_below()
  local q = queue( "Ann", "Bob", "Cid" )

  AutoRoundRobin.move( q, 1, 1 )

  eq( names( q ), { "Bob", "Ann", "Cid" } )
end

-- Deliberately does not wrap: an arrow on the last row that sent that player to the top would
-- read as a bug rather than as a rotation, and rotating is what cycle is for.
function AutoRoundRobinMoveSpec:should_not_wrap_off_either_end()
  local q = queue( "Ann", "Bob" )

  AutoRoundRobin.move( q, 1, -1 )
  AutoRoundRobin.move( q, 2, 1 )

  eq( names( q ), { "Ann", "Bob" } )
end

function AutoRoundRobinMoveSpec:should_ignore_a_position_that_is_not_in_the_queue()
  local q = queue( "Ann", "Bob" )

  AutoRoundRobin.move( q, 9, -1 )

  eq( names( q ), { "Ann", "Bob" } )
end

AutoRoundRobinPositionSpec = {}

function AutoRoundRobinPositionSpec:should_find_a_player_case_insensitively()
  eq( AutoRoundRobin.position_of( queue( "Ann", "Bob" ), "bOB" ), 2 )
end

function AutoRoundRobinPositionSpec:should_not_find_somebody_who_is_not_there()
  eq( AutoRoundRobin.position_of( queue( "Ann" ), "Bob" ), nil )
end

AutoRoundRobinCoreSpec = {}

-- Joiners arrive transient: the roster is what swept them in, and the roster is exactly what the
-- next group takes away again.
function AutoRoundRobinCoreSpec:should_append_a_joiner_as_transient()
  -- Given
  local q = queue( "Ann*" )

  -- When
  AutoRoundRobin.sync( q, { { name = "Bob" } } )

  -- Then
  eq( marked( q ), { "Ann*", "Bob" } )
end

-- Somebody already in the queue is left exactly as they are. A core player who steps out and
-- comes back must not be demoted by the roster update that readmits them.
function AutoRoundRobinCoreSpec:should_not_touch_the_flag_of_somebody_already_in_the_queue()
  -- Given
  local q = queue( "Ann*", "Bob" )

  -- When
  AutoRoundRobin.sync( q, { { name = "Ann" }, { name = "Bob" } } )

  -- Then
  eq( marked( q ), { "Ann*", "Bob" } )
end

AutoRoundRobinDropTransientsSpec = {}

function AutoRoundRobinDropTransientsSpec:should_keep_the_core_players_in_the_order_they_were_in()
  -- Given
  local q = queue( "Ann", "Bob*", "Cid", "Dee*" )

  -- When
  AutoRoundRobin.drop_transients( q )

  -- Then
  eq( names( q ), { "Bob", "Dee" } )
end

function AutoRoundRobinDropTransientsSpec:should_empty_a_queue_with_nobody_core_in_it()
  -- Given
  local q = queue( "Ann", "Bob" )

  -- When
  AutoRoundRobin.drop_transients( q )

  -- Then
  eq( names( q ), {} )
end

function AutoRoundRobinDropTransientsSpec:should_leave_an_all_core_queue_alone()
  -- Given
  local q = queue( "Ann*", "Bob*" )

  -- When
  AutoRoundRobin.drop_transients( q )

  -- Then
  eq( names( q ), { "Ann", "Bob" } )
end

function AutoRoundRobinDropTransientsSpec:should_do_nothing_to_an_empty_queue()
  -- Given
  local q = {}

  -- When
  AutoRoundRobin.drop_transients( q )

  -- Then
  eq( names( q ), {} )
end

os.exit( lu.LuaUnit.run() )
