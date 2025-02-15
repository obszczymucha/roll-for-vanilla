package.path = "./?.lua;" .. package.path .. ";../?.lua;../RollFor/?.lua"

require( "src/bcc/compat" )
local u = require( "test/utils" )
local lu = u.luaunit()
local builder = require( "test/IntegrationTestBuilder" )
local mock_loot_facade, mock_chat, new_roll_for = builder.mock_loot_facade, builder.mock_chat, builder.new_roll_for
local i, p = builder.i, builder.p
local gui = require( "test/gui_helpers" )
local item_link, text, buttons = gui.item_link, gui.text, gui.buttons
local enabled_item, disabled_item, selected_item = gui.enabled_item, gui.disabled_item, gui.selected_item
local individual_award_button = gui.individual_award_button
local mock_random = u.mock_multiple_math_random

SingleWinnerInstaRaidRollSpec = {}

function SingleWinnerInstaRaidRollSpec:should_display_insta_raid_roll_button_that_rolls_and_award_the_winner()
  -- Given
  local loot_facade, chat = mock_loot_facade(), mock_chat()
  local item, item2, p1, p2 = i( "Hearthstone", 123 ), i( "Bag", 69 ), p( "Psikutas" ), p( "Obszczymucha" )
  local rf = new_roll_for()
      :loot_facade( loot_facade )
      :raid_roster( p1, p2 )
      :chat( chat )
      :build()
  mock_random( { { 1, 2, 1 } } )
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
  rf.rolling_popup.click( "InstaRaidRoll" )

  -- Then
  chat.raid( "Obszczymucha wins [Bag] (raid-roll)." )
  rf.rolling_popup.should_display(
    item_link( item2, 1 ),
    text( "Obszczymucha wins the raid-roll.", 11 ),
    buttons( "AwardWinner", "RaidRollAgain", "AwardOther", "Close" )
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
  rf.loot_frame.should_display(
    enabled_item( 1, "Hearthstone" )
  )
  chat.console( "RollFor: Obszczymucha received [Bag]." )
end

function SingleWinnerInstaRaidRollSpec:should_display_insta_raid_roll_button_that_rolls_and_award_the_winners()
  -- Given
  local loot_facade, chat = mock_loot_facade(), mock_chat()
  local item, item2, p1, p2 = i( "Hearthstone", 123 ), i( "Bag", 69 ), p( "Psikutas" ), p( "Obszczymucha" )
  local rf = new_roll_for()
      :loot_facade( loot_facade )
      :raid_roster( p1, p2 )
      :chat( chat )
      :build()
  mock_random( { { 1, 2, 1 }, { 1, 2, 2 } } )
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
  rf.rolling_popup.click( "InstaRaidRoll" )

  -- Then
  chat.raid( "Obszczymucha wins [Bag] (raid-roll)." )
  chat.raid( "Psikutas wins [Bag] (raid-roll)." )
  rf.rolling_popup.should_display(
    item_link( item2, 2 ),
    text( "Obszczymucha wins the raid-roll.", 11 ),
    individual_award_button,
    text( "Psikutas wins the raid-roll.", 8 ),
    individual_award_button,
    buttons( "RaidRollAgain", "AwardOther", "Close" )
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
  rf.loot_frame.should_display(
    selected_item( 1, "Bag" ),
    disabled_item( 2, "Hearthstone" )
  )
  chat.console( "RollFor: Obszczymucha received [Bag]." )
  rf.rolling_popup.should_display(
    item_link( item2, 1 ),
    text( "Psikutas wins the raid-roll.", 11 ),
    buttons( "AwardWinner", "RaidRollAgain", "AwardOther", "Close" )
  )

  -- When
  loot_facade.notify( "LootClosed" )
  loot_facade.notify( "LootOpened", item, item2 )

  -- Then
  rf.loot_frame.should_display(
    selected_item( 1, "Bag" ),
    disabled_item( 2, "Hearthstone" )
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
  rf.loot_frame.should_display(
    enabled_item( 1, "Hearthstone" )
  )
  chat.console( "RollFor: Psikutas received [Bag]." )
end

function SingleWinnerInstaRaidRollSpec:should_display_insta_raid_roll_button_that_rolls_and_display_the_same_content_when_awarding_is_aborted()
  -- Given
  local loot_facade, chat = mock_loot_facade(), mock_chat()
  local item, item2, p1, p2 = i( "Hearthstone", 123 ), i( "Bag", 69 ), p( "Psikutas" ), p( "Obszczymucha" )
  local rf = new_roll_for()
      :loot_facade( loot_facade )
      :raid_roster( p1, p2 )
      :chat( chat )
      :build()
  mock_random( { { 1, 2, 1 } } )
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
  rf.rolling_popup.click( "InstaRaidRoll" )

  -- Then
  chat.raid( "Obszczymucha wins [Bag] (raid-roll)." )
  rf.rolling_popup.should_display(
    item_link( item2, 1 ),
    text( "Obszczymucha wins the raid-roll.", 11 ),
    buttons( "AwardWinner", "RaidRollAgain", "AwardOther", "Close" )
  )
  rf.confirmation_popup.should_be_hidden()

  -- When
  rf.rolling_popup.click( "AwardWinner" )

  -- Then
  rf.rolling_popup.should_be_hidden()
  rf.confirmation_popup.should_be_visible()

  -- When
  rf.confirmation_popup.abort()

  -- Then
  rf.confirmation_popup.should_be_hidden()
  rf.loot_frame.should_display(
    selected_item( 1, "Bag" ),
    disabled_item( 2, "Hearthstone" )
  )
  rf.rolling_popup.should_display(
    item_link( item2, 1 ),
    text( "Obszczymucha wins the raid-roll.", 11 ),
    buttons( "AwardWinner", "RaidRollAgain", "AwardOther", "Close" )
  )
end

function SingleWinnerInstaRaidRollSpec:should_display_insta_raid_roll_button_that_rolls_and_award_someone_else()
  -- Given
  local loot_facade, chat = mock_loot_facade(), mock_chat()
  local item, item2, p1, p2 = i( "Hearthstone", 123 ), i( "Bag", 69 ), p( "Psikutas" ), p( "Obszczymucha" )
  local rf = new_roll_for()
      :loot_facade( loot_facade )
      :raid_roster( p1, p2 )
      :chat( chat )
      :build()
  mock_random( { { 1, 2, 1 } } )
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
  rf.rolling_popup.click( "InstaRaidRoll" )

  -- Then
  chat.raid( "Obszczymucha wins [Bag] (raid-roll)." )
  rf.rolling_popup.should_display(
    item_link( item2, 1 ),
    text( "Obszczymucha wins the raid-roll.", 11 ),
    buttons( "AwardWinner", "RaidRollAgain", "AwardOther", "Close" )
  )
  rf.confirmation_popup.should_be_hidden()
  rf.player_selection.should_be_hidden()

  -- When
  rf.rolling_popup.click( "AwardOther" )

  -- Then
  rf.player_selection.should_display( "Obszczymucha", "Psikutas" )
  rf.rolling_popup.should_be_visible()

  -- When
  rf.player_selection.select( "Psikutas" )

  -- Then
  rf.player_selection.should_be_hidden()
  rf.rolling_popup.should_be_hidden()
  rf.confirmation_popup.should_be_visible()

  -- When
  rf.confirmation_popup.confirm()

  -- Then
  rf.confirmation_popup.should_be_hidden()
  rf.loot_frame.should_display(
    enabled_item( 1, "Hearthstone" )
  )
  chat.console( "RollFor: Psikutas received [Bag]." )
end

function SingleWinnerInstaRaidRollSpec:should_remember_the_winner_if_the_popup_is_closed_and_reopened()
  -- Given
  local loot_facade, chat = mock_loot_facade(), mock_chat()
  local item, item2, p1, p2 = i( "Hearthstone", 123 ), i( "Bag", 69 ), p( "Psikutas" ), p( "Obszczymucha" )
  local rf = new_roll_for()
      :loot_facade( loot_facade )
      :raid_roster( p1, p2 )
      :chat( chat )
      :build()
  mock_random( { { 1, 2, 1 } } )
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
  rf.rolling_popup.click( "InstaRaidRoll" )

  -- Then
  chat.raid( "Obszczymucha wins [Bag] (raid-roll)." )
  rf.rolling_popup.should_display(
    item_link( item2, 1 ),
    text( "Obszczymucha wins the raid-roll.", 11 ),
    buttons( "AwardWinner", "RaidRollAgain", "AwardOther", "Close" )
  )
  rf.confirmation_popup.should_be_hidden()

  -- When
  rf.rolling_popup.click( "Close" )

  -- Then
  rf.rolling_popup.should_be_hidden()
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
    text( "Obszczymucha wins the raid-roll.", 11 ),
    buttons( "AwardWinner", "RaidRollAgain", "AwardOther", "Close" )
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

  -- When
  rf.rolling_popup.click( "Close" )

  -- Then
  rf.rolling_popup.should_be_hidden()
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
    text( "Obszczymucha wins the raid-roll.", 11 ),
    buttons( "AwardWinner", "RaidRollAgain", "AwardOther", "Close" )
  )
end

function SingleWinnerInstaRaidRollSpec:should_hide_award_buttons_if_the_loot_is_closed_and_show_them_if_the_same_loot_is_reopened()
  -- Given
  local loot_facade, chat = mock_loot_facade(), mock_chat()
  local item, item2, item3, p1, p2 = i( "Hearthstone", 123 ), i( "Bag", 69 ), i( "Sword", 42 ), p( "Psikutas" ), p( "Obszczymucha" )
  local rf = new_roll_for()
      :loot_facade( loot_facade )
      :raid_roster( p1, p2 )
      :chat( chat )
      :build()
  mock_random( { { 1, 2, 1 } } )
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
  rf.rolling_popup.click( "InstaRaidRoll" )

  -- Then
  chat.raid( "Obszczymucha wins [Bag] (raid-roll)." )
  rf.rolling_popup.should_display(
    item_link( item2, 1 ),
    text( "Obszczymucha wins the raid-roll.", 11 ),
    buttons( "AwardWinner", "RaidRollAgain", "AwardOther", "Close" )
  )
  rf.confirmation_popup.should_be_hidden()

  -- When
  loot_facade.notify( "LootClosed" )

  -- Then
  rf.rolling_popup.should_display(
    item_link( item2, 1 ),
    text( "Obszczymucha wins the raid-roll.", 11 ),
    buttons( "RaidRollAgain", "Close" )
  )

  -- When
  loot_facade.notify( "LootOpened", item3 )

  -- Then
  rf.loot_frame.should_display(
    enabled_item( 1, "Sword" )
  )
  rf.rolling_popup.should_display(
    item_link( item2, 1 ),
    text( "Obszczymucha wins the raid-roll.", 11 ),
    buttons( "RaidRollAgain", "Close" )
  )

  -- When
  loot_facade.notify( "LootClosed" )
  loot_facade.notify( "LootOpened", item, item2 )

  -- Then
  rf.rolling_popup.should_display(
    item_link( item2, 1 ),
    text( "Obszczymucha wins the raid-roll.", 11 ),
    buttons( "AwardWinner", "RaidRollAgain", "AwardOther", "Close" )
  )
end

function SingleWinnerInstaRaidRollSpec:should_select_the_same_item_after_reopening_the_loot()
  -- Given
  local loot_facade, chat = mock_loot_facade(), mock_chat()
  local item, item2, item3, p1, p2 = i( "Hearthstone", 123 ), i( "Bag", 69 ), i( "Sword", 42 ), p( "Psikutas" ), p( "Obszczymucha" )
  local rf = new_roll_for()
      :loot_facade( loot_facade )
      :raid_roster( p1, p2 )
      :chat( chat )
      :build()
  mock_random( { { 1, 2, 1 } } )
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
  rf.rolling_popup.click( "InstaRaidRoll" )

  -- Then
  chat.raid( "Obszczymucha wins [Bag] (raid-roll)." )
  rf.rolling_popup.should_display(
    item_link( item2, 1 ),
    text( "Obszczymucha wins the raid-roll.", 11 ),
    buttons( "AwardWinner", "RaidRollAgain", "AwardOther", "Close" )
  )
  rf.confirmation_popup.should_be_hidden()

  -- When
  loot_facade.notify( "LootClosed" )

  -- Then
  rf.rolling_popup.should_display(
    item_link( item2, 1 ),
    text( "Obszczymucha wins the raid-roll.", 11 ),
    buttons( "RaidRollAgain", "Close" )
  )

  -- When
  loot_facade.notify( "LootOpened", item3 )

  -- Then
  rf.loot_frame.should_display(
    enabled_item( 1, "Sword" )
  )
  rf.rolling_popup.should_display(
    item_link( item2, 1 ),
    text( "Obszczymucha wins the raid-roll.", 11 ),
    buttons( "RaidRollAgain", "Close" )
  )

  -- When
  loot_facade.notify( "LootClosed" )
  loot_facade.notify( "LootOpened", item, item2 )

  -- Then
  rf.loot_frame.should_display(
    selected_item( 1, "Bag" ),
    disabled_item( 2, "Hearthstone" )
  )
end

function SingleWinnerInstaRaidRollSpec:should_not_select_the_item_after_awarding_it()
  -- Given
  local loot_facade, chat = mock_loot_facade(), mock_chat()
  local item, item2, item3, p1, p2 = i( "Hearthstone", 123 ), i( "Bag", 69 ), i( "Sword", 42 ), p( "Psikutas" ), p( "Obszczymucha" )
  local rf = new_roll_for()
      :loot_facade( loot_facade )
      :raid_roster( p1, p2 )
      :chat( chat )
      :build()
  mock_random( { { 1, 2, 1 } } )
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
  rf.rolling_popup.click( "InstaRaidRoll" )

  -- Then
  chat.raid( "Obszczymucha wins [Bag] (raid-roll)." )
  rf.rolling_popup.should_display(
    item_link( item2, 1 ),
    text( "Obszczymucha wins the raid-roll.", 11 ),
    buttons( "AwardWinner", "RaidRollAgain", "AwardOther", "Close" )
  )

  -- When
  loot_facade.notify( "LootClosed" )

  -- Then
  rf.rolling_popup.should_display(
    item_link( item2, 1 ),
    text( "Obszczymucha wins the raid-roll.", 11 ),
    buttons( "RaidRollAgain", "Close" )
  )

  -- When
  loot_facade.notify( "LootOpened", item3 )

  -- Then
  rf.loot_frame.should_display(
    enabled_item( 1, "Sword" )
  )
  rf.rolling_popup.should_display(
    item_link( item2, 1 ),
    text( "Obszczymucha wins the raid-roll.", 11 ),
    buttons( "RaidRollAgain", "Close" )
  )

  -- When
  loot_facade.notify( "LootClosed" )
  loot_facade.notify( "LootOpened", item, item2 )

  -- Then
  rf.loot_frame.should_display(
    selected_item( 1, "Bag" ),
    disabled_item( 2, "Hearthstone" )
  )
  rf.rolling_popup.should_display(
    item_link( item2, 1 ),
    text( "Obszczymucha wins the raid-roll.", 11 ),
    buttons( "AwardWinner", "RaidRollAgain", "AwardOther", "Close" )
  )
  rf.confirmation_popup.should_be_hidden()

  -- When
  rf.rolling_popup.click( "AwardWinner" )

  -- Then
  rf.confirmation_popup.should_be_visible()

  -- When
  rf.confirmation_popup.confirm()

  -- Then
  rf.confirmation_popup.should_be_hidden()
  rf.rolling_popup.should_be_hidden()
  rf.loot_frame.should_display(
    enabled_item( 1, "Hearthstone" )
  )

  -- When
  loot_facade.notify( "LootClosed" )
  loot_facade.notify( "LootOpened", item2 )

  -- Then
  rf.rolling_popup.should_be_hidden()
  rf.loot_frame.should_display(
    enabled_item( 1, "Bag" )
  )
end

function SingleWinnerInstaRaidRollSpec:should_work_if_loot_is_closed_while_awarding()
  -- Given
  local loot_facade, chat = mock_loot_facade(), mock_chat()
  local item, p1, p2 = i( "Bag", 69 ), p( "Psikutas" ), p( "Obszczymucha" )
  local rf = new_roll_for()
      :loot_facade( loot_facade )
      :raid_roster( p1, p2 )
      :chat( chat )
      :build()
  mock_random( { { 1, 2, 1 } } )
  u.mock( "GiveMasterLoot", function( slot ) loot_facade.notify( "LootSlotCleared", slot ) end )

  -- Then
  rf.loot_frame.should_be_hidden()

  -- When
  loot_facade.notify( "LootOpened", item )

  -- Then
  rf.loot_frame.should_display(
    enabled_item( 1, "Bag" )
  )
  chat.raid( "Princess Kenny dropped 1 item:" )
  chat.raid( "1. [Bag]" )
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
  rf.rolling_popup.click( "InstaRaidRoll" )

  -- Then
  chat.raid( "Obszczymucha wins [Bag] (raid-roll)." )
  rf.rolling_popup.should_display(
    item_link( item, 1 ),
    text( "Obszczymucha wins the raid-roll.", 11 ),
    buttons( "AwardWinner", "RaidRollAgain", "AwardOther", "Close" )
  )
  rf.confirmation_popup.should_be_hidden()

  -- When
  rf.rolling_popup.click( "AwardWinner" )

  -- Then
  rf.rolling_popup.should_be_hidden()
  rf.confirmation_popup.should_be_visible()

  -- When
  loot_facade.notify( "LootClosed" )

  -- Then
  rf.confirmation_popup.should_be_hidden()
  rf.rolling_popup.should_display(
    item_link( item, 1 ),
    text( "Obszczymucha wins the raid-roll.", 11 ),
    buttons( "RaidRollAgain", "Close" )
  )

  -- When
  loot_facade.notify( "LootOpened", item )

  -- Then
  rf.rolling_popup.should_display(
    item_link( item, 1 ),
    text( "Obszczymucha wins the raid-roll.", 11 ),
    buttons( "AwardWinner", "RaidRollAgain", "AwardOther", "Close" ) -- TODO: In game this didn't show the buttons ffs... Why?
  )
end

function SingleWinnerInstaRaidRollSpec:should_display_raid_roll_again_button_that_works()
  -- Given
  local loot_facade, chat = mock_loot_facade(), mock_chat()
  local item, item2, p1, p2 = i( "Hearthstone", 123 ), i( "Bag", 69 ), p( "Psikutas" ), p( "Obszczymucha" )
  local rf = new_roll_for()
      :loot_facade( loot_facade )
      :raid_roster( p1, p2 )
      :chat( chat )
      :build()
  mock_random( { { 1, 2, 1 }, { 1, 2, 2 } } )
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
  rf.rolling_popup.click( "InstaRaidRoll" )

  -- Then
  chat.raid( "Obszczymucha wins [Bag] (raid-roll)." )
  rf.rolling_popup.should_display(
    item_link( item2, 1 ),
    text( "Obszczymucha wins the raid-roll.", 11 ),
    buttons( "AwardWinner", "RaidRollAgain", "AwardOther", "Close" )
  )
  rf.confirmation_popup.should_be_hidden()

  -- When
  rf.rolling_popup.click( "RaidRollAgain" )

  -- Then
  chat.raid( "Psikutas wins [Bag] (raid-roll)." )
  rf.rolling_popup.should_display(
    item_link( item2, 1 ),
    text( "Psikutas wins the raid-roll.", 11 ),
    buttons( "AwardWinner", "RaidRollAgain", "AwardOther", "Close" )
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
  rf.loot_frame.should_display(
    enabled_item( 1, "Hearthstone" )
  )
  chat.console( "RollFor: Psikutas received [Bag]." )
end

os.exit( lu.LuaUnit.run() )
