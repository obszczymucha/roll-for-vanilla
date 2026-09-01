RollFor = RollFor or {}
local m = RollFor

---@diagnostic disable-next-line: undefined-global
local lib_stub = LibStub
local version = m.get_addon_version()

local M = {}

local getn = m.getn
local info = m.pretty_print
local hl = m.colors.highlight
local RollSlashCommand = m.Types.RollSlashCommand
local slash_cmd = m.slash_cmd
local alid = m.AwardedLoot.awarded_loot_item_data

local function clear_data()
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

local function trade_complete_callback( recipient_name, items_given, items_received )
  for i = 1, getn( items_given ) do
    local item = items_given[ i ]
    if item then
      local item_id = M.item_utils.get_item_id( item.link )
      local item_name = item_id and M.dropped_loot.get_dropped_item_name( item_id )

      if item_id and item_name then
        M.loot_award_callback.on_loot_awarded( item_id, item.link, recipient_name )
      end
    end
  end

  for i = 1, getn( items_received ) do
    local item = items_received[ i ]

    if item then
      local item_id = M.item_utils.get_item_id( item.link )

      local al_item = item_id and alid( item_id )
      if al_item and M.awarded_loot.has_item_been_awarded( recipient_name, al_item ) then
        M.unaward_item( recipient_name, item_id, item.link )
      end
    end
  end
end

-- TODO: Add type.
local function get_dummy_items()
  ---@diagnostic disable-next-line: unused-function
  local function item_link( name, id, quality )
    local color = (quality and m.api.ITEM_QUALITY_COLORS[ quality ] and m.api.ITEM_QUALITY_COLORS[ quality ].hex) or "|cffffffff"
    return string.format( "%s|Hitem:%s::::::::70::::::::::|h[%s]|h|r", color, id or "3299", name )
  end

  -- { item_id, quantity, name_override }
  local ids = {
    { 30237, 1 }, -- Chestguard of the Vanquished Defender
    { 29988, 1 }, -- The Nexus Key
    { 30236, 1 }, -- Chestguard of the Vanquished Champion
    { 30236, 1 }, -- Chestguard of the Vanquished Champion
    { 32405, 1 }, -- Verdant Sphere
    { 32458, 1 }, -- Ashes of Al'ar
    { 30183, 2 }, -- Nether Vortex
    { 29994, 1 }, -- Thalassian Wildercloak
  }
  local result = {}
  ---@type MakeDroppedItemFn
  local make_dropped_item = m.ItemUtils.make_dropped_item
  local boe = m.ItemUtils.BindType.BindOnEquip

  for _, entry in ipairs( ids ) do
    local item_id, quantity, name_override = entry[ 1 ], entry[ 2 ], entry[ 3 ]
    local name, tooltip_link, quality, texture

    local item_info = { m.api.GetItemInfo( item_id ) }
    name, tooltip_link, quality = item_info[ 1 ], item_info[ 2 ], item_info[ 3 ]
    texture = item_info[ 10 ]

    if name then
      name = name_override or name
      local link = item_link( name, item_id, quality )
      local item = make_dropped_item( item_id, name, link, tooltip_link, quality, quantity, texture, boe )
      table.insert( result, item )
    end
  end

  return result
end

-- "a", "a and b", "a, b and c". Nil for an empty list, which is what makes the summary
-- below able to say "nothing to lose" by returning it straight through.
---@param items string[]
---@return string?
local function join_and( items )
  local count = getn( items )
  if count < 2 then return items[ 1 ] end

  return string.format( "%s and %s", table.concat( items, ", ", 1, count - 1 ), items[ count ] )
end

