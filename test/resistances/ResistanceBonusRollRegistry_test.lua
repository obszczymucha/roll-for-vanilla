---@diagnostic disable: inject-field
package.path = "./?.lua;" .. package.path .. ";../../?.lua;../../RollFor/?.lua;../../RollFor/libs/?.lua"

require( "src/bcc/compat" )
local u = require( "test/utils" )
local lu, eq = u.luaunit( "assertEquals" )
require( "src/modules" )
require( "src/DebugBuffer" )
require( "src/Module" )
local Db = require( "src/Db" )
require( "src/AutoLootDb" )
local ResistanceBonusRollRegistry = require( "src/resistances/ResistanceBonusRollRegistry" )

u.mock_wow_api()

local SHAHRAZ = "Mother Shahraz"
local COUNCIL = "The Illidari Council"
local ILLIDAN = "Illidan Stormrage"

-- Frozen, so entries can be asserted whole rather than "some number near now".
local NOW = 1700000000

-- Stands in for BossKilled: the registry only ever subscribes to it.
local function mock_boss_killed()
  local listeners = {}

  return {
    subscribe = function( listener ) table.insert( listeners, listener ) end,
    kill = function( boss_name )
      for _, listener in ipairs( listeners ) do listener( boss_name ) end
    end
  }
end

-- Stands in for ResistanceBonusRollEligibility: the registry only reads get_rows.
---@param rows table[]?
local function mock_eligibility( rows )
  local m_rows = rows or {}

  return {
    get_rows = function() return m_rows end,
    set_rows = function( new_rows ) m_rows = new_rows end
  }
end

---@param name string
---@param eligible boolean
local function player( name, eligible )
  return { player_name = name, class = "Warrior", eligible = eligible, reason = "Manual" }
end

---@param boss_name string
---@param timestamp number?
---@param class PlayerClass? -- every grant in this file is Warrior unless stated otherwise
local function entry( boss_name, timestamp, class )
  return { boss_name = boss_name, class = class or "Warrior", timestamp = timestamp or NOW }
end

---@param rows table[]?
local function registry( rows )
  -- The real thing, not a plain table: the saved db is a proxy that forwards reads and
  -- writes but has no keys of its own, and code that forgets that passes happily
  -- against a plain table.
  local saved = {}
  local boss_killed = mock_boss_killed()
  local eligibility = mock_eligibility( rows )

  RollFor.lua.time = function() return NOW end

  local sut = ResistanceBonusRollRegistry.new( Db.new( saved )( "registry" ), boss_killed, eligibility )

  sut.boss_killed = boss_killed
  sut.eligibility = eligibility
  sut.stored = function() return saved.registry.players end

  -- What the addon printed, with the "RollFor: " prefix and the colors stripped --
  -- neither is what these tests are about.
  sut.printed = {}

  RollFor.api.DEFAULT_CHAT_FRAME = {
    AddMessage = function( _, message )
      local plain = u.decolorize( message ) or message
      table.insert( sut.printed, (string.gsub( plain, "^RollFor: ", "" )) )
    end
  }

  return sut
end

BonusRollRegistrySpec = {}

function BonusRollRegistrySpec:should_start_empty()
  -- Given
  local sut = registry()

  -- Then
  eq( sut.count( "Psikutas" ), 0 )
  eq( sut.get( "Psikutas" ), {} )
  eq( sut.get_rows(), {} )
end

function BonusRollRegistrySpec:should_grant_a_roll_to_every_eligible_player_on_a_granting_kill()
  -- Given
  local sut = registry( { player( "Psikutas", true ), player( "Obszczymucha", true ) } )

  -- When
  sut.boss_killed.kill( ILLIDAN )

  -- Then
  eq( sut.count( "Psikutas" ), 1 )
  eq( sut.count( "Obszczymucha" ), 1 )
end

