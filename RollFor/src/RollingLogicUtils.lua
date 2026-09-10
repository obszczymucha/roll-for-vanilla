RollFor = RollFor or {}
local m = RollFor

if m.RollingLogicUtils then return end

local M = {}

local getn = m.getn
local map = m.map
local RT = m.Types.RollType ---@type RT

---@type MakeRollingPlayerFn
local make_rolling_player = m.Types.make_rolling_player

-- The pools a player's rolls come out of, in the order they are spent. SR rolls are what
-- the player signed up for, so they go first.
--
-- This is the whole extension seam. A second pool -- a wipe-recovery roll, a penalty roll
-- -- is one entry here plus whatever persistence it needs, and nothing that decides
-- winners has to know it exists.
local roll_pools = {
  { field = "rolls", roll_type = RT.SoftRes }
}

-- How many rolls this player still has, across every pool. Absent reads as zero.
---@param player RollingPlayer
---@return number
function M.available_rolls( player )
  local result = 0

  for _, pool in ipairs( roll_pools ) do
    result = result + (player[ pool.field ] or 0)
  end

  return result
end

-- What may adjust a roll's *value*, after it is validated and before it is recorded.
--
-- `roll_pools` above is the seam for how many rolls a player gets; this is its sibling for
-- what a roll is worth. Core adds nothing to it: an empty list is today's behaviour
-- exactly, byte for byte, because a fold over nothing returns what it was given.
--
-- ## Two kinds, and you pick one by which registrar you call
--
--     roll_modifier.delta { name, rounds, apply = function( player, item ) end }
--     roll_modifier.adjust{ name, rounds, apply = function( player, item, base, current ) end }
--
-- Both `apply`s return the same thing: a signed number to add, or nil to decline this
-- player. The difference is what they are given. A delta sees who is rolling and what for.
-- An adjust also sees the roll that was just cast and the running total after earlier
-- modifiers.
--
--     -- delta: the soft-res list already states the number. No roll needed to know it.
--     ctx.roll_modifier.delta( {
--       name = "sr_plus",
--       rounds = { RS.SoftResRoll },
--       apply = function( player, item ) return bonus_for( player.name, item.id ) end
--     } )
--
--     -- adjust: "no roll above 100" is meaningless until there is a roll.
--     ctx.roll_modifier.adjust( {
--       name = "cap",
--       rounds = { RS.SoftResRoll, RS.NormalRoll },
--       apply = function( _, _, _, current ) return current > 100 and 100 - current or 0 end
--     } )
--
--     -- adjust: ten percent of what, if not the roll?
--     ctx.roll_modifier.adjust( {
--       name = "tithe",
--       rounds = { RS.NormalRoll },
--       apply = function( _, _, base ) return math.floor( base * 0.1 ) end
--     } )
--
-- ## Why the choice is the whole design
--
-- The roll call is printed *before anybody rolls*:
--
--     Roll for [Bag]. SR by Obszczymucha and Psikutas (+30)
--
-- To write `(+30)` there, core has to know what a modifier will contribute without a roll
-- to give it. A `delta` can answer -- its inputs already exist. An `adjust` cannot: its
-- answer is a function of a number that does not exist yet. Hence `preview_adjustments`
-- below asking only the deltas.
--
-- So **previewability is a consequence of which function was written**, not a flag anybody
-- can set wrongly. Had it been `previewable = true` on the spec, an author could set it
-- wrong and the roll call would announce a bonus that never arrived.
--
-- ## Which is why the kind is the registrar and not a field
--
-- This began as one `register` taking a spec with an optional `delta` and an optional
-- `adjust`, and a run-time check rejecting both-present and neither-present. That is an
-- untagged union written as optionality: the type says "here are two things you may or may
-- not supply" when the truth is "supply exactly one", so the checker accepts two shapes
-- that are not legal and the code has to catch them by hand.
--
-- Two registrars say it once, in the only place it cannot be got wrong. There is no spec
-- that carries two functions and none that carries none, so neither error exists to be
-- checked for -- and neither does the question of what the fold should do when it meets
-- one. What is left to validate is what any spec has to have: a name, a round, a function.
--
-- ## The knock-on
--
-- While every modifier is a `delta`, order does not affect the total -- addition commutes,
-- so +30 then +20 and +20 then +30 both reach +50. It only changes the order the breakdown
-- lists them in. The first `adjust` ends that: cap-then-add is not add-then-cap, since
-- 95 -> cap -> +30 is 125 while 95 -> +30 -> cap is 100. That is why the order is pinned
-- through `Ordering.place` rather than left to registration order -- which is load order,
-- which is alphabetical, which nobody chose.
-- What every modifier says regardless of kind. `apply` is the difference, and it is what
-- each of the two specs below adds -- required in both, so there is no shape of either that
-- is missing its function and no shape of either that carries the wrong one.
---@class RollModifierSpec
---@field name string -- unique; this is what lands in RollAdjustment.by
---@field after string? -- anchors, in the vocabulary Chain and the loot pipeline already use
---@field before string?
---@field rounds RollingStrategyType[] -- which rounds it takes part in