-- What a lockout turning over would forget: "9 boss kills, 14 bonus rolls and 12
-- eligible players", or nil when there is nothing to lose.
--
-- Read by the subscriber that does the wiping, just before it wipes, and by the drop
-- simulator before it asks whether you meant it -- so the sentence you agree to and the
-- sentence you get afterwards can't drift apart.
---@return string?
local function describe_lockout_loss()
  local counted = {
    { count = getn( M.boss_killed.get_killed_bosses() ), noun = "boss kill" },
    { count = M.resistance_bonus_roll_registry.count_all(), noun = "bonus roll" },
    { count = M.resistance_bonus_roll_eligibility.count_eligible(), noun = "eligible player" }
  }

  local lost = {}

  for _, entry in ipairs( counted ) do
    -- Only the number is highlighted, not the whole clause -- "9 boss kills" reads
    -- better than a solid block of color with no number to actually pick out of it.
    if entry.count > 0 then
      table.insert( lost, string.format( "%s %s%s",
        hl( entry.count ), entry.noun, entry.count == 1 and "" or "s" ) )
    end
  end

  return join_and( lost )
end

-- Asks before rolling the lockout over, and only when there's something to lose -- being
-- made to confirm losing nothing is friction for its own sake, and an empty record is
-- what you're testing against most of the time.
--
-- Lives here rather than in the simulator so that one keeps its narrow pair of
-- dependencies instead of growing the registry, eligibility and a popup just to ask a
-- question about them.
---@param on_confirmed fun()
local function confirm_lockout_reset( on_confirmed )
  local lost = describe_lockout_loss()

  if not lost then
    on_confirmed()
    return
  end

  M.confirmation_dialog.show( {
    title = "Roll the raid lockout over?",
    lines = { string.format( "This will forget %s.", lost ) },
    question = "There's no getting them back. Continue?",
    on_yes = on_confirmed
  } )
end

-- Asks before throwing the queues away, and only when there's something to lose -- queues that
-- are already just the group in roster order are what a reset would rebuild, and being made to
-- confirm losing nothing is friction for its own sake. Same shape, and the same reason for living
-- here, as confirm_lockout_reset above: the Queues window's Reset button and /rf autorobin reset
-- are the same answer to the same question, so neither of them gets to own it.
--
-- Reset is deliberately all-or-nothing rather than per-category. The queues are edited apart but
-- built together, and "put it back the way it started" means all of them; a Reset that emptied
-- only the category you happened to be looking at is the one nobody means to click.
local function confirm_round_robin_reset()
  if M.auto_round_robin.is_pristine() then
    M.auto_round_robin.reset()
    return
  end

  M.confirmation_dialog.show( {
    title = "Reset the round robin queues?",
    lines = { "This will throw away every queue's order and anyone added by hand." },
    question = "All of them go back to your current group. Continue?",
    on_yes = M.auto_round_robin.reset
  } )
end

