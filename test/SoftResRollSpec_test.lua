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
local softres_roll, roll_placeholder = gui.softres_roll, gui.sr_roll_placeholder
local sr = u.soft_res_item
local individual_award_button = gui.individual_award_button

WaitForRemainingRollsSpec = {}

function WaitForRemainingRollsSpec:should_wait_for_all_sr_players_to_roll_and_award_the_winner()
  -- Given
  local loot_facade, chat = mock_loot_facade(), mock_chat()
  local item, item2, p1, p2 = i( "Hearthstone", 123 ), i( "Bag", 69 ), p( "Psikutas" ), p( "Obszczymucha" )
  local rf = new_roll_for()
      :loot_facade( loot_facade )
      :raid_roster( p1, p2 )
      :chat( chat )
      :soft_res_data( sr( p1.name, 69 ), sr( p2.name, 69 ) )
      :build()
  u.mock( "GiveMasterLoot", function( slot ) loot_facade.notify( "LootSlotCleared", slot ) end )

  -- Then
  rf.loot_frame.should_be_hidden()

  -- When
  loot_facade.notify( "LootOpened", item, item2 )

  -- Then
  rf.loot_frame.should_display(
    enabled_item( 1, "Bag", "SR", { "Soft-ressed by:", "Obszczymucha", "Psikutas" } ),
    enabled_item( 2, "Hearthstone" )
  )
  chat.raid( "Princess Kenny dropped 2 items:" )
  chat.raid( "1. [Bag] (SR by Obszczymucha and Psikutas)" )
  chat.raid( "2. [Hearthstone]" )
  rf.rolling_popup.should_be_hidden()

  -- When
  rf.loot_frame.click( 1 )

  -- Then
  rf.loot_frame.should_display(
    selected_item( 1, "Bag", "SR", { "Soft-ressed by:", "Obszczymucha", "Psikutas" } ),
    disabled_item( 2, "Hearthstone" )
  )
  rf.rolling_popup.should_display(
    item_link( item2, 1 ),
    roll_placeholder( p2, 11 ),
    roll_placeholder( p1 ),
    buttons( "Roll", "AwardOther", "Close" )
  )

  -- When
  rf.rolling_popup.click( "Roll" )

  -- Then
  chat.raid_warning( "Roll for [Bag]: SR by Obszczymucha and Psikutas" )
  rf.rolling_popup.should_display(
    item_link( item2, 1 ),
    roll_placeholder( p2, 11 ),
    roll_placeholder( p1 ),
    text( "Rolling ends in 8 seconds.", 11 ),
    buttons( "Cancel" )
  )

  -- When
  rf.ace_timer.repeating_tick()

  -- Then
  rf.rolling_popup.should_display(
    item_link( item2, 1 ),
    roll_placeholder( p2, 11 ),
    roll_placeholder( p1 ),
    text( "Rolling ends in 7 seconds.", 11 ),
    buttons( "Cancel" )
  )

  -- When
  rf.ace_timer.repeating_tick( 4 )

  -- Then
  rf.rolling_popup.should_display(
    item_link( item2, 1 ),
    roll_placeholder( p2, 11 ),
    roll_placeholder( p1 ),
    text( "Rolling ends in 3 seconds.", 11 ),
    buttons( "Cancel" )
  )
  chat.raid( "Stopping rolls in 3" )

  -- When
  rf.ace_timer.repeating_tick()

  -- Then
  rf.rolling_popup.should_display(
    item_link( item2, 1 ),
    roll_placeholder( p2, 11 ),
    roll_placeholder( p1 ),
    text( "Rolling ends in 2 seconds.", 11 ),
    buttons( "Cancel" )
  )
  chat.raid( "2" )

  -- When
  rf.ace_timer.repeating_tick()

  -- Then
  rf.rolling_popup.should_display(
    item_link( item2, 1 ),
    roll_placeholder( p2, 11 ),
    roll_placeholder( p1 ),
    text( "Rolling ends in 1 second.", 11 ),
    buttons( "Cancel" )
  )
  chat.raid( "1" )

  -- When
  rf.ace_timer.repeating_tick()

  -- Then
  chat.raid( "SR rolls remaining: Obszczymucha (1 roll) and Psikutas (1 roll)" )
  rf.rolling_popup.should_display(
    item_link( item2, 1 ),
    roll_placeholder( p2, 11 ),
    roll_placeholder( p1 ),
    text( "Waiting for remaining rolls...", 11 ),
    buttons( "Cancel" )
  )

  -- When
  rf.roll( p1, 69, 1, 100 )

  -- Then
  rf.rolling_popup.should_display(
    item_link( item2, 1 ),
    softres_roll( p1, 69, 11 ),
    roll_placeholder( p2 ),
    text( "Waiting for remaining rolls...", 11 ),
    buttons( "FinishEarly", "Cancel" )
  )

  -- When
  rf.roll( p2, 99, 1, 100 )

  -- Then
  chat.console( "RollFor: Obszczymucha rolled the highest (99) for [Bag] (SR)." )
  chat.raid( "Obszczymucha rolled the highest (99) for [Bag] (SR)." )
  chat.console( "RollFor: Rolling for [Bag] finished." )
  rf.rolling_popup.should_display(
    item_link( item2, 1 ),
    softres_roll( p2, 99, 11 ),
    softres_roll( p1, 69 ),
    text( "Obszczymucha wins the soft-res roll with a 99.", 11 ),
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
  chat.console( "RollFor: Obszczymucha received [Bag]." )
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

function WaitForRemainingRollsSpec:should_cancel_rolling_and_display_initial_setup()
  -- Given
  local loot_facade, chat = mock_loot_facade(), mock_chat()
  local item, item2, p1, p2 = i( "Hearthstone", 123 ), i( "Bag", 69 ), p( "Psikutas" ), p( "Obszczymucha" )
  local rf = new_roll_for()
      :loot_facade( loot_facade )
      :raid_roster( p1, p2 )
      :chat( chat )
      :soft_res_data( sr( p1.name, 69 ), sr( p2.name, 69 ) )
      :build()
  u.mock( "GiveMasterLoot", function( slot ) loot_facade.notify( "LootSlotCleared", slot ) end )

  -- Then
  rf.loot_frame.should_be_hidden()

  -- When
  loot_facade.notify( "LootOpened", item, item2 )

  -- Then
  rf.loot_frame.should_display(
    enabled_item( 1, "Bag", "SR", { "Soft-ressed by:", "Obszczymucha", "Psikutas" } ),
    enabled_item( 2, "Hearthstone" )
  )
  chat.raid( "Princess Kenny dropped 2 items:" )
  chat.raid( "1. [Bag] (SR by Obszczymucha and Psikutas)" )
  chat.raid( "2. [Hearthstone]" )
  rf.rolling_popup.should_be_hidden()

  -- When
  rf.loot_frame.click( 1 )

  -- Then
  rf.loot_frame.should_display(
    selected_item( 1, "Bag", "SR", { "Soft-ressed by:", "Obszczymucha", "Psikutas" } ),
    disabled_item( 2, "Hearthstone" )
  )
  rf.rolling_popup.should_display(
    item_link( item2, 1 ),
    roll_placeholder( p2, 11 ),
    roll_placeholder( p1 ),
    buttons( "Roll", "AwardOther", "Close" )
  )

  -- When
  rf.rolling_popup.click( "Roll" )

  -- Then
  chat.raid_warning( "Roll for [Bag]: SR by Obszczymucha and Psikutas" )
  rf.rolling_popup.should_display(
    item_link( item2, 1 ),
    roll_placeholder( p2, 11 ),
    roll_placeholder( p1 ),
    text( "Rolling ends in 8 seconds.", 11 ),
    buttons( "Cancel" )
  )

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
    roll_placeholder( p2, 11 ),
    roll_placeholder( p1 ),
    buttons( "Roll", "AwardOther", "Close" )
  )
