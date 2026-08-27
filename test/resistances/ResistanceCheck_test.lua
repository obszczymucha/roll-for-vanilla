---@diagnostic disable: inject-field
package.path = "./?.lua;" .. package.path .. ";../../?.lua;../../RollFor/?.lua;../../RollFor/libs/?.lua"

require( "src/compat" )
local utils = require( "test/utils" )
local lu, eq = utils.luaunit( "assertEquals" )
require( "src/modules" )
require( "src/DebugBuffer" )
require( "src/Module" )
local Db = require( "src/Db" )
local ResistanceRegistry = require( "src/resistances/ResistanceRegistry" )
local ResistanceCheck = require( "src/resistances/ResistanceCheck" )

local Shadow = ResistanceRegistry.ResistanceType.Shadow
local Fire = ResistanceRegistry.ResistanceType.Fire

---@param name string
---@param unit string
local function player( name, unit )
  return { name = name, class = "Warrior", unit = unit }
end

-- Inspects don't come back on the same frame in the game, and the scanning flag
-- only exists because of that, so nothing here answers until the test says so.
local function mock_gear_scanner()
  local requests = {}

  local function pending( unit )
    for _, request in ipairs( requests ) do
      if request.unit == unit and not request.answered then return request end
    end

    error( string.format( "No pending scan for %s.", unit ), 3 )
  end

  return {
    scan_unit = function( unit, callback )
      table.insert( requests, { unit = unit, callback = callback } )
    end,
    scanned = function()
      local result = {}

      for _, request in ipairs( requests ) do
        table.insert( result, request.unit )
      end

      return result
    end,
    -- The parser is mocked too, so the "gear lines" are the totals.
    complete = function( unit, totals )
      local request = pending( unit )
      request.answered = true
      request.callback( totals or {} )
    end,
    fail = function( unit, error_type )
      local request = pending( unit )
      request.answered = true
      request.callback( nil, error_type or "timeout" )
    end
  }
end

-- buffs[ unit ] is a list of names; tooltips are keyed by buff name and only
-- handed back for the names the caller asked about.
local function mock_buff_scanner( buffs, tooltips )
  return {
    get_buffs = function( unit, tooltip_buffs )
      local result = {}

      for _, name in ipairs( buffs[ unit ] or {} ) do
        local buff = { name = name }

        if tooltip_buffs and tooltip_buffs[ name ] then
          buff.tooltip_data = tooltips and tooltips[ name ]
        end

        table.insert( result, buff )
      end

      return result
    end
  }
end

-- The real parser is covered by its own tests; here the "gear lines" are the
-- totals and a buff tooltip is just the number it grants. The neck's totals ride
-- along under a key of their own, because slot numbers and resistance types
-- share the same small integers and would otherwise collide.
local function mock_parser()
  return {
    parse = function( gear ) return gear end,
    parse_slot = function( gear ) return gear.neck or {} end,
    parse_all_schools = function( lines ) return lines and lines.all_schools or 0 end
  }
end

local function mock_roster( players )
  return { get_group_players = function() return players end }
end

---@param options table?
local function check( options )
  options = options or {}
  local buffs = options.buffs or {}
  local gear_scanner = mock_gear_scanner()
  -- The real thing, not a plain table: the saved db is a proxy that forwards
  -- reads and writes but has no keys of its own, and code that forgets that
  -- passes happily against a plain table.
  local saved = {}

  local sut = ResistanceCheck.new(
    Db.new( saved )( "resistance_check" ),
    mock_roster( options.players or { player( "Psikutas", "raid1" ) } ),
    gear_scanner,
    mock_buff_scanner( buffs, options.tooltips ),
    mock_parser(),
    ResistanceRegistry.new()
  )

  sut.buffs = buffs
  sut.gear_scanner = gear_scanner
  sut.cached_gear = function() return saved.resistance_check.gear end
  sut.cached_neck = function() return saved.resistance_check.neck end

  return sut
end