local function create_components()
  ---@type AceTimer
  M.ace_timer = lib_stub( "AceTimer-3.0" )

  local db = m.Db.new( M.char_db )

  ---@type EventBus
  M.config_event_bus = m.EventBus.new()

  ---@type Config
  M.config = m.Config.new( db( "config" ), M.config_event_bus )

  local classic = M.config.classic_look()
  local popup_bottom_margin, popup_bottom_button_margin = classic and 37 or 24, classic and 14 or 7
  local popup_side_margin = classic and 50 or 35
  local popup_builder_factory = classic and m.PopupBuilder.classic or m.PopupBuilder.modern

  ---@type fun(): PopupBuilder
  ---@param bottom_margin number?
  ---@param side_margin number?
  local function popup_builder( bottom_margin, side_margin )
    return popup_builder_factory( m.FrameBuilder, bottom_margin or popup_bottom_margin, popup_bottom_button_margin, side_margin or popup_side_margin )
  end

  local confirmation_margin = m.ConfirmationDialog.bottom_margin

  ---@type ConfirmationDialog
  M.confirmation_dialog = m.ConfirmationDialog.new(
    popup_builder( classic and confirmation_margin.classic or confirmation_margin.modern ), M.config )

  M.api = function() return m.api end

  ---@type PlayerInfo
  M.player_info = m.PlayerInfo.new( M.api() )

  ---@type GroupRoster
  M.group_roster = m.GroupRoster.new( M.api(), M.player_info )

  M.chat_api = m.ChatApi.new()

  ---@type Chat
  M.chat = m.Chat.new( M.chat_api, M.group_roster, M.player_info )

  ---@alias GroupAwareSoftResFn fun ( softres: SoftRes ): GroupAwareSoftRes
  ---@type GroupAwareSoftResFn
  M.present_softres = function( softres ) return m.SoftResPresentPlayersDecorator.new( M.group_roster, softres ) end
  ---@type GroupAwareSoftResFn
  M.absent_softres = function( softres ) return m.SoftResAbsentPlayersDecorator.new( M.group_roster, softres ) end

  ---@type ItemUtils
  M.item_utils = m.ItemUtils

  ---@type TooltipReader
  M.tooltip_reader = m.TooltipReader.new( M.api() )

  ---@type Inspector
  M.inspector = m.Inspector.new( M.api(), M.ace_timer, m.EventFrame.new( m.api ) )

  ---@type GearScanner
  M.gear_scanner = m.GearScanner.new( M.api(), M.tooltip_reader, M.inspector )

  ---@type BuffScanner
  M.buff_scanner = m.BuffScanner.new( M.api(), M.tooltip_reader )

  ---@type ResistanceRegistry
  M.resistance_registry = m.ResistanceRegistry.new()

  ---@type ResistanceParser
  M.resistance_parser = m.ResistanceParser.new( M.api(), M.resistance_registry )

  ---@type ResistanceCheck
  M.resistance_check = m.ResistanceCheck.new( db( "resistance_check" ), M.group_roster,
    M.gear_scanner, M.buff_scanner, M.resistance_parser, M.resistance_registry )

  ---@type ResistanceBonusRollEligibility
  M.resistance_bonus_roll_eligibility = m.ResistanceBonusRollEligibility.new(
    db( "resistance_bonus_roll_eligibility" ), M.group_roster, M.resistance_check, M.resistance_registry )

  ---@type BossKilled
  M.boss_killed = m.BossKilled.new( db( "boss_killed" ) )

  -- Subscribed here, before the registry, so this fires first: listeners run in
  -- subscription order, and "X was killed" reads better above "Bonus Roll granted"
  -- than below it.
  M.boss_killed.subscribe( function( boss_name )
    info( string.format( "%s was killed.", hl( boss_name ) ) )
  end )

  ---@type ResistanceBonusRollRegistry
  M.resistance_bonus_roll_registry = m.ResistanceBonusRollRegistry.new(
    db( "resistance_bonus_roll_registry" ), M.boss_killed, M.resistance_bonus_roll_eligibility )

  -- TODO: Add type.
  M.version_broadcast = m.VersionBroadcast.new( db( "version_broadcast" ), M.player_info, version.str )

  M.raw_awarded_loot = m.AwardedLoot.new( db( "awarded_loot" ), M.chat )

  ---@type AwardedLoot
  M.awarded_loot = m.NetherVortexAwardedLootDecorator.new( M.raw_awarded_loot )

  -- TODO: Add type.
  M.softres_db = db( "softres" )

  -- TODO: Add type.
  M.unfiltered_softres = m.SoftRes.new( M.softres_db )

  -- TODO: Add type.
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

  ---@type SoftRes
  M.nether_vortex_softres = m.SoftResNetherVortexDecorator.new( M.awarded_loot_softres )

  -- Outermost, so bonus rolls are only ever annotated onto players who are actually in
  -- the group -- the present-players decorator has already dropped everyone else.
  ---@type GroupAwareSoftRes
  M.softres = m.SoftResBonusRollDecorator.new(
    M.present_softres( M.nether_vortex_softres ), M.resistance_bonus_roll_registry, M.config )

  M.softres_check = m.SoftResCheck.new( M.nether_vortex_softres, M.group_roster, M.name_matcher, M.ace_timer,
    M.absent_softres, db( "softres_check" ) )

  ---@type WinnerTracker
  M.winner_tracker = m.WinnerTracker.new( db( "winner_tracker" ) )

  ---@type LootFacade
  M.loot_facade = m.LootFacade.new( m.EventFrame.new( m.api ), m.api )

  local rf_test = false
  local loot_facade = M.loot_facade

  if rf_test then
    M.rf_test_loot_facade = m.RfTestLootFacade.new( M.loot_facade )
    loot_facade = M.rf_test_loot_facade
  end

  ---@type LootList
  M.raw_loot_list = m.LootList.new( loot_facade, M.item_utils, M.tooltip_reader )

  ---@type SoftResLootList
  M.loot_list = m.SoftResLootListDecorator.new( M.raw_loot_list, M.softres )

  ---@type RaidLockout
  M.raid_lockout = m.RaidLockout.new( db( "raid_lockout" ), M.api(), m.EventFrame.new( m.api ) )

  ---@type DroppedLoot
  M.dropped_loot = m.DroppedLoot.new( db( "dropped_loot" ), M.loot_list, M.player_info, M.boss_killed )

  ---@type MasterLootCandidates
  M.master_loot_candidates = m.MasterLootCandidates.new( M.api(), M.group_roster, M.raw_loot_list ) -- remove group_roster for testing (dummy candidates)

  ---@type MasterLootCandidateSelectionFrame
  M.player_selection_frame = m.MasterLootCandidateSelectionFrame.new( m.FrameBuilder, M.config )

  local rolling_popup_db = db( "rolling_popup" )

  ---@type RollingPopupContentTransformer
  local rolling_popup_content_transformer = m.RollingPopupContentTransformer.new( M.config )

  ---@type RollingPopup
  M.rolling_popup = m.RollingPopup.new(
    popup_builder(),
    rolling_popup_content_transformer,
    rolling_popup_db,
    M.config
  )

  ---@type LootFrameSkin
  local skin = M.config.classic_look() and m.OgLootFrameSkin.new( m.FrameBuilder ) or m.ModernLootFrameSkin.new( m.FrameBuilder )

  ---@type LootFrame
  M.loot_frame = m.LootFrame.new(
    skin,
    db( "loot_frame" ),
    M.config
  )

  ---@type LootAwardPopup
  M.loot_award_popup = m.LootAwardPopup.new(
    popup_builder( classic and 38 or 30, classic and 65 or 55 ),
    M.config,
    M.rolling_popup
  )

  ---@type RollController
  M.roll_controller = m.RollController.new(
    M.master_loot_candidates,
    M.softres,
    M.loot_list,
    M.config,
    M.rolling_popup,
    M.loot_award_popup,
    M.player_selection_frame
  )

  ---@type LootAwardCallback
  M.loot_award_callback = m.LootAwardCallback.new( M.awarded_loot, M.roll_controller, M.winner_tracker, M.group_roster )

  ---@type MasterLoot
  M.master_loot = m.MasterLoot.new(
    M.master_loot_candidates,
    M.loot_award_callback,
    M.loot_list,
    M.roll_controller
  )

  M.autoloot_db = db( "autoloot_db" )

  ---@type AutoLoot
  M.auto_loot = m.AutoLoot.new( M.loot_list, M.api, M.autoloot_db, M.config, M.player_info, M.chat )

  -- Seeded here rather than at the bottom with the rest of the GUI: both the round-robin pass and
  -- its selection window read db.ids, and the pass runs on the first loot window whether or not
  -- the window has ever been opened.
  M.autorobin_db = db( "autorobin_db" )
  m.AutoRoundRobinDb.ensure_seeded( M.autorobin_db )

  ---@type AutoRoundRobin
  M.auto_round_robin = m.AutoRoundRobin.new(
    M.loot_list,
    M.api,
    M.autorobin_db,
    M.config,
    M.player_info,
    M.chat,
    M.group_roster,
    M.master_loot_candidates,
    M.auto_loot,
    M.loot_award_callback
  )

  ---@type DroppedLootAnnounce
  M.dropped_loot_announce = m.DroppedLootAnnounce.new(
    M.loot_list,
    M.chat,
    M.softres,
    M.winner_tracker,
    M.player_info,
    M.auto_loot,
    M.config
  )

  -- TODO: Add type.
  M.softres_gui = m.SoftResGui.new( M.api, M.import_encoded_softres_data, M.softres_check, M.softres, clear_data, M.dropped_loot_announce.reset,
    function() return M.roll_simulator and M.roll_simulator.is_simulating() end )

  -- TODO: Add type.
  M.trade_tracker = m.TradeTracker.new( M.ace_timer, M.chat, trade_complete_callback )

  -- TODO: Add type.
  M.usage_printer = m.UsagePrinter.new( M.chat )

  -- TODO: Add type.
  M.minimap_button = m.MinimapButton.new( M.api, db( "minimap_button" ), M.softres_gui.toggle, M.softres_check, M.config )

  -- TODO: Add type.
  M.master_loot_warning = m.MasterLootWarning.new( M.api, M.config, m.BossList.zones, M.player_info )

  -- TODO: Add type.
  M.new_group_event = m.NewGroupEvent.new( M.group_roster )

  -- TODO: Add type.
  M.auto_group_loot = m.AutoGroupLoot.new( M.loot_list, M.config, m.BossList.zones, M.player_info )

  -- TODO: Add type.
  M.auto_master_loot = m.AutoMasterLoot.new( M.config, m.BossList.zones, M.player_info )

  -- TODO: Add type.
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
    M.player_info,
    M.resistance_bonus_roll_registry
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

  M.loot_controller = m.LootController.new(
    M.player_info,
    loot_facade,
    M.loot_list,
    M.loot_frame,
    M.roll_controller,
    M.softres,
    M.rolling_logic,
    M.chat
  )

  ---@type ArgsParser
  M.args_parser = m.ArgsParser.new( m.ItemUtils, M.config )

  -- TODO: Add type.
  M.roll_result_announcer = m.RollResultAnnouncer.new( M.chat, M.roll_controller, M.config )

  M.loot_facade_listener = m.LootFacadeListener.new(
    M.loot_facade,
    M.auto_loot,
    M.auto_round_robin,
    M.dropped_loot,
    M.dropped_loot_announce,
    M.master_loot,
    M.auto_group_loot,
    M.roll_controller,
    M.player_info
  )

  M.roll_simulator = m.RollSimulator.new( M )

  M.drop_simulator = m.DropSimulator.new( M.boss_killed, M.raid_lockout, confirm_lockout_reset )

  M.round_robin_simulator = m.AutoRoundRobinSimulator.new( M.autorobin_db, M.group_roster )

  M.gargul_bridge = m.GargulBridge.new( M.player_info, M.roll_controller, M.config, function() return M.softres_db.data end, M.softres )

  M.roll_for_broadcast = m.RollForBroadcast.new( M.roll_controller, M.config )
  M.roll_for_receiver = m.RollForReceiver.new( M.rolling_popup, db( "receiver" ) )

  ---@type OptionsFrameContentTransformer
  local options_frame_content_transformer = m.OptionsFrameContentTransformer.new()

  ---@type OptionsFrame
  M.options = m.OptionsFrame.new( popup_builder(), options_frame_content_transformer, M.config, db( "options" ) )

  ---@type AutoLootFrameContentTransformer
  local autoloot_frame_content_transformer = m.AutoLootFrameContentTransformer.new()

  -- Before the frame, not after: the frame renders the roots it is handed, and init() replaces
  -- the table AutoLootTree.dungeons points at.
  m.AutoLootTree.init( M.autoloot_db )

  ---@type AutoLootFrame
  M.autoloot_frame = m.AutoLootFrame.new( {
    popup_builder = popup_builder(),
    content_transformer = autoloot_frame_content_transformer,
    db = db( "autoloot_frame" ),
    name = "RollForAutoLootFrame",
    title = "RollFor Auto Loot",
    roots = m.AutoLootTree.dungeons,
    make_link = m.AutoLootDb.make_link
  } )

  ---@type RoundRobinQueueFrameContentTransformer
  local autorobin_queue_frame_content_transformer = m.AutoRoundRobinQueueFrameContentTransformer.new()

  ---@type AutoRoundRobinAddPlayerFrame
  M.autorobin_add_player_frame = m.AutoRoundRobinAddPlayerFrame.new( popup_builder(),
    M.auto_round_robin, M.group_roster, function() end )

  ---@type AutoRoundRobinQueueFrame
  M.autorobin_queue_frame = m.AutoRoundRobinQueueFrame.new( popup_builder(),
    autorobin_queue_frame_content_transformer, M.auto_round_robin, M.autorobin_add_player_frame,
    M.config, db( "autorobin_queue_frame" ) )

  ---@type AutoRoundRobinFrame
  M.autorobin_frame = m.AutoRoundRobinFrame.new( popup_builder(), autoloot_frame_content_transformer,
    M.autorobin_db, db( "autorobin_frame" ), function() M.autorobin_queue_frame.toggle() end )

  ---@type ResistanceFrameContentTransformer
  local resistance_frame_content_transformer = m.ResistanceFrameContentTransformer.new( M.resistance_registry )

  ---@type ResistanceAnnouncer
  local resistance_announcer = m.ResistanceAnnouncer.new( M.chat, M.resistance_check,
    db( "resistance_announcer" ) )

  ---@type ResistanceFrame
  M.resistance_frame = m.ResistanceFrame.new( popup_builder(), resistance_frame_content_transformer,
    M.resistance_check, resistance_announcer, db( "resistance_frame" ) )

  ---@type BonusRollEligibilityFrameContentTransformer
  local resistance_bonus_roll_eligibility_frame_content_transformer =
      m.ResistanceBonusRollEligibilityFrameContentTransformer.new()

  ---@type ResistanceBonusRollEligibilityFrame
  M.resistance_bonus_roll_eligibility_frame = m.ResistanceBonusRollEligibilityFrame.new( popup_builder(),
    resistance_bonus_roll_eligibility_frame_content_transformer, M.resistance_bonus_roll_eligibility,
    M.resistance_check, db( "resistance_bonus_roll_eligibility_frame" ) )

  ---@type BonusRollFrameContentTransformer
  local resistance_bonus_roll_frame_content_transformer = m.ResistanceBonusRollFrameContentTransformer.new()

  ---@type ResistanceBonusRollFrame
  M.resistance_bonus_roll_frame = m.ResistanceBonusRollFrame.new( popup_builder(),
    resistance_bonus_roll_frame_content_transformer, M.resistance_bonus_roll_registry, M.group_roster,
    db( "resistance_bonus_roll_frame" ) )
