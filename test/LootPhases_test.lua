package.path = "./?.lua;" .. package.path .. ";../?.lua;../RollFor/?.lua;../RollFor/libs/?.lua"

-- Phases: when a handler runs, decided by core, who owns the pipeline.
--
-- The thing this replaces is handler identity doubling as a schedule coordinate -- `name`
-- answering "who am I" while everyone else's `after` used it to answer "when do I run".
-- A coordinate like that leaves with its owner, which is why core ended up holding a
-- position called `auto_loot` open for an extension that might not be installed.
--
-- A phase is not a handler. It cannot be vacant, so nothing falls out of the chain because
-- a name went missing, and an unsatisfied sibling constraint inside one is vacuously true
-- rather than fatal: the phase has already pinned the coarse position.

require( "src/compat" )
local u = require( "test/utils" )
local lu, eq = u.luaunit( "assertEquals" )
u.mock_wow_api()
require( "src/modules" )
require( "src/Types" )
require( "src/Ordering" )
local LootFacadeListener = require( "src/LootFacadeListener" )

---@param listener LootFacadeListener
---@param event LootEventName
---@param handlers table[]
local function register_all( listener, event, handlers )
  for _, handler in ipairs( handlers ) do
    handler.callback = handler.callback or function() end
    listener.on_loot( event, handler )
  end
end

---@param fn fun()
---@param expected string
local function should_fail_with( fn, expected )
  local ok, err = pcall( fn )
  eq( ok, false )
  eq( string.find( tostring( err ), expected, 1, true ) ~= nil, true, string.format(
    "Expected the error to mention %q, got: %s", expected, tostring( err ) ) )
end

---@param fn fun()
---@return string[]
local function complaints_from( fn )
  local complaints = {}
  local err = RollFor.err
  ---@diagnostic disable-next-line: duplicate-set-field
  RollFor.err = function( message ) table.insert( complaints, message ) end
  fn()
  RollFor.err = err
  return complaints
end

PhaseOrderSpec = {}

-- Registration order is addon load order, which is alphabetical by folder name. Nothing
-- about when a phase runs may depend on it.
function PhaseOrderSpec:should_place_handlers_in_phase_order_whatever_order_they_arrived_in()
  -- Given
  local listener = LootFacadeListener.new()

  register_all( listener, "LootOpened", {
    { name = "housekeeping", phase = "PostAward" },
    { name = "sweeper", phase = "Award" },
    { name = "observer", phase = "Loot" },
    { name = "announcer", phase = "PostLoot" }
  } )

  -- Then
  eq( listener.order( "LootOpened" ), { "observer", "announcer", "sweeper", "housekeeping" } )
end

-- Within one phase, the vocabulary is the one the soft-res chain already uses.
function PhaseOrderSpec:should_order_siblings_within_a_phase()
  -- Given
  local listener = LootFacadeListener.new()

  register_all( listener, "LootOpened", {
    { name = "second", phase = "Loot", after = "first" },
    { name = "first", phase = "Loot" },
    { name = "third", phase = "Award" }
  } )

  -- Then
  eq( listener.order( "LootOpened" ), { "first", "second", "third" } )
end

-- A sibling anchor cannot drag a handler out of its phase: the phase is the coarse
-- position and `after` only sorts what is already there.
function PhaseOrderSpec:should_keep_a_handler_in_its_phase_when_it_anchors_across_one()
  -- Given
  local listener = LootFacadeListener.new()

  register_all( listener, "LootOpened", {
    { name = "sweeper", phase = "Award" },
    { name = "observer", phase = "Loot", after = "sweeper" }
  } )

  -- Then
  eq( listener.order( "LootOpened" ), { "observer", "sweeper" } )
end

-- Not every event runs every phase. LootClosed is housekeeping and nothing else.
function PhaseOrderSpec:should_refuse_a_phase_the_event_does_not_run()
  should_fail_with( function()
    LootFacadeListener.new().on_loot( "LootClosed",
      { name = "mine", phase = "Award", callback = function() end } )
  end, "'Award' is not a phase of LootClosed" )
end

function PhaseOrderSpec:should_refuse_an_unknown_phase()
  should_fail_with( function()
    LootFacadeListener.new().on_loot( "LootOpened",
      { name = "mine", phase = "Cleanup", callback = function() end } )
  end, "'Cleanup' is not a phase of LootOpened" )
end

VacuousConstraintSpec = {}

-- The whole point of phases. `before = "master_loot"` with no master_loot registered means
-- "no constraint", because the phase already says where this runs -- so an extension whose
-- neighbour is not installed keeps its place instead of falling out of the pipeline.
function VacuousConstraintSpec:should_ignore_a_sibling_constraint_naming_nobody()
  -- Given
  local listener = LootFacadeListener.new()

  register_all( listener, "LootOpened", {
    { name = "mine", phase = "Loot", before = "somebody_elses" },
    { name = "yours", phase = "Loot" }
  } )

  -- Then
  eq( listener.order( "LootOpened" ), { "mine", "yours" } )
end

function VacuousConstraintSpec:should_not_complain_about_a_sibling_constraint_naming_nobody()
  -- Given
  local listener = LootFacadeListener.new()

  register_all( listener, "LootOpened", {
    { name = "mine", phase = "Loot", after = "never_installed" }
  } )

  -- When
  local complaints = complaints_from( function() listener.start( require( "mocks/LootFacade" ).new() ) end )

  -- Then
  eq( complaints, {} )
end

-- A name that *is* registered, in the same phase, still has to make sense. This one is
-- nobody's missing addon; it is two constraints that cannot both hold.
function VacuousConstraintSpec:should_still_report_a_contradiction_within_a_phase()
  -- Given
  local listener = LootFacadeListener.new()

  register_all( listener, "LootOpened", {
    { name = "first", phase = "Loot" },
    { name = "second", phase = "Loot", after = "first" },
    { name = "impossible", phase = "Loot", after = "second", before = "first" }
  } )

  -- When
  local complaints = complaints_from( function() listener.start( require( "mocks/LootFacade" ).new() ) end )

  -- Then
  eq( listener.order( "LootOpened" ), { "first", "second" } )
  eq( table.getn( complaints ), 1 )
  eq( string.find( complaints[ 1 ],
    "handler 'impossible' cannot be both after 'second' and before 'first'", 1, true ) ~= nil, true )
end

os.exit( lu.LuaUnit.run() )
