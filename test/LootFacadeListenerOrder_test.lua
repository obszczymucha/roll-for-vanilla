package.path = "./?.lua;" .. package.path .. ";../?.lua;../RollFor/?.lua;../RollFor/libs/?.lua"

-- The order core's loot handlers fire in, pinned.
--
-- Every loot event goes through LootFacadeListener, and the order is load-bearing rather
-- than incidental: auto-loot has to have run before anything decides an item is still
-- there, and the roll controller has to see what the ones before it left behind. None of
-- that throws when it is wrong -- it hands the item to the wrong person, or to nobody.
--
-- This suite exists so the registry that replaces the positional argument list can be
-- proved to reproduce exactly this, rather than something that looks about right.

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

-- Every collaborator is the same shape: a table whose methods append their own name to a
-- shared log. What is asserted is the log, so a handler that stops being called is as
-- visible as one that moves.
local function listener()
  local calls = {}

  local function record( name )
    return function() table.insert( calls, name ) end
  end

  local loot_facade = LootFacade.new()
  local listener = LootFacadeListener.new()

  listener.register_core( {
    auto_loot = { on_loot_opened = record( "auto_loot" ) },
    dropped_loot = { on_loot_opened = record( "dropped_loot" ) },
    dropped_loot_announce = { on_loot_opened = record( "dropped_loot_announce" ) },
    master_loot = {
      on_loot_opened = record( "master_loot" ),
      on_loot_slot_cleared = record( "master_loot" ),
      on_loot_received = record( "master_loot.on_loot_received" )
    },
    auto_group_loot = {
      on_loot_opened = record( "auto_group_loot" ),
      on_loot_slot_cleared = record( "auto_group_loot" )
    },
    roll_controller = {
      loot_opened = record( "roll_controller" ),
      loot_closed = record( "roll_controller.loot_closed" )
    },
    player_info = { get_name = function() return "Psikutas" end }
  } )

  listener.start( loot_facade )

  return loot_facade, calls, listener
end

LootOpenedOrderSpec = {}

function LootOpenedOrderSpec:should_fire_cores_six_handlers_in_order()
  -- Given
  local loot_facade, calls = listener()

  -- When
  loot_facade.notify( "LootOpened" )

  -- Then
  eq( calls, {
    "dropped_loot",
    "dropped_loot_announce",
    "auto_loot",
    "master_loot",
    "auto_group_loot",
    "roll_controller"
  } )
end

LootSlotClearedOrderSpec = {}

function LootSlotClearedOrderSpec:should_fire_cores_two_handlers_in_order()
  -- Given
  local loot_facade, calls = listener()

  -- When
  loot_facade.notify( "LootSlotCleared", 3 )

  -- Then
  eq( calls, { "master_loot", "auto_group_loot" } )
end

