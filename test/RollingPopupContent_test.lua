package.path = "./?.lua;" .. package.path .. ";../?.lua;../RollFor/?.lua;../RollFor/libs/?.lua"

local u = require( "test/utils" )
local getn, frequire, reqsrc = u.getn, u.force_require, u.multi_require_src
local lu, eq = u.luaunit( "assertEquals" )
local m, T, IU = require( "src/modules" ), require( "src/Types" ), require( "src/ItemUtils" )
reqsrc( "DebugBuffer", "Module", "Types", "SoftResDataTransformer", "RollingLogicUtils" )
reqsrc( "TieRollingLogic", "SoftResRollingLogic", "NonSoftResRollingLogic", "RaidRollRollingLogic", "InstaRaidRollRollingLogic" )
local SoftResDecorator = require( "src/SoftResPresentPlayersDecorator" )
local SoftRes, Db = require( "src/SoftRes" ), require( "src/Db" )
local RollingLogic = require( "src/RollingLogic" )
local mock_random, random_roll, mock_multi_random_roll = u.mock_multiple_math_random, u.mock_random_roll, u.mock_multiple_random_roll
local tick, repeating_tick = u.tick, u.repeating_tick
local db = Db.new( {} )
local sr, make_data = u.soft_res_item, u.create_softres_data

---@diagnostic disable-next-line: unused-local
local c, r = u.console_message, u.raid_message
---@diagnostic disable-next-line: unused-local
local cr, rw = u.console_and_raid_message, u.raid_warning
---@diagnostic disable-next-line: unused-local
local rolling_finished, rolling_not_in_progress = u.rolling_finished, u.rolling_not_in_progress

local C, RT, RS = T.PlayerClass, T.RollType, T.RollingStrategy
local make_player, make_rolling_player = T.make_player, T.make_rolling_player

u.mock_wow_api()
local link = "item_link_with_icon"

---@param name string
---@param class PlayerClass?
---@return Player
local function p( name, class ) return make_player( name, class or C.Warrior, true ) end

---@param player Player
---@param rolls number?
---@return RollingPlayer
local function rp( player, rolls )
  return make_rolling_player( player.name, player.class, player.online, rolls or 1 )
end

local mock_roster = require( "mocks/GroupRosterApi" ).new

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

---@return ChatMock
local function mock_chat()
  ---@diagnostic disable-next-line: return-type-mismatch
  return require( "mocks/ChatApi" ).new()
end

