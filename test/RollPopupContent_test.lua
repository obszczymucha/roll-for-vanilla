package.path = "./?.lua;" .. package.path .. ";../?.lua;../RollFor/?.lua;../RollFor/libs/?.lua"

local u = require( "test/utils" )
local getn, frequire, reqsrc = u.getn, u.force_require, u.multi_require_src
local lu, eq = u.luaunit( "assertEquals" )
local m, T, IU = require( "src/modules" ), require( "src/Types" ), require( "src/ItemUtils" )
reqsrc( "DebugBuffer", "Module", "Types", "SoftResDataTransformer", "RollingLogicUtils" )
reqsrc( "TieRollingLogic", "SoftResRollingLogic", "NonSoftResRollingLogic", "RaidRollRollingLogic", "InstaRaidRollRollingLogic" )
local SoftResDecorator = require( "src/SoftResPresentPlayersDecorator" )
local SoftRes, Db = require( "src/SoftRes" ), require( "src/Db" )
local RollingPopup, RollingLogic = require( "src/RollingPopup" ), require( "src/RollingLogic" )
local mock_random, mock_random_roll, mock_multi_random_roll = u.mock_multiple_math_random, u.mock_random_roll, u.mock_multiple_random_roll
local tick, repeating_tick = u.tick, u.repeating_tick
local db = Db.new( {} )
local sr, make_data = u.soft_res_item, u.create_softres_data

local C, RT, RS = T.PlayerClass, T.RollType, T.RollingStrategy
local make_player, make_rolling_player = T.make_player, T.make_rolling_player

u.mock_wow_api()
local link = "item_link_with_icon"

---@param name string
---@param class PlayerClass
---@return Player
local function p( name, class ) return make_player( name, class, true ) end

---@param player Player
---@param rolls number?
---@return RollingPlayer
local function rp( player, rolls )
  return make_rolling_player( player.name, player.class, player.online, rolls or 1 )
end

local mock_group_roster = require( "mocks/GroupRosterApi" ).new

---@diagnostic disable-next-line: unused-local, unused-function
local function enable_debug( ... )
  local module_names = { ... }

  for _, module_name in ipairs( module_names ) do
    local module = m[ module_name ]
    if module and module.debug and module.debug.enable then
      u.info( string.format( "Enabling debug for %s.", module_name ) )
      module.debug.enable( true )
    end
  end
end

---@return Config
local function mock_config( configuration )
  local c = configuration

  return {
    auto_raid_roll = function() return c and c.auto_raid_roll end,
    raid_roll_again = function() return c and c.raid_roll_again end,
    rolling_popup_lock = function() return c and c.rolling_popup_lock end,
    subscribe = function() end,
    rolling_popup = function() return true end,
    ms_roll_threshold = function() return 100 end,
    os_roll_threshold = function() return 99 end,
    tmog_roll_threshold = function() return 98 end,
    tmog_rolling_enabled = function() return true end,
    insta_raid_roll = function() return true end,
    default_rolling_time_seconds = function() return 8 end
  }
end

local function mock_popup( config, controller )
  local content

  local popup_builder = require( "mocks/PopupBuilder" )
  local popup = RollingPopup.new( popup_builder.new(), db( "dummy" ), config or mock_config(), controller )
  popup.get = function() return content end

  local old_refresh = popup.refresh
  popup.refresh = function( _, new_content )
    content = new_content
    old_refresh( _, new_content )
  end

  popup.is_visible = function()
    return popup.get_frame():IsVisible()
  end

  return popup
end

---@param group_roster GroupRoster
---@param data table?
---@return GroupedSoftRes
local function softres( group_roster, data )
  local raw_softres = SoftRes.new()
  local result = SoftResDecorator.new( group_roster, raw_softres )

  if data then
    result.import( data )
  end

  return result
end

---@param items (DroppedItem|SoftRessedDroppedItem|HardRessedDroppedItem)[]?
local function mock_loot_list( items )
  return frequire( "mocks/LootList" )( items or {} ).new()
end

local function new( dependencies, raid_roll, roll_item, insta_raid_roll, select_player )
  local deps = dependencies or {}

  local config = deps[ "Config" ] or mock_config()
  deps[ "Config" ] = config

  local player_info = require( "mocks/PlayerInfo" ).new( "Psikutas", "Warrior", true, true )
  deps[ "PlayerInfo" ] = player_info

  local chat = require( "mocks/Chat" ).new()
  deps[ "Chat" ] = chat

  local group_roster_api = deps[ "GroupRosterApi" ] or mock_group_roster( { p( "Jogobobek", C.Warrior ), p( "Obszczymucha", C.Druid ) } )
  local group_roster = require( "src/GroupRoster" ).new( group_roster_api, player_info )
  deps[ "GroupRoster" ] = group_roster

  local loot_list = deps[ "LootList" ] or mock_loot_list()
  deps[ "SoftResLootList" ] = loot_list

  local ml_candidates_api = deps[ "MasterLootCandidatesApi" ] or require( "mocks/MasterLootCandidatesApi" ).new( group_roster )
  local ml_candidates = require( "src/MasterLootCandidates" ).new( ml_candidates_api, group_roster )
  deps[ "MasterLootCandidates" ] = ml_candidates

  local ace_timer = u.mock_ace_timer()
  deps[ "AceTimer" ] = ace_timer

  local winner_tracker = require( "src/WinnerTracker" ).new( db( "winner_tracker" ) )
  deps[ "WinnerTracker" ] = winner_tracker

  local roll_tracker = require( "src/RollTracker" ).new()
  deps[ "RollTracker" ] = roll_tracker

  local roll_controller = require( "src/RollController" ).new(
    roll_tracker,
    player_info
  )

  local softres_dep = deps[ "SoftResData" ] and softres( group_roster, deps[ "SoftResData" ] ) or softres( group_roster )

  local strategy_factory = require( "src/RollingStrategyFactory" ).new(
    group_roster,
    loot_list,
    ml_candidates,
    chat,
    ace_timer,
    winner_tracker,
    config,
    softres_dep,
    player_info
  )
  deps[ "RollingStrategyFactory" ] = strategy_factory

  local rolling_logic = RollingLogic.new(
    chat,
    ace_timer,
    roll_controller,
    strategy_factory,
    ml_candidates,
    winner_tracker,
    config
  )
  deps[ "RollingLogic" ] = rolling_logic

  local popup = mock_popup( config, roll_controller )
  local noop = function() end

  local rolling_popup_content = require( "src/RollingPopupContent" ).new(
    popup,
    roll_controller,
    roll_tracker,
    loot_list,
    config,
    raid_roll or noop,
    roll_item or noop,
    insta_raid_roll or noop,
    select_player or noop
  )
  deps[ "RollingPopupContent" ] = rolling_popup_content

  if m.RollController.debug.is_enabled() then m.RollController.debug.disable() end
  return popup, roll_controller, rolling_logic.on_roll, deps
end

local function strip_functions( t )
  for _, line in ipairs( t ) do
    for k, v in pairs( line ) do
      if type( v ) == "function" then
        line[ k ] = nil
      end
    end
  end

  return t
end

---@param name string
---@param id number?
---@param sr_players RollingPlayer[]?
---@param hr boolean?
---@return DroppedItem|SoftRessedDroppedItem|HardRessedDroppedItem
local function i( name, id, sr_players, hr )
  local l = u.item_link( name, id )
  local tooltip_link = IU.get_tooltip_link( l )
  local item = IU.make_dropped_item( id or 123, name, l, tooltip_link )

  if hr then
    return IU.make_hardres_dropped_item( item )
  end

  if getn( sr_players or {} ) > 0 then
    return IU.make_softres_dropped_item( item, sr_players or {} )
  end

  return item
end

local function cleanse( t )
  return u.map( strip_functions( t ), function( v )
    if (v.type == "text" or v.type == "info") and v.value then
      v.value = u.decolorize( v.value ) or v.value
    end

    return v
  end )
end

RaidRollPopupContentSpec = {}

function RaidRollPopupContentSpec:should_return_initial_content()
  -- Given
  local popup, controller = new()
  local item = i( "Hearthstone", 123 )
  controller.start( RS.RaidRoll, item, 1 )

  -- Then
  eq( cleanse( popup.get() ), {
    { type = link,         link = item.link,          count = 1 },
    { type = "text",       value = "Raid rolling...", padding = 8 },
    { type = "empty_line", height = 5 },
  } )