end

local function subscribe_for_component_events()
  M.config.subscribe( "show_ml_warning", function( enabled )
    if enabled then
      M.master_loot_warning.on_player_target_changed()
    else
      M.master_loot_warning.hide()
    end
  end )

  M.new_group_event.subscribe( function()
    M.awarded_loot.clear()
    M.dropped_loot.clear()
  end )

  -- A new lockout is a new set of bosses to kill, so last week's record is not just
  -- stale, it's wrong -- the rolls those kills paid for expire with them, and so does
  -- who was eligible to earn them. Said out loud rather than wiped quietly, but only
  -- when there was something to lose.
  M.raid_lockout.subscribe( function( changed )
    -- Counted before the wipe, obviously, but also before it for a second reason: this
    -- is the same sentence the simulator showed when it asked.
    local lost = describe_lockout_loss()

    M.boss_killed.reset()
    M.resistance_bonus_roll_registry.reset()
    M.resistance_bonus_roll_eligibility.reset()

    if not lost then return end

    info( string.format( "New lockout (%s) - %s forgotten.",
      hl( table.concat( changed, ", " ) ), lost ) )
  end )

  M.config_event_bus.subscribe( "config_change_requires_ui_reload", function()
    M.confirmation_dialog.show( {
      title = "This change requires a UI reload.",
      question = "Reload the UI now?",
      on_yes = function() m.api.ReloadUI() end
    } )
  end )
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
  if data_loaded_callback then
    data_loaded_callback( softres_data )
    if M.gargul_bridge then M.gargul_bridge.broadcast_softres( data ) end
    M.auto_master_loot.on_softres_import()
  end

  update_minimap_icon()
