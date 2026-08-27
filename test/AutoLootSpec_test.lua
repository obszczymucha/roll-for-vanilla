package.path = "./?.lua;" .. package.path .. ";../?.lua;../RollFor/?.lua;../RollFor/libs/?.lua"

require( "src/compat" )
local u = require( "test/utils" )
local lu = u.luaunit()
local builder = require( "test/IntegrationTestBuilder" )
local ItemUtils = require( "src/ItemUtils" )
local new_roll_for = builder.new_roll_for
local qi = builder.qi
local boe, bop, quest = ItemUtils.BindType.BindOnEquip, ItemUtils.BindType.BindOnPickup, ItemUtils.BindType.Quest
local mock_loot_facade, mock_chat, i, p = builder.mock_loot_facade, builder.mock_chat, builder.i, builder.p
local gui = require( "test/gui_helpers" )
local item_link, buttons, enabled_item = gui.item_link, gui.buttons, gui.enabled_item
local sr = u.soft_res_item

AutoLootSpec = {}

function AutoLootSpec:should_autoloot_low_quality_items()
  local item = qi( "Pocket Lint", 123, 1, boe )

  local rf = new_roll_for()
      :config( {
        auto_loot = true
      } )
      :build()

  lu.assertEquals( rf.auto_loot.is_auto_looted( item ), true )
end

function AutoLootSpec:should_not_autoloot_high_quality_items()
  local item = qi( "Sword of Causing Damage", 123, 5, boe )

  local rf = new_roll_for()
      :config( {
        auto_loot = true
      } )
      :build()

  lu.assertEquals( rf.auto_loot.is_auto_looted( item ), false )
end

function AutoLootSpec:should_not_autoloot_bop_items_of_any_quality()
  local item = qi( "Scythe of Healing", 123, 1, bop )

  local rf = new_roll_for()
      :config( {
        auto_loot = true
      } )
      :build()

  lu.assertEquals( rf.auto_loot.is_auto_looted( item ), false )
end

function AutoLootSpec:should_not_autoloot_quest_items_of_any_quality()
  local item = qi( "Ancient Secret Text", 123, 1, quest )

  local rf = new_roll_for()
      :config( {
        auto_loot = true
      } )
      :build()

  lu.assertEquals( rf.auto_loot.is_auto_looted( item ), false )
end

function AutoLootSpec:autoloot_should_depend_on_loot_threshold()
  local rf_builder = new_roll_for()
      :config( {
        auto_loot = true
      } )

  local item = qi( "Fire for Crafting", 123, 2, boe )

  local rf_low_threshold = rf_builder:threshold( 2 ):build()
  lu.assertEquals( rf_low_threshold.auto_loot.is_auto_looted( item ), true )

  local rf_high_threshold = rf_builder:threshold( 3 ):build()
  lu.assertEquals( rf_high_threshold.auto_loot.is_auto_looted( item ), false )
end

-- Items ticked in the auto-loot GUI are auto-looted whatever their quality or bind type -- the
-- player asked for them by name, so none of the automatic rules get a say.
function AutoLootSpec:should_autoloot_items_on_the_predefined_list()
  local item = qi( "Fire for Crafting", 123, 4, bop )

  local rf = new_roll_for()
      :config( {
        auto_loot = true
      } )
      :build()

  lu.assertEquals( rf.auto_loot.is_auto_looted( item ), false )

  rf.auto_loot_list.enable( item )
  lu.assertEquals( rf.auto_loot.is_auto_looted( item ), true )

  rf.auto_loot_list.disable( item )
  lu.assertEquals( rf.auto_loot.is_auto_looted( item ), false )
end

function AutoLootSpec:should_not_autoloot_predefined_items_whose_boss_is_disabled()
  local item = qi( "Fire for Crafting", 123, 4, bop )

  local rf = new_roll_for()
      :config( {
        auto_loot = true
      } )
      :build()

  rf.auto_loot_list.enable( item )
  lu.assertEquals( rf.auto_loot.is_auto_looted( item ), true )

  rf.auto_loot_list.set_boss_enabled( false )
  lu.assertEquals( rf.auto_loot.is_auto_looted( item ), false )
end

function AutoLootSpec:should_not_autoloot_predefined_items_whose_dungeon_is_disabled()
  local item = qi( "Fire for Crafting", 123, 4, bop )

  local rf = new_roll_for()
      :config( {
        auto_loot = true
      } )
      :build()

  rf.auto_loot_list.enable( item )
  lu.assertEquals( rf.auto_loot.is_auto_looted( item ), true )

  rf.auto_loot_list.set_dungeon_enabled( false )
  lu.assertEquals( rf.auto_loot.is_auto_looted( item ), false )
end

function AutoLootSpec:should_not_autoloot_if_config_option_is_false()
  local low_quality_item = qi( "Pocket Lint", 123, 1, boe )
  local predefined_item = qi( "Fire for Crafting", 123, 4, bop )

  local rf = new_roll_for()
      :config( {
        auto_loot = false
      } )
      :build()

  rf.auto_loot_list.enable( predefined_item )

  lu.assertEquals( rf.auto_loot.is_auto_looted( low_quality_item ), false )
  lu.assertEquals( rf.auto_loot.is_auto_looted( predefined_item ), false )
