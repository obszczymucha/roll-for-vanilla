package.path = "./?.lua;" .. package.path .. ";../?.lua;../RollFor/?.lua"

require( "src/bcc/compat" )
local u = require( "test/utils" )
local lu = u.luaunit()
local builder = require( "test/IntegrationTestBuilder" )
local mock_loot_facade, mock_chat, new_roll_for = builder.mock_loot_facade, builder.mock_chat, builder.new_roll_for
local i, p = builder.i, builder.p
local gui = require( "test/gui_helpers" )
local item_link, text, buttons, empty_line = gui.item_link, gui.text, gui.buttons, gui.empty_line
local enabled_item, disabled_item, selected_item = gui.enabled_item, gui.disabled_item, gui.selected_item
local mainspec_roll, offspec_roll, roll_placeholder = gui.mainspec_roll, gui.offspec_roll, gui.roll_placeholder
local individual_award_button = gui.individual_award_button

NoOneRollsSpec = {}

function NoOneRollsSpec:should_display_roll_button_that_rolls()
  -- Given
  local loot_facade, chat = mock_loot_facade(), mock_chat()
  local item, item2, p1, p2 = i( "Hearthstone", 123 ), i( "Bag", 69 ), p( "Psikutas" ), p( "Obszczymucha" )
  local rf = new_roll_for()
      :loot_facade( loot_facade )
      :raid_roster( p1, p2 )
      :chat( chat )
      :build()
  u.mock( "GiveMasterLoot", function( slot ) loot_facade.notify( "LootSlotCleared", slot ) end )

  -- Then
  rf.loot_frame.should_be_hidden()

  -- When
  loot_facade.notify( "LootOpened", item, item2 )

  -- Then
  rf.loot_frame.should_display(
    enabled_item( 1, "Bag" ),
    enabled_item( 2, "Hearthstone" )
  )
  chat.raid( "Princess Kenny dropped 2 items:" )
  chat.raid( "1. [Bag]" )
  chat.raid( "2. [Hearthstone]" )
  rf.rolling_popup.should_be_hidden()

  -- When
  rf.loot_frame.click( 1 )

  -- Then
  rf.loot_frame.should_display(
    selected_item( 1, "Bag" ),
    disabled_item( 2, "Hearthstone" )
  )
  rf.rolling_popup.should_display(
    item_link( item2, 1 ),
    buttons( "Roll", "InstaRaidRoll", "AwardOther", "Close" )
  )

  -- When
  rf.rolling_popup.click( "Roll" )

  -- Then
  chat.raid_warning( "Roll for [Bag]: /roll (MS) or /roll 99 (OS) or /roll 98 (TMOG)" )
  rf.rolling_popup.should_display(
    item_link( item2, 1 ),
    text( "Rolling ends in 8 seconds.", 11 ),
    buttons( "Cancel" )
  )

  -- When
  rf.ace_timer.repeating_tick()

  -- Then
  rf.rolling_popup.should_display(
    item_link( item2, 1 ),
    text( "Rolling ends in 7 seconds.", 11 ),
    buttons( "Cancel" )
  )

  -- When
  rf.ace_timer.repeating_tick( 4 )

  -- Then
  rf.rolling_popup.should_display(
    item_link( item2, 1 ),
    text( "Rolling ends in 3 seconds.", 11 ),
    buttons( "Cancel" )
  )
  chat.raid( "Stopping rolls in 3" )

  -- When
  rf.ace_timer.repeating_tick()

  -- Then
  rf.rolling_popup.should_display(
    item_link( item2, 1 ),
    text( "Rolling ends in 2 seconds.", 11 ),
    buttons( "Cancel" )
  )
  chat.raid( "2" )

  -- When
  rf.ace_timer.repeating_tick()

  -- Then
  rf.rolling_popup.should_display(
    item_link( item2, 1 ),
    text( "Rolling ends in 1 second.", 11 ),
    buttons( "Cancel" )
  )
  chat.raid( "1" )

  -- When
  rf.ace_timer.repeating_tick()

  -- Then
  chat.console( "RollFor: No one rolled for [Bag]." )
  chat.raid( "No one rolled for [Bag]." )
  chat.console( "RollFor: Rolling for [Bag] finished." )
  rf.rolling_popup.should_display(
    item_link( item2, 1 ),
    text( "Rolling finished. No one rolled.", 11 ),
    buttons( "RaidRoll", "AwardOther", "Close" )
  )
end

function NoOneRollsSpec:should_display_cancel_button_that_cancels()
  -- Given
  local loot_facade, chat = mock_loot_facade(), mock_chat()
  local item, item2, p1, p2 = i( "Hearthstone", 123 ), i( "Bag", 69 ), p( "Psikutas" ), p( "Obszczymucha" )
  local rf = new_roll_for()
      :loot_facade( loot_facade )
      :raid_roster( p1, p2 )
      :chat( chat )
      :build()
  u.mock( "GiveMasterLoot", function( slot ) loot_facade.notify( "LootSlotCleared", slot ) end )

  -- Then
  rf.loot_frame.should_be_hidden()

  -- When
  loot_facade.notify( "LootOpened", item, item2 )

  -- Then
  rf.loot_frame.should_display(
    enabled_item( 1, "Bag" ),
    enabled_item( 2, "Hearthstone" )
  )
  chat.raid( "Princess Kenny dropped 2 items:" )
  chat.raid( "1. [Bag]" )
  chat.raid( "2. [Hearthstone]" )
  rf.rolling_popup.should_be_hidden()

  -- When
  rf.loot_frame.click( 1 )

  -- Then
  rf.loot_frame.should_display(
    selected_item( 1, "Bag" ),
    disabled_item( 2, "Hearthstone" )
  )
  rf.rolling_popup.should_display(
    item_link( item2, 1 ),
    buttons( "Roll", "InstaRaidRoll", "AwardOther", "Close" )
  )

  -- When
  rf.rolling_popup.click( "Roll" )

  -- Then
  chat.raid_warning( "Roll for [Bag]: /roll (MS) or /roll 99 (OS) or /roll 98 (TMOG)" )
  rf.rolling_popup.should_display(
    item_link( item2, 1 ),
    text( "Rolling ends in 8 seconds.", 11 ),
    buttons( "Cancel" )
  )

  -- When
  rf.ace_timer.repeating_tick()

  -- Then
  rf.rolling_popup.should_display(
    item_link( item2, 1 ),
    text( "Rolling ends in 7 seconds.", 11 ),
    buttons( "Cancel" )
  )

  -- When
  rf.ace_timer.repeating_tick( 4 )

  -- Then
  rf.rolling_popup.should_display(
    item_link( item2, 1 ),
    text( "Rolling ends in 3 seconds.", 11 ),
    buttons( "Cancel" )
  )
  chat.raid( "Stopping rolls in 3" )

  -- When
  rf.ace_timer.repeating_tick()

  -- Then
  rf.rolling_popup.should_display(
    item_link( item2, 1 ),
    text( "Rolling ends in 2 seconds.", 11 ),
    buttons( "Cancel" )
  )
  chat.raid( "2" )

  -- When
  rf.rolling_popup.click( "Cancel" )

  -- Then
  chat.console( "RollFor: Rolling for [Bag] was canceled." )
  chat.raid( "Rolling for [Bag] was canceled." )
  rf.rolling_popup.should_display(
    item_link( item2, 1 ),
    text( "Rolling was canceled.", 11 ),
    buttons( "Close" )
  )

  -- When
  rf.rolling_popup.click( "Close" )

  -- Then
  rf.rolling_popup.should_display(
    item_link( item2, 1 ),
    buttons( "Roll", "InstaRaidRoll", "AwardOther", "Close" )
  )
