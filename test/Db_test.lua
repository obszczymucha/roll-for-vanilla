---@diagnostic disable: inject-field
package.path = "./?.lua;" .. package.path .. ";../?.lua;../RollFor/?.lua;../RollFor/libs/?.lua"

require( "src/compat" )
local utils = require( "test/utils" )
local lu, eq = utils.luaunit( "assertEquals" )
require( "src/modules" )
local Db = require( "src/Db" )

local function names( queue )
  local result = {}
  for _, player in ipairs( queue ) do table.insert( result, player.name ) end

  return table.concat( result, "," )
end

DbSpec = {}

function DbSpec:should_forward_reads_and_writes_to_the_saved_table()
  local saved = {}
  local db = Db.new( saved )( "module" )

  db.thing = 42

  eq( saved.module.thing, 42 )
  eq( db.thing, 42 )
end

function DbSpec:should_keep_no_keys_of_its_own()
  local saved = {}
  local db = Db.new( saved )( "module" )

  db.thing = 42

  eq( rawget( db, "thing" ), nil )
end

DbWatchSpec = {}

local function watched()
  local saved = {}
  local db = Db.new( saved )( "module" )
  local queues = db.watch( "queues" )

  return db, queues, saved
end

function DbWatchSpec:should_notify_with_the_key_that_was_updated()
  local _, queues = watched()
  local seen = {}
  queues.subscribe( function( key ) table.insert( seen, key ) end )

  queues.update( "Gems", function( q ) table.insert( q, { name = "Jimmy" } ) end )
  queues.update( "Marks", function( q ) table.insert( q, { name = "Ohhaimark" } ) end )

  eq( seen, { "Gems", "Marks" } )
end

function DbWatchSpec:should_hand_out_a_plain_table_the_table_library_can_mutate()
  local db, queues = watched()

  queues.update( "Gems", function( q )
    table.insert( q, { name = "Jimmy" } )
    table.insert( q, { name = "Psikutas" } )
    table.insert( q, 1, { name = "Obszczymucha" } )
    table.remove( q, 2 )
  end )

  eq( names( db.queues[ "Gems" ] ), "Obszczymucha,Psikutas" )
end

function DbWatchSpec:should_write_through_to_the_saved_table()
  local _, queues, saved = watched()

  queues.update( "Gems", function( q ) table.insert( q, { name = "Jimmy" } ) end )

  eq( names( saved.module.queues[ "Gems" ] ), "Jimmy" )
end

function DbWatchSpec:should_notify_once_per_update_however_many_mutations_it_makes()
  local _, queues = watched()
  local count = 0
  queues.subscribe( function() count = count + 1 end )

  queues.update( "Gems", function( q )
    table.insert( q, { name = "Jimmy" } )
    table.insert( q, { name = "Psikutas" } )
    table.remove( q, 1 )
  end )

  eq( count, 1 )
end

function DbWatchSpec:should_notify_every_listener()
  local _, queues = watched()
  local first, second = 0, 0
  queues.subscribe( function() first = first + 1 end )
  queues.subscribe( function() second = second + 1 end )

  queues.update( "Gems", function() end )

  eq( first, 1 )
  eq( second, 1 )
end

function DbWatchSpec:should_stop_notifying_an_unsubscribed_listener()
  local _, queues = watched()
  local count = 0
  local unsubscribe = queues.subscribe( function() count = count + 1 end )

  queues.update( "Gems", function() end )
  unsubscribe()
  queues.update( "Gems", function() end )

  eq( count, 1 )
end

function DbWatchSpec:should_leave_the_other_listeners_alone_when_one_unsubscribes()
  local _, queues = watched()
  local kept = 0
  local unsubscribe = queues.subscribe( function() end )
  queues.subscribe( function() kept = kept + 1 end )

  unsubscribe()
  queues.update( "Gems", function() end )

  eq( kept, 1 )
end

function DbWatchSpec:should_create_the_container_and_the_value_on_first_update()
  local db, queues = watched()

  eq( db.queues, nil )

  queues.update( "Gems", function( q ) eq( q, {} ) end )

  eq( db.queues[ "Gems" ], {} )
end

function DbWatchSpec:should_hand_out_the_same_value_on_every_update()
  local db, queues = watched()

  queues.update( "Gems", function( q ) table.insert( q, { name = "Jimmy" } ) end )
  queues.update( "Gems", function( q ) table.insert( q, { name = "Psikutas" } ) end )

  eq( names( db.queues[ "Gems" ] ), "Jimmy,Psikutas" )
end

function DbWatchSpec:should_return_the_same_watched_table_for_the_same_field()
  local db = Db.new( {} )( "module" )

  eq( db.watch( "queues" ) == db.watch( "queues" ), true )
end

-- Two modules watching the same field name are two different dbs, and neither should hear
-- the other's updates.
function DbWatchSpec:should_keep_watchers_of_different_modules_apart()
  local factory = Db.new( {} )
  local mine = factory( "mine" ).watch( "queues" )
  local theirs = factory( "theirs" ).watch( "queues" )
  local heard = 0
  mine.subscribe( function() heard = heard + 1 end )

  theirs.update( "Gems", function() end )

  eq( heard, 0 )
end

-- The proxy is transparent, so `watch` has to be taken out of the key space rather than
-- left to be shadowed by whatever a module happens to store.
function DbWatchSpec:should_refuse_to_store_a_field_called_watch()
  local db = Db.new( {} )( "module" )

  eq( pcall( function() db.watch = "mine now" end ), false )
end

os.exit( lu.LuaUnit.run() )