end

function RaidRollPopupContentSpec:should_return_initial_content_with_multiple_items_to_roll()
  -- Given
  local popup, controller = new()
  local item = i( "Hearthstone", 123 )
  controller.start( RS.RaidRoll, item, 2 )

  -- Then
  eq( cleanse( popup.get() ), {
    { type = link,         link = item.link,          count = 2 },
    { type = "text",       value = "Raid rolling...", padding = 8 },
    { type = "empty_line", height = 5 },
  } )
end

function RaidRollPopupContentSpec:should_display_the_winner()
  -- Given
  local config = mock_config( { auto_raid_roll = true } )
  local group_roster = mock_group_roster( { p( "Psikutas", C.Warrior ), p( "Jogobobek", C.Warlock ) } )
  local popup, controller, roll = new( { [ "Config" ] = config, [ "GroupRosterApi" ] = group_roster } )
  local item = i( "Hearthstone", 123 )
  controller.start( RS.RaidRoll, item, 1 )
  mock_random_roll( "Psikutas", 1, 2, roll )
  tick()

  -- Then
  eq( cleanse( popup.get() ), {
    { type = link,     count = 1,   link = item.link },
    { type = "text",   padding = 8, value = "Jogobobek wins the raid-roll." },
    { type = "button", width = 70,  label = "Close" }
  } )
end

function RaidRollPopupContentSpec:should_display_the_winner_and_the_award_button()
  -- Given
  local config = mock_config( { auto_raid_roll = true } )
  local group_roster = mock_group_roster( { p( "Psikutas", C.Warrior ), p( "Jogobobek", C.Warlock ) } )
  local item = i( "Hearthstone", 123 )
  local loot_list = mock_loot_list( { item } )
  local popup, controller, roll = new( { [ "Config" ] = config, [ "GroupRosterApi" ] = group_roster, [ "LootList" ] = loot_list } )
  -- enable_debug( "RollController" )
  controller.start( RS.RaidRoll, item, 1 )
  mock_random_roll( "Psikutas", 2, 2, roll )
  tick()
  controller.award_aborted( item )

  -- Then
  eq( cleanse( popup.get() ), {
    { type = link,     count = 1,   link = item.link },
    { type = "text",   padding = 8, value = "Psikutas wins the raid-roll." },
    { type = "button", width = 130, label = "Award winner" },
    { type = "button", width = 70,  label = "Close" }
  } )
end

function RaidRollPopupContentSpec:should_display_the_winner_with_raid_roll_again_button()
  -- Given
  local config = mock_config( { auto_raid_roll = true, raid_roll_again = true } )
  local group_roster = mock_group_roster( { p( "Psikutas", C.Warrior ), p( "Jogobobek", C.Warlock ) } )
  local item = i( "Hearthstone", 123 )
  local loot_list = mock_loot_list( { item } )
  local popup, controller, roll = new( { [ "Config" ] = config, [ "GroupRosterApi" ] = group_roster, [ "LootList" ] = loot_list } )
  controller.start( RS.RaidRoll, item, 1 )
  mock_random_roll( "Psikutas", 2, 2, roll )
  tick()
  controller.award_aborted( item )

  -- Then
  eq( cleanse( popup.get() ), {
    { type = link,     count = 1,   link = item.link },
    { type = "text",   padding = 8, value = "Psikutas wins the raid-roll." },
    { type = "button", width = 130, label = "Award winner" },
    { type = "button", width = 130, label = "Raid roll again" },
    { type = "button", width = 70,  label = "Close" }
  } )
end

function RaidRollPopupContentSpec:should_display_the_winner_and_auto_raid_roll_info()
  -- Given
  local config = mock_config( { auto_raid_roll = false } )
  local group_roster = mock_group_roster( { p( "Psikutas", C.Warrior ), p( "Jogobobek", C.Warlock ) } )
  local item = i( "Hearthstone", 123 )
  local loot_list = mock_loot_list( { item } )
  local popup, controller, roll = new( { [ "Config" ] = config, [ "GroupRosterApi" ] = group_roster, [ "LootList" ] = loot_list } )
  controller.start( RS.RaidRoll, item, 1 )
  mock_random_roll( "Psikutas", 2, 2, roll )
  tick()
  controller.award_aborted( item )

  -- Then
  eq( cleanse( popup.get() ), {
    { type = link,     count = 1,                      link = item.link },
    { type = "text",   padding = 8,                    value = "Psikutas wins the raid-roll." },
    { type = "info",   anchor = "RollForRollingFrame", value = "Use /rf config auto-rr to enable auto raid-roll." },
    { type = "button", width = 130,                    label = "Award winner" },
    { type = "button", width = 70,                     label = "Close" }
  } )
end

function RaidRollPopupContentSpec:should_display_the_winners()
  -- Given
  local config = mock_config( { auto_raid_roll = true } )
  local group_roster = mock_group_roster( { p( "Psikutas", C.Warrior ), p( "Jogobobek", C.Warlock ) } )
  local item = i( "Hearthstone", 123 )
  local popup, controller, roll = new( { [ "Config" ] = config, [ "GroupRosterApi" ] = group_roster } )
  controller.start( RS.RaidRoll, item, 2 )
  mock_multi_random_roll( { { "Psikutas", 1, 2, roll }, { "Psikutas", 2, 2, roll } } )
  tick()

  -- Then
  eq( cleanse( popup.get() ), {
    { type = link,     count = 2,   link = item.link },
    { type = "text",   padding = 8, value = "Jogobobek wins the raid-roll." },
    { type = "text",   padding = 2, value = "Psikutas wins the raid-roll." },
    { type = "button", width = 70,  label = "Close" }
  } )
end

function RaidRollPopupContentSpec:should_display_the_winners_and_the_individual_award_buttons()
  -- Given
  local config = mock_config( { auto_raid_roll = true } )
  local group_roster = mock_group_roster( { p( "Psikutas", C.Warrior ), p( "Jogobobek", C.Warlock ) } )
  local item = i( "Hearthstone", 123 )
  local loot_list = mock_loot_list( { item } )
  local popup, controller, roll = new( { [ "Config" ] = config, [ "GroupRosterApi" ] = group_roster, [ "LootList" ] = loot_list } )
  controller.start( RS.RaidRoll, item, 2 )
  mock_multi_random_roll( { { "Psikutas", 1, 2, roll }, { "Psikutas", 2, 2, roll } } )
  tick()

  -- Then
  eq( cleanse( popup.get() ), {
    { type = link,           count = 2,   link = item.link },
    { type = "text",         padding = 8, value = "Jogobobek wins the raid-roll." },
    { type = "award_button", padding = 6, label = "Award",                        width = 90 },
    { type = "text",         padding = 8, value = "Psikutas wins the raid-roll." },
    { type = "award_button", padding = 6, label = "Award",                        width = 90 },
    { type = "button",       width = 70,  label = "Close" }
  } )
end

function RaidRollPopupContentSpec:should_properly_hide_and_show_the_popup_with_content_unchanged_after_aborting_the_award()
  -- Given
  local config = mock_config( { auto_raid_roll = true } )
  local group_roster = mock_group_roster( { p( "Psikutas", C.Warrior ), p( "Jogobobek", C.Warlock ) } )
  local item = i( "Hearthstone", 123 )
  local loot_list = mock_loot_list( { item } )
  local popup, controller, roll = new( { [ "Config" ] = config, [ "GroupRosterApi" ] = group_roster, [ "LootList" ] = loot_list } )
  -- enable_debug( "RollController" )
  controller.start( RS.RaidRoll, item, 1 )
  mock_random_roll( "Psikutas", 2, 2, roll )
  tick()

  --- Then
  eq( popup.is_visible(), false )

  --- When
  controller.award_aborted( item )

  --- Then
  eq( popup.is_visible(), true )

  -- And
  eq( cleanse( popup.get() ), {
    { type = link,     count = 1,   link = item.link },
    { type = "text",   padding = 8, value = "Psikutas wins the raid-roll." },
    { type = "button", width = 130, label = "Award winner" },
    { type = "button", width = 70,  label = "Close" }
  } )
end

