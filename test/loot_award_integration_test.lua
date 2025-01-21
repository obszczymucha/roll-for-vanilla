---@diagnostic disable: unused-local
package.path = "./?.lua;" .. package.path .. ";../?.lua;../RollFor/?.lua;../RollFor/libs/?.lua"

local lu = require( "luaunit" )
local eq = lu.assertEquals
local u = require( "test/utils" )
local fr = u.force_require
local modules = require( "src/modules" )

local player, leader, master_looter = u.player, u.raid_leader, u.master_looter
local is_in_raid = u.is_in_raid
local r, rw = u.raid_message, u.raid_warning
local c, cr = u.console_message, u.console_and_raid_message
local rolling_finished, rolling_not_in_progress = u.rolling_finished, u.rolling_not_in_progress
local roll_for, roll, roll_os = u.roll_for, u.roll, u.roll_os
local finish_rolling = u.finish_rolling
local assert_messages = u.assert_messages
local sr, soft_res = u.soft_res_item, u.soft_res
local tick, repeating_tick = u.tick, u.repeating_tick
local item, item_link = u.item, u.item_link
local award = u.award
local trade_with, trade_items, trade_complete = u.trade_with, u.trade_items, u.trade_complete
local confirm_master_looting = u.confirm_master_looting
local clear_dropped_items_db = u.clear_dropped_items_db
local loot_threshold = u.loot_threshold
local mock_blizzard_loot_buttons = u.mock_blizzard_loot_buttons
local mock_shift_key_pressed = u.mock_shift_key_pressed
local mock_alt_key_pressed = u.mock_alt_key_pressed
local mock_control_key_pressed = u.mock_control_key_pressed
local modifier_keys_not_pressed = u.modifier_keys_not_pressed
local run_command = u.run_command
local targetting_enemy = u.targetting_enemy
local LootQuality = u.LootQuality

local mock_config = function( config )
  return {
    new = function()
      return {
        auto_raid_roll = function() return config and config.auto_raid_roll end,
        minimap_button_hidden = function() return false end,
        minimap_button_locked = function() return false end,
        subscribe = function() end,
        rolling_popup_lock = function() return true end,
        ms_roll_threshold = function() return 100 end,
        os_roll_threshold = function() return 99 end,
        tmog_roll_threshold = function() return 98 end,
        roll_threshold = function() return { value = 100, str = "/roll" } end,
        auto_loot = function() return true end,
        show_rolling_tip = function() return true end,
        tmog_rolling_enabled = function() return true end,
        rolling_popup = function() return true end,
        insta_raid_roll = function() return true end,
        default_rolling_time_seconds = function() return 8 end,
        master_loot_frame_rows = function() return 5 end,
        auto_process_loot = function() return true end,
        autostart_loot_process = function() return true end
      }
    end
  }
end

---@type ModuleRegistry
local module_registry = {
  { module_name = "LootAwardPopup", mock = "mocks/LootAwardPopupMock" },
  { module_name = "Config",         mock = mock_config },
  { module_name = "LootFacade",     variable_name = "loot_facade",    mock = "mocks/LootFacade" },
  { module_name = "RollController", variable_name = "roll_controller" },
  { module_name = "RollTracker",    variable_name = "roll_tracker" },
  {}
}

-- The modules will be injected here using the above module_registry.
local m = {}

local function loot()
  m.LootFacade.notify( "LootOpened" )
end

local function dropped( ... )
  RollFor.LootList = nil

  local items = modules.map( { ... }, function( i )
    if not i.quality then i.quality = 4 end

    return i
  end )

  RollFor.LootList = fr( "mocks/LootList" )( items )
  m.loot_list = RollFor.LootList
end

LootAwardIntegrationSpec = {}

function LootAwardIntegrationSpec:should_successfully_assign_an_item_to_the_only_soft_ressing_player()
  -- Given
  dropped( item( "Hearthstone", 123 ) )
  master_looter( "Psikutas" )
  is_in_raid( leader( "Psikutas" ), "Obszczymucha" )
  soft_res( sr( "Psikutas", 123 ) )
  local controller = m.roll_controller ---@type RollController
  local tracker = m.roll_tracker ---@type RollTracker

  -- When
  loot()

  -- Then
  assert_messages(
    r( "1 item dropped:" ),
    r( "1. [Hearthstone] (SR by Psikutas)" ),
    r( "Remove calls to roll controller from the rolling popup and pass the callbacks instead." ),
    r( "That was we'll be able to mock the popup and call the callbacks." )
  )
end

u.mock_libraries()
u.load_real_stuff_and_inject( module_registry, m )

os.exit( lu.LuaUnit.run() )
