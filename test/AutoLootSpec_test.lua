package.path = "./?.lua;" .. package.path .. ";../?.lua;../RollFor/?.lua;../RollFor/libs/?.lua"

require( "src/bcc/compat" )
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

function AutoLootSpec:should_autoloot_any_explicitly_added_items()
  local item = qi( "Fire for Crafting", 123, 4, bop )

  local rf = new_roll_for()
      :config( {
        auto_loot = true
      } )
      :build()

  local id = rf.auto_loot.add_category( "global" )
  rf.auto_loot.add( id, item.link )

  lu.assertEquals( rf.auto_loot.is_auto_looted( item ), true )

  rf.auto_loot.remove( item.link )

  lu.assertEquals( rf.auto_loot.is_auto_looted( item ), false )
end

function AutoLootSpec:should_not_autoloot_if_category_is_disabled()
  local item = qi( "Fire for Crafting", 123, 4, bop )

  local rf = new_roll_for()
      :config( {
        auto_loot = true
      } )
      :build()

  local id = rf.auto_loot.add_category( "global" )
  rf.auto_loot.add( id, item.link )
  lu.assertEquals( rf.auto_loot.is_auto_looted( item ), true )

  rf.auto_loot.disable_category( id )
  lu.assertEquals( rf.auto_loot.is_auto_looted( item ), false )
end

function AutoLootSpec:should_not_autoloot_if_config_option_is_false()
  local low_quality_item = qi( "Pocket Lint", 123, 1, boe )
  local explicitly_added_item = qi( "Fire for Crafting", 123, 4, bop )

  local rf = new_roll_for()
      :config( {
        auto_loot = false
      } )
      :build()

  local id = rf.auto_loot.add_category( "global" )
  rf.auto_loot.add( id, explicitly_added_item.link )

  lu.assertEquals( rf.auto_loot.is_auto_looted( low_quality_item ), false )
  lu.assertEquals( rf.auto_loot.is_auto_looted( explicitly_added_item ), false )
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

  local id = rf.auto_loot.add_category( "global" )
  rf.auto_loot.add( id, item.link )
  lu.assertEquals( rf.auto_loot.is_auto_looted( item ), true )

  chat.console( "RollFor: Category global added with ID 1." )
  chat.console( "RollFor: [Hearthstone] added to global." )

  u.mock_table_function( "UnitName", { player = "Psikutas", target = "Princess Kenny" } )
  u.mock_table_function( "GetMasterLootCandidate", { "Psikutas", "Obszczymucha" } )
  u.mock( "GiveMasterLoot", function( slot ) loot_facade.notify( "LootSlotCleared", slot ) end )

  loot_facade.notify( "LootOpened", item )

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

  local id = rf.auto_loot.add_category( "global" )
  rf.auto_loot.add( id, item.link )
  lu.assertEquals( rf.auto_loot.is_auto_looted( item ), true )
  lu.assertEquals( rf.auto_loot.is_auto_looted( item2 ), false )

  chat.console( "RollFor: Category global added with ID 1." )
  chat.console( "RollFor: [Hearthstone] added to global." )

  u.mock_table_function( "UnitName", { player = "Psikutas", target = "Princess Kenny" } )
  u.mock_table_function( "GetMasterLootCandidate", { "Psikutas", "Obszczymucha" } )
  u.mock( "GiveMasterLoot", function( slot ) loot_facade.notify( "LootSlotCleared", slot ) end )

  loot_facade.notify( "LootOpened", item, item2 )

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

  local id = rf.auto_loot.add_category( "global" )
  rf.auto_loot.add( id, item.link )
  lu.assertEquals( rf.auto_loot.is_auto_looted( item ), true )
  lu.assertEquals( rf.auto_loot.is_auto_looted( item2 ), false )

  chat.console( "RollFor: Category global added with ID 1." )
  chat.console( "RollFor: [Hearthstone] added to global." )

  u.mock_table_function( "UnitName", { player = "Psikutas", target = "Princess Kenny" } )
  u.mock_table_function( "GetMasterLootCandidate", { "Psikutas", "Obszczymucha" } )
  u.mock( "GiveMasterLoot", function( slot ) loot_facade.notify( "LootSlotCleared", slot ) end )

  loot_facade.notify( "LootOpened", item, item2 )

  chat.raid( "Princess Kenny dropped 2 items:" )
  chat.raid( "1. [Hearthstone] (SR by Psikutas)" )
  chat.raid( "2. [Bag]" )

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

os.exit( lu.LuaUnit.run() )
