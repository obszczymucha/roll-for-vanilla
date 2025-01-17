RollFor = RollFor or {}
local m = RollFor

---@diagnostic disable-next-line: undefined-global
local lib_stub = LibStub
local version = m.get_addon_version()

local M = {}

local info = m.pretty_print
local hl = m.colors.highlight
local RollSlashCommand = m.Types.RollSlashCommand
local RS = m.Types.RollingStrategy

---@diagnostic disable-next-line: deprecated
local getn = table.getn

local function clear_data()
  M.dropped_loot.clear()
  M.awarded_loot.clear()
  M.softres_gui.clear()
  M.name_matcher.clear( true )
  M.softres.clear( true )
  M.minimap_button.set_icon( M.minimap_button.ColorType.White )
  M.winner_tracker.clear()
end

local function update_minimap_icon()
  local result = M.softres_check.check_softres( true )

  if result == M.softres_check.ResultType.NoItemsFound then
    M.minimap_button.set_icon( M.minimap_button.ColorType.White )
  elseif result == M.softres_check.ResultType.SomeoneIsNotSoftRessing then
    M.minimap_button.set_icon( M.minimap_button.ColorType.Orange )
  elseif result == M.softres_check.ResultType.FoundOutdatedData then
    M.minimap_button.set_icon( M.minimap_button.ColorType.Red )
  else
    M.minimap_button.set_icon( M.minimap_button.ColorType.Green )
  end
end

local function on_softres_status_changed()
  update_minimap_icon()
end

local function trade_complete_callback( recipient, items_given, items_received )
  for i = 1, getn( items_given ) do
    local item = items_given[ i ]
    if item then
      local item_id = M.item_utils.get_item_id( item.link )
      local item_name = item_id and M.dropped_loot.get_dropped_item_name( item_id )

      if item_id and item_name then
        M.on_loot_awarded( recipient, item_id, item.link )
      end
    end
  end

  for i = 1, getn( items_received ) do
    local item = items_received[ i ]
    if item then
      local item_id = M.item_utils.get_item_id( item.link )

      if M.awarded_loot.has_item_been_awarded( recipient, item_id ) then
        M.unaward_item( recipient, item_id, item.link )
      end
    end
  end
end

---@param item DroppedItem
---@param strategy RollingStrategyType
local function select_player( item, strategy )
  local anchor = M.rolling_popup.get_frame()
  M.master_loot.show_loot_candidates_frame( item, strategy )
  local player_list = M.master_loot_frame.get_frame()

  player_list:ClearAllPoints()
  player_list:SetPoint( "TOP", anchor, "BOTTOM", 0, -5 )
end

---@param item Item
local function raid_roll_item( item, count )
  M.roll_controller.start( RS.RaidRoll, item, count )
end

---@param item Item
local function insta_raid_roll_item( item, count )
  M.roll_controller.start( RS.InstaRaidRoll, item, count )
end

local function roll_item( item, item_count )
  local count = item_count or M.loot_list.count( item.id )
  M.roll_controller.start( RS.SoftResRoll, item, count )
end

