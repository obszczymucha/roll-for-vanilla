---@diagnostic disable: inject-field
package.path = "./?.lua;" .. package.path .. ";../../?.lua;../../RollFor/?.lua;../../RollFor/libs/?.lua"

require( "src/bcc/compat" )
local utils = require( "test/utils" )
local lu, eq = utils.luaunit( "assertEquals" )
require( "src/modules" )
require( "src/DebugBuffer" )
require( "src/Module" )
local Db = require( "src/Db" )
local ResistanceRegistry = require( "src/resistances/ResistanceRegistry" )
local ResistanceBonusRollEligibility = require( "src/resistances/ResistanceBonusRollEligibility" )

local getn = RollFor.getn

local Shadow = ResistanceRegistry.ResistanceType.Shadow
local Fire = ResistanceRegistry.ResistanceType.Fire

---@param name string
local function player( name )
  return { name = name, class = "Warrior", unit = "raid1" }
end

local function mock_roster( names )
  local players = {}

  for _, name in ipairs( names or { "Psikutas" } ) do
    table.insert( players, player( name ) )
  end

  local roster = {}
  roster.get_group_players = function() return players end

  roster.set_players = function( new_names )
    players = {}

    for _, name in ipairs( new_names ) do
      table.insert( players, player( name ) )
    end
  end

  return roster
end

-- Only get_rows is ever called on it, so that's all it answers.
---@param rows ResistanceRow[]?
local function mock_resistance_check( rows )
  local m_rows = rows or {}

  return {
    get_rows = function() return m_rows end,
    set_rows = function( new_rows ) m_rows = new_rows end
  }
end

-- A scanned row. personal is the reported school's number and personal_by_type
-- carries both, which is what the eligibility rule reads.
---@param name string
---@param fire number
---@param shadow number
local function scanned( name, fire, shadow )
  -- The same rule the resistance list uses to pick the school it reports.
  local resistance_type = fire > 150 and Fire or Shadow

  return {
    player_name = name,
    class = "Warrior",
    resistance_type = resistance_type,
    personal = resistance_type == Fire and fire or shadow,
    personal_by_type = { [ Fire ] = fire, [ Shadow ] = shadow },
    scanning = false,
    failed = false
  }
end

---@param name string
local function unscanned( name )
  return { player_name = name, class = "Warrior", scanning = false, failed = false }
end

---@param name string
---@param eligible boolean
---@param reason string
local function row( name, eligible, reason )
  return { player_name = name, class = "Warrior", eligible = eligible, reason = reason }
end

---@param options table?
local function eligibility( options )
  options = options or {}
  local roster = mock_roster( options.players )
  local resistance_check = mock_resistance_check( options.rows )
  -- The real thing, not a plain table: the saved db is a proxy that forwards
  -- reads and writes but has no keys of its own, and code that forgets that
  -- passes happily against a plain table.
  local saved = {}

  local sut = ResistanceBonusRollEligibility.new(
    Db.new( saved )( "eligibility" ),
    roster,
    resistance_check,
    ResistanceRegistry.new()
  )

  sut.roster = roster
  sut.resistance_check = resistance_check
  sut.stored = function() return saved.eligibility.players end

  return sut
end

EligibilitySpec = {}

function EligibilitySpec:should_report_nobody_as_eligible_before_anything_happens()
  -- An untouched database means nobody is eligible, not everybody.
  -- Given
  local sut = eligibility()

  -- Then
  eq( sut.is_eligible( "Psikutas" ), false )
  eq( sut.get( "Psikutas" ), nil )
end

function EligibilitySpec:should_list_the_whole_roster_as_not_scanned_before_anything_happens()
  -- Given
  local sut = eligibility( { players = { "Psikutas", "Obszczymucha" } } )

  -- Then
  eq( sut.get_rows(), {
    row( "Obszczymucha", false, "Not scanned" ),
    row( "Psikutas", false, "Not scanned" )
  } )
end

function EligibilitySpec:should_mark_a_player_eligible_by_hand()
  -- Given
  local sut = eligibility()

  -- When
  sut.set( "Psikutas", true )

  -- Then
  eq( sut.is_eligible( "Psikutas" ), true )
  eq( sut.get( "Psikutas" ), { eligible = true, reason = "Manual" } )
  eq( sut.get_rows(), { row( "Psikutas", true, "Manual" ) } )
end

function EligibilitySpec:should_mark_a_player_ineligible_by_hand()
  -- Given
  local sut = eligibility()
  sut.set( "Psikutas", true )

  -- When
  sut.set( "Psikutas", false )

  -- Then
  eq( sut.is_eligible( "Psikutas" ), false )
  eq( sut.get_rows(), { row( "Psikutas", false, "Manual" ) } )
end