---@param name string
local function no_data( name )
  return { player_name = name, class = "Warrior", scanning = false, failed = false }
end

---@param name string
local function scanning( name )
  return { player_name = name, class = "Warrior", scanning = true, failed = false }
end

---@param name string
local function failed( name )
  return { player_name = name, class = "Warrior", scanning = false, failed = true }
end

-- Every gear table in this file names one school, so the other one is whatever
-- the food added and nothing else. Tests that gear both schools pass the pair
-- in explicitly.
---@param resistance_type ResistanceType
---@param personal number -- gear and food for the school that was geared
---@param food number? -- how much of personal came from food
local function by_type( resistance_type, personal, food )
  local other = resistance_type == Shadow and Fire or Shadow

  return { [ resistance_type ] = personal, [ other ] = food or 0 }
end

---@param name string
---@param resistance_type ResistanceType
---@param personal number -- gear and food
---@param total number
---@param food number? -- how much of personal came from food
local function food_data( name, resistance_type, personal, total, food )
  return {
    player_name = name,
    class = "Warrior",
    resistance_type = resistance_type,
    personal = personal,
    personal_by_type = by_type( resistance_type, personal, food ),
    total = total,
    food = food,
    -- Nothing here equips a neck, so every scanned row says so.
    missing_neck = true,
    scanning = false,
    failed = false
  }
end

---@param name string
---@param resistance_type ResistanceType
---@param personal number
---@param total number
---@param neck boolean? -- true when the required resistance neck is equipped
local function data( name, resistance_type, personal, total, neck )
  return {
    player_name = name,
    class = "Warrior",
    resistance_type = resistance_type,
    personal = personal,
    personal_by_type = by_type( resistance_type, personal ),
    total = total,
    -- The neck requirement is a shadow one, so a fire row never carries it.
    missing_neck = resistance_type == Shadow and not neck or nil,
    scanning = false,
    failed = false
  }
end

ResistanceCheckSpec = {}

function ResistanceCheckSpec:should_list_the_whole_group_with_no_data_before_any_scan()
  -- Given
  local sut = check( { players = { player( "Psikutas", "raid1" ), player( "Obszczymucha", "raid2" ) } } )

  -- Then
  eq( sut.get_rows(), { no_data( "Obszczymucha" ), no_data( "Psikutas" ) } )
end

function ResistanceCheckSpec:should_report_gear_as_personal_and_gear_plus_buff_as_total()
  -- Given
  local sut = check( { buffs = { [ "raid1" ] = { "Shadow Protection" } } } )

  -- When
  sut.scan()
  sut.gear_scanner.complete( "raid1", { [ Shadow ] = 60 } )

  -- Then
  eq( sut.get_rows(), { data( "Psikutas", Shadow, 60, 130 ) } )
end

function ResistanceCheckSpec:should_report_total_equal_to_personal_when_unbuffed()
  -- Given
  local sut = check()

  -- When
  sut.scan()
  sut.gear_scanner.complete( "raid1", { [ Shadow ] = 60 } )

  -- Then
  eq( sut.get_rows(), { data( "Psikutas", Shadow, 60, 60 ) } )
end

function ResistanceCheckSpec:should_switch_to_fire_for_a_fire_geared_player()
  -- Given
  local sut = check()

  -- When
  sut.scan()
  sut.gear_scanner.complete( "raid1", { [ Shadow ] = 0, [ Fire ] = 302 } )

  -- Then
  eq( sut.get_rows(), { data( "Psikutas", Fire, 302, 302 ) } )
end

function ResistanceCheckSpec:should_report_personal_for_both_schools_not_just_the_reported_one()
  -- The reported school is Fire only because the fire gear is over 150, but the
  -- shadow number is still there and callers that ask about shadow get it.
  -- Given
  local sut = check()

  -- When
  sut.scan()
  sut.gear_scanner.complete( "raid1", { [ Fire ] = 160, [ Shadow ] = 180 } )

  -- Then
  local row = sut.get_rows()[ 1 ]
  eq( row.resistance_type, Fire )
  eq( row.personal, 160 )
  eq( row.personal_by_type, { [ Fire ] = 160, [ Shadow ] = 180 } )
