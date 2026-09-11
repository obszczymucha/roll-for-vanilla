package.path = "./?.lua;" .. package.path .. ";../?.lua;../RollFor/?.lua;../RollFor/libs/?.lua"

-- The order core's loot handlers fire in, pinned.
--
-- Every loot event goes through LootFacadeListener, and the order is load-bearing rather
-- than incidental: what a policy is taking has to be gone before anything decides an item is
-- still there, and the roll controller has to see what the ones before it left behind. None
-- of that throws when it is wrong -- it hands the item to the wrong person, or to nobody.
--
-- Core's own handlers, through the same on_loot an extension uses. LootPhases_test covers the
-- mechanism; this covers what core actually registers into it.

require( "src/compat" )
local u = require( "test/utils" )
local lu, eq = u.luaunit( "assertEquals" )
u.mock_wow_api()
require( "src/modules" )
require( "src/Types" )
require( "src/ItemUtils" )
require( "src/Ordering" )
local LootFacade = require( "mocks/LootFacade" )
local LootFacadeListener = require( "src/LootFacadeListener" )
local CoreLootHandlers = require( "src/CoreLootHandlers" )

-- Every collaborator is the same shape: a table whose methods append their own name to a
-- shared log. What is asserted is the log, so a handler that stops being called is as
-- visible as one that moves.
local function core_listener()
  local calls = {}

  local function record( name )
    return function() table.insert( calls, name ) end
  end

  local loot_facade = LootFacade.new()
  local listener = LootFacadeListener.new()

  CoreLootHandlers.register( listener, {
    award_policies = { on_loot_opened = record( "award_policies" ), on_loot_slot_cleared = record( "award_policies" ) },
    dropped_loot = { on_loot_opened = record( "dropped_loot" ) },
    dropped_loot_announce = { on_loot_opened = record( "dropped_loot_announce" ) },
    master_loot = {
      on_loot_opened = record( "master_loot" ),
      on_loot_slot_cleared = record( "master_loot" ),
      on_chat_msg_loot = record( "master_loot.on_chat_msg_loot" )
    },
    auto_group_loot = {
      on_loot_opened = record( "auto_group_loot" ),
      on_loot_slot_cleared = record( "auto_group_loot" )
    },
    roll_controller = {
      loot_opened = record( "roll_controller" ),
      loot_closed = record( "roll_controller.loot_closed" )
    }
  } )

  listener.start( loot_facade )

  return loot_facade, calls, listener
end

LootOpenedOrderSpec = {}

-- Core's six, in phase order: Loot, PostLoot, Award, Award, Award, PostAward. Two things to
-- read off it. auto_group_loot moved behind roll_controller when the phases landed, and
-- deliberately -- it is not an award at all, it counts what is left in the corpse so it can hand
-- the raid back to group loot. And award_policies is first in Award: every registered policy
-- gets its turn at every slot before master_loot and roll_controller, which are what an
-- unclaimed item falls through to.
function LootOpenedOrderSpec:should_fire_cores_six_handlers_in_order()
  -- Given
  local loot_facade, calls = core_listener()

  -- When
  loot_facade.notify( "LootOpened" )

  -- Then
  eq( calls, {
    "dropped_loot",
    "dropped_loot_announce",
    "award_policies",
    "master_loot",
    "roll_controller",
    "auto_group_loot"
  } )
end

LootSlotClearedOrderSpec = {}

function LootSlotClearedOrderSpec:should_fire_cores_three_handlers_in_order()
  -- Given
  local loot_facade, calls = core_listener()

  -- When
  loot_facade.notify( "LootSlotCleared", 3 )

  -- Then
  eq( calls, { "award_policies", "master_loot", "auto_group_loot" } )
end

function LootSlotClearedOrderSpec:should_pass_the_slot_through()
  -- Given
  local loot_facade = LootFacade.new()
  local slots = {}
  local listener = LootFacadeListener.new()

  CoreLootHandlers.register( listener, {
    award_policies = { on_loot_opened = function() end, on_loot_slot_cleared = function() end },
    dropped_loot = { on_loot_opened = function() end },
    dropped_loot_announce = { on_loot_opened = function() end },
    master_loot = {
      on_loot_opened = function() end,
      on_loot_slot_cleared = function( slot ) table.insert( slots, slot ) end,
      on_chat_msg_loot = function() end
    },
    auto_group_loot = { on_loot_opened = function() end, on_loot_slot_cleared = function() end },
    roll_controller = { loot_opened = function() end, loot_closed = function() end }
  } )

  listener.start( loot_facade )

  -- When
  loot_facade.notify( "LootSlotCleared", 7 )

  -- Then
  eq( slots, { 7 } )
