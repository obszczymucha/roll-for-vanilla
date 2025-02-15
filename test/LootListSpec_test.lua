package.path = "./?.lua;" .. package.path .. ";../?.lua"

local u = require( "test/utils" )
local lu = u.luaunit()
local builder = require( "test/IntegrationTestBuilder" )
local mock_loot_facade, mock_chat, new_roll_for = builder.mock_loot_facade, builder.mock_chat, builder.new_roll_for
local i, qi, p = builder.i, builder.qi, builder.p
local gui = require( "test/gui_helpers" )
local item_link, text, buttons = gui.item_link, gui.text, gui.buttons
local enabled_item, disabled_item, selected_item = gui.enabled_item, gui.disabled_item, gui.selected_item
local sr, hr = u.soft_res_item, u.hard_res_item
local ItemUtils = require( "src/ItemUtils" )
local boe, bop, quest = ItemUtils.BindType.BindOnEquip, ItemUtils.BindType.BindOnPickup, ItemUtils.BindType.Quest
local individual_award_button = gui.individual_award_button
local mock_random = u.mock_multiple_math_random

LootListSpec = {}

function LootListSpec:should_display_sr_tooltip()
  -- Given
  local loot_facade, chat = mock_loot_facade(), mock_chat()
  local item, p1, p2 = i( "Bag", 123 ), p( "Psikutas" ), p( "Obszczymucha" )
  local rf = new_roll_for()
      :loot_facade( loot_facade )
      :raid_roster( p1, p2 )
      :chat( chat )
      :soft_res_data( hr( 123 ), sr( p1.name, 123 ), sr( p2.name, 123 ) )
      :build()

  -- Then
  rf.loot_frame.should_be_hidden()

  -- When
  loot_facade.notify( "LootOpened", item, item )

  -- Then
  rf.loot_frame.should_display(
    enabled_item( 1, "Bag", "HR" ),
    enabled_item( 2, "Bag", "SR", { "Soft-ressed by:", "Obszczymucha", "Psikutas" } )
  )
end

function LootListSpec:should_display_item_bind_type()
  -- Given
  local loot_facade, chat = mock_loot_facade(), mock_chat()
  local p1, p2 = p( "Psikutas" ), p( "Obszczymucha" )
  local boe_item = qi( "Bag", 123, 1, boe )
  local bop_item = qi( "Dagger", 222, 1, bop )
  local quest_item = qi( "Piece of Text", 400, 1, quest )

  local rf = new_roll_for()
      :loot_facade( loot_facade )
      :raid_roster( p1, p2 )
      :chat( chat )
      :build()

  -- Then
  rf.loot_frame.should_be_hidden()

  -- When
  loot_facade.notify( "LootOpened", boe_item, bop_item, quest_item )

  -- Then
  rf.loot_frame.should_display(
    enabled_item( 1, "Bag", nil, nil, "BoE" ),
    enabled_item( 2, "Dagger", nil, nil, "BoP" ),
    enabled_item( 3, "Piece of Text", nil, nil, "BoP" )
  )
end

function LootListSpec:should_display_sr_tooltip_and_item_bind_type()
  -- Given
  local loot_facade, chat = mock_loot_facade(), mock_chat()
  local p1, p2 = p( "Psikutas" ), p( "Obszczymucha" )
  local i1 = qi( "Bag", 123, 1, bop )
  local i2 = qi( "Sword", 222, 1, bop )

  local rf = new_roll_for()
      :loot_facade( loot_facade )
      :raid_roster( p1, p2 )
      :chat( chat )
      :soft_res_data( hr( 222 ), sr( p1.name, 123 ), sr( p2.name, 123 ) )
      :build()

  -- Then
  rf.loot_frame.should_be_hidden()

  -- When
  loot_facade.notify( "LootOpened", i1, i2 )

  -- Then
  rf.loot_frame.should_display(
    enabled_item( 1, "Bag", "SR", { "Soft-ressed by:", "Obszczymucha", "Psikutas" }, "BoP" ),
    enabled_item( 2, "Sword", "HR", nil, "BoP" )
  )
