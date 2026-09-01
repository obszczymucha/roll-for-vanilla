RollFor = RollFor or {}
local m = RollFor

if m.AutoRoundRobinSimulator then return end

local M = {}

local getn = m.getn
local hl = m.colors.hl
local grey = m.colors.grey
local blue = m.colors.blue

-- Dev harness for the round-robin queues. It runs the shipped queue operations
-- (AutoRoundRobin.sync / next_position / serve / move / cycle -- the same functions the award
-- pass and the Queues window call) over a scratch roster, so a rotation can be watched solo,
-- without a raid, a loot window or master loot.
--
--   /rfrotate raid Ann,Bob,Cid  start a simulation with these players
--   /rfrotate raid 5            ...or five generated ones
--   /rfrotate raid              ...or your live Gems queue and current group, copied
--   /rfrotate drop [n]          hand out n items and trace each one
--   /rfrotate away <name>       in the queue, but not a master loot candidate right now
--   /rfrotate back <name>       can receive again
--   /rfrotate add <name>        append to the queue
--   /rfrotate remove <name>     take them out
--   /rfrotate up|down <name>    move that one player a place
--   /rfrotate cycle up|down     rotate the whole queue by one
--   /rfrotate queue             the queue as it stands
--   /rfrotate example           replay the away-player case, which is the subtle one
--   /rfrotate reset             start over
--
-- One queue, not one per category: the categories are independent copies of the same mechanism,
-- so simulating three of them would only ever show you the same thing three times.
--
-- This is the /rfdrop end of the scale, not the /rfsetup end: it never touches the live queues,
-- the real roster or the loot pipeline. `raid` with no arguments copies the live Gems queue in,
-- which is the one place the two meet, and even that is a copy.
--
-- What it therefore does not exercise: GiveMasterLoot, the announcement, the loot-history record
-- and the auto-loot precedence check. None of those can run solo anyway -- you cannot master loot
-- to yourself alone -- and all of them are covered in AutoRoundRobinSpec_test.

---@class AutoRoundRobinSimulator
---@field run fun( args: string? )

-- Enough for a full raid, and recognisable enough that a trace over ten drops can be followed
-- without keeping a legend. Real names come from the roster or the command line; these are only
-- for `raid <count>`.
local GENERATED_NAMES = {
  "Ann", "Bob", "Cid", "Dee", "Eli", "Fay", "Gus", "Hal", "Ivy", "Jax",
  "Kim", "Lou", "Mia", "Ned", "Oli", "Pia", "Quo", "Rex", "Sid", "Tia",
  "Uma", "Vic", "Wes", "Xan", "Yan", "Zoe", "Abe", "Bea", "Cal", "Dot",
  "Eve", "Finn", "Gil", "Hex", "Ida", "Jon", "Kit", "Lyn", "Moe", "Nia"
}

---@param names string[]
---@return string
local function join( names )
  return table.concat( names, ", " )
end

---@param raw string
---@return string[]
local function split_names( raw )
  local result = {}

  for name in string.gmatch( raw, "[^,%s]+" ) do
    table.insert( result, name )
  end

  return result
end

