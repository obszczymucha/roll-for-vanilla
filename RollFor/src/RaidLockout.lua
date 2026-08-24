RollFor = RollFor or {}
local m = RollFor

if m.RaidLockout then return end

local M = m.Module.new( "RaidLockout" )

local getn = m.getn

-- Watches the character's raid saves and says when one of them turns over.
--
-- The server hands out a fresh instance id every time you get saved to a raid, so
-- comparing ids against a stored snapshot is what tells a new lockout from the one
-- that's still running. UPDATE_INSTANCE_INFO is when the answer arrives;
-- RequestRaidInfo is how you ask.
--
-- Three things can happen to a save, and only two of them are a lockout change:
--
--   its id changed  -- the old lockout ended and a new one began. A change.
--   it disappeared  -- the lockout expired and nothing replaced it yet. A change,
--                      but only once its reset time has actually passed. See below.
--   it appeared     -- you just got saved to a raid you weren't saved to.
--
-- That last one is deliberately not a change, and the distinction is the whole
-- reason this module compares ids rather than counting saves. Getting saved is what
-- killing the first boss of the night *does* -- treating it as a new lockout would
-- wipe the record of the kill that caused it, every single week.
--
-- A save disappearing is the awkward one, because the client reports no saves at all
-- until the server's answer lands and UPDATE_INSTANCE_INFO fires before then, on login
-- and on zoning. "Expired" and "not answered yet" look identical if all you compare is
-- which keys are present, and reading one as the other wipes the night's kills, rolls
-- and eligibility -- none of which anything puts back. So the reset time each save
-- carries is stored with it: a save that is gone before its deadline was never really
-- gone, only unreported, and it stays on the snapshot until the deadline passes.

---@alias RaidLockouts table<string, number> -- "name|difficulty" -> instance id
---@alias RaidLockoutDeadlines table<string, number> -- "name|difficulty" -> when it resets, in epoch seconds

---@class RaidLockout
---@field refresh fun()
---@field get_lockouts fun(): RaidLockouts
---@field on_update_instance_info fun()
---@field simulate_turnover fun( name: string? )
---@field subscribe fun( listener: fun( changed: string[] ) )

-- Difficulty is part of the identity: the same raid saved at two sizes is two
-- lockouts that turn over independently.
---@param name string
---@param difficulty number?
---@return string
local function key_of( name, difficulty )
  return string.format( "%s|%s", name, tostring( difficulty or 0 ) )
end

