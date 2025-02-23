package.path = "./?.lua;" .. package.path .. ";../?.lua;../RollFor/?.lua"

require( "src/bcc/compat" )
local u = require( "test/utils" )
local lu, eq = u.luaunit( "assertEquals" ) ---@diagnostic disable-line: unused-local
local sr, hr = u.soft_res_item, u.hard_res_item
local builder = require( "test/IntegrationTestBuilder" )
local mock_loot_facade, mock_chat, new_roll_for = builder.mock_loot_facade, builder.mock_chat, builder.new_roll_for
local i, p = builder.i, builder.p
local gui = require( "test/gui_helpers" )
local item_link, text, roll_placeholder, buttons = gui.item_link, gui.text, gui.sr_roll_placeholder, gui.buttons
local enabled_item, disabled_item, selected_item = gui.enabled_item, gui.disabled_item, gui.selected_item
local individual_award_button = gui.individual_award_button

PreviewNotSoftRessedItemSpec = {}

function PreviewNotSoftRessedItemSpec:should_display_close_button_that_closes_the_popup()
  -- Given
  local loot_facade, chat = mock_loot_facade(), mock_chat()
  local item, item2 = i( "Hearthstone", 123 ), i( "Bag", 69 )
  local rf = new_roll_for()
      :loot_facade( loot_facade )
      :chat( chat )
      :build()

  -- Then
  rf.loot_frame.should_be_hidden()

  -- When
  loot_facade.notify( "LootOpened", item, item2 )

  -- Then
  rf.loot_frame.should_display(
    enabled_item( 1, "Bag" ),
    enabled_item( 2, "Hearthstone" )
  )
  chat.party( "Princess Kenny dropped 2 items:" )
  chat.party( "1. [Bag]" )
  chat.party( "2. [Hearthstone]" )
  rf.rolling_popup.should_be_hidden()

  -- When
  rf.loot_frame.click( 1 )

  -- Then
  rf.loot_frame.should_display(
    selected_item( 1, "Bag" ),
    disabled_item( 2, "Hearthstone" )
  )
  rf.rolling_popup.should_display(
    item_link( item2, 1, 5 ),
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
end

function PreviewNotSoftRessedItemSpec:should_close_rolling_popup_if_the_loot_is_closed()
  -- Given
  local loot_facade, chat = mock_loot_facade(), mock_chat()
  local item, item2 = i( "Hearthstone", 123 ), i( "Bag", 69 )
  local rf = new_roll_for()
      :loot_facade( loot_facade )
      :chat( chat )
      :build()

  -- Then
  rf.loot_frame.should_be_hidden()

  -- When
  loot_facade.notify( "LootOpened", item, item2 )

  -- Then
  rf.loot_frame.should_display(
    enabled_item( 1, "Bag" ),
    enabled_item( 2, "Hearthstone" )
  )
  chat.party( "Princess Kenny dropped 2 items:" )
  chat.party( "1. [Bag]" )
  chat.party( "2. [Hearthstone]" )
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
  loot_facade.notify( "LootClosed" )

  -- Then
  rf.loot_frame.should_be_hidden()
  rf.rolling_popup.should_be_hidden()
end

function PreviewNotSoftRessedItemSpec:should_display_roll_button_that_starts_rolling_in_party()
  -- Given
  local loot_facade, chat = mock_loot_facade(), mock_chat()
  local item, item2 = i( "Hearthstone", 123 ), i( "Bag", 69 )
  local rf = new_roll_for()
      :loot_facade( loot_facade )
      :chat( chat )
      :build()

  -- Then
  rf.loot_frame.should_be_hidden()

  -- When
  loot_facade.notify( "LootOpened", item, item2 )

  -- Then
  rf.loot_frame.should_display(
    enabled_item( 1, "Bag" ),
    enabled_item( 2, "Hearthstone" )
  )
  chat.party( "Princess Kenny dropped 2 items:" )
  chat.party( "1. [Bag]" )
  chat.party( "2. [Hearthstone]" )
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
  chat.party( "Roll for [Bag]: /roll (MS) or /roll 99 (OS) or /roll 98 (TMOG)" )
end

function PreviewNotSoftRessedItemSpec:should_display_roll_button_that_starts_rolling_in_raid()
  -- Given
  local loot_facade, chat = mock_loot_facade(), mock_chat()
  local item, item2, p1, p2 = i( "Hearthstone", 123 ), i( "Bag", 69 ), p( "Psikutas" ), p( "Obszczymucha" )
  local rf = new_roll_for()
      :loot_facade( loot_facade )
      :raid_roster( p1, p2 )
      :chat( chat )
      :build()

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
end

function PreviewNotSoftRessedItemSpec:should_display_award_other_button_that_shows_player_selection_popup_and_awards_the_item()
  -- Given
  local loot_facade, chat   = mock_loot_facade(), mock_chat()
  local item, item2, p1, p2 = i( "Hearthstone", 123 ), i( "Bag", 69 ), p( "Psikutas" ), p( "Obszczymucha" )
  local rf                  = new_roll_for()
      :loot_facade( loot_facade )
      :chat( chat )
      :roster( p1, p2 )
      :build()
  u.mock( "GiveMasterLoot", function( slot ) loot_facade.notify( "LootSlotCleared", slot ) end )

  -- When
  loot_facade.notify( "LootOpened", item, item2 )

  -- Then
  rf.loot_frame.should_display(
    enabled_item( 1, "Bag" ),
    enabled_item( 2, "Hearthstone" )
  )
  rf.rolling_popup.should_be_hidden()
  chat.party( "Princess Kenny dropped 2 items:" )
  chat.party( "1. [Bag]" )
  chat.party( "2. [Hearthstone]" )

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
  rf.rolling_popup.click( "AwardOther" )

  -- Then
  rf.loot_frame.should_be_visible()
  rf.player_selection.should_display( "Obszczymucha", "Psikutas" )
  rf.confirmation_popup.should_be_hidden()

  -- When
  rf.player_selection.select( p1.name )

  -- Then
  rf.player_selection.should_be_hidden()
  rf.rolling_popup.should_be_hidden()
  rf.confirmation_popup.should_be_visible()

  -- When
  rf.confirmation_popup.confirm()

  -- Then
  rf.player_selection.should_be_hidden()
  rf.rolling_popup.should_be_hidden()
  rf.confirmation_popup.should_be_hidden()
  chat.console( "RollFor: Psikutas received [Bag]." )
  rf.loot_frame.should_display(
    enabled_item( 1, "Hearthstone" )
  )
end

PreviewSoftResWinnersSpec = {}

function PreviewSoftResWinnersSpec:should_display_close_button_that_closes_the_popup()
  -- Given
  local loot_facade, chat = mock_loot_facade(), mock_chat()
  local item, p1, p2      = i( "Hearthstone", 123 ), p( "Psikutas" ), p( "Obszczymucha" )
  local rf                = new_roll_for()
      :loot_facade( loot_facade )
      :chat( chat )
      :roster( p1, p2 )
      :soft_res_data( sr( p1.name, 123 ) )
      :build()

  -- When
  loot_facade.notify( "LootOpened", item )

  -- Then
  chat.party( "Princess Kenny dropped 1 item:" )
  chat.party( "1. [Hearthstone] (SR by Psikutas)" )
  rf.loot_frame.should_display(
    enabled_item( 1, "Hearthstone", "SR", { "Soft-ressed by", "Psikutas" } )
  )
  rf.rolling_popup.should_be_hidden()

  -- When
  rf.loot_frame.click( 1 )

  -- Then
  rf.loot_frame.should_display(
    selected_item( 1, "Hearthstone", "SR", { "Soft-ressed by", "Psikutas" } )
  )
  rf.rolling_popup.should_display(
    item_link( item, 1 ),
    text( "Psikutas soft-ressed this item.", 11 ),
    buttons( "AwardWinner", "AwardOther", "Close" )
  )

  -- When
  rf.rolling_popup.click( "Close" )

  -- Then
  rf.rolling_popup.should_be_hidden()
  rf.loot_frame.should_display(
    enabled_item( 1, "Hearthstone", "SR", { "Soft-ressed by", "Psikutas" } )
  )
end

function PreviewSoftResWinnersSpec:should_display_award_winner_button_and_display_the_popup_again_if_award_confirmation_is_aborted()
  -- Given
  local loot_facade, chat = mock_loot_facade(), mock_chat()
  local item, p1, p2      = i( "Hearthstone", 123 ), p( "Psikutas" ), p( "Obszczymucha" )
  local rf                = new_roll_for()
      :loot_facade( loot_facade )
      :chat( chat )
      :roster( p1, p2 )
      :soft_res_data( sr( p1.name, 123 ), sr( p1.name, 123 ) )
      :build()
  u.mock( "GiveMasterLoot", u.noop )
  local rolling_popup_content = {
    item_link( item, 1 ),
    text( "Psikutas soft-ressed this item.", 11 ),
    buttons( "AwardWinner", "AwardOther", "Close" )
  }

  -- When
  loot_facade.notify( "LootOpened", item )

  -- Then
  chat.party( "Princess Kenny dropped 1 item:" )
  chat.party( "1. [Hearthstone] (SR by Psikutas)" )
  rf.loot_frame.should_display(
    enabled_item( 1, "Hearthstone", "SR", { "Soft-ressed by", "Psikutas" } )
  )
  rf.rolling_popup.should_be_hidden()

  -- When
  rf.loot_frame.click( 1 )

  -- Then
  rf.loot_frame.should_display(
    selected_item( 1, "Hearthstone", "SR", { "Soft-ressed by", "Psikutas" } )
  )
  rf.rolling_popup.should_display( table.unpack( rolling_popup_content ) )

  -- When
  rf.rolling_popup.click( "AwardWinner" )

  -- Then
  rf.confirmation_popup.should_be_visible()
  rf.rolling_popup.should_be_hidden()
  -- TODO: verify loot confirmation popup content

  -- When
  rf.confirmation_popup.abort()

  -- Then
  rf.confirmation_popup.should_be_hidden()
  rf.rolling_popup.should_display( table.unpack( rolling_popup_content ) )
end

function PreviewSoftResWinnersSpec:should_display_award_winner_button_and_award_the_winner_when_confirmed()
  -- Given
  local loot_facade, chat   = mock_loot_facade(), mock_chat()
  local item, item2, p1, p2 = i( "Hearthstone", 123 ), i( "Bag", 69 ), p( "Psikutas" ), p( "Obszczymucha" )
  local rf                  = new_roll_for()
      :loot_facade( loot_facade )
      :chat( chat )
      :roster( p1, p2 )
      :soft_res_data( sr( p1.name, 123 ), sr( p1.name, 123 ) )
      :build()
  u.mock( "GiveMasterLoot", function( slot ) loot_facade.notify( "LootSlotCleared", slot ) end )
  local rolling_popup_content = {
    item_link( item, 1 ),
    text( "Psikutas soft-ressed this item.", 11 ),
    buttons( "AwardWinner", "AwardOther", "Close" )
  }

  -- When
  loot_facade.notify( "LootOpened", item, item2 )

  -- Then
  rf.loot_frame.should_display(
    enabled_item( 1, "Hearthstone", "SR", { "Soft-ressed by", "Psikutas" } ),
    enabled_item( 2, "Bag" )
  )
  chat.party( "Princess Kenny dropped 2 items:" )
  chat.party( "1. [Hearthstone] (SR by Psikutas)" )
  chat.party( "2. [Bag]" )
  rf.rolling_popup.should_be_hidden()

  -- When
  rf.loot_frame.click( 1 )

  -- Then
  rf.loot_frame.should_display(
    selected_item( 1, "Hearthstone", "SR", { "Soft-ressed by", "Psikutas" } ),
    disabled_item( 2, "Bag" )
  )
  rf.rolling_popup.should_display( table.unpack( rolling_popup_content ) )

  -- When
  rf.rolling_popup.click( "AwardWinner" )

  -- Then
  rf.confirmation_popup.should_be_visible()
  rf.rolling_popup.should_be_hidden()
  -- TODO: verify loot confirmation popup content

  -- When
  rf.confirmation_popup.confirm()

  -- Then
  chat.console( "RollFor: Psikutas received [Hearthstone]." )
  rf.loot_frame.should_display(
    enabled_item( 1, "Bag" )
  )
  rf.confirmation_popup.should_be_hidden()
  rf.rolling_popup.should_be_hidden()
end

function PreviewSoftResWinnersSpec:should_display_award_winner_buttons_and_award_the_winner_when_confirmed_then_display_the_remaining_winner()
  -- Given
  local loot_facade, chat = mock_loot_facade(), mock_chat()
  local item, p1, p2      = i( "Hearthstone", 123 ), p( "Psikutas" ), p( "Obszczymucha" )
  local rf                = new_roll_for()
      :loot_facade( loot_facade )
      :chat( chat )
      :roster( p1, p2 )
      :soft_res_data( sr( p1.name, 123 ), sr( p2.name, 123 ) )
      :build()
  u.mock( "GiveMasterLoot", function( slot ) loot_facade.notify( "LootSlotCleared", slot ) end )

  -- When
  loot_facade.notify( "LootOpened", item, item )

  -- Then
  rf.loot_frame.should_display(
    enabled_item( 1, "Hearthstone", "SR", { "Soft-ressed by", "Obszczymucha" } ),
    enabled_item( 2, "Hearthstone", "SR", { "Soft-ressed by", "Psikutas" } )
  )
  chat.party( "Princess Kenny dropped 2 items:" )
  chat.party( "1. [Hearthstone] (SR by Obszczymucha)" )
  chat.party( "2. [Hearthstone] (SR by Psikutas)" )
  rf.rolling_popup.should_be_hidden()

  -- When
  rf.loot_frame.click( 1 )

  -- Then
  rf.loot_frame.should_display(
    selected_item( 1, "Hearthstone", "SR", { "Soft-ressed by", "Obszczymucha" } ),
    selected_item( 2, "Hearthstone", "SR", { "Soft-ressed by", "Psikutas" } )
  )
  rf.confirmation_popup.should_be_hidden()
  rf.rolling_popup.should_display(
    item_link( item, 2 ),
    text( "Obszczymucha soft-ressed this item.", 11 ),
    individual_award_button,
    text( "Psikutas soft-ressed this item.", 8 ),
    individual_award_button,
    buttons( "AwardOther", "Close" )
  )

  -- When
  rf.rolling_popup.award( "Obszczymucha" )

  -- Then
  rf.confirmation_popup.should_be_visible()
  rf.rolling_popup.should_be_hidden()
  -- TODO: verify loot confirmation popup content

  -- When
  rf.confirmation_popup.confirm()

  -- Then
  chat.console( "RollFor: Obszczymucha received [Hearthstone]." )
  rf.loot_frame.should_display(
    selected_item( 1, "Hearthstone", "SR", { "Soft-ressed by", "Psikutas" } )
  )
  rf.confirmation_popup.should_be_hidden()
  rf.rolling_popup.should_display(
    item_link( item, 1 ),
    text( "Psikutas soft-ressed this item.", 11 ),
    buttons( "AwardWinner", "AwardOther", "Close" )
  )

  -- When
  rf.rolling_popup.click( "AwardWinner" )

  -- Then
  rf.confirmation_popup.should_be_visible()
  rf.rolling_popup.should_be_hidden()
  -- TODO: verify loot confirmation popup content

  -- When
  rf.confirmation_popup.confirm()

  -- Then
  chat.console( "RollFor: Psikutas received [Hearthstone]." )
  rf.confirmation_popup.should_be_hidden()
  rf.rolling_popup.should_be_hidden()
end

function PreviewSoftResWinnersSpec:should_display_award_winner_buttons_and_award_the_winner_then_award_the_next_winner_after_closing_and_reopening_the_popup()
  -- Given
  local loot_facade, chat = mock_loot_facade(), mock_chat()
  local item, p1, p2      = i( "Hearthstone", 123 ), p( "Psikutas" ), p( "Obszczymucha" )
  local rf                = new_roll_for()
      :loot_facade( loot_facade )
      :chat( chat )
      :roster( p1, p2 )
      :soft_res_data( sr( p1.name, 123 ), sr( p2.name, 123 ) )
      :build()
  u.mock( "GiveMasterLoot", function( slot ) loot_facade.notify( "LootSlotCleared", slot ) end )

  -- When
  loot_facade.notify( "LootOpened", item, item )

  -- Then
  rf.loot_frame.should_display(
    enabled_item( 1, "Hearthstone", "SR", { "Soft-ressed by", "Obszczymucha" } ),
    enabled_item( 2, "Hearthstone", "SR", { "Soft-ressed by", "Psikutas" } )
  )
  chat.party( "Princess Kenny dropped 2 items:" )
  chat.party( "1. [Hearthstone] (SR by Obszczymucha)" )
  chat.party( "2. [Hearthstone] (SR by Psikutas)" )
  rf.rolling_popup.should_be_hidden()

  -- When
  rf.loot_frame.click( 1 )

  -- Then
  rf.loot_frame.should_display(
    selected_item( 1, "Hearthstone", "SR", { "Soft-ressed by", "Obszczymucha" } ),
    selected_item( 2, "Hearthstone", "SR", { "Soft-ressed by", "Psikutas" } )
  )
  rf.confirmation_popup.should_be_hidden()
  rf.rolling_popup.should_display(
    item_link( item, 2 ),
    text( "Obszczymucha soft-ressed this item.", 11 ),
    individual_award_button,
    text( "Psikutas soft-ressed this item.", 8 ),
    individual_award_button,
    buttons( "AwardOther", "Close" )
  )

  -- When
  rf.rolling_popup.award( "Obszczymucha" )

  -- Then
  rf.confirmation_popup.should_be_visible()
  rf.rolling_popup.should_be_hidden()
  -- TODO: verify loot confirmation popup content

  -- When
  rf.confirmation_popup.confirm()

  -- Then
  chat.console( "RollFor: Obszczymucha received [Hearthstone]." )
  rf.loot_frame.should_display(
    selected_item( 1, "Hearthstone", "SR", { "Soft-ressed by", "Psikutas" } )
  )
  rf.confirmation_popup.should_be_hidden()
  rf.rolling_popup.should_display(
    item_link( item, 1 ),
    text( "Psikutas soft-ressed this item.", 11 ),
    buttons( "AwardWinner", "AwardOther", "Close" )
  )

  -- When
  rf.rolling_popup.click( "Close" )

  -- Then
  rf.rolling_popup.should_be_hidden()
  rf.loot_frame.should_display(
    enabled_item( 1, "Hearthstone", "SR", { "Soft-ressed by", "Psikutas" } )
  )

  -- When
  rf.loot_frame.click( 1 )

  -- Then
  rf.loot_frame.should_display(
    selected_item( 1, "Hearthstone", "SR", { "Soft-ressed by", "Psikutas" } )
  )
  rf.confirmation_popup.should_be_hidden()
  rf.rolling_popup.should_display(
    item_link( item, 1 ),
    text( "Psikutas soft-ressed this item.", 11 ),
    buttons( "AwardWinner", "AwardOther", "Close" )
  )

  -- When
  rf.rolling_popup.click( "AwardWinner" )

  -- Then
  rf.confirmation_popup.should_be_visible()
  rf.rolling_popup.should_be_hidden()
  -- TODO: verify loot confirmation popup content

  -- When
  rf.confirmation_popup.confirm()

  -- Then
  chat.console( "RollFor: Psikutas received [Hearthstone]." )
  rf.confirmation_popup.should_be_hidden()
  rf.rolling_popup.should_be_hidden()
end

function PreviewSoftResWinnersSpec:should_display_award_other_button_and_award_jimmy_cuz_fuck_you_soft_ressers_lol()
  -- Given
  local loot_facade, chat = mock_loot_facade(), mock_chat()
  local item, p1, p2, p3  = i( "Hearthstone", 123 ), p( "Psikutas" ), p( "Obszczymucha" ), p( "Jimmy" )
  local rf                = new_roll_for()
      :loot_facade( loot_facade )
      :chat( chat )
      :roster( p1, p2, p3 )
      :soft_res_data( sr( p1.name, 123 ), sr( p2.name, 123 ) )
      :build()
  u.mock( "GiveMasterLoot", function( slot ) loot_facade.notify( "LootSlotCleared", slot ) end )

  -- When
  loot_facade.notify( "LootOpened", item, item )

  -- Then
  rf.loot_frame.should_display(
    enabled_item( 1, "Hearthstone", "SR", { "Soft-ressed by", "Obszczymucha" } ),
    enabled_item( 2, "Hearthstone", "SR", { "Soft-ressed by", "Psikutas" } )
  )
  chat.party( "Princess Kenny dropped 2 items:" )
  chat.party( "1. [Hearthstone] (SR by Obszczymucha)" )
  chat.party( "2. [Hearthstone] (SR by Psikutas)" )
  rf.rolling_popup.should_be_hidden()

  -- When
  rf.loot_frame.click( 1 )

  -- Then
  rf.loot_frame.should_display(
    selected_item( 1, "Hearthstone", "SR", { "Soft-ressed by", "Obszczymucha" } ),
    selected_item( 2, "Hearthstone", "SR", { "Soft-ressed by", "Psikutas" } )
  )
  rf.confirmation_popup.should_be_hidden()
  rf.rolling_popup.should_display(
    item_link( item, 2 ),
    text( "Obszczymucha soft-ressed this item.", 11 ),
    individual_award_button,
    text( "Psikutas soft-ressed this item.", 8 ),
    individual_award_button,
    buttons( "AwardOther", "Close" )
  )

  -- When
  rf.rolling_popup.click( "AwardOther" )

  -- Then
  rf.loot_frame.should_be_visible()
  rf.player_selection.should_display( "Jimmy", "Obszczymucha", "Psikutas" )
  rf.confirmation_popup.should_be_hidden()

  -- When
  rf.player_selection.select( p3.name )

  -- Then
  rf.player_selection.should_be_hidden()
  rf.rolling_popup.should_be_hidden()
  rf.confirmation_popup.should_be_visible()

  -- When
  rf.confirmation_popup.confirm()

  -- Then
  rf.player_selection.should_be_hidden()
  rf.rolling_popup.should_display(
    item_link( item, 1 ),
    roll_placeholder( p2, 11 ),
    roll_placeholder( p1 ),
    buttons( "Roll", "AwardOther", "Close" )
  )
  rf.confirmation_popup.should_be_hidden()
  chat.console( "RollFor: Jimmy received [Hearthstone]." )
end

function PreviewSoftResWinnersSpec:should_display_award_winner_button_and_award_the_winner_when_confirmed_and_moved_quickly()
  -- Given
  local loot_facade, chat = mock_loot_facade(), mock_chat()
  local item, p1, p2      = i( "Hearthstone", 123 ), p( "Psikutas" ), p( "Obszczymucha" )
  local rf                = new_roll_for()
      :loot_facade( loot_facade )
      :chat( chat )
      :roster( p1, p2 )
      :soft_res_data( sr( p1.name, 123 ), sr( p1.name, 123 ) )
      :build()
  u.mock( "GiveMasterLoot", function()
    loot_facade.notify( "LootClosed" )
    loot_facade.notify( "ChatMsgLoot", string.format( "%s receives loot: %s", p1.name, item.link ) )
  end )
  local rolling_popup_content = {
    item_link( item, 1 ),
    text( "Psikutas soft-ressed this item.", 11 ),
    buttons( "AwardWinner", "AwardOther", "Close" )
  }

  -- When
  loot_facade.notify( "LootOpened", item )

  -- Then
  rf.loot_frame.should_display(
    enabled_item( 1, "Hearthstone", "SR", { "Soft-ressed by", "Psikutas" } )
  )
  chat.party( "Princess Kenny dropped 1 item:" )
  chat.party( "1. [Hearthstone] (SR by Psikutas)" )
  rf.rolling_popup.should_be_hidden()

  -- When
  rf.loot_frame.click( 1 )

  -- Then
  rf.loot_frame.should_display(
    selected_item( 1, "Hearthstone", "SR", { "Soft-ressed by", "Psikutas" } )
  )
  rf.confirmation_popup.should_be_hidden()
  rf.rolling_popup.should_display( table.unpack( rolling_popup_content ) )

  -- When
  rf.rolling_popup.click( "AwardWinner" )

  -- Then
  rf.confirmation_popup.should_be_visible()
  rf.rolling_popup.should_be_hidden()
  -- TODO: verify loot confirmation popup content

  -- When
  rf.confirmation_popup.confirm()

  -- Then
  chat.console( "RollFor: Psikutas received [Hearthstone]." )
  rf.confirmation_popup.should_be_hidden()
  rf.rolling_popup.should_be_hidden()
end

PreviewSoftRessedItemSpec = {}

function PreviewSoftRessedItemSpec:should_display_close_button_that_closes_the_popup()
  -- Given
  local loot_facade, chat = mock_loot_facade(), mock_chat()
  local item, p1, p2      = i( "Hearthstone", 123 ), p( "Psikutas" ), p( "Obszczymucha" )
  local rf                = new_roll_for()
      :loot_facade( loot_facade )
      :chat( chat )
      :roster( p1, p2 )
      :soft_res_data( sr( p1.name, 123 ), sr( p1.name, 123 ), sr( p2.name, 123 ) )
      :build()

  -- When
  loot_facade.notify( "LootOpened", item )

  -- Then
  rf.loot_frame.should_display(
    enabled_item( 1, "Hearthstone", "SR", { "Soft-ressed by", "Obszczymucha", "Psikutas [2 rolls]" } )
  )
  chat.party( "Princess Kenny dropped 1 item:" )
  chat.party( "1. [Hearthstone] (SR by Obszczymucha and Psikutas [2 rolls])" )
  rf.rolling_popup.should_be_hidden()

  -- When
  rf.loot_frame.click( 1 )

  -- Then
  rf.loot_frame.should_display(
    selected_item( 1, "Hearthstone", "SR", { "Soft-ressed by", "Obszczymucha", "Psikutas [2 rolls]" } )
  )
  rf.confirmation_popup.should_be_hidden()
  rf.rolling_popup.should_display(
    item_link( item, 1 ),
    roll_placeholder( p2, 11 ),
    roll_placeholder( p1 ),
    roll_placeholder( p1 ),
    buttons( "Roll", "AwardOther", "Close" )
  )

  -- When
  rf.rolling_popup.click( "Close" )

  -- Then
  rf.rolling_popup.should_be_hidden()
  rf.loot_frame.should_display(
    enabled_item( 1, "Hearthstone", "SR", { "Soft-ressed by", "Obszczymucha", "Psikutas [2 rolls]" } )
  )
end

function PreviewSoftRessedItemSpec:should_display_roll_button_that_starts_rolling_in_party()
  -- Given
  local loot_facade, chat = mock_loot_facade(), mock_chat()
  local item, p1, p2      = i( "Hearthstone", 123 ), p( "Psikutas" ), p( "Obszczymucha" )
  local rf                = new_roll_for()
      :loot_facade( loot_facade )
      :chat( chat )
      :roster( p1, p2 )
      :soft_res_data( sr( p1.name, 123 ), sr( p1.name, 123 ), sr( p2.name, 123 ) )
      :build()

  -- When
  loot_facade.notify( "LootOpened", item )

  -- Then
  rf.loot_frame.should_display(
    enabled_item( 1, "Hearthstone", "SR", { "Soft-ressed by", "Obszczymucha", "Psikutas [2 rolls]" } )
  )
  chat.party( "Princess Kenny dropped 1 item:" )
  chat.party( "1. [Hearthstone] (SR by Obszczymucha and Psikutas [2 rolls])" )
  rf.rolling_popup.should_be_hidden()

  -- When
  rf.loot_frame.click( 1 )

  -- Then
  rf.confirmation_popup.should_be_hidden()
  rf.rolling_popup.should_display(
    item_link( item, 1 ),
    roll_placeholder( p2, 11 ),
    roll_placeholder( p1 ),
    roll_placeholder( p1 ),
    buttons( "Roll", "AwardOther", "Close" )
  )

  -- When
  rf.rolling_popup.click( "Roll" )

  -- Then
  chat.party( "Roll for [Hearthstone]: SR by Obszczymucha and Psikutas [2 rolls]" )
end

function PreviewSoftRessedItemSpec:should_display_roll_button_that_starts_rolling_in_raid()
  -- Given
  local loot_facade, chat = mock_loot_facade(), mock_chat()
  local item, p1, p2      = i( "Hearthstone", 123 ), p( "Psikutas" ), p( "Obszczymucha" )
  local rf                = new_roll_for()
      :loot_facade( loot_facade )
      :chat( chat )
      :raid_roster( p1, p2 )
      :soft_res_data( sr( p1.name, 123 ), sr( p1.name, 123 ), sr( p2.name, 123 ) )
      :build()

  -- When
  loot_facade.notify( "LootOpened", item )

  -- Then
  rf.loot_frame.should_display(
    enabled_item( 1, "Hearthstone", "SR", { "Soft-ressed by", "Obszczymucha", "Psikutas [2 rolls]" } )
  )
  chat.raid( "Princess Kenny dropped 1 item:" )
  chat.raid( "1. [Hearthstone] (SR by Obszczymucha and Psikutas [2 rolls])" )
  rf.rolling_popup.should_be_hidden()

  -- When
  rf.loot_frame.click( 1 )

  -- Then
  rf.confirmation_popup.should_be_hidden()
  rf.rolling_popup.should_display(
    item_link( item, 1 ),
    roll_placeholder( p2, 11 ),
    roll_placeholder( p1 ),
    roll_placeholder( p1 ),
    buttons( "Roll", "AwardOther", "Close" )
  )

  -- When
  rf.rolling_popup.click( "Roll" )

  -- Then
  chat.raid_warning( "Roll for [Hearthstone]: SR by Obszczymucha and Psikutas [2 rolls]" )
end

function PreviewSoftRessedItemSpec:should_reset_the_preview_if_loot_was_closed_and_reopened_with_the_same_item_but_different_count()
  -- Given
  local loot_facade, chat = mock_loot_facade(), mock_chat()
  local item, p1, p2      = i( "Hearthstone", 123 ), p( "Psikutas" ), p( "Obszczymucha" )
  local rf                = new_roll_for()
      :loot_facade( loot_facade )
      :chat( chat )
      :raid_roster( p1, p2 )
      :soft_res_data( sr( p1.name, 123 ), sr( p1.name, 123 ), sr( p2.name, 123 ) )
      :build()

  -- When
  loot_facade.notify( "LootOpened", item, item )

  -- Then
  rf.loot_frame.should_display(
    enabled_item( 1, "Hearthstone", "SR", { "Soft-ressed by", "Obszczymucha" } ),
    enabled_item( 2, "Hearthstone", "SR", { "Soft-ressed by", "Psikutas" } )
  )
  chat.raid( "Princess Kenny dropped 2 items:" )
  chat.raid( "1. [Hearthstone] (SR by Obszczymucha)" )
  chat.raid( "2. [Hearthstone] (SR by Psikutas)" )
  rf.rolling_popup.should_be_hidden()

  -- When
  rf.loot_frame.click( 1 )

  -- Then
  rf.confirmation_popup.should_be_hidden()
  rf.rolling_popup.should_display(
    item_link( item, 2 ),
    text( "Obszczymucha soft-ressed this item.", 11 ),
    individual_award_button,
    text( "Psikutas soft-ressed this item.", 8 ),
    individual_award_button,
    buttons( "AwardOther", "Close" )
  )

  -- When
  loot_facade.notify( "LootClosed" )
  loot_facade.notify( "LootOpened", item )

  -- Then
  rf.loot_frame.should_display(
    enabled_item( 1, "Hearthstone", "SR", { "Soft-ressed by", "Obszczymucha", "Psikutas [2 rolls]" } )
  )
  rf.rolling_popup.should_be_hidden()

  -- When
  rf.loot_frame.click( 1 )

  -- Then
  rf.rolling_popup.should_display(
    item_link( item, 1 ),
    roll_placeholder( p2, 11 ),
    roll_placeholder( p1 ),
    roll_placeholder( p1 ),
    buttons( "Roll", "AwardOther", "Close" )
  )
end

PreviewHardResWinnersSpec = {}

function PreviewHardResWinnersSpec:should_display_close_button_that_closes_the_popup()
  -- Given
  local loot_facade, chat = mock_loot_facade(), mock_chat()
  local item, p1, p2      = i( "Hearthstone", 123 ), p( "Psikutas" ), p( "Obszczymucha" )
  local rf                = new_roll_for()
      :loot_facade( loot_facade )
      :chat( chat )
      :roster( p1, p2 )
      :soft_res_data( hr( 123 ) )
      :build()

  -- When
  loot_facade.notify( "LootOpened", item )

  -- Then
  chat.party( "Princess Kenny dropped 1 item:" )
  chat.party( "1. [Hearthstone] (HR)" )
  rf.loot_frame.should_display(
    enabled_item( 1, "Hearthstone", "HR" )
  )
  rf.rolling_popup.should_be_hidden()

  -- When
  rf.loot_frame.click( 1 )

  -- Then
  rf.loot_frame.should_display(
    selected_item( 1, "Hearthstone", "HR" )
  )
  rf.rolling_popup.should_display(
    item_link( item, 1 ),
    text( "This item is hard-ressed.", 11 ),
    buttons( "Roll", "AwardOther", "Close" )
  )

  -- When
  rf.rolling_popup.click( "Close" )

  -- Then
  rf.rolling_popup.should_be_hidden()
  rf.loot_frame.should_display(
    enabled_item( 1, "Hearthstone", "HR" )
  )
end

function PreviewHardResWinnersSpec:should_display_roll_button_that_starts_rolling_in_party()
  -- Given
  local loot_facade, chat = mock_loot_facade(), mock_chat()
  local item, p1, p2      = i( "Hearthstone", 123 ), p( "Psikutas" ), p( "Obszczymucha" )
  local rf                = new_roll_for()
      :loot_facade( loot_facade )
      :chat( chat )
      :roster( p1, p2 )
      :soft_res_data( hr( 123 ) )
      :build()

  -- When
  loot_facade.notify( "LootOpened", item )

  -- Then
  chat.party( "Princess Kenny dropped 1 item:" )
  chat.party( "1. [Hearthstone] (HR)" )
  rf.loot_frame.should_display(
    enabled_item( 1, "Hearthstone", "HR" )
  )
  rf.rolling_popup.should_be_hidden()

  -- When
  rf.loot_frame.click( 1 )

  -- Then
  rf.loot_frame.should_display(
    selected_item( 1, "Hearthstone", "HR" )
  )
  rf.rolling_popup.should_display(
    item_link( item, 1 ),
    text( "This item is hard-ressed.", 11 ),
    buttons( "Roll", "AwardOther", "Close" )
  )

  -- When
  rf.rolling_popup.click( "Roll" )

  -- Then
  chat.party( "Roll for [Hearthstone]: /roll (MS) or /roll 99 (OS) or /roll 98 (TMOG)" )
end

function PreviewHardResWinnersSpec:should_display_award_other_button_that_shows_player_selection_popup_and_awards_the_item()
  -- Given
  local loot_facade, chat = mock_loot_facade(), mock_chat()
  local item, p1, p2      = i( "Hearthstone", 123 ), p( "Psikutas" ), p( "Obszczymucha" )
  local rf                = new_roll_for()
      :loot_facade( loot_facade )
      :chat( chat )
      :roster( p1, p2 )
      :soft_res_data( hr( 123 ) )
      :build()
  u.mock( "GiveMasterLoot", function( slot ) loot_facade.notify( "LootSlotCleared", slot ) end )

  -- When
  loot_facade.notify( "LootOpened", item )

  -- Then
  chat.party( "Princess Kenny dropped 1 item:" )
  chat.party( "1. [Hearthstone] (HR)" )
  rf.loot_frame.should_display(
    enabled_item( 1, "Hearthstone", "HR" )
  )
  rf.rolling_popup.should_be_hidden()

  -- When
  rf.loot_frame.click( 1 )

  -- Then
  rf.loot_frame.should_display(
    selected_item( 1, "Hearthstone", "HR" )
  )
  rf.rolling_popup.should_display(
    item_link( item, 1 ),
    text( "This item is hard-ressed.", 11 ),
    buttons( "Roll", "AwardOther", "Close" )
  )

  -- When
  rf.rolling_popup.click( "AwardOther" )

  -- Then
  rf.loot_frame.should_be_visible()
  rf.player_selection.should_display( "Obszczymucha", "Psikutas" )
  rf.confirmation_popup.should_be_hidden()

  -- When
  rf.player_selection.select( p1.name )

  -- Then
  rf.player_selection.should_be_hidden()
  rf.rolling_popup.should_be_hidden()
  rf.confirmation_popup.should_be_visible()

  -- When
  rf.confirmation_popup.confirm()

  -- Then
  rf.player_selection.should_be_hidden()
  rf.rolling_popup.should_be_hidden()
  rf.confirmation_popup.should_be_hidden()
  chat.console( "RollFor: Psikutas received [Hearthstone]." )
end

os.exit( lu.LuaUnit.run() )
