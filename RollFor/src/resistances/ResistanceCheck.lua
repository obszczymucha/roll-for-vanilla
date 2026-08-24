RollFor = RollFor or {}
local m = RollFor

if m.ResistanceCheck then return end

local M = m.Module.new( "ResistanceCheck" )

local getn = m.getn

-- Food shows up as a "Well Fed" buff whose name says nothing about what it
-- grants, so its tooltip has to be read to find out.
local WELL_FED = { [ "Well Fed" ] = true }

-- The neck the run calls for, judged on its own so the GUI can point out who
-- turned up without it. What gets cached is the neck's whole resistance
-- breakdown rather than a yes/no, so retuning these takes effect on the next
-- redraw without re-scanning anyone.
local NECK_SLOT = 2
local NECK_TYPE = m.ResistanceRegistry.ResistanceType.Shadow
local NECK_MINIMUM = 40

---@class ResistanceRow
---@field player_name string
---@field class PlayerClass?
---@field resistance_type ResistanceType?    -- nil when there's no data
---@field personal number?                   -- gear and food for the reported school, nil when there's no data
---@field personal_by_type ResistanceTotals? -- gear and food per school, nil when there's no data
---@field total number?                      -- personal plus the raid buff, nil when there's no data
---@field food number?                       -- how much of personal came from food, nil when none did
---@field missing_neck boolean?              -- true when the required neck isn't worn, nil when it is or isn't known
---@field scanning boolean
---@field failed boolean -- the last scan couldn't reach them; not the same as never scanned

---@class ResistanceCheck
---@field get_rows fun(): ResistanceRow[]
---@field scan fun()
---@field is_scanning fun(): boolean
---@field clear fun( player_name: string )
---@field clear_all fun()
---@field subscribe fun( listener: fun() )

