package.path = "./?.lua;" .. package.path .. ";../?.lua;../RollFor/?.lua;../RollFor/libs/?.lua"

require( "src/bcc/compat" )
local u                              = require( "test/utils" )
local lu                             = u.luaunit()
local player, leader                 = u.player, u.raid_leader
local is_in_party, is_in_raid        = u.is_in_party, u.is_in_raid
local c, p, r                        = u.console_message, u.party_message, u.raid_message
local cr, rw                         = u.console_and_raid_message, u.raid_warning
local rolling_not_in_progress        = u.rolling_not_in_progress
local roll_for, roll_for_raw         = u.roll_for, u.roll_for_raw
local cancel_rolling, finish_rolling = u.cancel_rolling, u.finish_rolling
local item_link                      = u.item_link

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
        classic_look = function() return true end,
        award_filter = function() return {} end,
        keep_award_data = function() return false end
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
local m               = {}

GenericSpec           = {}

function GenericSpec:should_load_roll_for()
  -- When
  ---@diagnostic disable-next-line: undefined-global
  local result = RollFor

  -- Expect
  lu.assertNotNil( result )
end

function GenericSpec:should_not_roll_if_not_in_group()
  -- Given
  player( "Psikutas" )

  -- When
  roll_for()

  -- Then
  m.chat.assert(
    c( "RollFor: Not in a group." )
  )
end

function GenericSpec:should_print_usage_if_in_party_and_no_item_is_provided()
  -- Given
  player( "Psikutas" )
  is_in_party( "Psikutas", "Obszczymucha" )

  -- When
  roll_for_raw( "" )

  -- Then
  m.chat.assert(
    c( "RollFor: Usage: /rf <item> [seconds]" )
  )
end

function GenericSpec:should_print_usage_if_in_raid_and_no_item_is_provided()
  -- Given
  player( "Psikutas" )
  is_in_raid( leader( "Psikutas" ), "Obszczymucha" )

  -- When
  roll_for_raw( "" )

  -- Then
  m.chat.assert(
    c( "RollFor: Usage: /rf <item> [seconds]" )
  )
end

function GenericSpec:should_print_usage_if_in_party_and_invalid_item_is_provided()
  -- Given
  player( "Psikutas" )
  is_in_party( "Psikutas", "Obszczymucha" )

  -- When
  roll_for_raw( "not an item" )

  -- Then
  m.chat.assert(
    c( "RollFor: Usage: /rf <item> [seconds]" )
  )
end

function GenericSpec:should_print_usage_if_in_raid_and_invalid_item_is_provided()
  -- Given
  player( "Psikutas" )
  is_in_raid( leader( "Psikutas" ), "Obszczymucha" )

  -- When
  roll_for_raw( "not an item" )

  -- Then
  m.chat.assert(
    c( "RollFor: Usage: /rf <item> [seconds]" )
  )
end

function GenericSpec:should_properly_parse_multiple_item_roll_for()
  -- Given
  player( "Psikutas" )
  is_in_raid( leader( "Psikutas" ), "Obszczymucha" )
  local item = item_link( "Hearthstone", 12345 )

  -- When
  roll_for_raw( string.format( "2x%s", item ) )

  -- Then
  m.chat.assert(
    rw( "Roll for 2x[Hearthstone]: /roll (MS) or /roll 99 (OS) or /roll 98 (TMOG). 2 top rolls win." )
  )
end

function GenericSpec:should_properly_parse_multiple_item_roll_for_if_there_is_space_before_the_item()
  -- Given
  player( "Psikutas" )
  is_in_raid( leader( "Psikutas" ), "Obszczymucha" )
  local item = item_link( "Hearthstone", 12345 )

  -- When
  roll_for_raw( string.format( "2x %s", item ) )

  -- Then
  m.chat.assert(
    rw( "Roll for 2x[Hearthstone]: /roll (MS) or /roll 99 (OS) or /roll 98 (TMOG). 2 top rolls win." )
  )
end

function GenericSpec:should_roll_the_item_in_party_chat()
  -- Given
  player( "Psikutas" )
  is_in_party( "Psikutas", "Obszczymucha" )

  -- When
  roll_for( "Hearthstone" )

  -- Then
  m.chat.assert(
    p( "Roll for [Hearthstone]: /roll (MS) or /roll 99 (OS) or /roll 98 (TMOG)" )
  )
end

function GenericSpec:should_not_roll_again_if_rolling_is_in_progress()
  -- Given
  player( "Psikutas" )
  is_in_party( "Psikutas", "Obszczymucha" )

  -- When
  roll_for( "Hearthstone" )
  roll_for( "Hearthstone" )

  -- Then
  m.chat.assert(
    p( "Roll for [Hearthstone]: /roll (MS) or /roll 99 (OS) or /roll 98 (TMOG)" ),
    c( "RollFor: Rolling is in progress." )
  )
end

function GenericSpec:should_roll_the_item_in_raid_chat()
  -- Given
  player( "Psikutas" )
  is_in_raid( "Psikutas", "Obszczymucha" )

  -- When
  roll_for( "Hearthstone" )

  -- Then
  m.chat.assert(
    r( "Roll for [Hearthstone]: /roll (MS) or /roll 99 (OS) or /roll 98 (TMOG)" )
  )
end

function GenericSpec:should_roll_the_item_in_raid_warning()
  -- Given
  player( "Psikutas" )
  is_in_raid( leader( "Psikutas" ), "Obszczymucha" )

  -- When
  roll_for( "Hearthstone" )

  -- Then
  m.chat.assert(
    rw( "Roll for [Hearthstone]: /roll (MS) or /roll 99 (OS) or /roll 98 (TMOG)" )
  )
end

function GenericSpec:should_not_cancel_rolling_if_rolling_is_not_in_progress()
  -- Given
  player( "Psikutas" )

  -- When
  cancel_rolling()

  -- Then
  m.chat.assert( rolling_not_in_progress() )
end

function GenericSpec:should_cancel_rolling()
  -- Given
  player( "Psikutas" )
  is_in_raid( leader( "Psikutas" ), "Obszczymucha" )

  -- When
  roll_for( "Hearthstone" )
  cancel_rolling()

  -- Then
  m.chat.assert(
    rw( "Roll for [Hearthstone]: /roll (MS) or /roll 99 (OS) or /roll 98 (TMOG)" ),
    c( "RollFor: Rolling for [Hearthstone] was canceled." ),
    r( "Rolling for [Hearthstone] was canceled." )
  )
end

function GenericSpec:should_not_finish_rolling_if_rolling_is_not_in_progress()
  -- Given
  player( "Psikutas" )

  -- When
  finish_rolling()

  -- Then
  m.chat.assert( rolling_not_in_progress() )
end

function GenericSpec:should_finish_rolling()
  -- Given
  player( "Psikutas" )
  is_in_raid( leader( "Psikutas" ), "Obszczymucha" )

  -- When
  roll_for( "Hearthstone" )
  finish_rolling()

  -- Then
  m.chat.assert(
    rw( "Roll for [Hearthstone]: /roll (MS) or /roll 99 (OS) or /roll 98 (TMOG)" ),
    cr( "No one rolled for [Hearthstone]." ),
    c( "RollFor: Rolling for [Hearthstone] finished." )
  )
end

u.mock_libraries()
u.load_real_stuff_and_inject( module_registry, m )

os.exit( lu.LuaUnit.run() )
