RollFor = RollFor or {}
local m = RollFor

if m.AutoRoundRobin then return end

local M = m.Module.new( "AutoRoundRobin" )
local getn = m.getn
local round_robin_db = m.AutoRoundRobinDb

-- Hands selected items out in a strict, visible rotation instead of rolling for them. When a loot
-- window opens with an item on the round-robin list in it, the item's category names a queue, the
-- first player in that queue who can actually receive gets it, and they go to the back.
--
-- One queue per category (Gems, Marks, Hearts -- see AutoRoundRobinDb), each independent: taking
-- a gem does not move you down the Marks queue.
--
-- A queue is an ordered list of { name, class } and nothing else. There is no random draw, no
-- cycle counter and no derived standing: the order you see is the order it serves, which is the
-- point of showing it. It is seeded from the group roster, joiners are appended, and from there
-- it is yours to edit -- add, remove, move a player, or rotate the whole thing.
--
-- The one thing the order alone does not decide is who can actually be handed the item.
-- GetMasterLootCandidate is the authority on that -- players outside the instance, offline or out
-- of range are simply not listed -- so the award walks down the queue to the first player who is
-- listed. Whoever it walks past keeps their place and wins the next drop they are around for.
-- That is the whole reason the queue and the candidate list are kept apart.
--
-- Kept apart in the read direction too: nothing this module hands out says whether a player can
-- receive. That is only answerable while a loot window is open, so a queue carrying it around
-- would be asserting something it cannot know for all but a few seconds at a time.

---@class RoundRobinPlayer
---@field name string
---@field class PlayerClass?

---@alias RoundRobinQueue RoundRobinPlayer[]

---@class AutoRoundRobinRow : RoundRobinPlayer

---@class AutoRoundRobin
---@field on_loot_opened fun()
---@field on_group_changed fun()
---@field get_categories fun(): string[]
---@field get_rows fun( category: string, limit: number? ): AutoRoundRobinRow[]
---@field get_queue fun( category: string ): RoundRobinQueue
---@field add_player fun( category: string, name: string, class: PlayerClass? ): boolean, string?
---@field remove_player fun( category: string, position: number )
---@field move_player fun( category: string, position: number, offset: number )
---@field cycle fun( category: string, offset: number )
---@field is_category_active fun( category: string ): boolean
---@field is_pristine fun(): boolean
---@field reset fun()
---@field subscribe fun( listener: fun( category: string ) ): fun() -- returns an unsubscribe function

-- Queue operations, as pure functions over a plain array so they can be tested without a loot
-- window, a roster or any of the WoW API. Every one of them is a no-op on input it can't act on,
-- because all of them are reachable from a button that a user can click twice.

---@param queue RoundRobinQueue
---@param name string
---@return number? -- their place in the queue, case-insensitively
function M.position_of( queue, name )
  local needle = string.lower( name )

  for i = 1, getn( queue ) do
    if string.lower( queue[ i ].name ) == needle then return i end
  end
end

-- Everybody in the group who isn't in the queue yet, appended in roster order. Leaving does not
-- remove you: the queue is a rotation, not a roster, and dropping out for a wipe or a disconnect
-- must not cost your place. Removing somebody is a deliberate act (see remove_player).
---@param queue RoundRobinQueue
---@param players RoundRobinPlayer[]
function M.sync( queue, players )
  for _, player in ipairs( players ) do
    if not M.position_of( queue, player.name ) then
      table.insert( queue, { name = player.name, class = player.class } )
    end
  end
end

-- The first player in the queue who can actually receive. Only the award pass asks this, and only
-- with a loot window open, which is the only time there is an answer: `eligible` being nil means
-- nobody has said who can, and the head of the queue is taken as given.
---@param queue RoundRobinQueue
---@param eligible table<string, boolean>? -- names GetMasterLootCandidate listed for this slot
---@return number? -- their position, or nil when nobody in the queue can receive
function M.next_position( queue, eligible )
  for i = 1, getn( queue ) do
    if not eligible or eligible[ queue[ i ].name ] then return i end
  end
end

-- Served, so they go to the back. The players walked past on the way are untouched and keep
-- their place at the front.
---@param queue RoundRobinQueue
---@param position number
---@return RoundRobinPlayer? -- who was served
function M.serve( queue, position )
  local player = queue[ position ]
  if not player then return nil end

  table.remove( queue, position )
  table.insert( queue, player )

  return player
end

-- Rotates the whole queue by one. Which of the two directions is called "up" is a question for
-- the window, not for this: a positive offset sends the head to the back and everybody else
-- climbs a place, a negative one brings the last player to the front.
---@param queue RoundRobinQueue
---@param offset number -- 1 sends the head to the back, -1 brings the last player to the front
function M.cycle( queue, offset )
  local count = getn( queue )
  if count < 2 then return end

  if offset > 0 then
    table.insert( queue, table.remove( queue, 1 ) )
  else
    table.insert( queue, 1, table.remove( queue, count ) )
  end
end