end

function NoOneRollsSpec:should_display_finish_early_button_that_finishes_early()
  -- Given
  local loot_facade, chat = mock_loot_facade(), mock_chat()
  local item, item2, p1, p2 = i( "Hearthstone", 123 ), i( "Bag", 69 ), p( "Psikutas" ), p( "Obszczymucha" )
  local rf = new_roll_for()
      :loot_facade( loot_facade )
      :raid_roster( p1, p2 )
      :chat( chat )
      :build()
  u.mock( "GiveMasterLoot", function( slot ) loot_facade.notify( "LootSlotCleared", slot ) end )

  -- Then
  rf.loot_frame.should_be_hidden()

  -- When
  loot_facade.notify( "LootOpened", item, item2 )

  -- Then
  rf.loot_frame.should_display(
    enabled_item( 1, "Bag" ),
    enabled_item( 2, "Hearthstone" )
  )
  chat.raid( "Princess Kenny dropped 2 items:" )
  chat.raid( "1. [Bag]" )
  chat.raid( "2. [Hearthstone]" )
  rf.rolling_popup.should_be_hidden()

  -- When
  rf.loot_frame.click( 1 )

  -- Then
  rf.loot_frame.should_display(
    selected_item( 1, "Bag" ),
    disabled_item( 2, "Hearthstone" )
  )
  rf.rolling_popup.should_display(
    item_link( item2, 1 ),
    buttons( "Roll", "InstaRaidRoll", "AwardOther", "Close" )
  )

  -- When
  rf.rolling_popup.click( "Roll" )

  -- Then
  chat.raid_warning( "Roll for [Bag]: /roll (MS) or /roll 99 (OS) or /roll 98 (TMOG)" )
  rf.rolling_popup.should_display(
    item_link( item2, 1 ),
    text( "Rolling ends in 8 seconds.", 11 ),
    buttons( "Cancel" )
  )

  -- When
  rf.ace_timer.repeating_tick()

  -- Then
  rf.rolling_popup.should_display(
    item_link( item2, 1 ),
    text( "Rolling ends in 7 seconds.", 11 ),
    buttons( "Cancel" )
  )

  -- When
  rf.ace_timer.repeating_tick( 4 )

  -- Then
  rf.rolling_popup.should_display(
    item_link( item2, 1 ),
    text( "Rolling ends in 3 seconds.", 11 ),
    buttons( "Cancel" )
  )
  chat.raid( "Stopping rolls in 3" )

  -- When
  rf.roll( p2, 96, 1, 99 )
  rf.ace_timer.repeating_tick()

  -- Then
  rf.rolling_popup.should_display(
    item_link( item2, 1 ),
    offspec_roll( p2, 96, 11 ),
    text( "Rolling ends in 2 seconds.", 11 ),
    buttons( "FinishEarly", "Cancel" )
  )
  chat.raid( "2" )

  -- When
  rf.rolling_popup.click( "FinishEarly" )

  -- Then
  chat.console( "RollFor: Obszczymucha rolled the highest (96) for [Bag] (OS)." )
  chat.raid( "Obszczymucha rolled the highest (96) for [Bag] (OS)." )
  chat.console( "RollFor: Rolling for [Bag] finished." )
  rf.rolling_popup.should_display(
    item_link( item2, 1 ),
    offspec_roll( p2, 96, 11 ),
    text( "Obszczymucha wins the off-spec roll with 96.", 11 ),
    buttons( "AwardWinner", "RaidRoll", "AwardOther", "Close" )
  )
end

function NoOneRollsSpec:should_not_display_finish_early_button_if_no_one_rolled()
  -- Given
  local loot_facade, chat = mock_loot_facade(), mock_chat()
  local item, item2, p1, p2 = i( "Hearthstone", 123 ), i( "Bag", 69 ), p( "Psikutas" ), p( "Obszczymucha" )
  local rf = new_roll_for()
      :loot_facade( loot_facade )
      :raid_roster( p1, p2 )
      :chat( chat )
      :build()
  u.mock( "GiveMasterLoot", function( slot ) loot_facade.notify( "LootSlotCleared", slot ) end )

  -- Then
  rf.loot_frame.should_be_hidden()

  -- When
  loot_facade.notify( "LootOpened", item, item2 )

  -- Then
  rf.loot_frame.should_display(
    enabled_item( 1, "Bag" ),
    enabled_item( 2, "Hearthstone" )
  )
  chat.raid( "Princess Kenny dropped 2 items:" )
  chat.raid( "1. [Bag]" )
  chat.raid( "2. [Hearthstone]" )
  rf.rolling_popup.should_be_hidden()

  -- When
  rf.loot_frame.click( 1 )

  -- Then
  rf.loot_frame.should_display(
    selected_item( 1, "Bag" ),
    disabled_item( 2, "Hearthstone" )
  )
  rf.rolling_popup.should_display(
    item_link( item2, 1 ),
    buttons( "Roll", "InstaRaidRoll", "AwardOther", "Close" )
  )

  -- When
  rf.rolling_popup.click( "Roll" )

  -- Then
  chat.raid_warning( "Roll for [Bag]: /roll (MS) or /roll 99 (OS) or /roll 98 (TMOG)" )
  rf.rolling_popup.should_display(
    item_link( item2, 1 ),
    text( "Rolling ends in 8 seconds.", 11 ),
    buttons( "Cancel" )
  )

  -- When
  rf.ace_timer.repeating_tick()

  -- Then
  rf.rolling_popup.should_display(
    item_link( item2, 1 ),
    text( "Rolling ends in 7 seconds.", 11 ),
    buttons( "Cancel" )
  )

  -- When
  rf.ace_timer.repeating_tick( 4 )

  -- Then
  rf.rolling_popup.should_display(
    item_link( item2, 1 ),
    text( "Rolling ends in 3 seconds.", 11 ),
    buttons( "Cancel" )
  )
  chat.raid( "Stopping rolls in 3" )

  -- When
  rf.ace_timer.repeating_tick( 3 )

  -- Then
  chat.raid( "2" )
  chat.raid( "1" )
  chat.console( "RollFor: No one rolled for [Bag]." )
  chat.raid( "No one rolled for [Bag]." )
  rf.rolling_popup.should_display(
    item_link( item2, 1 ),
    text( "Rolling finished. No one rolled.", 11 ),
    buttons( "RaidRoll", "AwardOther", "Close" )
  )
end

