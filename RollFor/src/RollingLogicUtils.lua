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

m.RollingLogicUtils = M
return M
