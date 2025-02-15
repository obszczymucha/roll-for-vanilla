package.path = "./?.lua;" .. package.path .. ";../?.lua;./../RollFor/?.lua;../RollFor/libs/?.lua"

local utils = require( "test/utils" )
local lu, eq = utils.luaunit( "assertEquals" )
local m = require( "src/modules" )
require( "src/DebugBuffer" )
require( "src/Module" )
require( "src/EventFrame" )

EventFrameSpec = {}

local function mock_api()
  local registered_event_names = {}
  local on_event_callback

  return {
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
end

function EventFrameSpec.should_register_events()
  -- Given
  local api = mock_api()
  local event_frame = m.EventFrame.new( api )

  -- When
  event_frame.subscribe( "LOOT_OPENED", function() end )
  event_frame.subscribe( "LOOT_CLOSED", function() end )
  event_frame.subscribe( "LOOT_SLOT_CLEARED", function() end )

  -- Then
  local event_names = api.get_registered_event_names()
  eq( event_names[ "LOOT_OPENED" ], true )
  eq( event_names[ "LOOT_CLOSED" ], true )
  eq( event_names[ "LOOT_SLOT_CLEARED" ], true )
  eq( event_names[ "PLAYER_ENTERING_WORLD" ], nil )
end

function EventFrameSpec.should_notify_the_loot_opened_subscribers()
  -- Given
  local api = mock_api()
  local event_frame = m.EventFrame.new( api )
  local notifications = {}

  -- When
  event_frame.subscribe( "LOOT_OPENED", function() notifications[ "LOOT_OPENED" ] = true end )
  api.fire_event( "LOOT_OPENED" )

  -- Then
  eq( notifications[ "LOOT_OPENED" ], true )
  eq( notifications[ "LOOT_CLOSED" ], nil )
end

os.exit( lu.LuaUnit.run() )
