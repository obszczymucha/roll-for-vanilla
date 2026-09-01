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
require( "src/AutoRoundRobinQueueFrameContentTransformer" )
local AutoRoundRobinSimulator = require( "src/AutoRoundRobinSimulator" )

u.mock_wow_api()

-- The simulator's whole job is to run the shipped selection algorithm over a roster it invents,
-- so these specs read its chat output. The draw is pinned to the first of the tied candidates
-- (they are sorted by name inside select), which makes every trace line below nameable.

---@param live_db table? -- the live autorobin_db `raid` with no arguments copies
---@param group_names string[]? -- the real group that copy also reads
local function simulator( live_db, group_names )
  local players = {}
  for _, name in ipairs( group_names or {} ) do table.insert( players, { name = name, class = "Warrior" } ) end

  local group_roster = { get_all_players_in_my_group = function() return players end }

  local sut = AutoRoundRobinSimulator.new(
    live_db or { cycle = 1, pool = {} },
    group_roster,
    function() return 1 end )

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

  sut.printed = function() return printed end
  sut.clear_output = function() printed = {} end

  -- Only the lines a spec asked about: run() is chatty by design, and a spec that had to restate
  -- the whole preamble to assert one trace line would be a spec about the preamble.
  sut.run_and_capture = function( args )
    printed = {}
    sut.run( args )

    return printed
  end

  return sut
end

---@param haystack string[]
---@param needle string
local function contains( haystack, needle )
  for _, line in ipairs( haystack ) do
    if string.find( line, needle, 1, true ) then return true end
  end

  return false
end

---@param lines string[]
---@param needle string
local function assert_says( lines, needle )
  if not contains( lines, needle ) then
    error( string.format( "Expected a line containing %q. Got:\n  %s", needle, table.concat( lines, "\n  " ) ), 2 )
  end
end

---@param lines string[]
---@param needle string
local function assert_silent_about( lines, needle )
  if contains( lines, needle ) then
    error( string.format( "Did not expect a line containing %q. Got:\n  %s", needle, table.concat( lines, "\n  " ) ), 2 )
  end
end

RoundRobinSimulatorSpec = {}

function RoundRobinSimulatorSpec:should_print_usage_when_asked_for_nothing()
  local out = simulator().run_and_capture( "" )

  assert_says( out, "/rfrotate" )
  assert_says( out, "raid <names or count>" )
  assert_says( out, "example" )
end

function RoundRobinSimulatorSpec:should_refuse_to_drop_before_a_raid_is_started()
  local out = simulator().run_and_capture( "drop" )

  assert_says( out, "No simulated raid yet" )
end

function RoundRobinSimulatorSpec:should_start_a_raid_from_names()
  local out = simulator().run_and_capture( "raid Ann,Bob,Cid" )

  assert_says( out, "Simulating 3 players: Ann, Bob, Cid." )
  assert_says( out, "Everybody seeded at cycle 1" )
end

function RoundRobinSimulatorSpec:should_start_a_raid_from_a_count()
  local out = simulator().run_and_capture( "raid 4" )

  assert_says( out, "Simulating 4 players: Ann, Bob, Cid, Dee." )
end

function RoundRobinSimulatorSpec:should_refuse_an_impossible_headcount()
  local out = simulator().run_and_capture( "raid 0" )

  assert_says( out, "Pick between" )
end

-- The first drop finds everybody seeded at the current cycle, so it turns the cycle over before
-- serving anyone -- the same thing the real award pass does on the first drop of a fresh pool.
function RoundRobinSimulatorSpec:should_turn_the_cycle_over_on_the_first_drop()
  local sut = simulator()
  sut.run( "raid Ann,Bob,Cid" )

  local out = sut.run_and_capture( "drop" )

  assert_says( out, "1. Ann -- Waiting, drawn from 3 tied; cycle 1 -> 2" )
end