-- Moves one player by one place, swapping with their neighbour. Deliberately does not wrap:
-- the arrow on the last row would otherwise send that player to the top, which reads as a bug
-- rather than as a rotation. Rotating is what cycle is for.
---@param queue RoundRobinQueue
---@param position number
---@param offset number -- -1 for up, 1 for down
function M.move( queue, position, offset )
  local target = position + offset
  if not queue[ position ] or not queue[ target ] then return end

  queue[ position ], queue[ target ] = queue[ target ], queue[ position ]
end

---@param loot_list LootList
---@param api function
---@param db table the persisted autorobin_db (the queues and the GUI's selection tree)
---@param config Config
---@param player_info PlayerInfo
---@param chat Chat
---@param group_roster GroupRoster
---@param master_loot_candidates MasterLootCandidates
---@param auto_loot AutoLoot
---@param loot_award_callback LootAwardCallback
---@return AutoRoundRobin
function M.new( loot_list, api, db, config, player_info, chat, group_roster, master_loot_candidates,
                auto_loot, loot_award_callback )
  db.queues = db.queues or {}

  -- Every write to a queue goes through queues.update, which hands out the array and notifies
  -- afterwards. That's the only way to get a writable queue, so there is no notify() to forget.
  local queues = db.watch( "queues" )

  -- Reads. Mutating what this returns is a write nobody is watching -- use queues.update.
  ---@param category string
  ---@return RoundRobinQueue
  local function queue( category )
    db.queues[ category ] = db.queues[ category ] or {}

    return db.queues[ category ]
  end

  ---@param listener fun( category: string )
  ---@return fun()
  local function subscribe( listener )
    return queues.subscribe( listener )
  end

  ---@return string[]
  local function get_categories()
    return round_robin_db.categories( db )
  end

  ---@return RoundRobinPlayer[]
  local function roster_players()
    local result = {}

    for _, player in ipairs( group_roster.get_all_players_in_my_group() ) do
      table.insert( result, { name = player.name, class = player.class } )
    end

    return result
  end

  -- Every queue gets every group member, which is what makes the queues independent but the
  -- membership shared: you are in all of them or you were taken out of one on purpose.
  local function on_group_changed()
    local players = roster_players()

    for _, category in ipairs( get_categories() ) do
      queues.update( category, function( q ) M.sync( q, players ) end )
    end
  end

  ---@param slot number
  ---@return table<string, boolean>?, table<string, PlayerClass>
  local function candidates_for( slot )
    local names = {}
    local classes = {}
    local any = false

    for _, candidate in ipairs( master_loot_candidates.get( slot ) ) do
      names[ candidate.name ] = true
      classes[ candidate.name ] = candidate.class
      any = true
    end

    return any and names or nil, classes
  end

  ---@param slot number
  ---@param item DroppedItem
  ---@param category string
  local function award( slot, item, category )
    local eligible, classes = candidates_for( slot )

    -- GetMasterLootCandidate returns nothing for a slot transiently. Leave the queue alone and
    -- let the next loot window retry rather than serving somebody who can't be paid.
    if not eligible then return end

    local q = queue( category )
    local position = M.next_position( q, eligible )

    -- Nobody in the queue is a candidate right now. Everybody keeps their place.
    if not position then return end

    local winner = q[ position ]
    local index = master_loot_candidates.get_index( slot, winner.name )
    if not index then return end

    M.debug.add( string.format( "award( %s, %s, %s, %s )", slot, item.link, category, winner.name ) )
    api().GiveMasterLoot( slot, index )

    -- Only once the award has actually gone through.
    queues.update( category, function( c ) M.serve( c, position ) end )

    chat.announce( string.format( "%s receives %s (%s round robin).", winner.name, item.link, string.lower( category ) ) )
    loot_award_callback.on_loot_awarded( item.id, item.link, winner.name,
      winner.class or classes[ winner.name ], 1 )
  end

  ---@param item DroppedItem
  ---@return boolean
  local function is_awardable( item )
    if not item.id then return false end

    -- Below the master loot threshold an item isn't master-lootable at all, so GiveMasterLoot
    -- would quietly do nothing. This matters to the shipping catalogue: Mark of the Illidari is
    -- Uncommon and Heart of Darkness is Rare, so neither is handed out unless the master loot
    -- threshold is set low enough to cover them.
    --
    -- It is also the whole of the Trash category's threshold rule: because this runs first,
    -- ticking Trash's Uncommon row can only ever take effect while the threshold is Uncommon, and
    -- its Rare row while the threshold is Uncommon or Rare. Nothing downstream re-checks that.
    if (item.quality or 0) < api().GetLootThreshold() then return false end

    -- Conflicts resolve in auto-loot's favour. Asking auto-loot rather than re-deriving its
    -- quality/bind rules keeps the precedence rule a single call, and stops the two features
    -- from both firing on one slot.
    return not auto_loot.is_auto_looted( item )
  end

  local function on_loot_opened()
    if not player_info.is_master_looter() then return end
    if not config.auto_round_robin() then return end
    -- The same manual-override escape auto-loot has.
    if m.is_shift_key_down() then return end

    -- Iterate by slot, not by item id: two of the same gem in one window are two awards to two
    -- different players, and loot_list.get_slot() would collapse them onto the first match.
    for slot, item in pairs( loot_list.get_items_by_slot() ) do
      if is_awardable( item ) then
        local category = round_robin_db.find_category( db, item.id, item.quality )
        if category then award( slot, item, category ) end
      end
    end
  end

  -- The queue in order, which is the order it serves. Nothing here depends on the client: who can
  -- actually receive is only answerable while a loot window is open, so it is the award pass's
  -- question (see next_position) and not something the queue carries around being wrong about
  -- the rest of the time.
  ---@param category string
  ---@param limit number? -- how many from the front; the whole queue when omitted
  ---@return AutoRoundRobinRow[]
  local function get_rows( category, limit )
    local q = queue( category )
    local result = {}
    local count = getn( q )

    if limit and limit < count then count = limit end

    for i = 1, count do
      table.insert( result, { name = q[ i ].name, class = q[ i ].class } )
    end

    return result
  end

  -- Anyone can be added, in the group or not: a queue outlives the raid it was built in, and
  -- somebody who is offline right now is exactly who you want to keep a place for.
  ---@param category string
  ---@param name string
  ---@param class PlayerClass?
  ---@return boolean -- whether they were added
  ---@return string? -- why not
  local function add_player( category, name, class )
    local trimmed = string.match( name or "", "^%s*(.-)%s*$" )

    if trimmed == "" then return false, "That's not a name." end

    local q = queue( category )
    local existing = M.position_of( q, trimmed )

    -- Reports the queue's own spelling rather than what was typed: the point of the message is to
    -- point at the row that is already there, and the match was case-insensitive.
    if existing then
      return false, string.format( "%s is already in the %s queue.", q[ existing ].name, category )
    end

    queues.update( category, function( c ) table.insert( c, { name = trimmed, class = class } ) end )

    return true
  end

  ---@param category string
  ---@param position number
  local function remove_player( category, position )
    local q = queue( category )
    if not q[ position ] then return end

    queues.update( category, function( c ) table.remove( c, position ) end )
  end

  ---@param category string
  ---@param position number
  ---@param offset number
  local function move_player( category, position, offset )
    queues.update( category, function( q ) M.move( q, position, offset ) end )
  end

  ---@param category string
  ---@param offset number
  local function cycle( category, offset )
    queues.update( category, function( q ) M.cycle( q, offset ) end )
  end

  -- Whether this category would actually hand anything out if an item dropped right now. The same
  -- question the award pass answers, asked without an item: the feature on, the category ticked,
  -- something ticked under it, and at least one of those things at or above the master loot
  -- threshold -- because below it GiveMasterLoot refuses and the queue never moves.
  --
  -- Exists for display addons (see RollForApi), so that "is anybody actually queuing for gems"
  -- is answered by the rule itself rather than re-derived from the saved variables by everyone
  -- who asks.
  ---@param category string
  ---@return boolean
  local function is_category_active( category )
    if not config.auto_round_robin() then return false end

    local entry = db.ids and db.ids[ category ]
    if not entry or not entry.enabled then return false end

    local threshold = api().GetLootThreshold() or 0

    for _, item in pairs( entry.items or {} ) do
      if item.enabled and (item.quality or 0) >= threshold then return true end
    end

    -- The Trash category's rows are qualities rather than item ids, and the key is the quality.
    for quality, row in pairs( entry.qualities or {} ) do
      if row.enabled and quality >= threshold then return true end
    end

    return false
  end

  -- Whether there's anything a reset would throw away. A queue that is exactly the group in
  -- roster order is what a reset would rebuild, so there is nothing to lose.
  ---@return boolean
  local function is_pristine()
    local players = roster_players()

    for _, category in ipairs( get_categories() ) do
      local q = queue( category )
      if getn( q ) ~= getn( players ) then return false end

      for i = 1, getn( q ) do
        if q[ i ].name ~= players[ i ].name then return false end
      end
    end

    return true
  end

  -- Back to the group roster, in roster order, for every category.
  local function reset()
    local players = roster_players()

    for _, category in ipairs( get_categories() ) do
      queues.update( category, function( q )
        for i = getn( q ), 1, -1 do table.remove( q, i ) end
        M.sync( q, players )
      end )
    end
  end

  ---@type AutoRoundRobin
  return {
    on_loot_opened = on_loot_opened,
    on_group_changed = on_group_changed,
    get_categories = get_categories,
    get_rows = get_rows,
    get_queue = queue,
    add_player = add_player,
    remove_player = remove_player,
    move_player = move_player,
    cycle = cycle,
    is_category_active = is_category_active,
    is_pristine = is_pristine,
    reset = reset,
    subscribe = subscribe
  }
end

m.AutoRoundRobin = M
return M