function EligibilitySpec:should_keep_a_reason_the_caller_supplies()
  -- Given
  local sut = eligibility()

  -- When
  sut.set( "Psikutas", true, "Fire 300" )

  -- Then
  eq( sut.get( "Psikutas" ), { eligible = true, reason = "Fire 300" } )
end

function EligibilitySpec:should_infer_a_player_who_reaches_the_fire_minimum()
  -- 295 is fire's minimum, so 295 qualifies and 294 doesn't.
  -- Given
  local sut = eligibility( {
    players = { "Psikutas", "Obszczymucha" },
    rows = { scanned( "Psikutas", 295, 0 ), scanned( "Obszczymucha", 294, 0 ) }
  } )

  -- When
  sut.infer()

  -- Then
  eq( sut.get_rows(), {
    row( "Psikutas", true, "Fire 295" ),
    row( "Obszczymucha", false, "Fire 294" )
  } )
end

function EligibilitySpec:should_infer_a_player_who_reaches_the_shadow_minimum()
  -- 174 is shadow's minimum, so 174 qualifies and 173 doesn't.
  -- Given
  local sut = eligibility( {
    players = { "Psikutas", "Obszczymucha" },
    rows = { scanned( "Psikutas", 0, 174 ), scanned( "Obszczymucha", 0, 173 ) }
  } )

  -- When
  sut.infer()

  -- Then
  eq( sut.get_rows(), {
    row( "Psikutas", true, "Shadow 174" ),
    row( "Obszczymucha", false, "Shadow 173" )
  } )
end

function EligibilitySpec:should_qualify_a_player_on_a_school_the_resistance_list_doesnt_report()
  -- 160 fire is over the list's 150, so the list reports this player as Fire --
  -- and they fall well short of fire's 295. Their shadow gear clears shadow's
  -- 174 all the same. Judging the reported school alone would miss them.
  -- Given
  local sut = eligibility( { rows = { scanned( "Psikutas", 160, 180 ) } } )

  -- When
  sut.infer()

  -- Then
  eq( sut.is_eligible( "Psikutas" ), true )
  eq( sut.get_rows(), { row( "Psikutas", true, "Shadow 180" ) } )
end

function EligibilitySpec:should_describe_a_player_who_clears_both_minimums_by_fire()
  -- Fire is the set they're visibly wearing, so that's what the row says.
  -- Given
  local sut = eligibility( { rows = { scanned( "Psikutas", 302, 180 ) } } )

  -- When
  sut.infer()

  -- Then
  eq( sut.get_rows(), { row( "Psikutas", true, "Fire 302" ) } )
end

function EligibilitySpec:should_name_the_reported_school_when_a_player_falls_short_of_both()
  -- The list reports this one as Shadow, so that's the number the row explains
  -- itself with, even though their fire is higher in absolute terms.
  -- Given
  local sut = eligibility( { rows = { scanned( "Psikutas", 140, 150 ) } } )

  -- When
  sut.infer()

  -- Then
  eq( sut.get_rows(), { row( "Psikutas", false, "Shadow 150" ) } )
end

function EligibilitySpec:should_infer_an_unscanned_player_as_not_scanned()
  -- Given
  local sut = eligibility( { rows = { unscanned( "Psikutas" ) } } )

  -- When
  sut.infer()

  -- Then
  eq( sut.is_eligible( "Psikutas" ), false )
  eq( sut.get_rows(), { row( "Psikutas", false, "Not scanned" ) } )
end

function EligibilitySpec:should_overwrite_a_manual_yes_when_the_scan_says_otherwise()
  -- Manual toggles aren't sticky. Infer recomputes everyone from scratch and the
  -- reason column is what says where a row came from.
  -- Given
  local sut = eligibility( { rows = { scanned( "Psikutas", 100, 100 ) } } )
  sut.set( "Psikutas", true )

  -- When
  sut.infer()

  -- Then
  eq( sut.is_eligible( "Psikutas" ), false )
  eq( sut.get_rows(), { row( "Psikutas", false, "Shadow 100" ) } )
end

function EligibilitySpec:should_overwrite_a_manual_no_when_the_scan_says_otherwise()
  -- Given
  local sut = eligibility( { rows = { scanned( "Psikutas", 302, 0 ) } } )
  sut.set( "Psikutas", false )

  -- When
  sut.infer()

  -- Then
  eq( sut.is_eligible( "Psikutas" ), true )
  eq( sut.get_rows(), { row( "Psikutas", true, "Fire 302" ) } )
end

function EligibilitySpec:should_count_eligible_players()
  -- Given
  local sut = eligibility( { players = { "Psikutas", "Obszczymucha", "Bomanz" } } )

  -- Then
  eq( sut.count_eligible(), 0 )

  -- When
  sut.set( "Psikutas", true )
  sut.set( "Obszczymucha", true )
  sut.set( "Bomanz", false )

  -- Then
  eq( sut.count_eligible(), 2 )
