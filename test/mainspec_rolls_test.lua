package.path = "./?.lua;" .. package.path .. ";../?.lua;../RollFor/?.lua;../RollFor/libs/?.lua"

require( "src/compat" )
local u = require( "test/utils" )
local lu, eq = u.luaunit( "assertEquals" )
require( "src/modules" )
local player, leader = u.player, u.raid_leader
local is_in_raid = u.is_in_raid
local c, r = u.console_message, u.raid_message
local cr, rw = u.console_and_raid_message, u.raid_warning
local rolling_finished, rolling_not_in_progress = u.rolling_finished, u.rolling_not_in_progress
local roll_for, roll, finish_rolling = u.roll_for, u.roll, u.finish_rolling
local repeating_tick = u.repeating_tick
local t, i = require( "src/Types" ), require( "src/ItemUtils" )
local make_item_candidate, make_dropped_item = t.make_item_candidate, i.make_dropped_item
local C = t.PlayerClass
local alid = u.awarded_loot_item_data

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
        roll_threshold = function()
          return {
            value = 100,
            str = "/roll"
          }
        end,
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
  { module_name = "Config",         mock = mock_config },
  { module_name = "RollController", variable_name = "roll_controller" },
  { module_name = "AwardedLoot",    variable_name = "awarded_loot" },
  { module_name = "DroppedLoot",    variable_name = "dropped_loot" },
  { module_name = "RfTestLootFacade", variable_name = "rf_test_loot_facade" },
  { module_name = "EventBus",       variable_name = "event_bus" },
  { module_name = "LootList",       variable_name = "loot_list" },
  { module_name = "LootFacade",     variable_name = "loot_facade",    mock = "mocks/LootFacade" },
  { module_name = "ChatApi",        variable_name = "chat",           mock = "mocks/ChatApi" }
}

-- The modules will be injected here using the above module_registry.
local m = {}

MainspecRollsSpec = {}

function MainspecRollsSpec:should_finish_rolling_automatically_if_all_players_rolled()
  -- Given
  player( "Psikutas" )
  is_in_raid( leader( "Psikutas" ), "Obszczymucha" )

  -- When
  roll_for( "Hearthstone" )
  roll( "Psikutas", 69 )
  roll( "Obszczymucha", 42 )
  finish_rolling()

  -- Then
  m.chat.assert(
    rw( "Roll for [Hearthstone]: /roll (MS) or /roll 99 (OS)" ),
    cr( "Psikutas rolled the highest (69) for [Hearthstone]." ),
    rolling_finished(),
    rolling_not_in_progress()
  )
end

function MainspecRollsSpec:should_finish_rolling_after_the_timer_if_not_all_players_rolled()
  -- Given
  player( "Psikutas" )
  is_in_raid( leader( "Psikutas" ), "Obszczymucha" )

  -- When
  roll_for( "Hearthstone" )
  roll( "Psikutas", 69 )
  repeating_tick( 8 )
  finish_rolling()

  -- Then
  m.chat.assert(
    rw( "Roll for [Hearthstone]: /roll (MS) or /roll 99 (OS)" ),
    r( "Stopping rolls in 3", "2", "1" ),
    cr( "Psikutas rolled the highest (69) for [Hearthstone]." ),
    rolling_finished(),
    rolling_not_in_progress()
  )
end

function MainspecRollsSpec:should_detect_and_ignore_double_rolls()
  -- Given
  player( "Psikutas" )
  is_in_raid( leader( "Psikutas" ), "Obszczymucha" )

  -- When
  roll_for( "Hearthstone" )
  roll( "Obszczymucha", 13 )
  repeating_tick( 6 )
  roll( "Obszczymucha", 100 )
  roll( "Psikutas", 69 )

  -- Then
  m.chat.assert(
    rw( "Roll for [Hearthstone]: /roll (MS) or /roll 99 (OS)" ),
    r( "Stopping rolls in 3", "2" ),
    c( "RollFor: Obszczymucha exhausted their rolls. This roll (100) is ignored." ),
    cr( "Psikutas rolled the highest (69) for [Hearthstone]." ),
    rolling_finished()
  )