function NoOneRollsSpec:should_display_close_button_that_closes_the_popup()
  -- Given
  local loot_facade, chat = mock_loot_facade(), mock_chat()
  local item, item2, p1, p2 = i( "Hearthstone", 123 ), i( "Bag", 69 ), p( "Psikutas" ), p( "Obszczymucha" )
  local rf = new_roll_for()
      :loot_facade( loot_facade )
      :raid_roster( p1, p2 )
      :chat( chat )
      :build()
  u.mock( "GiveMasterLoot", function( slot ) loot_facade.notify( "LootSlotCleared", slot ) end )

  -- Then
  rf.loot_frame.should_be_hidden()

  -- When
  loot_facade.notify( "LootOpened", item, item2 )

  -- Then
  rf.loot_frame.should_display(
    enabled_item( 1, "Bag" ),
    enabled_item( 2, "Hearthstone" )
  )
  chat.raid( "Princess Kenny dropped 2 items:" )
  chat.raid( "1. [Bag]" )
  chat.raid( "2. [Hearthstone]" )
  rf.rolling_popup.should_be_hidden()

  -- When
  rf.loot_frame.click( 1 )

  -- Then
  rf.loot_frame.should_display(
    selected_item( 1, "Bag" ),
    disabled_item( 2, "Hearthstone" )
  )
  rf.rolling_popup.should_display(
    item_link( item2, 1 ),
    buttons( "Roll", "InstaRaidRoll", "AwardOther", "Close" )
  )

  -- When
  rf.rolling_popup.click( "Roll" )

  -- Then
  chat.raid_warning( "Roll for [Bag]: /roll (MS) or /roll 99 (OS) or /roll 98 (TMOG)" )
  rf.rolling_popup.should_display(
    item_link( item2, 1 ),
    text( "Rolling ends in 8 seconds.", 11 ),
    buttons( "Cancel" )
  )

  -- When
  rf.ace_timer.repeating_tick()

  -- Then
  rf.rolling_popup.should_display(
    item_link( item2, 1 ),
    text( "Rolling ends in 7 seconds.", 11 ),
    buttons( "Cancel" )
  )

  -- When
  rf.ace_timer.repeating_tick( 4 )

  -- Then
  rf.rolling_popup.should_display(
    item_link( item2, 1 ),
    text( "Rolling ends in 3 seconds.", 11 ),
    buttons( "Cancel" )
  )
  chat.raid( "Stopping rolls in 3" )

  -- When
  rf.ace_timer.repeating_tick()

  -- Then
  rf.rolling_popup.should_display(
    item_link( item2, 1 ),
    text( "Rolling ends in 2 seconds.", 11 ),
    buttons( "Cancel" )
  )
  chat.raid( "2" )

  -- When
  rf.ace_timer.repeating_tick()

  -- Then
  rf.rolling_popup.should_display(
    item_link( item2, 1 ),
    text( "Rolling ends in 1 second.", 11 ),
    buttons( "Cancel" )
  )
  chat.raid( "1" )

  -- When
  rf.ace_timer.repeating_tick()

  -- Then
  chat.console( "RollFor: No one rolled for [Bag]." )
  chat.raid( "No one rolled for [Bag]." )
  chat.console( "RollFor: Rolling for [Bag] finished." )
  rf.rolling_popup.should_display(
    item_link( item2, 1 ),
    text( "Rolling finished. No one rolled.", 11 ),
    buttons( "RaidRoll", "AwardOther", "Close" )
  )

  -- When
  rf.rolling_popup.click( "Close" )

  -- Then
  rf.rolling_popup.should_be_hidden()
  rf.loot_frame.should_display(
    enabled_item( 1, "Bag" ),
    enabled_item( 2, "Hearthstone" )
  )

  -- When
  loot_facade.notify( "LootClosed" )
  loot_facade.notify( "LootOpened", item, item2 )

  -- Then
  rf.loot_frame.should_display(
    enabled_item( 1, "Bag" ),
    enabled_item( 2, "Hearthstone" )
  )

  -- When
  rf.loot_frame.click( 2 )

  -- Then
  rf.loot_frame.should_display(
    disabled_item( 1, "Bag" ),
    selected_item( 2, "Hearthstone" )
  )
  rf.rolling_popup.should_display(
    item_link( item, 1 ),
    buttons( "Roll", "InstaRaidRoll", "AwardOther", "Close" )
  )
end

function NoOneRollsSpec:should_auto_raid_roll_when_enabled_and_there_are_no_winners()
  -- Given
  local loot_facade, chat = mock_loot_facade(), mock_chat()
  local item, item2, p1, p2 = i( "Hearthstone", 123 ), i( "Bag", 69 ), p( "Psikutas" ), p( "Obszczymucha" )
  local rf = new_roll_for()
      :loot_facade( loot_facade )
      :raid_roster( p1, p2 )
      :chat( chat )
      :config( { auto_raid_roll = true } )
      :build()
  u.mock( "GiveMasterLoot", function( slot ) loot_facade.notify( "LootSlotCleared", slot ) end )

  -- Then
  rf.loot_frame.should_be_hidden()

  -- When
  loot_facade.notify( "LootOpened", item, item2 )

  -- Then
  rf.loot_frame.should_display(
    enabled_item( 1, "Bag" ),
    enabled_item( 2, "Hearthstone" )
  )
  chat.raid( "Princess Kenny dropped 2 items:" )
  chat.raid( "1. [Bag]" )
  chat.raid( "2. [Hearthstone]" )
  rf.rolling_popup.should_be_hidden()

  -- When
  rf.loot_frame.click( 1 )

  -- Then
  rf.loot_frame.should_display(
    selected_item( 1, "Bag" ),
    disabled_item( 2, "Hearthstone" )
  )
  rf.rolling_popup.should_display(
    item_link( item2, 1 ),
    buttons( "Roll", "InstaRaidRoll", "AwardOther", "Close" )
  )

  -- When
  rf.rolling_popup.click( "Roll" )

  -- Then
  chat.raid_warning( "Roll for [Bag]: /roll (MS) or /roll 99 (OS) or /roll 98 (TMOG)" )
  rf.rolling_popup.should_display(
    item_link( item2, 1 ),
    text( "Rolling ends in 8 seconds.", 11 ),
    buttons( "Cancel" )
  )

  -- When
  rf.ace_timer.repeating_tick()

  -- Then
  rf.rolling_popup.should_display(
    item_link( item2, 1 ),
    text( "Rolling ends in 7 seconds.", 11 ),
    buttons( "Cancel" )
  )

  -- When
  rf.ace_timer.repeating_tick( 4 )

  -- Then
  rf.rolling_popup.should_display(
    item_link( item2, 1 ),
    text( "Rolling ends in 3 seconds.", 11 ),
    buttons( "Cancel" )
  )
  chat.raid( "Stopping rolls in 3" )

  -- When
  rf.ace_timer.repeating_tick()

  -- Then
  rf.rolling_popup.should_display(
    item_link( item2, 1 ),
    text( "Rolling ends in 2 seconds.", 11 ),
    buttons( "Cancel" )
  )
  chat.raid( "2" )

  -- When
  rf.ace_timer.repeating_tick()

  -- Then
  rf.rolling_popup.should_display(
    item_link( item2, 1 ),
    text( "Rolling ends in 1 second.", 11 ),
    buttons( "Cancel" )
  )
  chat.raid( "1" )

  -- When
  rf.ace_timer.repeating_tick()

  -- Then
  chat.console( "RollFor: No one rolled for [Bag]." )
  chat.raid( "No one rolled for [Bag]." )
  chat.raid( "Raid rolling [Bag]..." )
end

