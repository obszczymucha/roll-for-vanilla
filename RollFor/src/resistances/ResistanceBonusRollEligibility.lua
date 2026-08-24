RollFor = RollFor or {}
local m = RollFor

if m.ResistanceBonusRollEligibility then return end

local M = m.Module.new( "ResistanceBonusRollEligibility" )

local getn = m.getn

local Shadow, Fire = m.ResistanceRegistry.ResistanceType.Shadow, m.ResistanceRegistry.ResistanceType.Fire

local school_labels = {
  [ Fire ] = "Fire",
  [ Shadow ] = "Shadow"
}

-- The schools the rule names, in the order they're tested. Fire leads, so a player
-- clearing both minimums is described by the set they are visibly wearing rather than
-- the one they happen to also cover.
local judged_schools = { Fire, Shadow }

-- Reasons are derived, never free-text: the module writes them, the GUI never
-- invents one. A scan says which school carried the player and by how much; a
-- hand-set row says only that a person decided it.
local NOT_SCANNED = "Not scanned"
local MANUAL = "Manual"

-- Exported because the frame transformer colors by them: those two are the reasons
-- that aren't a judgement about a number, so they're the ones it greys out. Reading
-- them from here rather than retyping them is what keeps a rename from silently
-- turning the whole column green.
M.NOT_SCANNED = NOT_SCANNED
M.MANUAL = MANUAL

---@class BonusRollEligibilityEntry
---@field eligible boolean
---@field reason string

---@class BonusRollEligibilityRow
---@field player_name string
---@field class PlayerClass?
---@field eligible boolean
---@field reason string

---@class ResistanceBonusRollEligibility
---@field is_eligible fun( player_name: string ): boolean
---@field get fun( player_name: string ): BonusRollEligibilityEntry?
---@field set fun( player_name: string, eligible: boolean, reason: string? )
---@field get_rows fun(): BonusRollEligibilityRow[]
---@field count_eligible fun(): number
---@field infer fun()
---@field reset fun()
---@field subscribe fun( listener: fun() )

---@param db table -- eligibility by player name, persisted per character
---@param group_roster GroupRoster
---@param resistance_check ResistanceCheck
---@param registry ResistanceRegistry
---@return ResistanceBonusRollEligibility
function M.new( db, group_roster, resistance_check, registry )
  -- db is a proxy over the saved table (see Db.lua): it forwards reads and
  -- writes but holds no keys of its own, so pairs() over it comes back empty.
  -- The map has to live one level down to be enumerable, and so reset can drop
  -- the whole thing in one write.
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
  ---@return BonusRollEligibilityEntry?
  local function get( player_name )
    return db.players[ player_name ]
  end

  -- False for anyone with no entry, so an untouched database means nobody is
  -- eligible rather than everybody.
  ---@param player_name string
  ---@return boolean
  local function is_eligible( player_name )
    local entry = db.players[ player_name ]

    return entry and entry.eligible and true or false
  end

  ---@param player_name string
  ---@param eligible boolean
  ---@param reason string?
  local function write( player_name, eligible, reason )
    db.players[ player_name ] = { eligible = eligible and true or false, reason = reason or MANUAL }
  end

  -- The GUI passes no reason, which is what stamps a row as hand-set.
  ---@param player_name string
  ---@param eligible boolean
  ---@param reason string?
  local function set( player_name, eligible, reason )
    write( player_name, eligible, reason )
    M.debug.add( string.format( "%s: %s (%s)", player_name, tostring( eligible and true or false ), reason or MANUAL ) )
    notify()
  end

  -- The rule is an *or* across two specific schools, which is not the question
  -- the resistance list answers -- that one reports a single school per player.
  -- Someone sitting at 160 fire and 180 shadow is reported as fire and still
  -- qualifies on shadow, so both are read from personal_by_type rather than
  -- from the reported number.
  ---@param row ResistanceRow
  ---@return boolean, string
  local function judge( row )
    -- Never scanned, or the scan failed. Either way there's nothing to judge.
    if not row.personal_by_type then return false, NOT_SCANNED end

    for i = 1, getn( judged_schools ) do
      local school = judged_schools[ i ]
      local value = row.personal_by_type[ school ] or 0
      local minimum = registry.minimum( school )

      if minimum and value >= minimum then
        return true, string.format( "%s %s", school_labels[ school ], value )
      end
    end

    -- Falling short is reported against the school they're geared for, so the
    -- row says what they were trying to do and how far off it was.
    local label = school_labels[ row.resistance_type ]
    if not label then return false, NOT_SCANNED end

    return false, string.format( "%s %s", label, row.personal or 0 )
  end

  -- Overwrites every row, hand-set ones included: this is a scan of what people
  -- actually brought, and a manual toggle isn't evidence against it. The reason
  -- column is what says which rows came from here.
  local function infer()
    local rows = resistance_check.get_rows()

    for i = 1, getn( rows ) do
      local row = rows[ i ]
      local eligible, reason = judge( row )
      write( row.player_name, eligible, reason )
      M.debug.add( string.format( "inferred %s: %s (%s)", row.player_name, tostring( eligible ), reason ) )
    end

    notify()
  end

  -- Across the whole db rather than the current roster, unlike get_rows: reset drops
  -- all of it, and a caller summarising what was lost would understate it by counting
  -- only whoever happens to be standing here.
  ---@return number
  local function count_eligible()
    local result = 0

    for _, entry in pairs( db.players ) do
      if entry.eligible then result = result + 1 end
    end

    return result
  end

  local function reset()
    db.players = {}
    M.debug.add( "reset" )
    notify()
  end

  -- Eligible first -- the list is read to answer "who gets one", so the yeses
  -- belong at the top -- then by name.
  ---@param lhs BonusRollEligibilityRow
  ---@param rhs BonusRollEligibilityRow
  local function by_eligible_then_name( lhs, rhs )
    if lhs.eligible ~= rhs.eligible then return lhs.eligible end

    return lhs.player_name < rhs.player_name
  end

  -- One row per current group member. Someone in the db who has left the group
  -- doesn't appear, and their entry is left alone rather than dropped -- they
  -- may well be back before the next boss.
  ---@return BonusRollEligibilityRow[]
  local function get_rows()
    local result = {}
    local players = group_roster.get_group_players()

    for i = 1, getn( players ) do
      local player = players[ i ]
      local entry = db.players[ player.name ]

      table.insert( result, {
        player_name = player.name,
        class = player.class,
        eligible = entry and entry.eligible and true or false,
        reason = entry and entry.reason or NOT_SCANNED
      } )
    end

    table.sort( result, by_eligible_then_name )

    return result
  end

  ---@type ResistanceBonusRollEligibility
  return {
    is_eligible = is_eligible,
    get = get,
    set = set,
    get_rows = get_rows,
    count_eligible = count_eligible,
    infer = infer,
    reset = reset,
    subscribe = subscribe
  }
end

m.ResistanceBonusRollEligibility = M
return M
