---@diagnostic disable: inject-field
package.path = "./?.lua;" .. package.path .. ";../?.lua;../RollFor/?.lua;../RollFor/libs/?.lua"

-- ctx.db forwards an extension's migrations to core's db(), which is what records the version
-- each store reached.
--
-- This suite exists because of a bug it would have caught. An extension declaring its own
-- migration by hand -- "if there is no version and there is data, drop the data" -- has no way
-- to write that version down, so the condition stays true and the step runs again on every
-- single login. The user's queues were wiped every time they reloaded.

require( "src/compat" )
local utils = require( "test/utils" )
local lu, eq = utils.luaunit( "assertEquals" )

utils.mock_wow_api()
utils.mock_libraries()
utils.load_real_stuff()

local Extensions = RollFor.Extensions

local seen = {}

Extensions.register( {
  name = "migration_probe",
  title = "Migration Probe",
  api_version = Extensions.API_VERSION,
  on_enable = function( ctx )
    seen.db = ctx.db( "store", {
      function( store ) store.queues = nil; seen.first = (seen.first or 0) + 1 end,
      function( store ) store.moved = true; seen.second = (seen.second or 0) + 1 end
    } )
  end
} )

utils.player( "Psikutas" )
local rf = utils.load_roll_for()

MigrationForwardingSpec = {}

function MigrationForwardingSpec:should_run_each_of_the_extensions_migrations_once()
  eq( seen.first, 1 )
  eq( seen.second, 1 )
end

-- The version the store reached, written by core. Without it there is nothing to stop the
-- steps running again, which is the whole bug.
function MigrationForwardingSpec:should_record_the_version_the_store_reached()
  eq( rf.char_db.extension_migration_probe_store.version, 3 )
end

function MigrationForwardingSpec:should_have_applied_what_the_migrations_did()
  eq( seen.db.queues, nil )
  eq( seen.db.moved, true )
end

-- The second login, on the store the first one left behind: nothing runs again.
function MigrationForwardingSpec:should_not_run_them_again_on_a_store_that_is_already_current()
  local store = rf.char_db.extension_migration_probe_store
  store.queues = { Gems = { { name = "Ann", core = true } } }

  local db = RollFor.Db.new( rf.char_db )
  db( "extension_migration_probe_store", {
    function( s ) s.queues = nil end,
    function( s ) s.moved = true end
  } )

  eq( store.queues.Gems[ 1 ].name, "Ann" )
end

os.exit( lu.LuaUnit.run() )