function NoOneRollsSpec:should_display_raid_roll_button_that_raid_rolls()
  -- Given
  local loot_facade, chat = mock_loot_facade(), mock_chat()
  local item, item2, p1, p2 = i( "Hearthstone", 123 ), i( "Bag", 69 ), p( "Psikutas" ), p( "Obszczymucha" )
  local rf = new_roll_for()
      :loot_facade( loot_facade )
      :raid_roster( p1, p2 )
      :chat( chat )
      :build()
  u.mock( "GiveMasterLoot", function( slot ) loot_facade.notify( "LootSlotCleared", slot ) end )

  -- Then
  rf.loot_frame.should_be_hidden()

  -- When
  loot_facade.notify( "LootOpened", item, item2 )

  -- Then
  rf.loot_frame.should_display(
    enabled_item( 1, "Bag" ),
    enabled_item( 2, "Hearthstone" )
  )
  chat.raid( "Princess Kenny dropped 2 items:" )
  chat.raid( "1. [Bag]" )
  chat.raid( "2. [Hearthstone]" )
  rf.rolling_popup.should_be_hidden()

  -- When
  rf.loot_frame.click( 1 )

  -- Then
  rf.loot_frame.should_display(
    selected_item( 1, "Bag" ),
    disabled_item( 2, "Hearthstone" )
  )
  rf.rolling_popup.should_display(
    item_link( item2, 1 ),
    buttons( "Roll", "InstaRaidRoll", "AwardOther", "Close" )
  )

  -- When
  rf.rolling_popup.click( "Roll" )

  -- Then
  chat.raid_warning( "Roll for [Bag]: /roll (MS) or /roll 99 (OS) or /roll 98 (TMOG)" )
  rf.rolling_popup.should_display(
    item_link( item2, 1 ),
    text( "Rolling ends in 8 seconds.", 11 ),
    buttons( "Cancel" )
  )

  -- When
  rf.ace_timer.repeating_tick()

  -- Then
  rf.rolling_popup.should_display(
    item_link( item2, 1 ),
    text( "Rolling ends in 7 seconds.", 11 ),
    buttons( "Cancel" )
  )

  -- When
  rf.ace_timer.repeating_tick( 4 )

  -- Then
  rf.rolling_popup.should_display(
    item_link( item2, 1 ),
    text( "Rolling ends in 3 seconds.", 11 ),
    buttons( "Cancel" )
  )
  chat.raid( "Stopping rolls in 3" )

  -- When
  rf.ace_timer.repeating_tick()

  -- Then
  rf.rolling_popup.should_display(
    item_link( item2, 1 ),
    text( "Rolling ends in 2 seconds.", 11 ),
    buttons( "Cancel" )
  )
  chat.raid( "2" )

  -- When
  rf.ace_timer.repeating_tick()

  -- Then
  rf.rolling_popup.should_display(
    item_link( item2, 1 ),
    text( "Rolling ends in 1 second.", 11 ),
    buttons( "Cancel" )
  )
  chat.raid( "1" )

  -- When
  rf.ace_timer.repeating_tick()

  -- Then
  chat.console( "RollFor: No one rolled for [Bag]." )
  chat.raid( "No one rolled for [Bag]." )
  chat.console( "RollFor: Rolling for [Bag] finished." )
  rf.rolling_popup.should_display(
    item_link( item2, 1 ),
    text( "Rolling finished. No one rolled.", 11 ),
    buttons( "RaidRoll", "AwardOther", "Close" )
  )

  -- When
  rf.rolling_popup.click( "RaidRoll" )

  -- Then
  chat.raid( "Raid rolling [Bag]..." )
end

SomeoneRolledSpec = {}

function SomeoneRolledSpec:should_display_roll_button_that_rolls()
  -- Given
  local loot_facade, chat = mock_loot_facade(), mock_chat()
  local item, item2, p1, p2 = i( "Hearthstone", 123 ), i( "Bag", 69 ), p( "Psikutas" ), p( "Obszczymucha" )
  local rf = new_roll_for()
      :loot_facade( loot_facade )
      :raid_roster( p1, p2 )
      :chat( chat )
      :build()
  u.mock( "GiveMasterLoot", function( slot ) loot_facade.notify( "LootSlotCleared", slot ) end )

  -- Then
  rf.loot_frame.should_be_hidden()

  -- When
  loot_facade.notify( "LootOpened", item, item2 )

  -- Then
  rf.loot_frame.should_display(
    enabled_item( 1, "Bag" ),
    enabled_item( 2, "Hearthstone" )
  )
  chat.raid( "Princess Kenny dropped 2 items:" )
  chat.raid( "1. [Bag]" )
  chat.raid( "2. [Hearthstone]" )
  rf.rolling_popup.should_be_hidden()

  -- When
  rf.loot_frame.click( 1 )

  -- Then
  rf.loot_frame.should_display(
    selected_item( 1, "Bag" ),
    disabled_item( 2, "Hearthstone" )
  )
  rf.rolling_popup.should_display(
    item_link( item2, 1 ),
    buttons( "Roll", "InstaRaidRoll", "AwardOther", "Close" )
  )

  -- When
  rf.rolling_popup.click( "Roll" )

  -- Then
  chat.raid_warning( "Roll for [Bag]: /roll (MS) or /roll 99 (OS) or /roll 98 (TMOG)" )
  rf.rolling_popup.should_display(
    item_link( item2, 1 ),
    text( "Rolling ends in 8 seconds.", 11 ),
    buttons( "Cancel" )
  )

  -- When
  rf.ace_timer.repeating_tick()

  -- Then
  rf.rolling_popup.should_display(
    item_link( item2, 1 ),
    text( "Rolling ends in 7 seconds.", 11 ),
    buttons( "Cancel" )
  )

  -- When
  rf.roll( p2, 96, 1, 99 )

  -- Then
  rf.rolling_popup.should_display(
    item_link( item2, 1 ),
    offspec_roll( p2, 96, 11 ),
    text( "Rolling ends in 7 seconds.", 11 ),
    buttons( "FinishEarly", "Cancel" )
  )

  -- When
  rf.ace_timer.repeating_tick( 4 )

  chat.raid( "Stopping rolls in 3" )

  -- When
  rf.roll( p1, 69, 1, 100 )

  -- Then
  rf.rolling_popup.should_display(
    item_link( item2, 1 ),
    mainspec_roll( p1, 69, 11 ),
    offspec_roll( p2, 96 ),
    text( "Rolling ends in 3 seconds.", 11 ),
    buttons( "FinishEarly", "Cancel" )
  )

  -- When
  rf.ace_timer.repeating_tick()

  -- Then
  rf.rolling_popup.should_display(
    item_link( item2, 1 ),
    mainspec_roll( p1, 69, 11 ),
    offspec_roll( p2, 96 ),
    text( "Rolling ends in 2 seconds.", 11 ),
    buttons( "FinishEarly", "Cancel" )
  )
  chat.raid( "2" )

  -- When
  rf.ace_timer.repeating_tick()

  -- Then
  rf.rolling_popup.should_display(
    item_link( item2, 1 ),
    mainspec_roll( p1, 69, 11 ),
    offspec_roll( p2, 96 ),
    text( "Rolling ends in 1 second.", 11 ),
    buttons( "FinishEarly", "Cancel" )
  )
  chat.raid( "1" )

  -- When
  rf.ace_timer.repeating_tick()

  -- Then
  chat.console( "RollFor: Psikutas rolled the highest (69) for [Bag]." )
  chat.raid( "Psikutas rolled the highest (69) for [Bag]." )
  chat.console( "RollFor: Rolling for [Bag] finished." )
  rf.rolling_popup.should_display(
    item_link( item2, 1 ),
    mainspec_roll( p1, 69, 11 ),
    offspec_roll( p2, 96 ),
    text( "Psikutas wins the main-spec roll with 69.", 11 ),
    buttons( "AwardWinner", "RaidRoll", "AwardOther", "Close" )
  )
  rf.confirmation_popup.should_be_hidden()

  -- When
  rf.rolling_popup.click( "AwardWinner" )

  -- Then
  rf.rolling_popup.should_be_hidden()
  rf.confirmation_popup.should_be_visible()

  -- When
  rf.confirmation_popup.confirm()

  -- Then
  chat.console( "RollFor: Psikutas received [Bag]." )
  rf.confirmation_popup.should_be_hidden()
  rf.rolling_popup.should_be_hidden()
  rf.loot_frame.should_display(
    enabled_item( 1, "Hearthstone" )
  )

  -- When
  rf.loot_frame.click( 1 )

  -- Then
  rf.loot_frame.should_display(
    selected_item( 1, "Hearthstone" )
  )
  rf.rolling_popup.should_display(
    item_link( item, 1 ),
    buttons( "Roll", "InstaRaidRoll", "AwardOther", "Close" )
  )