end

AutoLootGuiSpec = {}

function AutoLootGuiSpec:should_auto_loot_item_without_displaying_rolling_popup()
  local loot_facade, chat = mock_loot_facade(), mock_chat()
  local item, p1, p2 = i( "Hearthstone", 123 ), p( "Psikutas" ), p( "Obszczymucha" )
  local rf = new_roll_for()
      :loot_facade( loot_facade )
      :raid_roster( p1, p2 )
      :chat( chat )
      :config( {
        auto_loot = true,
        auto_loot_messages = true
      } )
      :build()

  rf.auto_loot_list.enable( item )
  lu.assertEquals( rf.auto_loot.is_auto_looted( item ), true )

  u.mock_table_function( "UnitName", { player = "Psikutas", target = "Princess Kenny" } )
  u.mock_master_loot_candidates( { "Psikutas", "Obszczymucha" } )
  local master_loot = u.mock_async_master_loot( loot_facade )

  loot_facade.notify( "LootOpened", item )
  master_loot.flush()

  chat.raid( "Princess Kenny dropped 1 item:" )
  chat.raid( "1. [Hearthstone]" )
  chat.console( "RollFor: Auto-looting [Hearthstone]." )

  rf.loot_frame.should_display()
  rf.rolling_popup.should_be_hidden()
end

function AutoLootGuiSpec:should_auto_loot_one_item_and_display_rolling_popup_for_the_other()
  local loot_facade, chat = mock_loot_facade(), mock_chat()
  local item, item2, p1, p2 = i( "Hearthstone", 123 ), i( "Bag", 69 ), p( "Psikutas" ), p( "Obszczymucha" )
  local rf = new_roll_for()
      :loot_facade( loot_facade )
      :raid_roster( p1, p2 )
      :chat( chat )
      :config( {
        auto_loot = true,
        auto_loot_messages = true
      } )
      :build()

  rf.auto_loot_list.enable( item )
  lu.assertEquals( rf.auto_loot.is_auto_looted( item ), true )
  lu.assertEquals( rf.auto_loot.is_auto_looted( item2 ), false )

  u.mock_table_function( "UnitName", { player = "Psikutas", target = "Princess Kenny" } )
  u.mock_master_loot_candidates( { "Psikutas", "Obszczymucha" } )
  local master_loot = u.mock_async_master_loot( loot_facade )

  loot_facade.notify( "LootOpened", item, item2 )
  master_loot.flush()

  chat.raid( "Princess Kenny dropped 2 items:" )
  chat.raid( "1. [Bag]" )
  chat.raid( "2. [Hearthstone]" )
  chat.console( "RollFor: Auto-looting [Hearthstone]." )

  rf.loot_frame.should_display(
    enabled_item( 1, "Bag" )
  )
  rf.rolling_popup.should_be_hidden()

  -- When
  rf.loot_frame.click( 1 )

  -- Then
  rf.rolling_popup.should_display(
    item_link( item2, 1 ),
    buttons( "Roll", "InstaRaidRoll", "AwardOther", "Close" )
  )
end

function AutoLootGuiSpec:should_auto_loot_soft_ressed_item_and_display_rolling_popup_for_the_other()
  local loot_facade, chat = mock_loot_facade(), mock_chat()
  local item, item2, p1, p2 = i( "Hearthstone", 123 ), i( "Bag", 69 ), p( "Psikutas" ), p( "Obszczymucha" )
  local rf = new_roll_for()
      :loot_facade( loot_facade )
      :raid_roster( p1, p2 )
      :chat( chat )
      :soft_res_data( sr( p1.name, 123 ) )
      :config( {
        auto_loot = true,
        auto_loot_messages = true
      } )
      :build()

  rf.auto_loot_list.enable( item )
  lu.assertEquals( rf.auto_loot.is_auto_looted( item ), true )
  lu.assertEquals( rf.auto_loot.is_auto_looted( item2 ), false )

  u.mock_table_function( "UnitName", { player = "Psikutas", target = "Princess Kenny" } )
  u.mock_master_loot_candidates( { "Psikutas", "Obszczymucha" } )
  local master_loot = u.mock_async_master_loot( loot_facade )

  loot_facade.notify( "LootOpened", item, item2 )
  master_loot.flush()

  chat.raid( "Princess Kenny dropped 2 items:" )
  chat.raid( "1. [Hearthstone] (SR by Psikutas)" )
  chat.raid( "2. [Bag]" )
  chat.console( "RollFor: Auto-looting [Hearthstone]." )

  rf.loot_frame.should_display(
    enabled_item( 1, "Bag" )
  )
  rf.rolling_popup.should_be_hidden()

  -- When
  rf.loot_frame.click( 1 )

  -- Then
  rf.rolling_popup.should_display(
    item_link( item2, 1 ),
    buttons( "Roll", "InstaRaidRoll", "AwardOther", "Close" )
  )