end

function LootListSpec:should_select_hr_item_if_clicked_on_any_item_of_that_id()
  -- Given
  local loot_facade, chat = mock_loot_facade(), mock_chat()
  local item, item2, p1, p2 = i( "Bag", 123 ), i( "Hearthstone", 69 ), p( "Psikutas" ), p( "Obszczymucha" )
  local rf = new_roll_for()
      :loot_facade( loot_facade )
      :raid_roster( p1, p2 )
      :chat( chat )
      :soft_res_data( hr( 123 ), sr( p1.name, 123 ), sr( p2.name, 123 ) )
      :build()

  -- Then
  rf.loot_frame.should_be_hidden()

  -- When
  loot_facade.notify( "LootOpened", item, item, item, item, item, item2 )

  -- Then
  rf.loot_frame.should_display(
    enabled_item( 1, "Bag", "HR" ),
    enabled_item( 2, "Bag", "SR", { "Soft-ressed by:", "Obszczymucha" } ),
    enabled_item( 3, "Bag", "SR", { "Soft-ressed by:", "Psikutas" } ),
    enabled_item( 4, "Bag" ),
    enabled_item( 5, "Bag" ),
    enabled_item( 6, "Hearthstone" )
  )
  chat.raid( "Princess Kenny dropped 6 items:" )
  chat.raid( "1. [Bag] (HR)" )
  chat.raid( "2. [Bag] (SR by Obszczymucha)" )
  chat.raid( "3. [Bag] (SR by Psikutas)" )
  chat.raid( "4. 2x[Bag]" )
  chat.raid( "5. [Hearthstone]" )
  rf.rolling_popup.should_be_hidden()

  ---@param item_index_to_click number
  local function assert_hr_item_is_selected( item_index_to_click )
    -- When
    rf.loot_frame.click( item_index_to_click )

    -- Then
    rf.loot_frame.should_display(
      selected_item( 1, "Bag", "HR" ),
      disabled_item( 2, "Bag", "SR", { "Soft-ressed by:", "Obszczymucha" } ),
      disabled_item( 3, "Bag", "SR", { "Soft-ressed by:", "Psikutas" } ),
      disabled_item( 4, "Bag" ),
      disabled_item( 5, "Bag" ),
      disabled_item( 6, "Hearthstone" )
    )
    rf.rolling_popup.should_display(
      item_link( item, 1 ),
      text( "This item is hard-ressed.", 11 ),
      buttons( "Roll", "AwardOther", "Close" )
    )

    -- When
    rf.rolling_popup.click( "Close" )

    -- Then
    rf.loot_frame.should_display(
      enabled_item( 1, "Bag", "HR" ),
      enabled_item( 2, "Bag", "SR", { "Soft-ressed by:", "Obszczymucha" } ),
      enabled_item( 3, "Bag", "SR", { "Soft-ressed by:", "Psikutas" } ),
      enabled_item( 4, "Bag" ),
      enabled_item( 5, "Bag" ),
      enabled_item( 6, "Hearthstone" )
    )
  end

  assert_hr_item_is_selected( 1 )
  assert_hr_item_is_selected( 2 )
  assert_hr_item_is_selected( 3 )
  assert_hr_item_is_selected( 4 )
  assert_hr_item_is_selected( 5 )

  -- When
  rf.loot_frame.click( 6 )

  -- Then
  rf.loot_frame.should_display(
    disabled_item( 1, "Bag", "HR" ),
    disabled_item( 2, "Bag", "SR", { "Soft-ressed by:", "Obszczymucha" } ),
    disabled_item( 3, "Bag", "SR", { "Soft-ressed by:", "Psikutas" } ),
    disabled_item( 4, "Bag" ),
    disabled_item( 5, "Bag" ),
    selected_item( 6, "Hearthstone" )
  )
  rf.rolling_popup.should_display(
    item_link( item2, 1 ),
    buttons( "Roll", "InstaRaidRoll", "AwardOther", "Close" )
  )

  -- When
  rf.rolling_popup.click( "Close" )

  -- Then
  rf.rolling_popup.should_be_hidden()
  rf.loot_frame.should_display(
    enabled_item( 1, "Bag", "HR" ),
    enabled_item( 2, "Bag", "SR", { "Soft-ressed by:", "Obszczymucha" } ),
    enabled_item( 3, "Bag", "SR", { "Soft-ressed by:", "Psikutas" } ),
    enabled_item( 4, "Bag" ),
    enabled_item( 5, "Bag" ),
    enabled_item( 6, "Hearthstone" )
  )
