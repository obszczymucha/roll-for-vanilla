RollFor = RollFor or {}
local m = RollFor

if m.ResistanceBonusRollRegistry then return end

local M = m.Module.new( "ResistanceBonusRollRegistry" )

local getn = m.getn
local hl = m.colors.hl

-- Who has earned a bonus roll, and for what. One roll per eligible player per kill of
-- one of the bosses below.
--
-- The names are the catalogue's, verbatim, because they're what BossKilled reports --
-- "The Illidari Council" and not "Illidari Council". Retyping one of these from memory
-- is the way this module silently stops granting anything, so they're checked against
-- AutoLootDb by its test rather than trusted.
local granting_bosses = {
  [ "Mother Shahraz" ] = true,
  [ "The Illidari Council" ] = true,
  [ "Illidan Stormrage" ] = true
}

M.granting_bosses = granting_bosses

-- Rolls are kept one entry per roll rather than as a count. A count answers "how many"
-- and nothing else; the entries also answer which boss paid for it and when, which is
-- what makes a disputed roll checkable after the fact.
---@class BonusRollEntry
---@field boss_name string
---@field class PlayerClass? -- the player's class as of this grant, for display -- stored
---                             per entry rather than looked up live, so a player who has
---                             since left the group still colors correctly
---@field timestamp number -- when the boss died, not when the row was written

---@class BonusRollRegistryRow
---@field player_name string
---@field class PlayerClass?
---@field count number
---@field entries BonusRollEntry[]

---@class ResistanceBonusRollRegistry
---@field grant fun( player_name: string, boss_name: string, class: PlayerClass?, timestamp: number? )
---@field get fun( player_name: string ): BonusRollEntry[]
---@field count fun( player_name: string ): number
---@field count_all fun(): number
---@field get_rows fun(): BonusRollRegistryRow[]
---@field list fun()
---@field reset fun()
---@field subscribe fun( listener: fun() )

