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

local u = require( "test/utils" )
local lu, eq = u.luaunit( "assertEquals" )
u.mock_wow_api()
require( "src/modules" )
require( "src/Types" )
require( "src/ItemUtils" )
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

  LootFacadeListener.new(
    loot_facade,
    { on_loot_opened = record( "auto_loot" ) },
    { on_loot_opened = record( "dropped_loot" ) },
    { on_loot_opened = record( "dropped_loot_announce" ) },
    {
      on_loot_opened = record( "master_loot" ),
      on_loot_slot_cleared = record( "master_loot" ),
      on_loot_received = record( "master_loot.on_loot_received" )
    },
    {
      on_loot_opened = record( "auto_group_loot" ),
      on_loot_slot_cleared = record( "auto_group_loot" )
    },
    {
      loot_opened = record( "roll_controller" ),
      loot_closed = record( "roll_controller.loot_closed" )
    },
    { get_name = function() return "Psikutas" end }
  )

  return loot_facade, calls
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

  LootFacadeListener.new(
    loot_facade,
    { on_loot_opened = function() end },
    { on_loot_opened = function() end },
    { on_loot_opened = function() end },
    {
      on_loot_opened = function() end,
      on_loot_slot_cleared = function( slot ) table.insert( slots, slot ) end,
      on_loot_received = function() end
    },
    { on_loot_opened = function() end, on_loot_slot_cleared = function() end },
    { loot_opened = function() end, loot_closed = function() end },
    { get_name = function() return "Psikutas" end }
  )

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

os.exit( lu.LuaUnit.run() )