end

function LootListSpec:should_select_both_sr_items_if_clicked_on_any_item_of_that_id()
  -- Given
  local loot_facade, chat = mock_loot_facade(), mock_chat()
  local item, item2, p1, p2 = i( "Bag", 123 ), i( "Hearthstone", 69 ), p( "Psikutas" ), p( "Obszczymucha" )
  local rf = new_roll_for()
      :loot_facade( loot_facade )
      :raid_roster( p1, p2 )
      :chat( chat )
      :soft_res_data( sr( p1.name, 123 ), sr( p2.name, 123 ) )
      :build()

  -- Then
  rf.loot_frame.should_be_hidden()

  -- When
  loot_facade.notify( "LootOpened", item, item, item, item, item2 )

  -- Then
  rf.loot_frame.should_display(
    enabled_item( 1, "Bag", "SR", { "Soft-ressed by:", "Obszczymucha" } ),
    enabled_item( 2, "Bag", "SR", { "Soft-ressed by:", "Psikutas" } ),
    enabled_item( 3, "Bag" ),
    enabled_item( 4, "Bag" ),
    enabled_item( 5, "Hearthstone" )
  )
  chat.raid( "Princess Kenny dropped 5 items:" )
  chat.raid( "1. [Bag] (SR by Obszczymucha)" )
  chat.raid( "2. [Bag] (SR by Psikutas)" )
  chat.raid( "3. 2x[Bag]" )
  chat.raid( "4. [Hearthstone]" )
  rf.rolling_popup.should_be_hidden()

  ---@param item_index_to_click number
  local function assert_sr_items_are_selected( item_index_to_click )
    -- When
    rf.loot_frame.click( item_index_to_click )

    -- Then
    rf.loot_frame.should_display(
      selected_item( 1, "Bag", "SR", { "Soft-ressed by:", "Obszczymucha" } ),
      selected_item( 2, "Bag", "SR", { "Soft-ressed by:", "Psikutas" } ),
      disabled_item( 3, "Bag" ),
      disabled_item( 4, "Bag" ),
      disabled_item( 5, "Hearthstone" )
    )
    rf.rolling_popup.should_display(
      item_link( item, 2 ),
      text( "Obszczymucha soft-ressed this item.", 11 ),
      individual_award_button,
      text( "Psikutas soft-ressed this item.", 8 ),
      individual_award_button,
      buttons( "AwardOther", "Close" )
    )

    -- When
    rf.rolling_popup.click( "Close" )

    -- Then
    rf.loot_frame.should_display(
      enabled_item( 1, "Bag", "SR", { "Soft-ressed by:", "Obszczymucha" } ),
      enabled_item( 2, "Bag", "SR", { "Soft-ressed by:", "Psikutas" } ),
      enabled_item( 3, "Bag" ),
      enabled_item( 4, "Bag" ),
      enabled_item( 5, "Hearthstone" )
    )
  end

  assert_sr_items_are_selected( 1 )
  assert_sr_items_are_selected( 2 )
  assert_sr_items_are_selected( 3 )
  assert_sr_items_are_selected( 4 )

  -- When
  rf.loot_frame.click( 5 )

  -- Then
  rf.loot_frame.should_display(
    disabled_item( 1, "Bag", "SR", { "Soft-ressed by:", "Obszczymucha" } ),
    disabled_item( 2, "Bag", "SR", { "Soft-ressed by:", "Psikutas" } ),
    disabled_item( 3, "Bag" ),
    disabled_item( 4, "Bag" ),
    selected_item( 5, "Hearthstone" )
  )
  rf.rolling_popup.should_display(
    item_link( item2, 1 ),
    buttons( "Roll", "InstaRaidRoll", "AwardOther", "Close" )
  )

  -- When
  rf.rolling_popup.click( "Close" )

  -- Then
  rf.rolling_popup.should_be_hidden()
  rf.loot_frame.should_display(
    enabled_item( 1, "Bag", "SR", { "Soft-ressed by:", "Obszczymucha" } ),
    enabled_item( 2, "Bag", "SR", { "Soft-ressed by:", "Psikutas" } ),
    enabled_item( 3, "Bag" ),
    enabled_item( 4, "Bag" ),
    enabled_item( 5, "Hearthstone" )
  )