function RaidRollPopupContentSpec:should_display_the_remaining_winner_after_awarding_one()
  -- Given
  local config = mock_config( { auto_raid_roll = true } )
  local group_roster = mock_group_roster( { p( "Psikutas", C.Warrior ), p( "Jogobobek", C.Warlock ) } )
  local item = i( "Hearthstone", 123 )
  local loot_list = mock_loot_list( { item } )
  local popup, controller, roll = new( { [ "Config" ] = config, [ "GroupRosterApi" ] = group_roster, [ "LootList" ] = loot_list } )
  controller.start( RS.RaidRoll, item, 2 )
  mock_multi_random_roll( { { "Psikutas", 1, 2, roll }, { "Psikutas", 2, 2, roll } } )
  tick()

  -- Then
  eq( cleanse( popup.get() ), {
    { type = link,           count = 2,   link = item.link },
    { type = "text",         padding = 8, value = "Jogobobek wins the raid-roll." },
    { type = "award_button", padding = 6, label = "Award",                        width = 90 },
    { type = "text",         padding = 8, value = "Psikutas wins the raid-roll." },
    { type = "award_button", padding = 6, label = "Award",                        width = 90 },
    { type = "button",       width = 70,  label = "Close" }
  } )

  -- eq( popup.is_visible(), true )
  -- controller.show_master_loot_confirmation( winners[ 1 ], item, strategy )
  -- eq( popup.is_visible(), false )
  controller.loot_awarded( "Jogobobek", item.id, item.link )
  eq( popup.is_visible(), true )

  -- Then
  eq( cleanse( popup.get() ), {
    { type = link,     count = 1,   link = item.link },
    { type = "text",   padding = 8, value = "Psikutas wins the raid-roll." },
    { type = "button", width = 130, label = "Award winner" },
    { type = "button", width = 70,  label = "Close" }
  } )
end

InstaRaidRollPopupContentSpec = {}

function InstaRaidRollPopupContentSpec:should_display_the_winner()
  -- Given
  local group_roster = mock_group_roster( { p( "Psikutas", C.Warrior ), p( "Obszczymucha", C.Druid ) } )
  local popup, controller = new( { [ "GroupRosterApi" ] = group_roster } )
  local item = i( "Hearthstone" )
  mock_random( { { 1, 2, 1 } } )
  controller.start( RS.InstaRaidRoll, item, 1 )

  -- Then
  eq( cleanse( popup.get() ), {
    { type = link,     count = 1,   link = item.link },
    { type = "text",   padding = 8, value = "Obszczymucha wins the insta raid-roll." },
    { type = "button", width = 70,  label = "Close" }
  } )
end

function InstaRaidRollPopupContentSpec:should_display_the_winner_and_the_award_button()
  -- Given
  local group_roster = mock_group_roster( { p( "Psikutas", C.Warrior ), p( "Obszczymucha", C.Druid ) } )
  local item = i( "Hearthstone" )
  local loot_list = mock_loot_list( { item } )
  local popup, controller = new( { [ "GroupRosterApi" ] = group_roster, [ "LootList" ] = loot_list } )
  enable_debug( "RollController" )
  mock_random( { { 1, 2, 1 } } )
  controller.start( RS.InstaRaidRoll, item, 1 )
  controller.award_aborted( item )

  -- Then
  eq( cleanse( popup.get() ), {
    { type = link,     count = 1,   link = item.link },
    { type = "text",   padding = 8, value = "Obszczymucha wins the insta raid-roll." },
    { type = "button", width = 130, label = "Award winner" },
    { type = "button", width = 70,  label = "Close" }
  } )
end

function InstaRaidRollPopupContentSpec:should_display_the_winner_with_award_and_raid_roll_again_buttons_if_the_award_was_aborted()
  -- Given
  local config = mock_config( { raid_roll_again = true } )
  local group_roster = mock_group_roster( { p( "Psikutas", C.Warrior ), p( "Obszczymucha", C.Druid ) } )
  local item = i( "Hearthstone" )
  local loot_list = mock_loot_list( { item } )
  local popup, controller = new( { [ "Config" ] = config, [ "GroupRosterApi" ] = group_roster, [ "LootList" ] = loot_list } )
  local strategy = RS.InstaRaidRoll
  mock_random( { { 1, 2, 1 } } )
  controller.start( strategy, item, 1 )
  controller.award_aborted( item )

  -- Then
  eq( cleanse( popup.get() ), {
    { type = link,     count = 1,   link = item.link },
    { type = "text",   padding = 8, value = "Obszczymucha wins the insta raid-roll." },
    { type = "button", width = 130, label = "Award winner" },
    { type = "button", width = 130, label = "Raid roll again" },
    { type = "button", width = 70,  label = "Close" }
  } )
end

function InstaRaidRollPopupContentSpec:should_display_the_winner_with_raid_roll_again_button_if_the_award_was_aborted()
  -- Given
  local config = mock_config( { raid_roll_again = true } )
  local group_roster = mock_group_roster( { p( "Psikutas", C.Warrior ), p( "Obszczymucha", C.Druid ) } )
  local popup, controller = new( { [ "Config" ] = config, [ "GroupRosterApi" ] = group_roster } )
  local item = i( "Hearthstone" )
  mock_random( { { 1, 2, 1 } } )
  controller.start( RS.InstaRaidRoll, item, 1 )
  controller.award_aborted( item )

  -- Then
  eq( cleanse( popup.get() ), {
    { type = link,     count = 1,   link = item.link },
    { type = "text",   padding = 8, value = "Obszczymucha wins the insta raid-roll." },
    { type = "button", width = 130, label = "Raid roll again" },
    { type = "button", width = 70,  label = "Close" }
  } )
end

function InstaRaidRollPopupContentSpec:should_display_the_winners_with_raid_roll_again_button()
  -- Given
  local config = mock_config( { raid_roll_again = true } )
  local group_roster = mock_group_roster( { p( "Psikutas", C.Warrior ), p( "Jogobobek", C.Warlock ) } )
  local popup, controller = new( { [ "Config" ] = config, [ "GroupRosterApi" ] = group_roster } )
  local item = i( "Hearthstone" )
  mock_random( { { 1, 2, 2 }, { 1, 2, 1 } } )
  controller.start( RS.InstaRaidRoll, item, 2 )

  -- Then
  eq( cleanse( popup.get() ), {
    { type = link,     count = 2,   link = item.link },
    { type = "text",   padding = 8, value = "Psikutas wins the insta raid-roll." },
    { type = "text",   padding = 2, value = "Jogobobek wins the insta raid-roll." },
    { type = "button", width = 130, label = "Raid roll again" },
    { type = "button", width = 70,  label = "Close" }
  } )
end

function InstaRaidRollPopupContentSpec:should_display_the_winners_without_raid_roll_again_button()
  -- Given
  local config = mock_config( { raid_roll_again = false } )
  local group_roster = mock_group_roster( { p( "Psikutas", C.Warrior ), p( "Jogobobek", C.Warlock ) } )
  local popup, controller = new( { [ "Config" ] = config, [ "GroupRosterApi" ] = group_roster } )
  local item = i( "Hearthstone" )
  mock_random( { { 1, 2, 2 }, { 1, 2, 1 } } )
  controller.start( RS.InstaRaidRoll, item, 2 )

  -- Then
  eq( cleanse( popup.get() ), {
    { type = link,     count = 2,   link = item.link },
    { type = "text",   padding = 8, value = "Psikutas wins the insta raid-roll." },
    { type = "text",   padding = 2, value = "Jogobobek wins the insta raid-roll." },
    { type = "button", width = 70,  label = "Close" }
  } )
end

function InstaRaidRollPopupContentSpec:should_display_the_winners_and_the_individual_award_buttons_without_raid_roll_again_button()
  -- Given
  local config = mock_config( { raid_roll_again = false } )
  local group_roster = mock_group_roster( { p( "Psikutas", C.Warrior ), p( "Jogobobek", C.Warlock ) } )
  local item = i( "Hearthstone" )
  local loot_list = mock_loot_list( { item } )
  local popup, controller = new( { [ "Config" ] = config, [ "GroupRosterApi" ] = group_roster, [ "LootList" ] = loot_list } )
  mock_random( { { 1, 2, 2 }, { 1, 2, 1 } } )
  controller.start( RS.InstaRaidRoll, item, 2 )

  -- Then
  eq( cleanse( popup.get() ), {
    { type = link,           count = 2,   link = item.link },
    { type = "text",         padding = 8, value = "Psikutas wins the insta raid-roll." },
    { type = "award_button", padding = 6, label = "Award",                              width = 90 },
    { type = "text",         padding = 8, value = "Jogobobek wins the insta raid-roll." },
    { type = "award_button", padding = 6, label = "Award",                              width = 90 },
    { type = "button",       width = 70,  label = "Close" }
  } )
