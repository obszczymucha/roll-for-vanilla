package.path = "./?.lua;" .. package.path .. ";../?.lua;../RollFor/?.lua;../RollFor/libs/?.lua"

require( "src/bcc/compat" )
local u = require( "test/utils" )
local lu = u.luaunit()
local player, leader = u.player, u.raid_leader
local is_in_raid = u.is_in_raid
local r, cr, rw = u.raid_message, u.console_and_raid_message, u.raid_warning
local rolling_finished = u.rolling_finished
local roll_for, roll, roll_os = u.roll_for, u.roll, u.roll_os
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
        classic_look = function() return true end
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

BothSpecRollsSpec = {}

function BothSpecRollsSpec:should_prioritize_mainspec_over_offspec_rolls()
  -- Given
  player( "Psikutas" )
  is_in_raid( leader( "Psikutas" ), "Obszczymucha" )

  -- When
  roll_for( "Hearthstone" )
  roll_os( "Obszczymucha", 99 )
  roll( "Psikutas", 69 )
  tick( 8 )

  -- Then
  m.chat.assert(
    rw( "Roll for [Hearthstone]: /roll (MS) or /roll 99 (OS) or /roll 98 (TMOG)" ),
    r( "Stopping rolls in 3", "2", "1" ),
    cr( "Psikutas rolled the highest (69) for [Hearthstone]." ),
    rolling_finished()
  )
end

function BothSpecRollsSpec:should_override_offspec_roll_with_mainspec_and_finish_automatically()
  -- Given
  player( "Psikutas" )
  is_in_raid( leader( "Psikutas" ), "Obszczymucha" )

  -- When
  roll_for( "Hearthstone" )
  roll_os( "Obszczymucha", 99 )
  roll( "Psikutas", 69 )
  tick( 6 )
  roll( "Obszczymucha", 42 )

  -- Then
  m.chat.assert(
    rw( "Roll for [Hearthstone]: /roll (MS) or /roll 99 (OS) or /roll 98 (TMOG)" ),
    r( "Stopping rolls in 3", "2" ),
    cr( "Psikutas rolled the highest (69) for [Hearthstone]." ),
    rolling_finished()
  )
end

function BothSpecRollsSpec:should_override_offspec_roll_with_mainspec_and_not_finish_automatically()
  -- Given
  player( "Psikutas" )
  is_in_raid( leader( "Psikutas" ), "Obszczymucha", "Chuj" )

  -- When
  roll_for( "Hearthstone" )
  roll_os( "Obszczymucha", 99 )
  roll( "Psikutas", 69 )
  tick( 6 )
  roll( "Obszczymucha", 42 )
  tick( 2 )

  -- Then
  m.chat.assert(
    rw( "Roll for [Hearthstone]: /roll (MS) or /roll 99 (OS) or /roll 98 (TMOG)" ),
    r( "Stopping rolls in 3", "2", "1" ),
    cr( "Psikutas rolled the highest (69) for [Hearthstone]." ),
    rolling_finished()
  )
end

function BothSpecRollsSpec:should_recognize_both_mainspec_and_offspec_rollers_and_stop_automatically()
  -- Given
  player( "Psikutas" )
  is_in_raid( leader( "Psikutas" ), "Obszczymucha" )

  -- When
  roll_for( "Hearthstone", 2 )
  roll( "Obszczymucha", 3 )
  tick( 6 )
  roll_os( "Psikutas", 63 )

  -- Then
  m.chat.assert(
    rw( "Roll for 2x[Hearthstone]: /roll (MS) or /roll 99 (OS) or /roll 98 (TMOG). 2 top rolls win." ),
    r( "Stopping rolls in 3", "2" ),
    cr( "Obszczymucha rolled the highest (3) for [Hearthstone]." ),
    cr( "Psikutas rolled the next highest (63) for [Hearthstone] (OS)." ),
    rolling_finished()
  )
end

function BothSpecRollsSpec:should_recognize_both_mainspec_and_top_offspec_rollers_and_stop_automatically()
  -- Given
  player( "Psikutas" )
  is_in_raid( leader( "Psikutas" ), "Obszczymucha", "Chuj" )

  -- When
  roll_for( "Hearthstone", 3 )
  roll_os( "Chuj", 99 )
  roll( "Obszczymucha", 3 )
  tick( 6 )
  roll_os( "Psikutas", 63 )

  -- Then
  m.chat.assert(
    rw( "Roll for 3x[Hearthstone]: /roll (MS) or /roll 99 (OS) or /roll 98 (TMOG). 3 top rolls win." ),
    r( "Stopping rolls in 3", "2" ),
    cr( "Obszczymucha rolled the highest (3) for [Hearthstone]." ),
    cr( "Chuj rolled the next highest (99) for [Hearthstone] (OS)." ),
    cr( "Psikutas rolled the next highest (63) for [Hearthstone] (OS)." ),
    rolling_finished()
  )
end

function BothSpecRollsSpec:should_recognize_both_top_mainspec_and_offspec_rollers_and_stop_automatically()
  -- Given
  player( "Psikutas" )
  is_in_raid( leader( "Psikutas" ), "Obszczymucha", "Chuj" )

  -- When
  roll_for( "Hearthstone", 3 )
  roll( "Chuj", 99 )
  roll( "Obszczymucha", 3 )
  tick( 6 )
  roll_os( "Psikutas", 63 )

  -- Then
  m.chat.assert(
    rw( "Roll for 3x[Hearthstone]: /roll (MS) or /roll 99 (OS) or /roll 98 (TMOG). 3 top rolls win." ),
    r( "Stopping rolls in 3", "2" ),
    cr( "Chuj rolled the highest (99) for [Hearthstone]." ),
    cr( "Obszczymucha rolled the next highest (3) for [Hearthstone]." ),
    cr( "Psikutas rolled the next highest (63) for [Hearthstone] (OS)." ),
    rolling_finished()
  )
