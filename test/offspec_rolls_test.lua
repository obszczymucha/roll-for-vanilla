package.path = "./?.lua;" .. package.path .. ";../?.lua;../RollFor/?.lua;../RollFor/libs/?.lua"

require( "src/bcc/compat" )
local u = require( "test/utils" )
local lu = u.luaunit()
local player, leader, is_in_raid = u.player, u.raid_leader, u.is_in_raid
local c, r = u.console_message, u.raid_message
local cr, rw = u.console_and_raid_message, u.raid_warning
local rolling_finished = u.rolling_finished
local roll_for, roll_os = u.roll_for, u.roll_os
local tick = u.repeating_tick

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
        classic_look = function() return false end,
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
local m = {}

OffspecRollsSpec = {}

-- This gives players a chance to still roll MS if they rolled OS by mistake.
function OffspecRollsSpec:should_not_finish_rolling_automatically_if_all_players_rolled()
  -- Given
  player( "Psikutas" )
  is_in_raid( leader( "Psikutas" ), "Obszczymucha" )

  -- When
  roll_for( "Hearthstone" )
  roll_os( "Obszczymucha", 42 )
  roll_os( "Psikutas", 69 )
  tick( 8 )

  -- Then
  m.chat.assert(
    rw( "Roll for [Hearthstone]: /roll (MS) or /roll 99 (OS) or /roll 98 (TMOG)" ),
    r( "Stopping rolls in 3", "2", "1" ),
    cr( "Psikutas rolled the highest (69) for [Hearthstone] (OS)." ),
    rolling_finished()
  )
end

function OffspecRollsSpec:should_finish_rolling_automatically_if_number_of_items_is_equal_to_the_size_of_the_group()
  -- Given
  player( "Psikutas" )
  is_in_raid( leader( "Psikutas" ), "Obszczymucha" )

  -- When
  roll_for( "Hearthstone", 2 )
  roll_os( "Psikutas", 69 )
  roll_os( "Obszczymucha", 100 )

  -- Then
  m.chat.assert(
    rw( "Roll for 2x[Hearthstone]: /roll (MS) or /roll 99 (OS) or /roll 98 (TMOG). 2 top rolls win." ),
    cr( "Obszczymucha rolled the highest (100) for [Hearthstone] (OS)." ),
    cr( "Psikutas rolled the next highest (69) for [Hearthstone] (OS)." ),
    rolling_finished()
  )
end

function OffspecRollsSpec:should_not_finish_rolling_automatically_if_number_of_items_is_less_than_the_size_of_the_group()
  -- Given
  player( "Psikutas" )
  is_in_raid( leader( "Psikutas" ), "Obszczymucha", "Chuj" )

  -- When
  roll_for( "Hearthstone", 2 )
  roll_os( "Psikutas", 69 )
  roll_os( "Obszczymucha", 100 )
  tick( 6 )
  roll_os( "Chuj", 42 )
  tick( 2 )

  -- Then
  m.chat.assert(
    rw( "Roll for 2x[Hearthstone]: /roll (MS) or /roll 99 (OS) or /roll 98 (TMOG). 2 top rolls win." ),
    r( "Stopping rolls in 3", "2", "1" ),
    cr( "Obszczymucha rolled the highest (100) for [Hearthstone] (OS)." ),
    cr( "Psikutas rolled the next highest (69) for [Hearthstone] (OS)." ),
    rolling_finished()
  )
end

function OffspecRollsSpec:should_detect_and_ignore_double_rolls()
  -- Given
  player( "Psikutas" )
  is_in_raid( leader( "Psikutas" ), "Obszczymucha" )

  -- When
  roll_for( "Hearthstone" )
  roll_os( "Obszczymucha", 13 )
  tick( 6 )
  roll_os( "Obszczymucha", 100 )
  roll_os( "Psikutas", 69 )
  tick( 2 )

  -- Then
  m.chat.assert(
    rw( "Roll for [Hearthstone]: /roll (MS) or /roll 99 (OS) or /roll 98 (TMOG)" ),
    r( "Stopping rolls in 3", "2" ),
    c( "RollFor: Obszczymucha exhausted their rolls. This roll (100) is ignored." ),
    r( "1" ),
    cr( "Psikutas rolled the highest (69) for [Hearthstone] (OS)." ),
    rolling_finished()
  )
end

u.mock_libraries()
u.load_real_stuff_and_inject( module_registry, m )

os.exit( lu.LuaUnit.run() )
