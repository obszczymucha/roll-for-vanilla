package.path = "./?.lua;" .. package.path .. ";../../?.lua;../../RollFor/?.lua;../../RollFor/libs/?.lua"

require( "src/bcc/compat" )
local utils = require( "test/utils" )
local lu, eq = utils.luaunit( "assertEquals" )
require( "src/modules" )
require( "src/DebugBuffer" )
require( "src/Module" )
local Inspector = require( "src/resistances/Inspector" )

local m_time

local function mock_timer()
  local result = { tick_fn = nil }

  result.ScheduleRepeatingTimer = function( _, f )
    result.tick_fn = f
    return 1
  end

  result.CancelTimer = function()
    result.tick_fn = nil
  end

  result.tick = function( seconds )
    m_time = m_time + (seconds or 0)
    if result.tick_fn then result.tick_fn() end
  end

  result.is_running = function() return result.tick_fn and true or false end

  return result
end

local function mock_event_frame()
  local result = { handlers = {} }

  result.subscribe = function( event, callback )
    result.handlers[ event ] = callback
  end

  result.fire = function( event, arg )
    if result.handlers[ event ] then result.handlers[ event ]( arg ) end
  end

  return result
end

---@param overrides table?
local function mock_api( overrides )
  local api = {
    GetTime = function() return m_time end,
    UnitExists = function() return true end,
    UnitIsPlayer = function() return true end,
    UnitGUID = function( unit ) return "guid-" .. unit end,
    CanInspect = function() return true end
  }

  api.NotifyInspect = function( unit ) api.inspected = unit end
  api.ClearInspectPlayer = function() api.cleared = true end

  for k, v in pairs( overrides or {} ) do
    api[ k ] = v
  end

  return api
end

InspectorSpec = {}

function InspectorSpec:should_complete_a_request_when_inspect_data_is_ready()
  -- Given
  m_time = 100
  local timer, events = mock_timer(), mock_event_frame()
  local api = mock_api()
  local inspector = Inspector.new( api, timer, events )
  local result

  inspector.inspect( "raid1", function( unit, guid, error_type ) result = { unit, guid, error_type } end )

  -- When
  timer.tick() -- sends the request
  events.fire( "INSPECT_READY", "guid-raid1" )
  timer.tick( 0.2 )

  -- Then
  eq( api.inspected, "raid1" )
  eq( result, { "raid1", "guid-raid1" } )
  eq( api.cleared, true )
end

function InspectorSpec:should_retry_three_times_before_giving_up()
  -- Given
  m_time = 100
  local timer = mock_timer()
  local inspector = Inspector.new( mock_api(), timer, mock_event_frame() )
  local error_type
  local retries = {}

  inspector.inspect( "raid1",
    function( _, _, e ) error_type = e end,
    function( unit, retry ) table.insert( retries, { unit, retry } ) end
  )
  timer.tick()

  -- When
  timer.tick( 2.6 ) -- first attempt times out

  -- Then
  eq( retries, { { "raid1", 1 } } )
  eq( error_type, nil )

  -- When
  timer.tick( 1.5 ) -- throttle elapses, sent again
  timer.tick( 2.6 )
  timer.tick( 1.5 )
  timer.tick( 2.6 )

  -- Then
  eq( retries, { { "raid1", 1 }, { "raid1", 2 }, { "raid1", 3 } } )
  eq( error_type, nil )

  -- When
  timer.tick( 1.5 ) -- fourth and final attempt
  timer.tick( 2.6 )

  -- Then
  eq( error_type, "timeout" )
  eq( retries, { { "raid1", 1 }, { "raid1", 2 }, { "raid1", 3 } } )
end

function InspectorSpec:should_complete_a_retried_request_that_arrives_late()
  -- Given
  m_time = 100
  local timer, events = mock_timer(), mock_event_frame()
  local inspector = Inspector.new( mock_api(), timer, events )
  local result

  inspector.inspect( "raid1", function( unit ) result = unit end, function() end )
  timer.tick()
  timer.tick( 2.6 ) -- times out, gets requeued
  timer.tick( 1.5 ) -- sent again

  -- When
  events.fire( "INSPECT_READY", "guid-raid1" )
  timer.tick( 0.2 )

  -- Then
  eq( result, "raid1" )
end

function InspectorSpec:should_throttle_consecutive_requests()
  -- Given
  m_time = 100
  local timer, events = mock_timer(), mock_event_frame()
  local api = mock_api()
  local inspector = Inspector.new( api, timer, events )
  local completed = {}

  local function complete( unit ) table.insert( completed, unit ) end

  inspector.inspect( "raid1", complete )
  inspector.inspect( "raid2", complete )

  -- When
  timer.tick()
  events.fire( "INSPECT_READY", "guid-raid1" )
  timer.tick( 0.2 )
  eq( completed, { "raid1" } )

  timer.tick( 0.2 ) -- still throttled, raid2 not sent yet
  eq( api.inspected, "raid1" )

  timer.tick( 1.5 )
  events.fire( "INSPECT_READY", "guid-raid2" )
  timer.tick( 0.2 )

  -- Then
  eq( api.inspected, "raid2" )
  eq( completed, { "raid1", "raid2" } )
end

function InspectorSpec:should_fail_units_that_cannot_be_inspected()
  -- Given
  m_time = 100
  local timer = mock_timer()
  local api = mock_api( { CanInspect = function() return false end } )
  local inspector = Inspector.new( api, timer, mock_event_frame() )
  local error_type

  inspector.inspect( "raid1", function( _, _, e ) error_type = e end )

  -- When
  timer.tick()

  -- Then
  eq( error_type, "cannot_inspect" )
  eq( api.inspected, nil )
end

function InspectorSpec:should_fail_units_that_do_not_exist()
  -- Given
  m_time = 100
  local timer = mock_timer()
  local inspector = Inspector.new( mock_api( { UnitExists = function() return false end } ), timer, mock_event_frame() )
  local error_type

  inspector.inspect( "raid1", function( _, _, e ) error_type = e end )

  -- When
  timer.tick()

  -- Then
  eq( error_type, "no_unit" )
end

function InspectorSpec:should_stop_ticking_when_the_queue_is_empty()
  -- Given
  m_time = 100
  local timer, events = mock_timer(), mock_event_frame()
  local inspector = Inspector.new( mock_api(), timer, events )

  inspector.inspect( "raid1", function() end )
  timer.tick()
  events.fire( "INSPECT_READY", "guid-raid1" )
  timer.tick( 0.2 )

  -- When
  timer.tick( 1.5 )

  -- Then
  eq( timer.is_running(), false )
end

function InspectorSpec:should_not_clear_inspect_data_while_the_inspect_frame_is_open()
  -- Given
  m_time = 100
  local timer, events = mock_timer(), mock_event_frame()
  local api = mock_api( { InspectFrame = { IsVisible = function() return true end } } )
  local inspector = Inspector.new( api, timer, events )

  inspector.inspect( "raid1", function() end )
  timer.tick()

  -- When
  events.fire( "INSPECT_READY", "guid-raid1" )
  timer.tick( 0.2 )

  -- Then
  eq( api.cleared, nil )
end

os.exit( lu.LuaUnit.run() )
