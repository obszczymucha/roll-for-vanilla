RollFor = RollFor or {}
local m = RollFor

if m.AutoRoundRobin then return end

local M = m.Module.new( "AutoRoundRobin" )
local getn = m.getn
local round_robin_db = m.AutoRoundRobinDb

-- Hands selected items to group members in a rotation instead of rolling for them. When a loot
-- window opens with an item on the round-robin list in it, this picks whoever is furthest from
-- having been served, awards it, announces it and records it. Once everybody eligible has had
-- one, the cycle turns over and it starts again.
--
-- Two things are deliberately kept apart, and conflating them is the bug this design exists to
-- avoid:
--
--   * the POOL is every player this character has ever seen in a group, each with the cycle in
--     which they were last served. It's never pruned, so leaving and rejoining keeps your place.
--   * the CANDIDATES are what GetMasterLootCandidate returns for the slot being awarded. That,
--     and not the roster, decides who can actually receive: players outside the instance,
--     offline or out of range simply aren't listed.
--
-- A cycle is judged complete against the candidates only. Judged against the pool it would never
-- complete, because the pool accumulates every player this character has ever raided with.
--
-- Absent players need no special case: their served_cycle stops advancing while everybody else's
-- climbs, so the moment they become a candidate they hold the lowest number and win outright.
-- Missing three cycles keeps them three cycles ahead of the queue.

---@class RoundRobinState
---@field cycle number
---@field pool table<string, number> -- player name -> the cycle they were last served in

---@class AutoRoundRobinRow
---@field player_name string
---@field class PlayerClass?
---@field served_cycle number
---@field behind number -- how many cycles they are owed; 0 means served this cycle
---@field eligible boolean -- currently a master loot candidate

---@class AutoRoundRobin
---@field on_loot_opened fun()
---@field on_group_changed fun()
---@field get_rows fun(): AutoRoundRobinRow[]
---@field get_cycle fun(): number
---@field is_pristine fun(): boolean
---@field reset fun()
---@field subscribe fun( listener: fun() )

-- The selection algorithm, as pure functions over a RoundRobinState so it can be tested without
-- a loot window, a roster or any of the WoW API. The instance below is the only thing that knows
-- where the state is persisted or how a winner is paid.

-- Every player in the group with no pool entry is inserted at the current cycle. That single rule
-- covers both seeding an empty pool and somebody joining mid-cycle, and is why a joiner lands at
-- the bottom: marked as already served for this cycle, they can't receive until it turns over.
-- Players already in the pool are never touched.
---@param state RoundRobinState
---@param names string[]
function M.seed( state, names )
  for _, name in ipairs( names ) do
    if state.pool[ name ] == nil then state.pool[ name ] = state.cycle end
  end
end

-- Who should receive next, and the cycle the award will be recorded under. Seeds any unknown
-- candidate first, then takes the lowest served_cycle among the candidates; if that's the current
-- cycle then everybody eligible has already been served, so the cycle turns over. One increment
-- always suffices -- after it, min_served < cycle holds for every candidate.
--
-- Nothing about the winner is written back here: the caller commits only once GiveMasterLoot has
-- actually gone through (see commit).
---@param state RoundRobinState
---@param names string[] -- eligible candidates, not the roster
---@param random_fn fun( n: number ): number
---@return string? -- the winner, or nil when nobody is eligible
---@return number -- the cycle to record the award under
function M.select( state, names, random_fn )
  if getn( names ) == 0 then return nil, state.cycle end

  M.seed( state, names )

  local min_served

  for _, name in ipairs( names ) do
    local served = state.pool[ name ]
    if not min_served or served < min_served then min_served = served end
  end

  local cycle = min_served == state.cycle and state.cycle + 1 or state.cycle

  local tied = {}
  for _, name in ipairs( names ) do
    if state.pool[ name ] == min_served then table.insert( tied, name ) end
  end

  -- Sorted so the draw is over a stable list: the candidate order is whatever the client
  -- enumerated, and a random index into an unstable list isn't a uniform choice over players.
  table.sort( tied )

  local count = getn( tied )
  -- One player at the minimum is not a decision, so no roll is spent making it.
  local index = count == 1 and 1 or random_fn( count )

  return tied[ index ], cycle
end

---@param state RoundRobinState
---@param winner string
---@param cycle number -- as returned by select
function M.commit( state, winner, cycle )
  state.cycle = cycle
  state.pool[ winner ] = cycle
end