-- Registered through `roll_modifier.delta`. Previewable.
---@class RollDeltaSpec : RollModifierSpec
---@field apply fun( player: RollingPlayer, item: Item ): number? -- nil declines this player

-- Registered through `roll_modifier.adjust`. Not previewable.
---@class RollAdjustSpec : RollModifierSpec
---@field apply fun( player: RollingPlayer, item: Item, base: number, current: number ): number?

---@class RollModifier : RollModifierSpec
---@field kind "delta" | "adjust" -- which registrar it came in through
---@field apply function

---@type RollModifier[]
local roll_modifiers = {}

-- Resolved once, on first use, and thrown away whenever a modifier is added. Chain and the
-- loot pipeline resolve at their own build time; rolls have no build step, and every
-- modifier arrives during Extensions.enable() -- long before anybody rolls -- so first use
-- is the same moment by a different name.
---@type RollModifier[]?
local placed

---@param spec RollDeltaSpec|RollAdjustSpec
---@param kind "delta" | "adjust"
---@return boolean -- whether the modifier was registered
local function register( spec, kind )
  if type( spec ) ~= "table" then
    m.err( "Roll modifier registration failed: the spec must be a table." )
    return false
  end

  if type( spec.name ) ~= "string" or spec.name == "" then
    m.err( "Roll modifier registration failed: 'name' must be a non-empty string." )
    return false
  end

  for _, modifier in ipairs( roll_modifiers ) do
    if modifier.name == spec.name then
      m.err( string.format( "Roll modifier %s is already registered.", m.colors.hl( spec.name ) ) )
      return false
    end
  end

  if type( spec.rounds ) ~= "table" or getn( spec.rounds ) == 0 then
    m.err( string.format( "Roll modifier %s failed to register: 'rounds' must name at least one round.",
      m.colors.hl( spec.name ) ) )
    return false
  end

  if type( spec.apply ) ~= "function" then
    m.err( string.format( "Roll modifier %s failed to register: 'apply' must be a function.",
      m.colors.hl( spec.name ) ) )
    return false
  end

  table.insert( roll_modifiers, {
    name = spec.name,
    after = spec.after,
    before = spec.before,
    rounds = spec.rounds,
    apply = spec.apply,
    kind = kind
  } )

  placed = nil

  return true
end

-- Two registrars rather than one taking a spec with two optional functions.
--
-- "Exactly one of these two fields" is a thing a type cannot say: it would have to be
-- declared as two optionals, and then both-present and neither-present are shapes the
-- checker accepts and the code has to reject by hand at run time. Which registrar was
-- called says the same thing, says it once, and cannot be got wrong -- there is no spec you
-- can write that carries two functions or none.
--
-- The kind is not on the spec either. An author who could write `kind = "delta"` next to an
-- `apply` taking four arguments would be back where we started.
---@param spec RollDeltaSpec
---@return boolean
function M.register_delta( spec ) return register( spec, "delta" ) end