function LootSlotClearedOrderSpec:should_pass_the_slot_through()
  -- Given
  local loot_facade = LootFacade.new()
  local slots = {}
  local listener = LootFacadeListener.new()

  listener.register_core( {
    auto_loot = { on_loot_opened = function() end },
    dropped_loot = { on_loot_opened = function() end },
    dropped_loot_announce = { on_loot_opened = function() end },
    master_loot = {
      on_loot_opened = function() end,
      on_loot_slot_cleared = function( slot ) table.insert( slots, slot ) end,
      on_loot_received = function() end
    },
    auto_group_loot = { on_loot_opened = function() end, on_loot_slot_cleared = function() end },
    roll_controller = { loot_opened = function() end, loot_closed = function() end },
    player_info = { get_name = function() return "Psikutas" end }
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
  local loot_facade, calls = listener()

  -- When
  loot_facade.notify( "LootClosed" )

  -- Then
  eq( calls, { "roll_controller.loot_closed" } )
end

function SingleHandlerEventSpec:should_fire_master_loot_on_a_loot_message_naming_a_player()
  -- Given
  local loot_facade, calls = listener()

  -- When
  loot_facade.notify( "ChatMsgLoot", "Obszczymucha receives loot: " .. u.item_link( "Hearthstone", 6948 ) )

  -- Then
  eq( calls, { "master_loot.on_loot_received" } )
end

function SingleHandlerEventSpec:should_fire_master_loot_on_a_loot_message_naming_you()
  -- Given
  local loot_facade, calls = listener()

  -- When
  loot_facade.notify( "ChatMsgLoot", "You receive loot: " .. u.item_link( "Hearthstone", 6948 ) )

  -- Then
  eq( calls, { "master_loot.on_loot_received" } )
end

ExtensionHandlerSpec = {}

-- What auto robin's argument position used to say implicitly, said out loud.
function ExtensionHandlerSpec:should_place_an_extension_handler_where_it_anchored()
  -- Given
  local loot_facade = LootFacade.new()
  local calls = {}
  local listener = LootFacadeListener.new()

  local function record( name ) return function() table.insert( calls, name ) end end

  listener.on_loot( "LootOpened",
    { name = "auto_robin", after = "auto_loot", callback = record( "auto_robin" ) } )

  listener.register_core( {
    auto_loot = { on_loot_opened = record( "auto_loot" ) },
    dropped_loot = { on_loot_opened = record( "dropped_loot" ) },
    dropped_loot_announce = { on_loot_opened = record( "dropped_loot_announce" ) },
    master_loot = { on_loot_opened = record( "master_loot" ), on_loot_slot_cleared = function() end,
      on_loot_received = function() end },
    auto_group_loot = { on_loot_opened = record( "auto_group_loot" ), on_loot_slot_cleared = function() end },
    roll_controller = { loot_opened = record( "roll_controller" ), loot_closed = function() end },
    player_info = { get_name = function() return "Psikutas" end }
  } )

  listener.start( loot_facade )

  -- When
  loot_facade.notify( "LootOpened" )

  -- Then
  eq( calls, {
    "dropped_loot",
    "dropped_loot_announce",
    "auto_loot",
    "auto_robin",
    "master_loot",
    "auto_group_loot",
    "roll_controller"
  } )
end

-- Registering before core does is the normal case: extensions declare during
-- Extensions.enable, which runs before core's components exist to be registered.
function ExtensionHandlerSpec:should_not_care_who_registered_first()
  local listener = LootFacadeListener.new()

  listener.on_loot( "LootSlotCleared",
    { name = "auto_robin", after = "auto_group_loot", callback = function() end } )

  listener.register_core( {
    auto_loot = { on_loot_opened = function() end },
    dropped_loot = { on_loot_opened = function() end },
    dropped_loot_announce = { on_loot_opened = function() end },
    master_loot = { on_loot_opened = function() end, on_loot_slot_cleared = function() end,
      on_loot_received = function() end },
    auto_group_loot = { on_loot_opened = function() end, on_loot_slot_cleared = function() end },
    roll_controller = { loot_opened = function() end, loot_closed = function() end },
    player_info = { get_name = function() return "Psikutas" end }
  } )

  eq( listener.order( "LootSlotCleared" ), { "master_loot", "auto_group_loot", "auto_robin" } )
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
    LootFacadeListener.new().on_loot( "LootPlundered", { name = "x", callback = function() end } )
  end, "'LootPlundered' is not a loot event" )
end

function RegistryErrorSpec:should_refuse_a_handler_without_a_callback()
  should_fail_with( function()
    LootFacadeListener.new().on_loot( "LootOpened", { name = "x" } )
  end, "handler 'x' must have a 'callback' function." )
end

function RegistryErrorSpec:should_refuse_a_duplicate_handler_name_for_the_same_event()
  should_fail_with( function()
    local listener = LootFacadeListener.new()
    listener.on_loot( "LootOpened", { name = "x", callback = function() end } )
    listener.on_loot( "LootOpened", { name = "x", callback = function() end } )
  end, "handler 'x' is already registered for LootOpened." )
end

-- The same name on two different events is how core's own master_loot is registered.
function RegistryErrorSpec:should_allow_the_same_name_on_two_events()
  local listener = LootFacadeListener.new()
  listener.on_loot( "LootOpened", { name = "x", callback = function() end } )
  listener.on_loot( "LootSlotCleared", { name = "x", callback = function() end } )

  eq( listener.order( "LootOpened" ), { "x" } )
  eq( listener.order( "LootSlotCleared" ), { "x" } )
end

-- Subscribing has already happened, so a handler arriving now would never be called.
-- Doing nothing silently is the one outcome worth refusing outright.
function RegistryErrorSpec:should_refuse_a_handler_registered_after_the_pipeline_started()
  should_fail_with( function()
    local listener = LootFacadeListener.new()
    listener.start( LootFacade.new() )
    listener.on_loot( "LootOpened", { name = "late", callback = function() end } )
  end, "handler 'late' was registered after the pipeline started." )
end

-- Left out and complained about, exactly as an unplaceable chain link is: a typo in
-- somebody's anchor should not take the rest of the pipeline down with it.
function RegistryErrorSpec:should_drop_a_handler_anchored_to_a_name_that_never_arrived()
  local listener = LootFacadeListener.new()
  local complaints = {}
  local err = RollFor.err
  RollFor.err = function( message ) table.insert( complaints, message ) end

  listener.on_loot( "LootOpened", { name = "mine", after = "nonexistent", callback = function() end } )
  listener.on_loot( "LootOpened", { name = "yours", callback = function() end } )
  listener.start( LootFacade.new() )

  RollFor.err = err

  eq( listener.order( "LootOpened" ), { "yours" } )
  eq( table.getn( complaints ), 1 )
  eq( string.find( complaints[ 1 ],
    "handler 'mine' is anchored after 'nonexistent', which is not in the chain", 1, true ) ~= nil, true )
end

os.exit( lu.LuaUnit.run() )
