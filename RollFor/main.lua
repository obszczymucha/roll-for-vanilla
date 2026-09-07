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

-- Assigned by create_components(); declared here so describe_lockout_loss(), which runs
-- above it, can see them.
---@type table<string, function[]>
local extension_hooks = { group_changed = {}, lockout_reset = {}, lockout_loss = {} }
---@type fun( extension_name: string ): ExtensionContext
local make_extension_context

local ColorSeverity = { White = 0, Green = 1, Orange = 2, Red = 3 }

-- Recomputed from the contribution list rather than cached: contributions are read at
-- render time because extensions register during on_ready, which runs after the button
-- is built, so a button that snapshotted the list at construction would show nothing.
local function refresh_minimap()
  -- Handed to extensions as ctx.minimap.refresh, and their on_enable runs well before
  -- create_components() gets as far as building the button. Nothing to repaint yet is a
  -- non-event, not a crash -- the colour is recomputed from scratch at every refresh, so
  -- the one skipped here costs nothing.
  if not M.minimap_button then return end

  local color = m.MinimapButton.ColorType.White
  local best = ColorSeverity[ color ]

  for _, contribution in ipairs( M.minimap_contributions ) do
    local status = contribution.status and contribution.status()
    -- A colour we don't know the severity of comes from a contribution we don't own, so
    -- it is ignored rather than allowed to take the button over.
    local severity = status and status.color and ColorSeverity[ status.color ]

    if severity and severity > best then
      color = status.color
      best = severity
    end
  end

  M.minimap_button.set_icon( color )
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

-- What a lockout turning over would forget: "9 boss kills", or nil when there is
-- nothing to lose.
--
-- Read by the subscriber that does the wiping, just before it wipes, and by the drop
-- simulator before it asks whether you meant it -- so the sentence you agree to and the
-- sentence you get afterwards can't drift apart.
---@return string?
local function describe_lockout_loss()
  local counted = {
    { count = getn( M.boss_killed.get_killed_bosses() ), noun = "boss kill" }
  }

  -- Extensions that keep lockout-scoped records add their own entries, so the sentence
  -- you agree to in the reset dialog and the one you're told afterwards stay the same
  -- sentence no matter what's loaded.
  for _, describe in ipairs( extension_hooks.lockout_loss ) do
    for _, entry in ipairs( describe() or {} ) do
      table.insert( counted, entry )
    end
  end

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

-- The full soft-res picture before the group filter drops everyone who isn't here, or nil
-- before the chain is built or if no such tap exists. Guarded because `Chain.build`'s
-- `tap()` errors on an unknown name -- once a source extension owns "present_players"
-- (Phase C), whether the "unfiltered" tap exists at all is no longer guaranteed. Asked
-- via has_tap rather than pcall so a genuine error from inside the chain still surfaces.
---@param name string
---@return any?
local function softres_tap( name )
  if not M.softres_built or not M.softres_built.has_tap( name ) then return nil end

  return M.softres_built.tap( name )
end