end

function MainspecRollsSpec:should_recognize_multiple_rollers_for_multiple_items_when_all_players_rolled()
  -- Given
  player( "Psikutas" )
  is_in_raid( leader( "Psikutas" ), "Obszczymucha" )

  -- When
  roll_for( "Hearthstone", 2 )
  roll( "Psikutas", 69 )
  roll( "Obszczymucha", 100 )

  -- Then
  m.chat.assert(
    rw( "Roll for 2x[Hearthstone]: /roll (MS) or /roll 99 (OS). 2 top rolls win." ),
    cr( "Obszczymucha rolled the highest (100) for [Hearthstone]." ),
    cr( "Psikutas rolled the next highest (69) for [Hearthstone]." ),
    rolling_finished()
  )
end

function MainspecRollsSpec:should_recognize_multiple_rollers_for_multiple_items_when_not_all_players_rolled()
  -- Given
  player( "Psikutas" )
  is_in_raid( leader( "Psikutas" ), "Obszczymucha", "Ponpon" )

  -- When
  roll_for( "Hearthstone", 2 )
  roll( "Psikutas", 69 )
  repeating_tick( 6 )
  roll( "Obszczymucha", 100 )
  repeating_tick( 2 )

  -- Then
  m.chat.assert(
    rw( "Roll for 2x[Hearthstone]: /roll (MS) or /roll 99 (OS). 2 top rolls win." ),
    r( "Stopping rolls in 3", "2", "1" ),
    cr( "Obszczymucha rolled the highest (100) for [Hearthstone]." ),
    cr( "Psikutas rolled the next highest (69) for [Hearthstone]." ),
    rolling_finished()
  )
end

---@param item MasterLootDistributableItem
local function loot_item( item )
  local loot_facade = m.loot_facade ---@type LootFacadeMock
  loot_facade.get_item_count = function() return 1 end
  loot_facade.get_link = function( _ ) return item.link end
  loot_facade.get_info = function( _ ) return { quality = 4, quantity = 1, texture = "chuj" } end
  u.mock( "GiveMasterLoot", function() end )
  loot_facade.notify( "LootOpened" )
end

---@param loot_facade LootFacadeMock
---@param player_name string
---@param item_link string
local function loot_received( loot_facade, player_name, item_link )
  loot_facade.notify( "ChatMsgLoot", string.format( "%s receives loot: %s", player_name, item_link ) )
end

-- Opening the corpse and emptying it are two things, and the simulator keeps them apart: the loot
-- frame is a window over what is still in there, so a /rftest that looted everything on the way in
-- would leave nothing to look at.
function MainspecRollsSpec:should_leave_simulated_loot_in_the_window()
  -- Given
  u.mock( "GetLootMethod", "master" )
  player( "Psikutas" )
  is_in_raid( leader( "Psikutas" ), "Obszczymucha" )

  u.mock( "GetItemInfo", function( item_id )
    return string.format( "Item %s", item_id ), u.item_link( "Item", item_id ), 4
  end )

  local cleared = {}
  m.rf_test_loot_facade.subscribe( "LootSlotCleared", function( slot ) table.insert( cleared, slot ) end )

  -- When
  u.run_command( "RFTEST" )

  -- Then (it dropped, and it is still there to be looked at)
  eq( m.dropped_loot.get_dropped_item_name( 29988 ), "Item 29988" )
  eq( cleared, {} )
  eq( RollFor.getn( m.loot_list.get_items() ) > 0, true )
end