local function create_components()
  ---@type AceTimer
  M.ace_timer = lib_stub( "AceTimer-3.0" )

  local db = m.Db.new( M.char_db )

  ---@type Config
  M.config = m.Config.new( db( "config" ) )

  M.api = function() return m.api end

  ---@type PlayerInfo
  M.player_info = m.PlayerInfo.new( M.api() )

  ---@type Chat
  M.chat = m.Chat.new( M.api(), M.player_info )

  ---@alias GroupedSoftResFn fun ( softres: SoftRes ): GroupedSoftRes
  ---@type GroupedSoftResFn
  M.present_softres = function( softres ) return m.SoftResPresentPlayersDecorator.new( M.group_roster, softres ) end
  ---@type GroupedSoftResFn
  M.absent_softres = function( softres ) return m.SoftResAbsentPlayersDecorator.new( M.group_roster, softres ) end

  ---@type ItemUtils
  M.item_utils = m.ItemUtils

  M.version_broadcast = m.VersionBroadcast.new( db( "version_broadcast" ), M.player_info, version.str )
  M.awarded_loot = m.AwardedLoot.new( db( "awarded_loot" ) )
  M.group_roster = m.GroupRoster.new( M.api, M.player_info )
  M.softres_db = db( "softres" )
  M.unfiltered_softres = m.SoftRes.new( M.softres_db )
  M.name_matcher = m.NameManualMatcher.new(
    db( "name_matcher" ), M.api,
    M.absent_softres( M.unfiltered_softres ),
    m.NameAutoMatcher.new( M.group_roster, M.unfiltered_softres, 0.57, 0.4 ),
    on_softres_status_changed
  )

  ---@type SoftRes
  M.matched_name_softres = m.SoftResMatchedNameDecorator.new( M.name_matcher, M.unfiltered_softres )

  ---@type SoftRes
  M.awarded_loot_softres = m.SoftResAwardedLootDecorator.new( M.awarded_loot, M.matched_name_softres )

  ---@type GroupedSoftRes
  M.softres = M.present_softres( M.awarded_loot_softres )

  ---@type DroppedLoot
  M.dropped_loot = m.DroppedLoot.new( db( "dropped_loot" ) )
  M.softres_check = m.SoftResCheck.new( M.matched_name_softres, M.group_roster, M.name_matcher, M.ace_timer,
    M.absent_softres, db( "softres_check" ) )

  ---@type WinnerTracker
  M.winner_tracker = m.WinnerTracker.new( db( "winner_tracker" ) )

  ---@type LootFacade
  M.loot_facade = m.LootFacade.new( m.EventFrame.new( m.api ), m.api )

  ---@diagnostic disable-next-line: unused-local, unused-function
  local function get_dummy_items()
    ---@diagnostic disable-next-line: unused-function
    local function item_link( name, id, quality )
      local color = m.api.ITEM_QUALITY_COLORS[ quality ].hex or "|cffffffff"
      return string.format( "%s|Hitem:%s::::::::20:257::::::|h[%s]|h|r", color, id or "3299", name )
    end

    -- local ids = { 17204, 16961, 18842, 16961, 16961, 18842, 16865, 16961, 17109, 16961, 18466, 11980, 12820, 3676 }
    local ids = { 18842, 18842, 3676 }
    local result = {}
    ---@type MakeDroppedItemFn
    local make_dropped_item = m.ItemUtils.make_dropped_item

    ---@diagnostic disable-next-line: unused-local
    for i, item_id in ipairs( ids ) do
      local name, tooltip_link, quality, _, _, _, _, _, texture = m.api.GetItemInfo( item_id )
      local link = item_link( name, item_id, quality )
      local item = make_dropped_item( item_id, name, link, tooltip_link, quality, 1, texture )

      table.insert( result, item )
    end

    table.sort( result, function( a, b ) return a.quality > b.quality end )

    return result
  end

  M.raw_loot_list = m.LootList.new( M.loot_facade, M.item_utils ) --, get_dummy_items )

  ---@type SoftResLootList
  M.loot_list = m.SoftResLootListDecorator.new( M.raw_loot_list, M.softres )

  M.dropped_loot_announce = m.DroppedLootAnnounce.new( M.loot_list, M.chat, M.dropped_loot, M.softres, M.winner_tracker, M.player_info )

  ---@type RollTracker
  M.roll_tracker = m.RollTracker.new()

  ---@type RollController
  M.roll_controller = m.RollController.new( M.roll_tracker, M.player_info, M.rolling_strategy_factory, M.config, M.rolling_logic, M.winner_tracker )
  M.master_loot_frame = m.MasterLootCandidateSelectionFrame.new( M.winner_tracker, M.roll_controller, M.config )

  ---@type MasterLootCandidates
  M.master_loot_candidates = m.MasterLootCandidates.new( M.api(), M.group_roster ) -- remove group_roster for testing (dummy candidates)

  ---@type MasterLoot
  M.master_loot = m.MasterLoot.new(
    M.master_loot_candidates,
    M.on_loot_awarded,
    M.master_loot_frame,
    M.loot_list,
    M.player_info
  )

  M.softres_gui = m.SoftResGui.new( M.api, M.import_encoded_softres_data, M.softres_check, M.softres, clear_data, M.dropped_loot_announce.reset )

  M.trade_tracker = m.TradeTracker.new(
    M.ace_timer,
    trade_complete_callback
  )

  M.usage_printer = m.UsagePrinter.new( M.config )
  M.minimap_button = m.MinimapButton.new( M.api, db( "minimap_button" ), M.softres_gui.toggle, M.softres_check, M.config )
  M.master_loot_warning = m.MasterLootWarning.new( M.api, M.config, m.BossList.zones, M.player_info )
  M.auto_loot = m.AutoLoot.new( M.loot_list, M.api, db( "auto_loot" ), M.config )
  M.new_group_event = m.NewGroupEvent.new()
  M.auto_group_loot = m.AutoGroupLoot.new( M.loot_list, M.config, m.BossList.zones, M.player_info )
  M.auto_master_loot = m.AutoMasterLoot.new( M.config, m.BossList.zones )
  M.softres_roll_gui_data = m.SoftResRollGuiData.new( M.softres, M.group_roster )
  M.tie_roll_gui_data = m.TieRollGuiData.new( M.group_roster )

  local rolling_popup_db = db( "rolling_popup" )

  ---@type LootAutoProcess
  M.loot_auto_process = m.LootAutoProcess.new( M.config, M.roll_tracker, M.loot_list, M.roll_controller, M.player_info )
  M.rolling_popup = m.RollingPopup.new( m.PopupBuilder.new( m.FrameBuilder ), rolling_popup_db, M.config, M.roll_controller )
  M.rolling_popup_content = m.RollingPopupContent.new(
    M.rolling_popup,
    M.roll_controller,
    M.roll_tracker,
    M.loot_list,
    M.config,
    raid_roll_item,
    roll_item,
    insta_raid_roll_item,
    select_player
  )

  M.loot_award_popup = m.LootAwardPopup.new(
    m.PopupBuilder.new( m.FrameBuilder ),
    M.roll_controller,
    M.master_loot.on_confirm,
    m.RollingPopupContent,
    rolling_popup_db,
    m.RollingPopup.center_point,
    M.master_loot_candidates,
    M.roll_tracker
  )

  M.welcome_popup = m.WelcomePopup.new( m.FrameBuilder, M.ace_timer, db( "welcome_popup" ) )

  M.config.subscribe( "show_ml_warning", function( enabled )
    if enabled then
      M.master_loot_warning.on_player_target_changed()
    else
      M.master_loot_warning.hide()
    end
  end )

  M.loot_facade.subscribe( "LootOpened", function()
    M.auto_loot.on_loot_opened()
    M.dropped_loot_announce.on_loot_opened()
    M.master_loot.on_loot_opened()
    M.auto_group_loot.on_loot_opened()
    M.loot_frame.show()
    M.roll_controller.loot_opened()
    M.loot_auto_process.on_loot_opened()
  end )

  M.loot_facade.subscribe( "LootClosed", function()
    M.master_loot.on_loot_closed()
    M.roll_controller.loot_closed()
    M.loot_frame.hide()
    M.loot_auto_process.on_loot_closed()
  end )

  M.loot_facade.subscribe( "LootSlotCleared", function( slot )
    M.master_loot.on_loot_slot_cleared( slot )
    M.auto_group_loot.on_loot_slot_cleared()
    M.loot_frame.update()
  end )

  ---@type LootFrame
  M.loot_frame = m.LootFrame.new(
    m.FrameBuilder,
    M.loot_list,
    db( "loot_frame" ),
    M.roll_controller,
    M.roll_tracker,
    M.config,
    M.player_info
  )

  M.roll_for_ad = m.RollForAd.new( M.player_info )

  ---@type RollingStrategyFactory
  M.rolling_strategy_factory = m.RollingStrategyFactory.new(
    M.group_roster,
    M.loot_list,
    M.master_loot_candidates,
    M.chat,
    M.ace_timer,
    M.winner_tracker,
    M.config,
    M.softres,
    M.player_info
  )

  ---@type RollingLogic
  M.rolling_logic = m.RollingLogic.new(
    M.chat,
    M.ace_timer,
    M.roll_controller,
    M.rolling_strategy_factory,
    M.master_loot_candidates,
    M.winner_tracker,
    M.config
  )

  ---@type ArgsParser
  M.args_parser = m.ArgsParser.new( m.ItemUtils, M.config )
  M.roll_result_announcer = m.RollResultAnnouncer.new( M.chat, M.roll_controller, M.roll_tracker, M.config )