---@param spec RollAdjustSpec
---@return boolean
function M.register_adjust( spec ) return register( spec, "adjust" ) end

-- Order comes from Ordering.place, the same vocabulary, failures and error messages a
-- soft-res chain link or a loot handler already uses. For two additive modifiers the order
-- does not change the total, but it changes the order they are *displayed* in, and it
-- becomes load-bearing the moment somebody writes an `adjust` -- cap-then-add is not
-- add-then-cap. Pinned before that happens rather than after.
---@return RollModifier[]
local function placed_modifiers()
  if placed then return placed end

  local ordered, rejected = m.Ordering.place( roll_modifiers, { base = "roll", noun = "Roll modifier" } )

  for _, entry in ipairs( rejected ) do
    m.err( entry.reason )
  end

  placed = ordered

  return placed
end

---@param modifier RollModifier
---@param strategy RollingStrategyType
---@return boolean
local function takes_part( modifier, strategy )
  for _, round in ipairs( modifier.rounds ) do
    if round == strategy then return true end
  end

  return false
end

-- The fold. `on_roll` calls it where a roll would otherwise be recorded as cast.
--
-- `d ~= 0` is deliberate, and 0 being truthy in Lua is exactly why it has to be written
-- out: a zero adjustment is not an adjustment, and without the guard it would print as
-- "(+0)" before the roll and decompose as "89+0=89" after it.
---@param player RollingPlayer
---@param item Item
---@param roll number
---@param strategy RollingStrategyType
---@return number -- the total
---@return RollAdjustment[]? -- absent when nothing adjusted it
function M.apply_modifiers( player, item, roll, strategy )
  local total, adjustments = roll, nil

  for _, modifier in ipairs( placed_modifiers() ) do
    if takes_part( modifier, strategy ) then
      -- Branch rather than `and/or`: a delta that declines returns nil, and nil is what
      -- `and/or` treats as "try the other side".
      local d

      if modifier.kind == "delta" then
        d = modifier.apply( player, item )
      else
        d = modifier.apply( player, item, roll, total )
      end

      if d and d ~= 0 then
        total = total + d
        adjustments = adjustments or {}
        table.insert( adjustments, { by = modifier.name, delta = d } )
      end
    end
  end

  return total, adjustments
end

-- What this player would get if they rolled now. `delta` modifiers only: an `adjust`
-- modifier depends on the roll value and has nothing to say before there is one.
---@param player RollingPlayer
---@param item Item
---@param strategy RollingStrategyType
---@return RollAdjustment[]?
function M.preview_adjustments( player, item, strategy )
  local adjustments

  for _, modifier in ipairs( placed_modifiers() ) do
    if modifier.kind == "delta" and takes_part( modifier, strategy ) then
      local d = modifier.apply( player, item )

      if d and d ~= 0 then
        adjustments = adjustments or {}
        table.insert( adjustments, { by = modifier.name, delta = d } )
      end
    end
  end

  return adjustments
end

-- The pre-roll annotation, summed into one number. Two modifiers contributing +30 and +20
-- read as " (+50)"; the breakdown is left to the winner announcement, where there is room
-- for it. Empty string when nothing has anything to add, so callers can concatenate it
-- unconditionally.
--
-- Shared because both display sites -- the roll call and the drop announcement -- have to
-- say the same thing about the same player.
---@param player RollingPlayer
---@param item Item
---@param strategy RollingStrategyType
---@return string
function M.format_preview_annotation( player, item, strategy )
  local adjustments = M.preview_adjustments( player, item, strategy )
  if not adjustments then return "" end

  local total = 0
  for _, adjustment in ipairs( adjustments ) do total = total + adjustment.delta end

  if total == 0 then return "" end

  return string.format( " (%s%d)", total > 0 and "+" or "-", math.abs( total ) )
end