end

function EligibilitySpec:should_count_eligible_players_who_left_the_group()
  -- Unlike get_rows, which is roster-scoped: reset drops the whole db, so a caller
  -- summarising what it wiped would understate it by counting only who's present.
  -- Given
  local sut = eligibility( { players = { "Psikutas", "Obszczymucha" } } )
  sut.set( "Psikutas", true )
  sut.set( "Obszczymucha", true )

  -- When
  sut.roster.set_players( { "Psikutas" } )

  -- Then
  eq( getn( sut.get_rows() ), 1 )
  eq( sut.count_eligible(), 2 )
end

function EligibilitySpec:should_count_nothing_after_a_reset()
  -- Given
  local sut = eligibility()
  sut.set( "Psikutas", true )

  -- When
  sut.reset()

  -- Then
  eq( sut.count_eligible(), 0 )
end

function EligibilitySpec:should_empty_everything_on_reset()
  -- The saved db is a proxy, so clearing it key by key silently does nothing.
  -- Given
  local sut = eligibility( { players = { "Psikutas", "Obszczymucha" } } )
  sut.set( "Psikutas", true )
  sut.set( "Obszczymucha", true )

  -- When
  sut.reset()

  -- Then
  eq( sut.stored(), {} )
  eq( sut.is_eligible( "Psikutas" ), false )
  eq( sut.get_rows(), {
    row( "Obszczymucha", false, "Not scanned" ),
    row( "Psikutas", false, "Not scanned" )
  } )
end

function EligibilitySpec:should_sort_eligible_players_first_then_by_name()
  -- Alphabetically these are Bomanz, Chuj, Obszczymucha, Psikutas -- a different
  -- name at every position below, so nothing here can pass on a name sort alone.
  -- Given
  local sut = eligibility( { players = { "Psikutas", "Bomanz", "Obszczymucha", "Chuj" } } )
  sut.set( "Psikutas", true )
  sut.set( "Obszczymucha", true )

  -- Then
  eq( sut.get_rows(), {
    row( "Obszczymucha", true, "Manual" ),
    row( "Psikutas", true, "Manual" ),
    row( "Bomanz", false, "Not scanned" ),
    row( "Chuj", false, "Not scanned" )
  } )
end

function EligibilitySpec:should_not_list_a_player_who_left_the_group_nor_forget_them()
  -- They may well be back before the next boss, so leaving drops them off the
  -- list without destroying what was decided about them.
  -- Given
  local sut = eligibility( { players = { "Psikutas", "Obszczymucha" } } )
  sut.set( "Obszczymucha", true )

  -- When
  sut.roster.set_players( { "Psikutas" } )

  -- Then
  eq( sut.get_rows(), { row( "Psikutas", false, "Not scanned" ) } )
  eq( sut.get( "Obszczymucha" ), { eligible = true, reason = "Manual" } )
  eq( sut.is_eligible( "Obszczymucha" ), true )

  -- When
  sut.roster.set_players( { "Psikutas", "Obszczymucha" } )

  -- Then
  eq( sut.get_rows(), {
    row( "Obszczymucha", true, "Manual" ),
    row( "Psikutas", false, "Not scanned" )
  } )
end

function EligibilitySpec:should_only_infer_players_the_resistance_check_reports()
  -- Given
  local sut = eligibility( {
    players = { "Psikutas", "Obszczymucha" },
    rows = { scanned( "Psikutas", 302, 0 ) }
  } )

  -- When
  sut.infer()

  -- Then
  eq( sut.get_rows(), {
    row( "Psikutas", true, "Fire 302" ),
    row( "Obszczymucha", false, "Not scanned" )
  } )
end

function EligibilitySpec:should_notify_listeners_on_set_infer_and_reset()
  -- Given
  local notifications = 0
  local sut = eligibility( { rows = { scanned( "Psikutas", 302, 0 ) } } )
  sut.subscribe( function() notifications = notifications + 1 end )

  -- When
  sut.set( "Psikutas", true )

  -- Then
  eq( notifications, 1 )

  -- When
  sut.infer()

  -- Then
  eq( notifications, 2 )

  -- When
  sut.reset()

  -- Then
  eq( notifications, 3 )
end

function EligibilitySpec:should_notify_every_listener()
  -- Given
  local first, second = 0, 0
  local sut = eligibility()
  sut.subscribe( function() first = first + 1 end )
  sut.subscribe( function() second = second + 1 end )

  -- When
  sut.reset()

  -- Then
  eq( first, 1 )
  eq( second, 1 )
end

os.exit( lu.LuaUnit.run() )