end

local function on_roll_command( roll_slash_command )
  return function( args )
    if string.find( args, "^debug" ) then
      m.DebugBuffer.on_command( args )
      return
    end

    if M.rolling_logic.is_rolling() then
      M.chat.info( "Rolling is in progress." )
      return
    end

    if string.find( args, "^config" ) then
      M.config.on_command( args )
      return
    end

    if string.find( args, "^options" ) then
      M.options.toggle()
      return
    end

    if string.find( args, "^autoloot" ) then
      M.autoloot_frame.toggle()
      return
    end

    -- Both of these have to be matched before the bare ^autorobin below, which would otherwise
    -- swallow them. All three are window and state commands, so they sit above the IsInGroup
    -- guard further down.
    if string.find( args, "^autorobin queue" ) then
      M.autorobin_queue_frame.toggle()
      return
    end

    if string.find( args, "^autorobin reset" ) then
      confirm_round_robin_reset()
      return
    end

    if string.find( args, "^autorobin" ) then
      M.autorobin_frame.toggle()
      return
    end

    -- A bare /rf is a request for the options window, not an incomplete roll command. Restoring a
    -- dismissed rolling popup still wins, same as it did when this printed usage instead.
    if roll_slash_command == RollSlashCommand.NormalRoll and string.find( args, "^%s*$" ) then
      if M.roll_for_receiver.show() then return end

      M.options.toggle()
      return
    end

    -- if string.find( args, "^autolootdb print" ) then
    --   m.AutoLootDb.on_print_command()
    --   return
    -- end
    --
    -- if string.find( args, "^autolootdb" ) then
    --   m.AutoLootDb.on_command( M.autoloot_db, function()
    --     m.print( "AutoLootDb: all pending items resolved." )
    --   end )
    --   return
    -- end

    if args == "versioncheck guild" then
      M.version_broadcast.guild_version_request()
      return
    end

    if not M.api().IsInGroup() then
      M.chat.info( "Not in a group." )
      return
    end

    if args == "versioncheck" then
      M.version_broadcast.group_version_request()
      return
    end

    local item, count, seconds, message = M.args_parser.parse( args )

    if not item then
      if M.roll_for_receiver.show() then return end
      M.usage_printer.print_usage( roll_slash_command )
      return
    end

    local strategy_type = m.Types.slash_command_to_strategy_type( roll_slash_command )

    if not strategy_type then
      info( string.format( "Unsupported command: %s", hl( roll_slash_command and roll_slash_command.slash_command or "?" ) ) )
      return
    end

    if M.softres.is_item_hardressed( item.id ) then
      M.roll_controller.preview( item, count )
      return
    end

    M.roll_controller.start( strategy_type, item, count, 1, seconds, message )
  end
