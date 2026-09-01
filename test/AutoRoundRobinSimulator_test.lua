---@diagnostic disable: inject-field
package.path = "./?.lua;" .. package.path .. ";../?.lua;../RollFor/?.lua;../RollFor/libs/?.lua"

require( "src/compat" )
local u = require( "test/utils" )
local lu, eq = u.luaunit( "assertEquals" )
u.multi_require_src( "DebugBuffer", "Module", "Types" )
require( "src/modules" )
require( "src/ItemCatalogue" )
require( "src/AutoRoundRobinDb" )
require( "src/AutoRoundRobin" )
local AutoRoundRobinSimulator = require( "src/AutoRoundRobinSimulator" )

u.mock_wow_api()

-- The simulator runs the shipped queue operations over a roster it invents, so these specs read
-- its chat output. There is nothing random in it, so every trace line below is exact.

---@param live_queue table[]? -- the live Gems queue `raid` with no arguments copies
---@param group_names string[]? -- the real group that copy also reads
local function simulator( live_queue, group_names )
  local players = {}
  for _, name in ipairs( group_names or {} ) do table.insert( players, { name = name, class = "Warrior" } ) end

  local group_roster = { get_all_players_in_my_group = function() return players end }

  local sut = AutoRoundRobinSimulator.new( { queues = { Gems = live_queue or {} } }, group_roster )

  -- What the addon printed, with the "RollFor: " prefix and the colors stripped -- neither is
  -- what these tests are about. Installed after the simulator is built, because every one after
  -- the first re-registers /rfrotate and slash_cmd says so; that's the harness talking, not the
  -- code under test.
  local printed = {}

  RollFor.api.DEFAULT_CHAT_FRAME = {
    AddMessage = function( _, message )
      local plain = u.decolorize( message ) or message
      table.insert( printed, (string.gsub( plain, "^RollFor: ", "" )) )
    end
  }

  -- Only the lines a spec asked about: run() is chatty by design, and a spec that had to restate
  -- the whole preamble to assert one trace line would be a spec about the preamble.
  sut.run_and_capture = function( args )
    printed = {}
    sut.run( args )

    return printed
  end

  return sut
end

---@param lines string[]
---@param needle string
local function assert_says( lines, needle )
  for _, line in ipairs( lines ) do
    if string.find( line, needle, 1, true ) then return end
  end

  error( string.format( "Expected a line containing %q. Got:\n  %s", needle, table.concat( lines, "\n  " ) ), 2 )
end

RoundRobinSimulatorSpec = {}

function RoundRobinSimulatorSpec:should_print_usage_when_asked_for_nothing()
  local out = simulator().run_and_capture( "" )

  assert_says( out, "/rfrotate" )
  assert_says( out, "raid <names or count>" )
  assert_says( out, "cycle up, cycle down" )
end

function RoundRobinSimulatorSpec:should_refuse_to_drop_before_a_raid_is_started()
  assert_says( simulator().run_and_capture( "drop" ), "No simulated raid yet" )
end

function RoundRobinSimulatorSpec:should_start_a_raid_from_names()
  assert_says( simulator().run_and_capture( "raid Ann,Bob,Cid" ), "Simulating 3 players: Ann, Bob, Cid." )
end

function RoundRobinSimulatorSpec:should_start_a_raid_from_a_count()
  assert_says( simulator().run_and_capture( "raid 4" ), "Simulating 4 players: Ann, Bob, Cid, Dee." )
end

function RoundRobinSimulatorSpec:should_refuse_an_impossible_headcount()
  assert_says( simulator().run_and_capture( "raid 0" ), "Pick between" )
end

function RoundRobinSimulatorSpec:should_go_round_in_order()
  local sut = simulator()
  sut.run( "raid Ann,Bob,Cid" )

  eq( sut.run_and_capture( "drop 4" ), {
    "4 drops:",
    "  1. Ann",
    "  2. Bob",
    "  3. Cid",
    "  4. Ann"
  } )
