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