end

function InstaRaidRollPopupContentSpec:should_display_the_winners_and_the_individual_award_buttons_with_raid_roll_again_button()
  -- Given
  local config = mock_config( { raid_roll_again = true } )
  local group_roster = mock_group_roster( { p( "Psikutas", C.Warrior ), p( "Jogobobek", C.Warlock ) } )
  local item = i( "Hearthstone" )
  local loot_list = mock_loot_list( { item } )
  local popup, controller = new( { [ "Config" ] = config, [ "GroupRosterApi" ] = group_roster, [ "LootList" ] = loot_list } )
  mock_random( { { 1, 2, 2 }, { 1, 2, 1 } } )
  controller.start( RS.InstaRaidRoll, item, 2 )

  -- Then
  eq( cleanse( popup.get() ), {
    { type = link,           count = 2,   link = item.link },
    { type = "text",         padding = 8, value = "Psikutas wins the insta raid-roll." },
    { type = "award_button", padding = 6, label = "Award",                              width = 90 },
    { type = "text",         padding = 8, value = "Jogobobek wins the insta raid-roll." },
    { type = "award_button", padding = 6, label = "Award",                              width = 90 },
    { type = "button",       width = 130, label = "Raid roll again" },
    { type = "button",       width = 70,  label = "Close" }
  } )
end

NormalRollPopupContentSpec = {}

function NormalRollPopupContentSpec:should_return_initial_content()
  -- Given
  local popup, controller = new()
  local item = i( "Hearthstone" )
  controller.start( RS.NormalRoll, item, 1, nil, 8 )

  -- Then
  eq( cleanse( popup.get() ), {
    { type = link,     count = 1,    link = item.link },
    { type = "text",   padding = 11, value = "Rolling ends in 8 seconds." },
    { type = "button", width = 100,  label = "Finish early" },
    { type = "button", width = 100,  label = "Cancel" }
  } )
end

function NormalRollPopupContentSpec:should_return_initial_content_and_auto_raid_roll_message()
  -- Given
  local popup, controller = new( { [ "Config" ] = mock_config( { auto_raid_roll = true } ) } )
  local item = i( "Hearthstone" )
  controller.start( RS.NormalRoll, item, 1, nil, 8 )

  -- Then
  eq( cleanse( popup.get() ), {
    { type = link,     link = item.link,                     count = 1 },
    { type = "text",   value = "Rolling ends in 8 seconds.", padding = 11 },
    { type = "text",   value = "Auto raid-roll is enabled." },
    { type = "button", label = "Finish early",               width = 100 },
    { type = "button", label = "Cancel",                     width = 100 }
  } )
end

function NormalRollPopupContentSpec:should_update_rolling_ends_message()
  -- Given
  local popup, controller = new()
  local item = i( "Hearthstone" )
  controller.start( RS.NormalRoll, item, 1, nil, 8 )
  controller.tick( 5 )

  -- Then
  eq( cleanse( popup.get() ), {
    { type = link,     count = 1,    link = item.link },
    { type = "text",   padding = 11, value = "Rolling ends in 5 seconds." },
    { type = "button", width = 100,  label = "Finish early" },
    { type = "button", width = 100,  label = "Cancel" }
  } )
end

function NormalRollPopupContentSpec:should_display_cancel_message()
  -- Given
  local popup, controller = new()
  local item = i( "Hearthstone" )
  controller.start( RS.NormalRoll, item, 1, nil, 8 )
  controller.tick( 5 )
  controller.cancel_rolling()

  -- Then
  eq( cleanse( popup.get() ), {
    { type = link,     count = 1,    link = item.link },
    { type = "text",   padding = 11, value = "Rolling has been canceled." },
    { type = "button", width = 70,   label = "Close" }
  } )
end

function NormalRollPopupContentSpec:should_update_rolling_ends_message_for_one_second_left()
  -- Given
  local popup, controller = new()
  local item = i( "Hearthstone" )
  controller.start( RS.NormalRoll, item, 1, nil, 8 )
  controller.tick( 1 )

  -- Then
  eq( cleanse( popup.get() ), {
    { type = link,     count = 1,    link = item.link },
    { type = "text",   padding = 11, value = "Rolling ends in 1 second." },
    { type = "button", width = 100,  label = "Finish early" },
    { type = "button", width = 100,  label = "Cancel" }
  } )
end

function NormalRollPopupContentSpec:should_display_the_winners()
  -- Given
  local p1, p2 = p( "Psikutas", C.Warrior ), p( "Ohhaimark", C.Priest )
  local ml_candidates_api = require( "mocks/MasterLootCandidatesApi" ).new()
  local group_roster = mock_group_roster( { p1, p2 } )
  local popup, controller, roll = new( { [ "GroupRosterApi" ] = group_roster, [ "MasterLootCandidatesApi" ] = ml_candidates_api } )
  local item = i( "Hearthstone" )
  controller.start( RS.NormalRoll, item, 1, nil, 8 )
  roll( p1.name, 69, 1, 100 )
  roll( p2.name, 42, 1, 100 )

  -- Then
  eq( cleanse( popup.get() ), {
    { type = link,     link = item.link,                                      count = 1 },
    { type = "roll",   roll_type = RT.MainSpec,                               player_name = p1.name, player_class = p1.class, roll = 69, padding = 11 },
    { type = "roll",   roll_type = RT.MainSpec,                               player_name = p2.name, player_class = p2.class, roll = 42 },
    { type = "text",   value = "Psikutas wins the main-spec roll with a 69.", padding = 11 },
    { type = "button", label = "Raid roll",                                   width = 90 },
    { type = "button", label = "Close",                                       width = 70 }
  } )
end

function NormalRollPopupContentSpec:should_display_the_winners_and_the_individual_award_buttons()
  -- Given
  local p1, p2 = p( "Psikutas", C.Warrior ), p( "Ohhaimark", C.Priest )
  local group_roster = mock_group_roster( { p1, p2 } )
  local popup, controller, roll = new( { [ "GroupRosterApi" ] = group_roster } )
  local item = i( "Hearthstone" )
  controller.start( RS.NormalRoll, item, 2, nil, 8 )
  roll( p1.name, 69, 1, 100 )
  roll( p2.name, 42, 1, 100 )

  -- Then
  eq( cleanse( popup.get() ), {
    { type = link,           link = item.link,                                       count = 2 },
    { type = "roll",         roll_type = RT.MainSpec,                                player_name = p1.name, player_class = p1.class, roll = 69, padding = 11 },
    { type = "roll",         roll_type = RT.MainSpec,                                player_name = p2.name, player_class = p2.class, roll = 42 },
    { type = "text",         value = "Psikutas wins the main-spec roll with a 69.",  padding = 11 },
    { type = "award_button", label = "Award",                                        padding = 6,           width = 90 },
    { type = "text",         value = "Ohhaimark wins the main-spec roll with a 42.", padding = 8 },
    { type = "award_button", label = "Award",                                        padding = 6,           width = 90 },
    { type = "button",       label = "Raid roll",                                    width = 90 },
    { type = "button",       label = "Close",                                        width = 70 }
  } )
end

function NormalRollPopupContentSpec:should_display_the_winner_with_proper_article_for_8()
  -- Given
  local p1, p2 = p( "Psikutas", C.Warrior ), p( "Ohhaimark", C.Priest )
  local group_roster = mock_group_roster( { p1, p2 } )
  local popup, controller, roll = new( { [ "GroupRosterApi" ] = group_roster } )
  local item = i( "Hearthstone" )
  controller.start( RS.NormalRoll, item, 1, nil, 8 )
  roll( p1.name, 8, 1, 100 )
  roll( p2.name, 7, 1, 100 )

  -- Then
  eq( cleanse( popup.get() ), {
    { type = link,     link = item.link,                                      count = 1 },
    { type = "roll",   roll_type = RT.MainSpec,                               player_name = p1.name, player_class = p1.class, roll = 8, padding = 11 },
    { type = "roll",   roll_type = RT.MainSpec,                               player_name = p2.name, player_class = p2.class, roll = 7 },
    { type = "text",   value = "Psikutas wins the main-spec roll with an 8.", padding = 11 },
    { type = "button", label = "Award winner",                                width = 130 },
    { type = "button", label = "Raid roll",                                   width = 90 },
    { type = "button", label = "Close",                                       width = 70 }
  } )
