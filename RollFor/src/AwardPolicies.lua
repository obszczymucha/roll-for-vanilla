RollFor = RollFor or {}
local m = RollFor

if m.AwardPolicies then return end

local M = m.Module.new( "AwardPolicies" )
local getn = m.getn

-- Who gets an item automatically, and core doing the handing out.
--
-- Phases answer *when* a handler runs and deliberately cannot answer *who gets this item*:
-- two policies competing for one slot are both in the Award phase, and ranking them is
-- exactly what a phase is not allowed to do. So the phase runs this, and this runs the
-- policies in order.
--
-- Core performs the award. A policy says what it would like -- a player name, or nil for
-- "not mine" -- and core resolves the candidate index, calls GiveMasterLoot and writes the
-- claim down. That is the whole of the fix: GiveMasterLoot is asynchronous, so a slot a
-- policy has taken is still sitting in the corpse when the next one looks at it, and
-- everything downstream reads the same stale list. The ledger is the answer to "is this
-- still up for grabs", and it is written at the point of action rather than re-derived from
-- a predicate -- which is what used to make one policy claiming an item it then could not
-- take mean nobody got it at all.
--
-- Slot-keyed, not item-keyed: two of the same gem in one window are two awards to two
-- different people, and an item id would collapse them onto one.
--
-- Cleared when a loot window opens rather than when one closes. LOOT_CLOSED can fire without
-- LOOT_SLOT_CLEARED -- the master looter assigning an item and walking away does it -- so
-- clearing on open is the one of the two that is robust to the client skipping an event.

---@class AwardPolicy
---@field name string -- unique id, and what a claim is recorded as
---@field title string -- what the user sees when ranking policies
-- What this policy would do with the slot: the name of the player it wants the item to go
-- to, or nil for "not mine". Must have no side effects -- core may still decline to send the
-- award, and the next policy then gets its turn.
---@field decide fun( slot: number, item: DroppedItem ): string?
-- The award was actually sent. This is where a policy's own bookkeeping goes: announcing it,
-- moving a rotation on, telling core's award callback. Separate from decide because only one
-- of the two is allowed to have happened.
---@field on_awarded fun( slot: number, item: DroppedItem, recipient: string )?

---@class AwardPolicies
---@field register fun( spec: AwardPolicy ): boolean
---@field claim_of fun( slot: number ): string?
---@field all fun(): AwardPolicy[] -- in the order they run
---@field move fun( position: number, offset: number ): boolean -- offset is -1 or 1
---@field attach fun( loot_list: LootList, player_info: PlayerInfo, master_loot_candidates: MasterLootCandidates )
---@field on_loot_opened fun()
---@field on_loot_slot_cleared fun()

-- The policies RollFor distributes with itself, in the order they went out with, seeding the
-- first run and nothing else.
--
-- This is not POSITIONS returning. That list was load-bearing: a name nobody occupied meant the
-- handlers anchored to it fell out of the chain and items went to the wrong person, which is why
-- vacancies needed placeholders. This is a seed value -- a name nobody registered is ignored, no
-- placeholder and no gap, an empty list works fine, and nothing anchors to it. And these are
-- addons shipped in the same package (see release.sh), so it is core knowing its own
-- distribution rather than core knowing a stranger's feature.
--
-- The soft failure to be aware of: if RollForAutoLoot renames its policy, this silently stops
-- applying to it and it lands below the known names instead. That costs a first-run ordering,
-- not correctness, and the user can drag it back.
--
-- Seeding from registration order was the alternative, and it is addon load order, which with
-- every pipeline addon declaring only `## Dependencies: RollFor` is alphabetical by folder name.
-- RollForAutoLoot above RollForAutoRobin preserves today's behaviour purely because L sorts
-- before R, and an addon called RollForAardvarkLoot would outrank both with nothing to explain
-- why.
local DEFAULT_ORDER = { "auto_loot", "auto_robin" }