---@return Config
local function mock_config( configuration )
  local config = configuration

  return {
    auto_raid_roll = function() return config and config.auto_raid_roll end,
    raid_roll_again = function() return config and config.raid_roll_again end,
    rolling_popup_lock = function() return config and config.rolling_popup_lock end,
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

---@param group_roster GroupRoster
---@param data table?
---@return GroupAwareSoftRes
local function group_aware_softres( group_roster, data )
  local raw_softres = SoftRes.new()
  local result = SoftResDecorator.new( group_roster, raw_softres )

  if data then
    result.import( data )
  end

  return result
end

---@param items (MasterLootDistributableItem)[]?
local function mock_loot_list( items )
  return frequire( "mocks/LootList" )( items or {} ).new()
end

local function new( dependencies, raid_roll, roll_item, insta_raid_roll, select_player )
  local deps = dependencies or {}

  local config = deps[ "Config" ] or mock_config()
  deps[ "Config" ] = config

  local player_info = require( "mocks/PlayerInfo" ).new( "Psikutas", "Warrior", true, true )
  deps[ "PlayerInfo" ] = player_info

  local group_roster_api = deps[ "GroupRosterApi" ] or mock_roster( { p( "Jogobobek", C.Warrior ), p( "Obszczymucha", C.Druid ) } )
  local group_roster = require( "src/GroupRoster" ).new( group_roster_api, player_info )
  deps[ "GroupRoster" ] = group_roster

  local chat_api = deps[ "ChatApi" ] or require( "mocks/ChatApi" ).new()
  local chat = deps[ "Chat" ] or require( "src/Chat" ).new( chat_api, group_roster, player_info )
  deps[ "Chat" ] = chat

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

  local softres = deps[ "SoftResData" ] and group_aware_softres( group_roster, deps[ "SoftResData" ] ) or group_aware_softres( group_roster )

  local roll_controller = require( "src/RollController" ).new(
    roll_tracker,
    player_info,
    ml_candidates,
    softres,
    loot_list,
    config
  )

  local master_loot_frame = require( "src/MasterLootCandidateSelectionFrame" ).new( winner_tracker, roll_controller, config )
  local awarded_loot = require( "src/AwardedLoot" ).new( db( "awarded_loot" ) )
  local loot_award_callback = require( "src/LootAwardCallback" ).new( awarded_loot, roll_controller, winner_tracker )
  local master_loot = require( "src/MasterLoot" ).new( ml_candidates, loot_award_callback, master_loot_frame, loot_list, roll_controller )
  deps[ "MasterLoot" ] = master_loot

  local strategy_factory = require( "src/RollingStrategyFactory" ).new(
    group_roster,
    loot_list,
    ml_candidates,
    chat,
    ace_timer,
    winner_tracker,
    config,
    softres,
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

  local popup_builder = require( "mocks/PopupBuilder" )
  local popup = require( "mocks/RollingPopup" ).new( popup_builder.new(), db( "dummy" ), config, roll_controller )
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

---@param name string
---@param id number?
---@param sr_players RollingPlayer[]?
---@param hr boolean?
---@return MasterLootDistributableItem
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

local function New()
  local dependencies = {}
  local M = {}

  ---@param chat_api ChatApi|ChatMock
  function M.chat( self, chat_api )
    dependencies[ "ChatApi" ] = chat_api
    return self
  end

  function M.config( self, config )
    dependencies[ "Config" ] = mock_config( config )
    return self
  end

  ---@param ... MasterLootDistributableItem[]
  function M.loot_list( self, ... )
    dependencies[ "LootList" ] = mock_loot_list( { ... } )
    return self
  end

  function M.no_master_loot_candidates( self )
    dependencies[ "MasterLootCandidatesApi" ] = require( "mocks/MasterLootCandidatesApi" ).new()
    return self
  end

  ---@param ... Player[]
  function M.roster( self, ... )
    dependencies[ "GroupRosterApi" ] = mock_roster( { ... } )
    return self
  end

  ---@param ... Player[]
  function M.raid_roster( self, ... )
    dependencies[ "GroupRosterApi" ] = mock_roster( { ... }, true )
    return self
  end

  function M.soft_res_data( self, ... )
    dependencies[ "SoftResData" ] = make_data( ... )
    return self
  end

  function M.build()
    return new( dependencies )
  end

  return M
end

RaidRollPopupContentSpec = {}

function RaidRollPopupContentSpec:should_return_initial_content()
  -- Given
  local item = i( "Hearthstone", 123 )
  local popup, controller = new()

  -- When
  controller.start( RS.RaidRoll, item, 1 )

  -- Then
  eq( popup.content(), {
    { type = link,         link = item.link,          count = 1 },
    { type = "text",       value = "Raid rolling...", padding = 8 },
    { type = "empty_line", height = 5 },
  } )
end

function RaidRollPopupContentSpec:should_return_initial_content_with_multiple_items_to_roll()
  -- Given
  local item = i( "Hearthstone", 123 )
  local popup, controller = new()

  -- When
  controller.start( RS.RaidRoll, item, 2 )

  -- Then
  eq( popup.content(), {
    { type = link,         link = item.link,          count = 2 },
    { type = "text",       value = "Raid rolling...", padding = 8 },
    { type = "empty_line", height = 5 },
  } )
end

function RaidRollPopupContentSpec:should_display_the_winner()
  -- Given
  local item = i( "Hearthstone", 123 )
  local popup, controller, roll = New()
      :config( { auto_raid_roll = true } )
      :roster( p( "Psikutas" ), p( "Jogobobek" ) )
      :build()

  -- When
  controller.start( RS.RaidRoll, item, 1 )
  random_roll( "Psikutas", 1, 2, roll )
  tick()

  -- Then
  eq( popup.content(), {
    { type = link,     count = 1,              link = item.link },
    { type = "text",   padding = 8,            value = "Jogobobek wins the raid-roll." },
    { type = "button", label = "Award winner", width = 130 },
    { type = "button", width = 70,             label = "Close" }
  } )
end

function RaidRollPopupContentSpec:should_display_the_winner_and_the_award_button()
  -- Given
  local item = i( "Hearthstone", 123 )
  local popup, controller, roll = New()
      :config( { auto_raid_roll = true } )
      :roster( p( "Psikutas" ), p( "Jogobobek" ) )
      :loot_list( item )
      :build()
  -- enable_debug( "RollController" )

  -- When
  controller.start( RS.RaidRoll, item, 1 )
  random_roll( "Psikutas", 2, 2, roll )
  tick()
  controller.award_aborted( item )

  -- Then
  eq( popup.content(), {
    { type = link,     count = 1,   link = item.link },
    { type = "text",   padding = 8, value = "Psikutas wins the raid-roll." },
    { type = "button", width = 130, label = "Award winner" },
    { type = "button", width = 70,  label = "Close" }
  } )
end

function RaidRollPopupContentSpec:should_display_the_winner_with_raid_roll_again_button()
  -- Given
  local item = i( "Hearthstone", 123 )
  local popup, controller, roll = New()
      :config( { auto_raid_roll = true, raid_roll_again = true } )
      :roster( p( "Psikutas" ), p( "Jogobobek" ) )
      :loot_list( item )
      :build()

  -- When
  controller.start( RS.RaidRoll, item, 1 )
  random_roll( "Psikutas", 2, 2, roll )
  tick()
  controller.award_aborted( item )

  -- Then
  eq( popup.content(), {
    { type = link,     count = 1,   link = item.link },
    { type = "text",   padding = 8, value = "Psikutas wins the raid-roll." },
    { type = "button", width = 130, label = "Award winner" },
    { type = "button", width = 130, label = "Raid roll again" },
    { type = "button", width = 70,  label = "Close" }
  } )
end

function RaidRollPopupContentSpec:should_display_the_winner_and_auto_raid_roll_info()
  -- Given
  local item = i( "Hearthstone", 123 )
  local popup, controller, roll = New()
      :config( { auto_raid_roll = false } )
      :roster( p( "Psikutas" ), p( "Jogobobek" ) )
      :loot_list( item )
      :build()

  -- When
  controller.start( RS.RaidRoll, item, 1 )
  random_roll( "Psikutas", 2, 2, roll )
  tick()
  controller.award_aborted( item )

  -- Then
  eq( popup.content(), {
    { type = link,     count = 1,                      link = item.link },
    { type = "text",   padding = 8,                    value = "Psikutas wins the raid-roll." },
    { type = "info",   anchor = "RollForRollingFrame", value = "Use /rf config auto-rr to enable auto raid-roll." },
    { type = "button", width = 130,                    label = "Award winner" },
    { type = "button", width = 70,                     label = "Close" }
  } )
end

function RaidRollPopupContentSpec:should_display_the_winners()
  -- Given
  local item = i( "Hearthstone", 123 )
  local popup, controller, roll = New()
      :config( { auto_raid_roll = true } )
      :roster( p( "Psikutas" ), p( "Jogobobek" ) )
      :build()

  -- When
  controller.start( RS.RaidRoll, item, 2 )
  mock_multi_random_roll( { { "Psikutas", 1, 2, roll }, { "Psikutas", 2, 2, roll } } )
  tick()

  -- Then
  eq( popup.content(), {
    { type = link,           count = 2,   link = item.link },
    { type = "text",         padding = 8, value = "Jogobobek wins the raid-roll." },
    { type = "award_button", padding = 6, label = "Award",                        width = 90 },
    { type = "text",         padding = 8, value = "Psikutas wins the raid-roll." },
    { type = "award_button", padding = 6, label = "Award",                        width = 90 },
    { type = "button",       width = 70,  label = "Close" }
  } )
end

function RaidRollPopupContentSpec:should_display_the_winners_and_the_individual_award_buttons()
  -- Given
  local item = i( "Hearthstone", 123 )
  local popup, controller, roll = New()
      :config( { auto_raid_roll = true } )
      :roster( p( "Psikutas" ), p( "Jogobobek" ) )
      :loot_list( item )
      :build()

  -- When
  controller.start( RS.RaidRoll, item, 2 )
  mock_multi_random_roll( { { "Psikutas", 1, 2, roll }, { "Psikutas", 2, 2, roll } } )
  tick()

  -- Then
  eq( popup.content(), {
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
  local item = i( "Hearthstone", 123 )
  local popup, controller, roll = New()
      :config( { auto_raid_roll = true } )
      :roster( p( "Psikutas" ), p( "Jogobobek" ) )
      :loot_list( item )
      :build()
  -- enable_debug( "RollController" )

  -- When
  controller.start( RS.RaidRoll, item, 1 )
  random_roll( "Psikutas", 2, 2, roll )
  tick()

  --- Then
  eq( popup.is_visible(), false )

  --- When
  controller.award_aborted( item )

  --- Then
  eq( popup.is_visible(), true )

  -- And
  eq( popup.content(), {
    { type = link,     count = 1,   link = item.link },
    { type = "text",   padding = 8, value = "Psikutas wins the raid-roll." },
    { type = "button", width = 130, label = "Award winner" },
    { type = "button", width = 70,  label = "Close" }
  } )
end

function RaidRollPopupContentSpec:should_display_the_remaining_winner_after_awarding_one()
  -- Given
  local item = i( "Hearthstone", 123 )
  local popup, controller, roll = New()
      :config( { auto_raid_roll = true } )
      :roster( p( "Psikutas" ), p( "Jogobobek" ) )
      :loot_list( item )
      :build()

  -- When
  controller.start( RS.RaidRoll, item, 2 )
  mock_multi_random_roll( { { "Psikutas", 1, 2, roll }, { "Psikutas", 2, 2, roll } } )
  tick()

  -- Then
  eq( popup.content(), {
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
  eq( popup.content(), {
    { type = link,     count = 1,   link = item.link },
    { type = "text",   padding = 8, value = "Psikutas wins the raid-roll." },
    { type = "button", width = 130, label = "Award winner" },
    { type = "button", width = 70,  label = "Close" }
  } )
end

InstaRaidRollPopupContentSpec = {}

function InstaRaidRollPopupContentSpec:should_display_the_winner()
  -- Given
  local item = i( "Hearthstone" )
  local popup, controller = New():roster( p( "Psikutas" ), p( "Obszczymucha" ) ):build()
  mock_random( { { 1, 2, 1 } } )

  -- When
  controller.start( RS.InstaRaidRoll, item, 1 )

  -- Then
  eq( popup.content(), {
    { type = link,     count = 1,              link = item.link },
    { type = "text",   padding = 8,            value = "Obszczymucha wins the insta raid-roll." },
    { type = "button", label = "Award winner", width = 130 },
    { type = "button", width = 70,             label = "Close" }
  } )
end

function InstaRaidRollPopupContentSpec:should_display_the_winner_and_the_award_button()
  -- Given
  local item = i( "Hearthstone" )
  local popup, controller = New()
      :roster( p( "Psikutas" ), p( "Obszczymucha" ) )
      :loot_list( item )
      :build()
  -- enable_debug( "RollController" )
  mock_random( { { 1, 2, 1 } } )

  -- When
  controller.start( RS.InstaRaidRoll, item, 1 )
  controller.award_aborted( item )

  -- Then
  eq( popup.content(), {
    { type = link,     count = 1,   link = item.link },
    { type = "text",   padding = 8, value = "Obszczymucha wins the insta raid-roll." },
    { type = "button", width = 130, label = "Award winner" },
    { type = "button", width = 70,  label = "Close" }
  } )
end

function InstaRaidRollPopupContentSpec:should_display_the_winner_with_award_and_raid_roll_again_buttons_if_the_award_was_aborted()
  -- Given
  local item = i( "Hearthstone" )
  local popup, controller = New()
      :config( { raid_roll_again = true } )
      :roster( p( "Psikutas" ), p( "Obszczymucha" ) )
      :loot_list( item )
      :build()
  local strategy = RS.InstaRaidRoll
  mock_random( { { 1, 2, 1 } } )

  -- When
  controller.start( strategy, item, 1 )
  controller.award_aborted( item )

  -- Then
  eq( popup.content(), {
    { type = link,     count = 1,   link = item.link },
    { type = "text",   padding = 8, value = "Obszczymucha wins the insta raid-roll." },
    { type = "button", width = 130, label = "Award winner" },
    { type = "button", width = 130, label = "Raid roll again" },
    { type = "button", width = 70,  label = "Close" }
  } )
end

function InstaRaidRollPopupContentSpec:should_display_the_winner_with_raid_roll_again_button_if_the_award_was_aborted()
  -- Given
  local item = i( "Hearthstone" )
  local popup, controller = New()
      :config( { raid_roll_again = true } )
      :roster( p( "Psikutas", C.Warrior ), p( "Obszczymucha", C.Druid ) )
      :build()
  mock_random( { { 1, 2, 1 } } )

  -- When
  controller.start( RS.InstaRaidRoll, item, 1 )
  controller.award_aborted( item )

  -- Then
  eq( popup.content(), {
    { type = link,     count = 1,              link = item.link },
    { type = "text",   padding = 8,            value = "Obszczymucha wins the insta raid-roll." },
    { type = "button", label = "Award winner", width = 130 },
    { type = "button", width = 130,            label = "Raid roll again" },
    { type = "button", width = 70,             label = "Close" }
  } )
end

function InstaRaidRollPopupContentSpec:should_display_the_winners_with_raid_roll_again_button()
  -- Given
  local item = i( "Hearthstone" )
  local popup, controller = New()
      :config( { raid_roll_again = true } )
      :roster( p( "Psikutas" ), p( "Jogobobek" ) )
      :build()
  mock_random( { { 1, 2, 2 }, { 1, 2, 1 } } )

  -- When
  controller.start( RS.InstaRaidRoll, item, 2 )

  -- Then
  eq( popup.content(), {
    { type = link,           count = 2,   link = item.link },
    { type = "text",         padding = 8, value = "Psikutas wins the insta raid-roll." },
    { type = "award_button", padding = 6, label = "Award",                              width = 90 },
    { type = "text",         padding = 8, value = "Jogobobek wins the insta raid-roll." },
    { type = "award_button", padding = 6, label = "Award",                              width = 90 },
    { type = "button",       width = 130, label = "Raid roll again" },
    { type = "button",       width = 70,  label = "Close" }
  } )
end

function InstaRaidRollPopupContentSpec:should_display_the_winners_without_raid_roll_again_button()
  -- Given
  local popup, controller = New()
      :config( { raid_roll_again = false } )
      :roster( p( "Psikutas" ), p( "Jogobobek" ) )
      :build()
  local item = i( "Hearthstone" )
  mock_random( { { 1, 2, 2 }, { 1, 2, 1 } } )

  -- When
  controller.start( RS.InstaRaidRoll, item, 2 )

  -- Then
  eq( popup.content(), {
    { type = link,           count = 2,   link = item.link },
    { type = "text",         padding = 8, value = "Psikutas wins the insta raid-roll." },
    { type = "award_button", padding = 6, label = "Award",                              width = 90 },
    { type = "text",         padding = 8, value = "Jogobobek wins the insta raid-roll." },
    { type = "award_button", padding = 6, label = "Award",                              width = 90 },
    { type = "button",       width = 70,  label = "Close" }
  } )
end

function InstaRaidRollPopupContentSpec:should_display_the_winners_and_the_individual_award_buttons_without_raid_roll_again_button()
  -- Given
  local item = i( "Hearthstone" )
  local popup, controller = New()
      :config( { raid_roll_again = false } )
      :roster( p( "Psikutas" ), p( "Jogobobek" ) )
      :loot_list( item )
      :build()
  mock_random( { { 1, 2, 2 }, { 1, 2, 1 } } )

  -- When
  controller.start( RS.InstaRaidRoll, item, 2 )

  -- Then
  eq( popup.content(), {
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
  local item = i( "Hearthstone" )
  local popup, controller = New()
      :config( { raid_roll_again = true } )
      :roster( p( "Psikutas" ), p( "Jogobobek" ) )
      :loot_list( item )
      :build()
  mock_random( { { 1, 2, 2 }, { 1, 2, 1 } } )

  -- When
  controller.start( RS.InstaRaidRoll, item, 2 )

  -- Then
  eq( popup.content(), {
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
  local item = i( "Hearthstone" )
  local chat = mock_chat() ---@type ChatMock
  local popup, controller = New()
      :chat( chat )
      :raid_roster( p( "Psikutas" ), p( "Jogobobek" ) )
      :build()

  -- When
  controller.start( RS.NormalRoll, item, 1, 8 )

  -- Then
  chat.assert(
    rw( "Roll for [Hearthstone]: /roll (MS) or /roll 99 (OS) or /roll 98 (TMOG)" )
  )

  -- And
  eq( popup.content(), {
    { type = link,     count = 1,    link = item.link },
    { type = "text",   padding = 11, value = "Rolling ends in 8 seconds." },
    { type = "button", width = 100,  label = "Finish early" },
    { type = "button", width = 100,  label = "Cancel" }
  } )
end

function NormalRollPopupContentSpec:should_return_initial_content_and_auto_raid_roll_message()
  -- Given
  local item = i( "Hearthstone" )
  local popup, controller = New():config( mock_config( { auto_raid_roll = true } ) ):build()

  -- When
  controller.start( RS.NormalRoll, item, 1, 8 )

  -- Then
  eq( popup.content(), {
    { type = link,     link = item.link,                     count = 1 },
    { type = "text",   value = "Rolling ends in 8 seconds.", padding = 11 },
    { type = "text",   value = "Auto raid-roll is enabled." },
    { type = "button", label = "Finish early",               width = 100 },
    { type = "button", label = "Cancel",                     width = 100 }
  } )
end

function NormalRollPopupContentSpec:should_update_rolling_ends_message()
  -- Given
  local item = i( "Hearthstone" )
  local popup, controller = new()

  -- When
  controller.start( RS.NormalRoll, item, 1, 8 )
  controller.tick( 5 )

  -- Then
  eq( popup.content(), {
    { type = link,     count = 1,    link = item.link },
    { type = "text",   padding = 11, value = "Rolling ends in 5 seconds." },
    { type = "button", width = 100,  label = "Finish early" },
    { type = "button", width = 100,  label = "Cancel" }
  } )
end

function NormalRollPopupContentSpec:should_display_cancel_message()
  -- Given
  local item = i( "Hearthstone" )
  local popup, controller = new()

  -- When
  controller.start( RS.NormalRoll, item, 1, 8 )
  controller.tick( 5 )
  controller.cancel_rolling()

  -- Then
  eq( popup.content(), {
    { type = link,     count = 1,    link = item.link },
    { type = "text",   padding = 11, value = "Rolling has been canceled." },
    { type = "button", width = 70,   label = "Close" }
  } )
end

function NormalRollPopupContentSpec:should_update_rolling_ends_message_for_one_second_left()
  -- Given
  local item = i( "Hearthstone" )
  local popup, controller = new()

  -- When
  controller.start( RS.NormalRoll, item, 1, 8 )
  controller.tick( 1 )

  -- Then
  eq( popup.content(), {
    { type = link,     count = 1,    link = item.link },
    { type = "text",   padding = 11, value = "Rolling ends in 1 second." },
    { type = "button", width = 100,  label = "Finish early" },
    { type = "button", width = 100,  label = "Cancel" }
  } )
end

function NormalRollPopupContentSpec:should_display_the_winners()
  -- Given
  local item, p1, p2 = i( "Hearthstone" ), p( "Psikutas" ), p( "Ohhaimark" )
  local popup, controller, roll = New():roster( p1, p2 ):no_master_loot_candidates():build()

  -- When
  controller.start( RS.NormalRoll, item, 1, 8 )
  roll( p1.name, 69, 1, 100 )
  roll( p2.name, 42, 1, 100 )

  -- Then
  eq( popup.content(), {
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
  local item, p1, p2 = i( "Hearthstone" ), p( "Psikutas" ), p( "Ohhaimark" )
  local popup, controller, roll = New():roster( p1, p2 ):build()

  -- When
  controller.start( RS.NormalRoll, item, 2, 8 )
  roll( p1.name, 69, 1, 100 )
  roll( p2.name, 42, 1, 100 )

  -- Then
  eq( popup.content(), {
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
  local item, p1, p2 = i( "Hearthstone" ), p( "Psikutas" ), p( "Ohhaimark" )
  local popup, controller, roll = New():roster( p1, p2 ):build()

  -- When
  controller.start( RS.NormalRoll, item, 1, 8 )
  roll( p1.name, 8, 1, 100 )
  roll( p2.name, 7, 1, 100 )

  -- Then
  eq( popup.content(), {
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
  local item, p1, p2 = i( "Hearthstone" ), p( "Psikutas" ), p( "Ohhaimark" )
  local popup, controller, roll = New():roster( p1, p2 ):build()

  -- When
  controller.start( RS.NormalRoll, item, 1, 8 )
  roll( p1.name, 8, 1, 100 )
  roll( p2.name, 11, 1, 100 )

  -- Then
  eq( popup.content(), {
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
  local item, p1, p2 = i( "Hearthstone" ), p( "Psikutas" ), p( "Ohhaimark" )
  local popup, controller, roll = New():roster( p1, p2 ):build()

  -- When
  controller.start( RS.NormalRoll, item, 1, 8 )
  roll( p1.name, 8, 1, 100 )
  roll( p2.name, 18, 1, 100 )

  -- Then
  eq( popup.content(), {
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
  local item, p1, p2, p3        = i( "Hearthstone" ), p( "Psikutas" ), p( "Obszczymucha" ), p( "Ponpon" )
  local popup, controller, roll = New():roster( p1, p2, p3 ):build()

  -- When
  controller.start( RS.NormalRoll, item, 1, 8 )
  roll( p1.name, 69, 1, 98 )
  roll( p1.name, 68, 1, 99 )
  roll( p1.name, 42, 1, 100 )
  roll( p2.name, 45, 1, 100 )
  roll( p3.name, 69, 1, 98 )
  roll( p3.name, 13, 1, 100 )

  -- Then
  eq( popup.content(), {
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
  local item, p1, p2            = i( "Hearthstone" ), p( "Psikutas" ), p( "Ohhaimark" )
  local popup, controller, roll = New():roster( p1, p2 ):build()

  -- When
  controller.start( RS.NormalRoll, item, 1, 8 )
  roll( p2.name, 42, 1, 99 )
  roll( p1.name, 69, 1, 99 )
  repeating_tick( 8 )

  -- Then
  eq( popup.content(), {
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
  local item, p1, p2            = i( "Hearthstone" ), p( "Psikutas" ), p( "Ohhaimark" )
  local popup, controller, roll = New():roster( p1, p2 ):build()

  -- When
  controller.start( RS.NormalRoll, item, 1, 8 )
  roll( p2.name, 42, 1, 98 )
  roll( p1.name, 69, 1, 98 )
  repeating_tick( 8 )

  -- Then
  eq( popup.content(), {
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
  local item, p1, p2            = i( "Hearthstone" ), p( "Psikutas" ), p( "Ohhaimark" )
  local popup, controller, roll = New():config( { auto_raid_roll = true } ):roster( p1, p2 ):build()

  -- When
  controller.start( RS.NormalRoll, item, 1, 8 )

  -- Then
  eq( popup.content(), {
    { type = link,     link = item.link,                     count = 1 },
    { type = "text",   value = "Rolling ends in 8 seconds.", padding = 11 },
    { type = "text",   value = "Auto raid-roll is enabled." },
    { type = "button", label = "Finish early",               width = 100 },
    { type = "button", label = "Cancel",                     width = 100 }
  } )

  -- When
  controller.finish_rolling_early()

  -- Then
  eq( popup.content(), {
    { type = link, link = item.link,   count = 1 },
    { padding = 8, type = "text",      value = "Raid rolling..." },
    { height = 5,  type = "empty_line" }
  } )

  -- And then
  random_roll( "Psikutas", 1, 2, roll )
  tick() -- To trigger the auto raid roll.

  -- Then
  random_roll( "Psikutas", 1, 2, roll )
  tick() -- To trigger the auto raid roll.

  -- Then
  eq( popup.content(), {
    { type = link,     link = item.link,                        count = 1 },
    { type = "text",   value = "Ohhaimark wins the raid-roll.", padding = 8 },
    { type = "button", label = "Award winner",                  width = 130 },
    { type = "button", label = "Close",                         width = 70 }
  } )
end

function NormalRollPopupContentSpec:should_not_close_the_popup_if_someone_loots_another_item_while_rolling()
  -- Given
  local item, p1, p2               = i( "Hearthstone" ), p( "Psikutas" ), p( "Obszczymucha" )
  local popup, controller, _, deps = New():roster( p1, p2 ):build()
  local master_loot                = deps[ "MasterLoot" ]

  -- When
  controller.start( RS.NormalRoll, item, 1, 8 )
  repeating_tick( 3 )

  -- Then
  eq( popup.is_visible(), true )

  -- And
  master_loot.on_loot_received( "Obszczymucha", 69, u.item_link( "Some item", 69 ) )

  -- Then
  eq( popup.is_visible(), true )

  -- Then
  eq( popup.content(), {
    { type = link,     count = 1,    link = item.link },
    { type = "text",   padding = 11, value = "Rolling ends in 5 seconds." },
    { type = "button", width = 100,  label = "Finish early" },
    { type = "button", width = 100,  label = "Cancel" }
  } )
end

SoftResRollPopupContentSpec = {}

function SoftResRollPopupContentSpec:should_preview_rolls()
  -- Given
  local item, p1, p2      = i( "Hearthstone", 123 ), p( "Psikutas" ), p( "Obszczymucha" )
  local popup, controller = New()
      :roster( p1, p2 )
      :soft_res_data( sr( p1.name, 123 ), sr( p1.name, 123 ), sr( p2.name, 123 ) )
      :build()

  -- When
  controller.preview( item, 1 )

  -- Then
  eq( popup.content(), {
    { type = link,     link = item.link,      tooltip_link = item.tooltip_link, count = 1 },
    { type = "roll",   player_name = p2.name, player_class = p2.class,          roll_type = RT.SoftRes, padding = 11 },
    { type = "roll",   player_name = p1.name, player_class = p1.class,          roll_type = RT.SoftRes },
    { type = "roll",   player_name = p1.name, player_class = p1.class,          roll_type = RT.SoftRes },
    { type = "button", label = "Roll",        width = 70 },
    { type = "button", label = "Award...",    width = 90 }
  } )
end

function SoftResRollPopupContentSpec:should_preview_the_winner_without_award_button_if_the_winner_is_not_a_candidate()
  -- Given
  local item, p1, p2      = i( "Hearthstone", 123 ), p( "Psikutas" ), p( "Obszczymucha" )
  local popup, controller = New()
      :roster( p1, p2 )
      :loot_list( item )
      :soft_res_data( sr( p1.name, 123 ) )
      :no_master_loot_candidates()
      :build()

  -- When
  controller.preview( item, 1 )

  -- Then
  eq( popup.content(), {
    { type = link,     link = item.link,                          tooltip_link = item.tooltip_link, count = 1 },
    { type = "text",   value = "Psikutas soft-ressed this item.", padding = 11 },
    { type = "button", label = "Close",                           width = 70 }
    -- { type = "button", label = "Award...",                        width = 90 }
  } )
end

function SoftResRollPopupContentSpec:should_preview_the_winner_with_award_button()
  -- Given
  local item, p1, p2      = i( "Hearthstone", 123 ), p( "Psikutas" ), p( "Obszczymucha" )
  local popup, controller = New()
      :roster( p1, p2 )
      :loot_list( item )
      :soft_res_data( sr( p1.name, 123 ) )
      :build()

  -- When
  controller.preview( item, 1 )

  -- Then
  eq( popup.content(), {
    { type = link,     link = item.link,                          tooltip_link = item.tooltip_link, count = 1 },
    { type = "text",   value = "Psikutas soft-ressed this item.", padding = 11 },
    { type = "button", label = "Award winner",                    width = 130 },
    { type = "button", label = "Close",                           width = 70 },
    { type = "button", label = "Award...",                        width = 90 }
  } )
end

function SoftResRollPopupContentSpec:should_preview_the_winners()
  -- Given
  local item, p1, p2      = i( "Hearthstone", 123 ), p( "Psikutas" ), p( "Obszczymucha" )
  local popup, controller = New()
      :roster( p1, p2 )
      :loot_list( item )
      :soft_res_data( sr( p1.name, 123 ), sr( p2.name, 123 ) )
      :build()

  -- When
  controller.preview( item, 2 )

  -- Then
  eq( popup.content(), {
    { type = link,           link = item.link,                              tooltip_link = item.tooltip_link, count = 2 },
    { type = "text",         value = "Obszczymucha soft-ressed this item.", padding = 11 },
    { type = "award_button", label = "Award",                               padding = 6,                      width = 90 },
    { type = "text",         value = "Psikutas soft-ressed this item.",     padding = 8 },
    { type = "award_button", label = "Award",                               padding = 6,                      width = 90 },
    { type = "button",       label = "Close",                               width = 70 },
    { type = "button",       label = "Award...",                            width = 90 }
  } )
end

function SoftResRollPopupContentSpec:should_return_initial_softres_content()
  -- Given
  local item, p1, p2      = i( "Hearthstone", 123 ), p( "Psikutas" ), p( "Obszczymucha" )
  local popup, controller = New()
      :roster( p1, p2 )
      :soft_res_data( sr( p1.name, 123 ), sr( p1.name, 123 ), sr( p2.name, 69, 2 ), sr( p2.name, 123 ) )
      :build()

  -- When
  controller.start( RS.SoftResRoll, item, 1, 7 )

  -- Then
  eq( popup.content(),
    {
      { type = link,     link = item.link,                     count = 1 },
      { type = "roll",   player_name = p2.name,                player_class = p2.class, roll_type = RT.SoftRes, padding = 11 },
      { type = "roll",   player_name = p1.name,                player_class = p1.class, roll_type = RT.SoftRes },
      { type = "roll",   player_name = p1.name,                player_class = p1.class, roll_type = RT.SoftRes },
      { type = "text",   value = "Rolling ends in 7 seconds.", padding = 11 },
      { type = "button", label = "Finish early",               width = 100 },
      { type = "button", label = "Cancel",                     width = 100 }
    } )
end

function SoftResRollPopupContentSpec:should_update_rolling_ends_message()
  -- Given
  local item, p1, p2      = i( "Hearthstone", 123 ), p( "Psikutas" ), p( "Obszczymucha" )
  local popup, controller = New()
      :roster( p1, p2 )
      :soft_res_data( sr( p1.name, 123 ), sr( p1.name, 123 ), sr( p2.name, 69, 2 ), sr( p2.name, 123 ) )
      :build()

  -- When
  controller.start( RS.SoftResRoll, item, 1, 7 )
  repeating_tick( 2 )

  -- Then
  eq( popup.content(),
    {
      { type = link,     link = item.link,                     count = 1 },
      { type = "roll",   player_name = p2.name,                player_class = p2.class, roll_type = RT.SoftRes, padding = 11 },
      { type = "roll",   player_name = p1.name,                player_class = p1.class, roll_type = RT.SoftRes },
      { type = "roll",   player_name = p1.name,                player_class = p1.class, roll_type = RT.SoftRes },
      { type = "text",   value = "Rolling ends in 5 seconds.", padding = 11 },
      { type = "button", label = "Finish early",               width = 100 },
      { type = "button", label = "Cancel",                     width = 100 }
    } )
end

function SoftResRollPopupContentSpec:should_update_rolling_ends_message_for_one_second_left()
  -- Given
  local item, p1, p2      = i( "Hearthstone", 123 ), p( "Psikutas" ), p( "Obszczymucha" )
  local popup, controller = New()
      :roster( p1, p2 )
      :soft_res_data( sr( p1.name, 123 ), sr( p1.name, 123 ), sr( p2.name, 69, 2 ), sr( p2.name, 123 ) )
      :build()

  -- When
  controller.start( RS.SoftResRoll, item, 1, 7 )
  repeating_tick( 6 )

  -- Then
  eq( popup.content(),
    {
      { type = link,     link = item.link,                    count = 1 },
      { type = "roll",   player_name = p2.name,               player_class = p2.class, roll_type = RT.SoftRes, padding = 11 },
      { type = "roll",   player_name = p1.name,               player_class = p1.class, roll_type = RT.SoftRes },
      { type = "roll",   player_name = p1.name,               player_class = p1.class, roll_type = RT.SoftRes },
      { type = "text",   value = "Rolling ends in 1 second.", padding = 11 },
      { type = "button", label = "Finish early",              width = 100 },
      { type = "button", label = "Cancel",                    width = 100 }
    } )
end

function SoftResRollPopupContentSpec:should_display_the_winner_if_the_winner_still_has_remaining_rolls()
  -- Given
  local item, p1, p2            = i( "Hearthstone", 123 ), p( "Psikutas" ), p( "Obszczymucha" )
  local popup, controller, roll = New()
      :roster( p1, p2 )
      :soft_res_data( sr( p1.name, 123 ), sr( p1.name, 123 ), sr( p2.name, 69, 2 ), sr( p2.name, 123 ) )
      :no_master_loot_candidates()
      :build()

  -- When
  controller.start( RS.SoftResRoll, item, 1, 7 )
  roll( p2.name, 42, 1, 100 )
  roll( p1.name, 69, 1, 100 )

  -- Then
  eq( popup.content(),
    {
      { type = link,     link = item.link,                                     count = 1 },
      { type = "roll",   player_name = p1.name,                                player_class = p1.class, roll_type = RT.SoftRes, roll = 69, padding = 11 },
      { type = "roll",   player_name = p2.name,                                player_class = p2.class, roll_type = RT.SoftRes, roll = 42 },
      { type = "roll",   player_name = p1.name,                                player_class = p1.class, roll_type = RT.SoftRes },
      { type = "text",   value = "Psikutas wins the soft-res roll with a 69.", padding = 11 },
      { type = "button", label = "Close",                                      width = 70 }
    } )
end

function SoftResRollPopupContentSpec:should_display_the_winner_if_the_winner_used_up_all_their_rolls()
  -- Given
  local item, p1, p2            = i( "Hearthstone", 123 ), p( "Psikutas" ), p( "Obszczymucha" )
  local popup, controller, roll = New()
      :roster( p1, p2 )
      :soft_res_data( sr( p1.name, 123 ), sr( p1.name, 123 ), sr( p2.name, 69, 2 ), sr( p2.name, 123 ) )
      :no_master_loot_candidates()
      :build()

  -- When
  controller.start( RS.SoftResRoll, item, 1, 7 )
  roll( p1.name, 12, 1, 100 )
  roll( p2.name, 42, 1, 100 )
  roll( p1.name, 69, 1, 100 )

  -- Then
  eq( popup.content(),
    {
      { type = link,     link = item.link,                                     count = 1 },
      { type = "roll",   player_name = p1.name,                                player_class = p1.class, roll_type = RT.SoftRes, roll = 69, padding = 11 },
      { type = "roll",   player_name = p2.name,                                player_class = p2.class, roll_type = RT.SoftRes, roll = 42 },
      { type = "roll",   player_name = p1.name,                                player_class = p1.class, roll_type = RT.SoftRes, roll = 12 },
      { type = "text",   value = "Psikutas wins the soft-res roll with a 69.", padding = 11 },
      { type = "button", label = "Close",                                      width = 70 }
    } )
end

function SoftResRollPopupContentSpec:should_display_the_winner_and_the_award_button()
  -- Given
  local item, p1, p2            = i( "Hearthstone", 123 ), p( "Psikutas" ), p( "Obszczymucha" )
  local popup, controller, roll = New()
      :roster( p1, p2 )
      :soft_res_data( sr( p1.name, 123 ), sr( p1.name, 123 ), sr( p2.name, 69, 2 ), sr( p2.name, 123 ) )
      :build()

  -- When
  controller.start( RS.SoftResRoll, item, 1, 7 )
  roll( p1.name, 12, 1, 100 )
  roll( p2.name, 42, 1, 100 )
  roll( p1.name, 69, 1, 100 )

  -- Then
  eq( popup.content(),
    {
      { type = link,     link = item.link,                                     count = 1 },
      { type = "roll",   player_name = p1.name,                                player_class = p1.class, roll_type = RT.SoftRes, roll = 69, padding = 11 },
      { type = "roll",   player_name = p2.name,                                player_class = p2.class, roll_type = RT.SoftRes, roll = 42 },
      { type = "roll",   player_name = p1.name,                                player_class = p1.class, roll_type = RT.SoftRes, roll = 12 },
      { type = "text",   value = "Psikutas wins the soft-res roll with a 69.", padding = 11 },
      { type = "button", label = "Award winner",                               width = 130 },
      { type = "button", label = "Close",                                      width = 70 }
    } )
end

function SoftResRollPopupContentSpec:should_display_the_only_soft_resser()
  -- Given
  local item, p1, p2      = i( "Hearthstone", 123 ), p( "Psikutas" ), p( "Obszczymucha" )
  local popup, controller = New()
      :roster( p1, p2 )
      :soft_res_data( sr( p1.name, 123 ) )
      :build()

  -- When
  controller.start( RS.SoftResRoll, item, 1, 7 )

  -- Then
  eq( popup.content(),
    {
      { type = link,     link = item.link,                          count = 1 },
      { type = "text",   value = "Psikutas soft-ressed this item.", padding = 11 },
      { type = "button", label = "Award winner",                    width = 130 },
      { type = "button", label = "Close",                           width = 70 },
      { type = "button", label = "Award...",                        width = 90 }
    } )
end

function SoftResRollPopupContentSpec:should_say_waiting_for_remaining_rolls()
  -- Given
  local item, p1, p2      = i( "Hearthstone", 123 ), p( "Psikutas" ), p( "Obszczymucha" )
  local popup, controller = New()
      :roster( p1, p2 )
      :soft_res_data( sr( p1.name, 123 ), sr( p1.name, 123 ), sr( p2.name, 69, 2 ), sr( p2.name, 123 ) )
      :build()

  -- When
  controller.start( RS.SoftResRoll, item, 1, 7 )
  repeating_tick( 7 )

  -- Then
  eq( popup.content(),
    {
      { type = link,     link = item.link,                         count = 1 },
      { type = "roll",   player_name = p2.name,                    player_class = p2.class, roll_type = RT.SoftRes, padding = 11 },
      { type = "roll",   player_name = p1.name,                    player_class = p1.class, roll_type = RT.SoftRes },
      { type = "roll",   player_name = p1.name,                    player_class = p1.class, roll_type = RT.SoftRes },
      { type = "text",   value = "Waiting for remaining rolls...", padding = 11 },
      { type = "button", label = "Finish early",                   width = 100 },
      { type = "button", label = "Cancel",                         width = 100 }
    } )
end

function SoftResRollPopupContentSpec:should_display_the_winners()
  -- Given
  local item, p1, p2      = i( "Hearthstone", 123 ), p( "Psikutas" ), p( "Obszczymucha" )
  local popup, controller = New()
      :roster( p1, p2 )
      :soft_res_data( sr( p1.name, 123 ), sr( p1.name, 123 ), sr( p2.name, 69, 2 ), sr( p2.name, 123 ) )
      :no_master_loot_candidates()
      :build()

  -- When
  controller.start( RS.SoftResRoll, item, 2, 7 )

  -- Then
  eq( popup.content(),
    {
      { type = link,     link = item.link,                              count = 2 },
      { type = "text",   value = "Obszczymucha soft-ressed this item.", padding = 11 },
      { type = "text",   value = "Psikutas soft-ressed this item.",     padding = 4 },
      { type = "button", label = "Close",                               width = 70 },
      { type = "button", label = "Award...",                            width = 90 }
    } )
end

function SoftResRollPopupContentSpec:should_display_the_winners_and_the_award_buttons()
  -- Given
  local item, p1, p2      = i( "Hearthstone", 123 ), p( "Psikutas" ), p( "Obszczymucha" )
  local popup, controller = New()
      :roster( p1, p2 )
      :soft_res_data( sr( p1.name, 123 ), sr( p1.name, 123 ), sr( p2.name, 69, 2 ), sr( p2.name, 123 ) )
      :build()

  -- When
  controller.start( RS.SoftResRoll, item, 2, 7 )

  -- Then
  eq( popup.content(),
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

function SoftResRollPopupContentSpec:should_properly_hide_and_show_the_popup_with_content_unchanged_after_aborting_the_award()
  -- Given
  local strategy                   = RS.SoftResRoll
  local item, p1, p2               = i( "Hearthstone", 123 ), p( "Psikutas" ), p( "Obszczymucha" )
  local popup, controller, _, deps = New()
      :roster( p1, p2 )
      :soft_res_data( sr( p1.name, 123 ), sr( p1.name, 123 ), sr( p2.name, 69, 2 ), sr( p2.name, 123 ) )
      :build()
  local to_winner                  = deps[ "MasterLootCandidates" ].transform_to_winner

  -- When
  controller.start( strategy, item, 2, 7 )

  -- Then
  eq( popup.is_visible(), true )
  controller.show_master_loot_confirmation( to_winner( rp( p1 ), item, RT.SoftRes ), item, strategy )
  eq( popup.is_visible(), false )
  controller.award_aborted( item )
  eq( popup.is_visible(), true )

  -- Then
  eq( popup.content(),
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

function SoftResRollPopupContentSpec:should_display_the_remaining_winner_after_awarding_one()
  -- Given
  local strategy                   = RS.SoftResRoll
  local item, p1, p2               = i( "Hearthstone", 123 ), p( "Psikutas" ), p( "Obszczymucha" )
  local popup, controller, _, deps = New()
      :roster( p1, p2 )
      :soft_res_data( sr( p1.name, 123 ), sr( p1.name, 123 ), sr( p2.name, 69, 2 ), sr( p2.name, 123 ) )
      :build()
  local to_winner                  = deps[ "MasterLootCandidates" ].transform_to_winner

  -- When
  controller.start( strategy, item, 2, 7 )

  -- Then
  eq( popup.is_visible(), true )
  controller.show_master_loot_confirmation( to_winner( rp( p1 ), item, RT.SoftRes ), item, strategy )
  eq( popup.is_visible(), false )
  controller.loot_awarded( "Psikutas", item.id, item.link )
  eq( popup.is_visible(), true )

  -- Then
  eq( popup.content(),
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
  local item, p1, p2            = i( "Hearthstone" ), p( "Psikutas" ), p( "Ohhaimark" )
  local popup, controller, roll = New():roster( p1, p2 ):build()

  -- When
  controller.start( RS.NormalRoll, item, 1, 8 )
  roll( p1.name, 69, 1, 100 )
  roll( p2.name, 69, 1, 100 )

  -- Then
  eq( popup.content(),
    {
      { type = link,         link = item.link,                count = 1 },
      { type = "roll",       player_name = p2.name,           player_class = p2.class, roll_type = RT.MainSpec, roll = 69,   padding = 11 },
      { type = "roll",       player_name = p1.name,           player_class = p1.class, roll_type = RT.MainSpec, roll = 69 },
      { type = "text",       value = "There was a tie (69):", padding = 11 },
      { type = "roll",       player_name = p2.name,           player_class = p2.class, roll_type = RT.MainSpec, padding = 11 },
      { type = "roll",       player_name = p1.name,           player_class = p1.class, roll_type = RT.MainSpec },
      { type = "empty_line", height = 5 }
    } )
end

function TieRollPopupContentSpec:should_display_tied_rolls_with_waiting_message()
  -- Given
  local item, p1, p2            = i( "Hearthstone" ), p( "Psikutas" ), p( "Ohhaimark" )
  local popup, controller, roll = New():roster( p1, p2 ):build()

  -- When
  controller.start( RS.NormalRoll, item, 1, 8 )
  roll( p1.name, 69, 1, 100 )
  roll( p2.name, 69, 1, 100 )
  tick()

  -- Then
  eq( popup.content(),
    {
      { type = link,     link = item.link,                         count = 1 },
      { type = "roll",   player_name = p2.name,                    player_class = p2.class, roll_type = RT.MainSpec, roll = 69,   padding = 11 },
      { type = "roll",   player_name = p1.name,                    player_class = p1.class, roll_type = RT.MainSpec, roll = 69 },
      { type = "text",   value = "There was a tie (69):",          padding = 11 },
      { type = "roll",   player_name = p2.name,                    player_class = p2.class, roll_type = RT.MainSpec, padding = 11 },
      { type = "roll",   player_name = p1.name,                    player_class = p1.class, roll_type = RT.MainSpec },
      { type = "text",   value = "Waiting for remaining rolls...", padding = 11 },
      { type = "button", label = "Finish early",                   width = 100 },
      { type = "button", label = "Cancel",                         width = 100 }
    } )
end

os.exit( lu.LuaUnit.run() )
