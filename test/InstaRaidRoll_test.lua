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
local insta_raid_roll = utils.insta_raid_roll
local run_command = utils.run_command
local insta_raid_roll_raw = utils.insta_raid_roll_raw
local assert_messages = utils.assert_messages
local tick = utils.tick
local roll = utils.roll
local mock_math_random = utils.mock_math_random

InstaRaidRollSpec = {}

local function mock_config( config )
  local m = require( "src/modules" )

  local defaults = {
    auto_raid_roll = function() return false end,
    minimap_button_hidden = function() return false end,
    minimap_button_locked = function() return false end,
    subscribe = function() end,
    rolling_popup_lock = function() return true end,
    ms_roll_threshold = function() return 100 end,
    os_roll_threshold = function() return 99 end,
    tmog_roll_threshold = function() return 98 end,
    roll_threshold = function()
      return {
        value = 100,
        str = "/roll"
      }
    end,
    auto_loot = function() return true end,
    show_rolling_tip = function() return true end,
    tmog_rolling_enabled = function() return true end,
    rolling_popup = function() return true end,
    insta_raid_roll = function() return config and config.insta_raid_roll end,
    raid_roll_again = function() return false end,
    default_rolling_time_seconds = function() return 8 end
  }

  m.Config = {
    new = function()
      return defaults
    end
  }
end

function InstaRaidRollSpec:should_not_roll_if_not_in_group()
  -- Given
  player( "Psikutas" )

  -- When
  insta_raid_roll()

  -- Then
  assert_messages(
    c( "RollFor: Not in a group." )
  )
end

function InstaRaidRollSpec:should_print_usage_if_in_party_and_no_item_is_provided()
  -- Given
  mock_config( { insta_raid_roll = true } )
  player( "Psikutas" )
  is_in_party( "Psikutas", "Obszczymucha" )

  -- When
  insta_raid_roll_raw( "" )

  -- Then
  assert_messages(
    c( "RollFor[ InstaRaidRoll ]: Usage: /irr <item>" )
  )
end

function InstaRaidRollSpec:should_print_usage_if_in_raid_and_no_item_is_provided()
  -- Given
  mock_config( { insta_raid_roll = true } )
  player( "Psikutas" )
  is_in_raid( leader( "Psikutas" ), "Obszczymucha" )

  -- When
  insta_raid_roll_raw( "" )

  -- Then
  assert_messages(
    c( "RollFor[ InstaRaidRoll ]: Usage: /irr <item>" )
  )
end

function InstaRaidRollSpec:should_print_usage_if_in_party_and_invalid_item_is_provided()
  -- Given
  mock_config( { insta_raid_roll = true } )
  player( "Psikutas" )
  is_in_party( "Psikutas", "Obszczymucha" )

  -- When
  insta_raid_roll_raw( "not an item" )

  -- Then
  assert_messages(
    c( "RollFor[ InstaRaidRoll ]: Usage: /irr <item>" )
  )
end

function InstaRaidRollSpec:should_print_usage_if_in_raid_and_invalid_item_is_provided()
  -- Given
  mock_config( { insta_raid_roll = true } )
  player( "Psikutas" )
  is_in_raid( leader( "Psikutas" ), "Obszczymucha" )

  -- When
  insta_raid_roll_raw( "not an item" )

  -- Then
  assert_messages(
    c( "RollFor[ InstaRaidRoll ]: Usage: /irr <item>" )
  )
end

function InstaRaidRollSpec:should_not_roll_if_insta_raid_roll_is_disabled()
  -- Given
  mock_config( { insta_raid_roll = false } )
  player( "Psikutas" )
  is_in_party( "Psikutas", "Obszczymucha" )
  mock_math_random( 1, 2, 2 )

  -- When
  insta_raid_roll( "Hearthstone" )

  -- Then
  assert_messages(
    c( "RollFor: Insta raid-roll is disabled." )
  )