---@param round_robin_db table the live autorobin_db -- read for `raid` with no arguments, never written
---@param group_roster GroupRoster
---@return AutoRoundRobinSimulator
function M.new( round_robin_db, group_roster )
  -- The whole simulation. `queue` is a real RoundRobinQueue and is the only thing the shipped
  -- operations ever see; `away` is what the game would otherwise be telling us.
  local sim

  local function clear()
    sim = {
      ---@type RoundRobinQueue
      queue = {},
      away = {}, -- who is in the queue but not a master loot candidate right now
      drops = 0
    }
  end

  clear()

  ---@return boolean
  local function started()
    return getn( sim.queue ) > 0
  end

  local function require_started()
    if started() then return true end

    m.info( string.format( "No simulated raid yet. Start one with %s.", hl( "/rfrotate raid <names>" ) ) )
    return false
  end

  -- Who could actually receive right now. Nobody away means nobody has anything to say about it,
  -- which is the same nil the real thing passes when no loot window is open.
  ---@return table<string, boolean>?
  local function eligible()
    local result = {}
    local any_away = false

    for _, player in ipairs( sim.queue ) do
      result[ player.name ] = not sim.away[ player.name ]
      if sim.away[ player.name ] then any_away = true end
    end

    return any_away and result or nil
  end

  ---@param name string
  ---@return number?
  local function find( name )
    return m.AutoRoundRobin.position_of( sim.queue, name )
  end

  ---@param name string
  ---@return string?
  local function spelling( name )
    local position = find( name )

    return position and sim.queue[ position ].name
  end

  ---@return string[]
  local function names()
    local result = {}

    for _, player in ipairs( sim.queue ) do table.insert( result, player.name ) end

    return result
  end

  ---@param name string
  ---@return boolean
  local function require_player( name )
    if find( name ) then return true end

    m.info( string.format( "%s is not in the simulated queue.", hl( name ) ) )
    return false
  end

  -- One drop, traced. The two calls below are the shipped algorithm verbatim -- the simulator
  -- decides who is standing where and nothing else.
  local function drop_once()
    local position = m.AutoRoundRobin.next_position( sim.queue, eligible() )

    if not position then
      m.info( string.format( "  %s. %s", sim.drops + 1,
        grey( "Nobody in the queue can receive -- the drop is skipped and the queue stays put." ) ) )
      return
    end

    -- Who the drop had to walk past, which is the whole reason the head is not always the answer.
    local passed = {}
    for i = 1, position - 1 do table.insert( passed, sim.queue[ i ].name ) end

    local winner = m.AutoRoundRobin.serve( sim.queue, position )
    sim.drops = sim.drops + 1

    local why = getn( passed ) == 0 and "" or
        string.format( " -- %s", grey( string.format( "passed over %s, who %s their place",
          join( passed ), getn( passed ) == 1 and "keeps" or "keep" ) ) )

    m.info( string.format( "  %s. %s%s", sim.drops, hl( winner.name ), why ) )
  end

  ---@param count number
  local function drop( count )
    m.info( string.format( "%s %s:", hl( count ), count == 1 and "drop" or "drops" ) )

    for _ = 1, count do drop_once() end
  end

  local function report_queue()
    m.info( string.format( "%s in the queue, %s %s so far:", hl( getn( sim.queue ) ), hl( sim.drops ),
      sim.drops == 1 and "drop" or "drops" ) )

    local next_position = m.AutoRoundRobin.next_position( sim.queue, eligible() )

    for i, player in ipairs( sim.queue ) do
      local marker = i == next_position and hl( "  <- next" ) or ""
      local away = sim.away[ player.name ] and grey( " (away)" ) or ""

      m.info( string.format( "  %s. %s%s%s", i, hl( player.name ), away, marker ) )
    end
  end

  ---@param list string[]
  local function start_with( list )
    clear()

    local players = {}
    for _, name in ipairs( list ) do table.insert( players, { name = name } ) end

    -- The roster sync the real thing does on GROUP_ROSTER_UPDATE: anybody not already in the
    -- queue is appended, in roster order.
    m.AutoRoundRobin.sync( sim.queue, players )

    m.info( string.format( "Simulating %s: %s.", hl( string.format( "%s players", getn( sim.queue ) ) ),
      join( names() ) ) )
  end

  -- The live Gems queue, copied. Read-only in both directions: the simulator never writes back,
  -- and what it copies is a snapshot, so a real award landing mid-simulation doesn't disturb it.
  local function start_from_live()
    clear()

    local live = (round_robin_db.queues or {})[ "Gems" ] or {}

    for _, player in ipairs( live ) do
      table.insert( sim.queue, { name = player.name, class = player.class } )
    end

    local players = {}

    for _, player in ipairs( group_roster.get_all_players_in_my_group() ) do
      table.insert( players, { name = player.name, class = player.class } )
    end

    m.AutoRoundRobin.sync( sim.queue, players )

    if getn( sim.queue ) == 0 then
      m.info( "Nothing to copy -- the live Gems queue is empty and you aren't in a group." )
      return
    end

    m.info( string.format( "Copied the live %s queue: %s.", hl( "Gems" ), join( names() ) ) )
    m.info( grey( "Nothing here is written back -- /reload is not needed to undo it." ) )
  end

  ---@param raw string
  local function start( raw )
    if raw == "" then
      start_from_live()
      return
    end

    local count = tonumber( raw )

    if count then
      if count < 1 or count > getn( GENERATED_NAMES ) then
        m.info( string.format( "Pick between %s and %s players.", hl( 1 ), hl( getn( GENERATED_NAMES ) ) ) )
        return
      end

      local list = {}
      for i = 1, count do table.insert( list, GENERATED_NAMES[ i ] ) end
      start_with( list )

      return
    end

    local list = split_names( raw )

    if getn( list ) == 0 then
      m.info( string.format( "Give me names, a count, or nothing at all. %s", grey( "/rfrotate raid Ann,Bob,Cid" ) ) )
      return
    end

    start_with( list )
  end

  -- The subtle half of the design, played out: the drop walks past somebody who cannot receive
  -- rather than stalling on them or costing them their place.
  local function worked_example()
    m.info( blue( "Worked example -- the player at the front cannot receive." ) )
    start_with( { "Ann", "Bob", "Cid" } )

    sim.away[ "Ann" ] = true
    m.info( string.format( "%s is out of range, so the loot window never lists her.", hl( "Ann" ) ) )

    drop( 2 )
    report_queue()

    sim.away[ "Ann" ] = nil
    m.info( string.format( "%s walks back in.", hl( "Ann" ) ) )

    drop( 1 )
    m.info( grey( "She was still at the front, so she took the very next drop." ) )
  end

  local function usage()
    m.info( string.format( "%s -- simulate a round-robin queue solo.", hl( "/rfrotate" ) ) )
    m.info( string.format( "  %s -- start with these players, that many, or your live Gems queue.",
      hl( "raid <names or count>" ) ) )
    m.info( string.format( "  %s -- hand out n items (default 1).", hl( "drop [n]" ) ) )
    m.info( string.format( "  %s -- in the queue, but out of range.", hl( "away <name>" ) ) )
    m.info( string.format( "  %s -- can receive again.", hl( "back <name>" ) ) )
    m.info( string.format( "  %s -- append / take out.", hl( "add <name>, remove <name>" ) ) )
    m.info( string.format( "  %s -- move that one player a place.", hl( "up <name>, down <name>" ) ) )
    m.info( string.format( "  %s -- rotate the whole queue.", hl( "cycle up, cycle down" ) ) )
    m.info( string.format( "  %s -- the queue as it stands.", hl( "queue" ) ) )
    m.info( string.format( "  %s -- replay the worked example.", hl( "example" ) ) )
    m.info( string.format( "  %s -- start over.", hl( "reset" ) ) )
  end

  ---@param name string
  ---@param value boolean
  local function set_away( name, value )
    if not require_player( name ) then return end

    local player = spelling( name )
    sim.away[ player ] = value or nil

    m.info( value
      and string.format( "%s is out of range. %s", hl( player ),
        grey( "Still in the queue -- drops walk past them without costing them their place." ) )
      or string.format( "%s can receive again.", hl( player ) ) )
  end

  ---@param name string
  local function add( name )
    if find( name ) then
      m.info( string.format( "%s is already in the queue.", hl( name ) ) )
      return
    end

    table.insert( sim.queue, { name = name } )
    m.info( string.format( "%s joins at the back, in place %s.", hl( name ), hl( getn( sim.queue ) ) ) )
  end

  ---@param name string
  local function remove( name )
    if not require_player( name ) then return end

    local player = spelling( name )
    table.remove( sim.queue, find( name ) )
    sim.away[ player ] = nil

    m.info( string.format( "%s is out of the queue.", hl( player ) ) )
  end

  ---@param name string
  ---@param offset number
  local function move( name, offset )
    if not require_player( name ) then return end

    local position = find( name )
    local player = spelling( name )

    m.AutoRoundRobin.move( sim.queue, position, offset )

    local moved = find( name )

    if moved == position then
      m.info( string.format( "%s is already %s.", hl( player ), offset < 0 and "at the front" or "at the back" ) )
      return
    end

    m.info( string.format( "%s moves from place %s to %s.", hl( player ), hl( position ), hl( moved ) ) )
  end

  ---@param direction string
  local function cycle( direction )
    -- Up moves the list up, the same way the Queues window's buttons do.
    local offset = direction == "up" and 1 or direction == "down" and -1

    if not offset then
      m.info( string.format( "%s or %s?", hl( "cycle up" ), hl( "cycle down" ) ) )
      return
    end

    m.AutoRoundRobin.cycle( sim.queue, offset )
    m.info( string.format( "Cycled %s: %s.", hl( direction ), join( names() ) ) )
  end

  ---@param args string?
  local function run( args )
    local input = string.match( args or "", "^%s*(.-)%s*$" )
    local command = string.lower( string.match( input, "^(%S*)" ) or "" )
    local rest = string.match( input, "^%S*%s+(.*)$" ) or ""

    if command == "" then
      usage()
      return
    end

    if command == "raid" then
      start( rest )
      return
    end

    if command == "example" then
      worked_example()
      return
    end

    if command == "reset" then
      clear()
      m.info( "Simulation cleared." )
      return
    end

    if not require_started() then return end

    if command == "drop" then
      local count = tonumber( rest ) or 1

      if count < 1 then
        m.info( string.format( "%s is not a number of drops.", hl( rest ) ) )
        return
      end

      drop( count )
      return
    end

    if command == "queue" or command == "list" then
      report_queue()
      return
    end

    if command == "cycle" then
      cycle( string.lower( rest ) )
      return
    end

    if rest == "" then
      m.info( string.format( "%s needs a name.", hl( command ) ) )
      return
    end

    if command == "away" then
      set_away( rest, true )
      return
    end

    if command == "back" then
      set_away( rest, false )
      return
    end

    if command == "add" then
      add( rest )
      return
    end

    if command == "remove" then
      remove( rest )
      return
    end

    if command == "up" then
      move( rest, -1 )
      return
    end

    if command == "down" then
      move( rest, 1 )
      return
    end

    usage()
  end

  m.slash_cmd( "rfrotate", run )

  ---@type AutoRoundRobinSimulator
  return {
    run = run
  }
end

m.AutoRoundRobinSimulator = M
return M
