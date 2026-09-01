RollFor = RollFor or {}
local m = RollFor

if m.AutoRoundRobinSimulator then return end

local M = {}

local getn = m.getn
local hl = m.colors.hl
local grey = m.colors.grey
local blue = m.colors.blue

-- Dev harness for the round-robin rotation. It runs the shipped selection algorithm
-- (AutoRoundRobin.seed / select / commit -- the same three functions the award pass calls) over
-- a scratch roster, so who wins, when the cycle turns over and what an absence costs can all be
-- watched solo, without a raid, a loot window or master loot.
--
--   /rfrotate raid Ann,Bob,Cid  start a simulation with these players
--   /rfrotate raid 5            ...or five generated ones
--   /rfrotate raid              ...or the live rotation and your current group, copied
--   /rfrotate drop [n]          run n drops (default 1) and trace each one
--   /rfrotate out <name>        in the group, but not a master loot candidate right now
--   /rfrotate in <name>         can receive again
--   /rfrotate join <name>       joins mid-cycle
--   /rfrotate leave <name>      leaves the group (stays in the pool, as the real one does)
--   /rfrotate queue             the standings, in the queue window's own words
--   /rfrotate example           replay the worked example from specs/AUTO-RAID-ROLL.md
--   /rfrotate reset             start over
--
-- This is the /rfdrop end of the scale, not the /rfsetup end: it never touches the live
-- rotation, the real roster or the loot pipeline. `raid` with no arguments copies the live
-- cycle and pool in, which is the one place the two meet, and even that is a copy -- nothing
-- the simulator does is ever written back.
--
-- What it therefore does not exercise: GiveMasterLoot, the announcement, the loot-history
-- record and the auto-loot precedence check. None of those can run solo anyway -- you cannot
-- master loot to yourself alone -- and all of them are covered in AutoRoundRobinSpec_test.

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
---@param random_fn fun( n: number ): number? -- injectable so the trace is reproducible in tests
---@return AutoRoundRobinSimulator
function M.new( round_robin_db, group_roster, random_fn )
  local random = random_fn or function( n ) return m.lua.math.random( 1, n ) end

  -- The whole simulation. `state` is a real RoundRobinState and is the only thing the shipped
  -- algorithm ever sees; the rest is what the game would otherwise be telling it.
  local sim

  local function clear()
    sim = {
      ---@type RoundRobinState
      state = { cycle = 1, pool = {} },
      roster = {}, -- who is in the group
      absent = {}, -- of those, who is not a master loot candidate right now
      drops = 0
    }
  end

  clear()

  ---@return boolean
  local function started()
    return getn( sim.roster ) > 0
  end

  local function require_started()
    if started() then return true end

    m.info( string.format( "No simulated raid yet. Start one with %s.", hl( "/rfrotate raid <names>" ) ) )
    return false
  end

  -- Case-insensitively, so a name typed in a hurry still finds its player.
  ---@param name string
  ---@return string? -- the roster's own spelling of it
  local function find( name )
    local needle = string.lower( name )

    for _, player in ipairs( sim.roster ) do
      if string.lower( player ) == needle then return player end
    end
  end

  ---@param name string
  local function add( name )
    if find( name ) then return end

    table.insert( sim.roster, name )
    table.sort( sim.roster )
  end

  -- Who could actually receive right now: in the group, and a master loot candidate. This is the
  -- distinction the whole design turns on, so it's the one thing the simulator has to model.
  ---@return string[]
  local function candidates()
    local result = {}

    for _, player in ipairs( sim.roster ) do
      if not sim.absent[ player ] then table.insert( result, player ) end
    end

    return result
  end

  -- Where a player stands, in the queue window's own words. The cycle is a parameter because the
  -- trace reads a winner against the cycle they are being paid for, which on a turnover is not
  -- the one that was current when they were picked -- against that one they'd read "Received",
  -- which is the opposite of why they just won.
  ---@param name string
  ---@param cycle number?
  ---@return string
  local function describe_place( name, cycle )
    local served = sim.state.pool[ name ]
    if not served then return grey( "not in the pool" ) end

    return m.AutoRoundRobinQueueFrameContentTransformer.status( (cycle or sim.state.cycle) - served )
  end

  -- One drop, traced. The three calls below are the shipped algorithm verbatim -- the simulator
  -- decides who is standing where and nothing else.
  ---@return boolean -- whether the drop went anywhere
  local function drop_once()
    local eligible = candidates()

    if getn( eligible ) == 0 then
      m.info( string.format( "  %s. %s", sim.drops + 1, grey( "Nobody eligible -- the drop is skipped and the rotation stays put." ) ) )
      return false
    end

    local before = sim.state.cycle
    local winner, cycle = m.AutoRoundRobin.select( sim.state, eligible, random )
    if not winner then return false end

    -- How many were tied at the front, recomputed for the trace only -- select() doesn't report
    -- it, and a one-line "why" is most of what makes a trace worth reading.
    local min_served
    for _, name in ipairs( eligible ) do
      local served = sim.state.pool[ name ]
      if not min_served or served < min_served then min_served = served end
    end

    local tied = 0
    for _, name in ipairs( eligible ) do
      if sim.state.pool[ name ] == min_served then tied = tied + 1 end
    end

    local owed = describe_place( winner, cycle )
    m.AutoRoundRobin.commit( sim.state, winner, cycle )
    sim.drops = sim.drops + 1

    local why = tied == 1 and "only one owed" or string.format( "drawn from %s tied", tied )
    local turnover = cycle ~= before and string.format( "; cycle %s -> %s", before, hl( cycle ) ) or ""

    m.info( string.format( "  %s. %s -- %s, %s%s", sim.drops, hl( winner ), owed, why, turnover ) )

    return true
  end

  ---@param count number
  local function drop( count )
    m.info( string.format( "%s %s among %s:", hl( count ), count == 1 and "drop" or "drops",
      join( candidates() ) ) )

    for _ = 1, count do drop_once() end
  end

  local function report_queue()
    m.info( string.format( "Cycle %s, %s %s so far:", hl( sim.state.cycle ), hl( sim.drops ),
      sim.drops == 1 and "drop" or "drops" ) )

    -- Owed the most first, then by name -- the same order the queue window lists them in.
    local rows = {}

    for _, player in ipairs( sim.roster ) do
      local served = sim.state.pool[ player ] or sim.state.cycle
      table.insert( rows, { name = player, served = served, behind = sim.state.cycle - served } )
    end

    table.sort( rows, function( lhs, rhs )
      if lhs.served ~= rhs.served then return lhs.served < rhs.served end

      return lhs.name < rhs.name
    end )

    for _, row in ipairs( rows ) do
      local status = m.AutoRoundRobinQueueFrameContentTransformer.status( row.behind )
      local out = sim.absent[ row.name ] and grey( " (out of range)" ) or ""

      m.info( string.format( "  %s -- %s%s", hl( row.name ), status, out ) )
    end

    -- Everyone the pool remembers who isn't standing here any more. The real pool keeps them
    -- forever, which is what lets them walk back in still owed, so the simulator says so rather
    -- than quietly dropping them.
    local gone = {}

    for name in pairs( sim.state.pool ) do
      if not find( name ) then table.insert( gone, name ) end
    end

    table.sort( gone )

    if getn( gone ) > 0 then
      m.info( string.format( "  %s", grey( string.format( "Still in the pool, not in the group: %s", join( gone ) ) ) ) )
    end
  end

  ---@param names string[]
  local function start_with( names )
    clear()

    for _, name in ipairs( names ) do add( name ) end

    -- The roster update the real thing does on GROUP_ROSTER_UPDATE: everybody unknown goes in at
    -- the current cycle.
    m.AutoRoundRobin.seed( sim.state, sim.roster )

    m.info( string.format( "Simulating %s: %s.", hl( string.format( "%s players", getn( sim.roster ) ) ),
      join( sim.roster ) ) )
    m.info( string.format( "Everybody seeded at cycle %s. %s", hl( sim.state.cycle ),
      grey( "The first drop turns it over." ) ) )
  end

  -- The live rotation, copied. Read-only in both directions: the simulator never writes back, and
  -- what it copies is a snapshot, so a real award landing mid-simulation doesn't disturb it.
  local function start_from_live()
    local names = {}

    for _, player in ipairs( group_roster.get_all_players_in_my_group() ) do
      table.insert( names, player.name )
    end

    if getn( names ) == 0 then
      m.info( "Nobody in your group to copy." )
      return
    end

    clear()

    for _, name in ipairs( names ) do add( name ) end

    sim.state.cycle = round_robin_db.cycle or 1

    for name, served in pairs( round_robin_db.pool or {} ) do
      sim.state.pool[ name ] = served
    end

    m.AutoRoundRobin.seed( sim.state, sim.roster )

    m.info( string.format( "Copied the live rotation: cycle %s, %s in the pool, %s in the group.",
      hl( sim.state.cycle ), hl( m.count_elements( sim.state.pool ) ), hl( getn( sim.roster ) ) ) )
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

      local names = {}
      for i = 1, count do table.insert( names, GENERATED_NAMES[ i ] ) end
      start_with( names )

      return
    end

    local names = split_names( raw )

    if getn( names ) == 0 then
      m.info( string.format( "Give me names, a count, or nothing at all. %s", grey( "/rfrotate raid Ann,Bob,Cid" ) ) )
      return
    end

    start_with( names )
  end

  -- The subtle half of the design, played out: an absent player's number stops climbing while
  -- everybody else's does, so the rotation never stalls on them and they win outright on return.
  local function worked_example()
    m.info( blue( "Worked example -- four players, one of them outside the instance." ) )
    start_with( { "Ann", "Bob", "Cid", "Dee" } )

    sim.absent[ "Dee" ] = true
    m.info( string.format( "%s is outside the instance, so the loot window never lists her.", hl( "Dee" ) ) )

    drop( 4 )

    m.info( string.format( "Four drops in and %s is still owed from cycle 1 -- the other three have gone round twice.",
      hl( "Dee" ) ) )
    report_queue()

    sim.absent[ "Dee" ] = nil
    m.info( string.format( "%s walks in.", hl( "Dee" ) ) )

    drop( 1 )
    m.info( grey( "She held the lowest number, so she won without a draw and without a reset." ) )
  end

  local function usage()
    m.info( string.format( "%s -- simulate the round-robin rotation solo.", hl( "/rfrotate" ) ) )
    m.info( string.format( "  %s -- start with these players, that many, or your live rotation.",
      hl( "raid <names or count>" ) ) )
    m.info( string.format( "  %s -- run n drops (default 1).", hl( "drop [n]" ) ) )
    m.info( string.format( "  %s -- in the group, but out of range.", hl( "out <name>" ) ) )
    m.info( string.format( "  %s -- can receive again.", hl( "in <name>" ) ) )
    m.info( string.format( "  %s -- joins mid-cycle.", hl( "join <name>" ) ) )
    m.info( string.format( "  %s -- leaves the group.", hl( "leave <name>" ) ) )
    m.info( string.format( "  %s -- the standings.", hl( "queue" ) ) )
    m.info( string.format( "  %s -- replay the worked example.", hl( "example" ) ) )
    m.info( string.format( "  %s -- start over.", hl( "reset" ) ) )
  end

  ---@param name string
  local function go_out( name )
    local player = find( name )

    if not player then
      m.info( string.format( "%s is not in the simulated group.", hl( name ) ) )
      return
    end

    sim.absent[ player ] = true
    m.info( string.format( "%s is out of range -- still in the rotation, just not a candidate. %s",
      hl( player ), grey( describe_place( player ) ) ) )
  end

  ---@param name string
  local function come_in( name )
    local player = find( name )

    if not player then
      m.info( string.format( "%s is not in the simulated group.", hl( name ) ) )
      return
    end

    sim.absent[ player ] = nil
    m.info( string.format( "%s can receive again. %s", hl( player ), grey( describe_place( player ) ) ) )
  end

  ---@param name string
  local function join_group( name )
    if find( name ) then
      m.info( string.format( "%s is already in the simulated group.", hl( name ) ) )
      return
    end

    add( name )
    -- Exactly what a real roster update does, which is why a joiner lands at the bottom.
    m.AutoRoundRobin.seed( sim.state, { name } )

    local player = find( name )
    m.info( string.format( "%s joins during cycle %s. %s", hl( player ), hl( sim.state.cycle ),
      grey( "Seeded as already served, so they wait for the next one." ) ) )
  end

  ---@param name string
  local function leave_group( name )
    local player = find( name )

    if not player then
      m.info( string.format( "%s is not in the simulated group.", hl( name ) ) )
      return
    end

    for i = 1, getn( sim.roster ) do
      if sim.roster[ i ] == player then
        table.remove( sim.roster, i )
        break
      end
    end

    sim.absent[ player ] = nil

    m.info( string.format( "%s leaves. %s", hl( player ),
      grey( "The pool keeps them, so rejoining keeps their place." ) ) )
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

    if rest == "" then
      m.info( string.format( "%s needs a name.", hl( command ) ) )
      return
    end

    if command == "out" then
      go_out( rest )
      return
    end

    if command == "in" then
      come_in( rest )
      return
    end

    if command == "join" then
      join_group( rest )
      return
    end

    if command == "leave" then
      leave_group( rest )
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
