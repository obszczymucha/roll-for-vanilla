---@diagnostic disable: inject-field
package.path = "./?.lua;" .. package.path .. ";../?.lua;../RollFor/?.lua;../RollFor/libs/?.lua"

require( "src/bcc/compat" )
local utils = require( "test/utils" )
local lu, eq = utils.luaunit( "assertEquals" )
require( "src/modules" )
require( "src/DebugBuffer" )
require( "src/Module" )
local Db = require( "src/Db" )
local RaidLockout = require( "src/RaidLockout" )

-- The module turns each save's "seconds until reset" into a deadline and later asks
-- whether that deadline has passed, so the clock is pinned rather than left to run.
local NOW = 1700000000
RollFor.lua.time = function() return NOW end

-- Long enough that nothing in a test drifts past it. A save whose reset is still in
-- the future and yet isn't reported is the client not having answered, not an expiry.
local NOT_YET = 3 * 24 * 3600

local RAID = true
local DUNGEON = false
local NORMAL = 1
local HEROIC = 2

-- One row of GetSavedInstanceInfo, in the order the client returns them:
-- name, instanceID, reset, difficulty, locked, extended, instanceIDMostSig, isRaid
--
-- `reset` defaults to 0 -- a save that is already at its deadline -- so that a test
-- which only cares about ids gets the plain "gone means expired" reading. Tests about
-- the unanswered-read case pass NOT_YET instead.
---@param name string
---@param instance_id number
---@param is_raid boolean?
---@param difficulty number?
---@param reset number?
local function save( name, instance_id, is_raid, difficulty, reset )
  return {
    name = name,
    instance_id = instance_id,
    reset = reset or 0,
    difficulty = difficulty or NORMAL,
    is_raid = is_raid == nil and RAID or is_raid
  }
end

-- Only the three calls the module makes. Saves are swapped between updates, which is
-- what a lockout turning over looks like from in here.
local function mock_api( saves )
  local m_saves = saves or {}
  local api = { requests = 0 }

  api.GetNumSavedInstances = function() return #m_saves end

  api.GetSavedInstanceInfo = function( i )
    local s = m_saves[ i ]
    if not s then return nil end

    return s.name, s.instance_id, s.reset, s.difficulty, true, false, 0, s.is_raid, 25, "25 Player"
  end

  api.RequestRaidInfo = function() api.requests = api.requests + 1 end
  api.set_saves = function( new_saves ) m_saves = new_saves or {} end

  return api
end

local function mock_event_frame()
  local frame = { subscribed = {} }

  frame.subscribe = function( event_name, callback )
    frame.subscribed[ event_name ] = callback
  end

  frame.fire = function( event_name )
    local callback = frame.subscribed[ event_name ]
    if not callback then error( string.format( "Nothing subscribed to %s.", event_name ), 2 ) end
    callback()
  end

  return frame
end

---@param saves table[]?
local function lockout( saves )
  -- The real thing, not a plain table: the saved db is a proxy that forwards reads
  -- and writes but has no keys of its own, and code that forgets that passes happily
  -- against a plain table.
  local saved = {}
  local api = mock_api( saves )
  local event_frame = mock_event_frame()

  local sut = RaidLockout.new( Db.new( saved )( "raid_lockout" ), api, event_frame )

  sut.api = api
  sut.event_frame = event_frame
  sut.stored = function() return saved.raid_lockout.lockouts end

  -- Every notification, in order.
  sut.changes = {}
  sut.subscribe( function( changed ) table.insert( sut.changes, changed ) end )

  -- The server answering, which is the only way anything in here happens.
  sut.update = function( new_saves )
    if new_saves then api.set_saves( new_saves ) end
    event_frame.fire( "UPDATE_INSTANCE_INFO" )
  end

  return sut
end

RaidLockoutSpec = {}

function RaidLockoutSpec:should_subscribe_to_the_instance_info_event()
  -- Given
  local sut = lockout()

  -- Then
  eq( sut.event_frame.subscribed[ "UPDATE_INSTANCE_INFO" ] ~= nil, true )
end

function RaidLockoutSpec:should_ask_the_server_on_refresh()
  -- The answer comes back as the event, not from the call.
  -- Given
  local sut = lockout()

  -- When
  sut.refresh()

  -- Then
  eq( sut.api.requests, 1 )
  eq( sut.changes, {} )
end

function RaidLockoutSpec:should_not_report_a_change_the_first_time_it_sees_a_save()
  -- Fresh install, or the first boss of the night. Either way nothing turned over.
  -- Given
  local sut = lockout( { save( "Serpentshrine Cavern", 111 ) } )

  -- When
  sut.update()

  -- Then
  eq( sut.changes, {} )
  eq( sut.stored(), { [ "Serpentshrine Cavern|1" ] = 111 } )
end