end

function ResistanceCheckSpec:should_count_food_towards_every_school_of_personal_by_type()
  -- Food is an all-schools buff, so it lands on both numbers, exactly as it
  -- already lands on the reported one.
  -- Given
  local sut = check( {
    buffs = { [ "raid1" ] = { "Well Fed" } },
    tooltips = { [ "Well Fed" ] = { all_schools = 8 } }
  } )

  -- When
  sut.scan()
  sut.gear_scanner.complete( "raid1", { [ Fire ] = 160, [ Shadow ] = 180 } )

  -- Then
  eq( sut.get_rows()[ 1 ].personal_by_type, { [ Fire ] = 168, [ Shadow ] = 188 } )
end

function ResistanceCheckSpec:should_mark_a_player_as_scanning_until_their_gear_arrives()
  -- Given
  local sut = check()

  -- When
  sut.scan()

  -- Then
  eq( sut.get_rows(), { scanning( "Psikutas" ) } )
  eq( sut.is_scanning(), true )

  -- When
  sut.gear_scanner.complete( "raid1", { [ Shadow ] = 60 } )

  -- Then
  eq( sut.get_rows(), { data( "Psikutas", Shadow, 60, 60 ) } )
  eq( sut.is_scanning(), false )
end

function ResistanceCheckSpec:should_not_be_scanning_before_the_first_scan()
  -- Given
  local sut = check()

  -- Then
  eq( sut.is_scanning(), false )
end

function ResistanceCheckSpec:should_only_scan_gear_once()
  -- Given
  local sut = check()

  -- When
  sut.scan()
  sut.gear_scanner.complete( "raid1", { [ Shadow ] = 60 } )
  sut.scan()

  -- Then
  eq( sut.gear_scanner.scanned(), { "raid1" } )
end

function ResistanceCheckSpec:should_not_queue_a_player_who_is_already_being_scanned()
  -- Given
  local sut = check()

  -- When
  sut.scan()
  sut.scan()

  -- Then
  eq( sut.gear_scanner.scanned(), { "raid1" } )
end

function ResistanceCheckSpec:should_scan_everyone_in_the_group()
  -- Given
  local sut = check( { players = { player( "Psikutas", "raid1" ), player( "Obszczymucha", "raid2" ) } } )

  -- When
  sut.scan()
  sut.gear_scanner.complete( "raid1", { [ Shadow ] = 60 } )
  sut.gear_scanner.complete( "raid2", { [ Shadow ] = 30 } )

  -- Then
  eq( sut.get_rows(), { data( "Psikutas", Shadow, 60, 60 ), data( "Obszczymucha", Shadow, 30, 30 ) } )
end

function ResistanceCheckSpec:should_reread_buffs_on_every_call()
  -- Buffs are free to read and change between pulls, so they aren't cached.
  -- Given
  local sut = check()

  sut.scan()
  sut.gear_scanner.complete( "raid1", { [ Shadow ] = 60 } )
  eq( sut.get_rows(), { data( "Psikutas", Shadow, 60, 60 ) } )

  -- When
  sut.buffs[ "raid1" ] = { "Shadow Protection" }

  -- Then
  eq( sut.get_rows(), { data( "Psikutas", Shadow, 60, 130 ) } )
end

function ResistanceCheckSpec:should_scan_a_cleared_player_again()
  -- Given
  local sut = check( { players = { player( "Psikutas", "raid1" ), player( "Obszczymucha", "raid2" ) } } )

  sut.scan()
  sut.gear_scanner.complete( "raid1", { [ Shadow ] = 60 } )
  sut.gear_scanner.complete( "raid2", { [ Shadow ] = 30 } )

  -- When
  sut.clear( "Psikutas" )

  -- Then
  eq( sut.get_rows(), { data( "Obszczymucha", Shadow, 30, 30 ), no_data( "Psikutas" ) } )

  -- When
  sut.scan()

  -- Then
  eq( sut.gear_scanner.scanned(), { "raid1", "raid2", "raid1" } )