end

function NormalRollPopupContentSpec:should_display_the_winner_with_proper_article_for_11()
  -- Given
  local p1, p2 = p( "Psikutas", C.Warrior ), p( "Ohhaimark", C.Priest )
  local group_roster = mock_group_roster( { p1, p2 } )
  local popup, controller, roll = new( { [ "GroupRosterApi" ] = group_roster } )
  local item = i( "Hearthstone" )
  controller.start( RS.NormalRoll, item, 1, nil, 8 )
  roll( p1.name, 8, 1, 100 )
  roll( p2.name, 11, 1, 100 )

  -- Then
  eq( cleanse( popup.get() ), {
    { type = link,     link = item.link,                                        count = 1 },
    { type = "roll",   roll_type = RT.MainSpec,                                 player_name = p2.name, player_class = p2.class, roll = 11, padding = 11 },
    { type = "roll",   roll_type = RT.MainSpec,                                 player_name = p1.name, player_class = p1.class, roll = 8 },
    { type = "text",   value = "Ohhaimark wins the main-spec roll with an 11.", padding = 11 },
    { type = "button", label = "Award winner",                                  width = 130 },
    { type = "button", label = "Raid roll",                                     width = 90 },
    { type = "button", label = "Close",                                         width = 70 }
  } )
end

function NormalRollPopupContentSpec:should_display_the_winner_with_proper_article_for_18()
  -- Given
  local p1, p2 = p( "Psikutas", C.Warrior ), p( "Ohhaimark", C.Priest )
  local group_roster = mock_group_roster( { p1, p2 } )
  local popup, controller, roll = new( { [ "GroupRosterApi" ] = group_roster } )
  local item = i( "Hearthstone" )
  controller.start( RS.NormalRoll, item, 1, nil, 8 )
  roll( p1.name, 8, 1, 100 )
  roll( p2.name, 18, 1, 100 )

  -- Then
  eq( cleanse( popup.get() ), {
    { type = link,     link = item.link,                                        count = 1 },
    { type = "roll",   roll_type = RT.MainSpec,                                 player_name = p2.name, player_class = p2.class, roll = 18, padding = 11 },
    { type = "roll",   roll_type = RT.MainSpec,                                 player_name = p1.name, player_class = p1.class, roll = 8 },
    { type = "text",   value = "Ohhaimark wins the main-spec roll with an 18.", padding = 11 },
    { type = "button", label = "Award winner",                                  width = 130 },
    { type = "button", label = "Raid roll",                                     width = 90 },
    { type = "button", label = "Close",                                         width = 70 }
  } )
end

function NormalRollPopupContentSpec:should_sort_the_rolls()
  -- Given
  local p1, p2, p3 = p( "Psikutas", C.Warrior ), p( "Obszczymucha", C.Druid ), p( "Ponpon", C.Warlock )
  local group_roster = mock_group_roster( { p1, p2, p3 } )
  local popup, controller, roll = new( { [ "GroupRosterApi" ] = group_roster } )
  local item = i( "Hearthstone" )
  controller.start( RS.NormalRoll, item, 1, nil, 8 )
  roll( p1.name, 69, 1, 98 )
  roll( p1.name, 68, 1, 99 )
  roll( p1.name, 42, 1, 100 )
  roll( p2.name, 45, 1, 100 )
  roll( p3.name, 69, 1, 98 )
  roll( p3.name, 13, 1, 100 )

  -- Then
  eq( cleanse( popup.get() ), {
    { type = link,     link = item.link,                                          count = 1 },
    { type = "roll",   roll_type = RT.MainSpec,                                   player_name = p2.name, player_class = p2.class, roll = 45, padding = 11 },
    { type = "roll",   roll_type = RT.MainSpec,                                   player_name = p1.name, player_class = p1.class, roll = 42 },
    { type = "roll",   roll_type = RT.MainSpec,                                   player_name = p3.name, player_class = p3.class, roll = 13 },
    { type = "roll",   roll_type = RT.OffSpec,                                    player_name = p1.name, player_class = p1.class, roll = 68 },
    { type = "roll",   roll_type = RT.Transmog,                                   player_name = p3.name, player_class = p3.class, roll = 69 },
    { type = "roll",   roll_type = RT.Transmog,                                   player_name = p1.name, player_class = p1.class, roll = 69 },
    { type = "text",   value = "Obszczymucha wins the main-spec roll with a 45.", padding = 11 },
    { type = "button", label = "Award winner",                                    width = 130 },
    { type = "button", label = "Raid roll",                                       width = 90 },
    { type = "button", label = "Close",                                           width = 70 }
  } )
end

function NormalRollPopupContentSpec:should_display_the_off_spec_winner()
  -- Given
  local p1, p2 = p( "Psikutas", C.Warrior ), p( "Ohhaimark", C.Priest )
  local group_roster = mock_group_roster( { p1, p2 } )
  local popup, controller, roll = new( { [ "GroupRosterApi" ] = group_roster } )
  local item = i( "Hearthstone" )
  controller.start( RS.NormalRoll, item, 1, nil, 8 )
  roll( p2.name, 42, 1, 99 )
  roll( p1.name, 69, 1, 99 )
  repeating_tick( 8 )

  -- Then
  eq( cleanse( popup.get() ), {
    { type = link,     link = item.link,                                     count = 1 },
    { type = "roll",   roll_type = RT.OffSpec,                               player_name = p1.name, player_class = p1.class, roll = 69, padding = 11 },
    { type = "roll",   roll_type = RT.OffSpec,                               player_name = p2.name, player_class = p2.class, roll = 42 },
    { type = "text",   value = "Psikutas wins the off-spec roll with a 69.", padding = 11 },
    { type = "button", label = "Award winner",                               width = 130 },
    { type = "button", label = "Raid roll",                                  width = 90 },
    { type = "button", label = "Close",                                      width = 70 }
  } )
end

function NormalRollPopupContentSpec:should_display_the_transmog_winner()
  -- Given
  local p1, p2 = p( "Psikutas", C.Warrior ), p( "Ohhaimark", C.Priest )
  local group_roster = mock_group_roster( { p1, p2 } )
  local popup, controller, roll = new( { [ "GroupRosterApi" ] = group_roster } )
  local item = i( "Hearthstone" )
  controller.start( RS.NormalRoll, item, 1, nil, 8 )
  roll( p2.name, 42, 1, 98 )
  roll( p1.name, 69, 1, 98 )
  repeating_tick( 8 )

  -- Then
  eq( cleanse( popup.get() ), {
    { type = link,     link = item.link,                                     count = 1 },
    { type = "roll",   roll_type = RT.Transmog,                              player_name = p1.name, player_class = p1.class, roll = 69, padding = 11 },
    { type = "roll",   roll_type = RT.Transmog,                              player_name = p2.name, player_class = p2.class, roll = 42 },
    { type = "text",   value = "Psikutas wins the transmog roll with a 69.", padding = 11 },
    { type = "button", label = "Award winner",                               width = 130 },
    { type = "button", label = "Raid roll",                                  width = 90 },
    { type = "button", label = "Close",                                      width = 70 }
  } )
end

