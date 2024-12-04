package.path = "./?.lua;" .. package.path .. ";../?.lua;../RollFor/?.lua;../RollFor/libs/?.lua;../RollFor/libs/LibStub/?.lua"

local lu = require( "luaunit" )
local utils = require( "test/utils" )
local player = utils.player
local leader = utils.raid_leader
local is_in_party = utils.is_in_party
local is_in_raid = utils.is_in_raid
local c = utils.console_message
local p = utils.party_message
local r = utils.raid_message
local roll_for = utils.roll_for
local raid_roll = utils.raid_roll
local run_command = utils.run_command
local raid_roll_raw = utils.raid_roll_raw
local assert_messages = utils.assert_messages
local mock_random_roll = utils.mock_random_roll
local tick = utils.tick
local roll = utils.roll

RaidRollSpec = {}

function RaidRollSpec:should_not_roll_if_not_in_group()
  -- Given
  player( "Psikutas" )

  -- When
  raid_roll()

  -- Then
  assert_messages(
    c( "RollFor: Not in a group." )
  )
end

function RaidRollSpec:should_print_usage_if_in_party_and_no_item_is_provided()
  -- Given
  player( "Psikutas" )
  is_in_party( "Psikutas", "Obszczymucha" )

  -- When
  raid_roll_raw( "" )

  -- Then
  assert_messages(
    c( "RollFor[ RaidRoll ]: Usage: /rr <item>" )
  )
end

function RaidRollSpec:should_print_usage_if_in_raid_and_no_item_is_provided()
  -- Given
  player( "Psikutas" )
  is_in_raid( leader( "Psikutas" ), "Obszczymucha" )

  -- When
  raid_roll_raw( "" )

  -- Then
  assert_messages(
    c( "RollFor[ RaidRoll ]: Usage: /rr <item>" )
  )
end

function RaidRollSpec:should_print_usage_if_in_party_and_invalid_item_is_provided()
  -- Given
  player( "Psikutas" )
  is_in_party( "Psikutas", "Obszczymucha" )

  -- When
  raid_roll_raw( "not an item" )

  -- Then
  assert_messages(
    c( "RollFor[ RaidRoll ]: Usage: /rr <item>" )
  )
end

function RaidRollSpec:should_print_usage_if_in_raid_and_invalid_item_is_provided()
  -- Given
  player( "Psikutas" )
  is_in_raid( leader( "Psikutas" ), "Obszczymucha" )

  -- When
  raid_roll_raw( "not an item" )

  -- Then
  assert_messages(
    c( "RollFor[ RaidRoll ]: Usage: /rr <item>" )
  )
end

function RaidRollSpec:should_raid_roll_the_item_in_party_chat()
  -- Given
  player( "Psikutas" )
  is_in_party( "Psikutas", "Obszczymucha" )
  mock_random_roll( "Psikutas", 2, 2 )

  -- When
  raid_roll( "Hearthstone" )
  tick()

  -- Then
  assert_messages(
    p( "Raid rolling [Hearthstone]..." ),
    p( "[1]:Psikutas, [2]:Obszczymucha" ),
    p( "Obszczymucha wins [Hearthstone]." )
  )
end

function RaidRollSpec:should_not_raid_roll_if_rolling_is_in_progress()
  -- Given
  player( "Psikutas" )
  is_in_party( "Psikutas", "Obszczymucha" )

  -- When
  roll_for( "Hearthstone" )
  raid_roll( "Hearthstone" )

  -- Then
  assert_messages(
    p( "Roll for [Hearthstone]: /roll (MS) or /roll 99 (OS) or /roll 98 (TMOG)" ),
    c( "RollFor: Rolling already in progress." )
  )
end

function RaidRollSpec:should_not_raid_roll_again_if_raid_rolling_is_in_progress()
  -- Given
  player( "Psikutas" )
  is_in_party( "Psikutas", "Obszczymucha" )
  mock_random_roll( "Psikutas", 1, 2 )

  -- When
  raid_roll( "Hearthstone" )
  raid_roll( "Hearthstone" )
  tick()

  -- Then
  assert_messages(
    p( "Raid rolling [Hearthstone]..." ),
    p( "[1]:Psikutas, [2]:Obszczymucha" ),
    c( "RollFor: Rolling already in progress." ),
    p( "Psikutas wins [Hearthstone]." )
  )
end

function RaidRollSpec:should_ignore_other_players_rolls()
  -- Given
  player( "Psikutas" )
  is_in_party( "Psikutas", "Obszczymucha" )
  mock_random_roll( "Psikutas", 1, 2 )

  -- When
  raid_roll( "Hearthstone" )
  roll( "Obszczymucha", 100 )
  tick()

  -- Then
  assert_messages(
    p( "Raid rolling [Hearthstone]..." ),
    p( "[1]:Psikutas, [2]:Obszczymucha" ),
    p( "Psikutas wins [Hearthstone]." )
  )
end

function RaidRollSpec:should_ignore_my_own_hacky_rolls()
  -- Given
  player( "Psikutas" )
  is_in_party( "Psikutas", "Obszczymucha" )
  mock_random_roll( "Psikutas", 2, 2 )

  -- When
  raid_roll( "Hearthstone" )
  roll( "Psikutas", 1, 1 )
  tick()

  -- Then
  assert_messages(
    p( "Raid rolling [Hearthstone]..." ),
    p( "[1]:Psikutas, [2]:Obszczymucha" ),
    p( "Obszczymucha wins [Hearthstone]." )
  )
end

function RaidRollSpec:should_raid_roll_the_item_in_raid_chat()
  -- Given
  player( "Psikutas" )
  is_in_raid( "Psikutas", "Obszczymucha" )
  mock_random_roll( "Psikutas", 2, 2 )

  -- When
  raid_roll( "Hearthstone" )
  tick()

  -- Then
  assert_messages(
    r( "Raid rolling [Hearthstone]..." ),
    r( "[1]:Psikutas, [2]:Obszczymucha" ),
    r( "Obszczymucha wins [Hearthstone]." )
  )
end

function RaidRollSpec:should_raid_roll_the_item_in_raid_chat_even_as_a_leader()
  -- Given
  player( "Psikutas" )
  is_in_raid( leader( "Psikutas" ), "Obszczymucha" )
  mock_random_roll( "Psikutas", 2, 2 )

  -- When
  raid_roll( "Hearthstone" )
  tick()

  -- Then
  assert_messages(
    r( "Raid rolling [Hearthstone]..." ),
    r( "[1]:Psikutas, [2]:Obszczymucha" ),
    r( "Obszczymucha wins [Hearthstone]." )
  )
end

function RaidRollSpec:should_show_the_winner_with_ssr_command()
  -- Given
  player( "Psikutas" )
  is_in_party( "Psikutas", "Obszczymucha" )
  mock_random_roll( "Psikutas", 2, 2 )

  -- When
  raid_roll( "Hearthstone" )
  roll( "Obszczymucha", 100 )
  tick()
  run_command( "SSR" )

  -- Then
  assert_messages(
    p( "Raid rolling [Hearthstone]..." ),
    p( "[1]:Psikutas, [2]:Obszczymucha" ),
    p( "Obszczymucha wins [Hearthstone]." ),
    c( "RollFor[ RaidRoll ]: Obszczymucha won [Hearthstone]." )
  )
end

utils.mock_libraries()
utils.load_real_stuff()

os.exit( lu.LuaUnit.run() )