---@param db table -- the lockout snapshot, persisted per character
---@param api table
---@param event_frame table
---@return RaidLockout
function M.new( db, api, event_frame )
  -- db is a proxy over the saved table (see Db.lua): it forwards reads and writes
  -- but holds no keys of its own, so pairs() over it comes back empty. The snapshot
  -- has to live one level down to be enumerable, and so it can be replaced in one
  -- write.
  db.lockouts = db.lockouts or {}
  -- Parallel to lockouts rather than folded into it: the ids are what callers read
  -- through get_lockouts, and the deadlines are bookkeeping only this file looks at.
  db.expires_at = db.expires_at or {}

  local m_listeners = {}

  ---@param changed string[]
  local function notify( changed )
    for i = 1, getn( m_listeners ) do
      m_listeners[ i ]( changed )
    end
  end

  ---@param listener fun( changed: string[] )
  local function subscribe( listener )
    table.insert( m_listeners, listener )
  end

  local function get_lockouts()
    return db.lockouts
  end

  -- Raids only. GetNumSavedInstances covers heroic dungeons too, and those turn over
  -- daily -- nothing here is about them, and letting one through would wipe a raid's
  -- kills every morning.
  ---@return RaidLockouts, RaidLockoutDeadlines, table<string, string> -- ids, deadlines and display names, all by key
  local function read_saves()
    local result = {}
    local expires_at = {}
    local names = {}
    local count = api.GetNumSavedInstances()
    local now = m.lua.time()

    for i = 1, count do
      local name, instance_id, reset, difficulty, _, _, _, is_raid = api.GetSavedInstanceInfo( i )

      if name and is_raid then
        local key = key_of( name, difficulty )
        result[ key ] = instance_id or 0
        -- reset is seconds from now, which is only meaningful at the moment it's read.
        expires_at[ key ] = now + (reset or 0)
        names[ key ] = name
      end
    end

    return result, expires_at, names
  end

  -- A vanished save is no longer in `names`, so there is nothing left to name it with
  -- but its key, which carries the raid's name in front of the difficulty.
  ---@param key string
  ---@param names table<string, string>
  ---@return string
  local function display_name( key, names )
    return names[ key ] or string.gsub( key, "|.*$", "" )
  end

  -- Whether a save the client stopped reporting is really gone. Before its own reset
  -- time, its absence is the client not having answered rather than an expiry.
  ---@param key string
  ---@return boolean
  local function has_expired( key )
    return m.lua.time() >= (db.expires_at[ key ] or 0)
  end

  -- What turned over since the last snapshot. An id that changed counts, and so does a
  -- save that vanished once it's past its reset; a save that wasn't there before does
  -- not (see the note at the top of the file). Anything that vanished early is handed
  -- back to be carried forward untouched, so its real turnover is still seen later.
  ---@param current RaidLockouts
  ---@param names table<string, string>
  ---@return string[], RaidLockouts -- what changed, sorted by display name, and what to carry forward
  local function changes( current, names )
    local result = {}
    local carried = {}
    local stored = db.lockouts

    for key, instance_id in pairs( stored ) do
      if current[ key ] == nil then
        if has_expired( key ) then
          table.insert( result, display_name( key, names ) )
        else
          carried[ key ] = instance_id
        end
      elseif current[ key ] ~= instance_id then
        table.insert( result, display_name( key, names ) )
      end
    end

    table.sort( result )

    return result, carried
  end

  ---@param current RaidLockouts
  ---@param expires_at RaidLockoutDeadlines
  ---@param names table<string, string>
  local function apply( current, expires_at, names )
    local changed, carried = changes( current, names )

    -- Always stored, changed or not: a save that only appeared is not a lockout
    -- change, but it still has to be remembered or its turnover would never be seen.
    -- Unreported-but-unexpired saves come along too, deadline included, so a run of
    -- empty reads can't quietly forget them one event at a time.
    for key, instance_id in pairs( carried ) do
      current[ key ] = instance_id
      expires_at[ key ] = db.expires_at[ key ]
    end

    db.lockouts = current
    db.expires_at = expires_at

    if getn( changed ) == 0 then return end

    M.debug.add( string.format( "lockout change: %s", table.concat( changed, ", " ) ) )
    notify( changed )
  end

  local function on_update_instance_info()
    apply( read_saves() )
  end

  -- The answer comes back as UPDATE_INSTANCE_INFO rather than from this call.
  local function refresh()
    api.RequestRaidInfo()
  end

  -- Dev hook, driven by DropSimulator. Plants a save that isn't really there and then
  -- re-reads, so the real diff is what sees it vanish and the real notification is what
  -- goes out. Deliberately not a shortcut to notify(): the diff is the part worth
  -- exercising, and a simulation that skipped it would pass while it was broken.
  --
  -- Works out of an instance and with no raid saves at all, which is where you'd want
  -- to test this from. The planted entry is gone by the time it returns -- the snapshot
  -- is overwritten with what the client actually reports.
  ---@param name string?
  local function simulate_turnover( name )
    local key = key_of( name or "Simulated Raid", 0 )

    -- Any id will do; it only has to be one the client won't report back. The deadline
    -- is planted in the past so the diff reads its disappearance as a real expiry
    -- rather than as an unanswered read.
    db.lockouts[ key ] = -1
    db.expires_at[ key ] = 0

    on_update_instance_info()
  end

  event_frame.subscribe( "UPDATE_INSTANCE_INFO", on_update_instance_info )

  ---@type RaidLockout
  return {
    refresh = refresh,
    get_lockouts = get_lockouts,
    on_update_instance_info = on_update_instance_info,
    simulate_turnover = simulate_turnover,
    subscribe = subscribe
  }
end

m.RaidLockout = M
return M