function BonusRollRegistrySpec:should_not_grant_a_roll_to_an_ineligible_player()
  -- Given
  local sut = registry( { player( "Psikutas", true ), player( "Obszczymucha", false ) } )

  -- When
  sut.boss_killed.kill( ILLIDAN )

  -- Then
  eq( sut.count( "Psikutas" ), 1 )
  eq( sut.count( "Obszczymucha" ), 0 )
end

function BonusRollRegistrySpec:should_grant_for_each_of_the_three_bosses()
  -- Given
  local sut = registry( { player( "Psikutas", true ) } )

  -- When
  sut.boss_killed.kill( SHAHRAZ )
  sut.boss_killed.kill( COUNCIL )
  sut.boss_killed.kill( ILLIDAN )

  -- Then
  eq( sut.count( "Psikutas" ), 3 )
end

function BonusRollRegistrySpec:should_not_grant_for_any_other_boss()
  -- Given
  local sut = registry( { player( "Psikutas", true ) } )

  -- When
  sut.boss_killed.kill( "Teron Gorefiend" )
  sut.boss_killed.kill( "Lady Vashj" )
  sut.boss_killed.kill( "Gurtogg Bloodboil" )

  -- Then
  eq( sut.count( "Psikutas" ), 0 )
  eq( sut.printed, {} )
end

function BonusRollRegistrySpec:should_store_each_roll_as_its_own_entry()
  -- A count answers "how many" and nothing else. The entries also say which boss paid
  -- for each one and when.
  -- Given
  local sut = registry( { player( "Psikutas", true ) } )

  -- When
  sut.boss_killed.kill( SHAHRAZ )
  sut.boss_killed.kill( ILLIDAN )

  -- Then
  eq( sut.get( "Psikutas" ), { entry( SHAHRAZ ), entry( ILLIDAN ) } )
  eq( sut.stored(), { [ "Psikutas" ] = { entry( SHAHRAZ ), entry( ILLIDAN ) } } )
end

function BonusRollRegistrySpec:should_stamp_every_roll_from_one_kill_with_the_same_time()
  -- They were earned by the same event, and reading them back should say so.
  -- Given
  local sut = registry( { player( "Psikutas", true ), player( "Obszczymucha", true ) } )

  -- When
  sut.boss_killed.kill( ILLIDAN )

  -- Then
  eq( sut.get( "Psikutas" )[ 1 ].timestamp, NOW )
  eq( sut.get( "Obszczymucha" )[ 1 ].timestamp, sut.get( "Psikutas" )[ 1 ].timestamp )
end

function BonusRollRegistrySpec:should_announce_a_kills_payout_in_one_line()
  -- A kill pays out to the whole raid at once, so it gets one line and not one per
  -- player. Who they were is what the /rfbr list is for.
  -- Given
  local sut = registry( { player( "Psikutas", true ), player( "Obszczymucha", true ) } )

  -- When
  sut.boss_killed.kill( ILLIDAN )

  -- Then
  eq( sut.printed, { "Bonus Roll granted to 2 players." } )
end

function BonusRollRegistrySpec:should_say_player_singular_when_a_kill_pays_out_to_one()
  -- Given
  local sut = registry( { player( "Psikutas", true ), player( "Obszczymucha", false ) } )

  -- When
  sut.boss_killed.kill( ILLIDAN )

  -- Then
  eq( sut.printed, { "Bonus Roll granted to 1 player." } )
end

function BonusRollRegistrySpec:should_grant_by_hand()
  -- Given
  local sut = registry()

  -- When
  sut.grant( "Psikutas", ILLIDAN, "Warrior", NOW )

  -- Then
  eq( sut.get( "Psikutas" ), { entry( ILLIDAN ) } )
  eq( sut.printed, { "Bonus Roll granted to Psikutas (1 total)." } )
end

function BonusRollRegistrySpec:should_stamp_a_hand_granted_roll_with_the_current_time()
  -- Given
  local sut = registry()

  -- When
  sut.grant( "Psikutas", ILLIDAN, "Warrior" )

  -- Then
  eq( sut.get( "Psikutas" ), { entry( ILLIDAN, NOW ) } )
end