end

function ResistanceCheckSpec:should_scan_everyone_again_after_clear_all()
  -- Given
  local sut = check( { players = { player( "Psikutas", "raid1" ), player( "Obszczymucha", "raid2" ) } } )

  sut.scan()
  sut.gear_scanner.complete( "raid1", { [ Shadow ] = 60 } )
  sut.gear_scanner.complete( "raid2", { [ Shadow ] = 30 } )

  -- When
  sut.clear_all()

  -- Then
  eq( sut.cached_gear(), {} )
  eq( sut.get_rows(), { no_data( "Obszczymucha" ), no_data( "Psikutas" ) } )

  -- When
  sut.scan()

  -- Then
  eq( sut.gear_scanner.scanned(), { "raid1", "raid2", "raid1", "raid2" } )
end

function ResistanceCheckSpec:should_not_cache_a_failed_scan_and_flag_the_row()
  -- Given
  local sut = check()

  -- When
  sut.scan()
  sut.gear_scanner.fail( "raid1", "cannot_inspect" )

  -- Then
  eq( sut.cached_gear(), {} )
  eq( sut.get_rows(), { failed( "Psikutas" ) } )

  -- When
  sut.scan()

  -- Then
  eq( sut.gear_scanner.scanned(), { "raid1", "raid1" } )
  eq( sut.get_rows(), { scanning( "Psikutas" ) } )
end

function ResistanceCheckSpec:should_clear_the_failed_flag_when_the_retry_succeeds()
  -- Given
  local sut = check()

  sut.scan()
  sut.gear_scanner.fail( "raid1", "timeout" )

  -- When
  sut.scan()
  sut.gear_scanner.complete( "raid1", { [ Shadow ] = 60 } )

  -- Then
  eq( sut.get_rows(), { data( "Psikutas", Shadow, 60, 60 ) } )
end

function ResistanceCheckSpec:should_clear_the_failed_flag_on_clear()
  -- Given
  local sut = check()

  sut.scan()
  sut.gear_scanner.fail( "raid1", "timeout" )

  -- When
  sut.clear( "Psikutas" )

  -- Then
  eq( sut.get_rows(), { no_data( "Psikutas" ) } )
end

function ResistanceCheckSpec:should_clear_the_failed_flag_on_clear_all()
  -- Given
  local sut = check()

  sut.scan()
  sut.gear_scanner.fail( "raid1", "timeout" )

  -- When
  sut.clear_all()

  -- Then
  eq( sut.get_rows(), { no_data( "Psikutas" ) } )
end

function ResistanceCheckSpec:should_notify_listeners_on_every_row_change()
  -- Given
  local notifications = 0
  local sut = check()
  sut.subscribe( function() notifications = notifications + 1 end )

  -- When
  sut.scan()

  -- Then
  eq( notifications, 1 )

  -- When
  sut.gear_scanner.complete( "raid1", { [ Shadow ] = 60 } )

  -- Then
  eq( notifications, 2 )

  -- When
  sut.clear( "Psikutas" )

  -- Then
  eq( notifications, 3 )

  -- When
  sut.clear_all()

  -- Then
  eq( notifications, 4 )
end

function ResistanceCheckSpec:should_notify_every_listener()
  -- Given
  local first, second = 0, 0
  local sut = check()
  sut.subscribe( function() first = first + 1 end )
  sut.subscribe( function() second = second + 1 end )

  -- When
  sut.clear_all()

  -- Then
  eq( first, 1 )
  eq( second, 1 )
end

