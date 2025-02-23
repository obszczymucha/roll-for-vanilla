package.path = "./?.lua;" .. package.path .. ";../?.lua;../RollFor/?.lua;../RollFor/libs/?.lua"

require( "src/bcc/compat" )
local lu = require( "luaunit" )
local eq = lu.assertEquals
local u = require( "test/utils" )
local mods = require( "src/modules" )

local player, leader, master_looter = u.player, u.raid_leader, u.master_looter
local is_in_raid = u.is_in_raid
local r, rw = u.raid_message, u.raid_warning
local c, cr = u.console_message, u.console_and_raid_message
local rolling_finished, rolling_not_in_progress = u.rolling_finished, u.rolling_not_in_progress
local roll_for, roll, roll_os = u.roll_for, u.roll, u.roll_os
local finish_rolling = u.finish_rolling
local sr, soft_res = u.soft_res_item, u.soft_res
local tick, repeating_tick = u.tick, u.repeating_tick
local item, item_link = u.item, u.item_link
local award = u.award
local trade_with, trade_items, trade_complete = u.trade_with, u.trade_items, u.trade_complete
local confirm_master_looting = u.confirm_master_looting
local clear_dropped_items_db = u.clear_dropped_items_db
local loot_threshold = u.loot_threshold
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
        roll_threshold = function()
          return {
            value = 100,
            str = "/roll"
          }
        end,
        auto_loot = function() return true end,
        tmog_rolling_enabled = function() return true end,
        rolling_popup = function() return true end,
        default_rolling_time_seconds = function() return 8 end,
        master_loot_frame_rows = function() return 5 end,
        superwow_auto_loot_coins = function() return true end,
        classic_look = function() return false end,
      }
    end
  }
end

---@type ModuleRegistry
local module_registry = {
  { module_name = "LootAwardPopup", mock = "mocks/LootAwardPopup" },
  { module_name = "Config",         mock = mock_config },
  { module_name = "LootFacade",     mock = "mocks/LootFacade",    variable_name = "loot_facade" },
  { module_name = "ChatApi",        mock = "mocks/ChatApi",       variable_name = "chat" },
  { module_name = "LootList",       mock = "mocks/LootList",      variable_name = "loot_list" }
}

local m = {}

local function loot( ... )
  m.loot_facade.notify( "LootOpened", ... )
end

SoftResIntegrationSpec = {}

function SoftResIntegrationSpec:should_announce_sr_and_ignore_all_rolls_if_item_is_soft_ressed_by_one_player()
  -- Given
  player( "Psikutas" )
  is_in_raid( leader( "Psikutas" ), "Obszczymucha", "Rikus" )
  soft_res( sr( "Psikutas", 123 ) )

  -- When
  roll_for( "Hearthstone", 1, 123 )
  roll( "Rikus", 99 )
  roll_os( "Obszczymucha", 100 )
  roll( "Psikutas", 69 )
  finish_rolling()

  -- Then
  m.chat.assert(
    rw( "Psikutas soft-ressed [Hearthstone]." ),
    -- c( "RollFor [Tip]: Use /arf [Hearthstone] to roll the item and ignore the softres." ),
    rolling_not_in_progress()
  )
end

function SoftResIntegrationSpec:should_only_process_rolls_from_players_who_soft_ressed_and_finish_automatically()
  -- Given
  player( "Psikutas" )
  is_in_raid( leader( "Psikutas" ), "Obszczymucha", "Ponpon", "Rikus" )
  soft_res( sr( "Psikutas", 123 ), sr( "Ponpon", 123 ) )

  -- When
  roll_for( "Hearthstone", 1, 123 )
  roll( "Rikus", 100 )
  roll( "Psikutas", 69 )
  roll_os( "Obszczymucha", 42 )
  roll( "Ponpon", 42 )

  -- Then
  m.chat.assert(
    rw( "Roll for [Hearthstone]: SR by Ponpon and Psikutas" ),
    c( "RollFor: Rikus didn't SR [Hearthstone]. This roll (100) is ignored." ),
    c( "RollFor: Obszczymucha didn't SR [Hearthstone]. This roll (42) is ignored." ),
    cr( "Psikutas rolled the highest (69) for [Hearthstone] (SR)." ),
    rolling_finished()
  )