function NormalRollPopupContentSpec:should_auto_raid_roll_when_finishing_early_if_enabled()
  -- Given
  local p1, p2 = p( "Psikutas", C.Warrior ), p( "Ohhaimark", C.Priest )
  local group_roster = mock_group_roster( { p1, p2 } )
  local popup, controller, roll = new( { [ "Config" ] = mock_config( { auto_raid_roll = true } ), [ "GroupRosterApi" ] = group_roster } )
  local item = i( "Hearthstone" )
  controller.start( RS.NormalRoll, item, 1, nil, 8 )

  -- Then
  eq( cleanse( popup.get() ), {
    { type = link,     link = item.link,                     count = 1 },
    { type = "text",   value = "Rolling ends in 8 seconds.", padding = 11 },
    { type = "text",   value = "Auto raid-roll is enabled." },
    { type = "button", label = "Finish early",               width = 100 },
    { type = "button", label = "Cancel",                     width = 100 }
  } )

  -- When
  controller.finish_rolling_early()

  -- Then
  eq( cleanse( popup.get() ), {
    { type = link, link = item.link,   count = 1 },
    { padding = 8, type = "text",      value = "Raid rolling..." },
    { height = 5,  type = "empty_line" }
  } )

  -- And then
  mock_random_roll( "Psikutas", 1, 2, roll )
  tick() -- To trigger the auto raid roll.

  -- Then
  mock_random_roll( "Psikutas", 1, 2, roll )
  tick() -- To trigger the auto raid roll.

  -- Then
  eq( cleanse( popup.get() ), {
    { type = link,     link = item.link,                        count = 1 },
    { type = "text",   value = "Ohhaimark wins the raid-roll.", padding = 8 },
    { type = "button", label = "Close",                         width = 70 }
  } )
end

SoftResrollPopupContentSpec = {}

function SoftResrollPopupContentSpec:should_preview_rolls()
  -- Given
  local p1, p2 = p( "Psikutas", C.Warrior ), p( "Obszczymucha", C.Druid )
  local group_roster = mock_group_roster( { p1, p2 } )
  local popup, controller = new( { [ "GroupRosterApi" ] = group_roster } )
  local item = i( "Hearthstone", 123, { rp( p1, 2 ), rp( p2, 1 ) } )
  controller.preview( item, 1 )

  -- Then
  eq( cleanse( popup.get() ), {
    { type = link,     link = item.link,             count = 1 },
    { type = "roll",   player_name = "Obszczymucha", player_class = C.Druid,   roll_type = RT.SoftRes, padding = 11 },
    { type = "roll",   player_name = "Psikutas",     player_class = C.Warrior, roll_type = RT.SoftRes },
    { type = "roll",   player_name = "Psikutas",     player_class = C.Warrior, roll_type = RT.SoftRes },
    { type = "button", label = "Roll",               width = 70 },
    { type = "button", label = "Award...",           width = 90 }
  } )
end

function SoftResrollPopupContentSpec:should_preview_the_winner()
  -- Given
  local p1, p2 = p( "Psikutas", C.Warrior ), p( "Obszczymucha", C.Druid )
  local group_roster = mock_group_roster( { p1, p2 } )
  local popup, controller = new( { [ "GroupRosterApi" ] = group_roster } )
  local item = i( "Hearthstone", 123, { rp( p1, 1 ) } )
  controller.preview( item, 1 )

  -- Then
  eq( cleanse( popup.get() ), {
    { type = link,     link = item.link,                          count = 1 },
    { type = "text",   value = "Psikutas soft-ressed this item.", padding = 11 },
    { type = "button", label = "Close",                           width = 70 },
    { type = "button", label = "Award...",                        width = 90 }
  } )
end

function SoftResrollPopupContentSpec:should_preview_the_winners()
  -- Given
  local p1, p2 = p( "Psikutas", C.Warrior ), p( "Obszczymucha", C.Druid )
  local group_roster = mock_group_roster( { p1, p2 } )
  local popup, controller = new( { [ "GroupRosterApi" ] = group_roster } )
  local item = i( "Hearthstone", 123, { rp( p1, 2 ), rp( p2, 1 ) } )
  controller.preview( item, 2 )

  -- Then
  eq( cleanse( popup.get() ), {
    { type = link,     link = item.link,                              count = 2 },
    { type = "text",   value = "Obszczymucha soft-ressed this item.", padding = 11 },
    { type = "text",   value = "Psikutas soft-ressed this item.",     padding = 4 },
    { type = "button", label = "Close",                               width = 70 },
    { type = "button", label = "Award...",                            width = 90 }
  } )
end

function SoftResrollPopupContentSpec:should_return_initial_softres_content()
  -- Given
  local p1, p2 = p( "Psikutas", C.Warrior ), p( "Obszczymucha", C.Druid )
  local group_roster = mock_group_roster( { p1, p2 } )
  local data = make_data( sr( p1.name, 123 ), sr( p1.name, 123 ), sr( p2.name, 69, 2 ), sr( p2.name, 123 ) )
  local popup, controller = new( { [ "GroupRosterApi" ] = group_roster, [ "SoftResData" ] = data } )
  local item = i( "Hearthstone", 123, { rp( p1, 2 ), rp( p2, 1 ) } )
  controller.start( RS.SoftResRoll, item, 1, nil, 7 )

  -- Then
  eq( cleanse( popup.get() ),
    {
      { type = link,     link = item.link,                     count = 1 },
      { type = "roll",   player_name = "Obszczymucha",         player_class = C.Druid,   roll_type = RT.SoftRes, padding = 11 },
      { type = "roll",   player_name = "Psikutas",             player_class = C.Warrior, roll_type = RT.SoftRes },
      { type = "roll",   player_name = "Psikutas",             player_class = C.Warrior, roll_type = RT.SoftRes },
      { type = "text",   value = "Rolling ends in 7 seconds.", padding = 11 },
      { type = "button", label = "Finish early",               width = 100 },
      { type = "button", label = "Cancel",                     width = 100 }
    } )
end

function SoftResrollPopupContentSpec:should_update_rolling_ends_message()
  -- Given
  local p1, p2 = p( "Psikutas", C.Warrior ), p( "Obszczymucha", C.Druid )
  local group_roster = mock_group_roster( { p1, p2 } )
  local data = make_data( sr( p1.name, 123 ), sr( p1.name, 123 ), sr( p2.name, 69, 2 ), sr( p2.name, 123 ) )
  local popup, controller = new( { [ "GroupRosterApi" ] = group_roster, [ "SoftResData" ] = data } )
  local item = i( "Hearthstone", 123, { rp( p1, 2 ), rp( p2, 1 ) } )
  controller.start( RS.SoftResRoll, item, 1, nil, 7 )
  repeating_tick( 2 )

  -- Then
  eq( cleanse( popup.get() ),
    {
      { type = link,     link = item.link,                     count = 1 },
      { type = "roll",   player_name = "Obszczymucha",         player_class = C.Druid,   roll_type = RT.SoftRes, padding = 11 },
      { type = "roll",   player_name = "Psikutas",             player_class = C.Warrior, roll_type = RT.SoftRes },
      { type = "roll",   player_name = "Psikutas",             player_class = C.Warrior, roll_type = RT.SoftRes },
      { type = "text",   value = "Rolling ends in 5 seconds.", padding = 11 },
      { type = "button", label = "Finish early",               width = 100 },
      { type = "button", label = "Cancel",                     width = 100 }
    } )
end

function SoftResrollPopupContentSpec:should_update_rolling_ends_message_for_one_second_left()
  -- Given
  local p1, p2 = p( "Psikutas", C.Warrior ), p( "Obszczymucha", C.Druid )
  local group_roster = mock_group_roster( { p1, p2 } )
  local data = make_data( sr( p1.name, 123 ), sr( p1.name, 123 ), sr( p2.name, 69, 2 ), sr( p2.name, 123 ) )
  local popup, controller = new( { [ "GroupRosterApi" ] = group_roster, [ "SoftResData" ] = data } )
  local item = i( "Hearthstone", 123, { rp( p1, 2 ), rp( p2, 1 ) } )
  controller.start( RS.SoftResRoll, item, 1, nil, 7 )
  repeating_tick( 6 )

  -- Then
  eq( cleanse( popup.get() ),
    {
      { type = link,     link = item.link,                    count = 1 },
      { type = "roll",   player_name = "Obszczymucha",        player_class = C.Druid,   roll_type = RT.SoftRes, padding = 11 },
      { type = "roll",   player_name = "Psikutas",            player_class = C.Warrior, roll_type = RT.SoftRes },
      { type = "roll",   player_name = "Psikutas",            player_class = C.Warrior, roll_type = RT.SoftRes },
      { type = "text",   value = "Rolling ends in 1 second.", padding = 11 },
      { type = "button", label = "Finish early",              width = 100 },
      { type = "button", label = "Cancel",                    width = 100 }
    } )
end

