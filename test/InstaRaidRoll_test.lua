package.path = "./?.lua;" .. package.path .. ";../?.lua;../RollFor/?.lua;../RollFor/libs/?.lua"

require( "src/bcc/compat" )
local u = require( "test/utils" )
local lu = u.luaunit()
local player, leader = u.player, u.raid_leader
local is_in_party, is_in_raid = u.is_in_party, u.is_in_raid
local c, p, r = u.console_message, u.party_message, u.raid_message
local roll_for, insta_raid_roll, insta_raid_roll_raw = u.roll_for, u.insta_raid_roll, u.insta_raid_roll_raw
local run_command = u.run_command
local tick, roll = u.tick, u.roll
local mock_math_random, mock_multiple_math_random = u.mock_math_random, u.mock_multiple_math_random

local function mock_config()
  return {
    new = function()
      return {
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
        tmog_rolling_enabled = function() return true end,
        rolling_popup = function() return true end,
        raid_roll_again = function() return false end,
        default_rolling_time_seconds = function() return 8 end,
        classic_look = function() return false end
      }
    end
  }
end

---@type ModuleRegistry
local module_registry = {
  { module_name = "Config",  mock = mock_config },
  { module_name = "ChatApi", mock = "mocks/ChatApi", variable_name = "chat" }
}

-- The modules will be injected here using the above module_registry.
local m = {}

InstaRaidRollLegacySpec = {}

function InstaRaidRollLegacySpec:should_not_roll_if_not_in_group()
  -- Given
  player( "Psikutas" )

  -- When
  insta_raid_roll()

  -- Then
  m.chat.assert(
    c( "RollFor: Not in a group." )
  )
end

function InstaRaidRollLegacySpec:should_print_usage_if_in_party_and_no_item_is_provided()
  -- Given
  player( "Psikutas", mock_config() )
  is_in_party( "Psikutas", "Obszczymucha" )

  -- When
  insta_raid_roll_raw( "" )

  -- Then
  m.chat.assert(
    c( "RollFor [InstaRaidRoll]: Usage: /irr <item>" )
  )
end

function InstaRaidRollLegacySpec:should_print_usage_if_in_raid_and_no_item_is_provided()
  -- Given
  player( "Psikutas", mock_config() )
  is_in_raid( leader( "Psikutas" ), "Obszczymucha" )

  -- When
  insta_raid_roll_raw( "" )

  -- Then
  m.chat.assert(
    c( "RollFor [InstaRaidRoll]: Usage: /irr <item>" )
  )
end

function InstaRaidRollLegacySpec:should_print_usage_if_in_party_and_invalid_item_is_provided()
  -- Given
  player( "Psikutas", mock_config() )
  is_in_party( "Psikutas", "Obszczymucha" )

  -- When
  insta_raid_roll_raw( "not an item" )

  -- Then
  m.chat.assert(
    c( "RollFor [InstaRaidRoll]: Usage: /irr <item>" )
  )
end

function InstaRaidRollLegacySpec:should_print_usage_if_in_raid_and_invalid_item_is_provided()
  -- Given
  mock_config()
  player( "Psikutas" )
  is_in_raid( leader( "Psikutas" ), "Obszczymucha" )

  -- When
  insta_raid_roll_raw( "not an item" )

  -- Then
  m.chat.assert(
    c( "RollFor [InstaRaidRoll]: Usage: /irr <item>" )
  )
end

function InstaRaidRollLegacySpec:should_raid_roll_the_item_in_party_chat()
  -- Given
  player( "Psikutas", mock_config() )
  is_in_party( "Psikutas", "Obszczymucha" )
  mock_math_random( 1, 2, 2 )

  -- When
  insta_raid_roll( "Hearthstone" )

  -- Then
  m.chat.assert(
    p( "Psikutas wins [Hearthstone] (raid-roll)." )
  )
end

function InstaRaidRollLegacySpec:should_raid_roll_two_items_in_party_chat()
  -- Given
  player( "Psikutas", mock_config() )
  is_in_party( "Psikutas", "Obszczymucha" )
  mock_multiple_math_random( { { 1, 2, 2 }, { 1, 2, 1 } } )

  -- When
  insta_raid_roll( "Hearthstone", 123, 2 )

  -- Then
  m.chat.assert(
    p( "Psikutas wins [Hearthstone] (raid-roll)." ),
    p( "Obszczymucha wins [Hearthstone] (raid-roll)." )
  )
end

function InstaRaidRollLegacySpec:should_raid_roll_the_item_in_party_chat_2()
  -- Given
  player( "Psikutas", mock_config() )
  is_in_party( "Psikutas", "Obszczymucha" )
  mock_math_random( 1, 2, 1 )

  -- When
  insta_raid_roll( "Hearthstone" )

  -- Then
  m.chat.assert(
    p( "Obszczymucha wins [Hearthstone] (raid-roll)." )
  )
end

function InstaRaidRollLegacySpec:should_not_raid_roll_if_rolling_is_in_progress()
  -- Given
  player( "Psikutas", mock_config() )
  is_in_party( "Psikutas", "Obszczymucha" )

  -- When
  roll_for( "Hearthstone" )
  insta_raid_roll( "Hearthstone" )

  -- Then
  m.chat.assert(
    p( "Roll for [Hearthstone]: /roll (MS) or /roll 99 (OS) or /roll 98 (TMOG)" ),
    c( "RollFor: Rolling is in progress." )
  )
end

function InstaRaidRollLegacySpec:should_ignore_other_players_rolls()
  -- Given
  player( "Psikutas", mock_config() )
  is_in_party( "Psikutas", "Obszczymucha" )
  mock_math_random( 1, 2, 1 )

  -- When
  insta_raid_roll( "Hearthstone" )
  roll( "Obszczymucha", 100 )
  tick()

  -- Then
  m.chat.assert(
    p( "Obszczymucha wins [Hearthstone] (raid-roll)." )
  )
end

function InstaRaidRollLegacySpec:should_raid_roll_the_item_in_raid_chat()
  -- Given
  player( "Psikutas", mock_config() )
  is_in_raid( "Psikutas", "Obszczymucha" )
  mock_math_random( 1, 2, 1 )

  -- When
  insta_raid_roll( "Hearthstone" )

  -- Then
  m.chat.assert(
    r( "Obszczymucha wins [Hearthstone] (raid-roll)." )
  )
end

function InstaRaidRollLegacySpec:should_raid_roll_the_item_in_raid_chat_even_as_a_leader()
  -- Given
  player( "Psikutas", mock_config() )
  is_in_raid( leader( "Psikutas" ), "Obszczymucha" )
  mock_math_random( 1, 2, 1 )

  -- When
  insta_raid_roll( "Hearthstone" )
  tick()

  -- Then
  m.chat.assert(
    r( "Obszczymucha wins [Hearthstone] (raid-roll)." )
  )
end

function InstaRaidRollLegacySpec:should_show_the_winner_with_ssr_command()
  -- Given
  player( "Psikutas", mock_config() )
  is_in_party( "Psikutas", "Obszczymucha" )
  mock_math_random( 1, 2, 1 )

  -- When
  insta_raid_roll( "Hearthstone" )
  run_command( "SSR" )

  -- Then
  m.chat.assert(
    p( "Obszczymucha wins [Hearthstone] (raid-roll)." ),
    c( "RollFor [InstaRaidRoll]: Obszczymucha won [Hearthstone]." )
  )
end

u.mock_libraries()
u.load_real_stuff_and_inject( module_registry, m )

os.exit( lu.LuaUnit.run() )
