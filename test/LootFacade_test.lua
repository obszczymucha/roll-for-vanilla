package.path = "./?.lua;" .. package.path .. ";../?.lua;./../RollFor/?.lua;../RollFor/libs/?.lua"

require( "src/bcc/compat" )
local utils = require( "test/utils" )
local lu, eq = utils.luaunit( "assertEquals" )
local m = require( "src/modules" )
local interface = require( "src/Interface" )
local mock = interface.mock
require( "src/DebugBuffer" )
require( "src/Module" )
require( "src/EventFrame" )
require( "src/LootFacade" )
local WowApi = require( "src/WowApi" )
local LootQuality = utils.LootQuality

LootFacadeSpec = {}

local function target( name )
  return function( unit_type )
    return unit_type == "target" and name
  end
end

local function mock_api()
  local registered_event_names = {}
  local on_event_callback

  local frame_api = {
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
      on_event_callback( nil, event_name, _arg1, _arg2 )
    end,
    get_registered_event_names = function() return registered_event_names end
  }

  return frame_api, mock( WowApi.LootInterface )
end

function LootFacadeSpec.should_register_loot_opened_event_with_event_frame()
  -- Given
  local frame_api, loot_api = mock_api()
  local event_frame = m.EventFrame.new( frame_api )
  local facade = m.LootFacade.new( event_frame, loot_api )

  -- When
  facade.subscribe( "LootOpened", function() end )

  -- Then
  local event_names = frame_api.get_registered_event_names()
  eq( event_names[ "LOOT_OPENED" ], true )
end

function LootFacadeSpec.should_register_loot_closed_event_with_event_frame()
  -- Given
  local frame_api, loot_api = mock_api()
  local event_frame = m.EventFrame.new( frame_api )
  local facade = m.LootFacade.new( event_frame, loot_api )

  -- When
  facade.subscribe( "LootClosed", function() end )

  -- Then
  local event_names = frame_api.get_registered_event_names()
  eq( event_names[ "LOOT_CLOSED" ], true )
end

function LootFacadeSpec.should_register_loot_slot_cleared_event_with_event_frame()
  -- Given
  local frame_api, loot_api = mock_api()
  local event_frame = m.EventFrame.new( frame_api )
  local facade = m.LootFacade.new( event_frame, loot_api )

  -- When
  facade.subscribe( "LootSlotCleared", function() end )

  -- Then
  local event_names = frame_api.get_registered_event_names()
  eq( event_names[ "LOOT_SLOT_CLEARED" ], true )
end

function LootFacadeSpec.should_not_blow_up_when_registering_an_unknown_event()
  -- Given
  local frame_api, loot_api = mock_api()
  local event_frame = m.EventFrame.new( frame_api )
  local facade = m.LootFacade.new( event_frame, loot_api )

  -- When
  facade.subscribe( "PlayerEnteringWorld", function() end )
end

function LootFacadeSpec.should_notify_the_loot_opened_subscribers()
  -- Given
  local frame_api, loot_api = mock_api()
  local event_frame = m.EventFrame.new( frame_api )
  local facade = m.LootFacade.new( event_frame, loot_api )
  local notifications = {}

  -- When
  facade.subscribe( "LootOpened", function() notifications[ "LOOT_OPENED" ] = true end )
  frame_api.fire_event( "LOOT_OPENED" )

  -- Then
  eq( notifications[ "LOOT_OPENED" ], true )
  eq( notifications[ "LOOT_CLOSED" ], nil )
  eq( notifications[ "LOOT_SLOT_CLEARED" ], nil )
end

function LootFacadeSpec.should_notify_the_loot_closed_subscribers()
  -- Given
  local frame_api, loot_api = mock_api()
  local event_frame = m.EventFrame.new( frame_api )
  local facade = m.LootFacade.new( event_frame, loot_api )
  local notifications = {}

  -- When
  facade.subscribe( "LootClosed", function() notifications[ "LOOT_CLOSED" ] = true end )
  frame_api.fire_event( "LOOT_CLOSED" )

  -- Then
  eq( notifications[ "LOOT_CLOSED" ], true )
  eq( notifications[ "LOOT_OPENED" ], nil )
  eq( notifications[ "LOOT_SLOT_CLEARED" ], nil )
end

function LootFacadeSpec.should_notify_the_loot_slot_cleared_subscribers()
  -- Given
  local frame_api, loot_api = mock_api()
  local event_frame = m.EventFrame.new( frame_api )
  local facade = m.LootFacade.new( event_frame, loot_api )
  local notifications = {}

  -- When
  facade.subscribe( "LootSlotCleared", function() notifications[ "LOOT_SLOT_CLEARED" ] = true end )
  frame_api.fire_event( "LOOT_SLOT_CLEARED" )

  -- Then
  eq( notifications[ "LOOT_OPENED" ], nil )
  eq( notifications[ "LOOT_CLOSED" ], nil )
  eq( notifications[ "LOOT_SLOT_CLEARED" ], true )
end