end

function BothSpecRollsSpec:should_recognize_both_mainspec_rollers_and_not_stop_automatically_with_items_less_than_group_size()
  -- Given
  player( "Psikutas" )
  is_in_raid( leader( "Psikutas" ), "Obszczymucha", "Chuj" )

  -- When
  roll_for( "Hearthstone", 2 )
  roll_os( "Chuj", 99 )
  roll( "Obszczymucha", 3 )
  tick( 6 )
  roll( "Psikutas", 63 )
  tick( 2 )

  -- Then
  m.chat.assert(
    rw( "Roll for 2x[Hearthstone]: /roll (MS) or /roll 99 (OS) or /roll 98 (TMOG). 2 top rolls win." ),
    r( "Stopping rolls in 3", "2", "1" ),
    cr( "Psikutas rolled the highest (63) for [Hearthstone]." ),
    cr( "Obszczymucha rolled the next highest (3) for [Hearthstone]." ),
    rolling_finished()
  )
end

function BothSpecRollsSpec:should_recognize_both_mainspec_rollers_and_not_stop_automatically_with_items_equal_to_group_size()
  -- Given
  player( "Psikutas" )
  is_in_raid( leader( "Psikutas" ), "Obszczymucha", "Chuj" )

  -- When
  roll_for( "Hearthstone", 3 )
  roll( "Obszczymucha", 3 )
  tick( 6 )
  roll( "Psikutas", 63 )
  tick( 2 )

  -- Then
  m.chat.assert(
    rw( "Roll for 3x[Hearthstone]: /roll (MS) or /roll 99 (OS) or /roll 98 (TMOG). 3 top rolls win." ),
    r( "Stopping rolls in 3", "2", "1" ),
    cr( "Psikutas rolled the highest (63) for [Hearthstone]." ),
    cr( "Obszczymucha rolled the next highest (3) for [Hearthstone]." ),
    rolling_finished()
  )
end

function BothSpecRollsSpec:should_recognize_mainspec_and_offspec_rollers_and_not_stop_automatically_with_items_less_than_group_size()
  -- Given
  player( "Psikutas" )
  is_in_raid( leader( "Psikutas" ), "Obszczymucha", "Chuj" )

  -- When
  roll_for( "Hearthstone", 2 )
  roll_os( "Chuj", 99 )
  roll_os( "Obszczymucha", 98 )
  tick( 6 )
  roll( "Psikutas", 63 )
  tick( 2 )

  -- Then
  m.chat.assert(
    rw( "Roll for 2x[Hearthstone]: /roll (MS) or /roll 99 (OS) or /roll 98 (TMOG). 2 top rolls win." ),
    r( "Stopping rolls in 3", "2", "1" ),
    cr( "Psikutas rolled the highest (63) for [Hearthstone]." ),
    cr( "Chuj rolled the next highest (99) for [Hearthstone] (OS)." ),
    rolling_finished()
  )
end

function BothSpecRollsSpec:should_recognize_mainspec_roller_and_top_offspec_roller_if_item_count_is_less_than_group_size()
  -- Given
  player( "Psikutas" )
  is_in_raid( leader( "Psikutas" ), "Obszczymucha", "Chuj" )

  -- When
  roll_for( "Hearthstone", 2 )
  roll_os( "Chuj", 42 )
  roll( "Obszczymucha", 1 )
  tick( 6 )
  roll_os( "Psikutas", 69 )
  tick( 2 )

  -- Then
  m.chat.assert(
    rw( "Roll for 2x[Hearthstone]: /roll (MS) or /roll 99 (OS) or /roll 98 (TMOG). 2 top rolls win." ),
    r( "Stopping rolls in 3", "2", "1" ),
    cr( "Obszczymucha rolled the highest (1) for [Hearthstone]." ),
    cr( "Psikutas rolled the next highest (69) for [Hearthstone] (OS)." ),
    rolling_finished()
  )
end

function BothSpecRollsSpec:should_recognize_mainspec_rollers_if_item_count_is_less_than_group_size()
  -- Given
  player( "Psikutas" )
  is_in_raid( leader( "Psikutas" ), "Obszczymucha", "Chuj" )

  -- When
  roll_for( "Hearthstone", 2 )
  roll_os( "Chuj", 42 )
  roll( "Obszczymucha", 1 )
  tick( 6 )
  roll( "Psikutas", 69 )
  tick( 2 )

  -- Then
  m.chat.assert(
    rw( "Roll for 2x[Hearthstone]: /roll (MS) or /roll 99 (OS) or /roll 98 (TMOG). 2 top rolls win." ),
    r( "Stopping rolls in 3", "2", "1" ),
    cr( "Psikutas rolled the highest (69) for [Hearthstone]." ),
    cr( "Obszczymucha rolled the next highest (1) for [Hearthstone]." ),
    rolling_finished()
  )
end

u.mock_libraries()
u.load_real_stuff_and_inject( module_registry, m )

os.exit( lu.LuaUnit.run() )
