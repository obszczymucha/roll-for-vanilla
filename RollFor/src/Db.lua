RollFor = RollFor or {}
local m = RollFor

if m.Db then return end

local M = {}
local getn = m.getn

-- Reserved on every proxy: reading it hands back the watch accessor instead of a stored value, so
-- no module may keep a field under this name. Guarded in __newindex rather than left to collide
-- silently, because Config writes arbitrary setting names through the same proxy.
local watch_field = "watch"

-- The applied schema version, kept in the module's own store alongside the data it describes.
--
-- Unlike `watch` this needs no guard in __newindex. That one has to be reserved because Config
-- writes setting names invented at runtime through the proxy, so a collision is genuinely
-- reachable; the modules that carry migrations are a hardcoded handful and none of them stores a
-- field by this name. (RollForDb.version, the addon's own version string, is a different table.)
local version_field = "version"

-- A watched field of a module's db.
--
-- The proxy below is transparent by design -- db.foo = value writes straight through -- which is
-- also why it can't see a write any deeper than that: db.queues[ key ] reads the inner table out
-- and then mutates it with nobody watching. Proxying that inner table is not an option, since
-- Lua 5.1's table library, ipairs and # are all raw: they'd bypass the metatable, and
-- table.insert would rawset into the empty proxy shell and drop the write on the floor.
--
-- So the deal is inverted. update() hands you the plain table to mutate with ordinary table
-- functions, and does the notifying once you're done with it. Nothing has to remember to notify,
-- because notifying is how you get the table.
---@class WatchedDbTable
---@field update fun( key: any, fn: fun( value: table ) )
---@field subscribe fun( listener: fun( key: any ) ): fun() -- returns an unsubscribe function

-- What every store is at before it has ever been migrated: the shape the addon shipped with
-- before this file could migrate anything. Never written down -- an absent version reads as this
-- -- so a db that has had no migration run against it carries no version at all and stays exactly
-- as whatever wrote it left it.
local base_version = 1

-- One step of a module's schema history, handed the module's plain store to rewrite in place.
---@alias DbMigration fun( store: table )

-- Brings a module's stored data up to date, one step at a time. Migrations are an array of steps
-- rather than a table keyed by version: the list orders itself, a version can be neither skipped
-- nor claimed twice, and there is no sort to do before it can be walked. The first step takes a
-- store from base_version to base_version + 1, so a module's first ever migration lands it on 2.
---@param store table -- the module's plain store, not the proxy
---@param migrations DbMigration[]?
local function migrate( store, migrations )
  if not migrations then return end

  local latest = base_version + getn( migrations )

  -- Ahead of us means the addon was rolled back. The loop simply doesn't run, which is the point:
  -- the data has already been through steps this build has never heard of, and lowering the
  -- version to match would only arrange for them to be applied a second time on the way back up.
  for version = (store[ version_field ] or base_version) + 1, latest do
    migrations[ version - base_version ]( store )

    -- Recorded step by step rather than once at the end, so a migration that throws doesn't cost
    -- the ones that had already succeeded before it.
    store[ version_field ] = version
  end
end

---@param db table
---@return fun( module_name: string, migrations: DbMigration[]? ): table
function M.new( db )
  ---@param module_name string
  ---@param migrations DbMigration[]? -- the module's schema history, oldest first
  return function( module_name, migrations )
    db[ module_name ] = db[ module_name ] or {}

    migrate( db[ module_name ], migrations )

    local watched = {}

    ---@param field string
    ---@return WatchedDbTable
    local function watch( field )
      if watched[ field ] then return watched[ field ] end

      local listeners = {}

      local function container()
        local store = db[ module_name ]
        store[ field ] = store[ field ] or {}

        return store[ field ]
      end

      ---@param key any
      ---@param fn fun( value: table )
      local function update( key, fn )
        local values = container()
        values[ key ] = values[ key ] or {}

        fn( values[ key ] )

        for _, listener in ipairs( listeners ) do listener( key ) end
      end

      ---@param listener fun( key: any )
      ---@return fun()
      local function subscribe( listener )
        table.insert( listeners, listener )

        return function()
          for i = getn( listeners ), 1, -1 do
            if listeners[ i ] == listener then table.remove( listeners, i ) end
          end
        end
      end

      watched[ field ] = { update = update, subscribe = subscribe }

      return watched[ field ]
    end

    local proxy = {}
    local mt = {
      __index = function( _, key )
        if key == watch_field then return watch end

        return db[ module_name ][ key ]
      end,
      __newindex = function( _, key, value )
        if key == watch_field then
          error( string.format( "'%s' is reserved on a db proxy and can't be stored.", watch_field ), 2 )
        end

        db[ module_name ][ key ] = value
      end
    }

    setmetatable( proxy, mt )
    return proxy
  end
end

m.Db = M
return M