function RoundRobinSimulatorSpec:should_serve_everybody_once_before_starting_over()
  local sut = simulator()
  sut.run( "raid Ann,Bob,Cid" )

  local out = sut.run_and_capture( "drop 4" )

  eq( out, {
    "4 drops among Ann, Bob, Cid:",
    "  1. Ann -- Waiting, drawn from 3 tied; cycle 1 -> 2",
    "  2. Bob -- Waiting, drawn from 2 tied",
    "  3. Cid -- Waiting, only one owed",
    "  4. Ann -- Waiting, drawn from 3 tied; cycle 2 -> 3"
  } )
end

function RoundRobinSimulatorSpec:should_say_when_a_winner_was_not_drawn_for()
  local sut = simulator()
  sut.run( "raid Ann,Bob" )
  sut.run( "drop" )

  local out = sut.run_and_capture( "drop" )

  assert_says( out, "only one owed" )
end

RoundRobinSimulatorAbsenceSpec = {}

-- The subtle half of the design: an absent player's number stops climbing while everybody else's
-- does, so the rotation never stalls on them and they win outright on return.
function RoundRobinSimulatorAbsenceSpec:should_skip_a_player_who_is_out_of_range()
  local sut = simulator()
  sut.run( "raid Ann,Bob,Cid" )
  sut.run( "out Ann" )

  local out = sut.run_and_capture( "drop 2" )

  eq( out[ 1 ], "2 drops among Bob, Cid:" )
  assert_silent_about( out, "Ann --" )
end

function RoundRobinSimulatorAbsenceSpec:should_let_a_returning_player_win_outright()
  local sut = simulator()
  sut.run( "raid Ann,Bob,Cid" )
  sut.run( "out Ann" )
  sut.run( "drop 4" )
  sut.run( "in Ann" )

  local out = sut.run_and_capture( "drop" )

  assert_says( out, "Ann -- Owed (2 cycles), only one owed" )
end

function RoundRobinSimulatorAbsenceSpec:should_report_a_players_place_when_they_go_out_and_come_back()
  local sut = simulator()
  sut.run( "raid Ann,Bob" )

  local out = sut.run_and_capture( "out Ann" )
  assert_says( out, "still in the rotation, just not a candidate" )

  out = sut.run_and_capture( "in Ann" )
  assert_says( out, "Ann can receive again" )
end

function RoundRobinSimulatorAbsenceSpec:should_find_a_player_case_insensitively()
  local sut = simulator()
  sut.run( "raid Ann,Bob" )

  local out = sut.run_and_capture( "out ANN" )

  assert_says( out, "Ann is out of range" )
end

function RoundRobinSimulatorAbsenceSpec:should_say_so_when_the_name_is_not_in_the_group()
  local sut = simulator()
  sut.run( "raid Ann,Bob" )

  local out = sut.run_and_capture( "out Nobody" )

  assert_says( out, "Nobody is not in the simulated group." )
end

-- Everybody out of range is a loot window with no candidates in it, which the real pass skips
-- silently rather than turning the cycle over for nobody.
function RoundRobinSimulatorAbsenceSpec:should_skip_a_drop_with_nobody_eligible()
  local sut = simulator()
  sut.run( "raid Ann,Bob" )
  sut.run( "out Ann" )
  sut.run( "out Bob" )

  local out = sut.run_and_capture( "drop" )

  assert_says( out, "Nobody eligible" )
  assert_says( sut.run_and_capture( "queue" ), "Cycle 1, 0 drops so far:" )
end

RoundRobinSimulatorRosterSpec = {}

function RoundRobinSimulatorRosterSpec:should_put_a_joiner_at_the_bottom_of_the_cycle()
  local sut = simulator()
  sut.run( "raid Ann,Bob" )
  sut.run( "drop" ) -- cycle is now 2, Ann served

  local out = sut.run_and_capture( "join Dee" )
  assert_says( out, "Dee joins during cycle 2" )

  -- Bob is still owed from cycle 1; Dee went in at 2, so she waits for cycle 3.
  assert_says( sut.run_and_capture( "drop" ), "Bob --" )
