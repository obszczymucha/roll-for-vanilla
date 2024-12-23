package.path = "./?.lua;" .. package.path .. ";../?.lua;../RollFor/?.lua;../RollFor/libs/?.lua"

local lu = require( "luaunit" )
local utils = require( "test/utils" )
local player = utils.player
local leader = utils.raid_leader
local is_in_party = utils.is_in_party
local is_in_raid = utils.is_in_raid
local c = utils.console_message
local p = utils.party_message
local r = utils.raid_message
local run_command = utils.run_command
local assert_messages = utils.assert_messages

HowToRollSpec = {}

function HowToRollSpec:should_not_show_how_to_roll_if_not_in_a_group()
  -- Given
  player( "Psikutas" )

  -- When
  run_command( "HTR" )

  -- Then
  assert_messages(
    c( "RollFor: Not in a group." )
  )
end

function HowToRollSpec:should_show_how_to_roll_if_in_party()
  -- Given
  player( "Psikutas" )
  is_in_party( "Psikutas", "Obszczymucha" )

  -- When
  run_command( "HTR" )

  -- Then
  assert_messages(
    p( "How to roll:" ),
    p( "For main-spec, type: /roll" ),
    p( "For off-spec, type: /roll 99" ),
    p( "For transmog, type: /roll 98" )
  )
end

function HowToRollSpec:should_show_how_to_roll_if_in_raid()
  -- Given
  player( "Psikutas" )
  is_in_raid( "Psikutas", "Obszczymucha" )

  -- When
  run_command( "HTR" )

  -- Then
  assert_messages(
    r( "How to roll:" ),
    r( "For main-spec, type: /roll" ),
    r( "For off-spec, type: /roll 99" ),
    r( "For transmog, type: /roll 98" )
  )
end

function HowToRollSpec:should_show_how_to_roll_if_in_raid_and_a_leader()
  -- Given
  player( "Psikutas" )
  is_in_raid( leader( "Psikutas" ), "Obszczymucha" )

  -- When
  run_command( "HTR" )

  -- Then
  assert_messages(
    r( "How to roll:" ),
    r( "For main-spec, type: /roll" ),
    r( "For off-spec, type: /roll 99" ),
    r( "For transmog, type: /roll 98" )
  )
end

utils.mock_libraries()
utils.load_real_stuff()

os.exit( lu.LuaUnit.run() )