end

function SomeoneRolledSpec:should_display_roll_button_that_rolls_for_multiple_items()
  -- Given
  local loot_facade, chat = mock_loot_facade(), mock_chat()
  local item, item2, p1, p2, p3 = i( "Hearthstone", 123 ), i( "Bag", 69 ), p( "Psikutas" ), p( "Obszczymucha" ), p( "Johnny" )
  local rf = new_roll_for()
      :loot_facade( loot_facade )
      :raid_roster( p1, p2, p3 )
      :chat( chat )
      :build()
  u.mock( "GiveMasterLoot", function( slot ) loot_facade.notify( "LootSlotCleared", slot ) end )

  -- Then
  rf.loot_frame.should_be_hidden()

  -- When
  loot_facade.notify( "LootOpened", item, item2, item2 )

  -- Then
  rf.loot_frame.should_display(
    enabled_item( 1, "Bag" ),
    enabled_item( 2, "Bag" ),
    enabled_item( 3, "Hearthstone" )
  )
  chat.raid( "Princess Kenny dropped 3 items:" )
  chat.raid( "1. 2x[Bag]" )
  chat.raid( "2. [Hearthstone]" )
  rf.rolling_popup.should_be_hidden()

  -- When
  rf.loot_frame.click( 1 )

  -- Then
  rf.loot_frame.should_display(
    selected_item( 1, "Bag" ),
    selected_item( 2, "Bag" ),
    disabled_item( 3, "Hearthstone" )
  )
  rf.rolling_popup.should_display(
    item_link( item2, 2 ),
    buttons( "Roll", "InstaRaidRoll", "AwardOther", "Close" )
  )

  -- When
  rf.rolling_popup.click( "Roll" )

  -- Then
  chat.raid_warning( "Roll for 2x[Bag]: /roll (MS) or /roll 99 (OS) or /roll 98 (TMOG). 2 top rolls win." )
  rf.rolling_popup.should_display(
    item_link( item2, 2 ),
    text( "Rolling ends in 8 seconds.", 11 ),
    buttons( "Cancel" )
  )

  -- When
  rf.ace_timer.repeating_tick()

  -- Then
  rf.rolling_popup.should_display(
    item_link( item2, 2 ),
    text( "Rolling ends in 7 seconds.", 11 ),
    buttons( "Cancel" )
  )

  -- When
  rf.roll( p2, 96, 1, 99 )

  -- Then
  rf.rolling_popup.should_display(
    item_link( item2, 2 ),
    offspec_roll( p2, 96, 11 ),
    text( "Rolling ends in 7 seconds.", 11 ),
    buttons( "FinishEarly", "Cancel" )
  )

  -- When
  rf.ace_timer.repeating_tick( 4 )

  chat.raid( "Stopping rolls in 3" )

  -- When
  rf.roll( p1, 69, 1, 100 )

  -- Then
  rf.rolling_popup.should_display(
    item_link( item2, 2 ),
    mainspec_roll( p1, 69, 11 ),
    offspec_roll( p2, 96 ),
    text( "Rolling ends in 3 seconds.", 11 ),
    buttons( "FinishEarly", "Cancel" )
  )

  -- When
  rf.ace_timer.repeating_tick()

  -- Then
  rf.rolling_popup.should_display(
    item_link( item2, 2 ),
    mainspec_roll( p1, 69, 11 ),
    offspec_roll( p2, 96 ),
    text( "Rolling ends in 2 seconds.", 11 ),
    buttons( "FinishEarly", "Cancel" )
  )
  chat.raid( "2" )

  -- When
  rf.ace_timer.repeating_tick()

  -- Then
  rf.rolling_popup.should_display(
    item_link( item2, 2 ),
    mainspec_roll( p1, 69, 11 ),
    offspec_roll( p2, 96 ),
    text( "Rolling ends in 1 second.", 11 ),
    buttons( "FinishEarly", "Cancel" )
  )
  chat.raid( "1" )

  -- When
  rf.ace_timer.repeating_tick()

  -- Then
  chat.console( "RollFor: Psikutas rolled the highest (69) for [Bag]." )
  chat.raid( "Psikutas rolled the highest (69) for [Bag]." )
  chat.console( "RollFor: Obszczymucha rolled the next highest (96) for [Bag] (OS)." )
  chat.raid( "Obszczymucha rolled the next highest (96) for [Bag] (OS)." )
  chat.console( "RollFor: Rolling for [Bag] finished." )
  rf.rolling_popup.should_display(
    item_link( item2, 2 ),
    mainspec_roll( p1, 69, 11 ),
    offspec_roll( p2, 96 ),
    text( "Psikutas wins the main-spec roll with 69.", 11 ),
    individual_award_button,
    text( "Obszczymucha wins the off-spec roll with 96.", 8 ),
    individual_award_button,
    buttons( "RaidRoll", "AwardOther", "Close" )
  )
  rf.confirmation_popup.should_be_hidden()

  -- When
  rf.rolling_popup.award( "Obszczymucha" )

  -- Then
  rf.rolling_popup.should_be_hidden()
  rf.confirmation_popup.should_be_visible()

  -- When
  rf.confirmation_popup.confirm()

  -- Then
  rf.confirmation_popup.should_be_hidden()
  chat.console( "RollFor: Obszczymucha received [Bag]." )
  rf.loot_frame.should_display(
    selected_item( 1, "Bag" ),
    disabled_item( 2, "Hearthstone" )
  )
  rf.rolling_popup.should_display(
    item_link( item2, 1 ),
    mainspec_roll( p1, 69, 11 ),
    offspec_roll( p2, 96 ),
    text( "Psikutas wins the main-spec roll with 69.", 11 ),
    buttons( "AwardWinner", "RaidRoll", "AwardOther", "Close" )
  )
  rf.confirmation_popup.should_be_hidden()

  -- When
  rf.rolling_popup.click( "AwardWinner" )

  -- Then
  rf.rolling_popup.should_be_hidden()
  rf.confirmation_popup.should_be_visible()

  -- When
  rf.confirmation_popup.confirm()

  -- Then
  rf.confirmation_popup.should_be_hidden()
  chat.console( "RollFor: Psikutas received [Bag]." )

  -- Then
  rf.rolling_popup.should_be_hidden()
  rf.loot_frame.should_display(
    enabled_item( 1, "Hearthstone" )
  )
