---@diagnostic disable: inject-field
package.path = "./?.lua;" .. package.path .. ";../?.lua;../RollFor/?.lua;../RollFor/libs/?.lua"

require( "src/compat" )
local u = require( "test/utils" )
local lu, eq = u.luaunit( "assertEquals" )
require( "src/modules" )
require( "src/DebugBuffer" )
require( "src/Module" )
local Db = require( "src/Db" )
require( "src/ItemUtils" )
require( "src/ItemCatalogue" ) -- the catalogue helpers AutoLootDb delegates its seeding and queries to
require( "src/AutoLootDb" )
local BossKilled = require( "src/BossKilled" )
local RaidLockout = require( "src/RaidLockout" )
local DropSimulator = require( "src/DropSimulator" )

u.mock_wow_api()

local ROBE_OF_HATEFUL_ECHOES = 30056 -- Hydross the Unstable
local BEASTMAW_PAULDRONS = 28589     -- shared by all three Opera bosses
local ADAMANTITE_CHERRY_BOMB = 32897 -- trash only
local NOT_IN_THE_CATALOGUE = 6948    -- Hearthstone

-- The real RaidLockout, not a mock: the point of /rfdrop lockout is that it drives the
-- module's own diff, and a mock would only ever confirm the command called something.
-- A client with no saves at all is what you'd be testing from anyway.
local function mock_event_frame()
  local frame = {}
  frame.subscribe = function() end

  return frame
end

-- A character with no raid saves, which is where you'd be running /rfdrop from anyway.
local function mock_api()
  return {
    GetNumSavedInstances = function() return 0 end,
    GetSavedInstanceInfo = function() return nil end,
    RequestRaidInfo = function() end
  }
end

local function simulator()
  local saved = {}
  local db = Db.new( saved )
  local boss_killed = BossKilled.new( db( "boss_killed" ) )
  local raid_lockout = RaidLockout.new( db( "raid_lockout" ), mock_api(), mock_event_frame() )

  -- Stands in for main.lua's confirmation, which weighs up what's at stake and puts the
  -- dialog up when there's something to lose. Answering yes straight through is what most
  -- of these tests want -- they're about the simulator, not about being asked.
  local asked = 0
  local answer_with_yes = true
  local pending_yes ---@type fun()?

  local function confirm_lockout_reset( on_confirmed )
    asked = asked + 1
    pending_yes = on_confirmed

    if answer_with_yes then on_confirmed() end
  end

  local sut = DropSimulator.new( boss_killed, raid_lockout, confirm_lockout_reset )

  -- main.lua's own subscriber does the actual reset on a lockout turnover -- this
  -- module only fires the event. Mirrored here so /rfdrop lockout behaves in the test
  -- the way it does in game, without pulling in the whole of main.lua to prove it.
  raid_lockout.subscribe( function() boss_killed.reset() end )

  -- What the addon printed, with the "RollFor: " prefix and the colors stripped --
  -- neither is what these tests are about. Installed after the simulator is built,
  -- because every one after the first re-registers /rfdrop and slash_cmd says so;
  -- that's the harness talking, not the code under test.
  local printed = {}

  RollFor.api.DEFAULT_CHAT_FRAME = {
    AddMessage = function( _, message )
      local plain = u.decolorize( message ) or message
      table.insert( printed, (string.gsub( plain, "^RollFor: ", "" )) )
    end
  }

  sut.boss_killed = boss_killed
  sut.raid_lockout = raid_lockout
  -- Leaves the question hanging, the way the dialog does until it's clicked.
  sut.dont_answer = function() answer_with_yes = false end
  sut.asked = function() return asked end
  sut.answer_yes = function() pending_yes() end

  -- Everything the lockout told its subscribers, in order.
  sut.turnovers = {}
  raid_lockout.subscribe( function( changed ) table.insert( sut.turnovers, changed ) end )

  sut.printed = printed
  sut.said = function( needle )
    for _, line in ipairs( printed ) do
      if string.find( line, needle, 1, true ) then return true end
    end

    return false
  end

  -- The kill announcement is main.lua's subscriber, not the simulator's, so the
  -- simulator staying quiet on success is the thing being asserted.
  sut.announced = {}
  boss_killed.subscribe( function( boss_name ) table.insert( sut.announced, boss_name ) end )

  return sut
end

DropSimulatorSpec = {}

function DropSimulatorSpec:should_drop_an_item_by_id()
  -- Given
  local sut = simulator()

  -- When
  sut.drop( tostring( ROBE_OF_HATEFUL_ECHOES ) )

  -- Then
  eq( sut.boss_killed.is_killed( "Hydross the Unstable" ), true )
  eq( sut.announced, { "Hydross the Unstable" } )
