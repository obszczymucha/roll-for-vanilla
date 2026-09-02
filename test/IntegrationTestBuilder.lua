local u = require( "test/utils" )
local reqsrc = u.multi_require_src
local lu, eq = u.luaunit( "assertEquals" ) ---@diagnostic disable-line: unused-local
local m, T, IU = require( "src/modules" ), require( "src/Types" ), require( "src/ItemUtils" )
reqsrc( "DebugBuffer", "Module", "Types", "SoftResDataTransformer", "RollingLogicUtils", "RollTracker" )
reqsrc( "TieRollingLogic", "SoftResRollingLogic", "NonSoftResRollingLogic", "RaidRollRollingLogic", "InstaRaidRollRollingLogic" )
require( "src/AwardedLoot" )
local SoftResAwardedLootDecorator = require( "src/SoftResAwardedLootDecorator" )
local SoftResNetherVortexDecorator = require( "src/SoftResNetherVortexDecorator" )
local NetherVortexAwardedLootDecorator = require( "src/NetherVortexAwardedLootDecorator" )
local SoftResDecorator = require( "src/SoftResPresentPlayersDecorator" )
local SoftResBonusRollDecorator = require( "src/SoftResBonusRollDecorator" )
require( "src/ItemCatalogue" ) -- the catalogue helpers AutoLootDb delegates its seeding and queries to
require( "src/AutoLootDb" )
local ResistanceBonusRollRegistry = require( "src/resistances/ResistanceBonusRollRegistry" )
local SoftRes, Db = require( "src/SoftRes" ), require( "src/Db" )
local RollingLogic = require( "src/RollingLogic" )
local sr, hr, make_data = u.soft_res_item, u.hard_res_item, u.create_softres_data ---@diagnostic disable-line: unused-local
local c, r, pm = u.console_message, u.raid_message, u.party_message ---@diagnostic disable-line: unused-local
local cr, rw = u.console_and_raid_message, u.raid_warning ---@diagnostic disable-line: unused-local
local C, RT, RS = T.PlayerClass, T.RollType, T.RollingStrategy ---@diagnostic disable-line: unused-local
local make_player = T.make_player
local BindType = IU.BindType

u.mock_wow_api()

local M = {}

-- The bonus roll registry's two collaborators, inert. Specs seed grants directly through
-- builder.bonus_rolls rather than playing out a kill, so the registry only needs to be able
-- to subscribe to the kill feed and read eligibility's rows -- neither of which fires here.
---@return BossKilled
local function inert_boss_killed()
  ---@diagnostic disable-next-line: missing-fields
  return { subscribe = function() end }
end

---@return ResistanceBonusRollEligibility
local function inert_eligibility()
  ---@diagnostic disable-next-line: missing-fields
  return { get_rows = function() return {} end }
end

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
    auto_loot = function() return config and config.auto_loot end,
    auto_loot_announce = function()
      if config and config.auto_loot_announce ~= nil then return config.auto_loot_announce end
      return true
    end,
    superwow_auto_loot_coins = function()
      if config and config.superwow_auto_loot_coins ~= nil then return config.superwow_auto_loot_coins end
      return true
    end,
    auto_loot_messages = function() return config and config.auto_loot_messages end,
    auto_raid_roll = function() return config and config.auto_raid_roll end,
    auto_round_robin = function() return config and config.auto_round_robin end,
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
    classic_look = function() return false end,
    resistance_bonus_rolls_enabled = function()
      if config and config.resistance_bonus_rolls_enabled ~= nil then return config.resistance_bonus_rolls_enabled end
      return true
    end
  }
end

-- The same chain main.lua builds, bonus-roll decorator outermost.
---@param group_roster GroupRoster
---@param awarded_loot AwardedLoot
---@param bonus_roll_registry ResistanceBonusRollRegistry
---@param config Config
---@param data table?
---@return GroupAwareSoftRes
---@return AwardedLoot
local function group_aware_softres( group_roster, awarded_loot, bonus_roll_registry, config, data )
  local raw_softres = SoftRes.new()
  local vortex_awarded_loot = NetherVortexAwardedLootDecorator.new( awarded_loot )
  local awarded_loot_softres = SoftResAwardedLootDecorator.new( vortex_awarded_loot, raw_softres )
  local nether_vortex_softres = SoftResNetherVortexDecorator.new( awarded_loot_softres )
  local present_softres = SoftResDecorator.new( group_roster, nether_vortex_softres )
  local result = SoftResBonusRollDecorator.new( present_softres, bonus_roll_registry, config )

  if data then
    result.import( data )
  end

  return result, vortex_awarded_loot