end

function SomeoneRolledSpec:should_display_close_button_that_closes_the_popup_and_remember_the_winner()
  -- Given
  local loot_facade, chat = mock_loot_facade(), mock_chat()
  local item, item2, p1, p2 = i( "Hearthstone", 123 ), i( "Bag", 69 ), p( "Psikutas" ), p( "Obszczymucha" )
  local rf = new_roll_for()
      :loot_facade( loot_facade )
      :raid_roster( p1, p2 )
      :chat( chat )
      :build()
  u.mock( "GiveMasterLoot", function( slot ) loot_facade.notify( "LootSlotCleared", slot ) end )

  -- Then
  rf.loot_frame.should_be_hidden()

  -- When
  loot_facade.notify( "LootOpened", item, item2 )

  -- Then
  rf.loot_frame.should_display(
    enabled_item( 1, "Bag" ),
    enabled_item( 2, "Hearthstone" )
  )
  chat.raid( "Princess Kenny dropped 2 items:" )
  chat.raid( "1. [Bag]" )
  chat.raid( "2. [Hearthstone]" )
  rf.rolling_popup.should_be_hidden()

  -- When
  rf.loot_frame.click( 1 )

  -- Then
  rf.loot_frame.should_display(
    selected_item( 1, "Bag" ),
    disabled_item( 2, "Hearthstone" )
  )
  rf.rolling_popup.should_display(
    item_link( item2, 1 ),
    buttons( "Roll", "InstaRaidRoll", "AwardOther", "Close" )
  )

  -- When
  rf.rolling_popup.click( "Roll" )

  -- Then
  chat.raid_warning( "Roll for [Bag]: /roll (MS) or /roll 99 (OS) or /roll 98 (TMOG)" )
  rf.rolling_popup.should_display(
    item_link( item2, 1 ),
    text( "Rolling ends in 8 seconds.", 11 ),
    buttons( "Cancel" )
  )

  -- When
  rf.roll( p1, 69, 1, 99 )

  -- When
  rf.ace_timer.repeating_tick( 8 )

  -- Then
  chat.raid( "Stopping rolls in 3" )
  chat.raid( "2" )
  chat.raid( "1" )
  chat.console( "RollFor: Psikutas rolled the highest (69) for [Bag] (OS)." )
  chat.raid( "Psikutas rolled the highest (69) for [Bag] (OS)." )
  chat.console( "RollFor: Rolling for [Bag] finished." )
  rf.rolling_popup.should_display(
    item_link( item2, 1 ),
    offspec_roll( p1, 69, 11 ),
    text( "Psikutas wins the off-spec roll with 69.", 11 ),
    buttons( "AwardWinner", "RaidRoll", "AwardOther", "Close" )
  )

  -- When
  rf.rolling_popup.click( "Close" )

  -- Then
  rf.rolling_popup.should_be_hidden()
  rf.loot_frame.should_display(
    enabled_item( 1, "Bag" ),
    enabled_item( 2, "Hearthstone" )
  )

  -- When
  loot_facade.notify( "LootClosed" )
  loot_facade.notify( "LootOpened", item, item2 )

  -- Then
  rf.loot_frame.should_display(
    enabled_item( 1, "Bag" ),
    enabled_item( 2, "Hearthstone" )
  )

  -- When
  rf.loot_frame.click( 1 )

  -- Then
  rf.loot_frame.should_display(
    selected_item( 1, "Bag" ),
    disabled_item( 2, "Hearthstone" )
  )
  rf.rolling_popup.should_display(
    item_link( item2, 1 ),
    offspec_roll( p1, 69, 11 ),
    text( "Psikutas wins the off-spec roll with 69.", 11 ),
    buttons( "AwardWinner", "RaidRoll", "AwardOther", "Close" )
  )
end

NormalTieRollSpec = {}