local function create_components()
  ---@type AceTimer
  M.ace_timer = lib_stub( "AceTimer-3.0" )

  local db = m.Db.new( M.char_db )

  ---@type EventBus
  M.event_bus = m.EventBus.new()

  ---@type Config
  M.config = m.Config.new( db( "config" ), M.event_bus )

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

  ---@type Chain
  M.softres_chain = m.Chain.new( "softres" )

  ---@type Chain
  M.awarded_loot_chain = m.Chain.new( "awarded_loot" )

  -- Fan-outs that used to be a hardcoded list of callees in this file. Rebuilt on every
  -- create_components() so a reload doesn't accumulate the previous run's subscribers.
  extension_hooks = { group_changed = {}, lockout_reset = {}, lockout_loss = {} }

  ---@type MinimapContribution[]
  M.minimap_contributions = {}

  -- Same reason, and it has to happen before Extensions.enable() gets its chance to
  -- register one: a source left over from a previous composition would make the built-in
  -- fallback below think the slot was claimed, and core would then skip contributing the
  -- backbone that goes with it.
  m.SoftResSource.clear()

  m.Extensions.attach( db( "extensions" ), M.event_bus )

  -- What an extension is allowed to see. Deliberately narrow: this is the surface we're
  -- committing to, and the composition root is not part of it.
  ---@param extension_name string
  ---@return ExtensionContext
  make_extension_context = function( extension_name )
    local extension = m.Extensions.get( extension_name ) or {}

    return {
      -- Scoped, so an extension can't collide with core's db keys or another
      -- extension's, and so its data is recognisable when it needs cleaning up.
      db = function( key )
        return db( string.format( "extension_%s_%s", extension_name, key ) )
      end,
      api = M.api,
      config = M.config,
      chat = M.chat,
      group_roster = M.group_roster,
      player_info = M.player_info,
      ace_timer = M.ace_timer,
      event_bus = M.event_bus,
      popup_builder = popup_builder,
      frame_builder = m.FrameBuilder,
      gui_elements = m.GuiElements,
      softres_chain = M.softres_chain,
      awarded_loot_chain = M.awarded_loot_chain,
      softres_source = { register = m.SoftResSource.register },
      softres_tap = softres_tap,
      minimap = {
        register = function( contribution ) table.insert( M.minimap_contributions, contribution ) end,
        refresh = refresh_minimap
      },
      is_enabled = function() return m.Extensions.is_enabled( extension_name ) end,
      set_enabled = function( value ) m.Extensions.set_enabled( extension_name, value ) end,
      title = extension.title,
      on_group_changed = function( callback ) table.insert( extension_hooks.group_changed, callback ) end,
      on_lockout_reset = function( callback ) table.insert( extension_hooks.lockout_reset, callback ) end,
      lockout_loss = function( describe ) table.insert( extension_hooks.lockout_loss, describe ) end,
      -- on_ready only: everything core builds exists by then. Named lookup rather than
      -- handing over M itself, so what extensions depend on stays visible.
      get = function( name ) return M[ name ] end
    }
  end

  ---@type ItemUtils
  M.item_utils = m.ItemUtils

  ---@type TooltipReader
  M.tooltip_reader = m.TooltipReader.new( M.api() )

  ---@type BossKilled
  M.boss_killed = m.BossKilled.new( db( "boss_killed" ) )

  M.boss_killed.subscribe( function( boss_name )
    info( string.format( "%s was killed.", hl( boss_name ) ) )
  end )

  -- TODO: Add type.
  M.version_broadcast = m.VersionBroadcast.new( db( "version_broadcast" ), M.player_info, version.str )

  M.raw_awarded_loot = m.AwardedLoot.new( db( "awarded_loot" ), M.chat )

  -- Extensions declare themselves here: chain links, config settings, lifecycle hooks.
  -- First, so a source extension can contribute the backbone before core decides whether
  -- to supply its own; before anything is built, so their links are in the chain when it
  -- is. They can anchor to names that do not exist yet -- see Chain's resolve().
  m.Extensions.enable( make_extension_context )

  ---@type AwardedLoot
  M.awarded_loot = M.awarded_loot_chain.build( M.raw_awarded_loot ).final

  -- Quiet when nothing is installed to contribute the backbone: every soft-res link an
  -- extension added is then unplaceable for one reason the user already got told about at
  -- login, and reporting each one as its own error blames a working configuration. With a
  -- source present an unplaceable link is a real mistake and still says so.
  M.softres_built = M.softres_chain.build( m.SoftResSource.base(),
    { report = m.SoftResSource.get() ~= nil } )

  ---@type GroupAwareSoftRes
  M.softres = M.softres_built.final

  ---@type SoftRes
  M.unfiltered_view = softres_tap( "unfiltered" )

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
  M.trade_tracker = m.TradeTracker.new( M.ace_timer, M.chat, trade_complete_callback )

  -- TODO: Add type.
  M.usage_printer = m.UsagePrinter.new( M.chat )

  -- TODO: Add type.
  M.minimap_button = m.MinimapButton.new( M.api, db( "minimap_button" ), M.config, M.event_bus, M.minimap_contributions )

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
    M.dropped_loot,
    M.dropped_loot_announce,
    M.master_loot,
    M.auto_group_loot,
    M.roll_controller,
    M.player_info
  )

  M.roll_simulator = m.RollSimulator.new( M )

  M.drop_simulator = m.DropSimulator.new( M.boss_killed, M.raid_lockout, confirm_lockout_reset )

  M.gargul_bridge = m.GargulBridge.new( M.player_info, M.roll_controller, M.config, m.SoftResSource.get_import_string, M.softres )

  M.roll_for_broadcast = m.RollForBroadcast.new( M.roll_controller, M.config )
  M.roll_for_receiver = m.RollForReceiver.new( M.rolling_popup, db( "receiver" ) )

  ---@type OptionsFrameContentTransformer
  local options_frame_content_transformer = m.OptionsFrameContentTransformer.new()

  -- The options render into the game's settings window, so the panel owns the frames and
  -- hands each one over as it builds that page.
  ---@type table<string, OptionsFrame>
  M.extension_options = {}

  ---@type InterfaceOptions
  M.interface_options = m.InterfaceOptions.new( M.api(), function( parent, section, extension_name )
    -- An extension owns its page: it keeps its own database, so core has no idea what is
    -- worth putting on it. Core supplies the canvas and the builders and asks the
    -- extension to fill it in. Pages may end up looking a little different from each
    -- other, which is the trade for extensions not having to register their settings with
    -- core just to be allowed to draw them.
    if extension_name then
      local extension = m.Extensions.get( extension_name )
      local page

      if extension and extension.options_page then
        page = extension.options_page( make_extension_context( extension_name ), parent )
      end

      -- No page of its own, so core draws the one thing every extension has: its summary
      -- and the switch that turns it on.
      page = page or m.OptionsFrame.new(
        popup_builder(), options_frame_content_transformer, M.config, parent, "extension", extension_name )

      M.extension_options[ extension_name ] = page

      return page
    end

    ---@type OptionsFrame
    M.options = m.OptionsFrame.new(
      popup_builder(), options_frame_content_transformer, M.config, parent, section )

    return M.options
  end )

  ---@type AutoLootFrameContentTransformer
  local autoloot_frame_content_transformer = m.AutoLootFrameContentTransformer.new()

  ---@type AutoLootFrame
  M.autoloot_frame = m.AutoLootFrame.new( popup_builder(), autoloot_frame_content_transformer, db( "autoloot_frame" ) )

  m.AutoLootTree.init( M.autoloot_db )

  -- Construction phase. Everything above exists now, so extensions that build frames or
  -- register slash commands do it here rather than in on_enable.
  m.Extensions.ready( make_extension_context )

  -- Nobody claimed the click, so it does what a bare /rf does. Decided once, here, after
  -- every extension has had its chance to subscribe during on_enable/on_ready -- the
  -- subscriber list is fixed for the rest of the session, so this is equivalent to asking
  -- "did anyone claim it" at click time, without the button needing to know what the
  -- default even is. With no soft-res source installed this is the path the button takes.
  if not M.event_bus.has_subscribers( "minimap_icon_left_click" ) then
    M.event_bus.subscribe( "minimap_icon_left_click", function() M.interface_options.open() end )
  end
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
  -- stale, it's wrong. Said out loud rather than wiped quietly, but only when there was
  -- something to lose.
  M.raid_lockout.subscribe( function( changed )
    -- Counted before the wipe, obviously, but also before it for a second reason: this
    -- is the same sentence the simulator showed when it asked.
    local lost = describe_lockout_loss()

    M.boss_killed.reset()

    for _, callback in ipairs( extension_hooks.lockout_reset ) do
      callback()
    end

    if not lost then return end

    info( string.format( "New lockout (%s) - %s forgotten.",
      hl( table.concat( changed, ", " ) ), lost ) )
  end )

  M.event_bus.subscribe( "config_change_requires_ui_reload", function()
    M.confirmation_dialog.show( {
      title = "This change requires a UI reload.",
      question = "Reload the UI now?",
      on_yes = function() m.api.ReloadUI() end
    } )
  end )

  M.event_bus.subscribe( "softres_imported", function( event )
    refresh_minimap()

    -- Only on an interactive (GUI) import -- not on the login reload re-importing the
    -- saved string, which would otherwise re-broadcast to Gargul and fire auto-master-loot
    -- on every login.
    if not event.interactive then return end

    if M.gargul_bridge then M.gargul_bridge.broadcast_softres( event.raw ) end
    M.auto_master_loot.on_softres_import()
  end )

  M.event_bus.subscribe( "softres_cleared", function()
    M.winner_tracker.clear()
    refresh_minimap()
  end )

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
      M.interface_options.open()
      return
    end

    if string.find( args, "^autoloot" ) then
      M.autoloot_frame.toggle()
      return
    end

    -- A bare /rf is a request for the options window, not an incomplete roll command. Restoring a
    -- dismissed rolling popup still wins, same as it did when this printed usage instead.
    if roll_slash_command == RollSlashCommand.NormalRoll and string.find( args, "^%s*$" ) then
      if M.roll_for_receiver.show() then return end

      M.interface_options.open()
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

  -- Which extensions are actually live this session, in ModUi's banner format: the addon
  -- name, then the extension's name, then the extension's own version -- which is not
  -- core's and can differ from it. Asked here rather than printed by each extension so a
  -- third-party one can't decide not to say, and so "it's installed" and "it enabled
  -- without throwing" stay distinguishable -- a failed extension has already said so via
  -- m.err and is not announced as loaded.
  for _, extension in ipairs( m.Extensions.enabled() ) do
    if not extension.failed then
      local extension_version = m.Extensions.version( extension.name )
      local version_str = extension_version and string.format( " (%s)", hl( string.format( "v%s", extension_version ) ) ) or ""

      m.print( string.format( "%s %s: Loaded%s.", m.colors.blue( "RollFor" ), m.colors.purple( extension.title ), version_str ) )
    end
  end

  M.version_broadcast.broadcast()
  -- Answers as UPDATE_INSTANCE_INFO, which is where a lockout that turned over while
  -- we were logged out gets noticed.
  M.raid_lockout.refresh()

  -- Whoever owns the soft-res source imports its saved data off this, at exactly the
  -- point in the login sequence where core used to do it inline.
  M.event_bus.notify( "player_login" )

  -- The button constructs White and is corrected here, once every source has had its say
  -- through the player_login event above.
  refresh_minimap()

  -- Soft-res is a source extension's job now, and with none installed every soft-res
  -- command and window is simply absent. Said once, plainly, so that "where did /sr go"
  -- has an answer in the chat frame rather than only in a changelog. Not m.err: nothing
  -- has gone wrong, this is a supported way to run the addon.
  if not m.SoftResSource.get() then
    info( string.format( "No soft-res source installed. Soft-res features are unavailable -- install %s.",
      hl( "RollForSoftResIt" ) ) )
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
  for _, callback in ipairs( extension_hooks.group_changed ) do
    callback()
  end

  refresh_minimap()
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