end

SingleHandlerEventSpec = {}

function SingleHandlerEventSpec:should_fire_the_roll_controller_on_loot_closed()
  -- Given
  local loot_facade, calls = core_listener()

  -- When
  loot_facade.notify( "LootClosed" )

  -- Then
  eq( calls, { "roll_controller.loot_closed" } )
end

function SingleHandlerEventSpec:should_fire_master_loot_on_a_loot_message_naming_a_player()
  -- Given
  local loot_facade, calls = core_listener()

  -- When
  loot_facade.notify( "ChatMsgLoot", "Obszczymucha receives loot: " .. u.item_link( "Hearthstone", 6948 ) )

  -- Then
  eq( calls, { "master_loot.on_chat_msg_loot" } )
end

function SingleHandlerEventSpec:should_fire_master_loot_on_a_loot_message_naming_you()
  -- Given
  local loot_facade, calls = core_listener()

  -- When
  loot_facade.notify( "ChatMsgLoot", "You receive loot: " .. u.item_link( "Hearthstone", 6948 ) )

  -- Then
  eq( calls, { "master_loot.on_chat_msg_loot" } )
end

ExtensionHandlerSpec = {}

-- An extension declares when it runs and nothing about who else is there. Registering before
-- core -- which is what actually happens, since Extensions.enable runs long before core's
-- components exist -- still lands it inside its phase rather than in front of everything.
function ExtensionHandlerSpec:should_place_an_extension_handler_in_its_phase()
  -- Given
  local loot_facade = LootFacade.new()
  local calls = {}
  local listener = LootFacadeListener.new()

  local function record( name ) return function() table.insert( calls, name ) end end

  listener.on_loot( "LootOpened",
    { name = "auto_robin", phase = "Award", callback = record( "auto_robin" ) } )

  CoreLootHandlers.register( listener, {
    award_policies = { on_loot_opened = record( "award_policies" ), on_loot_slot_cleared = record( "award_policies" ) },
    dropped_loot = { on_loot_opened = record( "dropped_loot" ) },
    dropped_loot_announce = { on_loot_opened = record( "dropped_loot_announce" ) },
    master_loot = { on_loot_opened = record( "master_loot" ), on_loot_slot_cleared = function() end,
      on_chat_msg_loot = function() end },
    auto_group_loot = { on_loot_opened = record( "auto_group_loot" ), on_loot_slot_cleared = function() end },
    roll_controller = { loot_opened = record( "roll_controller" ), loot_closed = function() end }
  } )

  listener.start( loot_facade )

  -- When
  loot_facade.notify( "LootOpened" )

  -- Then
  eq( calls, {
    "dropped_loot",
    "dropped_loot_announce",
    "auto_robin",
    "award_policies",
    "master_loot",
    "roll_controller",
    "auto_group_loot"
  } )
end

-- The other way round. A phase is a position in the schedule and not a place in a queue, so
-- who called on_loot first decides nothing across phases.
function ExtensionHandlerSpec:should_not_care_who_registered_first()
  local listener = LootFacadeListener.new()

  listener.on_loot( "LootSlotCleared",
    { name = "auto_robin", phase = "Award", callback = function() end } )

  CoreLootHandlers.register( listener, {
    award_policies = { on_loot_opened = function() end, on_loot_slot_cleared = function() end },
    dropped_loot = { on_loot_opened = function() end },
    dropped_loot_announce = { on_loot_opened = function() end },
    master_loot = { on_loot_opened = function() end, on_loot_slot_cleared = function() end,
      on_chat_msg_loot = function() end },
    auto_group_loot = { on_loot_opened = function() end, on_loot_slot_cleared = function() end },
    roll_controller = { loot_opened = function() end, loot_closed = function() end }
  } )

  eq( listener.order( "LootSlotCleared" ), { "auto_robin", "award_policies", "master_loot", "auto_group_loot" } )
end

RegistryErrorSpec = {}

---@param fn fun()
---@param expected string
local function should_fail_with( fn, expected )
  local ok, err = pcall( fn )
  eq( ok, false )
  eq( string.find( tostring( err ), expected, 1, true ) ~= nil, true, string.format(
    "Expected the error to mention %q, got: %s", expected, tostring( err ) ) )
end

