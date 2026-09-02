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

DbMigrationSpec = {}

-- A store an earlier build wrote. It carries no version, which is what an unmigrated db looks
-- like: base_version is never written down, only reached.
local function unversioned( data )
  return { module = data or { thing = 42 } }
end

function DbMigrationSpec:should_run_a_migration_against_an_unversioned_store()
  local saved = unversioned( { queues = { "stale" } } )

  Db.new( saved )( "module", { function( store ) store.queues = nil end } )

  eq( saved.module.queues, nil )
end

-- The first step lands on 2, which is what makes an absent version mean 1.
function DbMigrationSpec:should_land_the_first_migration_on_version_two()
  local saved = unversioned()

  Db.new( saved )( "module", { function() end } )

  eq( saved.module.version, 2 )
end

function DbMigrationSpec:should_record_the_version_it_reached()
  local saved = unversioned()

  Db.new( saved )( "module", { function() end, function() end } )

  eq( saved.module.version, 3 )
end

function DbMigrationSpec:should_run_migrations_in_order()
  local saved = unversioned()
  local seen = {}

  Db.new( saved )( "module", {
    function() table.insert( seen, "first" ) end,
    function() table.insert( seen, "second" ) end,
    function() table.insert( seen, "third" ) end
  } )

  eq( seen, { "first", "second", "third" } )
end

function DbMigrationSpec:should_run_only_the_migrations_the_store_has_not_seen()
  local saved = unversioned()
  saved.module.version = 2
  local seen = {}

  Db.new( saved )( "module", {
    function() table.insert( seen, "first" ) end,
    function() table.insert( seen, "second" ) end
  } )

  eq( seen, { "second" } )
end

function DbMigrationSpec:should_run_nothing_the_second_time_round()
  local saved = unversioned()
  local count = 0
  local migrations = { function() count = count + 1 end }

  Db.new( saved )( "module", migrations )
  Db.new( saved )( "module", migrations )

  eq( count, 1 )
end

-- The whole point of never writing base_version down: a db nobody has had to migrate is left
-- exactly as it was found.
function DbMigrationSpec:should_store_nothing_for_a_module_with_no_migrations()
  local saved = {}

  Db.new( saved )( "module" )

  eq( saved.module, {} )
end

function DbMigrationSpec:should_store_no_version_on_a_store_it_just_created()
  local saved = {}

  Db.new( saved )( "module" )

  eq( saved.module.version, nil )
end

-- A rolled back addon: the data has been through steps this build has never heard of.
function DbMigrationSpec:should_run_nothing_when_the_store_is_ahead_of_the_migrations()
  local saved = unversioned()
  saved.module.version = 5
  local count = 0

  Db.new( saved )( "module", { function() count = count + 1 end } )

  eq( count, 0 )
end

function DbMigrationSpec:should_leave_a_version_it_is_behind_where_it_is()
  local saved = unversioned()
  saved.module.version = 5

  Db.new( saved )( "module", { function() end } )

  eq( saved.module.version, 5 )
end

function DbMigrationSpec:should_keep_a_migration_that_succeeded_when_a_later_one_throws()
  local saved = unversioned()

  pcall( function()
    Db.new( saved )( "module", {
      function( store ) store.migrated = true end,
      function() error( "boom" ) end
    } )
  end )

  eq( saved.module.migrated, true )
  eq( saved.module.version, 2 )
end

function DbMigrationSpec:should_keep_the_modules_versions_apart()
  local saved = { mine = { thing = 1 }, theirs = { thing = 2 } }
  local factory = Db.new( saved )
  local seen = {}

  factory( "mine", { function() table.insert( seen, "mine" ) end } )
  factory( "theirs", { function() table.insert( seen, "theirs" ) end, function() end } )

  eq( seen, { "mine", "theirs" } )
  eq( saved.mine.version, 2 )
  eq( saved.theirs.version, 3 )
end

-- The version sits in the module's own store, so it is a field the proxy reads back like any other.
function DbMigrationSpec:should_read_the_version_back_through_the_proxy()
  local db = Db.new( unversioned() )( "module", { function() end } )

  eq( db.version, 2 )
end

function DbMigrationSpec:should_hand_the_module_a_working_proxy_over_the_migrated_store()
  local saved = unversioned( { old = "gone" } )

  local db = Db.new( saved )( "module", {
    function( store )
      store.new_name = store.old
      store.old = nil
    end
  } )

  eq( db.new_name, "gone" )
  eq( db.old, nil )
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
