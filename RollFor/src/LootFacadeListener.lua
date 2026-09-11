RollFor = RollFor or {}
local m = RollFor

if m.LootFacadeListener then return end

local M = {}
local getn = m.getn

-- The loot pipeline, as a phased registry.
--
-- These handlers used to be positional arguments called in a fixed run, which meant an
-- extension could only join the pipeline by being edited into that run. Naming them and
-- letting everyone anchor to each other by name fixed that and introduced a subtler
-- problem: handler *identity* became the schedule *coordinate*. `name` answers "who am I";
-- everybody else's `after` used it to answer "when do I run". A coordinate like that leaves
-- when its owner does, so core ended up declaring positions for handlers it did not own and
-- inserting placeholders to keep them anchorable -- because a missing anchor drops the
-- handlers waiting on it, silently, and that hands items to the wrong person.
--
-- Phases separate the two. Core declares when things run, because core owns the pipeline; a
-- handler's name says only who it is. A phase is not a handler, so it cannot be vacant and
-- nothing falls out of the chain because a name went missing. `after`/`before` survive as
-- sibling ordering *within* a phase, and one naming nobody is vacuously true rather than
-- fatal -- the phase has already pinned the coarse position.
--
-- This file knows no clients, core's included: CoreLootHandlers registers core's own
-- through the same on_loot an extension uses. What is left here is the mechanism and
-- nothing else -- when a handler runs, and what to do with one that cannot be placed.
--
-- Ordering still places the siblings, which is why an extension gets the same vocabulary,
-- failures and error messages it already knows from the soft-res chain.
--
-- Registration happens before the loot facade exists (extensions declare during
-- Extensions.enable, which runs first), so collecting and subscribing are separate:
-- start() resolves the order once and subscribes, exactly like the chain being built.

---@class LootHandler
---@field name string -- who it is; no longer where in the schedule it sits
---@field phase string -- when it runs; see PHASES
---@field after string? -- a sibling, within the same phase
---@field before string?
---@field callback fun( ... )

---@class LootFacadeListener
---@field on_loot fun( event: LootEventName, handler: LootHandler )
---@field start fun( loot_facade: LootFacade )
---@field order fun( event: LootEventName ): string[]

local EVENTS = {
  LootOpened = true,
  LootClosed = true,
  LootSlotCleared = true,
  ChatMsgLoot = true
}

-- When a handler runs, as a coarse position core owns, subdividing each event.
--
-- These are core's because core owns the pipeline, and they are stages rather than
-- components: a phase cannot be vacant, so nothing anchors to a name that might not be
-- installed and nothing falls out of the chain when one is not. That is the whole of what
-- POSITIONS was for and could not do.
--
--   Loot      -- react to the event; change nothing in the corpse.
--   PostLoot  -- the loot event has settled; nothing has been handed out yet.
--   Award     -- hand items out.
--   PostAward -- housekeeping, once awards have landed or been abandoned.
--
-- The names say *when*, not *what*: observe/announce/cleanup were considered and rejected,
-- because a handler that does not announce has no home in a phase called announce, and the
-- next stage anyone needed would be a freshly invented noun whose position you could not
-- derive from its name. PreLoot sorts itself.
--
-- PreAward is deliberately absent: it and PostLoot are the same slot, and shipping both
-- leaves nothing to tell a handler which to pick. PostLoot already is PreAward.
--
-- A phase is per event, not per component. roll_controller is Award on LootOpened -- the
-- fallback that starts a roll for what nobody claimed -- and PostAward on LootClosed, where
-- it is tearing an abandoned award down. Reading a component's phase off one event and
-- assuming it holds on the others is the mistake this table is easiest to get wrong in.
--
-- Room costs nothing: a declared-but-empty phase is harmless, because nothing anchors to a
-- phase's occupant. So a new one is a one-line change here on the day something needs it,
-- not shipped speculatively.
local PHASES = {
  LootOpened = { "Loot", "PostLoot", "Award", "PostAward" },
  LootSlotCleared = { "Loot", "Award", "PostAward" },
  LootClosed = { "PostAward" },
  ChatMsgLoot = { "Loot" }
}