function LootFacadeSpec.should_return_item_count()
  -- Given
  local frame_api, loot_api = mock_api()
  local event_frame = m.EventFrame.new( frame_api )
  local facade = m.LootFacade.new( event_frame, loot_api )

  -- When
  loot_api.GetNumLootItems = function() return 69 end

  -- Then
  eq( facade.get_item_count(), 69 )
end

function LootFacadeSpec.should_return_source_guid()
  -- Given
  local frame_api, loot_api = mock_api()
  local event_frame = m.EventFrame.new( frame_api )
  local facade = m.LootFacade.new( event_frame, loot_api )

  -- When
  loot_api.UnitGUID = target( "PrincessKenny" )

  -- Then
  eq( facade.get_source_guid(), "PrincessKenny" )
end

function LootFacadeSpec.should_return_item_link()
  -- Given
  local frame_api, loot_api = mock_api()
  local event_frame = m.EventFrame.new( frame_api )
  local facade = m.LootFacade.new( event_frame, loot_api )

  -- When
  loot_api.GetLootSlotLink = function( slot ) return slot == 1 and "[Darkflame Helm]" or nil end

  -- Then
  eq( facade.get_link( 1 ), "[Darkflame Helm]" )
end

function LootFacadeSpec.should_not_return_item_link_for_a_slot_that_doesnt_exist()
  -- Given
  local frame_api, loot_api = mock_api()
  local event_frame = m.EventFrame.new( frame_api )
  local facade = m.LootFacade.new( event_frame, loot_api )

  -- When
  loot_api.GetLootSlotLink = function( slot ) return slot == 1 and "[Darkflame Helm]" or nil end

  -- Then
  eq( facade.get_link( 2 ), nil )
end

function LootFacadeSpec.should_return_item_info()
  -- Given
  local frame_api, loot_api = mock_api()
  local event_frame = m.EventFrame.new( frame_api )
  local facade = m.LootFacade.new( event_frame, loot_api )

  -- When
  loot_api.GetLootSlotInfo = function( slot )
    if slot ~= 1 then return nil end
    return "texture", "name", 69, nil, LootQuality.Epic
  end
  local result = facade.get_info( 1 )

  -- Then
  eq( result.texture, "texture" )
  eq( result.name, "name" )
  eq( result.quantity, 69 )
  eq( result.quality, LootQuality.Epic )
end

function LootFacadeSpec.should_not_return_item_info_for_a_slot_that_doesnt_exist()
  -- Given
  local frame_api, loot_api = mock_api()
  local event_frame = m.EventFrame.new( frame_api )
  local facade = m.LootFacade.new( event_frame, loot_api )

  -- When
  loot_api.GetLootSlotInfo = function( slot )
    if slot ~= 1 then return nil end
    return "texture", "name", 69, LootQuality.Epic
  end

  -- Then
  eq( facade.get_info( 2 ), nil )
end

function LootFacadeSpec.should_return_whether_a_slot_is_an_item()
  -- Given
  local frame_api, loot_api = mock_api()
  local event_frame = m.EventFrame.new( frame_api )
  local facade = m.LootFacade.new( event_frame, loot_api )
  loot_api.LOOT_SLOT_ITEM = 1
  loot_api.LOOT_SLOT_MONEY = 2

  -- When
  ---@diagnostic disable-next-line: duplicate-set-field
  loot_api.GetLootSlotType = function() return loot_api.LOOT_SLOT_ITEM end

  -- Then
  eq( facade.is_item(), true )

  -- And When
  ---@diagnostic disable-next-line: duplicate-set-field
  loot_api.GetLootSlotType = function() return loot_api.LOOT_SLOT_MONEY end

  -- Then
  eq( facade.is_item(), false )

  -- And When
  ---@diagnostic disable-next-line: duplicate-set-field
  loot_api.GetLootSlotType = function() return nil end

  -- Then
  eq( facade.is_item(), false )
end

function LootFacadeSpec.should_return_whether_a_slot_is_a_coin()
  -- Given
  local frame_api, loot_api = mock_api()
  local event_frame = m.EventFrame.new( frame_api )
  local facade = m.LootFacade.new( event_frame, loot_api )
  loot_api.LOOT_SLOT_ITEM = 1
  loot_api.LOOT_SLOT_MONEY = 2

  -- When
  ---@diagnostic disable-next-line: duplicate-set-field
  loot_api.GetLootSlotType = function() return loot_api.LOOT_SLOT_MONEY end

  -- Then
  eq( facade.is_coin(), true )

  -- And When
  ---@diagnostic disable-next-line: duplicate-set-field
  loot_api.GetLootSlotType = function() return loot_api.LOOT_SLOT_ITEM end

  -- Then
  eq( facade.is_coin(), false )

  -- And When
  ---@diagnostic disable-next-line: duplicate-set-field
  loot_api.LootSlotIsCoin = function() return nil end

  -- Then
  eq( facade.is_coin(), false )
end

os.exit( lu.LuaUnit.run() )