end

function M.import_softres_data( softres_data )
  M.unfiltered_softres.import( softres_data )
  M.name_matcher.auto_match()
end

function M.import_encoded_softres_data( data, data_loaded_callback )
  local sr = m.SoftRes
  local softres_data = sr.decode( data )

  if not softres_data and data and string.len( data ) > 0 then
    info( "Could not load soft-res data!", m.colors.red )
    return
  elseif not softres_data then
    M.minimap_button.set_icon( M.minimap_button.ColorType.White )
    return
  end

  M.import_softres_data( softres_data )

  info( "Soft-res data loaded successfully!" )
  if data_loaded_callback then data_loaded_callback( softres_data ) end

  update_minimap_icon()
end

local function announce_hr( item )
  M.chat.announce( string.format( "%s is hard-ressed.", item ), true )
end

local function on_roll_command( roll_slash_command )
  return function( args )
    if M.rolling_logic.is_rolling() then
      -- TODO: Maybe bring it back.
      -- if not args or args == "" then
      --   M.roll_controller.show()
      --   return
      -- end

      info( "Rolling is in progress." )
      return
    end

    for command, modules in string.gmatch( args, "debug (.-) (.*)" ) do
      for module_name in string.gmatch( modules, "%S+" ) do
        local mod = m[ module_name ]
        if mod and mod.debug then
          local dbg = mod.debug
          local f = dbg[ command ]

          if f then f() end
        end
      end

      return
    end

    if string.find( args, "^config" ) then
      M.config.on_command( args )
      return
    end

    if args == "versioncheck guild" then
      M.version_broadcast.guild_version_request()
      return
    end

    if not M.api().IsInGroup() then
      info( "Not in a group." )
      return
    end

    if args == "versioncheck" then
      M.version_broadcast.group_version_request()
      return
    end

    local item, count, seconds, message = M.args_parser.parse( args )

    if not item then
      M.usage_printer.print_usage( roll_slash_command )
      return
    end

    -- TODO: What if we wanted to bypass the hard-res?
    -- Also, get rid of this here. Make a strategy for this shit or something.
    if M.softres.is_item_hardressed( item.id ) then
      announce_hr( item.link )
      return
    end

    local strategy_type = m.Types.slash_command_to_strategy_type( roll_slash_command )

    if not strategy_type then
      info( string.format( "Unsupported command: %s", hl( roll_slash_command and roll_slash_command.slash_command or "?" ) ) )
      return
    end

    M.roll_controller.start( strategy_type, item, count, message, seconds )
  end