function MainspecRollsSpec:should_register_simulated_loot_as_dropped_and_looted()
  -- Given
  u.mock( "GetLootMethod", "master" )
  player( "Psikutas" )
  is_in_raid( leader( "Psikutas" ), "Obszczymucha" )

  -- The simulator builds its items out of whatever the client knows about the ids it names, and
  -- skips the ones it knows nothing about -- so the cache has to answer here.
  u.mock( "GetItemInfo", function( item_id )
    return string.format( "Item %s", item_id ), u.item_link( "Item", item_id ), 4
  end )

  local cleared = {}
  m.rf_test_loot_facade.subscribe( "LootSlotCleared", function( slot ) table.insert( cleared, slot ) end )

  -- When
  u.run_command( "RFTEST" )
  u.run_command( "RFTEST", "loot" )

  -- Then (the dummy loot is on core's record of what dropped...)
  eq( m.dropped_loot.get_dropped_item_name( 29988 ), "Item 29988" )

  -- ...and every slot of it was looted, which is what anything downstream watches for
  eq( RollFor.getn( cleared ) > 0, true )
end

-- One slot at a time, for the half-emptied corpse a demo actually wants: some rows on the pending
-- list, the rest still in the loot window.
function MainspecRollsSpec:should_loot_a_single_simulated_slot()
  -- Given
  u.mock( "GetLootMethod", "master" )
  player( "Psikutas" )
  is_in_raid( leader( "Psikutas" ), "Obszczymucha" )

  u.mock( "GetItemInfo", function( item_id )
    return string.format( "Item %s", item_id ), u.item_link( "Item", item_id ), 4
  end )

  local cleared = {}
  m.rf_test_loot_facade.subscribe( "LootSlotCleared", function( slot ) table.insert( cleared, slot ) end )

  u.run_command( "RFTEST" )
  local dropped = RollFor.getn( m.loot_list.get_items() )

  -- When
  u.run_command( "RFTEST", "loot 2" )

  -- Then
  eq( cleared, { 2 } )
  eq( RollFor.getn( m.loot_list.get_items() ), dropped - 1 )
end

-- Slots are where an item is, not how many are left. Looting the first four and then asking for
-- the fifth was refused as out of range, because the count had come down to four while the slots
-- still standing were five to eight.
function MainspecRollsSpec:should_loot_a_slot_that_is_still_there_after_earlier_ones_went()
  -- Given
  u.mock( "GetLootMethod", "master" )
  player( "Psikutas" )
  is_in_raid( leader( "Psikutas" ), "Obszczymucha" )

  u.mock( "GetItemInfo", function( item_id )
    return string.format( "Item %s", item_id ), u.item_link( "Item", item_id ), 4
  end )

  local cleared = {}
  m.rf_test_loot_facade.subscribe( "LootSlotCleared", function( slot ) table.insert( cleared, slot ) end )

  u.run_command( "RFTEST" )

  -- When
  for slot = 1, 4 do u.run_command( "RFTEST", string.format( "loot %s", slot ) ) end
  u.run_command( "RFTEST", "loot 5" )

  -- Then
  eq( cleared, { 1, 2, 3, 4, 5 } )
end

-- An empty slot is not a slot to loot, whether it was emptied a moment ago or never existed.
function MainspecRollsSpec:should_refuse_a_simulated_slot_that_is_already_empty()
  -- Given
  u.mock( "GetLootMethod", "master" )
  player( "Psikutas" )
  is_in_raid( leader( "Psikutas" ), "Obszczymucha" )

  u.mock( "GetItemInfo", function( item_id )
    return string.format( "Item %s", item_id ), u.item_link( "Item", item_id ), 4
  end )

  local cleared = {}
  m.rf_test_loot_facade.subscribe( "LootSlotCleared", function( slot ) table.insert( cleared, slot ) end )

  u.run_command( "RFTEST" )

  -- When
  u.run_command( "RFTEST", "loot 2" )
  u.run_command( "RFTEST", "loot 2" )
  u.run_command( "RFTEST", "loot 99" )

  -- Then
  eq( cleared, { 2 } )
end

-- And what "loot" on its own means is whatever is left in there, not slots one through however
-- many that is.
function MainspecRollsSpec:should_empty_whatever_slots_are_left()
  -- Given
  u.mock( "GetLootMethod", "master" )
  player( "Psikutas" )
  is_in_raid( leader( "Psikutas" ), "Obszczymucha" )

  u.mock( "GetItemInfo", function( item_id )
    return string.format( "Item %s", item_id ), u.item_link( "Item", item_id ), 4
  end )

  u.run_command( "RFTEST" )
  local dropped = RollFor.getn( m.loot_list.get_items() )

  u.run_command( "RFTEST", "loot 8" )

  -- When
  u.run_command( "RFTEST", "loot" )

  -- Then
  eq( dropped, 8 )
  eq( RollFor.getn( m.loot_list.get_items() ), 0 )
end

-- What the simulator leaves behind is a raid's worth of loot nobody dropped, so it comes with a
-- way to put things back: the simulated window itself, core's record of what dropped, and -- for
-- anything keeping its own list off that record -- a word on the event bus.
function MainspecRollsSpec:should_clear_what_the_simulator_left_behind()
  -- Given
  u.mock( "GetLootMethod", "master" )
  player( "Psikutas" )
  is_in_raid( leader( "Psikutas" ), "Obszczymucha" )

  u.mock( "GetItemInfo", function( item_id )
    return string.format( "Item %s", item_id ), u.item_link( "Item", item_id ), 4
  end )

  local heard = 0
  m.event_bus.subscribe( "simulation_cleared", function() heard = heard + 1 end )

  u.run_command( "RFTEST" )
  eq( m.dropped_loot.get_dropped_item_name( 29988 ), "Item 29988" )

  -- When
  u.run_command( "RFTEST", "clear" )

  -- Then
  eq( m.dropped_loot.get_dropped_item_name( 29988 ), nil )
  eq( heard, 1 )
end

-- /award and /unaward are corrections to the record made by hand, but a correction to the record
-- is still an award: the pending list, the winner tracker and the announcement all hang off the
-- roll controller's word, and a command nobody downstream can hear leaves them all wrong.
function MainspecRollsSpec:should_announce_and_broadcast_an_awarded_item()
  -- Given
  player( "Psikutas" )
  is_in_raid( leader( "Psikutas" ), "Obszczymucha" )

  local awarded_loot = m.awarded_loot ---@type AwardedLoot
  local link = u.item_link( "Hearthstone", 123 )
  local heard = {}

  m.roll_controller.subscribe( "loot_awarded", function( event ) table.insert( heard, event.player_name ) end )

  -- When
  u.run_command( "AWARD", string.format( "Obszczymucha %s", link ) )

  -- Then
  eq( awarded_loot.has_item_been_awarded( "Obszczymucha", alid( 123 ) ), true )
  eq( heard, { "Obszczymucha" } )
  m.chat.assert( c( "RollFor: Obszczymucha received [Hearthstone]." ) )
end

function MainspecRollsSpec:should_broadcast_an_unawarded_item()
  -- Given
  player( "Psikutas" )
  is_in_raid( leader( "Psikutas" ), "Obszczymucha" )

  local awarded_loot = m.awarded_loot ---@type AwardedLoot
  local link = u.item_link( "Hearthstone", 123 )
  local heard = {}

  m.roll_controller.subscribe( "loot_unawarded", function( event ) table.insert( heard, event.player_name ) end )

  u.run_command( "AWARD", string.format( "Obszczymucha %s", link ) )

  -- When
  u.run_command( "UNAWARD", string.format( "Obszczymucha %s", link ) )

  -- Then
  eq( awarded_loot.has_item_been_awarded( "Obszczymucha", alid( 123 ) ), false )
  eq( heard, { "Obszczymucha" } )
end

-- The award is only complete when the player it was confirmed for actually gets the item.
--
-- "X receives loot" is how an award is reconciled when the loot frame closed before
-- LOOT_SLOT_CLEARED could fire (see LootFacadeListener). Until now it took anybody's name: the
-- master looter confirms an award to somebody, the assignment never goes through, they pick the
-- item up themselves -- and it is recorded as awarded to them. Nobody was awarded anything.
function MainspecRollsSpec:should_not_record_an_award_when_i_loot_the_item_myself()
  -- Given
  u.mock( "GetLootMethod", "master" )
  player( "Psikutas" )
  is_in_raid( leader( "Psikutas" ), "Obszczymucha" )
  local controller = m.roll_controller ---@type RollController
  local awarded_loot = m.awarded_loot ---@type AwardedLoot
  local loot_facade = m.loot_facade ---@type LootFacadeMock

  local link = u.item_link( "Hearthstone", 123 )
  local item = make_dropped_item( 123, "Hearthstone", link, "tooltip_link" )
  loot_item( item )
  roll_for( item.name, 1, item.id )
  roll( "Obszczymucha", 69 )

  -- When -- the award is confirmed for Obszczymucha and the loot frame closes before the
  -- assignment lands, so the item is still in the corpse.
  local candidate = make_item_candidate( "Obszczymucha", C.Druid, true )
  controller.award_confirmed( candidate, item )
  loot_facade.notify( "LootClosed" )

  -- And I pick it up myself.
  loot_received( loot_facade, "Psikutas", item.link )

  -- Then
  eq( awarded_loot.has_item_been_awarded( "Psikutas", alid( item.id ) ), false )
  eq( awarded_loot.has_item_been_awarded( "Obszczymucha", alid( item.id ) ), false )
end

function MainspecRollsSpec:should_only_record_loot_that_we_are_awarding()
  -- Given
  u.mock( "GetLootMethod", "master" )
  player( "Psikutas" )
  is_in_raid( leader( "Psikutas" ), "Obszczymucha" )
  local controller = m.roll_controller ---@type RollController
  local awarded_loot = m.awarded_loot ---@type AwardedLoot
  local loot_facade = m.loot_facade ---@type LootFacadeMock

  -- When
  local link = u.item_link( "Hearthstone", 123 )
  local item = make_dropped_item( 123, "Hearthstone", link, "tooltip_link" )
  loot_item( item )
  roll_for( item.name, 1, item.id )
  roll( "Obszczymucha", 13 )
  roll( "Psikutas", 69 )
  -- RollFor.MasterLoot.debug.enable( true )

  -- Then
  m.chat.assert(
    r( "1 item dropped:" ),
    r( "1. [Hearthstone]" ),
    rw( "Roll for [Hearthstone]: /roll (MS) or /roll 99 (OS)" ),
    cr( "Psikutas rolled the highest (69) for [Hearthstone]." ),
    rolling_finished()
  )
  eq( awarded_loot.has_item_been_awarded( "Psikutas", alid( item.id ) ), false )

  -- And we confirm loot award and move, so the loot is closed.
  local candidate = make_item_candidate( "Psikutas", C.Warrior, true )
  controller.award_confirmed( candidate, item )
  loot_facade.notify( "LootClosed" )

  -- And also, Psikutas receives another item.
  loot_received( loot_facade, "Psikutas", u.item_link( "Some other item", 96 ) )

  -- Then
  eq( awarded_loot.has_item_been_awarded( "Psikutas", alid( item.id ) ), false )

  -- And
  loot_received( loot_facade, "Psikutas", item.link )

  -- Then
  eq( awarded_loot.has_item_been_awarded( "Psikutas", alid( item.id ) ), true )
  m.chat.assert(
    r( "1 item dropped:" ),
    r( "1. [Hearthstone]" ),
    rw( "Roll for [Hearthstone]: /roll (MS) or /roll 99 (OS)" ),
    cr( "Psikutas rolled the highest (69) for [Hearthstone]." ),
    rolling_finished(),
    c( "RollFor: Psikutas received [Hearthstone]." )
  )
end

u.mock_libraries()
u.load_real_stuff_and_inject( module_registry, m )

os.exit( lu.LuaUnit.run() )