end

function DropSimulatorSpec:should_say_nothing_itself_when_the_drop_lands()
  -- The subscriber announces the kill. If the simulator announced it too, the one
  -- being read would be the wrong one.
  -- Given
  local sut = simulator()

  -- When
  sut.drop( tostring( ROBE_OF_HATEFUL_ECHOES ) )

  -- Then
  eq( sut.printed, {} )
end

function DropSimulatorSpec:should_drop_a_shift_clicked_item_link()
  -- A link has digits in it beyond the item id, so it can't be read with tonumber.
  -- Given
  local sut = simulator()
  local link = RollFor.AutoLootDb.make_link( ROBE_OF_HATEFUL_ECHOES, 4, "Robe of Hateful Echoes" )

  -- When
  sut.drop( link )

  -- Then
  eq( sut.boss_killed.is_killed( "Hydross the Unstable" ), true )
end

function DropSimulatorSpec:should_drop_something_that_names_the_boss_asked_for()
  -- Given
  local sut = simulator()

  -- When
  sut.drop( "vashj" )

  -- Then
  eq( sut.announced, { "Lady Vashj" } )
end

function DropSimulatorSpec:should_match_a_boss_name_case_insensitively()
  -- Given
  local sut = simulator()

  -- When
  sut.drop( "HYDROSS" )

  -- Then
  eq( sut.announced, { "Hydross the Unstable" } )
end

function DropSimulatorSpec:should_list_the_candidates_when_a_boss_name_is_ambiguous()
  -- Guessing which one was meant would be worse than saying so.
  -- Given
  local sut = simulator()

  -- When
  sut.drop( "the" )

  -- Then
  eq( sut.announced, {} )
  eq( sut.said( "matches" ), true )
  eq( sut.said( "Hydross the Unstable" ), true )
end

function DropSimulatorSpec:should_say_so_when_no_boss_matches()
  -- Given
  local sut = simulator()

  -- When
  sut.drop( "Hogger" )

  -- Then
  eq( sut.announced, {} )
  eq( sut.said( "No boss matches" ), true )
end

function DropSimulatorSpec:should_explain_an_item_the_bosses_share()
  -- Given
  local sut = simulator()

  -- When
  sut.drop( tostring( BEASTMAW_PAULDRONS ) )

  -- Then
  eq( sut.announced, {} )
  eq( sut.said( "shared between bosses" ), true )
  -- Named, so it's obvious which item was rejected.
  eq( sut.said( "Beastmaw Pauldrons" ), true )
end

function DropSimulatorSpec:should_explain_a_trash_drop()
  -- Given
  local sut = simulator()

  -- When
  sut.drop( tostring( ADAMANTITE_CHERRY_BOMB ) )

  -- Then
  eq( sut.announced, {} )
  eq( sut.said( "No boss in the catalogue drops" ), true )
end

function DropSimulatorSpec:should_explain_an_item_that_isnt_in_the_catalogue()
  -- Given
  local sut = simulator()

  -- When
  sut.drop( tostring( NOT_IN_THE_CATALOGUE ) )

  -- Then
  eq( sut.announced, {} )
  eq( sut.said( "No boss in the catalogue drops" ), true )
end

function DropSimulatorSpec:should_explain_a_boss_that_was_already_killed()
  -- Without this the second drop would look like the simulator had stopped working.
  -- Given
  local sut = simulator()
  sut.drop( tostring( ROBE_OF_HATEFUL_ECHOES ) )

  -- When
  sut.drop( tostring( ROBE_OF_HATEFUL_ECHOES ) )

  -- Then
  eq( sut.announced, { "Hydross the Unstable" } )
  eq( sut.said( "was already killed" ), true )
end

function DropSimulatorSpec:should_report_nothing_killed_yet()
  -- Given
  local sut = simulator()

  -- When
  sut.drop( "list" )

  -- Then
  eq( sut.said( "No bosses killed yet" ), true )
end

function DropSimulatorSpec:should_report_what_has_been_killed()
  -- Given
  local sut = simulator()
  sut.drop( "vashj" )
  sut.drop( "hydross" )

  -- When
  sut.drop( "list" )

  -- Then
  eq( sut.said( "2 killed:" ), true )
  eq( sut.said( "Hydross the Unstable" ), true )
  eq( sut.said( "Lady Vashj" ), true )
end

function DropSimulatorSpec:should_print_usage_when_asked_for_nothing()
  -- Given
  local sut = simulator()

  -- When
  sut.drop( "" )

  -- Then
  eq( sut.said( "/rfdrop <what>" ), true )
  eq( sut.said( "/rfdrop list" ), true )
  eq( sut.said( "/rfdrop lockout" ), true )