end

local function on_show_sorted_rolls_command( args )
  if M.rolling_logic.is_rolling() then
    info( "Rolling is in progress." )
    return
  end

  if args then
    for limit in string.gmatch( args, "(%d+)" ) do
      M.rolling_logic.show_sorted_rolls( tonumber( limit ) )
      return
    end
  end

  M.rolling_logic.show_sorted_rolls( 5 )
end

local function is_rolling_check( f )
  ---@diagnostic disable-next-line: unused-vararg
  return function( ... )
    if not M.rolling_logic.is_rolling() then
      info( "Rolling not in progress." )
      return
    end

    f( unpack( arg ) )
  end
end

local function in_group_check( f )
  ---@diagnostic disable-next-line: unused-vararg
  return function( ... )
    if not M.api().IsInGroup() then
      info( "Not in a group." )
      return
    end

    f( unpack( arg ) )
  end
end

local function setup_storage()
  -- Reset old AceDB configuration. I don't give a fuck :)
  if RollForDb and RollForDb.global and RollForDb.global.version then
    RollForDb = nil
  end

  RollForDb = RollForDb or {}
  RollForCharDb = RollForCharDb or {}

  M.db = RollForDb
  M.char_db = RollForCharDb

  if not M.db.version then
    M.db.version = version.str
  end
end

local function on_softres_command( args )
  if args == "init" then
    clear_data()
  end

  M.softres_gui.toggle()
end

local function on_roll( player_name, roll, min, max )
  M.rolling_logic.on_roll( player_name, roll, min, max )
end

local function on_loot_method_changed()
  M.master_loot_warning.on_party_loot_method_changed()
end

local function on_master_looter_changed( player_name )
  if M.player_info.get_name() == player_name and m.is_master_loot() then
    M.ace_timer.ScheduleTimer( M, M.config.print_raid_roll_settings, 0.1 )
  end
end

