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
-- the player signed up for, so they go first; a bonus roll is only ever the overflow.
--
-- This is the whole extension seam. A third pool -- a wipe-recovery roll, a penalty roll
-- -- is one entry here plus whatever persistence it needs, and nothing that decides
-- winners has to know it exists.
local roll_pools = {
  { field = "rolls", roll_type = RT.SoftRes },
  { field = "bonus_rolls", roll_type = RT.BonusRoll }
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
  return make_rolling_player( roller.name, roller.class, roller.online, roller.rolls, roller.bonus_rolls )
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
-- Prefers a placeholder of the same type, because a player can hold both SR and bonus
-- placeholders and dropping an SR roll into the bonus cell would relabel it. The fallback
-- to any pending placeholder is what keeps the tie path working: RollTracker.start seeds
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

-- Whether the rolling can stop before every roll has been cast. Shared by both rounds: a
-- tie round carries bonus rolls too, so it can reach the same "nothing left can change
-- this" state the soft-res round can.

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
-- spent, never used -- and a bonus roll is deducted the moment it is cast, so waiting for
-- them costs those players rolls in a contest that is already over.
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
-- Shared by both rolling logics: a tie round now carries bonus rolls too, so it has the
-- same "a player may hold several rolls" problem the soft-res round has.
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

-- Casting a bonus roll is what spends it, in the tie round exactly as in the soft-res one.
-- Announced with the count left, because a bonus roll is a thing the player earned and is
-- now out of, and that number is what stops the next argument.
---@param registry ResistanceBonusRollRegistry
---@param chat Chat
---@param item Item
---@param player RollingPlayer
---@param roll number
---@return BonusRollToken?
function M.spend_bonus_roll( registry, chat, item, player, roll )
  local token = registry.use( player.name, item.id, item.link, roll )
  if not token then return nil end

  local left = registry.count_for_item( player.name, item.id )
  chat.info( string.format( "%s used a %s on %s (%s). %s left.",
    m.colorize_player_by_class( player.name, player.class ), m.colors.hl( "Bonus Roll" ), item.link,
    m.colors.hl( roll ), m.colors.hl( left ) ) )

  return token
end

m.RollingLogicUtils = M
return M