end

function SoftResIntegrationSpec:should_ignore_offspec_rolls_by_players_who_soft_ressed_and_announce_they_still_have_to_roll()
  -- Given
  player( "Psikutas" )
  is_in_raid( leader( "Psikutas" ), "Obszczymucha", "Ponpon" )
  soft_res( sr( "Psikutas", 123 ), sr( "Ponpon", 123 ) )

  -- When
  roll_for( "Hearthstone", 1, 123 )
  roll_os( "Psikutas", 69 )
  roll( "Ponpon", 42 )
  repeating_tick( 8 )
  roll( "Psikutas", 99 )

  -- Then
  m.chat.assert(
    rw( "Roll for [Hearthstone]: SR by Ponpon and Psikutas" ),
    c( "RollFor: Psikutas did SR [Hearthstone], but didn't /roll. This roll (69) is ignored." ),
    r( "Stopping rolls in 3", "2", "1" ),
    r( "SR rolls remaining: Psikutas (1 roll)" ),
    cr( "Psikutas rolled the highest (99) for [Hearthstone] (SR)." ),
    rolling_finished()
  )
end

function SoftResIntegrationSpec:should_announce_current_highest_roller_if_a_player_who_soft_ressed_did_not_roll_and_rolls_were_manually_finished()
  -- Given
  player( "Psikutas" )
  is_in_raid( leader( "Psikutas" ), "Obszczymucha", "Ponpon" )
  soft_res( sr( "Psikutas", 123 ), sr( "Ponpon", 123 ) )

  -- When
  roll_for( "Hearthstone", 1, 123 )
  roll_os( "Psikutas", 69 )
  roll( "Ponpon", 42 )
  repeating_tick( 8 )
  finish_rolling()

  -- Then
  m.chat.assert(
    rw( "Roll for [Hearthstone]: SR by Ponpon and Psikutas" ),
    c( "RollFor: Psikutas did SR [Hearthstone], but didn't /roll. This roll (69) is ignored." ),
    r( "Stopping rolls in 3", "2", "1" ),
    r( "SR rolls remaining: Psikutas (1 roll)" ),
    cr( "Ponpon rolled the highest (42) for [Hearthstone] (SR)." ),
    rolling_finished()
  )
end

function SoftResIntegrationSpec:should_announce_all_missing_sr_rolls_if_players_didnt_roll_on_time()
  -- Given
  player( "Psikutas" )
  is_in_raid( leader( "Psikutas" ), "Obszczymucha", "Ponpon", "Rikus" )
  soft_res( sr( "Psikutas", 123 ), sr( "Ponpon", 123 ), sr( "Psikutas", 123 ), sr( "Ponpon", 123 ), sr( "Rikus", 123 ) )

  -- When
  roll_for( "Hearthstone", 1, 123 )
  roll( "Ponpon", 42 )
  repeating_tick( 8 )

  -- Then
  m.chat.assert(
    rw( "Roll for [Hearthstone]: SR by Ponpon [2 rolls], Psikutas [2 rolls] and Rikus" ),
    r( "Stopping rolls in 3", "2", "1" ),
    r( "SR rolls remaining: Ponpon (1 roll), Psikutas (2 rolls) and Rikus (1 roll)" )
  )
end

function SoftResIntegrationSpec:should_announce_all_missing_sr_rolls_if_none_of_the_sr_players_rolled_and_auto_raid_roll_is_enabled()
  -- Given
  player( "Psikutas", mock_config( { auto_raid_roll = true } ) )
  is_in_raid( leader( "Psikutas" ), "Obszczymucha", "Ponpon", "Rikus" )
  soft_res( sr( "Psikutas", 123 ), sr( "Ponpon", 123 ), sr( "Psikutas", 123 ), sr( "Ponpon", 123 ), sr( "Rikus", 123 ) )

  -- When
  roll_for( "Hearthstone", 1, 123 )
  repeating_tick( 8 )

  -- Then
  m.chat.assert(
    rw( "Roll for [Hearthstone]: SR by Ponpon [2 rolls], Psikutas [2 rolls] and Rikus" ),
    r( "Stopping rolls in 3", "2", "1" ),
    r( "SR rolls remaining: Ponpon (2 rolls), Psikutas (2 rolls) and Rikus (1 roll)" )
  )