function BonusRollRegistrySpec:should_grant_again_when_eligibility_changes_between_kills()
  -- Eligibility is read at the moment of the kill, not cached.
  -- Given
  local sut = registry( { player( "Psikutas", true ), player( "Obszczymucha", false ) } )
  sut.boss_killed.kill( SHAHRAZ )

  -- When
  sut.eligibility.set_rows( { player( "Psikutas", false ), player( "Obszczymucha", true ) } )
  sut.boss_killed.kill( ILLIDAN )

  -- Then
  eq( sut.get( "Psikutas" ), { entry( SHAHRAZ ) } )
  eq( sut.get( "Obszczymucha" ), { entry( ILLIDAN ) } )
end

function BonusRollRegistrySpec:should_grant_nothing_when_nobody_is_eligible()
  -- Said out loud rather than passed over in silence: a granting boss dying with nobody
  -- eligible almost always means the scan was never run, and silence is how you find
  -- that out after the loot is gone.
  -- Given
  local sut = registry( { player( "Psikutas", false ), player( "Obszczymucha", false ) } )

  -- When
  sut.boss_killed.kill( ILLIDAN )

  -- Then
  eq( sut.get_rows(), {} )
  eq( sut.printed, { "No one is eligible for a Bonus Roll. Run Infer in /rfbonus." } )
end

function BonusRollRegistrySpec:should_list_players_most_rolls_first_then_by_name()
  -- Alphabetically these are Bomanz, Obszczymucha, Psikutas -- a different name at
  -- every position below, so nothing here can pass on a name sort alone.
  -- Given
  local sut = registry()
  sut.grant( "Bomanz", ILLIDAN, "Warrior" )
  sut.grant( "Psikutas", SHAHRAZ, "Warrior" )
  sut.grant( "Psikutas", COUNCIL, "Warrior" )
  sut.grant( "Psikutas", ILLIDAN, "Warrior" )
  sut.grant( "Obszczymucha", SHAHRAZ, "Warrior" )
  sut.grant( "Obszczymucha", ILLIDAN, "Warrior" )

  -- Then
  eq( u.map( sut.get_rows(), function( row ) return { row.player_name, row.count } end ), {
    { "Psikutas", 3 },
    { "Obszczymucha", 2 },
    { "Bomanz", 1 }
  } )
end

function BonusRollRegistrySpec:should_print_the_list()
  -- Given
  local sut = registry()
  sut.grant( "Psikutas", SHAHRAZ, "Warrior" )
  sut.grant( "Psikutas", ILLIDAN, "Warrior" )
  sut.grant( "Obszczymucha", ILLIDAN, "Warrior" )
  sut.printed = {}
  RollFor.api.DEFAULT_CHAT_FRAME.AddMessage = function( _, message )
    table.insert( sut.printed, (string.gsub( u.decolorize( message ) or message, "^RollFor: ", "" )) )
  end

  -- When
  sut.list()

  -- Then
  eq( sut.printed, {
    "Bonus rolls:",
    "  Psikutas: 2",
    "  Obszczymucha: 1"
  } )
end

function BonusRollRegistrySpec:should_say_so_when_there_is_nothing_to_list()
  -- Given
  local sut = registry()

  -- When
  sut.list()

  -- Then
  eq( sut.printed, { "No bonus rolls granted yet." } )
end

function BonusRollRegistrySpec:should_empty_everything_on_reset()
  -- The saved db is a proxy, so clearing it key by key silently does nothing.
  -- Given
  local sut = registry( { player( "Psikutas", true ) } )
  sut.boss_killed.kill( ILLIDAN )

  -- When
  sut.reset()

  -- Then
  eq( sut.stored(), {} )
  eq( sut.count( "Psikutas" ), 0 )
  eq( sut.get_rows(), {} )
end