end

function AutoLootGuiSpec:should_auto_loot_all_auto_lootable_items_and_display_rolling_popup_for_the_other()
  local loot_facade, chat = mock_loot_facade(), mock_chat()
  local item, item2, item3, p1, p2 = i( "Hearthstone", 123 ), i( "Hearthstone", 123 ), i( "Bag", 69 ), p( "Psikutas" ), p( "Obszczymucha" )
  local rf = new_roll_for()
      :loot_facade( loot_facade )
      :raid_roster( p1, p2 )
      :chat( chat )
      :soft_res_data( sr( p1.name, 123 ) )
      :config( {
        auto_loot = true,
        auto_loot_messages = true
      } )
      :build()

  rf.auto_loot_list.enable( item )
  lu.assertEquals( rf.auto_loot.is_auto_looted( item ), true )
  lu.assertEquals( rf.auto_loot.is_auto_looted( item2), true )
  lu.assertEquals( rf.auto_loot.is_auto_looted( item3 ), false )

  u.mock_table_function( "UnitName", { player = "Psikutas", target = "Princess Kenny" } )
  u.mock_master_loot_candidates( { "Psikutas", "Obszczymucha" } )

  local master_loot = u.mock_async_master_loot( loot_facade )

  loot_facade.notify( "LootOpened", item, item2, item3 )
  master_loot.flush()

  chat.raid( "Princess Kenny dropped 3 items:" )
  chat.raid( "1. [Hearthstone] (SR by Psikutas)" )
  chat.raid( "2. [Bag]" )
  chat.raid( "3. [Hearthstone]" )
  chat.console( "RollFor: Auto-looting [Hearthstone]." )
  chat.console( "RollFor: Auto-looting [Hearthstone]." )

  rf.loot_frame.should_display(
    enabled_item( 1, "Bag" )
  )
  rf.rolling_popup.should_be_hidden()

  -- When
  rf.loot_frame.click( 1 )

  -- Then
  rf.rolling_popup.should_display(
    item_link( item3, 1 ),
    buttons( "Roll", "InstaRaidRoll", "AwardOther", "Close" )
  )
end

-- Regression: auto-looted items must be registered as dropped loot so that
-- trading them out later is recognised as awarding them. This must hold even
-- when announcements are turned off -- registration is independent of the
-- announce path. Before the fix, disabling announcements also suppressed
-- registration, so this asserted name would have been nil.
function AutoLootGuiSpec:should_register_auto_looted_items_as_dropped_loot_even_when_announcements_are_off()
  local loot_facade, chat = mock_loot_facade(), mock_chat()
  local item, p1, p2 = i( "Hearthstone", 123 ), p( "Psikutas" ), p( "Obszczymucha" )
  local rf = new_roll_for()
      :loot_facade( loot_facade )
      :raid_roster( p1, p2 )
      :chat( chat )
      :config( {
        auto_loot = true,
        auto_loot_messages = true,
        auto_loot_announce = false
      } )
      :build()

  rf.auto_loot_list.enable( item )

  u.mock_table_function( "UnitName", { player = "Psikutas", target = "Princess Kenny" } )
  u.mock_master_loot_candidates( { "Psikutas", "Obszczymucha" } )
  local master_loot = u.mock_async_master_loot( loot_facade )

  -- When
  loot_facade.notify( "LootOpened", item )
  master_loot.flush()

  -- Then
  lu.assertEquals( rf.dropped_loot.get_dropped_item_name( 123 ), "Hearthstone" )
end

-- Items on the predefined auto-loot list are announced even when auto-loot
-- announcements are turned off (only automatically auto-looted items are
-- silenced by that toggle).
function AutoLootGuiSpec:should_announce_predefined_items_even_when_announcements_are_off()
  local loot_facade, chat = mock_loot_facade(), mock_chat()
  local item, p1, p2 = i( "Hearthstone", 123 ), p( "Psikutas" ), p( "Obszczymucha" )
  local rf = new_roll_for()
      :loot_facade( loot_facade )
      :raid_roster( p1, p2 )
      :chat( chat )
      :config( {
        auto_loot = true,
        auto_loot_messages = true,
        auto_loot_announce = false
      } )
      :build()

  rf.auto_loot_list.enable( item )

  u.mock_table_function( "UnitName", { player = "Psikutas", target = "Princess Kenny" } )
  u.mock_master_loot_candidates( { "Psikutas", "Obszczymucha" } )
  local master_loot = u.mock_async_master_loot( loot_facade )

  -- When
  loot_facade.notify( "LootOpened", item )
  master_loot.flush()

  -- Then
  chat.raid( "Princess Kenny dropped 1 item:" )
  chat.raid( "1. [Hearthstone]" )
  chat.console( "RollFor: Auto-looting [Hearthstone]." )
end

os.exit( lu.LuaUnit.run() )