end

function SoftResIntegrationSpec:should_announce_all_missing_sr_rolls_if_none_of_the_sr_players_rolled_and_auto_raid_roll_is_disabled()
  -- Given
  player( "Psikutas", mock_config( { auto_raid_roll = false } ) )
  is_in_raid( leader( "Psikutas" ), "Obszczymucha", "Ponpon", "Rikus" )
  soft_res( sr( "Psikutas", 123 ), sr( "Ponpon", 123 ), sr( "Psikutas", 123 ), sr( "Ponpon", 123 ), sr( "Rikus", 123 ) )

  -- When
  roll_for( "Hearthstone", 1, 123 )
  repeating_tick( 8 )

  -- Then
  m.chat.assert(
    rw( "Roll for [Hearthstone]: SR by Ponpon [2 rolls], Psikutas [2 rolls] and Rikus" ),
    r( "Stopping rolls in 3", "2", "1" ),
    r( "SR rolls remaining: Ponpon (2 rolls), Psikutas (2 rolls) and Rikus (1 roll)" )
  )
end

function SoftResIntegrationSpec:should_allow_multiple_rolls_if_a_player_soft_ressed_multiple_times()
  -- Given
  player( "Psikutas" )
  is_in_raid( leader( "Psikutas" ), "Ponpon" )
  soft_res( sr( "Psikutas", 123 ), sr( "Psikutas", 123 ), sr( "Ponpon", 123 ) )

  -- When
  roll_for( "Hearthstone", 1, 123 )
  roll( "Psikutas", 42 )
  roll( "Ponpon", 69 )
  roll( "Ponpon", 100 )
  roll( "Psikutas", 99 )

  -- Then
  m.chat.assert(
    rw( "Roll for [Hearthstone]: SR by Ponpon and Psikutas [2 rolls]" ),
    c( "RollFor: Ponpon exhausted their rolls. This roll (100) is ignored." ),
    cr( "Psikutas rolled the highest (99) for [Hearthstone] (SR)." ),
    rolling_finished()
  )
end

function SoftResIntegrationSpec:should_ask_for_a_reroll_if_there_is_a_tie_and_ignore_non_tied_rolls()
  -- Given
  player( "Psikutas" )
  is_in_raid( leader( "Psikutas" ), "Ponpon", "Rikus", "Pimp" )
  soft_res( sr( "Psikutas", 123 ), sr( "Ponpon", 123 ), sr( "Rikus", 123 ), sr( "Pimp", 123 ) )

  -- When
  roll_for( "Hearthstone", 1, 123 )
  roll( "Psikutas", 69 )
  roll( "Rikus", 42 )
  roll( "Ponpon", 69 )
  roll( "Pimp", 69 )
  tick() -- ScheduleTimer() needs to tick
  roll( "Rikus", 100 )
  roll( "Psikutas", 100 )
  roll( "Ponpon", 1 )
  roll( "Pimp", 1 )

  -- Then
  m.chat.assert(
    rw( "Roll for [Hearthstone]: SR by Pimp, Ponpon, Psikutas and Rikus" ),
    cr( "Pimp, Ponpon and Psikutas rolled the highest (69) for [Hearthstone] (SR)." ),
    r( "Pimp, Ponpon and Psikutas /roll for [Hearthstone] now." ),
    c( "RollFor: Rikus didn't tie roll for [Hearthstone]. This roll (100) is ignored." ),
    cr( "Psikutas re-rolled the highest (100) for [Hearthstone] (SR)." ),
    rolling_finished()
  )
end