end

function LootListSpec:should_not_select_the_loot_if_the_popup_was_closed_after_looting_low_quality_items_items()
  -- Given
  local loot_facade, chat = mock_loot_facade(), mock_chat()
  local item, item2, p1, p2 = qi( "Bag", 123, 4 ), qi( "Hearthstone", 69, 4 ), p( "Psikutas" ), p( "Obszczymucha" )
  local rf = new_roll_for()
      :loot_facade( loot_facade )
      :raid_roster( p1, p2 )
      :chat( chat )
      :build()
  mock_random( { { 1, 2, 1 } } )

  -- Then
  rf.loot_frame.should_be_hidden()

  -- When
  loot_facade.notify( "LootOpened", item, item2 )

  -- Then
  chat.raid( "Princess Kenny dropped 2 items:" )
  chat.raid( "1. [Bag]" )
  chat.raid( "2. [Hearthstone]" )
  rf.loot_frame.should_display(
    enabled_item( 1, "Bag" ),
    enabled_item( 2, "Hearthstone" )
  )
  rf.rolling_popup.should_be_hidden()

  -- When
  rf.loot_frame.click( 1 )

  -- Then
  rf.loot_frame.should_display(
    selected_item( 1, "Bag" ),
    disabled_item( 2, "Hearthstone" )
  )
  rf.rolling_popup.should_display(
    item_link( item, 1 ),
    buttons( "Roll", "InstaRaidRoll", "AwardOther", "Close" )
  )

  -- When
  rf.rolling_popup.click( "InstaRaidRoll" )

  -- Then
  chat.raid( "Obszczymucha wins [Bag] (raid-roll)." )
  rf.rolling_popup.should_display(
    item_link( item, 1 ),
    text( "Obszczymucha wins the raid-roll.", 11 ),
    buttons( "AwardWinner", "RaidRollAgain", "AwardOther", "Close" )
  )

  -- When
  loot_facade.notify( "LootClosed" )
  loot_facade.notify( "LootOpened", item, item2 )
  loot_facade.notify( "LootSlotCleared", 1 )
  loot_facade.notify( "LootSlotCleared", 2 )
  loot_facade.notify( "LootClosed" )

  -- When
  rf.rolling_popup.click( "Close" )

  -- Then
  rf.rolling_popup.should_be_hidden()
  rf.loot_frame.should_be_hidden()

  -- When
  loot_facade.notify( "LootOpened", item, item2 )

  -- Then
  rf.rolling_popup.should_be_hidden()
  rf.loot_frame.should_display(
    enabled_item( 1, "Bag" ),
    enabled_item( 2, "Hearthstone" )
  )
end