end

function M.mock_loot_facade()
  return require( "mocks/LootFacade" ).new()
end

-- Test seam for a selection GUI's predefined list -- auto-loot's or auto round robin's, they are
-- the same db shape. Test items aren't in either real catalogue, so instead of ticking rows in the
-- tree this writes the exact db shape ticking them would produce (see ItemCatalogue.ensure_seeded
-- and AutoLootTree.set_checked): the item enabled under an enabled boss under an enabled dungeon.
-- AutoLootTree's own write-through is covered in AutoLootTree_test; what these specs care about is
-- the feature honouring the resulting selection.
---@param db table the autoloot_db / autorobin_db the module under test was built with
function M.auto_loot_list( db )
  local DUNGEON, BOSS = "Test Dungeon", "Test Boss"

  local function boss_entry()
    db.ids = db.ids or {}
    db.ids[ DUNGEON ] = db.ids[ DUNGEON ] or { enabled = true, order = 1, bosses = {} }
    db.ids[ DUNGEON ].bosses[ BOSS ] = db.ids[ DUNGEON ].bosses[ BOSS ] or { enabled = true, order = 1, items = {} }

    return db.ids[ DUNGEON ].bosses[ BOSS ]
  end

  ---@param item DroppedItem
  local function enable( item )
    boss_entry().items[ item.id ] = { enabled = true, name = item.name, quality = item.quality, icon = 0 }
  end

  ---@param item DroppedItem
  local function disable( item )
    local entry = boss_entry().items[ item.id ]
    if entry then entry.enabled = false end
  end

  ---@param enabled boolean
  local function set_dungeon_enabled( enabled )
    boss_entry()
    db.ids[ DUNGEON ].enabled = enabled
  end

  ---@param enabled boolean
  local function set_boss_enabled( enabled )
    boss_entry().enabled = enabled
  end

  return {
    enable = enable,
    disable = disable,
    set_dungeon_enabled = set_dungeon_enabled,
    set_boss_enabled = set_boss_enabled
  }
end

