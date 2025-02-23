package.path = "./?.lua;" .. package.path .. ";../?.lua;../RollFor/?.lua;../RollFor/libs/?.lua"

require( "src/bcc/compat" )
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
  { module_name = "Config",         mock = mock_config },
  { module_name = "RollController", variable_name = "roll_controller" },
  { module_name = "AwardedLoot",    variable_name = "awarded_loot" },
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
    rw( "Roll for [Hearthstone]: /roll (MS) or /roll 99 (OS) or /roll 98 (TMOG)" ),
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
    rw( "Roll for [Hearthstone]: /roll (MS) or /roll 99 (OS) or /roll 98 (TMOG)" ),
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
    rw( "Roll for [Hearthstone]: /roll (MS) or /roll 99 (OS) or /roll 98 (TMOG)" ),
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
    rw( "Roll for 2x[Hearthstone]: /roll (MS) or /roll 99 (OS) or /roll 98 (TMOG). 2 top rolls win." ),
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
    rw( "Roll for 2x[Hearthstone]: /roll (MS) or /roll 99 (OS) or /roll 98 (TMOG). 2 top rolls win." ),
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
    rw( "Roll for [Hearthstone]: /roll (MS) or /roll 99 (OS) or /roll 98 (TMOG)" ),
    cr( "Psikutas rolled the highest (69) for [Hearthstone]." ),
    rolling_finished()
  )
  eq( awarded_loot.has_item_been_awarded( "Psikutas", item.id ), false )

  -- And we confirm loot award and move, so the loot is closed.
  local candidate = make_item_candidate( "Psikutas", C.Warrior, true )
  controller.award_confirmed( candidate, item )
  loot_facade.notify( "LootClosed" )

  -- And also, Psikutas receives another item.
  loot_received( loot_facade, "Psikutas", u.item_link( "Some other item", 96 ) )

  -- Then
  eq( awarded_loot.has_item_been_awarded( "Psikutas", item.id ), false )

  -- And
  loot_received( loot_facade, "Psikutas", item.link )

  -- Then
  eq( awarded_loot.has_item_been_awarded( "Psikutas", item.id ), true )
  m.chat.assert(
    rw( "Roll for [Hearthstone]: /roll (MS) or /roll 99 (OS) or /roll 98 (TMOG)" ),
    cr( "Psikutas rolled the highest (69) for [Hearthstone]." ),
    rolling_finished(),
    c( "RollFor: Psikutas received [Hearthstone]." )
  )
end

u.mock_libraries()
u.load_real_stuff_and_inject( module_registry, m )

os.exit( lu.LuaUnit.run() )