end

function WaitForRemainingRollsSpec:should_wait_for_all_sr_players_to_roll_and_award_the_winners()
  -- Given
  local loot_facade, chat = mock_loot_facade(), mock_chat()
  local item, item2, p1, p2, p3 = i( "Hearthstone", 123 ), i( "Bag", 69 ), p( "Psikutas" ), p( "Obszczymucha" ), p( "Jimmy" )
  local rf = new_roll_for()
      :loot_facade( loot_facade )
      :raid_roster( p1, p2, p3 )
      :chat( chat )
      :soft_res_data( sr( p1.name, 69 ), sr( p2.name, 69 ), sr( p3.name, 69 ) )
      :build()
  u.mock( "GiveMasterLoot", function( slot ) loot_facade.notify( "LootSlotCleared", slot ) end )

  -- Then
  rf.loot_frame.should_be_hidden()

  -- When
  loot_facade.notify( "LootOpened", item, item2, item2 )

  -- Then
  rf.loot_frame.should_display(
    enabled_item( 1, "Bag", "SR", { "Soft-ressed by:", "Jimmy", "Obszczymucha", "Psikutas" } ),
    enabled_item( 2, "Bag", "SR", { "Soft-ressed by:", "Jimmy", "Obszczymucha", "Psikutas" } ),
    enabled_item( 3, "Hearthstone" )
  )
  chat.raid( "Princess Kenny dropped 3 items:" )
  chat.raid( "1. 2x[Bag] (SR by Jimmy, Obszczymucha and Psikutas)" )
  chat.raid( "2. [Hearthstone]" )
  rf.rolling_popup.should_be_hidden()

  -- When
  rf.loot_frame.click( 1 )

  -- Then
  rf.loot_frame.should_display(
    selected_item( 1, "Bag", "SR", { "Soft-ressed by:", "Jimmy", "Obszczymucha", "Psikutas" } ),
    selected_item( 2, "Bag", "SR", { "Soft-ressed by:", "Jimmy", "Obszczymucha", "Psikutas" } ),
    disabled_item( 3, "Hearthstone" )
  )
  rf.rolling_popup.should_display(
    item_link( item2, 2 ),
    roll_placeholder( p3, 11 ),
    roll_placeholder( p2 ),
    roll_placeholder( p1 ),
    buttons( "Roll", "AwardOther", "Close" )
  )

  -- When
  rf.rolling_popup.click( "Roll" )

  -- Then
  chat.raid_warning( "Roll for 2x[Bag]: SR by Jimmy, Obszczymucha and Psikutas. 2 top rolls win." )
  rf.rolling_popup.should_display(
    item_link( item2, 2 ),
    roll_placeholder( p3, 11 ),
    roll_placeholder( p2 ),
    roll_placeholder( p1 ),
    text( "Rolling ends in 8 seconds.", 11 ),
    buttons( "Cancel" )
  )

  -- When
  rf.ace_timer.repeating_tick()

  -- Then
  rf.rolling_popup.should_display(
    item_link( item2, 2 ),
    roll_placeholder( p3, 11 ),
    roll_placeholder( p2 ),
    roll_placeholder( p1 ),
    text( "Rolling ends in 7 seconds.", 11 ),
    buttons( "Cancel" )
  )

  -- When
  rf.ace_timer.repeating_tick( 4 )

  -- Then
  rf.rolling_popup.should_display(
    item_link( item2, 2 ),
    roll_placeholder( p3, 11 ),
    roll_placeholder( p2 ),
    roll_placeholder( p1 ),
    text( "Rolling ends in 3 seconds.", 11 ),
    buttons( "Cancel" )
  )
  chat.raid( "Stopping rolls in 3" )

  -- When
  rf.ace_timer.repeating_tick()

  -- Then
  rf.rolling_popup.should_display(
    item_link( item2, 2 ),
    roll_placeholder( p3, 11 ),
    roll_placeholder( p2 ),
    roll_placeholder( p1 ),
    text( "Rolling ends in 2 seconds.", 11 ),
    buttons( "Cancel" )
  )
  chat.raid( "2" )

  -- When
  rf.ace_timer.repeating_tick()

  -- Then
  rf.rolling_popup.should_display(
    item_link( item2, 2 ),
    roll_placeholder( p3, 11 ),
    roll_placeholder( p2 ),
    roll_placeholder( p1 ),
    text( "Rolling ends in 1 second.", 11 ),
    buttons( "Cancel" )
  )
  chat.raid( "1" )

  -- When
  rf.ace_timer.repeating_tick()

  -- Then
  chat.raid( "SR rolls remaining: Jimmy (1 roll), Obszczymucha (1 roll) and Psikutas (1 roll)" )
  rf.rolling_popup.should_display(
    item_link( item2, 2 ),
    roll_placeholder( p3, 11 ),
    roll_placeholder( p2 ),
    roll_placeholder( p1 ),
    text( "Waiting for remaining rolls...", 11 ),
    buttons( "Cancel" )
  )

  -- When
  rf.roll( p1, 69, 1, 100 )

  -- Then
  rf.rolling_popup.should_display(
    item_link( item2, 2 ),
    softres_roll( p1, 69, 11 ),
    roll_placeholder( p3 ),
    roll_placeholder( p2 ),
    text( "Waiting for remaining rolls...", 11 ),
    buttons( "FinishEarly", "Cancel" )
  )

  -- When
  rf.roll( p2, 99, 1, 100 )

  -- Then
  rf.rolling_popup.should_display(
    item_link( item2, 2 ),
    softres_roll( p2, 99, 11 ),
    softres_roll( p1, 69 ),
    roll_placeholder( p3 ),
    text( "Waiting for remaining rolls...", 11 ),
    buttons( "FinishEarly", "Cancel" )
  )

  -- When
  rf.roll( p3, 98, 1, 100 )

  -- Then
  chat.console( "RollFor: Obszczymucha rolled the highest (99) for [Bag] (SR)." )
  chat.raid( "Obszczymucha rolled the highest (99) for [Bag] (SR)." )
  chat.console( "RollFor: Jimmy rolled the next highest (98) for [Bag] (SR)." )
  chat.raid( "Jimmy rolled the next highest (98) for [Bag] (SR)." )
  chat.console( "RollFor: Rolling for [Bag] finished." )
  rf.rolling_popup.should_display(
    item_link( item2, 2 ),
    softres_roll( p2, 99, 11 ),
    softres_roll( p3, 98 ),
    softres_roll( p1, 69 ),
    text( "Obszczymucha wins the soft-res roll with a 99.", 11 ),
    individual_award_button,
    text( "Jimmy wins the soft-res roll with a 98.", 8 ),
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
    selected_item( 1, "Bag", "SR", { "Soft-ressed by:", "Jimmy", "Obszczymucha", "Psikutas" } ),
    disabled_item( 2, "Hearthstone" )
  )
  rf.rolling_popup.should_display(
    item_link( item2, 1 ),
    softres_roll( p2, 99, 11 ),
    softres_roll( p3, 98 ),
    softres_roll( p1, 69 ),
    text( "Jimmy wins the soft-res roll with a 98.", 11 ),
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
  chat.console( "RollFor: Jimmy received [Bag]." )

  -- Then
  rf.rolling_popup.should_be_hidden()
  rf.loot_frame.should_display(
    enabled_item( 1, "Hearthstone" )
  )

  -- When
  loot_facade.notify( "LootClosed" )
  rf.reset_announcements()
  loot_facade.notify( "LootOpened", item, item2 )

  -- Then
  rf.loot_frame.should_display(
    enabled_item( 1, "Bag", "SR", { "Soft-ressed by:", "Psikutas" } ),
    enabled_item( 2, "Hearthstone" )
  )
  chat.raid( "Princess Kenny dropped 2 items:" )
  chat.raid( "1. [Bag] (SR by Psikutas)" )
  chat.raid( "2. [Hearthstone]" )
  rf.rolling_popup.should_be_hidden()

  -- When
  rf.loot_frame.click( 1 )

  -- Then
  rf.loot_frame.should_display(
    selected_item( 1, "Bag", "SR", { "Soft-ressed by:", "Psikutas" } ),
    disabled_item( 2, "Hearthstone" )
  )
  rf.rolling_popup.should_display(
    item_link( item2, 1 ),
    text( "Psikutas soft-ressed this item.", 11 ),
    buttons( "AwardWinner", "AwardOther", "Close" )
  )
end

SoftResTieRollSpec = {}

function SoftResTieRollSpec:should_display_tie_rolls()
  -- Given
  local loot_facade, chat = mock_loot_facade(), mock_chat()
  local item, item2, p1, p2 = i( "Hearthstone", 123 ), i( "Bag", 69 ), p( "Psikutas" ), p( "Obszczymucha" )
  local rf = new_roll_for()
      :loot_facade( loot_facade )
      :raid_roster( p1, p2 )
      :chat( chat )
      :soft_res_data( sr( p1.name, 69 ), sr( p2.name, 69 ) )
      :build()
  u.mock( "GiveMasterLoot", function( slot ) loot_facade.notify( "LootSlotCleared", slot ) end )

  -- Then
  rf.loot_frame.should_be_hidden()

  -- When
  loot_facade.notify( "LootOpened", item, item2 )

  -- Then
  rf.loot_frame.should_display(
    enabled_item( 1, "Bag", "SR", { "Soft-ressed by:", "Obszczymucha", "Psikutas" } ),
    enabled_item( 2, "Hearthstone" )
  )
  chat.raid( "Princess Kenny dropped 2 items:" )
  chat.raid( "1. [Bag] (SR by Obszczymucha and Psikutas)" )
  chat.raid( "2. [Hearthstone]" )
  rf.rolling_popup.should_be_hidden()

  -- When
  rf.loot_frame.click( 1 )

  -- Then
  rf.loot_frame.should_display(
    selected_item( 1, "Bag", "SR", { "Soft-ressed by:", "Obszczymucha", "Psikutas" } ),
    disabled_item( 2, "Hearthstone" )
  )
  rf.rolling_popup.should_display(
    item_link( item2, 1 ),
    roll_placeholder( p2, 11 ),
    roll_placeholder( p1 ),
    buttons( "Roll", "AwardOther", "Close" )
  )

  -- When
  rf.rolling_popup.click( "Roll" )

  -- Then
  chat.raid_warning( "Roll for [Bag]: SR by Obszczymucha and Psikutas" )
  rf.rolling_popup.should_display(
    item_link( item2, 1 ),
    roll_placeholder( p2, 11 ),
    roll_placeholder( p1 ),
    text( "Rolling ends in 8 seconds.", 11 ),
    buttons( "Cancel" )
  )

  -- When
  rf.roll( p2, 69, 1, 100 )
  rf.roll( p1, 69, 1, 100 )

  -- Then
  chat.console( "RollFor: Obszczymucha and Psikutas rolled the highest (69) for [Bag] (SR)." )
  chat.raid( "Obszczymucha and Psikutas rolled the highest (69) for [Bag] (SR)." )
  rf.rolling_popup.should_display(
    item_link( item2, 1 ),
    softres_roll( p2, 69, 11 ),
    softres_roll( p1, 69 ),
    text( "There was a tie (69):", 11 ),
    roll_placeholder( p2, 11 ),
    roll_placeholder( p1 ),
    empty_line( 5 )
  )

  -- When
  rf.ace_timer.tick()

  -- Then
  chat.raid( "Obszczymucha and Psikutas /roll for [Bag] now." )
  rf.rolling_popup.should_display(
    item_link( item2, 1 ),
    softres_roll( p2, 69, 11 ),
    softres_roll( p1, 69 ),
    text( "There was a tie (69):", 11 ),
    roll_placeholder( p2, 11 ),
    roll_placeholder( p1 ),
    text( "Waiting for remaining rolls...", 11 ),
    buttons( "FinishEarly", "Cancel" )
  )

  -- When
  rf.roll( p2, 42, 1, 100 )
  rf.roll( p1, 42, 1, 100 )

  -- Then
  chat.console( "RollFor: Obszczymucha and Psikutas re-rolled the highest (42) for [Bag] (SR)." )
  chat.raid( "Obszczymucha and Psikutas re-rolled the highest (42) for [Bag] (SR)." )
  rf.rolling_popup.should_display(
    item_link( item2, 1 ),
    softres_roll( p2, 69, 11 ),
    softres_roll( p1, 69 ),
    text( "There was a tie (69):", 11 ),
    softres_roll( p2, 42, 11 ),
    softres_roll( p1, 42 ),
    text( "There was a tie (42):", 11 ),
    roll_placeholder( p2, 11 ),
    roll_placeholder( p1 ),
    empty_line( 5 )
  )

  -- When
  rf.ace_timer.tick()

  -- Then
  chat.raid( "Obszczymucha and Psikutas /roll for [Bag] now." )
  rf.rolling_popup.should_display(
    item_link( item2, 1 ),
    softres_roll( p2, 69, 11 ),
    softres_roll( p1, 69 ),
    text( "There was a tie (69):", 11 ),
    softres_roll( p2, 42, 11 ),
    softres_roll( p1, 42 ),
    text( "There was a tie (42):", 11 ),
    roll_placeholder( p2, 11 ),
    roll_placeholder( p1 ),
    text( "Waiting for remaining rolls...", 11 ),
    buttons( "FinishEarly", "Cancel" )
  )

  -- When
  rf.roll( p2, 1, 1, 100 )
  rf.roll( p1, 2, 1, 100 )

  -- Then
  chat.console( "RollFor: Psikutas re-rolled the highest (2) for [Bag] (SR)." )
  chat.raid( "Psikutas re-rolled the highest (2) for [Bag] (SR)." )
  chat.console( "RollFor: Rolling for [Bag] finished." )
  rf.rolling_popup.should_display(
    item_link( item2, 1 ),
    softres_roll( p2, 69, 11 ),
    softres_roll( p1, 69 ),
    text( "There was a tie (69):", 11 ),
    softres_roll( p2, 42, 11 ),
    softres_roll( p1, 42 ),
    text( "There was a tie (42):", 11 ),
    softres_roll( p1, 2, 11 ),
    softres_roll( p2, 1 ),
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
    softres_roll( p2, 69, 11 ),
    softres_roll( p1, 69 ),
    text( "There was a tie (69):", 11 ),
    softres_roll( p2, 42, 11 ),
    softres_roll( p1, 42 ),
    text( "There was a tie (42):", 11 ),
    softres_roll( p1, 2, 11 ),
    softres_roll( p2, 1 ),
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

os.exit( lu.LuaUnit.run() )