function NormalTieRollSpec:should_display_tie_rolls()
  -- Given
  local loot_facade, chat = mock_loot_facade(), mock_chat()
  local item, item2, p1, p2 = i( "Hearthstone", 123 ), i( "Bag", 69 ), p( "Psikutas" ), p( "Obszczymucha" )
  local rf = new_roll_for()
      :loot_facade( loot_facade )
      :raid_roster( p1, p2 )
      :chat( chat )
      :build()
  u.mock( "GiveMasterLoot", function( slot ) loot_facade.notify( "LootSlotCleared", slot ) end )

  -- Then
  rf.loot_frame.should_be_hidden()

  -- When
  loot_facade.notify( "LootOpened", item, item2 )

  -- Then
  rf.loot_frame.should_display(
    enabled_item( 1, "Bag" ),
    enabled_item( 2, "Hearthstone" )
  )
  chat.raid( "Princess Kenny dropped 2 items:" )
  chat.raid( "1. [Bag]" )
  chat.raid( "2. [Hearthstone]" )
  rf.rolling_popup.should_be_hidden()

  -- When
  rf.loot_frame.click( 1 )

  -- Then
  rf.loot_frame.should_display(
    selected_item( 1, "Bag" ),
    disabled_item( 2, "Hearthstone" )
  )
  rf.rolling_popup.should_display(
    item_link( item2, 1 ),
    buttons( "Roll", "InstaRaidRoll", "AwardOther", "Close" )
  )

  -- When
  rf.rolling_popup.click( "Roll" )

  -- Then
  chat.raid_warning( "Roll for [Bag]: /roll (MS) or /roll 99 (OS) or /roll 98 (TMOG)" )
  rf.rolling_popup.should_display(
    item_link( item2, 1 ),
    text( "Rolling ends in 8 seconds.", 11 ),
    buttons( "Cancel" )
  )

  -- When
  rf.roll( p2, 69, 1, 100 )
  rf.roll( p1, 69, 1, 100 )

  -- Then
  chat.console( "RollFor: Obszczymucha and Psikutas rolled the highest (69) for [Bag]." )
  chat.raid( "Obszczymucha and Psikutas rolled the highest (69) for [Bag]." )
  rf.rolling_popup.should_display(
    item_link( item2, 1 ),
    mainspec_roll( p2, 69, 11 ),
    mainspec_roll( p1, 69 ),
    text( "There was a tie (69):", 11 ),
    roll_placeholder( p2, "MainSpec", 11 ),
    roll_placeholder( p1, "MainSpec" ),
    empty_line( 5 )
  )

  -- When
  rf.ace_timer.tick()

  -- Then
  chat.raid( "Obszczymucha and Psikutas /roll for [Bag] now." )
  rf.rolling_popup.should_display(
    item_link( item2, 1 ),
    mainspec_roll( p2, 69, 11 ),
    mainspec_roll( p1, 69 ),
    text( "There was a tie (69):", 11 ),
    roll_placeholder( p2, "MainSpec", 11 ),
    roll_placeholder( p1, "MainSpec" ),
    text( "Waiting for remaining rolls...", 11 ),
    buttons( "FinishEarly", "Cancel" )
  )

  -- When
  rf.roll( p2, 42, 1, 100 )
  rf.roll( p1, 42, 1, 100 )

  -- Then
  chat.console( "RollFor: Obszczymucha and Psikutas re-rolled the highest (42) for [Bag]." )
  chat.raid( "Obszczymucha and Psikutas re-rolled the highest (42) for [Bag]." )
  rf.rolling_popup.should_display(
    item_link( item2, 1 ),
    mainspec_roll( p2, 69, 11 ),
    mainspec_roll( p1, 69 ),
    text( "There was a tie (69):", 11 ),
    mainspec_roll( p2, 42, 11 ),
    mainspec_roll( p1, 42 ),
    text( "There was a tie (42):", 11 ),
    roll_placeholder( p2, "MainSpec", 11 ),
    roll_placeholder( p1, "MainSpec" ),
    empty_line( 5 )
  )

  -- When
  rf.ace_timer.tick()

  -- Then
  chat.raid( "Obszczymucha and Psikutas /roll for [Bag] now." )
  rf.rolling_popup.should_display(
    item_link( item2, 1 ),
    mainspec_roll( p2, 69, 11 ),
    mainspec_roll( p1, 69 ),
    text( "There was a tie (69):", 11 ),
    mainspec_roll( p2, 42, 11 ),
    mainspec_roll( p1, 42 ),
    text( "There was a tie (42):", 11 ),
    roll_placeholder( p2, "MainSpec", 11 ),
    roll_placeholder( p1, "MainSpec" ),
    text( "Waiting for remaining rolls...", 11 ),
    buttons( "FinishEarly", "Cancel" )
  )

  -- When
  rf.roll( p2, 1, 1, 100 )

  -- Then
  rf.rolling_popup.should_display(
    item_link( item2, 1 ),
    mainspec_roll( p2, 69, 11 ),
    mainspec_roll( p1, 69 ),
    text( "There was a tie (69):", 11 ),
    mainspec_roll( p2, 42, 11 ),
    mainspec_roll( p1, 42 ),
    text( "There was a tie (42):", 11 ),
    mainspec_roll( p2, 1, 11 ),
    roll_placeholder( p1, "MainSpec" ),
    text( "Waiting for remaining rolls...", 11 ),
    buttons( "FinishEarly", "Cancel" )
  )

  rf.roll( p1, 2, 1, 100 )

  -- Then
  chat.console( "RollFor: Psikutas re-rolled the highest (2) for [Bag]." )
  chat.raid( "Psikutas re-rolled the highest (2) for [Bag]." )
  chat.console( "RollFor: Rolling for [Bag] finished." )
  rf.rolling_popup.should_display(
    item_link( item2, 1 ),
    mainspec_roll( p2, 69, 11 ),
    mainspec_roll( p1, 69 ),
    text( "There was a tie (69):", 11 ),
    mainspec_roll( p2, 42, 11 ),
    mainspec_roll( p1, 42 ),
    text( "There was a tie (42):", 11 ),
    mainspec_roll( p1, 2, 11 ),
    mainspec_roll( p2, 1 ),
    buttons( "AwardWinner", "RaidRoll", "AwardOther", "Close" )
  )
  rf.confirmation_popup.should_be_hidden()

  -- When
  rf.rolling_popup.click( "AwardWinner" )

  -- Then
  rf.confirmation_popup.should_be_visible()
  rf.rolling_popup.should_be_hidden()

  -- When
  rf.confirmation_popup.abort()

  -- Then
  rf.confirmation_popup.should_be_hidden()
  rf.rolling_popup.should_display(
    item_link( item2, 1 ),
    mainspec_roll( p2, 69, 11 ),
    mainspec_roll( p1, 69 ),
    text( "There was a tie (69):", 11 ),
    mainspec_roll( p2, 42, 11 ),
    mainspec_roll( p1, 42 ),
    text( "There was a tie (42):", 11 ),
    mainspec_roll( p1, 2, 11 ),
    mainspec_roll( p2, 1 ),
    buttons( "AwardWinner", "RaidRoll", "AwardOther", "Close" )
  )

  -- When
  rf.rolling_popup.click( "AwardWinner" )

  -- Then
  rf.confirmation_popup.should_be_visible()
  rf.rolling_popup.should_be_hidden()

  -- When
  rf.confirmation_popup.confirm()

  -- Then
  rf.confirmation_popup.should_be_hidden()
  chat.console( "RollFor: Psikutas received [Bag]." )
  rf.loot_frame.should_display(
    enabled_item( 1, "Hearthstone" )
  )
end

function NormalTieRollSpec:should_not_consider_ms_and_tm_rolls_tie()
  -- Given
  local loot_facade, chat = mock_loot_facade(), mock_chat()
  local item, item2, p1, p2 = i( "Hearthstone", 123 ), i( "Bag", 69 ), p( "Psikutas" ), p( "Obszczymucha" )
  local rf = new_roll_for()
      :loot_facade( loot_facade )
      :raid_roster( p1, p2 )
      :chat( chat )
      :build()
  u.mock( "GiveMasterLoot", function( slot ) loot_facade.notify( "LootSlotCleared", slot ) end )

  -- Then
  rf.loot_frame.should_be_hidden()

  -- When
  loot_facade.notify( "LootOpened", item, item2 )

  -- Then
  rf.loot_frame.should_display(
    enabled_item( 1, "Bag" ),
    enabled_item( 2, "Hearthstone" )
  )
  chat.raid( "Princess Kenny dropped 2 items:" )
  chat.raid( "1. [Bag]" )
  chat.raid( "2. [Hearthstone]" )
  rf.rolling_popup.should_be_hidden()

  -- When
  rf.loot_frame.click( 1 )

  -- Then
  rf.loot_frame.should_display(
    selected_item( 1, "Bag" ),
    disabled_item( 2, "Hearthstone" )
  )
  rf.rolling_popup.should_display(
    item_link( item2, 1 ),
    buttons( "Roll", "InstaRaidRoll", "AwardOther", "Close" )
  )

  -- When
  rf.rolling_popup.click( "Roll" )

  -- Then
  chat.raid_warning( "Roll for [Bag]: /roll (MS) or /roll 99 (OS) or /roll 98 (TMOG)" )
  rf.rolling_popup.should_display(
    item_link( item2, 1 ),
    text( "Rolling ends in 8 seconds.", 11 ),
    buttons( "Cancel" )
  )

  -- When
  rf.roll( p1, 42, 1, 100 )
  rf.roll( p2, 42, 1, 99 )
  rf.ace_timer.repeating_tick( 7 )

  -- Then
  chat.raid( "Stopping rolls in 3" )
  chat.raid( "2" )
  chat.raid( "1" )

  -- When
  rf.ace_timer.repeating_tick( 1 )

  -- Then
  chat.console( "RollFor: Psikutas rolled the highest (42) for [Bag]." )
  chat.raid( "Psikutas rolled the highest (42) for [Bag]." )
  chat.console( "RollFor: Rolling for [Bag] finished." )
  rf.rolling_popup.should_display(
    item_link( item2, 1 ),
    mainspec_roll( p1, 42, 11 ),
    offspec_roll( p2, 42 ),
    text( "Psikutas wins the main-spec roll with 42.", 11 ),
    buttons( "AwardWinner", "RaidRoll", "AwardOther", "Close" )
  )
  rf.confirmation_popup.should_be_hidden()

  -- When
  rf.rolling_popup.click( "AwardWinner" )

  -- Then
  rf.confirmation_popup.should_be_visible()
  rf.rolling_popup.should_be_hidden()

  -- When
  rf.confirmation_popup.confirm()

  -- Then
  rf.confirmation_popup.should_be_hidden()
  chat.console( "RollFor: Psikutas received [Bag]." )
  rf.loot_frame.should_display(
    enabled_item( 1, "Hearthstone" )
  )