---@param loot_list LootList
---@param api function
---@param db table the persisted autorobin_db (cycle, pool and the GUI's selection tree)
---@param config Config
---@param player_info PlayerInfo
---@param chat Chat
---@param group_roster GroupRoster
---@param master_loot_candidates MasterLootCandidates
---@param auto_loot AutoLoot
---@param loot_award_callback LootAwardCallback
---@param random_fn fun( n: number ): number? -- injectable so the award pass is testable
---@return AutoRoundRobin
function M.new( loot_list, api, db, config, player_info, chat, group_roster, master_loot_candidates,
                auto_loot, loot_award_callback, random_fn )
  local listeners = {}
  local random = random_fn or function( n ) return m.lua.math.random( 1, n ) end

  db.cycle = db.cycle or 1
  db.pool = db.pool or {}

  ---@return RoundRobinState
  local function state()
    -- Read through db rather than captured once: it's the SavedVariables table, and reset()
    -- replaces what's in it.
    return db
  end

  local function notify()
    for _, listener in ipairs( listeners ) do listener() end
  end

  ---@param listener fun()
  local function subscribe( listener )
    table.insert( listeners, listener )
  end

  ---@return string[]
  local function roster_names()
    local result = {}

    for _, player in ipairs( group_roster.get_all_players_in_my_group() ) do
      table.insert( result, player.name )
    end

    return result
  end

  local function on_group_changed()
    M.seed( state(), roster_names() )
    notify()
  end

  ---@param slot number
  ---@param item DroppedItem
  local function award( slot, item )
    local candidates = master_loot_candidates.get( slot )
    -- GetMasterLootCandidate returns nothing for a slot transiently. Leave the state alone and
    -- let the next loot window retry rather than turning the cycle over for nobody.
    if getn( candidates ) == 0 then return end

    local names = {}
    local classes = {}

    for _, candidate in ipairs( candidates ) do
      table.insert( names, candidate.name )
      classes[ candidate.name ] = candidate.class
    end

    local winner, cycle = M.select( state(), names, random )
    if not winner then return end

    local index = master_loot_candidates.get_index( slot, winner )
    if not index then return end

    M.debug.add( string.format( "award( %s, %s, %s )", slot, item.link, winner ) )
    api().GiveMasterLoot( slot, index )
    M.commit( state(), winner, cycle )

    chat.announce( string.format( "%s receives %s (round robin).", winner, item.link ) )
    loot_award_callback.on_loot_awarded( item.id, item.link, winner, classes[ winner ], 1 )

    notify()
  end

  ---@param item DroppedItem
  ---@return boolean
  local function is_awardable( item )
    if not item.id then return false end
    if not round_robin_db.is_enabled( db, item.id ) then return false end

    -- Conflicts resolve in auto-loot's favour. Asking auto-loot rather than re-deriving its
    -- quality/bind rules keeps the precedence rule a single call, and stops the two features
    -- from both firing on one slot.
    if auto_loot.is_auto_looted( item ) then return false end

    -- Below the master loot threshold an item isn't master-lootable at all, so GiveMasterLoot
    -- would quietly do nothing. Can't bite the shipping catalogue -- every gem in it is epic --
    -- but the pass shouldn't depend on that staying true.
    return (item.quality or 0) >= api().GetLootThreshold()
  end

  local function on_loot_opened()
    if not player_info.is_master_looter() then return end
    if not config.auto_round_robin() then return end
    -- The same manual-override escape auto-loot has.
    if m.is_shift_key_down() then return end

    -- Iterate by slot, not by item id: two of the same gem in one window are two awards to two
    -- different players, and loot_list.get_slot() would collapse them onto the first match.
    for slot, item in pairs( loot_list.get_items_by_slot() ) do
      if is_awardable( item ) then award( slot, item ) end
    end
  end

  -- Who is a master loot candidate right now. Only answerable while a loot window is open --
  -- GetMasterLootCandidate has no slot to speak about otherwise -- so an empty answer is read as
  -- "nothing to say" and everyone shows as eligible rather than as a window full of dimmed rows.
  ---@return table<string, boolean>?
  local function current_candidates()
    if not loot_list.is_looting() then return nil end

    local result = {}
    local any = false

    for slot in pairs( loot_list.get_items_by_slot() ) do
      for _, candidate in ipairs( master_loot_candidates.get( slot ) ) do
        result[ candidate.name ] = true
        any = true
      end

      break
    end

    return any and result or nil
  end

  -- The pool keeps everyone forever; this is a display, not the record, so it narrows down to
  -- who's actually standing in the group right now. Ordered by served_cycle ascending -- who is
  -- owed the most, first -- and then by name.
  ---@return AutoRoundRobinRow[]
  local function get_rows()
    local candidates = current_candidates()
    local result = {}

    for _, player in ipairs( group_roster.get_all_players_in_my_group() ) do
      -- Somebody the roster has but the pool doesn't hasn't been seeded yet (the roster update
      -- lands after this window is drawn on the very first refresh); they're where a joiner is.
      local served_cycle = db.pool[ player.name ] or db.cycle
      local eligible = true
      if candidates then eligible = candidates[ player.name ] and true or false end

      table.insert( result, {
        player_name = player.name,
        class = player.class,
        served_cycle = served_cycle,
        behind = db.cycle - served_cycle,
        eligible = eligible
      } )
    end

    table.sort( result, function( lhs, rhs )
      if lhs.served_cycle ~= rhs.served_cycle then return lhs.served_cycle < rhs.served_cycle end

      return lhs.player_name < rhs.player_name
    end )

    return result
  end

  -- Whether there's anything a reset would throw away, so confirming can be skipped when there
  -- isn't. An untouched rotation is cycle 1 with nobody served in an earlier one.
  ---@return boolean
  local function is_pristine()
    if db.cycle ~= 1 then return false end

    for _, served_cycle in pairs( db.pool ) do
      if served_cycle ~= 1 then return false end
    end

    return true
  end

  local function reset()
    db.cycle = 1
    db.pool = {}
    -- The rotation is empty rather than gone: everybody present is back in at cycle 1, which is
    -- what the next roster update would do anyway.
    M.seed( state(), roster_names() )
    notify()
  end

  ---@type AutoRoundRobin
  return {
    on_loot_opened = on_loot_opened,
    on_group_changed = on_group_changed,
    get_rows = get_rows,
    get_cycle = function() return db.cycle end,
    is_pristine = is_pristine,
    reset = reset,
    subscribe = subscribe
  }
end

m.AutoRoundRobin = M
return M
