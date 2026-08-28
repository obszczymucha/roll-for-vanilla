RollFor = RollFor or {}
local m = RollFor

if m.DropSimulator then return end

local M = {}

local getn = m.getn
local hl = m.colors.hl
local grey = m.colors.grey

-- Dev harness for the boss kill tracker. It feeds BossKilled the item ids it would
-- have got from a loot window, so kills can be exercised solo without a raid.
--
--   /rfdrop 30056           drop that item id
--   /rfdrop [Fathomstone]   drop a shift-clicked item link
--   /rfdrop vashj           drop something only Lady Vashj drops
--   /rfdrop                 usage
--   /rfdrop list            what's been killed so far
--   /rfdrop lockout         roll the raid lockout over, forgetting kills, bonus rolls
--                           and eligible players -- asks first when there's something
--                           to lose
--
-- This is the /rft end of the scale, not the /rfsetup end: it calls on_item_dropped
-- directly, so it bypasses the loot window, the quality/bind filter and the
-- master-looter gate that DroppedLoot applies in the real thing. What it does exercise
-- is everything downstream of that -- the catalogue lookup, the ignore list, the
-- already-killed check and the subscribers.
--
-- Announcing a kill is the subscriber's job, so this only speaks up when nothing
-- happened -- otherwise the same kill would be reported twice and only one of the two
-- would be the code under test.

---@class DropSimulator
---@field drop fun( args: string? )

-- Only the name is read off it, and every copy of a shared item carries the same one,
-- so an arbitrary match is the right match here.
---@param item_id number
---@return string? -- the item's name, nil when it isn't in the catalogue
local function item_name( item_id )
  for _, dungeon in pairs( m.AutoLootDb.ids ) do
    for _, boss in pairs( dungeon.bosses or {} ) do
      local item = boss.items and boss.items[ item_id ]
      if item then return item.name end
    end
  end

  return nil
end

---@param item_id number
---@return string
local function describe( item_id )
  local name = item_name( item_id )

  return name and string.format( "%s (%s)", hl( name ), item_id ) or hl( item_id )
end

-- Bosses whose name contains the query, case-insensitively. Trash and Patterns are
-- skipped for the same reason the lookup skips them: they name no boss.
---@param query string
---@return string[] -- boss names, sorted
local function matching_bosses( query )
  local needle = string.lower( query )
  local result = {}

  for _, dungeon in pairs( m.AutoLootDb.ids ) do
    for boss_name in pairs( dungeon.bosses or {} ) do
      if not m.AutoLootDb.non_bosses[ boss_name ] and string.find( string.lower( boss_name ), needle, 1, true ) then
        table.insert( result, boss_name )
      end
    end
  end

  table.sort( result )

  return result
end

-- An item that names this boss and nothing else. Anything on the ignore list is no use
-- here -- dropping one would be a no-op and look like the simulator was broken -- and
-- the lowest id is picked so the same boss always drops the same thing.
---@param boss_name string
---@return number? -- nil when every item this boss has is shared or ignored
local function droppable_item( boss_name )
  local best

  for _, dungeon in pairs( m.AutoLootDb.ids ) do
    local boss = (dungeon.bosses or {})[ boss_name ]

    for item_id in pairs( boss and boss.items or {} ) do
      if not m.BossKilled.ignored_items[ item_id ] and m.AutoLootDb.find_boss( item_id ) == boss_name then
        if not best or item_id < best then best = item_id end
      end
    end
  end

  return best
end

---@param boss_killed BossKilled
---@param raid_lockout RaidLockout
---@param confirm_lockout_reset fun( on_confirmed: fun() ) -- asks the user, then calls back
---@return DropSimulator
function M.new( boss_killed, raid_lockout, confirm_lockout_reset )
  local function usage()
    m.info( string.format( "%s -- simulate a drop by item id, item link or boss name.", hl( "/rfdrop <what>" ) ) )
    m.info( string.format( "%s -- what's been killed so far.", hl( "/rfdrop list" ) ) )
    m.info( string.format( "%s -- roll the raid lockout over (kills, bonus rolls and eligibility with it).",
      hl( "/rfdrop lockout" ) ) )
  end

  local function report_killed()
    local killed = boss_killed.get_killed_bosses()

    if getn( killed ) == 0 then
      m.info( "No bosses killed yet." )
      return
    end

    m.info( string.format( "%s killed:", hl( getn( killed ) ) ) )

    for i = 1, getn( killed ) do
      m.info( string.format( "  %s", killed[ i ] ) )
    end
  end

  -- Says nothing on success: the subscriber announces the kill, which is the thing
  -- worth seeing. Everything below is a no-op that would otherwise look like a bug.
  ---@param item_id number
  local function drop_item( item_id )
    if m.BossKilled.ignored_items[ item_id ] then
      m.info( string.format( "%s is shared between bosses, so it names none of them. %s",
        describe( item_id ), grey( "Ignored." ) ) )
      return
    end

    local boss_name = m.AutoLootDb.find_boss( item_id )

    if not boss_name then
      m.info( string.format( "No boss in the catalogue drops %s. %s",
        describe( item_id ), grey( "Trash, patterns and unlisted items name nobody." ) ) )
      return
    end

    if boss_killed.is_killed( boss_name ) then
      m.info( string.format( "%s was already killed. %s", hl( boss_name ), grey( "Nothing to report." ) ) )
      return
    end

    boss_killed.on_item_dropped( item_id )
  end

  ---@param query string
  local function drop_from_boss( query )
    local matches = matching_bosses( query )
    local count = getn( matches )

    if count == 0 then
      m.info( string.format( "No boss matches %s.", hl( query ) ) )
      return
    end

    if count > 1 then
      m.info( string.format( "%s matches %s bosses:", hl( query ), hl( count ) ) )

      for i = 1, count do
        m.info( string.format( "  %s", matches[ i ] ) )
      end

      return
    end

    local boss_name = matches[ 1 ]
    local item_id = droppable_item( boss_name )

    if not item_id then
      -- The Opera bosses are the reason this can happen at all: every item they have is
      -- either shared with the other two or resolves to whichever of them sorts first.
      m.info( string.format( "%s has nothing that names it on its own.", hl( boss_name ) ) )
      return
    end

    drop_item( item_id )
  end

  -- The one command here that destroys something a real raid night can't get back, so
  -- unlike everything else in this file it asks first. What that costs and whether it's
  -- worth asking at all is the caller's to judge -- this only says what to do with a yes.
  local function simulate_lockout()
    confirm_lockout_reset( function()
      -- Announced before it fires, not after: whatever the turnover wipes gets reported
      -- by the subscribers as it happens, and those lines belong underneath this one.
      m.info( string.format( "Simulating a %s...", hl( "raid lockout turnover" ) ) )
      raid_lockout.simulate_turnover()
    end )
  end

  ---@param args string?
  local function drop( args )
    local query = string.match( args or "", "^%s*(.-)%s*$" )

    if query == "" then
      usage()
      return
    end

    if string.lower( query ) == "list" then
      report_killed()
      return
    end

    if string.lower( query ) == "lockout" then
      simulate_lockout()
      return
    end

    -- A shift-clicked link first: it has digits in it too, so a plain number check would
    -- read the item id off the wrong part of it.
    local item_id = m.ItemUtils.get_item_id( query ) or tonumber( query )

    if item_id then
      drop_item( item_id )
      return
    end

    drop_from_boss( query )
  end

  m.slash_cmd( "rfdrop", drop )

  ---@type DropSimulator
  return {
    drop = drop
  }
end

m.DropSimulator = M
return M
