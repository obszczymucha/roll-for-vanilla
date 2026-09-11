local u = require( "test/utils" )
local reqsrc = u.multi_require_src
local lu, eq = u.luaunit( "assertEquals" ) ---@diagnostic disable-line: unused-local
local m, T, IU = require( "src/modules" ), require( "src/Types" ), require( "src/ItemUtils" )
reqsrc( "DebugBuffer", "Module", "Types", "RollingLogicUtils", "RollTracker" )
reqsrc( "TieRollingLogic", "SoftResRollingLogic", "NonSoftResRollingLogic", "RaidRollRollingLogic", "InstaRaidRollRollingLogic" )
require( "src/AwardedLoot" )
local SoftResSourceMock = require( "mocks/SoftResSource" )
require( "src/Ordering" )
local Chain = require( "src/Chain" )
require( "src/DropTable" )
require( "src/SoftRes" )
local Db = require( "src/Db" )
local RollingLogic = require( "src/RollingLogic" )
local sr, hr = u.soft_res_item, u.hard_res_item ---@diagnostic disable-line: unused-local
local c, r, pm = u.console_message, u.raid_message, u.party_message ---@diagnostic disable-line: unused-local
local cr, rw = u.console_and_raid_message, u.raid_warning ---@diagnostic disable-line: unused-local
local C, RT, RS = T.PlayerClass, T.RollType, T.RollingStrategy ---@diagnostic disable-line: unused-local
local make_player = T.make_player
local BindType = IU.BindType

u.mock_wow_api()

local M = {}

---@param name string
---@param class PlayerClass?
---@return Player
function M.p( name, class ) return make_player( name, class or C.Warrior, true ) end

M.mock_roster = require( "mocks/GroupRosterApi" ).new

local function enable_debug( ... ) ---@diagnostic disable-line: unused-local, unused-function
  local module_names = { ... }

  for _, module_name in ipairs( module_names ) do
    local module = m[ module_name ]
    if module and module.debug and module.debug.enable then
      u.info( string.format( "Enabling debug for %s.", module_name ) )
      module.debug.enable( true )
    end
  end
end

---@return ChatApiMock
function M.mock_chat()
  return require( "mocks/ChatApi" ).new() ---@diagnostic disable-next-line: return-type-mismatch
end

---@return Config
function M.mock_config( configuration )
  local config = configuration

  return {
    auto_raid_roll = function() return config and config.auto_raid_roll end,
    raid_roll_again = function() return config and config.raid_roll_again end,
    rolling_popup_lock = function() return config and config.rolling_popup_lock end,
    subscribe = function() end,
    rolling_popup = function() return true end,
    ms_roll_threshold = function() return 100 end,
    os_roll_threshold = function() return 99 end,
    default_rolling_time_seconds = function() return 8 end,
    master_loot_frame_rows = function() return 5 end,
    sr_roll_spacing = function()
      if config and config.sr_roll_spacing then return config.sr_roll_spacing end
      return 24
    end,
    roll_threshold = function()
      return {
        value = 100,
        str = "/roll"
      }
    end,
    classic_look = function() return false end
  }
end

-- The same chain main.lua builds, and built the same way, through Chain, so that a test
-- can insert an extension's links exactly where the real addon would.
---@param group_roster GroupRoster
---@param awarded_loot AwardedLoot
---@param data table?
---@param extend fun( softres_chain: Chain, awarded_loot_chain: Chain )? -- stands in for Extensions.enable
---@return GroupAwareSoftRes
---@return AwardedLoot
local function group_aware_softres( group_roster, awarded_loot, data, extend )
  -- No backbone. matched_name, awarded_loot and present_players belong to whichever source
  -- extension is installed, and with none installed this is exactly what core's chain looks
  -- like: the source's data, and whatever core itself contributes on top.
  local awarded_loot_chain = Chain.new( "awarded_loot" )
  local softres_chain = Chain.new( "softres" )

  if extend then extend( softres_chain, awarded_loot_chain ) end

  local decorated_awarded_loot = awarded_loot_chain.build( awarded_loot ).final

  local result = softres_chain.build( SoftResSourceMock.new( data, function( name )
    local player = group_roster.find_player( name )
    return player and player.class
  end ) ).final

  return result, decorated_awarded_loot
end

function M.mock_loot_facade()
  return require( "mocks/LootFacade" ).new()
end

