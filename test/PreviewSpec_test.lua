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
local db = Db.new( {} )
---@diagnostic disable-next-line: unused-local
local sr, make_data = u.soft_res_item, u.create_softres_data

---@diagnostic disable-next-line: unused-local
local c, r = u.console_message, u.raid_message
---@diagnostic disable-next-line: unused-local
local cr, rw = u.console_and_raid_message, u.raid_warning
---@diagnostic disable-next-line: unused-local
local rolling_finished, rolling_not_in_progress = u.rolling_finished, u.rolling_not_in_progress

---@diagnostic disable-next-line: unused-local
local C, RT, RS = T.PlayerClass, T.RollType, T.RollingStrategy
local make_player = T.make_player

u.mock_wow_api()
local link = "item_link_with_icon"

---@param name string
---@param class PlayerClass?
---@return Player
local function p( name, class ) return make_player( name, class or C.Warrior, true ) end

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

PreviewNotSoftRessedItemSpec = {}

function PreviewNotSoftRessedItemSpec:should_close_the_popup()
  -- Given
  local item = i( "Hearthstone", 123 )
  local popup, controller = New():build()

  -- When
  controller.preview( item, 1 )

  -- Then
  eq( popup.is_visible(), true )
  eq( popup.content(), {
    { type = link,     link = item.link, tooltip_link = item.tooltip_link, count = 1 },
    { type = "button", label = "Roll",   width = 70 },
    { type = "button", label = "Close",  width = 70 }
  } )

  -- When
  popup.click( "Close" )

  -- Then
  eq( popup.is_visible(), false )
end

function PreviewNotSoftRessedItemSpec:should_start_rolling()
  -- Given
  local chat = mock_chat() ---@type ChatMock
  local item = i( "Hearthstone", 123 )
  local popup, controller = New():chat( chat ):build()

  -- When
  controller.preview( item, 1 )

  -- Then
  eq( popup.is_visible(), true )
  eq( popup.content(), {
    { type = link,     link = item.link, tooltip_link = item.tooltip_link, count = 1 },
    { type = "button", label = "Roll",   width = 70 },
    { type = "button", label = "Close",  width = 70 }
  } )
  chat.assert()

  -- When
  popup.click( "Close" )

  -- Then
  eq( popup.is_visible(), false )
end

os.exit( lu.LuaUnit.run() )