---Drops every registration. Tests only -- an extension never unregisters.
function M.clear_modifiers()
  roll_modifiers = {}
  placed = nil
end

-- Spends one roll out of the first pool that still has any, and says which pool it came
-- from. nil means the player is out of rolls and nothing was spent.
---@param player RollingPlayer
---@return RollType?
function M.consume_roll( player )
  for _, pool in ipairs( roll_pools ) do
    local left = player[ pool.field ] or 0

    if left > 0 then
      player[ pool.field ] = left - 1
      return pool.roll_type
    end
  end
end

function M.can_roll( rollers, player_name )
  for _, v in ipairs( rollers ) do
    if v.name == player_name then return true end
  end

  return false
end

---@param roller RollingPlayer
function M.copy_roller( roller )
  return make_rolling_player( roller.name, roller.class, roller.online, roller.rolls )
end

---@param rollers RollingPlayer[]
function M.copy_rollers( rollers )
  local result = {}

  for k, v in pairs( rollers ) do
    result[ k ] = M.copy_roller( v )
  end

  return result
end

function M.one_roll( player_name )
  return { name = player_name, rolls = 1 }
end

function M.all_present_players( group_roster )
  local player_names = map( group_roster.get_all_players_in_my_group(), function( p ) return p.name end )
  return map( player_names, M.one_roll )
end

function M.have_all_players_rolled( rollers )
  if getn( rollers ) == 0 then return false end

  for _, v in pairs( rollers ) do
    if v.rolls > 0 then return false end
  end

  return true
end

function M.sort_rolls( rolls, roll_type )
  local function to_roll_map()
    local result = {}

    for _, roll in pairs( rolls ) do
      if not result[ roll ] then result[ roll ] = true end
    end

    return result
  end

  local function to_map( roll_map )
    local result = {}

    for player_name, roll in pairs( roll_map ) do
      if result[ roll ] then
        table.insert( result[ roll ].players, player_name )
      else
        result[ roll ] = { roll = roll, players = { player_name }, roll_type = roll_type }
      end
    end

    return result
  end

  local function f( l, r )
    if l > r then
      return true
    else
      return false
    end
  end

  local function to_sorted_rolls_array( rollmap )
    local result = {}

    for k in pairs( rollmap ) do
      table.insert( result, k )
    end

    table.sort( result, f )
    return result
  end

  local sorted_rolls = to_sorted_rolls_array( to_roll_map() )
  local rollmap = to_map( rolls )

  return map( sorted_rolls, function( v ) return rollmap[ v ] end )
end

-- Fills one of the player's pending placeholders with the roll they just cast.
--
-- Prefers a placeholder of the same type, so a roll never relabels the cell it lands in.
-- The fallback to any pending placeholder is what keeps the tie path working: RollTracker.start seeds
-- tie placeholders with RS.TieRoll as their roll type while add() passes a real RollType,
-- so nothing there ever matches.
---@param rolls RollData[]
---@param data RollData
function M.update_roll( rolls, data )
  local fallback

  for _, line in ipairs( rolls ) do
    if line.player_name == data.player_name and not line.roll then
      if line.roll_type == data.roll_type then
        line.roll = data.roll
        line.ordinal = data.ordinal
        return
      end

      fallback = fallback or line
    end
  end

  if not fallback then return end

  fallback.roll = data.roll
  fallback.ordinal = data.ordinal
end

---@param rolls RollData[]
function M.sort_roll_data( rolls )
  table.sort( rolls, function( a, b )
    local a_rank, b_rank = m.roll_type_rank( a.roll_type ), m.roll_type_rank( b.roll_type )
    if a_rank ~= b_rank then return a_rank < b_rank end

    if a.roll and b.roll then
      if a.roll == b.roll then return a.player_name < b.player_name end
      return a.roll > b.roll
    end

    if a.roll then return true end
    if b.roll then return false end

    return a.player_name < b.player_name
  end )
end