function SoftResIntegrationSpec:should_not_ask_for_a_reroll_if_there_is_a_tie_and_there_are_still_sr_rolls_remaining()
  -- Given
  player( "Psikutas" )
  is_in_raid( leader( "Psikutas" ), "Ponpon", "Rikus", "Pimp" )
  soft_res( sr( "Psikutas", 123 ), sr( "Psikutas", 123 ), sr( "Ponpon", 123 ), sr( "Rikus", 123 ), sr( "Pimp", 123 ) )

  -- When
  roll_for( "Hearthstone", 1, 123 )
  roll( "Psikutas", 69 )
  roll( "Rikus", 42 )
  roll( "Ponpon", 69 )
  roll( "Pimp", 69 )
  tick() -- ScheduleTimer() needs to tick
  repeating_tick( 8 )
  tick()
  tick()
  roll( "Psikutas", 70 )

  -- Then
  m.chat.assert(
    rw( "Roll for [Hearthstone]: SR by Pimp, Ponpon, Psikutas [2 rolls] and Rikus" ),
    r( "Stopping rolls in 3", "2", "1" ),
    r( "SR rolls remaining: Psikutas (1 roll)" ),
    cr( "Psikutas rolled the highest (70) for [Hearthstone] (SR)." ),
    rolling_finished()
  )
end

function SoftResIntegrationSpec:should_allow_others_to_roll_if_player_who_soft_ressed_already_received_the_item()
  -- Given
  master_looter( "Psikutas" )
  is_in_raid( leader( "Psikutas" ), "Ponpon" )
  soft_res( sr( "Psikutas", 123 ) )
  loot_threshold( LootQuality.Epic )

  -- When
  loot( item( "Hearthstone", 123 ), item( "Hearthstone", 123 ) )
  roll_for( "Hearthstone", 1, 123 )
  award( "Psikutas", "Hearthstone", 123 )
  roll_for( "Hearthstone", 1, 123 )
  roll( "Ponpon", 1 )
  repeating_tick( 8 )

  -- Then
  m.chat.assert(
    r( "2 items dropped:", "1. [Hearthstone] (SR by Psikutas)", "2. [Hearthstone]" ),
    rw( "Psikutas soft-ressed [Hearthstone]." ),
    -- c( "RollFor [Tip]: Use /arf [Hearthstone] to roll the item and ignore the softres." ),
    c( "RollFor: Psikutas received [Hearthstone]." ),
    rw( "Roll for [Hearthstone]: /roll (MS) or /roll 99 (OS) or /roll 98 (TMOG)" ),
    r( "Stopping rolls in 3", "2", "1" ),
    cr( "Ponpon rolled the highest (1) for [Hearthstone]." ),
    rolling_finished()
  )
end

--Disabling due to fucking 2.4.3 hack with delayed trade check.
function SoftResIntegrationSpec:should_allow_others_to_roll_if_player_who_soft_ressed_already_received_the_item_via_trade()
  -- Given
  local trade_mod = require( "src/TradeTracker" )
  trade_mod.debug_enabled = true
  master_looter( "Psikutas" )
  is_in_raid( leader( "Psikutas" ), "Obszczymucha", "Ponpon" )
  soft_res( sr( "Obszczymucha", 123 ) )

  -- When
  loot( item( "Hearthstone", 123 ), item( "Hearthstone", 123 ) )
  roll_for( "Hearthstone", 1, 123 )
  trade_with( "Obszczymucha" )
  trade_items( nil, { item_link = u.item_link( "Hearthstone", 123 ), quantity = 1 } )
  trade_complete()
  tick()
  roll_for( "Hearthstone", 1, 123 )
  roll( "Ponpon", 1 )
  repeating_tick( 8 )

  -- Then
  m.chat.assert(
    r( "2 items dropped:", "1. [Hearthstone] (SR by Obszczymucha)", "2. [Hearthstone]" ),
    rw( "Obszczymucha soft-ressed [Hearthstone]." ),
    -- c( "RollFor [Tip]: Use /arf [Hearthstone] to roll the item and ignore the softres." ),
    c( "RollFor: Started trading with Obszczymucha." ),
    c( "RollFor: Giving in slot 1: 1x[Hearthstone]" ),
    c( "RollFor: Trading with Obszczymucha complete." ),
    c( "RollFor: Traded: 1x[Hearthstone]" ),
    c( "RollFor: Obszczymucha received [Hearthstone]." ),
    rw( "Roll for [Hearthstone]: /roll (MS) or /roll 99 (OS) or /roll 98 (TMOG)" ),
    r( "Stopping rolls in 3", "2", "1" ),
    cr( "Ponpon rolled the highest (1) for [Hearthstone]." ),
    rolling_finished()
  )