end

function RoundRobinSimulatorRosterSpec:should_refuse_to_add_somebody_already_in_the_group()
  local sut = simulator()
  sut.run( "raid Ann,Bob" )

  assert_says( sut.run_and_capture( "join Ann" ), "already in the simulated group" )
end

-- The pool is never pruned, which is what lets somebody who left keep their place. The standings
-- say so rather than quietly dropping them.
function RoundRobinSimulatorRosterSpec:should_keep_a_leaver_in_the_pool()
  local sut = simulator()
  sut.run( "raid Ann,Bob" )
  sut.run( "leave Ann" )

  local out = sut.run_and_capture( "queue" )

  assert_says( out, "Still in the pool, not in the group: Ann" )
  assert_silent_about( out, "Ann -- " )
end

function RoundRobinSimulatorRosterSpec:should_list_the_standings_owed_first()
  local sut = simulator()
  sut.run( "raid Ann,Bob,Cid" )
  sut.run( "drop 2" )

  local out = sut.run_and_capture( "queue" )

  eq( out, {
    "Cycle 2, 2 drops so far:",
    "  Cid -- Waiting",
    "  Ann -- Received",
    "  Bob -- Received"
  } )
end

RoundRobinSimulatorLiveSpec = {}

-- `raid` with no arguments is the one place the simulator and the live rotation meet, and even
-- there it is a copy.
function RoundRobinSimulatorLiveSpec:should_copy_the_live_rotation_and_the_real_group()
  local live = { cycle = 3, pool = { Psikutas = 3, Obszczymucha = 1, Ghost = 2 } }
  local sut = simulator( live, { "Psikutas", "Obszczymucha" } )

  local out = sut.run_and_capture( "raid" )
  assert_says( out, "Copied the live rotation: cycle 3, 3 in the pool, 2 in the group." )

  eq( sut.run_and_capture( "queue" ), {
    "Cycle 3, 0 drops so far:",
    "  Obszczymucha -- Owed (2 cycles)",
    "  Psikutas -- Received",
    "  Still in the pool, not in the group: Ghost"
  } )
end

function RoundRobinSimulatorLiveSpec:should_never_write_back_to_the_live_rotation()
  local live = { cycle = 3, pool = { Psikutas = 3, Obszczymucha = 1 } }
  local sut = simulator( live, { "Psikutas", "Obszczymucha" } )

  sut.run( "raid" )
  sut.run( "drop 5" )
  sut.run( "join Newcomer" )

  eq( live, { cycle = 3, pool = { Psikutas = 3, Obszczymucha = 1 } } )
end

function RoundRobinSimulatorLiveSpec:should_say_so_when_there_is_no_group_to_copy()
  local out = simulator( { cycle = 1, pool = {} }, {} ).run_and_capture( "raid" )

  assert_says( out, "Nobody in your group to copy." )
end

RoundRobinSimulatorExampleSpec = {}

-- The worked example is the feature's own documentation, so it has to keep telling the truth
-- about what the algorithm does rather than drifting into a story about it.
function RoundRobinSimulatorExampleSpec:should_replay_the_worked_example()
  local out = simulator().run_and_capture( "example" )

  assert_says( out, "Simulating 4 players: Ann, Bob, Cid, Dee." )
  assert_says( out, "Dee is outside the instance" )
  assert_says( out, "  Dee -- Owed (2 cycles) (out of range)" )
  assert_says( out, "5. Dee -- Owed (2 cycles), only one owed" )
end

function RoundRobinSimulatorExampleSpec:should_start_a_fresh_simulation()
  local sut = simulator()
  sut.run( "raid Ann,Bob,Cid" )
  sut.run( "drop 6" )

  sut.run( "example" )

  -- The example is its own four-player raid, not six drops added to whatever was there.
  assert_says( sut.run_and_capture( "queue" ), "Cycle 3, 5 drops so far:" )
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