---@param db table -- bonus rolls by player name, persisted
---@param boss_killed BossKilled
---@param eligibility ResistanceBonusRollEligibility
---@return ResistanceBonusRollRegistry
function M.new( db, boss_killed, eligibility )
  -- db is a proxy over the saved table (see Db.lua): it forwards reads and writes but
  -- holds no keys of its own, so pairs() over it comes back empty. The map has to live
  -- one level down to be enumerable, and so reset can drop the whole thing in one write.
  db.players = db.players or {}

  local m_listeners = {}

  local function notify()
    for i = 1, getn( m_listeners ) do
      m_listeners[ i ]()
    end
  end

  ---@param listener fun()
  local function subscribe( listener )
    table.insert( m_listeners, listener )
  end

  ---@param player_name string
  ---@return BonusRollEntry[]
  local function get( player_name )
    return db.players[ player_name ] or {}
  end

  ---@param player_name string
  ---@return number
  local function count( player_name )
    return getn( get( player_name ) )
  end

  -- Deliberately not deduplicated by boss: BossKilled reports each boss once, which is
  -- what makes this once per kill, and a grant asked for by hand is asked for on purpose.
  --
  -- Silent on both notify and chat, because it's shared between one player granted by
  -- hand and a whole raid paid out by a kill, and those two want saying very differently.
  -- Each caller announces in its own words and notifies once when it's done, rather than
  -- redrawing a listening frame and printing a line per player.
  ---@param player_name string
  ---@param boss_name string
  ---@param class PlayerClass?
  ---@param timestamp number?
  ---@return number -- how many rolls that player now has
  local function write( player_name, boss_name, class, timestamp )
    local entries = db.players[ player_name ] or {}
    table.insert( entries, { boss_name = boss_name, class = class, timestamp = timestamp or m.lua.time() } )
    db.players[ player_name ] = entries

    M.debug.add( string.format( "%s: %s (%s)", player_name, boss_name, getn( entries ) ) )

    return getn( entries )
  end

  -- One player, asked for on purpose, so it's named and its running total given.
  ---@param player_name string
  ---@param boss_name string
  ---@param class PlayerClass?
  ---@param timestamp number?
  local function grant( player_name, boss_name, class, timestamp )
    local total = write( player_name, boss_name, class, timestamp )

    m.info( string.format( "%s granted to %s (%s total).",
      hl( "Bonus Roll" ), m.colorize_player_by_class( player_name, class ), hl( total ) ) )
    notify()
  end

  -- Across the whole db rather than the current roster, the same way eligibility's
  -- count_eligible does: reset drops all of it, and a caller summarising what was lost
  -- would understate it by counting only whoever happens to be standing here.
  ---@return number
  local function count_all()
    local result = 0

    for _, entries in pairs( db.players ) do
      result = result + getn( entries )
    end

    return result
  end

  -- Most rolls first -- the list is read to answer who is owed what -- then by name.
  ---@param lhs BonusRollRegistryRow
  ---@param rhs BonusRollRegistryRow
  local function by_count_descending( lhs, rhs )
    if lhs.count ~= rhs.count then return lhs.count > rhs.count end

    return lhs.player_name < rhs.player_name
  end

  -- Everyone the db holds, not just the current roster: a roll is earned, so leaving the
  -- group doesn't spend it, and the count that pays for a lockout-wipe summary has to
  -- include it too. Callers that only want to *display* current members -- the GUI --
  -- filter this against the roster themselves.
  ---@return BonusRollRegistryRow[]
  local function get_rows()
    local result = {}

    for player_name, entries in pairs( db.players ) do
      local last = entries[ getn( entries ) ]

      if last then
        table.insert( result, { player_name = player_name, class = last.class, count = getn( entries ), entries = entries } )
      end
    end

    table.sort( result, by_count_descending )

    return result
  end

  local function list()
    local rows = get_rows()

    if getn( rows ) == 0 then
      m.info( "No bonus rolls granted yet." )
      return
    end

    m.info( "Bonus rolls:" )

    for i = 1, getn( rows ) do
      local row = rows[ i ]
      m.info( string.format( "  %s: %s", row.player_name, hl( row.count ) ) )
    end
  end

  local function reset()
    db.players = {}
    M.debug.add( "reset" )
    notify()
  end

  -- One timestamp for the whole kill, so every roll it paid for carries the same one --
  -- they were earned by the same event, and reading them back should say so. Uses write()
  -- rather than grant() so a kill that pays out to a whole raid redraws a listening frame
  -- once and says so in one line, not once per player.
  --
  -- The names are deliberately left out of that line: this window's own list is what
  -- answers "who", and two dozen colored names wrapped across the chat frame is no better
  -- than the two dozen lines it replaced.
  ---@param boss_name string
  local function on_boss_killed( boss_name )
    if not granting_bosses[ boss_name ] then return end

    local timestamp = m.lua.time()
    local paid_out = 0

    for _, row in ipairs( eligibility.get_rows() ) do
      if row.eligible then
        write( row.player_name, boss_name, row.class, timestamp )
        paid_out = paid_out + 1
      end
    end

    -- Worth saying out loud rather than passing in silence: a boss that grants rolls
    -- dying with nobody eligible almost always means the scan was never run, and the
    -- alternative is finding that out after the loot is gone.
    if paid_out == 0 then
      m.info( string.format( "No one is eligible for a %s. Run %s in %s.",
        hl( "Bonus Roll" ), hl( "Infer" ), hl( "/rfbonus" ) ) )
      return
    end

    m.info( string.format( "%s granted to %s %s.",
      hl( "Bonus Roll" ), hl( paid_out ), paid_out == 1 and "player" or "players" ) )
    notify()
  end

  boss_killed.subscribe( on_boss_killed )

  ---@type ResistanceBonusRollRegistry
  return {
    grant = grant,
    get = get,
    count = count,
    count_all = count_all,
    get_rows = get_rows,
    list = list,
    reset = reset,
    subscribe = subscribe
  }
end

m.ResistanceBonusRollRegistry = M
return M