end

local function is_rolling_check( f )
  return m.is_rolling_check( M.rolling_logic, M.chat, f )
end

local function in_group_check( f )
  return m.in_group_check( M.api(), M.chat, f )
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
  local player = M.group_roster.find_player( player_name )

  if not player then
    m.err( string.format( "Player %s could not be found.", hl( player_name ) ) )
    return
  end

  M.rolling_logic.on_roll( player, roll, min, max )
end

local function on_loot_method_changed()
  M.master_loot_warning.on_party_loot_method_changed()
end

local function on_master_looter_changed( player_name )
  if M.player_info.get_name() == player_name and m.is_master_loot() then
    M.ace_timer.ScheduleTimer( M, M.config.print_raid_roll_settings, 0.1 )
  end
end

function M.on_chat_msg_system( message )
  for player_name, roll, min, max in string.gmatch( message, "([^%s]+) rolls (%d+) %((%d+)%-(%d+)%)" ) do
    on_roll( player_name, tonumber( roll ), tonumber( min ), tonumber( max ) )
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
end

local function reset_usage()
  info( string.format( "Usage: %s", hl( "/rfreset <command>" ) ) )
  info( string.format( "  %s - %s", hl( "announce" ), "reset the dropped loot announcement" ) )
end

local function on_reset_command( args )
  local command = string.match( args or "", "^%s*(%S*)" )

  if command == "announce" then
    M.dropped_loot_announce.reset( true )
    return
  end

  reset_usage()