end

function RoundRobinSimulatorSpec:should_list_the_queue_with_the_head_marked_next()
  local sut = simulator()
  sut.run( "raid Ann,Bob,Cid" )
  sut.run( "drop" )

  eq( sut.run_and_capture( "queue" ), {
    "3 in the queue, 1 drop so far:",
    "  1. Bob  <- next",
    "  2. Cid",
    "  3. Ann"
  } )
end

RoundRobinSimulatorAbsenceSpec = {}

-- The subtle half of the design: the drop walks past somebody who cannot receive rather than
-- stalling on them or costing them their place.
function RoundRobinSimulatorAbsenceSpec:should_walk_past_a_head_who_is_away()
  local sut = simulator()
  sut.run( "raid Ann,Bob,Cid" )
  sut.run( "away Ann" )

  eq( sut.run_and_capture( "drop" ), {
    "1 drop:",
    "  1. Bob -- passed over Ann, who keeps their place"
  } )
end

function RoundRobinSimulatorAbsenceSpec:should_let_a_returning_player_take_the_very_next_drop()
  local sut = simulator()
  sut.run( "raid Ann,Bob,Cid" )
  sut.run( "away Ann" )
  sut.run( "drop 2" )
  sut.run( "back Ann" )

  -- The third drop overall, and hers -- the two she was away for did not cost her the front.
  assert_says( sut.run_and_capture( "drop" ), "3. Ann" )
end

function RoundRobinSimulatorAbsenceSpec:should_mark_an_away_player_in_the_queue()
  local sut = simulator()
  sut.run( "raid Ann,Bob" )
  sut.run( "away Ann" )

  eq( sut.run_and_capture( "queue" ), {
    "2 in the queue, 0 drops so far:",
    "  1. Ann (away)",
    "  2. Bob  <- next"
  } )
end

function RoundRobinSimulatorAbsenceSpec:should_skip_a_drop_when_nobody_can_receive()
  local sut = simulator()
  sut.run( "raid Ann,Bob" )
  sut.run( "away Ann" )
  sut.run( "away Bob" )

  assert_says( sut.run_and_capture( "drop" ), "Nobody in the queue can receive" )
  assert_says( sut.run_and_capture( "queue" ), "0 drops so far" )
end

function RoundRobinSimulatorAbsenceSpec:should_find_a_player_case_insensitively()
  local sut = simulator()
  sut.run( "raid Ann,Bob" )

  assert_says( sut.run_and_capture( "away ANN" ), "Ann is out of range" )
end

function RoundRobinSimulatorAbsenceSpec:should_say_so_when_the_name_is_not_in_the_queue()
  local sut = simulator()
  sut.run( "raid Ann" )

  assert_says( sut.run_and_capture( "away Nobody" ), "Nobody is not in the simulated queue." )
end

RoundRobinSimulatorEditingSpec = {}

function RoundRobinSimulatorEditingSpec:should_add_a_player_at_the_back()
  local sut = simulator()
  sut.run( "raid Ann,Bob" )

  assert_says( sut.run_and_capture( "add Dee" ), "Dee joins at the back, in place 3." )
  assert_says( sut.run_and_capture( "queue" ), "3. Dee" )
end

function RoundRobinSimulatorEditingSpec:should_refuse_a_duplicate()
  local sut = simulator()
  sut.run( "raid Ann,Bob" )

  assert_says( sut.run_and_capture( "add Ann" ), "already in the queue" )
end

function RoundRobinSimulatorEditingSpec:should_remove_a_player()
  local sut = simulator()
  sut.run( "raid Ann,Bob" )

  assert_says( sut.run_and_capture( "remove Ann" ), "Ann is out of the queue." )
  assert_says( sut.run_and_capture( "queue" ), "1. Bob" )
end