function M.has_rolls_left( rollers, player_name )
  for _, v in pairs( rollers ) do
    if v.name == player_name then
      return v.rolls > 0
    end
  end

  return false
end

-- Whether the rolling can stop before every roll has been cast. Shared by both rounds.

function M.has_everyone_rolled( rollers, rolls )
  local rolled_player_names = {}
  map( rolls, function( roll ) rolled_player_names[ roll.player.name ] = true end )

  for _, roller in ipairs( rollers ) do
    if not rolled_player_names[ roller.name ] then return false end
  end

  return true
end

function M.players_with_available_rolls( rollers )
  return m.filter( rollers, function( roller ) return M.available_rolls( roller ) > 0 end )
end

-- Whether the rolling is already decided: everyone still holding rolls is in the winning
-- set, so nothing they have left can change who wins.
--
-- A tie on the cut-off line normally means it *can* still change -- one of the tied players
-- rolling higher breaks it -- so it is not a stopping point. The exception is a tie on the
-- highest roll there is: nobody can beat it, and nobody outside it can join it, which is
-- what the loop below rules out. The rolls the tied players still hold can then only be
-- spent, never used -- and a roll is deducted the moment it is cast, so waiting for them
-- costs those players rolls in a contest that is already over.
---@param max_roll number -- the highest a /roll can come back with
function M.are_remaining_rollers_already_winners( rollers, rolls, item_count, max_roll )
  local candidates = M.best_roll_per_player( rolls )
  local top_roll_count = M.count_top_roll_winners( candidates, item_count )
  local rollers_with_remaining_rolls = M.players_with_available_rolls( rollers )
  local roller_count = getn( rollers_with_remaining_rolls )
  local roll_count = getn( rolls )

  if roller_count == 0 or roll_count == 0 then return false end

  -- The roll on the cut-off line is the contested one, which is not always the top one:
  -- with two items up and a 100 followed by two 87s, it is the 87 that is tied, and an 87
  -- can still be improved on.
  if top_roll_count > item_count and candidates[ top_roll_count ].roll < max_roll then return false end

  local top_winner_names = {}
  for i = 1, top_roll_count do
    top_winner_names[ candidates[ i ].player.name ] = true
  end

  for _, roller in ipairs( rollers_with_remaining_rolls ) do
    if not top_winner_names[ roller.name ] then return false end
  end

  return true
end

function M.winner_found( rollers, rolls, item_count, max_roll )
  return M.has_everyone_rolled( rollers, rolls ) and M.are_remaining_rollers_already_winners( rollers, rolls, item_count, max_roll )
end

-- One player, one prize: every roll beyond a player's best one is spent, so only their
-- best roll can win. `rolls` must be sorted descending, so the first roll seen for a
-- player is their best one.
--
-- Shared by both rolling logics: either round may have a player holding several rolls.
---@param rolls Roll[]
---@return Roll[]
function M.best_roll_per_player( rolls )
  local seen, result = {}, {}

  for _, roll in ipairs( rolls ) do
    if not seen[ roll.player.name ] then
      seen[ roll.player.name ] = true
      table.insert( result, roll )
    end
  end

  return result
end

-- Expects the candidate rolls (one per player) sorted descending. Returns how many of
-- them win, which exceeds item_count when the roll on the cut-off line is tied.
---@param candidates Roll[]
---@param item_count number
---@return number
function M.count_top_roll_winners( candidates, item_count )
  if getn( candidates ) == 0 then return 0 end

  local function split_by_roll()
    local result = {}
    local last_roll

    for _, roll in ipairs( candidates ) do
      if not last_roll or last_roll ~= roll.roll then
        table.insert( result, { roll } )
        last_roll = roll.roll
      else
        table.insert( result[ getn( result ) ], roll )
      end
    end

    return result
  end

  local result = 0

  for _, group in ipairs( split_by_roll() ) do
    result = result + getn( group )
    if result >= item_count then return result end
  end

  return result
end

m.RollingLogicUtils = M
return M