function SoftResrollPopupContentSpec:should_display_the_winner_if_the_winner_still_has_remaining_rolls()
  -- Given
  local p1, p2 = p( "Psikutas", C.Warrior ), p( "Obszczymucha", C.Druid )
  local ml_candidates_api = require( "mocks/MasterLootCandidatesApi" ).new()
  local group_roster = mock_group_roster( { p1, p2 } )
  local data = make_data( sr( p1.name, 123 ), sr( p1.name, 123 ), sr( p2.name, 69, 2 ), sr( p2.name, 123 ) )
  local popup, controller, roll = new( { [ "GroupRosterApi" ] = group_roster, [ "SoftResData" ] = data, [ "MasterLootCandidatesApi" ] = ml_candidates_api } )
  local item = i( "Hearthstone", 123, { rp( p1, 2 ), rp( p2, 1 ) } )
  controller.start( RS.SoftResRoll, item, 1, nil, 7 )
  roll( p2.name, 42, 1, 100 )
  roll( p1.name, 69, 1, 100 )

  -- Then
  eq( cleanse( popup.get() ),
    {
      { type = link,     link = item.link,                                     count = 1 },
      { type = "roll",   player_name = "Psikutas",                             player_class = C.Warrior, roll_type = RT.SoftRes, roll = 69, padding = 11 },
      { type = "roll",   player_name = "Obszczymucha",                         player_class = C.Druid,   roll_type = RT.SoftRes, roll = 42 },
      { type = "roll",   player_name = "Psikutas",                             player_class = C.Warrior, roll_type = RT.SoftRes },
      { type = "text",   value = "Psikutas wins the soft-res roll with a 69.", padding = 11 },
      { type = "button", label = "Close",                                      width = 70 }
    } )
end

function SoftResrollPopupContentSpec:should_display_the_winner_if_the_winner_used_up_all_their_rolls()
  -- Given
  local p1, p2 = p( "Psikutas", C.Warrior ), p( "Obszczymucha", C.Druid )
  local ml_candidates_api = require( "mocks/MasterLootCandidatesApi" ).new()
  local group_roster = mock_group_roster( { p1, p2 } )
  local data = make_data( sr( p1.name, 123 ), sr( p1.name, 123 ), sr( p2.name, 69, 2 ), sr( p2.name, 123 ) )
  local popup, controller, roll = new( { [ "GroupRosterApi" ] = group_roster, [ "SoftResData" ] = data, [ "MasterLootCandidatesApi" ] = ml_candidates_api } )
  local item = i( "Hearthstone", 123, { rp( p1, 2 ), rp( p2, 1 ) } )
  controller.start( RS.SoftResRoll, item, 1, nil, 7 )
  roll( p1.name, 12, 1, 100 )
  roll( p2.name, 42, 1, 100 )
  roll( p1.name, 69, 1, 100 )

  -- Then
  eq( cleanse( popup.get() ),
    {
      { type = link,     link = item.link,                                     count = 1 },
      { type = "roll",   player_name = "Psikutas",                             player_class = C.Warrior, roll_type = RT.SoftRes, roll = 69, padding = 11 },
      { type = "roll",   player_name = "Obszczymucha",                         player_class = C.Druid,   roll_type = RT.SoftRes, roll = 42 },
      { type = "roll",   player_name = "Psikutas",                             player_class = C.Warrior, roll_type = RT.SoftRes, roll = 12 },
      { type = "text",   value = "Psikutas wins the soft-res roll with a 69.", padding = 11 },
      { type = "button", label = "Close",                                      width = 70 }
    } )
end

function SoftResrollPopupContentSpec:should_display_the_winner_and_the_award_button()
  -- Given
  local p1, p2 = p( "Psikutas", C.Warrior ), p( "Obszczymucha", C.Druid )
  local group_roster = mock_group_roster( { p1, p2 } )
  local data = make_data( sr( p1.name, 123 ), sr( p1.name, 123 ), sr( p2.name, 69, 2 ), sr( p2.name, 123 ) )
  local popup, controller, roll = new( { [ "GroupRosterApi" ] = group_roster, [ "SoftResData" ] = data } )
  local item = i( "Hearthstone", 123, { rp( p1, 2 ), rp( p2, 1 ) } )
  controller.start( RS.SoftResRoll, item, 1, nil, 7 )
  roll( p1.name, 12, 1, 100 )
  roll( p2.name, 42, 1, 100 )
  roll( p1.name, 69, 1, 100 )

  -- Then
  eq( cleanse( popup.get() ),
    {
      { type = link,     link = item.link,                                     count = 1 },
      { type = "roll",   player_name = "Psikutas",                             player_class = C.Warrior, roll_type = RT.SoftRes, roll = 69, padding = 11 },
      { type = "roll",   player_name = "Obszczymucha",                         player_class = C.Druid,   roll_type = RT.SoftRes, roll = 42 },
      { type = "roll",   player_name = "Psikutas",                             player_class = C.Warrior, roll_type = RT.SoftRes, roll = 12 },
      { type = "text",   value = "Psikutas wins the soft-res roll with a 69.", padding = 11 },
      { type = "button", label = "Award winner",                               width = 130 },
      { type = "button", label = "Close",                                      width = 70 }
    } )
end

function SoftResrollPopupContentSpec:should_display_the_only_soft_resser()
  -- Given
  local p1, p2 = p( "Psikutas", C.Warrior ), p( "Obszczymucha", C.Druid )
  local group_roster = mock_group_roster( { p1, p2 } )
  local data = make_data( sr( p1.name, 123 ) )
  local popup, controller = new( { [ "GroupRosterApi" ] = group_roster, [ "SoftResData" ] = data } )
  local item = i( "Hearthstone", 123 )
  controller.start( RS.SoftResRoll, item, 1, nil, 7 )

  -- Then
  eq( cleanse( popup.get() ),
    {
      { type = link,     link = item.link,                          count = 1 },
      { type = "text",   value = "Psikutas soft-ressed this item.", padding = 11 },
      { type = "button", label = "Award winner",                    width = 130 },
      { type = "button", label = "Close",                           width = 70 },
      { type = "button", label = "Award...",                        width = 90 }
    } )
end

function SoftResrollPopupContentSpec:should_say_waiting_for_remaining_rolls()
  -- Given
  local p1, p2 = p( "Psikutas", C.Warrior ), p( "Obszczymucha", C.Druid )
  local group_roster = mock_group_roster( { p1, p2 } )
  local data = make_data( sr( p1.name, 123 ), sr( p1.name, 123 ), sr( p2.name, 69, 2 ), sr( p2.name, 123 ) )
  local popup, controller = new( { [ "GroupRosterApi" ] = group_roster, [ "SoftResData" ] = data } )
  local item = i( "Hearthstone", 123, { rp( p1, 2 ), rp( p2, 1 ) } )
  controller.start( RS.SoftResRoll, item, 1, nil, 7 )
  repeating_tick( 7 )

  -- Then
  eq( cleanse( popup.get() ),
    {
      { type = link,     link = item.link,                         count = 1 },
      { type = "roll",   player_name = "Obszczymucha",             player_class = C.Druid,   roll_type = RT.SoftRes, padding = 11 },
      { type = "roll",   player_name = "Psikutas",                 player_class = C.Warrior, roll_type = RT.SoftRes },
      { type = "roll",   player_name = "Psikutas",                 player_class = C.Warrior, roll_type = RT.SoftRes },
      { type = "text",   value = "Waiting for remaining rolls...", padding = 11 },
      { type = "button", label = "Finish early",                   width = 100 },
      { type = "button", label = "Cancel",                         width = 100 }
    } )
end

function SoftResrollPopupContentSpec:should_display_the_winners()
  -- Given
  local p1, p2 = p( "Psikutas", C.Warrior ), p( "Obszczymucha", C.Druid )
  local group_roster = mock_group_roster( { p1, p2 } )
  local data = make_data( sr( p1.name, 123 ), sr( p1.name, 123 ), sr( p2.name, 69, 2 ), sr( p2.name, 123 ) )
  local ml_candidates_api = require( "mocks/MasterLootCandidatesApi" ).new()
  local popup, controller = new( { [ "GroupRosterApi" ] = group_roster, [ "SoftResData" ] = data, [ "MasterLootCandidatesApi" ] = ml_candidates_api } )
  local item = i( "Hearthstone", 123, { rp( p1, 2 ), rp( p2, 1 ) } )
  controller.start( RS.SoftResRoll, item, 2, nil, 7 )

  -- Then
  eq( cleanse( popup.get() ),
    {
      { type = link,     link = item.link,                              count = 2 },
      { type = "text",   value = "Obszczymucha soft-ressed this item.", padding = 11 },
      { type = "text",   value = "Psikutas soft-ressed this item.",     padding = 4 },
      { type = "button", label = "Close",                               width = 70 },
      { type = "button", label = "Award...",                            width = 90 }
    } )