end

function InstaRaidRollSpec:should_raid_roll_the_item_in_party_chat()
  -- Given
  mock_config( { insta_raid_roll = true } )
  player( "Psikutas" )
  is_in_party( "Psikutas", "Obszczymucha" )
  mock_math_random( 1, 2, 2 )

  -- When
  insta_raid_roll( "Hearthstone" )

  -- Then
  assert_messages(
    p( "Obszczymucha wins [Hearthstone] via insta raid-roll." )
  )
end

function InstaRaidRollSpec:should_raid_roll_the_item_in_party_chat_2()
  -- Given
  mock_config( { insta_raid_roll = true } )
  player( "Psikutas" )
  is_in_party( "Psikutas", "Obszczymucha" )
  mock_math_random( 1, 2, 1 )

  -- When
  insta_raid_roll( "Hearthstone" )

  -- Then
  assert_messages(
    p( "Psikutas wins [Hearthstone] via insta raid-roll." )
  )
end

function InstaRaidRollSpec:should_not_raid_roll_if_rolling_is_in_progress()
  -- Given
  mock_config( { insta_raid_roll = true } )
  player( "Psikutas" )
  is_in_party( "Psikutas", "Obszczymucha" )

  -- When
  roll_for( "Hearthstone" )
  insta_raid_roll( "Hearthstone" )

  -- Then
  assert_messages(
    p( "Roll for [Hearthstone]: /roll (MS) or /roll 99 (OS) or /roll 98 (TMOG)" ),
    c( "RollFor: Rolling already in progress." )
  )
end

function InstaRaidRollSpec:should_ignore_other_players_rolls()
  -- Given
  mock_config( { insta_raid_roll = true } )
  player( "Psikutas" )
  is_in_party( "Psikutas", "Obszczymucha" )
  mock_math_random( 1, 2, 1 )

  -- When
  insta_raid_roll( "Hearthstone" )
  roll( "Obszczymucha", 100 )
  tick()

  -- Then
  assert_messages(
    p( "Psikutas wins [Hearthstone] via insta raid-roll." )
  )
end

function InstaRaidRollSpec:should_raid_roll_the_item_in_raid_chat()
  -- Given
  mock_config( { insta_raid_roll = true } )
  player( "Psikutas" )
  is_in_raid( "Psikutas", "Obszczymucha" )
  mock_math_random( 1, 2, 1 )

  -- When
  insta_raid_roll( "Hearthstone" )

  -- Then
  assert_messages(
    r( "Psikutas wins [Hearthstone] via insta raid-roll." )
  )
end

function InstaRaidRollSpec:should_raid_roll_the_item_in_raid_chat_even_as_a_leader()
  -- Given
  mock_config( { insta_raid_roll = true } )
  player( "Psikutas" )
  is_in_raid( leader( "Psikutas" ), "Obszczymucha" )
  mock_math_random( 1, 2, 1 )

  -- When
  insta_raid_roll( "Hearthstone" )
  tick()

  -- Then
  assert_messages(
    r( "Psikutas wins [Hearthstone] via insta raid-roll." )
  )
end

function InstaRaidRollSpec:should_show_the_winner_with_ssr_command()
  -- Given
  mock_config( { insta_raid_roll = true } )
  player( "Psikutas" )
  is_in_party( "Psikutas", "Obszczymucha" )
  mock_math_random( 1, 2, 1 )

  -- When
  insta_raid_roll( "Hearthstone" )
  run_command( "SSR" )

  -- Then
  assert_messages(
    p( "Psikutas wins [Hearthstone] via insta raid-roll." ),
    c( "RollFor[ InstaRaidRoll ]: Psikutas won [Hearthstone]." )
  )
end

utils.mock_libraries()
utils.load_real_stuff( function( module_name )
  if module_name == "src/Config" then return mock_config() end

  return require( module_name )
end )

os.exit( lu.LuaUnit.run() )