function RegistryErrorSpec:should_refuse_an_unknown_event()
  should_fail_with( function()
    ---@diagnostic disable-next-line: param-type-mismatch
    LootFacadeListener.new().on_loot( "LootPlundered", { name = "x", callback = function() end } )
  end, "'LootPlundered' is not a loot event" )
end

function RegistryErrorSpec:should_refuse_a_handler_without_a_callback()
  should_fail_with( function()
    ---@diagnostic disable-next-line: missing-fields
    LootFacadeListener.new().on_loot( "LootOpened", { name = "x" } )
  end, "handler 'x' must have a 'callback' function." )
end

function RegistryErrorSpec:should_refuse_a_duplicate_handler_name_for_the_same_event()
  should_fail_with( function()
    local listener = LootFacadeListener.new()
    listener.on_loot( "LootOpened", { name = "x", phase = "Loot", callback = function() end } )
    listener.on_loot( "LootOpened", { name = "x", phase = "Loot", callback = function() end } )
  end, "handler 'x' is already registered for LootOpened." )
end

-- The same name on two different events is how core's own master_loot is registered -- and in
-- two different phases, because a phase is per event, not per component.
function RegistryErrorSpec:should_allow_the_same_name_on_two_events()
  local listener = LootFacadeListener.new()
  listener.on_loot( "LootOpened", { name = "x", phase = "Loot", callback = function() end } )
  listener.on_loot( "LootSlotCleared", { name = "x", phase = "PostAward", callback = function() end } )

  eq( listener.order( "LootOpened" ), { "x" } )
  eq( listener.order( "LootSlotCleared" ), { "x" } )
end

-- Subscribing has already happened, so a handler arriving now would never be called.
-- Doing nothing silently is the one outcome worth refusing outright.
function RegistryErrorSpec:should_refuse_a_handler_registered_after_the_pipeline_started()
  should_fail_with( function()
    local listener = LootFacadeListener.new()
    listener.start( LootFacade.new() )
    listener.on_loot( "LootOpened", { name = "late", phase = "Loot", callback = function() end } )
  end, "handler 'late' was registered after the pipeline started." )
end

-- A handler is placed by its phase, so there is nothing left for a name to be required for.
-- An anchor naming somebody who never arrived is vacuously true and the handler keeps its
-- place -- which is the whole point: an extension's neighbour not being installed is normal,
-- and used to take that extension out of the pipeline silently.
function RegistryErrorSpec:should_keep_a_handler_whose_anchor_never_arrived()
  local listener = LootFacadeListener.new()
  local complaints = {}
  local err = RollFor.err
  ---@diagnostic disable-next-line: duplicate-set-field
  RollFor.err = function( message ) table.insert( complaints, message ) end

  listener.on_loot( "LootOpened",
    { name = "mine", phase = "Loot", after = "nonexistent", callback = function() end } )
  listener.on_loot( "LootOpened", { name = "yours", phase = "Loot", callback = function() end } )
  listener.start( LootFacade.new() )

  RollFor.err = err

  eq( listener.order( "LootOpened" ), { "mine", "yours" } )
  eq( complaints, {} )
end

-- A name that *is* registered, in another phase, is a different thing: not somebody's absent
-- addon but somebody's mistake, and the phases have already decided the order it was trying
-- to state. Said out loud, and the handler still runs where its phase puts it.
function RegistryErrorSpec:should_complain_about_an_anchor_naming_another_phase()
  local listener = LootFacadeListener.new()
  local complaints = {}
  local err = RollFor.err
  ---@diagnostic disable-next-line: duplicate-set-field
  RollFor.err = function( message ) table.insert( complaints, message ) end

  listener.on_loot( "LootOpened",
    { name = "mine", phase = "Loot", after = "theirs", callback = function() end } )
  listener.on_loot( "LootOpened", { name = "theirs", phase = "Award", callback = function() end } )
  listener.start( LootFacade.new() )

  RollFor.err = err

  eq( listener.order( "LootOpened" ), { "mine", "theirs" } )
  eq( table.getn( complaints ), 1 )
  eq( string.find( complaints[ 1 ],
    "handler 'mine' is after 'theirs', which is in phase Award, not Loot", 1, true ) ~= nil, true )
end

-- A phase is the only thing that says when a handler runs, so a handler without one cannot
-- be placed at all.
function RegistryErrorSpec:should_refuse_a_handler_without_a_phase()
  should_fail_with( function()
    ---@diagnostic disable-next-line: missing-fields
    LootFacadeListener.new().on_loot( "LootOpened", { name = "x", callback = function() end } )
  end, "handler 'x' must declare a 'phase'." )
end

os.exit( lu.LuaUnit.run() )