end

function SoftResrollPopupContentSpec:should_display_the_winners_and_the_award_buttons()
  -- Given
  local p1, p2 = p( "Psikutas", C.Warrior ), p( "Obszczymucha", C.Druid )
  local group_roster = mock_group_roster( { p1, p2 } )
  local data = make_data( sr( p1.name, 123 ), sr( p1.name, 123 ), sr( p2.name, 69, 2 ), sr( p2.name, 123 ) )
  local popup, controller = new( { [ "GroupRosterApi" ] = group_roster, [ "SoftResData" ] = data } )
  local item = i( "Hearthstone", 123, { rp( p1, 2 ), rp( p2, 1 ) } )
  controller.start( RS.SoftResRoll, item, 2, nil, 7 )

  -- Then
  eq( cleanse( popup.get() ),
    {
      { type = link,           link = item.link,                              count = 2 },
      { type = "text",         value = "Obszczymucha soft-ressed this item.", padding = 11 },
      { type = "award_button", label = "Award",                               padding = 6, width = 90 },
      { type = "text",         value = "Psikutas soft-ressed this item.",     padding = 8 },
      { type = "award_button", label = "Award",                               padding = 6, width = 90 },
      { type = "button",       label = "Close",                               width = 70 },
      { type = "button",       label = "Award...",                            width = 90 }
    } )
end

function SoftResrollPopupContentSpec:should_properly_hide_and_show_the_popup_with_content_unchanged_after_aborting_the_award()
  -- Given
  local p1, p2 = p( "Psikutas", C.Warrior ), p( "Obszczymucha", C.Druid )
  local group_roster = mock_group_roster( { p1, p2 } )
  local data = make_data( sr( p1.name, 123 ), sr( p1.name, 123 ), sr( p2.name, 69, 2 ), sr( p2.name, 123 ) )
  local popup, controller, _, deps = new( { [ "GroupRosterApi" ] = group_roster, [ "SoftResData" ] = data } )
  local to_winner = deps[ "MasterLootCandidates" ].transform_to_winner
  local item = i( "Hearthstone", 123, { rp( p1, 2 ), rp( p2, 1 ) } )
  local strategy = RS.SoftResRoll
  controller.start( strategy, item, 2, nil, 7 )

  -- Then
  eq( popup.is_visible(), true )
  controller.show_master_loot_confirmation( to_winner( rp( p1 ), item, RT.SoftRes ), item, strategy )
  eq( popup.is_visible(), false )
  controller.award_aborted( item )
  eq( popup.is_visible(), true )

  -- Then
  eq( cleanse( popup.get() ),
    {
      { type = link,           link = item.link,                              count = 2 },
      { type = "text",         value = "Obszczymucha soft-ressed this item.", padding = 11 },
      { type = "award_button", label = "Award",                               padding = 6, width = 90 },
      { type = "text",         value = "Psikutas soft-ressed this item.",     padding = 8 },
      { type = "award_button", label = "Award",                               padding = 6, width = 90 },
      { type = "button",       label = "Close",                               width = 70 },
      { type = "button",       label = "Award...",                            width = 90 }
    } )
end

function SoftResrollPopupContentSpec:should_display_the_remaining_winner_after_awarding_one()
  -- Given
  local p1, p2 = p( "Psikutas", C.Warrior ), p( "Obszczymucha", C.Druid )
  local group_roster = mock_group_roster( { p1, p2 } )
  local data = make_data( sr( p1.name, 123 ), sr( p1.name, 123 ), sr( p2.name, 69, 2 ), sr( p2.name, 123 ) )
  local popup, controller, _, deps = new( { [ "GroupRosterApi" ] = group_roster, [ "SoftResData" ] = data } )
  local to_winner = deps[ "MasterLootCandidates" ].transform_to_winner
  local item = i( "Hearthstone", 123, { rp( p1, 2 ), rp( p2, 1 ) } )
  local strategy = RS.SoftResRoll
  controller.start( strategy, item, 2, nil, 7 )

  -- Then
  eq( popup.is_visible(), true )
  controller.show_master_loot_confirmation( to_winner( rp( p1 ), item, RT.SoftRes ), item, strategy )
  eq( popup.is_visible(), false )
  controller.loot_awarded( "Psikutas", item.id, item.link )
  eq( popup.is_visible(), true )

  -- Then
  eq( cleanse( popup.get() ),
    {
      { type = link,     link = item.link,                              count = 1 },
      { type = "text",   value = "Obszczymucha soft-ressed this item.", padding = 11 },
      { type = "button", label = "Award winner",                        width = 130 },
      { type = "button", label = "Close",                               width = 70 },
      { type = "button", label = "Award...",                            width = 90 }
    } )
end

TieRollPopupContentSpec = {}

function TieRollPopupContentSpec:should_display_tied_rolls()
  -- Given
  local p1, p2 = p( "Psikutas", C.Warrior ), p( "Ohhaimark", C.Priest )
  local ml_candidates_api = require( "mocks/MasterLootCandidatesApi" ).new()
  local group_roster = mock_group_roster( { p1, p2 } )
  local popup, controller, roll = new( { [ "GroupRosterApi" ] = group_roster, [ "MasterLootCandidatesApi" ] = ml_candidates_api } )
  local item = i( "Hearthstone" )
  controller.start( RS.NormalRoll, item, 1, nil, 8 )
  roll( p1.name, 69, 1, 100 )
  roll( p2.name, 69, 1, 100 )

  -- Then
  eq( cleanse( popup.get() ),
    {
      { type = link,   link = item.link,                count = 1 },
      { type = "roll", player_name = "Ohhaimark",       player_class = C.Priest,  roll_type = RT.MainSpec, roll = 69,   padding = 11 },
      { type = "roll", player_name = "Psikutas",        player_class = C.Warrior, roll_type = RT.MainSpec, roll = 69 },
      { type = "text", value = "There was a tie (69):", padding = 11 },
      { type = "roll", player_name = "Ohhaimark",       player_class = C.Priest,  roll_type = RT.MainSpec, padding = 11 },
      { type = "roll", player_name = "Psikutas",        player_class = C.Warrior, roll_type = RT.MainSpec }
    } )
end

function TieRollPopupContentSpec:should_display_tied_rolls_with_waiting_message()
  -- Given
  local p1, p2 = p( "Psikutas", C.Warrior ), p( "Ohhaimark", C.Priest )
  local ml_candidates_api = require( "mocks/MasterLootCandidatesApi" ).new()
  local group_roster = mock_group_roster( { p1, p2 } )
  local popup, controller, roll = new( { [ "GroupRosterApi" ] = group_roster, [ "MasterLootCandidatesApi" ] = ml_candidates_api } )
  local item = i( "Hearthstone" )
  controller.start( RS.NormalRoll, item, 1, nil, 8 )
  roll( p1.name, 69, 1, 100 )
  roll( p2.name, 69, 1, 100 )
  tick()

  -- Then
  eq( cleanse( popup.get() ),
    {
      { type = link,     link = item.link,                         count = 1 },
      { type = "roll",   player_name = "Ohhaimark",                player_class = C.Priest,  roll_type = RT.MainSpec, roll = 69,   padding = 11 },
      { type = "roll",   player_name = "Psikutas",                 player_class = C.Warrior, roll_type = RT.MainSpec, roll = 69 },
      { type = "text",   value = "There was a tie (69):",          padding = 11 },
      { type = "roll",   player_name = "Ohhaimark",                player_class = C.Priest,  roll_type = RT.MainSpec, padding = 11 },
      { type = "roll",   player_name = "Psikutas",                 player_class = C.Warrior, roll_type = RT.MainSpec },
      { type = "text",   value = "Waiting for remaining rolls...", padding = 11 },
      { type = "button", label = "Finish early",                   width = 100 },
      { type = "button", label = "Cancel",                         width = 100 }
    } )
end

os.exit( lu.LuaUnit.run() )