function ResistanceCheckSpec:should_sort_rows_by_personal_resistance_descending()
  -- Every key in the comparator is pinned by a pair that only that key orders
  -- correctly:
  --   Elizalee / Rikus         -- Rikus has the bigger total, Elizalee the
  --                               bigger gear, so this only comes out right if
  --                               gear leads.
  --   Obszczymucha / Jogobobek -- same gear, split by the buff, and in the
  --                               opposite order to their names.
  --   Mendunia / Trololoo      -- identical in every value, so only the name
  --                               is left.
  --   Bomanz                   -- no data at all, so last.
  -- Alphabetically these are Bomanz, Chuj, Elizalee, Jogobobek, Mendunia,
  -- Obszczymucha, Rikus, Trololoo: a different name at every position below,
  -- so nothing here can pass on a name sort.
  -- Given
  local sut = check( {
    players = {
      player( "Trololoo", "raid1" ),
      player( "Rikus", "raid2" ),
      player( "Bomanz", "raid3" ),
      player( "Chuj", "raid8" ),
      player( "Jogobobek", "raid4" ),
      player( "Elizalee", "raid5" ),
      player( "Obszczymucha", "raid6" ),
      player( "Mendunia", "raid7" )
    },
    buffs = {
      [ "raid2" ] = { "Shadow Protection" },
      [ "raid6" ] = { "Shadow Protection" }
    }
  } )

  -- When
  sut.scan()
  sut.gear_scanner.complete( "raid1", { [ Shadow ] = 60 } )
  sut.gear_scanner.complete( "raid2", { [ Shadow ] = 100 } )
  sut.gear_scanner.fail( "raid3", "cannot_inspect" )
  sut.gear_scanner.complete( "raid4", { [ Shadow ] = 90 } )
  sut.gear_scanner.complete( "raid5", { [ Shadow ] = 130 } )
  sut.gear_scanner.complete( "raid6", { [ Shadow ] = 90 } )
  sut.gear_scanner.complete( "raid7", { [ Shadow ] = 60 } )
  sut.gear_scanner.complete( "raid8", { [ Shadow ] = 95 } )

  -- Then
  eq( sut.get_rows(), {
    data( "Elizalee", Shadow, 130, 130 ),
    -- Out in front on total, behind on gear, and gear is what orders the list.
    data( "Rikus", Shadow, 100, 170 ),
    data( "Chuj", Shadow, 95, 95 ),
    -- Same gear as Jogobobek, buffed, so the total breaks the tie.
    data( "Obszczymucha", Shadow, 90, 160 ),
    data( "Jogobobek", Shadow, 90, 90 ),
    -- Nothing left to separate these two but their names.
    data( "Mendunia", Shadow, 60, 60 ),
    data( "Trololoo", Shadow, 60, 60 ),
    failed( "Bomanz" )
  } )
end

function ResistanceCheckSpec:should_wipe_the_saved_gear_cache_on_clear_all()
  -- The saved db is a proxy, so clearing it key by key silently does nothing.
  -- Given
  local sut = check( { players = { player( "Psikutas", "raid1" ), player( "Obszczymucha", "raid2" ) } } )

  sut.scan()
  sut.gear_scanner.complete( "raid1", { [ Shadow ] = 60 } )
  sut.gear_scanner.complete( "raid2", { [ Shadow ] = 30 } )
  eq( sut.cached_gear(), { [ "Psikutas" ] = { [ Shadow ] = 60 }, [ "Obszczymucha" ] = { [ Shadow ] = 30 } } )

  -- When
  sut.clear_all()

  -- Then
  eq( sut.cached_gear(), {} )
end

function ResistanceCheckSpec:should_count_food_towards_personal_and_total()
  -- 60 gear + 8 food is what the player brings; the raid buff goes on top of
  -- that. Food is reported on its own as well, so the GUI can mark it.
  -- Given
  local sut = check( {
    buffs = { [ "raid1" ] = { "Well Fed", "Shadow Protection" } },
    tooltips = { [ "Well Fed" ] = { all_schools = 8 } }
  } )

  -- When
  sut.scan()
  sut.gear_scanner.complete( "raid1", { [ Shadow ] = 60 } )

  -- Then
  local row = sut.get_rows()[ 1 ]
  eq( row.personal, 68 )
  eq( row.total, 138 )
  eq( row.food, 8 )