function RaidLockoutSpec:should_not_report_a_change_when_a_new_save_appears()
  -- This is what killing the first boss of the night does. Calling it a lockout
  -- change would wipe the record of the kill that caused it.
  -- Given
  local sut = lockout( { save( "Serpentshrine Cavern", 111 ) } )
  sut.update()

  -- When
  sut.update( { save( "Serpentshrine Cavern", 111 ), save( "Tempest Keep", 222 ) } )

  -- Then
  eq( sut.changes, {} )
  eq( sut.stored(), { [ "Serpentshrine Cavern|1" ] = 111, [ "Tempest Keep|1" ] = 222 } )
end

function RaidLockoutSpec:should_report_a_change_when_the_instance_id_turns_over()
  -- The server hands out a fresh id for a fresh lockout.
  -- Given
  local sut = lockout( { save( "Serpentshrine Cavern", 111 ) } )
  sut.update()

  -- When
  sut.update( { save( "Serpentshrine Cavern", 999 ) } )

  -- Then
  eq( sut.changes, { { "Serpentshrine Cavern" } } )
  eq( sut.stored(), { [ "Serpentshrine Cavern|1" ] = 999 } )
end

function RaidLockoutSpec:should_report_a_change_when_a_save_expires()
  -- Logging in after the reset, before getting saved again.
  -- Given
  local sut = lockout( { save( "Serpentshrine Cavern", 111 ) } )
  sut.update()

  -- When
  sut.update( {} )

  -- Then
  eq( sut.changes, { { "Serpentshrine Cavern" } } )
  eq( sut.stored(), {} )
end

function RaidLockoutSpec:should_not_report_a_change_when_the_client_has_not_answered_yet()
  -- UPDATE_INSTANCE_INFO fires on login and on zoning before the server's answer
  -- lands, and the client reports no saves at all until it does. Taking that at face
  -- value would wipe the night's kills, rolls and eligibility. The save's own reset
  -- time is what tells the two apart: this one is days away, so it isn't gone.
  -- Given
  local sut = lockout( { save( "Serpentshrine Cavern", 111, RAID, NORMAL, NOT_YET ) } )
  sut.update()

  -- When
  sut.update( {} )

  -- Then
  eq( sut.changes, {} )
  -- Kept, not dropped, so its real turnover is still seen on a later event.
  eq( sut.stored(), { [ "Serpentshrine Cavern|1" ] = 111 } )
end

function RaidLockoutSpec:should_report_a_change_once_an_unanswered_save_passes_its_reset()
  -- Given
  local sut = lockout( { save( "Serpentshrine Cavern", 111, RAID, NORMAL, NOT_YET ) } )
  sut.update()
  sut.update( {} )

  -- When
  NOW = NOW + NOT_YET + 1
  sut.update( {} )
  NOW = 1700000000

  -- Then
  eq( sut.changes, { { "Serpentshrine Cavern" } } )
  eq( sut.stored(), {} )
end

function RaidLockoutSpec:should_report_every_raid_that_turned_over_at_once()
  -- Given
  local sut = lockout( { save( "Serpentshrine Cavern", 111 ), save( "Tempest Keep", 222 ) } )
  sut.update()

  -- When
  sut.update( { save( "Serpentshrine Cavern", 333 ), save( "Tempest Keep", 444 ) } )

  -- Then
  eq( sut.changes, { { "Serpentshrine Cavern", "Tempest Keep" } } )
end

function RaidLockoutSpec:should_report_a_turnover_alongside_a_brand_new_save()
  -- Only the one that turned over is named; the new one is not a change.
  -- Given
  local sut = lockout( { save( "Serpentshrine Cavern", 111 ) } )
  sut.update()

  -- When
  sut.update( { save( "Serpentshrine Cavern", 999 ), save( "Karazhan", 555 ) } )

  -- Then
  eq( sut.changes, { { "Serpentshrine Cavern" } } )
  eq( sut.stored(), { [ "Serpentshrine Cavern|1" ] = 999, [ "Karazhan|1" ] = 555 } )
end

function RaidLockoutSpec:should_say_nothing_when_the_saves_are_unchanged()
  -- UPDATE_INSTANCE_INFO fires on its own; most of the time nothing has moved.
  -- Given
  local sut = lockout( { save( "Serpentshrine Cavern", 111 ) } )
  sut.update()

  -- When
  sut.update()
  sut.update()

  -- Then
  eq( sut.changes, {} )
end

function RaidLockoutSpec:should_treat_the_same_raid_at_two_difficulties_as_two_lockouts()
  -- They turn over independently, so one moving must not look like the other moving.
  -- Given
  local sut = lockout( {
    save( "Karazhan", 111, RAID, NORMAL ),
    save( "Karazhan", 222, RAID, HEROIC )
  } )
  sut.update()

  -- When
  sut.update( {
    save( "Karazhan", 111, RAID, NORMAL ),
    save( "Karazhan", 999, RAID, HEROIC )
  } )

  -- Then
  eq( sut.changes, { { "Karazhan" } } )
  eq( sut.stored(), { [ "Karazhan|1" ] = 111, [ "Karazhan|2" ] = 999 } )
end

