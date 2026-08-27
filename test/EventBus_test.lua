---@diagnostic disable: inject-field
package.path = "./?.lua;" .. package.path .. ";../?.lua;../RollFor/?.lua;../RollFor/libs/?.lua"

require( "src/compat" )
local utils = require( "test/utils" )
local lu, eq = utils.luaunit( "assertEquals" )
require( "src/modules" )
local EventBus = require( "src/EventBus" )

NotifySpec = {}

function NotifySpec:should_return_zero_and_not_error_when_nobody_is_subscribed()
  local bus = EventBus.new()

  eq( bus.notify( "nobody_home" ), 0 )
end

function NotifySpec:should_return_the_number_of_callbacks_it_ran()
  local bus = EventBus.new()

  bus.subscribe( "event", function() end )
  bus.subscribe( "event", function() end )
  bus.subscribe( "event", function() end )

  eq( bus.notify( "event" ), 3 )
end

function NotifySpec:should_only_count_callbacks_for_the_notified_event()
  local bus = EventBus.new()

  bus.subscribe( "one", function() end )
  bus.subscribe( "two", function() end )
  bus.subscribe( "two", function() end )

  eq( bus.notify( "one" ), 1 )
  eq( bus.notify( "two" ), 2 )
end

function NotifySpec:should_pass_the_data_through_to_every_callback()
  local bus = EventBus.new()
  local seen = {}

  bus.subscribe( "event", function( data ) table.insert( seen, data ) end )
  bus.subscribe( "event", function( data ) table.insert( seen, data ) end )

  bus.notify( "event", "payload" )

  eq( seen, { "payload", "payload" } )
end

HasSubscribersSpec = {}

function HasSubscribersSpec:should_be_false_for_an_event_nobody_subscribed_to()
  local bus = EventBus.new()

  eq( bus.has_subscribers( "nobody_home" ), false )
end

function HasSubscribersSpec:should_be_true_once_someone_subscribes()
  local bus = EventBus.new()

  bus.subscribe( "event", function() end )

  eq( bus.has_subscribers( "event" ), true )
end

function HasSubscribersSpec:should_not_confuse_one_event_for_another()
  local bus = EventBus.new()

  bus.subscribe( "one", function() end )

  eq( bus.has_subscribers( "two" ), false )
end

os.exit( lu.LuaUnit.run() )
