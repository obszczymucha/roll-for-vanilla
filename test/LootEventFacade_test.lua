package.path = "./?.lua;" .. package.path .. ";../?.lua;./../RollFor/?.lua;../RollFor/libs/?.lua"

local utils = require( "test/utils" )
local lu, eq = utils.luaunit( "assertEquals" )
local m = require( "src/modules" )
require( "src/api/EventFrame" )
require( "src/api/LootEventFacade" )

LootEventFacadeSpec = {}

local function mock_api( item_count, target_name )
  local registered_event_names = {}
  local on_event_callback

  return {
    GetNumLootItems = function() return item_count end,
    UnitName = function( unit_type )
      return unit_type == "target" and target_name
    end,
    CreateFrame = function()
      return {
        RegisterEvent = function( _, event_name )
          registered_event_names[ event_name ] = true
        end,
        SetScript = function( _, event_name, callback )
          if event_name ~= "OnEvent" then return end
          on_event_callback = callback
        end
      }
    end,
    fire_event = function( event_name, _arg1, _arg2 )
      if not on_event_callback then return end
      ---@diagnostic disable-next-line: lowercase-global
      event = event_name
      ---@diagnostic disable-next-line: lowercase-global
      arg1 = _arg1
      ---@diagnostic disable-next-line: lowercase-global
      arg2 = _arg2
      on_event_callback()
    end,
    get_registered_event_names = function() return registered_event_names end
  }
end

function LootEventFacadeSpec.should_register_loot_opened_event_with_event_frame()
  -- Given
  local api = mock_api()
  local event_frame = m.EventFrame.new( api )
  local facade = m.LootEventFacade.new( event_frame, api )

  -- When
  facade.subscribe( "LootOpened", function() end )

  -- Then
  local event_names = api.get_registered_event_names()
  eq( event_names[ "LOOT_OPENED" ], true )
end

function LootEventFacadeSpec.should_register_loot_closed_event_with_event_frame()
  -- Given
  local api = mock_api()
  local event_frame = m.EventFrame.new( api )
  local facade = m.LootEventFacade.new( event_frame, api )

  -- When
  facade.subscribe( "LootClosed", function() end )

  -- Then
  local event_names = api.get_registered_event_names()
  eq( event_names[ "LOOT_CLOSED" ], true )
end

function LootEventFacadeSpec.should_register_loot_slot_cleared_event_with_event_frame()
  -- Given
  local api = mock_api()
  local event_frame = m.EventFrame.new( api )
  local facade = m.LootEventFacade.new( event_frame, api )

  -- When
  facade.subscribe( "LootSlotCleared", function() end )

  -- Then
  local event_names = api.get_registered_event_names()
  eq( event_names[ "LOOT_SLOT_CLEARED" ], true )
end

function LootEventFacadeSpec.should_not_blow_up_when_registering_an_unknown_event()
  -- Given
  local api = mock_api()
  local event_frame = m.EventFrame.new( api )
  local facade = m.LootEventFacade.new( event_frame, api )

  -- When
  facade.subscribe( "PlayerEnteringWorld", function() end )
end

function LootEventFacadeSpec.should_notify_the_loot_opened_subscribers()
  -- Given
  local api = mock_api()
  local event_frame = m.EventFrame.new( api )
  local facade = m.LootEventFacade.new( event_frame, api )
  local notifications = {}

  -- When
  facade.subscribe( "LootOpened", function() notifications[ "LOOT_OPENED" ] = true end )
  api.fire_event( "LOOT_OPENED" )

  -- Then
  eq( notifications[ "LOOT_OPENED" ], true )
  eq( notifications[ "LOOT_CLOSED" ], nil )
  eq( notifications[ "LOOT_SLOT_CLEARED" ], nil )
end

function LootEventFacadeSpec.should_notify_the_loot_closed_subscribers()
  -- Given
  local api = mock_api()
  local event_frame = m.EventFrame.new( api )
  local facade = m.LootEventFacade.new( event_frame, api )
  local notifications = {}

  -- When
  facade.subscribe( "LootClosed", function() notifications[ "LOOT_CLOSED" ] = true end )
  api.fire_event( "LOOT_CLOSED" )

  -- Then
  eq( notifications[ "LOOT_CLOSED" ], true )
  eq( notifications[ "LOOT_OPENED" ], nil )
  eq( notifications[ "LOOT_SLOT_CLEARED" ], nil )
end

function LootEventFacadeSpec.should_notify_the_loot_slot_cleared_subscribers()
  -- Given
  local api = mock_api()
  local event_frame = m.EventFrame.new( api )
  local facade = m.LootEventFacade.new( event_frame, api )
  local notifications = {}

  -- When
  facade.subscribe( "LootSlotCleared", function() notifications[ "LOOT_SLOT_CLEARED" ] = true end )
  api.fire_event( "LOOT_SLOT_CLEARED" )

  -- Then
  eq( notifications[ "LOOT_OPENED" ], nil )
  eq( notifications[ "LOOT_CLOSED" ], nil )
  eq( notifications[ "LOOT_SLOT_CLEARED" ], true )
end

function LootEventFacadeSpec.should_return_item_count()
  -- Given
  local api = mock_api( 69 )
  local event_frame = m.EventFrame.new( api )
  local facade = m.LootEventFacade.new( event_frame, api )

  -- When
  local result = facade.get_item_count()

  -- Then
  eq( result, 69 )
end

function LootEventFacadeSpec.should_return_source_guid()
  -- Given
  local api = mock_api( 69, "PrincessKenny" )
  local event_frame = m.EventFrame.new( api )
  local facade = m.LootEventFacade.new( event_frame, api )

  -- When
  local result = facade.get_source_guid()

  -- Then
  eq( result, "PrincessKenny" )
end

os.exit( lu.LuaUnit.run() )