end

local function on_rftest_command()
  if not M.player_info.is_master_looter() then
    info( "You must be the master looter to use this command." )
    return
  end

  M.rf_test_loot_facade.setup( get_dummy_items() )
  M.rf_test_loot_facade.notify( "LootOpened" )
end

local function setup_slash_commands()
  -- Roll For commands
  slash_cmd( RollSlashCommand.NormalRoll, on_roll_command( RollSlashCommand.NormalRoll ) )
  slash_cmd( RollSlashCommand.NoSoftResRoll, in_group_check( on_roll_command( RollSlashCommand.NoSoftResRoll ) ) )
  slash_cmd( RollSlashCommand.RaidRoll, in_group_check( on_roll_command( RollSlashCommand.RaidRoll ) ) )
  slash_cmd( RollSlashCommand.InstaRaidRoll, in_group_check( on_roll_command( RollSlashCommand.InstaRaidRoll ) ) )
  slash_cmd( "htr", in_group_check( show_how_to_roll ) )
  slash_cmd( "cr", is_rolling_check( M.roll_controller.cancel_rolling ) )
  slash_cmd( "fr", is_rolling_check( M.roll_controller.finish_rolling_early ) )
  slash_cmd( "rfreset", on_reset_command )
  slash_cmd( "sr", on_softres_command )

  if M.rf_test_loot_facade then
    slash_cmd( "rftest", on_rftest_command )
  end

  --slash_cmd( "dropped", simulate_loot_dropped )