end

function SoftResIntegrationSpec:should_allow_others_to_roll_if_player_who_soft_ressed_already_received_the_item_via_master_loot()
  -- Given
  local dropped_item = item( "Hearthstone", 123 )
  clear_dropped_items_db()
  master_looter( "Psikutas" )
  is_in_raid( leader( "Psikutas" ), "Obszczymucha", "Ponpon" )
  soft_res( sr( "Obszczymucha", 123 ) )
  mock_shift_key_pressed( false )
  mock_alt_key_pressed( false )
  mock_control_key_pressed( false )
  local link = item_link( "Heartstone", 123 )
  local rf = clear_dropped_items_db()
  rf.db.awarded_loot = {}

  -- When
  loot( dropped_item, item( "Hearthstone", 123 ) )
  roll_for( "Hearthstone", 1, 123 )
  u.mock( "GiveMasterLoot", function() end )
  local candidate = mods.Types.make_item_candidate( "Obszczymucha", "Warrior", true )
  rf.roll_controller.award_confirmed( candidate, dropped_item )
  m.loot_facade.notify( "LootSlotCleared", 1 )
  confirm_master_looting( m.loot_facade, candidate, link )
  roll_for( "Hearthstone", 1, 123 )
  roll( "Ponpon", 1 )
  repeating_tick( 8 )

  -- Then
  m.chat.assert(
    r( "2 items dropped:", "1. [Hearthstone] (SR by Obszczymucha)", "2. [Hearthstone]" ),
    rw( "Obszczymucha soft-ressed [Hearthstone]." ),
    -- c( "RollFor [Tip]: Use /arf [Hearthstone] to roll the item and ignore the softres." ),
    c( "RollFor: Obszczymucha received [Hearthstone]." ),
    rw( "Roll for [Hearthstone]: /roll (MS) or /roll 99 (OS) or /roll 98 (TMOG)" ),
    r( "Stopping rolls in 3", "2", "1" ),
    cr( "Ponpon rolled the highest (1) for [Hearthstone]." ),
    rolling_finished()
  )
end

function SoftResIntegrationSpec:should_not_subtract_rolls_from_softres_data()
  -- Given
  local rf = clear_dropped_items_db()
  rf.db.awarded_loot = {}
  master_looter( "Jogobobek" )
  is_in_raid( leader( "Jogobobek" ), "Trololoo", "Bomanz", "Elizalee" )
  soft_res( sr( "Trololoo", 22637 ), sr( "Elizalee", 22637 ), sr( "Elizalee", 22637 ), sr( "Bomanz", 22637 ) )
  modifier_keys_not_pressed()

  -- Then
  local sr_data = rf.softres.get( 22637 )[ 1 ]
  eq( sr_data.rolls, 1 )

  -- And
  targetting_enemy( "Jin'do the Hexxer" )
  loot( item( "Primal Hakkari Idol", 22637 ) )
  roll_for( "Primal Hakkari Idol", 1, 22637 )
  roll( "Elizalee", 96 )
  roll( "Bomanz", 100 )

  -- Then
  sr_data = rf.softres.get( 22637 )[ 1 ]
  eq( sr_data.rolls, 1 )
end

