package.path = "./?.lua;" .. package.path .. ";../?.lua;../RollFor/?.lua;../RollFor/libs/?.lua"

require( "src/compat" )
local u = require( "test/utils" )
local lu, eq = u.luaunit( "assertEquals" )
u.multi_require_src( "DebugBuffer", "Module", "Types" )
require( "src/modules" )
u.mock_wow_api()
require( "src/ItemCatalogue" )
require( "src/AutoRoundRobinDb" )
local AutoRoundRobin = require( "src/AutoRoundRobin" )

-- The selection algorithm on its own: a state table, a list of eligible candidate names, and a
-- draw. No loot window, no roster, no WoW API -- everything the award pass adds on top of this
-- (who is a candidate, paying them, announcing it) is covered in AutoRoundRobinSpec_test.

---@param cycle number
---@param pool table<string, number>?
local function state( cycle, pool )
  return { cycle = cycle, pool = pool or {} }
end

-- Deterministic stand-in for the random draw: takes the nth of the tied candidates, which are
-- sorted by name before the draw so the spec can name who that is.
local function picks( n )
  return function() return n end
end

local first = picks( 1 )

-- The draw is only reached when more than one player sits at the minimum, so a random_fn that
-- refuses to be called proves a selection was forced rather than rolled for.
local function never()
  return function() error( "The draw should not have been reached.", 2 ) end
end

---@param s table
---@param names string[]
---@param random_fn function?
---@return string? -- the winner, already committed
local function award( s, names, random_fn )
  local winner, cycle = AutoRoundRobin.select( s, names, random_fn or first )
  if winner then AutoRoundRobin.commit( s, winner, cycle ) end

  return winner
end

AutoRoundRobinSeedingSpec = {}

function AutoRoundRobinSeedingSpec:should_insert_unknown_players_at_the_current_cycle()
  -- Given
  local s = state( 3 )

  -- When
  AutoRoundRobin.seed( s, { "Psikutas", "Obszczymucha" } )

  -- Then
  eq( s.pool, { Psikutas = 3, Obszczymucha = 3 } )
end

-- Leaving and rejoining keeps your place: the pool is never pruned, so a rejoiner is not an
-- unknown player and nothing about them is rewritten.
function AutoRoundRobinSeedingSpec:should_not_reseed_a_player_who_is_already_in_the_pool()
  -- Given
  local s = state( 4, { Obszczymucha = 1 } )

  -- When
  AutoRoundRobin.seed( s, { "Obszczymucha", "Psikutas" } )

  -- Then
  eq( s.pool, { Obszczymucha = 1, Psikutas = 4 } )
end

-- Marked as already served for the current cycle, a joiner can't receive until it turns over.
function AutoRoundRobinSeedingSpec:should_put_a_player_who_joins_mid_cycle_at_the_bottom()
  -- Given
  local s = state( 2, { Psikutas = 2, Obszczymucha = 1 } )

  -- When
  AutoRoundRobin.seed( s, { "Jogobobek" } )
  local winner = award( s, { "Psikutas", "Obszczymucha", "Jogobobek" } )

  -- Then
  eq( winner, "Obszczymucha" )
end

AutoRoundRobinSelectionSpec = {}

function AutoRoundRobinSelectionSpec:should_draw_from_the_lowest_served_cycle_among_the_candidates()
  -- Given
  local s = state( 3, { Psikutas = 3, Obszczymucha = 1, Jogobobek = 2 } )

  -- When
  local winner = award( s, { "Psikutas", "Obszczymucha", "Jogobobek" }, never() )

  -- Then
  eq( winner, "Obszczymucha" )
  eq( s.pool.Obszczymucha, 3 )
  eq( s.cycle, 3 )
end

function AutoRoundRobinSelectionSpec:should_not_draw_when_only_one_candidate_is_at_the_minimum()
  -- Given
  local s = state( 2, { Psikutas = 2, Obszczymucha = 1 } )

  -- When / Then -- never() errors if the draw is reached at all
  eq( award( s, { "Psikutas", "Obszczymucha" }, never() ), "Obszczymucha" )
end

function AutoRoundRobinSelectionSpec:should_draw_among_everyone_tied_at_the_minimum()
  -- Given
  local s = state( 2, { Jogobobek = 1, Obszczymucha = 1, Psikutas = 2 } )

  -- When / Then -- tied candidates are sorted by name before the draw
  eq( award( s, { "Psikutas", "Obszczymucha", "Jogobobek" }, picks( 2 ) ), "Obszczymucha" )