function LootListSpec:should_loot_the_items_below_quality()
  -- Given
  local loot_facade, chat = mock_loot_facade(), mock_chat()
  local item, item2, p1, p2 = qi( "Bag", 123, 1 ), qi( "Hearthstone", 69, 1 ), p( "Psikutas" ), p( "Obszczymucha" )
  local rf = new_roll_for()
      :loot_facade( loot_facade )
      :raid_roster( p1, p2 )
      :chat( chat )
      :build()
  mock_random( { { 1, 2, 1 } } )
  rf.enable_debug( "RollController", "LootController" )

  -- Then
  rf.loot_frame.should_be_hidden()

  -- When
  loot_facade.notify( "LootOpened", item, item2 )

  -- Then
  rf.loot_frame.should_display(
    enabled_item( 1, "Bag" ),
    enabled_item( 2, "Hearthstone" )
  )
  rf.rolling_popup.should_be_hidden()

  -- When
  rf.loot_frame.click( 1 )

  -- Then
  rf.loot_frame.should_display(
    enabled_item( 1, "Hearthstone" )
  )
  rf.rolling_popup.should_be_hidden()
end

function LootListSpec:should_not_allow_to_select_item_while_rolling_is_in_progress()
  -- Given
  local loot_facade, chat = mock_loot_facade(), mock_chat()
  local item, item2, item3, p1, p2 = i( "Bag", 123 ), i( "Hearthstone", 69 ), i( "Sword", 42 ), p( "Psikutas" ), p( "Obszczymucha" )
  local rf = new_roll_for()
      :loot_facade( loot_facade )
      :raid_roster( p1, p2 )
      :chat( chat )
      :build()

  -- Then
  rf.loot_frame.should_be_hidden()

  -- When
  loot_facade.notify( "LootOpened", item )

  -- Then
  chat.raid( "Princess Kenny dropped 1 item:" )
  chat.raid( "1. [Bag]" )
  rf.loot_frame.should_display(
    enabled_item( 1, "Bag" )
  )
  rf.rolling_popup.should_be_hidden()

  -- When
  rf.loot_frame.click( 1 )

  -- Then
  rf.loot_frame.should_display(
    selected_item( 1, "Bag" )
  )
  rf.rolling_popup.should_display(
    item_link( item, 1 ),
    buttons( "Roll", "InstaRaidRoll", "AwardOther", "Close" )
  )

  -- When
  rf.rolling_popup.click( "Roll" )

  -- Then
  chat.raid_warning( "Roll for [Bag]: /roll (MS) or /roll 99 (OS) or /roll 98 (TMOG)" )
  rf.rolling_popup.should_display(
    item_link( item, 1 ),
    text( "Rolling ends in 8 seconds.", 11 ),
    buttons( "Cancel" )
  )

  -- When
  loot_facade.notify( "LootClosed" )

  -- Then
  rf.rolling_popup.should_display(
    item_link( item, 1 ),
    text( "Rolling ends in 8 seconds.", 11 ),
    buttons( "Cancel" )
  )

  -- When
  loot_facade.notify( "LootOpened", item2, item3 )

  -- Then
  rf.loot_frame.should_display(
    enabled_item( 1, "Hearthstone" ),
    enabled_item( 2, "Sword" )
  )

  -- When
  rf.loot_frame.click( 1 )

  -- Then
  chat.console( "RollFor: Cannot select item while rolling is in progress." )
  rf.rolling_popup.should_display(
    item_link( item, 1 ),
    text( "Rolling ends in 8 seconds.", 11 ),
    buttons( "Cancel" )
  )
  rf.loot_frame.should_display(
    enabled_item( 1, "Hearthstone" ),
    enabled_item( 2, "Sword" )
  )

  -- When
  loot_facade.notify( "LootClosed" )
  loot_facade.notify( "LootOpened", item )

  -- Then
  rf.loot_frame.should_display(
    selected_item( 1, "Bag" )
  )
  rf.rolling_popup.should_display(
    item_link( item, 1 ),
    text( "Rolling ends in 8 seconds.", 11 ),
    buttons( "Cancel" )
  )
end

os.exit( lu.LuaUnit.run() )