function BonusRollRegistrySpec:should_keep_rolls_for_a_player_who_left_the_group()
  -- A roll is earned, so leaving doesn't spend it and shouldn't hide it either.
  -- Given
  local sut = registry( { player( "Psikutas", true ), player( "Obszczymucha", true ) } )
  sut.boss_killed.kill( ILLIDAN )

  -- When
  sut.eligibility.set_rows( { player( "Psikutas", true ) } )

  -- Then
  eq( sut.count( "Obszczymucha" ), 1 )
  eq( u.map( sut.get_rows(), function( row ) return row.player_name end ), { "Obszczymucha", "Psikutas" } )
end

function BonusRollRegistrySpec:should_remember_rolls_across_a_reload()
  -- A second module over the same saved table is what a /reload looks like.
  -- Given
  local saved = {}
  local db = Db.new( saved )
  local first = ResistanceBonusRollRegistry.new( db( "registry" ), mock_boss_killed(), mock_eligibility() )
  first.grant( "Psikutas", ILLIDAN, "Warrior", NOW )

  -- When
  local second = ResistanceBonusRollRegistry.new( db( "registry" ), mock_boss_killed(), mock_eligibility() )

  -- Then
  eq( second.get( "Psikutas" ), { entry( ILLIDAN ) } )
  eq( second.count( "Psikutas" ), 1 )
end

function BonusRollRegistrySpec:should_notify_on_a_hand_granted_roll()
  -- Given
  local sut = registry()
  local notifications = 0
  sut.subscribe( function() notifications = notifications + 1 end )

  -- When
  sut.grant( "Psikutas", ILLIDAN, "Warrior" )

  -- Then
  eq( notifications, 1 )
end

function BonusRollRegistrySpec:should_notify_once_for_a_kill_that_pays_out_to_several_players()
  -- A kill grants to everyone eligible at once. A listening frame redrawing once per
  -- player it pays out to would be the same mistake infer() avoids on the eligibility
  -- side.
  -- Given
  local sut = registry( { player( "Psikutas", true ), player( "Obszczymucha", true ) } )
  local notifications = 0
  sut.subscribe( function() notifications = notifications + 1 end )

  -- When
  sut.boss_killed.kill( ILLIDAN )

  -- Then
  eq( notifications, 1 )
end

function BonusRollRegistrySpec:should_not_notify_a_kill_that_pays_out_to_nobody()
  -- Given
  local sut = registry( { player( "Psikutas", false ) } )
  local notifications = 0
  sut.subscribe( function() notifications = notifications + 1 end )

  -- When
  sut.boss_killed.kill( ILLIDAN )

  -- Then
  eq( notifications, 0 )
end

function BonusRollRegistrySpec:should_notify_on_reset()
  -- Given
  local sut = registry()
  sut.grant( "Psikutas", ILLIDAN, "Warrior" )
  local notifications = 0
  sut.subscribe( function() notifications = notifications + 1 end )

  -- When
  sut.reset()

  -- Then
  eq( notifications, 1 )
end

function BonusRollRegistrySpec:should_notify_every_subscriber()
  -- Given
  local sut = registry()
  local first, second = 0, 0
  sut.subscribe( function() first = first + 1 end )
  sut.subscribe( function() second = second + 1 end )

  -- When
  sut.grant( "Psikutas", ILLIDAN, "Warrior" )

  -- Then
  eq( first, 1 )
  eq( second, 1 )
end

GrantingBossesSpec = {}

function GrantingBossesSpec:should_name_bosses_that_actually_exist_in_the_catalogue()
  -- These strings only ever arrive from BossKilled, which gets them from AutoLootDb.
  -- A typo here doesn't fail loudly -- it just silently stops granting -- so the names
  -- are checked against the catalogue rather than trusted.
  local found = {}

  for _, dungeon in pairs( RollFor.AutoLootDb.ids ) do
    for boss_name in pairs( dungeon.bosses or {} ) do
      if ResistanceBonusRollRegistry.granting_bosses[ boss_name ] then found[ boss_name ] = true end
    end
  end

  eq( found, {
    [ "Mother Shahraz" ] = true,
    [ "The Illidari Council" ] = true,
    [ "Illidan Stormrage" ] = true
  } )
end

os.exit( lu.LuaUnit.run() )