-- The same seam for the round-robin GUI's list, which is a flat Category -> items tree rather
-- than auto-loot's nested one (see AutoRoundRobinDb). Test items aren't in the real catalogue, so
-- this writes what ticking a row would produce: the item enabled under an enabled category.
-- Everything goes under one category, because which queue serves an item is what the category
-- names, and a spec that wants two queues says so by naming them.
---@param db table the autorobin_db the AutoRoundRobin under test was built with
function M.round_robin_list( db )
  local DEFAULT = "Gems"

  ---@param category string?
  local function category_entry( category )
    local name = category or DEFAULT
    db.ids = db.ids or {}
    db.ids[ name ] = db.ids[ name ] or { enabled = true, order = 1, items = {} }
    db.ids[ name ].enabled = true

    return db.ids[ name ]
  end

  ---@param item DroppedItem
  ---@param category string?
  local function enable( item, category )
    category_entry( category ).items[ item.id ] = {
      enabled = true, name = item.name, quality = item.quality, icon = 0
    }
  end

  ---@param item DroppedItem
  ---@param category string?
  local function disable( item, category )
    local entry = category_entry( category ).items[ item.id ]
    if entry then entry.enabled = false end
  end

  ---@param enabled boolean
  ---@param category string?
  local function set_category_enabled( enabled, category )
    category_entry( category ).enabled = enabled
  end

  -- The fallback category's rows are qualities, not items, so ticking one is a different write --
  -- the same one AutoLootTree.set_checked would make on a quality leaf. The category is seeded by
  -- AutoRoundRobinDb.ensure_seeded and starts off, so this switches on both it and the row.
  ---@param quality number
  local function enable_trash( quality )
    local trash = db.ids[ RollFor.AutoRoundRobinDb.TRASH ]
    trash.enabled = true
    trash.qualities[ quality ].enabled = true
  end

  return {
    enable = enable,
    disable = disable,
    set_category_enabled = set_category_enabled,
    enable_trash = enable_trash
  }
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
    dependencies[ "SoftResData" ] = make_data( ... )
    return self
  end

  -- Bonus rolls seeded straight into the registry -- { Drutree = { "Mother Shahraz" } } --
  -- rather than played out through eligibility and a kill, which is a different module's
  -- test.
  ---@param grants table<string, string[]>
  function builder.bonus_rolls( self, grants )
    dependencies[ "BonusRollGrants" ] = grants
    return self
  end

  -- Remembered rather than applied here: build() sets the threshold too, and used to do it
  -- afterwards, which made every call to this a silent no-op.
  ---@param threshold number
  function builder.loot_threshold( self, threshold )
    dependencies[ "LootThreshold" ] = threshold
    return self
  end

  function builder.build()
    u.mock_slashcmdlist() -- Drop the previous build's commands so this one can register its own.
    u.zone_name()
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

    local bonus_roll_registry = ResistanceBonusRollRegistry.new(
      db( "resistance_bonus_roll_registry" ), inert_boss_killed(), inert_eligibility() )
    deps[ "ResistanceBonusRollRegistry" ] = bonus_roll_registry

    for player_name, bosses in pairs( deps[ "BonusRollGrants" ] or {} ) do
      for _, boss_name in ipairs( bosses ) do
        bonus_roll_registry.grant( player_name, boss_name, C.Warrior )
      end
    end

    local softres, awarded_loot = group_aware_softres(
      group_roster, raw_awarded_loot, bonus_roll_registry, config, deps[ "SoftResData" ] )
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
    local master_loot = require( "src/MasterLoot" ).new( ml_candidates, loot_award_callback, loot_list, roll_controller )
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
      player_info,
      bonus_roll_registry
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

    local autoloot_db = db( "autoloot_db" )
    local auto_loot = require( "mocks/AutoLoot" ).new( loot_list, u.modules().api, autoloot_db, config, player_info, chat )
    deps[ "AutoLoot" ] = auto_loot

    -- The real thing, not a mock: the award pass is most of what these specs are about, and
    -- there is nothing random left in it to pin down -- the queue order decides the winner.
    require( "src/AutoRoundRobinDb" ) -- the round-robin catalogue the pass reads its selection from
    local autorobin_db = db( "autorobin_db" )
    require( "src/AutoRoundRobinDb" ).ensure_seeded( autorobin_db )

    local auto_round_robin = require( "src/AutoRoundRobin" ).new(
      loot_list,
      function() return u.modules().api end,
      autorobin_db,
      config,
      player_info,
      chat,
      group_roster,
      ml_candidates,
      auto_loot,
      loot_award_callback
    )
    deps[ "AutoRoundRobin" ] = auto_round_robin

    require( "src/RollResultAnnouncer" ).new( chat, roll_controller, config )
    local boss_killed = deps[ "BossKilled" ] or require( "src/BossKilled" ).new( db( "boss_killed" ) )
    deps[ "BossKilled" ] = boss_killed

    local dropped_loot = require( "src/DroppedLoot" ).new( db( "dummy" ), loot_list, player_info, boss_killed )
    local dropped_loot_announce = require( "src/DroppedLootAnnounce" ).new(
      loot_list,
      chat,
      softres,
      winner_tracker,
      player_info,
      auto_loot,
      config
    )

    local auto_group_loot = require( "mocks/AutoGroupLoot" ).new()
    local loot_facade_listener = require( "src/LootFacadeListener" ).new(
      loot_facade,
      auto_loot,
      auto_round_robin,
      dropped_loot,
      dropped_loot_announce,
      master_loot,
      auto_group_loot,
      roll_controller,
      player_info
    )
    deps[ "LootFacadeListener" ] = loot_facade_listener

    require( "src/DebugBuffer" ).disable_all()
    deps.roll = rolling_logic.on_roll

    return {
      loot_frame = loot_frame,
      rolling_popup = rolling_popup,
      confirmation_popup = confirmation_popup,
      player_selection = player_selection_frame,
      loot_list = loot_list, ---@type LootList
      auto_loot = auto_loot, ---@type AutoLoot
      auto_loot_list = M.auto_loot_list( autoloot_db ),
      autoloot_db = autoloot_db,
      auto_round_robin = auto_round_robin, ---@type AutoRoundRobin
      round_robin_list = M.round_robin_list( autorobin_db ),
      autorobin_db = autorobin_db,
      dropped_loot = dropped_loot, ---@type DroppedLoot
      ace_timer = ace_timer,
      roll = rolling_logic.on_roll,
      roll_controller = roll_controller,
      awarded_loot = awarded_loot, ---@type AwardedLoot
      bonus_roll_registry = bonus_roll_registry, ---@type ResistanceBonusRollRegistry
      softres = softres, ---@type GroupAwareSoftRes
      reset_announcements = dropped_loot_announce.reset,
      enable_debug = enable_debug
    }
  end

  return builder
end

return M