---@param db table -- gear totals by player name, persisted
---@param group_roster GroupRoster
---@param gear_scanner GearScanner
---@param buff_scanner BuffScanner
---@param parser ResistanceParser
---@param registry ResistanceRegistry
---@return ResistanceCheck
function M.new( db, group_roster, gear_scanner, buff_scanner, parser, registry )
  -- db is a proxy over the saved table (see Db.lua): it forwards reads and
  -- writes but holds no keys of its own, so pairs() over it comes back empty.
  -- The cache has to live one level down to be enumerable, and so clear_all can
  -- drop the whole thing in one write.
  db.gear = db.gear or {}
  db.neck = db.neck or {}

  local m_scanning = {}
  local m_scanning_count = 0
  local m_failed = {}
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

  -- Personal is what the player brings themselves: the gear scan plus their
  -- food. Both are read from tooltips, so both are already buff-free -- nothing
  -- anywhere subtracts the raid buff back out, Total adds it on top. Don't
  -- "correct" this into a subtraction later; that would double-count. Food is
  -- also kept in its own field, so the GUI can say how much of Personal isn't
  -- gear.
  ---@param player GroupPlayer
  ---@return ResistanceRow
  local function make_row( player )
    local result = {
      player_name = player.name,
      class = player.class,
      scanning = m_scanning[ player.name ] and true or false,
      failed = m_failed[ player.name ] and true or false
    }

    local totals = db.gear[ player.name ]
    if not totals then return result end

    local resistance_type, personal = registry.default_reported_type( totals )
    -- Buffs are read fresh every time. They're free to read and they change
    -- between pulls, which is the whole point of running the check again.
    local buff_data = buff_scanner.get_buffs( player.unit, WELL_FED )
    local names = {}
    local food = 0

    for i = 1, getn( buff_data ) do
      local buff = buff_data[ i ]
      table.insert( names, buff.name )
      food = food + parser.parse_all_schools( buff.tooltip_data )
    end

    local buffs = registry.resolve( names )

    -- The same gear-plus-food sum as personal, but kept per school instead of
    -- collapsed to the reported one. A caller judging more than one school --
    -- bonus roll eligibility asks about Fire *or* Shadow -- can't work from
    -- personal alone, since the player reported as Fire may be the one who
    -- qualifies on Shadow. Food is an all-schools buff, so it lands on each.
    local personal_by_type = {}

    for _, buffed_type in ipairs( registry.buffed_resistance_types() ) do
      personal_by_type[ buffed_type ] = (totals[ buffed_type ] or 0) + food
    end

    result.resistance_type = resistance_type
    result.personal = personal + food
    result.personal_by_type = personal_by_type
    result.total = result.personal + (buffs[ resistance_type ] or 0)
    result.food = food > 0 and food or nil

    -- Gear cached before the neck was tracked has nothing to say either way, so
    -- it says nothing rather than accusing everyone of turning up without one.
    local neck = db.neck[ player.name ]
    if neck and (neck[ NECK_TYPE ] or 0) < NECK_MINIMUM then result.missing_neck = true end

    return result
  end

  -- Most gear first, so whoever needs some is at the bottom of the list. Equal
  -- gear is broken by the buffed total, then by name. Players with no data yet
  -- sort last, which also keeps the order stable while a scan fills in.
  ---@param lhs ResistanceRow
  ---@param rhs ResistanceRow
  local function by_resistance_descending( lhs, rhs )
    if lhs.personal ~= rhs.personal then
      if not lhs.personal then return false end
      if not rhs.personal then return true end

      return lhs.personal > rhs.personal
    end

    if lhs.total ~= rhs.total then
      return (lhs.total or 0) > (rhs.total or 0)
    end

    return lhs.player_name < rhs.player_name
  end

  -- One row per group member. Members without cached gear come back with nil
  -- values, so opening the frame before any scan lists everyone.
  ---@return ResistanceRow[]
  local function get_rows()
    local result = {}
    local players = group_roster.get_group_players()

    for i = 1, getn( players ) do
      table.insert( result, make_row( players[ i ] ) )
    end

    table.sort( result, by_resistance_descending )

    return result
  end

  local function on_gear( name )
    return function( gear, error_type )
      m_scanning[ name ] = nil
      m_scanning_count = m_scanning_count - 1

      if error_type then
        -- Deliberately not cached, so the next scan retries them.
        m_failed[ name ] = true
        M.debug.add( string.format( "%s: %s", name, error_type ) )
      else
        db.gear[ name ] = parser.parse( gear )
        db.neck[ name ] = parser.parse_slot( gear, NECK_SLOT )
        M.debug.add( string.format( "cached %s", name ) )
      end

      notify()
    end
  end

  -- Scans everyone without cached gear. Cached players are left alone; clear()
  -- is what forces a re-scan.
  local function scan()
    local players = group_roster.get_group_players()

    for i = 1, getn( players ) do
      local player = players[ i ]
      local name = player.name

      if not db.gear[ name ] and not m_scanning[ name ] then
        m_scanning[ name ] = true
        m_scanning_count = m_scanning_count + 1
        m_failed[ name ] = nil
        gear_scanner.scan_unit( player.unit, on_gear( name ) )
      end
    end

    notify()
  end

  local function is_scanning()
    return m_scanning_count > 0
  end

  ---@param player_name string
  local function clear( player_name )
    db.gear[ player_name ] = nil
    db.neck[ player_name ] = nil
    m_failed[ player_name ] = nil
    M.debug.add( string.format( "cleared %s", player_name ) )
    notify()
  end

  local function clear_all()
    db.gear = {}
    db.neck = {}

    for player_name in pairs( m_failed ) do
      m_failed[ player_name ] = nil
    end

    M.debug.add( "cleared all" )
    notify()
  end

  ---@type ResistanceCheck
  return {
    get_rows = get_rows,
    scan = scan,
    is_scanning = is_scanning,
    clear = clear,
    clear_all = clear_all,
    subscribe = subscribe
  }
end

m.ResistanceCheck = M
return M