function SoftResIntegrationSpec:should_not_allow_a_sr_winner_to_roll_again_if_the_same_item_drops()
  -- Given
  m.LootList.source_guid = "Jin'do the Hexxer"
  local dropped_item = item( "Primal Hakkari Idol", 22637 )
  local rf = clear_dropped_items_db()
  rf.db.awarded_loot = {}
  master_looter( "Jogobobek" )
  is_in_raid( leader( "Jogobobek" ), "Trololoo", "Bomanz", "Elizalee" )
  soft_res( sr( "Trololoo", 22637 ), sr( "Elizalee", 22637 ), sr( "Elizalee", 22637 ), sr( "Bomanz", 22637 ) )
  modifier_keys_not_pressed()

  -- When the first idol drops.
  -- Trololoo 100, Elizalee 35, Elizalee 27, Bomanz - passed
  targetting_enemy( "Jin'do the Hexxer" )
  loot( dropped_item )
  roll_for( "Primal Hakkari Idol", 1, 22637 )
  repeating_tick( 1 )
  roll( "Elizalee", 35 )
  roll( "Trololoo", 100 )
  repeating_tick( 1 )
  roll( "Elizalee", 27 )
  repeating_tick( 6 )
  run_command( "FR" )
  u.mock( "GiveMasterLoot", function() end )
  local candidate = mods.Types.make_item_candidate( "Trololoo", "Warlock", true )
  rf.roll_controller.award_confirmed( candidate, dropped_item )
  m.loot_facade.notify( "LootSlotCleared", 1 )
  m.loot_facade.notify( "LootClosed" )

  -- And then another idol drops.
  -- Bomanz 94, Eliza 81, Eliza 66, Trololoo - passed
  m.LootList.source_guid = "Bloodlord Mandokir"
  targetting_enemy( "Bloodlord Mandokir" )
  loot( dropped_item )
  roll_for( "Primal Hakkari Idol", 1, 22637 )
  repeating_tick( 2 )
  roll( "Bomanz", 94 )
  roll( "Elizalee", 81 )
  roll( "Elizalee", 66 )

  -- Then it should not count Trololoo in the list of SRers, because he already got one.
  m.chat.assert(
    r( "Jin'do the Hexxer dropped 1 item:", "1. [Primal Hakkari Idol] (SR by Bomanz, Elizalee [2 rolls] and Trololoo)" ),
    rw( "Roll for [Primal Hakkari Idol]: SR by Bomanz, Elizalee [2 rolls] and Trololoo" ),
    r( "Stopping rolls in 3", "2", "1" ),
    r( "SR rolls remaining: Bomanz (1 roll)" ),
    cr( "Trololoo rolled the highest (100) for [Primal Hakkari Idol] (SR)." ),
    rolling_finished(),
    c( "RollFor: Trololoo received [Primal Hakkari Idol]." ),
    r( "Bloodlord Mandokir dropped 1 item:", "1. [Primal Hakkari Idol] (SR by Bomanz and Elizalee [2 rolls])" ),
    rw( "Roll for [Primal Hakkari Idol]: SR by Bomanz and Elizalee [2 rolls]" ),
    cr( "Bomanz rolled the highest (94) for [Primal Hakkari Idol] (SR)." ),
    rolling_finished()
  )
end