---@param event LootEventName
---@param phase string
---@return boolean
local function runs_phase( event, phase )
  for _, name in ipairs( PHASES[ event ] or {} ) do
    if name == phase then return true end
  end

  return false
end

---@return LootFacadeListener
function M.new()
  local handlers = {}
  local started = false

  local function fail( message )
    error( string.format( "RollFor loot pipeline: %s", message ), 3 )
  end

  ---@param event LootEventName
  ---@param handler LootHandler
  local function on_loot( event, handler )
    if not EVENTS[ event ] then
      fail( string.format( "'%s' is not a loot event. Known: LootOpened, LootClosed, LootSlotCleared, ChatMsgLoot.",
        tostring( event ) ) )
    end

    if type( handler ) ~= "table" then fail( "a handler must be a table." ) end
    if type( handler.name ) ~= "string" or handler.name == "" then
      fail( "a handler must have a non-empty 'name'." )
    end
    if type( handler.callback ) ~= "function" then
      fail( string.format( "handler '%s' must have a 'callback' function.", handler.name ) )
    end

    -- A phase is the only thing that says when a handler runs, so there is no placing one
    -- without it. This is what POSITIONS used to answer for core's own handlers and could not
    -- answer for anybody else's.
    if handler.phase == nil then
      fail( string.format( "handler '%s' must declare a 'phase'. %s runs: %s.",
        handler.name, event, table.concat( PHASES[ event ] or {}, ", " ) ) )
    end

    -- Not every event runs every phase, and a phase the event does not run is a handler that
    -- would never fire. Refused rather than dropped quietly, for the same reason registering
    -- after start() is: silently doing nothing is the one outcome worth refusing outright.
    if not runs_phase( event, handler.phase ) then
      fail( string.format( "'%s' is not a phase of %s. It runs: %s.",
        tostring( handler.phase ), event, table.concat( PHASES[ event ] or {}, ", " ) ) )
    end

    -- Subscribing has already happened, so anything arriving now would never be called.
    -- Silently doing nothing is the one outcome worth refusing outright.
    if started then
      fail( string.format( "handler '%s' was registered after the pipeline started.", handler.name ) )
    end

    handlers[ event ] = handlers[ event ] or {}

    for _, existing in ipairs( handlers[ event ] ) do
      if existing.name == handler.name then
        fail( string.format( "handler '%s' is already registered for %s.", handler.name, event ) )
      end
    end

    table.insert( handlers[ event ], {
      name = handler.name,
      phase = handler.phase,
      after = handler.after,
      before = handler.before,
      callback = handler.callback
    } )
  end

  -- The event's handlers, one group per phase, in the order the phases run.
  --
  -- A phase that nobody registered for is an empty group and nothing else: declaring room is
  -- free, because nothing anchors to a phase's *occupant*. That is the whole of what the
  -- placeholder arithmetic here used to exist for, and why it could be deleted rather than
  -- ported -- a position could be vacant, and a phase cannot.
  ---@param event LootEventName
  ---@return LootHandler[][]
  local function grouped_for( event )
    local by_phase = {}

    for _, handler in ipairs( handlers[ event ] or {} ) do
      by_phase[ handler.phase ] = by_phase[ handler.phase ] or {}
      table.insert( by_phase[ handler.phase ], handler )
    end

    local groups = {}
    for _, phase in ipairs( PHASES[ event ] or {} ) do
      table.insert( groups, by_phase[ phase ] or {} )
    end

    return groups
  end

  ---@param group LootHandler[]
  ---@param name string
  ---@return boolean
  local function names_somebody( group, name )
    for _, handler in ipairs( group ) do
      if handler.name == name then return true end
    end

    return false
  end

  -- Which phase a name is registered in for this event, if any. Only asked about a name a
  -- sibling constraint could not find in its own phase, to tell the two cases apart: nobody
  -- registered it, or somebody did and they are not siblings.
  ---@param event LootEventName
  ---@param name string
  ---@return string?
  local function phase_of( event, name )
    for _, handler in ipairs( handlers[ event ] or {} ) do
      if handler.name == name then return handler.phase end
    end
  end

  -- A sibling constraint naming nobody in this phase is vacuously true, not fatal. The phase
  -- has already pinned the coarse position, so there is nothing left for the constraint to
  -- decide -- and an extension whose neighbour simply is not installed keeps its place
  -- instead of falling out of the pipeline, which is the failure phases exist to end.
  --
  -- A name that *is* registered, in another phase, is a different thing entirely: a phase
  -- mistake wearing a sibling constraint. The constraint cannot hold -- the phases have already
  -- decided which runs first, and they outrank it -- so it is dropped either way, but this one
  -- is somebody's error and gets said out loud rather than passed over.
  --
  -- The handler itself still runs, in the phase it asked for. Dropping a handler over a
  -- misplaced anchor is the exact failure this whole scheme exists to end, and a mistake in
  -- one is no reason to reintroduce it.
  --
  -- Copies rather than clearing the handler, because order() and the subscription both
  -- resolve and neither may change what is registered.
  ---@param event LootEventName
  ---@param group LootHandler[]
  ---@param complain boolean
  ---@return OrderingEntry[]
  local function siblings_only( event, group, complain )
    local result = {}

    ---@param handler LootHandler
    ---@param relation string
    ---@param name string?
    ---@return string?
    local function sibling( handler, relation, name )
      if not name or names_somebody( group, name ) then return name end

      local elsewhere = phase_of( event, name )

      if elsewhere and complain then
        m.err( string.format(
          "RollFor loot pipeline (%s): handler '%s' is %s '%s', which is in phase %s, not %s. Phases decide that; the constraint has been ignored.",
          event, handler.name, relation, name, elsewhere, handler.phase ) )
      end
    end

    for _, handler in ipairs( group ) do
      table.insert( result, {
        name = handler.name,
        after = sibling( handler, "after", handler.after ),
        before = sibling( handler, "before", handler.before ),
        callback = handler.callback
      } )
    end

    return result
  end

  -- Every group placed and concatenated. `complain` is what separates resolving from asking:
  -- start() says out loud what it could not place, order() resolves the same list quietly.
  ---@param event LootEventName
  ---@param complain boolean
  ---@return LootHandler[]
  local function placed_for( event, complain )
    local result = {}

    for _, group in ipairs( grouped_for( event ) ) do
      local placed, unplaceable = m.Ordering.place( siblings_only( event, group, complain ),
        { base = "base", noun = "handler" } )

      for _, handler in ipairs( placed ) do table.insert( result, handler ) end

      if complain then
        for _, rejected in ipairs( unplaceable ) do
          m.err( string.format( "RollFor loot pipeline (%s): %s It has been left out.", event, rejected.reason ) )
        end
      end
    end

    return result
  end

  -- Chain order, for tests and diagnostics. Resolves quietly -- asking is not starting.
  ---@param event LootEventName
  ---@return string[]
  local function order( event )
    local result = {}
    for _, handler in ipairs( placed_for( event, false ) ) do table.insert( result, handler.name ) end
    return result
  end

  ---@param loot_facade LootFacade
  local function start( loot_facade )
    started = true

    for event in pairs( EVENTS ) do
      local placed = placed_for( event, true )

      if getn( placed ) > 0 then
        loot_facade.subscribe( event, function( ... )
          for _, handler in ipairs( placed ) do
            handler.callback( ... )
          end
        end )
      end
    end
  end

  ---@type LootFacadeListener
  return {
    on_loot = on_loot,
    start = start,
    order = order
  }
end

m.LootFacadeListener = M
return M