---@param name string
---@param id number?
---@param sr_players RollingPlayer[]?
---@param hard_ressed boolean?
---@param quality number?
---@param bind_type BindType?
---@return MasterLootDistributableItem
function M.i( name, id, sr_players, hard_ressed, quality, bind_type )
  local l = u.item_link( name, id )
  local tooltip_link = IU.get_tooltip_link( l )
  local item = IU.make_dropped_item( id or 123, name, l, tooltip_link, quality or 4, nil, nil, bind_type or BindType.None )

  if hard_ressed then
    return IU.make_hardres_dropped_item( item )
  end

  if sr_players and #sr_players > 0 then
    return IU.make_softres_dropped_item( item, sr_players )
  end

  return item
end

---@param name string
---@param id number?
---@param quality number?
---@param bind_type BindType?
---@return MasterLootDistributableItem
function M.qi( name, id, quality, bind_type )
  return M.i( name, id, nil, nil, quality, bind_type )
end

function M.new_roll_for()
  local dependencies = {}
  local builder = {}

  ---@param chat_api ChatApi|ChatApiMock
  function builder.chat( self, chat_api )
    dependencies[ "ChatApi" ] = chat_api
    return self
  end

  function builder.config( self, config )
    dependencies[ "Config" ] = M.mock_config( config )
    return self
  end

  ---@param loot_facade LootFacadeMock
  function builder.loot_facade( self, loot_facade )
    dependencies[ "LootFacade" ] = loot_facade
    return self
  end

  function builder.no_master_loot_candidates( self )
    dependencies[ "MasterLootCandidatesApi" ] = require( "mocks/MasterLootCandidatesApi" ).new()
    return self
  end

  ---@param ... Player[]
  function builder.roster( self, ... )
    dependencies[ "GroupRosterApi" ] = M.mock_roster( { ... } )
    return self
  end

  ---@param ... Player[]
  function builder.raid_roster( self, ... )
    dependencies[ "GroupRosterApi" ] = M.mock_roster( { ... }, true )
    return self
  end

  function builder.soft_res_data( self, ... )
    dependencies[ "SoftResData" ] = { ... }
    return self
  end

  ---@param threshold number
  -- Remembered rather than applied here: build() sets the threshold itself, and applying it
  -- now would just be overwritten a moment later. That is what it used to do, which made
  -- this setter look like it worked and do nothing.
  function builder.loot_threshold( self, threshold )
    dependencies[ "LootThreshold" ] = threshold
    return self
  end

  function builder.build()
    u.mock_slashcmdlist() -- Drop the previous build's commands so this one can register its own.
    u.zone_name()
    -- Uncommon unless a test said otherwise, which is what nearly every one of them wants.
    u.loot_threshold( dependencies[ "LootThreshold" ] or 2 )
    u.targetting_enemy( "Princess Kenny" )

    local deps = dependencies or {}
    local db = Db.new( {} )

    local config = deps[ "Config" ] or M.mock_config()
    deps[ "Config" ] = config

    local player_info = require( "mocks/PlayerInfo" ).new( "Psikutas", "Warrior", true, true )
    deps[ "PlayerInfo" ] = player_info

    local group_roster_api = deps[ "GroupRosterApi" ] or M.mock_roster( { M.p( "Jogobobek", C.Warrior ), M.p( "Obszczymucha", C.Druid ) } )
    local group_roster = require( "src/GroupRoster" ).new( group_roster_api, player_info )
    deps[ "GroupRoster" ] = group_roster

    local chat_api = deps[ "ChatApi" ] or require( "mocks/ChatApi" ).new()
    local chat = deps[ "Chat" ] or require( "src/Chat" ).new( chat_api, group_roster, player_info )
    deps[ "Chat" ] = chat

    local loot_facade = deps[ "LootFacade" ] or M.mock_loot_facade()
    deps[ "LootFacade" ] = loot_facade

    local raw_awarded_loot = require( "src/AwardedLoot" ).new( db( "awarded_loot" ), chat )

    local softres, awarded_loot = group_aware_softres(
      group_roster, raw_awarded_loot, deps[ "SoftResData" ], deps[ "ExtendChains" ] )
    deps[ "SoftRes" ] = softres

    local raw_loot_list = require( "mocks/LootList" ).new( loot_facade )
    deps[ "LootList" ] = raw_loot_list
    local loot_list = require( "src/SoftResLootListDecorator" ).new( raw_loot_list, softres )
    deps[ "SoftResLootList" ] = loot_list

    local ml_candidates_api = deps[ "MasterLootCandidatesApi" ] or require( "mocks/MasterLootCandidatesApi" ).new( group_roster, raw_loot_list )
    local ml_candidates = require( "src/MasterLootCandidates" ).new( ml_candidates_api, group_roster, raw_loot_list )
    deps[ "MasterLootCandidates" ] = ml_candidates

    local ace_timer = require( "mocks/AceTimer" ).new()
    deps[ "AceTimer" ] = ace_timer

    local winner_tracker = require( "src/WinnerTracker" ).new( db( "winner_tracker" ) )
    deps[ "WinnerTracker" ] = winner_tracker

    local frame_builder = require( "mocks/FrameBuilder" )
    local loot_frame_skin = require( "mocks/MockedLootFrameSkin" ).new( frame_builder )
    local loot_frame = require( "mocks/LootFrame" ).new( loot_frame_skin, db( "loot_frame" ), config )
    local popup_builder = require( "mocks/PopupBuilder" )
    local rolling_popup = require( "mocks/RollingPopup" ).new( popup_builder.new(), db( "dummy" ), config )

    local confirmation_popup = require( "mocks/LootAwardPopup" ).new( nil )
    deps[ "LootAwardPopup" ] = confirmation_popup

    local player_selection_frame = require( "mocks/MasterLootCandidateSelectionFrame" ).new( frame_builder, config )
    deps[ "PlayerSelectionFrame" ] = player_selection_frame

    local roll_controller = require( "src/RollController" ).new(
      ml_candidates,
      softres,
      loot_list,
      config,
      rolling_popup,
      confirmation_popup, ---@diagnostic disable-line: param-type-mismatch
      player_selection_frame
    )

    local loot_award_callback = require( "src/LootAwardCallback" ).new( awarded_loot, roll_controller, winner_tracker, group_roster )
    local master_loot = require( "src/MasterLoot" ).new( ml_candidates, loot_award_callback, loot_list, roll_controller, player_info )

    -- Where main.lua registers them, and for its reason: an award by hand goes through the same
    -- callback master loot and trading do, so everything downstream hears it.
    u.modules().slash_cmd( "award", raw_awarded_loot.make_command( "/award", function( player_name, item_data )
      loot_award_callback.on_loot_awarded( item_data.item_id, item_data.link, player_name )
    end ) )

    u.modules().slash_cmd( "unaward", raw_awarded_loot.make_command( "/unaward", function( player_name, item_data )
      awarded_loot.unaward( player_name, item_data, true )
      roll_controller.loot_unawarded( item_data.item_id, item_data.link, player_name )
    end ) )
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

    local loot_controller = require( "src/LootController" ).new(
      player_info,
      loot_facade,
      loot_list,
      loot_frame,
      roll_controller,
      softres,
      rolling_logic,
      chat
    )
    deps[ "LootController" ] = loot_controller

    local rolling_popup_content = require( "src/RollingPopupContentTransformer" ).new( config )
    deps[ "RollingPopupContent" ] = rolling_popup_content

    require( "src/RollResultAnnouncer" ).new( chat, roll_controller, config )
    local boss_killed = deps[ "BossKilled" ] or require( "src/BossKilled" ).new( db( "boss_killed" ) )
    deps[ "BossKilled" ] = boss_killed

    local dropped_loot = require( "src/DroppedLoot" ).new( db( "dummy" ), loot_list, player_info, boss_killed )
    local dropped_loot_announce = require( "src/DroppedLootAnnounce" ).new(
      loot_list,
      chat,
      softres,
      winner_tracker,
      player_info
    )

    local auto_group_loot = require( "mocks/AutoGroupLoot" ).new()
    local loot_facade_listener = require( "src/LootFacadeListener" ).new()

    -- The real one, not a stand-in: an addon registering an award policy has to have somewhere
    -- to register it, and core is what performs the award now.
    local award_policies = require( "src/AwardPolicies" ).new( db( "award_order" ) )
    award_policies.attach( loot_list, player_info, ml_candidates )

    require( "src/CoreLootHandlers" ).register( loot_facade_listener, {
      award_policies = award_policies,
      dropped_loot = dropped_loot,
      dropped_loot_announce = dropped_loot_announce,
      master_loot = master_loot,
      auto_group_loot = auto_group_loot,
      roll_controller = roll_controller
    } )

    loot_facade_listener.start( loot_facade )
    deps[ "LootFacadeListener" ] = loot_facade_listener

    require( "src/DebugBuffer" ).disable_all()
    deps.roll = rolling_logic.on_roll

    return {
      loot_frame = loot_frame,
      rolling_popup = rolling_popup,
      confirmation_popup = confirmation_popup,
      player_selection = player_selection_frame,
      loot_list = loot_list, ---@type LootList
      dropped_loot = dropped_loot, ---@type DroppedLoot
      ace_timer = ace_timer,
      roll = rolling_logic.on_roll,
      roll_controller = roll_controller,
      awarded_loot = awarded_loot, ---@type AwardedLoot
      softres = softres, ---@type GroupAwareSoftRes
      reset_announcements = dropped_loot_announce.reset,
      enable_debug = enable_debug
    }
  end

  return builder
end

return M