end

function DropSimulatorSpec:should_print_usage_when_the_command_carries_no_arguments_at_all()
  -- A bare slash command hands the callback nil rather than an empty string.
  -- Given
  local sut = simulator()

  -- When
  sut.drop( nil )

  -- Then
  eq( sut.said( "/rfdrop <what>" ), true )
end

function DropSimulatorSpec:should_list_case_insensitively()
  -- Given
  local sut = simulator()
  sut.drop( "hydross" )

  -- When
  sut.drop( "LIST" )

  -- Then
  eq( sut.said( "1 killed:" ), true )
  eq( sut.said( "Hydross the Unstable" ), true )
end

function DropSimulatorSpec:should_roll_the_lockout_over()
  -- Given
  local sut = simulator()

  -- When
  sut.drop( "lockout" )

  -- Then
  eq( sut.turnovers, { { "Simulated Raid" } } )
  eq( sut.said( "Simulating a raid lockout turnover" ), true )
end

function DropSimulatorSpec:should_roll_the_lockout_over_case_insensitively()
  -- Given
  local sut = simulator()

  -- When
  sut.drop( "LOCKOUT" )

  -- Then
  eq( sut.turnovers, { { "Simulated Raid" } } )
end

function DropSimulatorSpec:should_announce_the_turnover_before_firing_it()
  -- Whatever the turnover wipes is reported by the subscribers as it happens, and those
  -- lines belong underneath the "simulating..." line rather than above it.
  -- Given
  local sut = simulator()
  sut.raid_lockout.subscribe( function() RollFor.info( "a subscriber said something" ) end )

  -- When
  sut.drop( "lockout" )

  -- Then
  eq( sut.printed, {
    "Simulating a raid lockout turnover...",
    "a subscriber said something"
  } )
end

function DropSimulatorSpec:should_not_treat_lockout_as_a_boss_name()
  -- Given
  local sut = simulator()

  -- When
  sut.drop( "lockout" )

  -- Then
  eq( sut.announced, {} )
  eq( sut.said( "No boss matches" ), false )
end

function DropSimulatorSpec:should_ask_before_rolling_the_lockout_over()
  -- The one command in here that destroys something a real raid night can't get back.
  -- Given
  local sut = simulator()
  sut.dont_answer()

  -- When
  sut.drop( "lockout" )

  -- Then
  eq( sut.asked(), 1 )
  eq( sut.turnovers, {} )
  eq( sut.said( "Simulating a raid lockout turnover" ), false )
end

function DropSimulatorSpec:should_roll_the_lockout_over_once_the_question_is_answered()
  -- Given
  local sut = simulator()
  sut.dont_answer()
  sut.drop( "lockout" )

  -- When
  sut.answer_yes()

  -- Then
  eq( sut.turnovers, { { "Simulated Raid" } } )
  eq( sut.said( "Simulating a raid lockout turnover" ), true )
end

function DropSimulatorSpec:should_list_the_lockout_command_in_the_usage()
  -- Given
  local sut = simulator()

  -- When
  sut.drop( "" )

  -- Then
  eq( sut.said( "/rfdrop lockout" ), true )
end

function DropSimulatorSpec:should_forget_every_kill_when_the_lockout_is_rolled()
  -- Given
  local sut = simulator()
  sut.drop( "vashj" )
  sut.drop( "hydross" )

  -- When
  sut.drop( "lockout" )

  -- Then
  eq( sut.boss_killed.get_killed_bosses(), {} )
end

function DropSimulatorSpec:should_drop_the_same_boss_again_after_the_lockout_rolls()
  -- Given
  local sut = simulator()
  sut.drop( "hydross" )
  sut.drop( "lockout" )

  -- When
  sut.drop( "hydross" )

  -- Then
  eq( sut.announced, { "Hydross the Unstable", "Hydross the Unstable" } )
end

function DropSimulatorSpec:should_ignore_surrounding_whitespace()
  -- Given
  local sut = simulator()

  -- When
  sut.drop( "   hydross   " )

  -- Then
  eq( sut.announced, { "Hydross the Unstable" } )
end

function DropSimulatorSpec:should_never_pick_an_ignored_item_for_a_boss()
  -- Dropping one would be a no-op and read as the simulator being broken, so a boss
  -- is only ever dropped something that names it on its own.
  -- Given
  local sut = simulator()

  -- When
  sut.drop( "Wizard of Oz" )

  -- Then
  eq( sut.announced, { "The Wizard of Oz" } )
  eq( sut.printed, {} )
end

os.exit( lu.LuaUnit.run() )