end

function M.on_player_login()
  setup_storage()
  create_components()
  subscribe_for_component_events()
  setup_slash_commands()

  info( string.format( "Loaded (%s).", hl( string.format( "v%s", version.str ) ) ) )

  M.version_broadcast.broadcast()
  -- Answers as UPDATE_INSTANCE_INFO, which is where a lockout that turned over while
  -- we were logged out gets noticed.
  M.raid_lockout.refresh()
  M.import_encoded_softres_data( M.softres_db.data )
  M.softres_gui.load( M.softres_db.data )

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

function M.unaward_item( player_name, item_id, item_link )
  local al_item = alid( item_id )
  M.awarded_loot.unaward( player_name, al_item )
  info( string.format( "%s returned %s.", hl( player_name ), item_link ) )
end

function M.on_item_info_received( item_id )
  M.roll_controller.on_item_info_received( item_id )
  M.roll_for_receiver.on_item_info_received( item_id )
  m.AutoLootDb.on_item_info_received( item_id )
end

function M.on_group_changed()
  M.name_matcher.auto_match()
  M.auto_round_robin.on_group_changed()
  M.autorobin_queue_frame.on_group_changed()
  M.resistance_frame.on_group_changed()
  M.resistance_bonus_roll_eligibility_frame.on_group_changed()
  M.resistance_bonus_roll_frame.on_group_changed()
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
