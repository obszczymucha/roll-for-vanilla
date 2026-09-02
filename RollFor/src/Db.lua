RollFor = RollFor or {}
local m = RollFor

if m.Db then return end

local M = {}
local getn = m.getn

-- Reserved on every proxy: reading it hands back the watch accessor instead of a stored value, so
-- no module may keep a field under this name. Guarded in __newindex rather than left to collide
-- silently, because Config writes arbitrary setting names through the same proxy.
local watch_field = "watch"

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

---@param db table
---@return fun( module_name: string ): table
function M.new( db )
  return function( module_name )
    db[ module_name ] = db[ module_name ] or {}

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