function RaidLockoutSpec:should_ignore_dungeons()
  -- Heroics are saved too and turn over daily. Letting one through would wipe a
  -- raid's kills every morning.
  -- Given
  local sut = lockout( { save( "Shattered Halls", 111, DUNGEON ) } )
  sut.update()

  -- When
  sut.update( { save( "Shattered Halls", 999, DUNGEON ) } )

  -- Then
  eq( sut.changes, {} )
  eq( sut.stored(), {} )
end

function RaidLockoutSpec:should_ignore_a_dungeon_sitting_next_to_a_raid()
  -- Given
  local sut = lockout( {
    save( "Shattered Halls", 111, DUNGEON ),
    save( "Serpentshrine Cavern", 222 )
  } )
  sut.update()

  -- When
  sut.update( {
    save( "Shattered Halls", 999, DUNGEON ),
    save( "Serpentshrine Cavern", 222 )
  } )

  -- Then
  eq( sut.changes, {} )
  eq( sut.stored(), { [ "Serpentshrine Cavern|1" ] = 222 } )
end

function RaidLockoutSpec:should_notify_every_subscriber()
  -- Given
  local sut = lockout( { save( "Serpentshrine Cavern", 111 ) } )
  local second = {}
  sut.subscribe( function( changed ) table.insert( second, changed ) end )
  sut.update()

  -- When
  sut.update( { save( "Serpentshrine Cavern", 999 ) } )

  -- Then
  eq( sut.changes, { { "Serpentshrine Cavern" } } )
  eq( second, { { "Serpentshrine Cavern" } } )
end

function RaidLockoutSpec:should_remember_the_snapshot_across_a_reload()
  -- A second module over the same saved table is what a /reload looks like. Without
  -- persistence every login would see its saves for the "first" time and never
  -- notice a lockout that turned over while we were away.
  -- Given
  local saved = {}
  local db = Db.new( saved )
  local api = mock_api( { save( "Serpentshrine Cavern", 111 ) } )
  local first_frame = mock_event_frame()
  RaidLockout.new( db( "raid_lockout" ), api, first_frame )
  first_frame.fire( "UPDATE_INSTANCE_INFO" )

  -- When
  local second_frame = mock_event_frame()
  local second = RaidLockout.new( db( "raid_lockout" ), api, second_frame )
  local changes = {}
  second.subscribe( function( changed ) table.insert( changes, changed ) end )

  api.set_saves( { save( "Serpentshrine Cavern", 999 ) } )
  second_frame.fire( "UPDATE_INSTANCE_INFO" )

  -- Then
  eq( changes, { { "Serpentshrine Cavern" } } )
  eq( second.get_lockouts(), { [ "Serpentshrine Cavern|1" ] = 999 } )
end

function RaidLockoutSpec:should_report_a_change_when_a_turnover_is_simulated()
  -- The dev hook goes through the real diff rather than straight to the listeners, so
  -- a simulation that passed while the diff was broken isn't possible.
  -- Given
  local sut = lockout()

  -- When
  sut.simulate_turnover()

  -- Then
  eq( sut.changes, { { "Simulated Raid" } } )
end

function RaidLockoutSpec:should_simulate_a_turnover_with_no_real_saves_at_all()
  -- Which is where you'd be testing from: solo, out of an instance, saved to nothing.
  -- Given
  local sut = lockout()

  -- When
  sut.simulate_turnover()

  -- Then
  eq( sut.changes, { { "Simulated Raid" } } )
  -- The planted entry is gone again: the snapshot is overwritten with what the client
  -- actually reports, so a second simulation isn't answering for the first one's mess.
  eq( sut.stored(), {} )
end

function RaidLockoutSpec:should_simulate_a_turnover_under_a_given_name()
  -- Given
  local sut = lockout()

  -- When
  sut.simulate_turnover( "Black Temple" )

  -- Then
  eq( sut.changes, { { "Black Temple" } } )
end

function RaidLockoutSpec:should_leave_real_saves_alone_when_simulating()
  -- Given
  local sut = lockout( { save( "Serpentshrine Cavern", 111 ) } )
  sut.update()

  -- When
  sut.simulate_turnover()

  -- Then
  eq( sut.changes, { { "Simulated Raid" } } )
  eq( sut.stored(), { [ "Serpentshrine Cavern|1" ] = 111 } )
end

function RaidLockoutSpec:should_simulate_a_turnover_more_than_once()
  -- Given
  local sut = lockout()

  -- When
  sut.simulate_turnover()
  sut.simulate_turnover()

  -- Then
  eq( sut.changes, { { "Simulated Raid" }, { "Simulated Raid" } } )
end

function RaidLockoutSpec:should_cope_with_a_client_that_has_no_saves_at_all()
  -- Given
  local sut = lockout()

  -- When
  sut.update()

  -- Then
  eq( sut.changes, {} )
  eq( sut.stored(), {} )
  eq( sut.get_lockouts(), {} )
end

os.exit( lu.LuaUnit.run() )