function RoundRobinSimulatorEditingSpec:should_move_one_player_a_place()
  local sut = simulator()
  sut.run( "raid Ann,Bob,Cid" )

  assert_says( sut.run_and_capture( "up Cid" ), "Cid moves from place 3 to 2." )
  assert_says( sut.run_and_capture( "down Ann" ), "Ann moves from place 1 to 2." )
end

-- Moving deliberately does not wrap, so the arrow at either end says so rather than doing
-- something surprising.
function RoundRobinSimulatorEditingSpec:should_say_when_a_player_is_already_at_an_end()
  local sut = simulator()
  sut.run( "raid Ann,Bob" )

  assert_says( sut.run_and_capture( "up Ann" ), "Ann is already at the front." )
  assert_says( sut.run_and_capture( "down Bob" ), "Bob is already at the back." )
end

function RoundRobinSimulatorEditingSpec:should_cycle_the_whole_queue()
  local sut = simulator()
  sut.run( "raid Ann,Bob,Cid" )

  assert_says( sut.run_and_capture( "cycle up" ), "Cycled up: Bob, Cid, Ann." )
  assert_says( sut.run_and_capture( "cycle down" ), "Cycled down: Ann, Bob, Cid." )
end

function RoundRobinSimulatorEditingSpec:should_ask_which_way_to_cycle()
  local sut = simulator()
  sut.run( "raid Ann,Bob" )

  assert_says( sut.run_and_capture( "cycle sideways" ), "cycle up" )
end

RoundRobinSimulatorLiveSpec = {}

-- `raid` with no arguments is the one place the simulator and the live queues meet, and even
-- there it is a copy.
function RoundRobinSimulatorLiveSpec:should_copy_the_live_queue_and_append_the_real_group()
  local sut = simulator( { { name = "Zed" } }, { "Psikutas" } )

  assert_says( sut.run_and_capture( "raid" ), "Copied the live Gems queue: Zed, Psikutas." )
end

function RoundRobinSimulatorLiveSpec:should_never_write_back_to_the_live_queue()
  local live = { { name = "Zed" }, { name = "Yan" } }
  local sut = simulator( live, { "Psikutas" } )

  sut.run( "raid" )
  sut.run( "drop 5" )
  sut.run( "add Newcomer" )
  sut.run( "cycle down" )

  eq( live, { { name = "Zed" }, { name = "Yan" } } )
end

function RoundRobinSimulatorLiveSpec:should_say_so_when_there_is_nothing_to_copy()
  assert_says( simulator().run_and_capture( "raid" ), "Nothing to copy" )
end

RoundRobinSimulatorExampleSpec = {}

-- The worked example is the feature's own documentation, so it has to keep telling the truth
-- about what the queue does rather than drifting into a story about it.
function RoundRobinSimulatorExampleSpec:should_replay_the_worked_example()
  local out = simulator().run_and_capture( "example" )

  assert_says( out, "Ann is out of range" )
  assert_says( out, "1. Bob -- passed over Ann, who keeps their place" )
  assert_says( out, "  1. Ann (away)" )
  assert_says( out, "3. Ann" )
end

function RoundRobinSimulatorExampleSpec:should_start_a_fresh_simulation()
  local sut = simulator()
  sut.run( "raid Ann,Bob,Cid,Dee,Eli" )
  sut.run( "drop 6" )

  sut.run( "example" )

  assert_says( sut.run_and_capture( "queue" ), "3 in the queue, 3 drops so far:" )
end

RoundRobinSimulatorResetSpec = {}

function RoundRobinSimulatorResetSpec:should_clear_the_simulation()
  local sut = simulator()
  sut.run( "raid Ann,Bob" )
  sut.run( "drop 3" )

  assert_says( sut.run_and_capture( "reset" ), "Simulation cleared." )
  assert_says( sut.run_and_capture( "drop" ), "No simulated raid yet" )
end

os.exit( lu.LuaUnit.run() )