end

function NoOneRollsSpec:should_show_award_button_when_looting_the_corpse_again_if_the_looting_was_closed_during_the_roll()
  -- Given
  local loot_facade, chat = mock_loot_facade(), mock_chat()
  local item, p1, p2 = i( "Essence Gatherer", 123 ), p( "Cosmicshadow" ), p( "Jogobobek" )
  local rf = new_roll_for()
      :loot_facade( loot_facade )
      :raid_roster( p1, p2 )
      :chat( chat )
      :build()
  u.mock( "GiveMasterLoot", function( slot ) loot_facade.notify( "LootSlotCleared", slot ) end )

  -- Then
  rf.loot_frame.should_be_hidden()

  -- When
  loot_facade.notify( "LootOpened", item )

  -- Then
  rf.loot_frame.should_display(
    enabled_item( 1, "Essence Gatherer" )
  )
  chat.raid( "Princess Kenny dropped 1 item:" )
  chat.raid( "1. [Essence Gatherer]" )
  rf.rolling_popup.should_be_hidden()

  -- When
  rf.loot_frame.click( 1 )

  -- Then
  rf.loot_frame.should_display(
    selected_item( 1, "Essence Gatherer" )
  )
  rf.rolling_popup.should_display(
    item_link( item, 1 ),
    buttons( "Roll", "InstaRaidRoll", "AwardOther", "Close" )
  )

  -- When
  rf.rolling_popup.click( "Roll" )

  -- Then
  chat.raid_warning( "Roll for [Essence Gatherer]: /roll (MS) or /roll 99 (OS) or /roll 98 (TMOG)" )
  rf.rolling_popup.should_display(
    item_link( item, 1 ),
    text( "Rolling ends in 8 seconds.", 11 ),
    buttons( "Cancel" )
  )

  -- When
  rf.ace_timer.repeating_tick( 2 )
  loot_facade.notify( "LootClosed" )

  -- Then
  rf.rolling_popup.should_display(
    item_link( item, 1 ),
    text( "Rolling ends in 6 seconds.", 11 ),
    buttons( "Cancel" )
  )

  -- When
  rf.ace_timer.repeating_tick( 4 )
  rf.roll( p1, 24, 1, 100 )

  -- Then
  chat.raid( "Stopping rolls in 3" )
  rf.rolling_popup.should_display(
    item_link( item, 1 ),
    mainspec_roll( p1, 24, 11 ),
    text( "Rolling ends in 2 seconds.", 11 ),
    buttons( "FinishEarly", "Cancel" )
  )

  -- When
  rf.ace_timer.repeating_tick( 2 )

  -- Then
  chat.raid( "2" )
  chat.raid( "1" )
  chat.console( "RollFor: Cosmicshadow rolled the highest (24) for [Essence Gatherer]." )
  chat.raid( "Cosmicshadow rolled the highest (24) for [Essence Gatherer]." )
  chat.console( "RollFor: Rolling for [Essence Gatherer] finished." )
  rf.rolling_popup.should_display(
    item_link( item, 1 ),
    mainspec_roll( p1, 24, 11 ),
    text( "Cosmicshadow wins the main-spec roll with 24.", 11 ),
    buttons( "RaidRoll", "Close" )
  )

  -- When
  loot_facade.notify( "LootOpened", item )

  -- Then
  rf.loot_frame.should_display(
    selected_item( 1, "Essence Gatherer" )
  )
  rf.rolling_popup.should_display(
    item_link( item, 1 ),
    mainspec_roll( p1, 24, 11 ),
    text( "Cosmicshadow wins the main-spec roll with 24.", 11 ),
    buttons( "AwardWinner", "RaidRoll", "AwardOther", "Close" )
  )
end

ClassAnnounceSpec = {}

function ClassAnnounceSpec:should_show_class_on_roll()
  -- Given
  local loot_facade, chat = mock_loot_facade(), mock_chat()
  local item = i( "Hearthstone", 123, nil, nil, nil, nil, { "Mage", "Hunter", "Warrior" } )
  local item2 = i( "Bag", 69, nil, nil, nil, nil, { "Mage" } )
  local item3 = i( "Earthstrike", 21180, nil, nil, nil, nil, { "Hunter", "Priest" } )
  local p1, p2 = p( "Sica" ), p( "Obszczymucha" )
  local rf = new_roll_for()
      :loot_facade( loot_facade )
      :raid_roster( p1, p2 )
      :chat( chat )
      :build()
  u.mock( "GiveMasterLoot", function( slot ) loot_facade.notify( "LootSlotCleared", slot ) end )

  -- Then
  rf.loot_frame.should_be_hidden()

  -- When
  loot_facade.notify( "LootOpened", item, item2, item3 )

  -- Then
  rf.loot_frame.should_display(
    enabled_item( 1, "Bag" ),    
    enabled_item( 2, "Earthstrike" ),
    enabled_item( 3, "Hearthstone" )
  )
  chat.raid( "Princess Kenny dropped 3 items:" )
  chat.raid( "1. [Bag]" )
  chat.raid( "2. [Earthstrike]" )
  chat.raid( "3. [Hearthstone]" )
  rf.rolling_popup.should_be_hidden()

  -- When
  rf.loot_frame.click( 1 )

  -- Then
  rf.loot_frame.should_display(
    selected_item( 1, "Bag" ),
    disabled_item( 2, "Earthstrike" ),
    disabled_item( 3, "Hearthstone" )
  )
  rf.rolling_popup.should_display(
    item_link( item2, 1 ),
    buttons( "Roll", "RaidRoll", "AwardOther", "Close" )
  )

  -- When
  rf.rolling_popup.click( "Roll" )

  -- Then
  chat.raid_warning( "Roll for [Bag]: Mages" )

  -- When
  rf.rolling_popup.click( "Cancel" )

  -- Then
  chat.console( "RollFor: Rolling for [Bag] was canceled." )
  chat.raid( "Rolling for [Bag] was canceled." )

  -- When
  rf.rolling_popup.click( "Close" )
  rf.rolling_popup.click( "Close" )
  rf.loot_frame.click( 2 )

  -- Then
  rf.rolling_popup.should_display(
    item_link( item3, 1 ),
    buttons( "Roll", "RaidRoll", "AwardOther", "Close" )
  )

  -- When
  rf.rolling_popup.click( "Roll" )

  -- Then
  chat.raid_warning( "Roll for [Earthstrike]: Hunters and Priests" )

  -- When
  rf.rolling_popup.click( "Cancel" )

  -- Then
  chat.console( "RollFor: Rolling for [Earthstrike] was canceled." )
  chat.raid( "Rolling for [Earthstrike] was canceled." )

   -- When
  rf.rolling_popup.click( "Close" )
  rf.rolling_popup.click( "Close" )
  rf.loot_frame.click( 3 )

  -- Then
  rf.rolling_popup.should_display(
    item_link( item, 1 ),
    buttons( "Roll", "RaidRoll", "AwardOther", "Close" )
  )

  -- When
  rf.rolling_popup.click( "Roll" )

  -- Then
  chat.raid_warning( "Roll for [Hearthstone]: Mages, Hunters and Warriors" )
end

os.exit( lu.LuaUnit.run() )