-- Made before the components it works on exist, for the same reason LootFacadeListener is:
-- extensions register during Extensions.enable, which runs long before create_components gets
-- to the loot list. Registering and awarding are therefore separate -- attach() supplies the
-- collaborators once they are built, and nothing awards anything until a loot window opens.
---@param order_db table -- db( "award_order" ), per character like the extension enabled flags
---@return AwardPolicies
function M.new( order_db )
  ---@type AwardPolicy[]
  local policies = {}
  ---@type table<string, AwardPolicy>
  local by_name = {}
  ---@type table<number, string>
  local claims = {}

  local loot_list, player_info, master_loot_candidates

  ---@param spec AwardPolicy
  ---@return boolean
  local function register( spec )
    if type( spec ) ~= "table" then
      m.err( "Award policy registration failed: the spec must be a table." )
      return false
    end

    if type( spec.name ) ~= "string" or spec.name == "" then
      m.err( "Award policy registration failed: 'name' must be a non-empty string." )
      return false
    end

    if type( spec.decide ) ~= "function" then
      m.err( string.format( "Award policy %s failed to register: 'decide' must be a function.",
        m.colors.hl( spec.name ) ) )
      return false
    end

    if by_name[ spec.name ] then
      m.err( string.format( "Award policy %s is already registered.", m.colors.hl( spec.name ) ) )
      return false
    end

    local policy = {
      name = spec.name,
      title = spec.title or spec.name,
      decide = spec.decide,
      on_awarded = spec.on_awarded
    }

    by_name[ policy.name ] = policy
    table.insert( policies, policy )

    return true
  end

  ---@param slot number
  ---@return string?
  local function claim_of( slot )
    return claims[ slot ]
  end

  ---@return string[]?
  local function saved()
    return order_db and order_db.names
  end

  -- Whose turn comes first. The user's arrangement, reconciled against what actually registered
  -- this session.
  --
  --   1. The saved order, keeping only names that registered.
  --   2. Then anything registered the saved order does not name, in registration order, at the
  --      bottom -- a newly installed addon must not silently outrank an established one.
  --   3. Saved names that did not register are skipped here and kept in the saved list, so
  --      uninstalling and reinstalling gets a policy's position back. Absent is not removed.
  --
  -- Computed fresh every time rather than written back, which is what makes rule 3 hold in
  -- practice rather than on paper: a session where an addon failed to load, or an alt without
  -- it, would otherwise quietly rewrite the order to say it was never there.
  ---@return string[]
  local function ordered_names()
    local seed = saved() or DEFAULT_ORDER
    local result = {}
    local seeded = {}

    for _, name in ipairs( seed ) do
      if by_name[ name ] then
        table.insert( result, name )
        seeded[ name ] = true
      end
    end

    for _, policy in ipairs( policies ) do
      if not seeded[ policy.name ] then table.insert( result, policy.name ) end
    end

    return result
  end

  -- Core holds the registered policies and never declares one of them the winner. That is the
  -- whole difference from the list of positions this replaced: core learns the set instead of
  -- naming it.
  ---@return AwardPolicy[]
  local function all()
    local result = {}
    for _, name in ipairs( ordered_names() ) do table.insert( result, by_name[ name ] ) end
    return result
  end

  -- Written only when the user moves something. The effective order is computed at load from
  -- saved-plus-registered and core never writes on startup, so nothing but a deliberate move
  -- can change what is stored.
  --
  -- Names nobody registered keep the slots they held: the saved list is walked, each slot that
  -- holds a registered name takes the next name from the new arrangement, and each slot holding
  -- an absent one is left exactly as it was.
  ---@param names string[]
  local function persist( names )
    local previous = saved()
    local result = {}
    local index = 1

    for _, name in ipairs( previous or {} ) do
      if by_name[ name ] then
        if names[ index ] then
          table.insert( result, names[ index ] )
          index = index + 1
        end
      else
        table.insert( result, name )
      end
    end

    for i = index, getn( names ) do table.insert( result, names[ i ] ) end

    order_db.names = result
  end

  -- Moves one policy by one place, swapping with its neighbour. Deliberately does not wrap: an
  -- arrow on the last row sending that policy to the top reads as a bug rather than as a
  -- rotation. The same shape, and the same reasoning, as the round-robin queue's own move.
  ---@param position number
  ---@param offset number -- -1 for up, 1 for down
  ---@return boolean -- whether anything moved
  local function move( position, offset )
    local names = ordered_names()
    local target = position + offset

    if not names[ position ] or not names[ target ] then return false end

    names[ position ], names[ target ] = names[ target ], names[ position ]
    persist( names )

    return true
  end

  -- The slots, lowest first. pairs() over a slot-keyed table is unordered, and which of two
  -- gems in one window a rotation hands out first is not a thing to leave to a hash.
  ---@return number[]
  local function slots_in_order()
    local result = {}
    for slot in pairs( loot_list.get_items_by_slot() ) do table.insert( result, slot ) end
    table.sort( result )
    return result
  end

  -- The guards core checks once, so no policy has to repeat them.
  --
  -- Being master looter is GiveMasterLoot's own requirement and core is the one calling it
  -- now. Shift is the standard "don't do the automatic thing" modifier: it used to describe
  -- itself as living in exactly one place, which stopped being true the moment there were two
  -- policies, and is true again now that the loop is core's.
  ---@return boolean
  local function automatic_awards_allowed()
    return player_info.is_master_looter() and not m.is_shift_key_down()
  end

  -- Sends one award and stops, and runs again on every LOOT_SLOT_CLEARED.
  --
  -- Stopping is the part that is not obvious, and it is what makes this correct whether or not
  -- the client refuses a batch. Handing out two in a single pass does not work: the first lands
  -- and the rest are refused without a word -- no Lua error, the window just sits there with
  -- the other items in it. Core cannot see that happen, so a pass that sent three awards and
  -- wrote three claims would have two items claimed by an award that never went out and
  -- nothing left to retry them: the claim is what stops a later pass reawarding a slot the
  -- stale loot list still shows, and it cannot tell the two apart.
  --
  -- So only send what can be confirmed. LOOT_SLOT_CLEARED is the server saying the last award
  -- landed, and it is the cue for the next one. If the client would in fact have taken all
  -- three, this costs a round trip each and ends in the same place -- one loot window opened,
  -- everything assigned -- which is what lets that question stay unanswered.
  local function award()
    if not loot_list then return end
    if not automatic_awards_allowed() then return end

    local items = loot_list.get_items_by_slot()

    for _, slot in ipairs( slots_in_order() ) do
      local item = items[ slot ]

      -- Coins carry no id, and looting one is behind a secure button the API cannot press.
      -- One rule rather than two: this subsumes the separate "not a Coin" test the rotation
      -- used to keep, so the two can no longer disagree about how to say the same thing.
      if item and item.id and not claims[ slot ] then
        for _, policy in ipairs( all() ) do
          local recipient = policy.decide( slot, item )

          if recipient then
            -- A recipient who is not a candidate is not a refusal, it is this policy having
            -- nothing it can do here -- so the next one gets its turn rather than the slot
            -- being held by a claim nobody can act on.
            local index = master_loot_candidates.get_index( slot, recipient )

            if index then
              M.debug.add( string.format( "award( %s, %s ) -> %s (%s)", slot, item.link or item.id,
                recipient, policy.name ) )

              m.api.GiveMasterLoot( slot, index )
              claims[ slot ] = policy.name

              if policy.on_awarded then policy.on_awarded( slot, item, recipient ) end

              return
            end
          end
        end
      end
    end
  end

  local function on_loot_opened()
    M.debug.add( string.format( "on_loot_opened: %s policies", getn( policies ) ) )
    claims = {}
    award()
  end

  ---@param a LootList
  ---@param b PlayerInfo
  ---@param c MasterLootCandidates
  local function attach( a, b, c )
    loot_list, player_info, master_loot_candidates = a, b, c
  end

  ---@type AwardPolicies
  return {
    register = register,
    move = move,
    attach = attach,
    claim_of = claim_of,
    all = all,
    on_loot_opened = on_loot_opened,
    on_loot_slot_cleared = award
  }
end

m.AwardPolicies = M
return M