end

function ResistanceCheckSpec:should_count_food_for_an_unbuffed_player()
  -- Given
  local sut = check( {
    buffs = { [ "raid1" ] = { "Well Fed" } },
    tooltips = { [ "Well Fed" ] = { all_schools = 8 } }
  } )

  -- When
  sut.scan()
  sut.gear_scanner.complete( "raid1", { [ Shadow ] = 60 } )

  -- Then
  eq( sut.get_rows(), { food_data( "Psikutas", Shadow, 68, 68, 8 ) } )
end

function ResistanceCheckSpec:should_leave_food_unset_for_a_player_who_is_not_well_fed()
  -- Given
  local sut = check( { buffs = { [ "raid1" ] = { "Shadow Protection" } } } )

  -- When
  sut.scan()
  sut.gear_scanner.complete( "raid1", { [ Shadow ] = 60 } )

  -- Then
  eq( sut.get_rows(), { data( "Psikutas", Shadow, 60, 130 ) } )
end

function ResistanceCheckSpec:should_report_a_neck_that_meets_the_requirement()
  -- Given
  local sut = check()

  -- When
  sut.scan()
  sut.gear_scanner.complete( "raid1", { [ Shadow ] = 60, neck = { [ Shadow ] = 40 } } )

  -- Then
  eq( sut.get_rows(), { data( "Psikutas", Shadow, 60, 60, true ) } )
end

function ResistanceCheckSpec:should_report_a_neck_that_falls_short_as_missing()
  -- Given
  local sut = check()

  -- When
  sut.scan()
  sut.gear_scanner.complete( "raid1", { [ Shadow ] = 60, neck = { [ Shadow ] = 39 } } )

  -- Then
  eq( sut.get_rows(), { data( "Psikutas", Shadow, 60, 60 ) } )
end

function ResistanceCheckSpec:should_say_nothing_about_the_shadow_neck_of_a_fire_geared_player()
  -- A fire set comes with a fire neck, which has no shadow resistance on it. The
  -- row reports fire, so the shadow neck requirement isn't theirs to fail.
  -- Given
  local sut = check()

  -- When
  sut.scan()
  sut.gear_scanner.complete( "raid1", { [ Shadow ] = 0, [ Fire ] = 302, neck = { [ Fire ] = 30 } } )

  -- Then
  eq( sut.get_rows()[ 1 ].missing_neck, nil )
end

function ResistanceCheckSpec:should_say_nothing_about_the_neck_of_a_player_scanned_before_it_was_tracked()
  -- Gear cached by an older version has no neck entry, which is not the same as
  -- having scanned an empty neck slot.
  -- Given
  local sut = check()

  -- When
  sut.scan()
  sut.gear_scanner.complete( "raid1", { [ Shadow ] = 60 } )
  sut.cached_neck()[ "Psikutas" ] = nil

  -- Then
  eq( sut.get_rows()[ 1 ].missing_neck, nil )
end

function ResistanceCheckSpec:should_forget_the_neck_along_with_the_gear()
  -- Given
  local sut = check()
  sut.scan()
  sut.gear_scanner.complete( "raid1", { [ Shadow ] = 60, neck = { [ Shadow ] = 40 } } )

  -- When
  sut.clear( "Psikutas" )

  -- Then
  eq( sut.cached_neck(), {} )
end

function ResistanceCheckSpec:should_forget_every_neck_when_clearing_all()
  -- Given
  local sut = check()
  sut.scan()
  sut.gear_scanner.complete( "raid1", { [ Shadow ] = 60, neck = { [ Shadow ] = 40 } } )

  -- When
  sut.clear_all()

  -- Then
  eq( sut.cached_neck(), {} )
end

os.exit( lu.LuaUnit.run() )