-- This covers the scenario where the master looter assigns the loot and then moves immediately,
-- causing the loot frame to close. In normal circumstances, when the last item gets assigned,
-- the LOOT_SLOT_CLEARED fires and then LOOT_CLOSED event follows. In this case, however,
-- LOOT_CLOSED fires first, because of the player movement and the LOOT_SLOT_CLEARED doesn't
-- (because we're not looting anymore).
function M.on_chat_msg_loot( message )
  for player_name, link_with_optional_quantity in string.gmatch( message, "(.-) receives loot: (.*)" ) do
    local item_link = M.item_utils.parse_link( link_with_optional_quantity )
    local item_id = item_link and M.item_utils.get_item_id( item_link )

    if item_id and item_link then
      M.master_loot.on_loot_received( player_name, item_id, item_link )
    end

    return
  end

  for link_with_optional_quantity in string.gmatch( message, "You receive loot: (.*)" ) do
    local item_link = M.item_utils.parse_link( link_with_optional_quantity )
    local item_id = item_link and M.item_utils.get_item_id( item_link )

    if item_id and item_link then
      M.master_loot.on_loot_received( M.player_info.get_name(), item_id, item_link )
    end

    return
  end
end

function M.on_chat_msg_system( message )
  for player, roll, min, max in string.gmatch( message, "([^%s]+) rolls (%d+) %((%d+)%-(%d+)%)" ) do
    on_roll( player, tonumber( roll ), tonumber( min ), tonumber( max ) )
    return
  end

  if string.find( message, "^Looting changed to" ) then
    on_loot_method_changed()
    return
  end

  for player_name in string.gmatch( message, "(.-) is now the loot master%." ) do
    on_master_looter_changed( player_name )
    return
  end
end

-- TODO: this can now be replaced by mocking LootList
---@diagnostic disable-next-line: unused-local, unused-function
local function simulate_loot_dropped( args )
  ---@diagnostic disable-next-line: unused-function
  local function mock_table_function( name, values )
    M.api()[ name ] = function( key )
      local value = values[ key ]

      if type( value ) == "function" then
        return value()
      else
        return value
      end
    end
  end

  ---@diagnostic disable-next-line: unused-function
  local function make_loot_slot_info( count, quality )
    local result = {}

    for i = 1, count do
      table.insert( result, function()
        if i == count then
          m.api = m.real_api
          m.real_api = nil
        end

        return nil, nil, nil, quality or 4
      end )
    end

    return result
  end

  local item_links = M.item_utils.parse_all_links( args )

  if m.real_api then
    info( "Mocking in progress." )
    return
  end

  m.real_api = m.api
  m.api = m.clone( m.api )
  M.api()[ "GetNumLootItems" ] = function() return getn( item_links ) end
  M.api()[ "UnitName" ] = function() return tostring( m.lua.time() ) end
  M.api()[ "GetLootThreshold" ] = function() return 4 end
  mock_table_function( "GetLootSlotLink", item_links )
  mock_table_function( "GetLootSlotInfo", make_loot_slot_info( getn( item_links ), 4 ) )

  M.dropped_loot_announce.on_loot_opened()
end

local function show_how_to_roll()
  M.chat.announce( "How to roll:" )
  local ms = M.config.ms_roll_threshold() ~= 100 and string.format( " (%s)", M.config.ms_roll_threshold() or "100" ) or ""

  local sr = M.softres.get_all_rollers()
  local sr_count = getn( sr )

  M.chat.announce( string.format( "For main-spec%s, type: /roll%s", sr_count > 0 and " and soft-res" or "", ms ) )
  M.chat.announce( string.format( "For off-spec, type: /roll %s", M.config.os_roll_threshold() ) )

  if M.config.tmog_rolling_enabled() then
    M.chat.announce( string.format( "For transmog, type: /roll %s", M.config.tmog_roll_threshold() ) )
  end
end

local function on_reset_dropped_loot_announce_command()
  M.dropped_loot_announce.reset()
end

local function test()
  -- local f = M.raw_loot_list.get_items
  local g = m.api.UnitName
  m.api.UnitName = function( t ) return t == "target" and "Princess Kenny" or g( t ) end

  M.loot_frame.show()
  -- M.raw_loot_list.get_items = f
  m.api.UnitName = g
end

local function setup_slash_commands()
  -- Roll For commands
  SLASH_RF1 = RollSlashCommand.NormalRoll
  M.api().SlashCmdList[ "RF" ] = on_roll_command( RollSlashCommand.NormalRoll )
  SLASH_ARF1 = RollSlashCommand.NoSoftResRoll
  M.api().SlashCmdList[ "ARF" ] = in_group_check( on_roll_command( RollSlashCommand.NoSoftResRoll ) )
  SLASH_RR1 = RollSlashCommand.RaidRoll
  M.api().SlashCmdList[ "RR" ] = in_group_check( on_roll_command( RollSlashCommand.RaidRoll ) )
  SLASH_IRR1 = RollSlashCommand.InstaRaidRoll
  M.api().SlashCmdList[ "IRR" ] = in_group_check( on_roll_command( RollSlashCommand.InstaRaidRoll ) )
  SLASH_HTR1 = "/htr"
  M.api().SlashCmdList[ "HTR" ] = in_group_check( show_how_to_roll )
  SLASH_CR1 = "/cr"
  M.api().SlashCmdList[ "CR" ] = is_rolling_check( M.roll_controller.cancel_rolling )
  SLASH_FR1 = "/fr"
  M.api().SlashCmdList[ "FR" ] = is_rolling_check( M.roll_controller.finish_rolling_early )
  SLASH_SSR1 = "/ssr"
  M.api().SlashCmdList[ "SSR" ] = on_show_sorted_rolls_command
  SLASH_RFR1 = "/rfr"
  M.api().SlashCmdList[ "RFR" ] = on_reset_dropped_loot_announce_command

  -- Soft Res commands
  SLASH_SR1 = "/sr"
  M.api().SlashCmdList[ "SR" ] = on_softres_command
  SLASH_SRS1 = "/srs"
  M.api().SlashCmdList[ "SRS" ] = M.softres_check.show_softres
  SLASH_SRC1 = "/src"
  M.api().SlashCmdList[ "SRC" ] = M.softres_check.check_softres
  SLASH_SRO1 = "/sro"
  M.api().SlashCmdList[ "SRO" ] = M.name_matcher.manual_match

  SLASH_RFT1 = "/rft"
  M.api().SlashCmdList[ "RFT" ] = test

  --SLASH_DROPPED1 = "/DROPPED"
  --M.api().SlashCmdList[ "DROPPED" ] = simulate_loot_dropped
end

function M.on_first_enter_world()
  setup_storage()
  create_components()
  setup_slash_commands()

  info( string.format( "Loaded (%s).", hl( string.format( "v%s", version.str ) ) ) )

  M.version_broadcast.broadcast()
  M.import_encoded_softres_data( M.softres_db.data )
  M.softres_gui.load( M.softres_db.data )

  if M.welcome_popup.should_show() then
    M.welcome_popup.show()
  end

  ---@diagnostic disable-next-line: undefined-global
  LootFrame:UnregisterAllEvents()
  ---@diagnostic disable-next-line: undefined-global
  if pfLootFrame then pfLootFrame:UnregisterAllEvents() end
end

---@diagnostic disable-next-line: unused-local, unused-function
local function on_party_message( message, player )
  for name, roll in string.gmatch( message, "(%a+) rolls (%d+)" ) do
    on_roll( name, tonumber( roll ), 1, 100 )
  end
  for name, roll in string.gmatch( message, "(%a+) rolls os (%d+)" ) do
    on_roll( name, tonumber( roll ), 1, 99 )
  end
end

---@param player_name string
---@param item_id number
---@param item_link string
function M.on_loot_awarded( player_name, item_id, item_link )
  M.awarded_loot.award( player_name, item_id )
  M.roll_controller.loot_awarded( player_name, item_id, item_link )
  info( string.format( "%s received %s.", hl( player_name ), item_link ) ) -- TODO: Remove from here and subscribe to an event.
  M.winner_tracker.untrack( player_name, item_link )
end

function M.unaward_item( player_name, item_id, item_link )
  M.awarded_loot.unaward( player_name, item_id )
  info( string.format( "%s returned %s.", hl( player_name ), item_link ) )
end

function M.on_group_changed()
  M.name_matcher.auto_match()
  update_minimap_icon()
end

function M.on_chat_msg_addon( name, message )
  if name ~= "RollFor" or not message then return end

  for ver in string.gmatch( message, "VERSION::(.*)" ) do
    M.version_broadcast.on_version( ver )
    return
  end

  for channel, requesting_player_name in string.gmatch( message, "VERSION_REQUEST::(.-)::(.*)" ) do
    M.version_broadcast.on_version_request( channel, requesting_player_name )
    return
  end

  for requesting_player_name, channel, their_name, their_class, their_version in string.gmatch( message, "VERSION_RESPONSE::(.-)::(.-)::(.-)::(.-)::(.*)" ) do
    M.version_broadcast.on_version_response( requesting_player_name, channel, their_name, their_class, their_version )
    return
  end
end

m.EventHandler.handle_events( M )
return M