function SoftResIntegrationSpec:should_not_allow_a_double_sr_winner_to_roll_again_if_the_same_item_drops()
  -- Given
  m.LootList.source_guid = "Jin'do the Hexxer"
  local dropped_item = item( "Primal Hakkari Idol", 22637 )
  local rf = clear_dropped_items_db()
  rf.db.awarded_loot = {}
  master_looter( "Jogobobek" )
  is_in_raid( leader( "Jogobobek" ), "Trololoo", "Bomanz", "Elizalee" )
  soft_res( sr( "Trololoo", 22637 ), sr( "Elizalee", 22637 ), sr( "Elizalee", 22637 ), sr( "Bomanz", 22637 ) )
  modifier_keys_not_pressed()

  -- When the first idol drops.
  targetting_enemy( "Jin'do the Hexxer" )
  loot( dropped_item )
  roll_for( "Primal Hakkari Idol", 1, 22637 )
  repeating_tick( 1 )
  roll( "Trololoo", 35 )
  roll( "Elizalee", 100 )
  repeating_tick( 1 )
  roll( "Elizalee", 27 )
  repeating_tick( 6 )
  run_command( "FR" )
  u.mock( "GiveMasterLoot", function() end )
  local candidate = mods.Types.make_item_candidate( "Elizalee", "Paladin", true )
  rf.roll_controller.award_confirmed( candidate, dropped_item )
  m.loot_facade.notify( "LootSlotCleared", 1 )
  m.loot_facade.notify( "LootClosed" )

  -- And then another idol drops.
  m.LootList.source_guid = "Bloodlord Mandokir"
  targetting_enemy( "Bloodlord Mandokir" )
  loot( dropped_item )
  roll_for( "Primal Hakkari Idol", 1, 22637 )
  repeating_tick( 2 )
  roll( "Bomanz", 94 )
  roll( "Trololoo", 81 )

  -- Then it should not count Elizalee in the list of SRers, because he already got one.
  m.chat.assert(
    r( "Jin'do the Hexxer dropped 1 item:", "1. [Primal Hakkari Idol] (SR by Bomanz, Elizalee [2 rolls] and Trololoo)" ),
    rw( "Roll for [Primal Hakkari Idol]: SR by Bomanz, Elizalee [2 rolls] and Trololoo" ),
    r( "Stopping rolls in 3", "2", "1" ),
    r( "SR rolls remaining: Bomanz (1 roll)" ),
    cr( "Elizalee rolled the highest (100) for [Primal Hakkari Idol] (SR)." ),
    rolling_finished(),
    c( "RollFor: Elizalee received [Primal Hakkari Idol]." ),
    r( "Bloodlord Mandokir dropped 1 item:", "1. [Primal Hakkari Idol] (SR by Bomanz and Trololoo)" ),
    rw( "Roll for [Primal Hakkari Idol]: SR by Bomanz and Trololoo" ),
    cr( "Bomanz rolled the highest (94) for [Primal Hakkari Idol] (SR)." ),
    rolling_finished()
  )
end

function SoftResIntegrationSpec:should_only_process_rolls_from_players_who_soft_ressed_if_players_name_was_auto_matched_and_finish_automatically()
  -- Given
  player( "Psikutas" )
  is_in_raid( leader( "Psikutas" ), "Sälvatrucha", "Ponpon" )
  soft_res( sr( "Psikutas", 123 ), sr( "Salvatrucha", 123 ), sr( "Ponpon", 123 ) )

  -- When
  roll_for( "Hearthstone", 1, 123 )
  roll( "Psikutas", 42 )
  repeating_tick( 5 )
  roll( "Sälvatrucha", 69 )
  repeating_tick( 2 )
  roll( "Ponpon", 1 )
  repeating_tick( 1 )

  -- Then
  m.chat.assert(
    rw( "Roll for [Hearthstone]: SR by Ponpon, Psikutas and Sälvatrucha" ),
    r( "Stopping rolls in 3", "2", "1" ),
    cr( "Sälvatrucha rolled the highest (69) for [Hearthstone] (SR)." ),
    rolling_finished()
  )
end

function SoftResIntegrationSpec:should_stop_rolling_if_player_who_won_still_has_extra_rolls()
  -- Given
  player( "Psikutas" )
  is_in_raid( leader( "Psikutas" ), "Obszczymucha", "Ponpon" )
  soft_res( sr( "Psikutas", 123 ), sr( "Ponpon", 123 ), sr( "Psikutas", 123 ) )

  -- When
  roll_for( "Hearthstone", 1, 123 )
  roll( "Psikutas", 69 )
  roll( "Ponpon", 42 )

  -- Then
  m.chat.assert(
    rw( "Roll for [Hearthstone]: SR by Ponpon and Psikutas [2 rolls]" ),
    cr( "Psikutas rolled the highest (69) for [Hearthstone] (SR)." ),
    rolling_finished()
  )
end

u.mock_libraries()
u.load_real_stuff_and_inject( module_registry, m )

os.exit( lu.LuaUnit.run() )