end

function AutoRoundRobinSelectionSpec:should_advance_the_cycle_exactly_once_when_every_candidate_was_served()
  -- Given
  local s = state( 2, { Psikutas = 2, Obszczymucha = 2, Jogobobek = 2 } )

  -- When
  local winner = award( s, { "Psikutas", "Obszczymucha", "Jogobobek" } )

  -- Then
  eq( s.cycle, 3 )
  eq( winner, "Jogobobek" )
  eq( s.pool, { Psikutas = 2, Obszczymucha = 2, Jogobobek = 3 } )
end

function AutoRoundRobinSelectionSpec:should_serve_everybody_once_before_starting_over()
  -- Given
  local s = state( 1 )
  local candidates = { "Psikutas", "Obszczymucha", "Jogobobek" }
  AutoRoundRobin.seed( s, candidates )

  -- When -- the draw always takes the first name still at the minimum
  local winners = {}
  for _ = 1, 4 do table.insert( winners, award( s, candidates ) ) end

  -- Then -- the fourth award is the start of the next cycle, not a second helping in this one
  eq( winners, { "Jogobobek", "Obszczymucha", "Psikutas", "Jogobobek" } )
  eq( s.cycle, 3 )
end

function AutoRoundRobinSelectionSpec:should_pick_nobody_when_there_are_no_candidates()
  -- Given
  local s = state( 2, { Psikutas = 1 } )

  -- When
  local winner, cycle = AutoRoundRobin.select( s, {}, never() )

  -- Then -- the state is left alone for the next loot window to retry
  eq( winner, nil )
  eq( cycle, 2 )
  eq( s.cycle, 2 )
  eq( s.pool, { Psikutas = 1 } )
end

-- Nothing is written back until the caller has actually paid the winner, so a select() whose
-- GiveMasterLoot never happens leaves the rotation exactly where it was.
function AutoRoundRobinSelectionSpec:should_not_touch_the_state_until_the_award_is_committed()
  -- Given
  local s = state( 2, { Psikutas = 2, Obszczymucha = 2 } )

  -- When
  local winner, cycle = AutoRoundRobin.select( s, { "Psikutas", "Obszczymucha" } , first )

  -- Then
  eq( winner, "Obszczymucha" )
  eq( cycle, 3 )
  eq( s.cycle, 2 )
  eq( s.pool, { Psikutas = 2, Obszczymucha = 2 } )
end

AutoRoundRobinAbsenceSpec = {}

-- The whole point of judging a cycle against the candidates rather than the pool: an absent
-- player's number stops climbing while everybody else's does, so they come back owed.
function AutoRoundRobinAbsenceSpec:should_skip_an_absent_player_and_let_them_win_outright_on_return()
  -- Given
  local s = state( 1 )
  AutoRoundRobin.seed( s, { "Psikutas", "Obszczymucha", "Jogobobek" } )
  local present = { "Psikutas", "Obszczymucha" }

  -- When -- Jogobobek is outside the instance for two full cycles
  for _ = 1, 4 do award( s, present ) end

  -- Then
  eq( s.cycle, 3 )
  eq( s.pool, { Psikutas = 3, Obszczymucha = 3, Jogobobek = 1 } )

  -- When -- and then walks in
  local winner = award( s, { "Psikutas", "Obszczymucha", "Jogobobek" }, never() )

  -- Then -- two cycles behind is two cycles ahead of the queue, so no reset was needed
  eq( winner, "Jogobobek" )
  eq( s.cycle, 3 )
end

-- Judged against the pool, a cycle in which somebody is away would never complete and the
-- rotation would stall on them.
function AutoRoundRobinAbsenceSpec:should_complete_a_cycle_that_a_pool_member_is_absent_for()
  -- Given
  local s = state( 1, { Psikutas = 1, Obszczymucha = 1, Ohhaimark = 1 } )
  local present = { "Psikutas", "Obszczymucha" }

  -- When
  award( s, present )
  award( s, present )
  local winner = award( s, present )

  -- Then -- both present players were served in cycle 2, so the third award opens cycle 3
  eq( s.cycle, 3 )
  eq( winner, "Obszczymucha" )
  eq( s.pool.Ohhaimark, 1 )
end

os.exit( lu.LuaUnit.run() )
