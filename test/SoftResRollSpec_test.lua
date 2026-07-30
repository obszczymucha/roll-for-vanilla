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
local mainspec_roll = gui.mainspec_roll
local sr = u.soft_res_item
local individual_award_button = gui.individual_award_button

WaitForRemainingRollsSpec = {}

function WaitForRemainingRollsSpec:should_finish_early_if_two_items_drop_and_the_winner_has_extra_roll_left()
  -- Given
  local loot_facade, chat = mock_loot_facade(), mock_chat()
  local c, r, rw = chat.console, chat.raid, chat.raid_warning
  local item, item2, p1, p2, p3, p4 = i( "Bag", 69 ), i( "Bag", 69 ), p( "Drutree" ), p( "Mendunia" ), p( "Mufasapowel" ), p( "Pinp" )
  local rf = new_roll_for()
      :loot_facade( loot_facade )
      :raid_roster( p1, p2, p3, p4 )
      :chat( chat )
      :soft_res_data( sr( p1.name, 69 ), sr( p1.name, 69 ), sr( p2.name, 69 ), sr( p3.name, 69 ), sr( p3.name, 69 ), sr( p4.name, 69 ) )
      :build()
  u.mock( "GiveMasterLoot", function( slot ) loot_facade.notify( "LootSlotCleared", slot ) end )
  local tick = rf.ace_timer.repeating_tick

  -- Then
  rf.loot_frame.should_be_hidden()

  -- When
  loot_facade.notify( "LootOpened", item, item2 )

  -- Then
  rf.loot_frame.should_display(
    enabled_item( 1, "Bag", "SR", { "Soft-ressed by", "Drutree [2 rolls]", "Mendunia", "Mufasapowel [2 rolls]", "Pinp" } ),
    enabled_item( 2, "Bag", "SR", { "Soft-ressed by", "Drutree [2 rolls]", "Mendunia", "Mufasapowel [2 rolls]", "Pinp" } )
  )
  r( "Princess Kenny dropped 2 items:" )
  r( "1. 2x[Bag] (SR by Drutree [2 rolls], Mendunia, Mufasapowel [2 rolls] and Pinp)" )
  rf.rolling_popup.should_be_hidden()

  -- When
  rf.loot_frame.click( 1 )

  -- Then
  rf.rolling_popup.should_display(
    item_link( item2, 2 ),
    roll_placeholder( p1, 11 ),
    roll_placeholder( p1 ),
    roll_placeholder( p2 ),
    roll_placeholder( p3 ),
    roll_placeholder( p3 ),
    roll_placeholder( p4 ),
    buttons( "Roll", "AwardOther", "Close" )
  )

  -- When
  rf.rolling_popup.click( "Roll" )

  -- Then
  rw( "Roll for 2x[Bag]: SR by Drutree [2 rolls], Mendunia, Mufasapowel [2 rolls] and Pinp. 2 top rolls win." )
  rf.rolling_popup.should_display(
    item_link( item2, 2 ),
    roll_placeholder( p1, 11 ),
    roll_placeholder( p1 ),
    roll_placeholder( p2 ),
    roll_placeholder( p3 ),
    roll_placeholder( p3 ),
    roll_placeholder( p4 ),
    text( "Rolling ends in 8 seconds.", 11 ),
    buttons( "Cancel" )
  )

  -- When
  rf.roll( p3, 47, 1, 100 ) -- Mufasa
  tick()
  rf.roll( p1, 91, 1, 100 ) -- Drutree
  tick()
  rf.roll( p3, 75, 1, 100 ) -- Mufasa
  tick()
  rf.roll( p4, 21, 1, 100 ) -- Pinp
  tick()
  rf.roll( p2, 32, 1, 100 ) -- Mendunia

  -- Then
  c( "RollFor: Drutree rolled the highest (91) for [Bag] (SR)." )
  r( "Drutree rolled the highest (91) for [Bag] (SR)." )
  c( "RollFor: Mufasapowel rolled the next highest (75) for [Bag] (SR)." )
  r( "Mufasapowel rolled the next highest (75) for [Bag] (SR)." )
  c( "RollFor: Rolling for [Bag] finished." )
end

function WaitForRemainingRollsSpec:should_wait_for_remaining_roll_and_win_if_roll_breaks_the_tie()
  -- Given
  local loot_facade, chat = mock_loot_facade(), mock_chat()
  local c, r, rw = chat.console, chat.raid, chat.raid_warning
  local item, item2, p1, p2, p3, p4 = i( "Bag", 69 ), i( "Bag", 69 ), p( "Drutree" ), p( "Mendunia" ), p( "Mufasapowel" ), p( "Pinp" )
  local rf = new_roll_for()
      :loot_facade( loot_facade )
      :raid_roster( p1, p2, p3, p4 )
      :chat( chat )
      :soft_res_data( sr( p1.name, 69 ), sr( p1.name, 69 ), sr( p2.name, 69 ), sr( p3.name, 69 ), sr( p3.name, 69 ), sr( p4.name, 69 ) )
      :build()
  u.mock( "GiveMasterLoot", function( slot ) loot_facade.notify( "LootSlotCleared", slot ) end )
  local tick = rf.ace_timer.repeating_tick

  -- Then
  rf.loot_frame.should_be_hidden()

  -- When
  loot_facade.notify( "LootOpened", item, item2 )

  -- Then
  rf.loot_frame.should_display(
    enabled_item( 1, "Bag", "SR", { "Soft-ressed by", "Drutree [2 rolls]", "Mendunia", "Mufasapowel [2 rolls]", "Pinp" } ),
    enabled_item( 2, "Bag", "SR", { "Soft-ressed by", "Drutree [2 rolls]", "Mendunia", "Mufasapowel [2 rolls]", "Pinp" } )
  )
  r( "Princess Kenny dropped 2 items:" )
  r( "1. 2x[Bag] (SR by Drutree [2 rolls], Mendunia, Mufasapowel [2 rolls] and Pinp)" )
  rf.rolling_popup.should_be_hidden()

  -- When
  rf.loot_frame.click( 1 )

  -- Then
  rf.rolling_popup.should_display(
    item_link( item2, 2 ),
    roll_placeholder( p1, 11 ),
    roll_placeholder( p1 ),
    roll_placeholder( p2 ),
    roll_placeholder( p3 ),
    roll_placeholder( p3 ),
    roll_placeholder( p4 ),
    buttons( "Roll", "AwardOther", "Close" )
  )

  -- When
  rf.rolling_popup.click( "Roll" )

  -- Then
  rw( "Roll for 2x[Bag]: SR by Drutree [2 rolls], Mendunia, Mufasapowel [2 rolls] and Pinp. 2 top rolls win." )
  rf.rolling_popup.should_display(
    item_link( item2, 2 ),
    roll_placeholder( p1, 11 ),
    roll_placeholder( p1 ),
    roll_placeholder( p2 ),
    roll_placeholder( p3 ),
    roll_placeholder( p3 ),
    roll_placeholder( p4 ),
    text( "Rolling ends in 8 seconds.", 11 ),
    buttons( "Cancel" )
  )

  -- When
  rf.roll( p3, 91, 1, 100 ) -- Mufasa
  tick()
  rf.roll( p1, 75, 1, 100 ) -- Drutree
  tick()
  rf.roll( p3, 50, 1, 100 ) -- Mufasa
  tick()
  rf.roll( p4, 75, 1, 100 ) -- Pinp
  tick()
  rf.roll( p2, 32, 1, 100 ) -- Mendunia
  tick()
  r( "Stopping rolls in 3" )
  tick()
  r( "2" )
  tick()
  r( "1" )
  tick()

  -- Then
  r( "SR rolls remaining: Drutree (1 roll)" )

  -- When
  rf.roll( p1, 76, 1, 100 ) -- Drutree rolls higher, breaks the tie

  -- Then
  c( "RollFor: Mufasapowel rolled the highest (91) for [Bag] (SR)." )
  r( "Mufasapowel rolled the highest (91) for [Bag] (SR)." )
  c( "RollFor: Drutree rolled the next highest (76) for [Bag] (SR)." )
  r( "Drutree rolled the next highest (76) for [Bag] (SR)." )
  c( "RollFor: Rolling for [Bag] finished." )
end

function WaitForRemainingRollsSpec:should_wait_for_remaining_roll_and_tie_if_roll_does_not_break_the_tie()
  -- Given
  local loot_facade, chat = mock_loot_facade(), mock_chat()
  local c, r, rw = chat.console, chat.raid, chat.raid_warning
  local item, item2, p1, p2, p3, p4 = i( "Bag", 69 ), i( "Bag", 69 ), p( "Drutree" ), p( "Mendunia" ), p( "Mufasapowel" ), p( "Pinp" )
  local rf = new_roll_for()
      :loot_facade( loot_facade )
      :raid_roster( p1, p2, p3, p4 )
      :chat( chat )
      :soft_res_data( sr( p1.name, 69 ), sr( p1.name, 69 ), sr( p2.name, 69 ), sr( p3.name, 69 ), sr( p3.name, 69 ), sr( p4.name, 69 ) )
      :build()
  u.mock( "GiveMasterLoot", function( slot ) loot_facade.notify( "LootSlotCleared", slot ) end )
  local tick = rf.ace_timer.repeating_tick

  -- Then
  rf.loot_frame.should_be_hidden()

  -- When
  loot_facade.notify( "LootOpened", item, item2 )

  -- Then
  rf.loot_frame.should_display(
    enabled_item( 1, "Bag", "SR", { "Soft-ressed by", "Drutree [2 rolls]", "Mendunia", "Mufasapowel [2 rolls]", "Pinp" } ),
    enabled_item( 2, "Bag", "SR", { "Soft-ressed by", "Drutree [2 rolls]", "Mendunia", "Mufasapowel [2 rolls]", "Pinp" } )
  )
  r( "Princess Kenny dropped 2 items:" )
  r( "1. 2x[Bag] (SR by Drutree [2 rolls], Mendunia, Mufasapowel [2 rolls] and Pinp)" )
  rf.rolling_popup.should_be_hidden()

  -- When
  rf.loot_frame.click( 1 )

  -- Then
  rf.rolling_popup.should_display(
    item_link( item2, 2 ),
    roll_placeholder( p1, 11 ),
    roll_placeholder( p1 ),
    roll_placeholder( p2 ),
    roll_placeholder( p3 ),
    roll_placeholder( p3 ),
    roll_placeholder( p4 ),
    buttons( "Roll", "AwardOther", "Close" )
  )

  -- When
  rf.rolling_popup.click( "Roll" )

  -- Then
  rw( "Roll for 2x[Bag]: SR by Drutree [2 rolls], Mendunia, Mufasapowel [2 rolls] and Pinp. 2 top rolls win." )
  rf.rolling_popup.should_display(
    item_link( item2, 2 ),
    roll_placeholder( p1, 11 ),
    roll_placeholder( p1 ),
    roll_placeholder( p2 ),
    roll_placeholder( p3 ),
    roll_placeholder( p3 ),
    roll_placeholder( p4 ),
    text( "Rolling ends in 8 seconds.", 11 ),
    buttons( "Cancel" )
  )

  -- When
  rf.roll( p3, 91, 1, 100 ) -- Mufasa
  tick()
  rf.roll( p1, 75, 1, 100 ) -- Drutree
  tick()
  rf.roll( p3, 50, 1, 100 ) -- Mufasa
  tick()
  rf.roll( p4, 75, 1, 100 ) -- Pinp
  tick()
  rf.roll( p2, 32, 1, 100 ) -- Mendunia
  tick()
  r( "Stopping rolls in 3" )
  tick()
  r( "2" )
  tick()
  r( "1" )
  tick()

  -- Then
  r( "SR rolls remaining: Drutree (1 roll)" )

  -- When
  rf.roll( p1, 74, 1, 100 ) -- Drutree rolls lower, tie remains

  -- Then
  c( "RollFor: Mufasapowel rolled the highest (91) for [Bag] (SR)." )
  r( "Mufasapowel rolled the highest (91) for [Bag] (SR)." )
  c( "RollFor: Drutree and Pinp rolled the next highest (75) for [Bag] (SR)." )
  r( "Drutree and Pinp rolled the next highest (75) for [Bag] (SR)." )
  rf.rolling_popup.should_display(
    item_link( item2, 2 ),
    softres_roll( p3, 91, 11 ),
    softres_roll( p1, 75 ),
    softres_roll( p4, 75 ),
    softres_roll( p1, 74 ),
    softres_roll( p3, 50 ),
    softres_roll( p2, 32 ),
    text( "There was a tie (75):", 11 ),
    roll_placeholder( p1, 11 ),
    roll_placeholder( p4 ),
    empty_line( 5 )
  )

  -- When
  rf.ace_timer.tick()

  -- Then
  r( "Drutree and Pinp /roll for [Bag] now." )

  -- When
  rf.roll( p1, 60, 1, 100 )
  rf.roll( p4, 99, 1, 100 )

  -- Then
  c( "RollFor: Pinp re-rolled the highest (99) for [Bag] (SR)." )
  r( "Pinp re-rolled the highest (99) for [Bag] (SR)." )
  c( "RollFor: Rolling for [Bag] finished." )
  rf.rolling_popup.should_display(
    item_link( item2, 2 ),
    softres_roll( p3, 91, 11 ),
    softres_roll( p1, 75 ),
    softres_roll( p4, 75 ),
    softres_roll( p1, 74 ),
    softres_roll( p3, 50 ),
    softres_roll( p2, 32 ),
    text( "There was a tie (75):", 11 ),
    softres_roll( p4, 99, 11 ),
    softres_roll( p1, 60 ),
    text( "Mufasapowel wins the soft-res roll with 91.", 11 ),
    individual_award_button,
    text( "Pinp wins the soft-res roll with 99.", 8 ),
    individual_award_button,
    buttons( "RaidRoll", "AwardOther", "Close" )
  )
end

function WaitForRemainingRollsSpec:should_finish_early_if_two_top_rolls_tie()
  -- Given
  local loot_facade, chat = mock_loot_facade(), mock_chat()
  local c, r, rw = chat.console, chat.raid, chat.raid_warning
  local item, item2, p1, p2, p3, p4 = i( "Bag", 69 ), i( "Bag", 69 ), p( "Drutree" ), p( "Mendunia" ), p( "Mufasapowel" ), p( "Pinp" )
  local rf = new_roll_for()
      :loot_facade( loot_facade )
      :raid_roster( p1, p2, p3, p4 )
      :chat( chat )
      :soft_res_data( sr( p1.name, 69 ), sr( p1.name, 69 ), sr( p2.name, 69 ), sr( p3.name, 69 ), sr( p3.name, 69 ), sr( p4.name, 69 ) )
      :build()
  u.mock( "GiveMasterLoot", function( slot ) loot_facade.notify( "LootSlotCleared", slot ) end )
  local tick = rf.ace_timer.repeating_tick

  -- Then
  rf.loot_frame.should_be_hidden()

  -- When
  loot_facade.notify( "LootOpened", item, item2 )

  -- Then
  rf.loot_frame.should_display(
    enabled_item( 1, "Bag", "SR", { "Soft-ressed by", "Drutree [2 rolls]", "Mendunia", "Mufasapowel [2 rolls]", "Pinp" } ),
    enabled_item( 2, "Bag", "SR", { "Soft-ressed by", "Drutree [2 rolls]", "Mendunia", "Mufasapowel [2 rolls]", "Pinp" } )
  )
  r( "Princess Kenny dropped 2 items:" )
  r( "1. 2x[Bag] (SR by Drutree [2 rolls], Mendunia, Mufasapowel [2 rolls] and Pinp)" )
  rf.rolling_popup.should_be_hidden()

  -- When
  rf.loot_frame.click( 1 )

  -- Then
  rf.rolling_popup.should_display(
    item_link( item2, 2 ),
    roll_placeholder( p1, 11 ),
    roll_placeholder( p1 ),
    roll_placeholder( p2 ),
    roll_placeholder( p3 ),
    roll_placeholder( p3 ),
    roll_placeholder( p4 ),
    buttons( "Roll", "AwardOther", "Close" )
  )

  -- When
  rf.rolling_popup.click( "Roll" )

  -- Then
  rw( "Roll for 2x[Bag]: SR by Drutree [2 rolls], Mendunia, Mufasapowel [2 rolls] and Pinp. 2 top rolls win." )
  rf.rolling_popup.should_display(
    item_link( item2, 2 ),
    roll_placeholder( p1, 11 ),
    roll_placeholder( p1 ),
    roll_placeholder( p2 ),
    roll_placeholder( p3 ),
    roll_placeholder( p3 ),
    roll_placeholder( p4 ),
    text( "Rolling ends in 8 seconds.", 11 ),
    buttons( "Cancel" )
  )

  -- When
  rf.roll( p3, 47, 1, 100 ) -- Mufasa
  tick()
  rf.roll( p1, 91, 1, 100 ) -- Drutree
  tick()
  rf.roll( p3, 75, 1, 100 ) -- Mufasa
  tick()
  rf.roll( p4, 91, 1, 100 ) -- Pinp
  tick()
  rf.roll( p2, 32, 1, 100 ) -- Mendunia

  -- Then
  c( "RollFor: Drutree and Pinp rolled the highest (91) for [Bag] (SR)." )
  r( "Drutree and Pinp rolled the highest (91) for [Bag] (SR)." )
  c( "RollFor: Rolling for [Bag] finished." )
end

function WaitForRemainingRollsSpec:should_wait_for_all_sr_players_to_roll_and_award_the_winner()
  -- Given
  local loot_facade, chat = mock_loot_facade(), mock_chat()
  local c, r, rw = chat.console, chat.raid, chat.raid_warning
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
    enabled_item( 1, "Bag", "SR", { "Soft-ressed by", "Obszczymucha", "Psikutas" } ),
    enabled_item( 2, "Hearthstone" )
  )
  r( "Princess Kenny dropped 2 items:" )
  r( "1. [Bag] (SR by Obszczymucha and Psikutas)" )
  r( "2. [Hearthstone]" )
  rf.rolling_popup.should_be_hidden()

  -- When
  rf.loot_frame.click( 1 )

  -- Then
  rf.loot_frame.should_display(
    selected_item( 1, "Bag", "SR", { "Soft-ressed by", "Obszczymucha", "Psikutas" } ),
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
  rw( "Roll for [Bag]: SR by Obszczymucha and Psikutas" )
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
  r( "Stopping rolls in 3" )

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
  r( "2" )

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
  r( "1" )

  -- When
  rf.ace_timer.repeating_tick()

  -- Then
  r( "SR rolls remaining: Obszczymucha (1 roll) and Psikutas (1 roll)" )
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
  c( "RollFor: Obszczymucha rolled the highest (99) for [Bag] (SR)." )
  r( "Obszczymucha rolled the highest (99) for [Bag] (SR)." )
  c( "RollFor: Rolling for [Bag] finished." )
  rf.rolling_popup.should_display(
    item_link( item2, 1 ),
    softres_roll( p2, 99, 11 ),
    softres_roll( p1, 69 ),
    text( "Obszczymucha wins the soft-res roll with 99.", 11 ),
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
  c( "RollFor: Obszczymucha received [Bag]." )
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
  local c, r, rw = chat.console, chat.raid, chat.raid_warning
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
    enabled_item( 1, "Bag", "SR", { "Soft-ressed by", "Obszczymucha", "Psikutas" } ),
    enabled_item( 2, "Hearthstone" )
  )
  r( "Princess Kenny dropped 2 items:" )
  r( "1. [Bag] (SR by Obszczymucha and Psikutas)" )
  r( "2. [Hearthstone]" )
  rf.rolling_popup.should_be_hidden()

  -- When
  rf.loot_frame.click( 1 )

  -- Then
  rf.loot_frame.should_display(
    selected_item( 1, "Bag", "SR", { "Soft-ressed by", "Obszczymucha", "Psikutas" } ),
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
  rw( "Roll for [Bag]: SR by Obszczymucha and Psikutas" )
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
  c( "RollFor: Rolling for [Bag] was canceled." )
  r( "Rolling for [Bag] was canceled." )
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
  local c, r, rw = chat.console, chat.raid, chat.raid_warning
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
    enabled_item( 1, "Bag", "SR", { "Soft-ressed by", "Jimmy", "Obszczymucha", "Psikutas" } ),
    enabled_item( 2, "Bag", "SR", { "Soft-ressed by", "Jimmy", "Obszczymucha", "Psikutas" } ),
    enabled_item( 3, "Hearthstone" )
  )
  r( "Princess Kenny dropped 3 items:" )
  r( "1. 2x[Bag] (SR by Jimmy, Obszczymucha and Psikutas)" )
  r( "2. [Hearthstone]" )
  rf.rolling_popup.should_be_hidden()

  -- When
  rf.loot_frame.click( 1 )

  -- Then
  rf.loot_frame.should_display(
    selected_item( 1, "Bag", "SR", { "Soft-ressed by", "Jimmy", "Obszczymucha", "Psikutas" } ),
    selected_item( 2, "Bag", "SR", { "Soft-ressed by", "Jimmy", "Obszczymucha", "Psikutas" } ),
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
  rw( "Roll for 2x[Bag]: SR by Jimmy, Obszczymucha and Psikutas. 2 top rolls win." )
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
  r( "Stopping rolls in 3" )

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
  r( "2" )

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
  r( "1" )

  -- When
  rf.ace_timer.repeating_tick()

  -- Then
  r( "SR rolls remaining: Jimmy (1 roll), Obszczymucha (1 roll) and Psikutas (1 roll)" )
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
  c( "RollFor: Obszczymucha rolled the highest (99) for [Bag] (SR)." )
  r( "Obszczymucha rolled the highest (99) for [Bag] (SR)." )
  c( "RollFor: Jimmy rolled the next highest (98) for [Bag] (SR)." )
  r( "Jimmy rolled the next highest (98) for [Bag] (SR)." )
  c( "RollFor: Rolling for [Bag] finished." )
  rf.rolling_popup.should_display(
    item_link( item2, 2 ),
    softres_roll( p2, 99, 11 ),
    softres_roll( p3, 98 ),
    softres_roll( p1, 69 ),
    text( "Obszczymucha wins the soft-res roll with 99.", 11 ),
    individual_award_button,
    text( "Jimmy wins the soft-res roll with 98.", 8 ),
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
  c( "RollFor: Obszczymucha received [Bag]." )
  rf.loot_frame.should_display(
    selected_item( 1, "Bag", "SR", { "Soft-ressed by", "Jimmy", "Obszczymucha", "Psikutas" } ),
    disabled_item( 2, "Hearthstone" )
  )
  rf.rolling_popup.should_display(
    item_link( item2, 1 ),
    softres_roll( p2, 99, 11 ),
    softres_roll( p3, 98 ),
    softres_roll( p1, 69 ),
    text( "Jimmy wins the soft-res roll with 98.", 11 ),
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
  c( "RollFor: Jimmy received [Bag]." )

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
    enabled_item( 1, "Bag", "SR", { "Soft-ressed by", "Psikutas" } ),
    enabled_item( 2, "Hearthstone" )
  )
  r( "Princess Kenny dropped 2 items:" )
  r( "1. [Bag] (SR by Psikutas)" )
  r( "2. [Hearthstone]" )
  rf.rolling_popup.should_be_hidden()

  -- When
  rf.loot_frame.click( 1 )

  -- Then
  rf.loot_frame.should_display(
    selected_item( 1, "Bag", "SR", { "Soft-ressed by", "Psikutas" } ),
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
  local c, r, rw = chat.console, chat.raid, chat.raid_warning
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
    enabled_item( 1, "Bag", "SR", { "Soft-ressed by", "Obszczymucha", "Psikutas" } ),
    enabled_item( 2, "Hearthstone" )
  )
  r( "Princess Kenny dropped 2 items:" )
  r( "1. [Bag] (SR by Obszczymucha and Psikutas)" )
  r( "2. [Hearthstone]" )
  rf.rolling_popup.should_be_hidden()

  -- When
  rf.loot_frame.click( 1 )

  -- Then
  rf.loot_frame.should_display(
    selected_item( 1, "Bag", "SR", { "Soft-ressed by", "Obszczymucha", "Psikutas" } ),
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
  rw( "Roll for [Bag]: SR by Obszczymucha and Psikutas" )
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
  c( "RollFor: Obszczymucha and Psikutas rolled the highest (69) for [Bag] (SR)." )
  r( "Obszczymucha and Psikutas rolled the highest (69) for [Bag] (SR)." )
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
  r( "Obszczymucha and Psikutas /roll for [Bag] now." )
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
  c( "RollFor: Obszczymucha and Psikutas re-rolled the highest (42) for [Bag] (SR)." )
  r( "Obszczymucha and Psikutas re-rolled the highest (42) for [Bag] (SR)." )
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
  r( "Obszczymucha and Psikutas /roll for [Bag] now." )
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
  c( "RollFor: Psikutas re-rolled the highest (2) for [Bag] (SR)." )
  r( "Psikutas re-rolled the highest (2) for [Bag] (SR)." )
  c( "RollFor: Rolling for [Bag] finished." )
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
    text( "Psikutas wins the soft-res roll with 2.", 11 ),
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
    text( "Psikutas wins the soft-res roll with 2.", 11 ),
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
  c( "RollFor: Psikutas received [Bag]." )
  rf.loot_frame.should_display(
    enabled_item( 1, "Hearthstone" )
  )
end

function SoftResTieRollSpec:should_not_tie_roll_if_sring_player_rolls_the_same_amount()
  -- Given
  local loot_facade, chat = mock_loot_facade(), mock_chat()
  local c, r, rw = chat.console, chat.raid, chat.raid_warning
  local item, p1, p2 = i( "Bag", 69 ), p( "Maulfunction" ), p( "Goldblood" )
  local rf = new_roll_for()
      :loot_facade( loot_facade )
      :raid_roster( p1, p2 )
      :chat( chat )
      :soft_res_data( sr( p1.name, 69 ), sr( p1.name, 69 ), sr( p2.name, 69 ) )
      :build()
  u.mock( "GiveMasterLoot", function( slot ) loot_facade.notify( "LootSlotCleared", slot ) end )

  -- Then
  rf.loot_frame.should_be_hidden()

  -- When
  loot_facade.notify( "LootOpened", item )

  -- Then
  rf.loot_frame.should_display(
    enabled_item( 1, "Bag", "SR", { "Soft-ressed by", "Goldblood", "Maulfunction [2 rolls]" } )
  )
  r( "Princess Kenny dropped 1 item:" )
  r( "1. [Bag] (SR by Goldblood and Maulfunction [2 rolls])" )
  rf.rolling_popup.should_be_hidden()

  -- When
  rf.loot_frame.click( 1 )

  -- Then
  rf.loot_frame.should_display(
    selected_item( 1, "Bag", "SR", { "Soft-ressed by", "Goldblood", "Maulfunction [2 rolls]" } )
  )
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
  rw( "Roll for [Bag]: SR by Goldblood and Maulfunction [2 rolls]" )
  rf.rolling_popup.should_display(
    item_link( item, 1 ),
    roll_placeholder( p2, 11 ),
    roll_placeholder( p1 ),
    roll_placeholder( p1 ),
    text( "Rolling ends in 8 seconds.", 11 ),
    buttons( "Cancel" )
  )

  -- When
  rf.ace_timer.tick()
  rf.ace_timer.tick()
  rf.ace_timer.tick()
  rf.roll( p1, 90, 1, 100 ) -- Maulfunction
  rf.roll( p1, 90, 1, 100 ) -- Maulfunction (same amount again)
  rf.ace_timer.tick()
  rf.roll( p2, 80, 1, 100 ) -- Goldblood

  -- Then
  c( "RollFor: Maulfunction rolled the highest (90) for [Bag] (SR)." )
  r( "Maulfunction rolled the highest (90) for [Bag] (SR)." )
  c( "RollFor: Rolling for [Bag] finished." )
  rf.rolling_popup.should_display(
    item_link( item, 1 ),
    softres_roll( p1, 90, 11 ),
    softres_roll( p1, 90 ),
    softres_roll( p2, 80 ),
    text( "Maulfunction wins the soft-res roll with 90.", 11 ),
    buttons( "AwardWinner", "RaidRoll", "AwardOther", "Close" )
  )
end

SrCountEqualsItemCountSpec = {}

function SrCountEqualsItemCountSpec:should_not_show_sr_placeholders_when_sr_player_count_equals_item_count()
  -- Given
  local loot_facade, chat = mock_loot_facade(), mock_chat()
  local item, item2, p1, p2 = i( "Bag", 69 ), i( "Hearthstone", 123 ), p( "Psikutas" ), p( "Obszczymucha" )
  local rf = new_roll_for()
      :loot_facade( loot_facade )
      :raid_roster( p1, p2 )
      :chat( chat )
      :soft_res_data( sr( p1.name, 69 ), sr( p2.name, 69 ) )
      :build()
  u.mock( "GiveMasterLoot", function( slot ) loot_facade.notify( "LootSlotCleared", slot ) end )

  -- When
  loot_facade.notify( "LootOpened", item, item, item2 )
  rf.loot_frame.click( 1 )

  -- Then (preview shows winners directly without Roll button and without placeholders)
  rf.rolling_popup.should_display(
    item_link( item, 2 ),
    text( "Obszczymucha soft-ressed this item.", 11 ),
    individual_award_button,
    text( "Psikutas soft-ressed this item.", 8 ),
    individual_award_button,
    buttons( "AwardOther", "Close" )
  )

  -- When (simulating /rf 2x[Bag])
  rf.roll_controller.start( "SoftResRoll", item, 2, 8 )

  -- Then (popup shows winners without SR placeholder rolls)
  rf.rolling_popup.should_display(
    item_link( item, 2 ),
    text( "Obszczymucha soft-ressed this item.", 11 ),
    individual_award_button,
    text( "Psikutas soft-ressed this item.", 8 ),
    individual_award_button,
    buttons( "RaidRoll", "AwardOther", "Close" )
  )
end

TwoSrPlayersThreeItemsSpec = {}

function TwoSrPlayersThreeItemsSpec:should_handle_two_sr_players_with_three_items()
  -- Given
  local loot_facade, chat = mock_loot_facade(), mock_chat()
  local item, p1, p2 = i( "Bag", 69 ), p( "Psikutas" ), p( "Obszczymucha" )
  local rf = new_roll_for()
      :loot_facade( loot_facade )
      :raid_roster( p1, p2 )
      :chat( chat )
      :soft_res_data( sr( p1.name, 69 ), sr( p2.name, 69 ) )
      :build()

  -- When (simulating /rf 3x[Bag])
  rf.roll_controller.start( "SoftResRoll", item, 3, 8 )

  -- Then
  rf.rolling_popup.should_display(
    item_link( item, 3 ),
    text( "Obszczymucha soft-ressed this item.", 11 ),
    text( "Psikutas soft-ressed this item.", 2 ),
    buttons( "RaidRoll", "Close" )
  )
end

function TwoSrPlayersThreeItemsSpec:should_show_award_buttons_when_looting_and_clicking()
  -- Given
  local loot_facade, chat = mock_loot_facade(), mock_chat()
  local item, p1, p2 = i( "Bag", 69 ), p( "Psikutas" ), p( "Obszczymucha" )
  local rf = new_roll_for()
      :loot_facade( loot_facade )
      :raid_roster( p1, p2 )
      :chat( chat )
      :soft_res_data( sr( p1.name, 69 ), sr( p2.name, 69 ) )
      :build()
  u.mock( "GiveMasterLoot", function( slot ) loot_facade.notify( "LootSlotCleared", slot ) end )

  -- When
  loot_facade.notify( "LootOpened", item, item, item )
  rf.loot_frame.click( 1 )

  -- Then (loot frame groups only 2 bags for the 2 SR players, leaving the 3rd for normal rolling)
  rf.rolling_popup.should_display(
    item_link( item, 2 ),
    text( "Obszczymucha soft-ressed this item.", 11 ),
    individual_award_button,
    text( "Psikutas soft-ressed this item.", 8 ),
    individual_award_button,
    buttons( "AwardOther", "Close" )
  )
end

NetherVortexSpec = {}

function NetherVortexSpec:should_handle_single_and_double_vortex_drops_across_multiple_looting_sessions()
  -- Given
  -- Alfa and Beta have 3xSR on Nether Vortex, Gamma has none.
  local loot_facade, chat = mock_loot_facade(), mock_chat()
  local c, r, rw = chat.console, chat.raid, chat.raid_warning
  local p1, p2, p3 = p( "Alfa" ), p( "Beta" ), p( "Gamma" )
  local single_vortex = i( "Nether Vortex", 30183 )
  local double_vortex = i( "Nether Vortex", 30183 )
  double_vortex.quantity = 2
  local rf = new_roll_for()
      :loot_facade( loot_facade )
      :raid_roster( p1, p2, p3 )
      :chat( chat )
      :soft_res_data(
        sr( p1.name, 30183 ), sr( p1.name, 30183 ), sr( p1.name, 30183 ),
        sr( p2.name, 30183 ), sr( p2.name, 30183 ), sr( p2.name, 30183 )
      )
      :build()
  u.mock( "GiveMasterLoot", function( slot ) loot_facade.notify( "LootSlotCleared", slot ) end )

  -- ===== Drop 1: Single vortex. Both Alfa and Beta are eligible. =====
  loot_facade.notify( "LootOpened", single_vortex )

  -- Then
  rf.loot_frame.should_display(
    enabled_item( 1, "Nether Vortex", "SR", { "Soft-ressed by", "Alfa", "Beta" } )
  )
  r( "Princess Kenny dropped 1 item:" )
  r( "1. [Nether Vortex] (SR by Alfa and Beta)" )

  -- When
  rf.loot_frame.click( 1 )

  -- Then
  rf.rolling_popup.should_display(
    item_link( single_vortex, 1 ),
    roll_placeholder( p1, 11 ),
    roll_placeholder( p2 ),
    buttons( "Roll", "AwardOther", "Close" )
  )

  -- When
  rf.rolling_popup.click( "Roll" )

  -- Then
  rw( "Roll for [Nether Vortex]: SR by Alfa and Beta" )

  -- When both roll
  rf.roll( p1, 80, 1, 100 )
  rf.roll( p2, 50, 1, 100 )

  -- Then Alfa wins
  c( "RollFor: Alfa rolled the highest (80) for [Nether Vortex] (SR)." )
  r( "Alfa rolled the highest (80) for [Nether Vortex] (SR)." )
  c( "RollFor: Rolling for [Nether Vortex] finished." )
  rf.rolling_popup.should_display(
    item_link( single_vortex, 1 ),
    softres_roll( p1, 80, 11 ),
    softres_roll( p2, 50 ),
    text( "Alfa wins the soft-res roll with 80.", 11 ),
    buttons( "AwardWinner", "RaidRoll", "AwardOther", "Close" )
  )

  -- When award Alfa
  rf.rolling_popup.click( "AwardWinner" )
  rf.confirmation_popup.confirm()

  -- Then
  c( "RollFor: Alfa received [Nether Vortex]." )
  rf.loot_frame.should_display()

  -- Close loot
  loot_facade.notify( "LootClosed" )
  rf.reset_announcements()

  -- ===== Drop 2: Single vortex. Only Beta is eligible (Alfa was awarded single). =====
  loot_facade.notify( "LootOpened", single_vortex )

  -- Then
  rf.loot_frame.should_display(
    enabled_item( 1, "Nether Vortex", "SR", { "Soft-ressed by", "Beta" } )
  )
  r( "Princess Kenny dropped 1 item:" )
  r( "1. [Nether Vortex] (SR by Beta)" )

  -- When
  rf.loot_frame.click( 1 )

  -- Then Beta is the sole soft-resser
  rf.rolling_popup.should_display(
    item_link( single_vortex, 1 ),
    text( "Beta soft-ressed this item.", 11 ),
    buttons( "AwardWinner", "AwardOther", "Close" )
  )

  -- When award Beta
  rf.rolling_popup.click( "AwardWinner" )
  rf.confirmation_popup.confirm()

  -- Then
  c( "RollFor: Beta received [Nether Vortex]." )
  rf.loot_frame.should_display()

  -- Close loot
  loot_facade.notify( "LootClosed" )
  rf.reset_announcements()

  -- ===== Drop 3: Single vortex. No SR players left. All three can roll. =====
  loot_facade.notify( "LootOpened", single_vortex )

  -- Then
  rf.loot_frame.should_display(
    enabled_item( 1, "Nether Vortex" )
  )
  r( "Princess Kenny dropped 1 item:" )
  r( "1. [Nether Vortex]" )

  -- When
  rf.loot_frame.click( 1 )

  -- Then no SR players - normal roll buttons
  rf.rolling_popup.should_display(
    item_link( single_vortex, 1 ),
    buttons( "Roll", "InstaRaidRoll", "AwardOther", "Close" )
  )

  -- Close loot
  loot_facade.notify( "LootClosed" )
  rf.reset_announcements()

  -- ===== Drop 4: Double vortex. Alfa and Beta are both eligible for double. =====
  loot_facade.notify( "LootOpened", double_vortex )

  -- Then
  rf.loot_frame.should_display(
    enabled_item( 1, "Nether Vortex", "SR", { "Soft-ressed by", "Alfa", "Beta" }, nil, 2 )
  )
  r( "Princess Kenny dropped 1 item:" )
  r( "1. [Nether Vortex] (SR by Alfa and Beta)" )

  -- When
  rf.loot_frame.click( 1 )

  -- Then both are eligible for double despite having won single
  rf.rolling_popup.should_display(
    item_link( double_vortex, 1 ),
    roll_placeholder( p1, 11 ),
    roll_placeholder( p2 ),
    buttons( "Roll", "AwardOther", "Close" )
  )

  -- When
  rf.rolling_popup.click( "Roll" )

  -- Then
  rw( "Roll for [Nether Vortex]: SR by Alfa and Beta" )

  -- When both roll
  rf.roll( p1, 30, 1, 100 )
  rf.roll( p2, 90, 1, 100 )

  -- Then Beta wins
  c( "RollFor: Beta rolled the highest (90) for [Nether Vortex] (SR)." )
  r( "Beta rolled the highest (90) for [Nether Vortex] (SR)." )
  c( "RollFor: Rolling for [Nether Vortex] finished." )
  rf.rolling_popup.should_display(
    item_link( double_vortex, 1 ),
    softres_roll( p2, 90, 11 ),
    softres_roll( p1, 30 ),
    text( "Beta wins the soft-res roll with 90.", 11 ),
    buttons( "AwardWinner", "RaidRoll", "AwardOther", "Close" )
  )
end

ThreeIdenticalItemsOneSrSpec = {}

function ThreeIdenticalItemsOneSrSpec:should_auto_loot_three_items_then_rf_command()
  -- Given
  local loot_facade, chat = mock_loot_facade(), mock_chat()
  local c, r, rw = chat.console, chat.raid, chat.raid_warning
  local item, item2, item3 = i( "Bag", 69 ), i( "Bag", 69 ), i( "Bag", 69 )
  local p1, p2, p3, p4 = p( "Psikutas" ), p( "Obszczymucha" ), p( "Jimmy" ), p( "Pumba" )
  local rf = new_roll_for()
      :loot_facade( loot_facade )
      :raid_roster( p1, p2, p3, p4 )
      :chat( chat )
      :soft_res_data( sr( p1.name, 69 ) )
      :config( {
        auto_loot = true,
        auto_loot_messages = true,
        tmog_rolling_enabled = false
      } )
      :build()

  local id = rf.auto_loot.add_category( "global" )
  rf.auto_loot.add( id, item.link )
  lu.assertEquals( rf.auto_loot.is_auto_looted( item ), true )
  lu.assertEquals( rf.auto_loot.is_auto_looted( item2 ), true )
  lu.assertEquals( rf.auto_loot.is_auto_looted( item3 ), true )

  c( "RollFor: Category global added with ID 1." )
  c( "RollFor: [Bag] added to global." )

  u.mock_table_function( "UnitName", { player = "Psikutas", target = "Princess Kenny" } )
  u.mock_master_loot_candidates( { "Psikutas", "Obszczymucha", "Jimmy", "Pumba" } )
  local master_loot = u.mock_async_master_loot( loot_facade )

  -- When
  loot_facade.notify( "LootOpened", item, item2, item3 )
  master_loot.flush()

  -- Then (the SR item is announced separately, the two non-SR identical items are grouped)
  r( "Princess Kenny dropped 3 items:" )
  r( "1. [Bag] (SR by Psikutas)" )
  r( "2. 2x[Bag]" )
  c( "RollFor: Auto-looting [Bag]." )
  c( "RollFor: Auto-looting [Bag]." )
  c( "RollFor: Auto-looting [Bag]." )
  rf.loot_frame.should_display()
  rf.rolling_popup.should_be_hidden()

  -- When (simulating /rf 3x[Bag])
  rf.roll_controller.start( "SoftResRoll", item, 3, 8 )

  -- Then (the single soft-resser wins one copy outright, and the remaining two go to a normal roll)
  rw( "Psikutas soft-ressed [Bag]." )
  rw( "Roll for 2x[Bag]: /roll (MS) or /roll 99 (OS). 2 top rolls win." )

  -- When (everyone rolls; Psikutas already won his via soft-res, so his roll is ignored)
  rf.roll( p1, 95, 1, 100 ) -- Psikutas (ignored, already won via SR)
  c( "RollFor: Psikutas already won [Bag] via soft-res. This roll (95) is ignored." )
  rf.roll( p2, 80, 1, 100 ) -- Obszczymucha
  rf.roll( p3, 70, 1, 100 ) -- Jimmy
  rf.roll( p4, 60, 1, 100 ) -- Pumba

  -- Then (all three winners are announced at the end: the soft-resser first, then the top two rollers)
  rw( "Psikutas soft-ressed [Bag]." )
  c( "RollFor: Obszczymucha rolled the highest (80) for [Bag]." )
  r( "Obszczymucha rolled the highest (80) for [Bag]." )
  c( "RollFor: Jimmy rolled the next highest (70) for [Bag]." )
  r( "Jimmy rolled the next highest (70) for [Bag]." )
  c( "RollFor: Rolling for [Bag] finished." )

  -- Then (popup lists all winners: the soft-resser first, then the two roll winners)
  rf.rolling_popup.should_display(
    item_link( item, 2 ),
    mainspec_roll( p2, 80, 11 ),
    mainspec_roll( p3, 70 ),
    mainspec_roll( p4, 60 ),
    text( "Psikutas soft-ressed this item.", 11 ),
    text( "Obszczymucha wins the main-spec roll with 80.", 2 ),
    text( "Jimmy wins the main-spec roll with 70.", 2 ),
    buttons( "RaidRoll", "Close" )
  )
end

ThreeIdenticalItemsTwoSrSpec = {}

function ThreeIdenticalItemsTwoSrSpec:should_auto_loot_three_items_then_rf_command()
  -- Given
  local loot_facade, chat = mock_loot_facade(), mock_chat()
  local c, r, rw = chat.console, chat.raid, chat.raid_warning
  local item, item2, item3 = i( "Bag", 69 ), i( "Bag", 69 ), i( "Bag", 69 )
  local p1, p2, p3, p4 = p( "Psikutas" ), p( "Obszczymucha" ), p( "Jimmy" ), p( "Pumba" )
  local rf = new_roll_for()
      :loot_facade( loot_facade )
      :raid_roster( p1, p2, p3, p4 )
      :chat( chat )
      :soft_res_data( sr( p1.name, 69 ), sr( p2.name, 69 ) )
      :config( {
        auto_loot = true,
        auto_loot_messages = true,
        tmog_rolling_enabled = false
      } )
      :build()

  local id = rf.auto_loot.add_category( "global" )
  rf.auto_loot.add( id, item.link )
  lu.assertEquals( rf.auto_loot.is_auto_looted( item ), true )
  lu.assertEquals( rf.auto_loot.is_auto_looted( item2 ), true )
  lu.assertEquals( rf.auto_loot.is_auto_looted( item3 ), true )

  c( "RollFor: Category global added with ID 1." )
  c( "RollFor: [Bag] added to global." )

  u.mock_table_function( "UnitName", { player = "Psikutas", target = "Princess Kenny" } )
  u.mock_master_loot_candidates( { "Psikutas", "Obszczymucha", "Jimmy", "Pumba" } )
  local master_loot = u.mock_async_master_loot( loot_facade )

  -- When
  loot_facade.notify( "LootOpened", item, item2, item3 )
  master_loot.flush()

  -- Then (with two soft-ressers and three copies, each soft-ressed copy is announced separately and the leftover as a plain drop)
  r( "Princess Kenny dropped 3 items:" )
  r( "1. [Bag] (SR by Obszczymucha)" )
  r( "2. [Bag] (SR by Psikutas)" )
  r( "3. [Bag]" )
  c( "RollFor: Auto-looting [Bag]." )
  c( "RollFor: Auto-looting [Bag]." )
  c( "RollFor: Auto-looting [Bag]." )
  rf.loot_frame.should_display()
  rf.rolling_popup.should_be_hidden()

  -- When (simulating /rf 3x[Bag])
  rf.roll_controller.start( "SoftResRoll", item, 3, 8 )

  -- Then (both soft-ressers win a copy outright, the remaining one goes to a normal roll)
  rw( "Obszczymucha and Psikutas soft-ressed [Bag]." )
  rw( "Roll for [Bag]: /roll (MS) or /roll 99 (OS)" )

  -- When (everyone rolls; Psikutas and Obszczymucha already won theirs via soft-res, so their rolls are ignored)
  rf.roll( p1, 95, 1, 100 ) -- Psikutas (ignored)
  c( "RollFor: Psikutas already won [Bag] via soft-res. This roll (95) is ignored." )
  rf.roll( p2, 80, 1, 100 ) -- Obszczymucha (ignored)
  c( "RollFor: Obszczymucha already won [Bag] via soft-res. This roll (80) is ignored." )
  rf.roll( p3, 70, 1, 100 ) -- Jimmy
  rf.roll( p4, 60, 1, 100 ) -- Pumba

  -- Then (all three winners announced at the end: the two soft-ressers first, then the roll winner)
  rw( "Obszczymucha and Psikutas soft-ressed [Bag]." )
  c( "RollFor: Jimmy rolled the highest (70) for [Bag]." )
  r( "Jimmy rolled the highest (70) for [Bag]." )
  c( "RollFor: Rolling for [Bag] finished." )

  -- Then (popup lists all winners: the two soft-ressers first, then the roll winner)
  rf.rolling_popup.should_display(
    item_link( item, 1 ),
    mainspec_roll( p3, 70, 11 ),
    mainspec_roll( p4, 60 ),
    text( "Obszczymucha soft-ressed this item.", 11 ),
    text( "Psikutas soft-ressed this item.", 2 ),
    text( "Jimmy wins the main-spec roll with 70.", 2 ),
    buttons( "RaidRoll", "Close" )
  )
end

AwardedLootSpec = {}

function AwardedLootSpec:should_award_the_sr_item_then_roll_for_the_rest()
  -- Given
  local loot_facade, chat = mock_loot_facade(), mock_chat()
  local c, r, rw = chat.console, chat.raid, chat.raid_warning
  local item, item2 = i( "Bag", 69 ), i( "Bag", 69 )
  local p1, p2, p3 = p( "Psikutas" ), p( "Obszczymucha" ), p( "Jimmy" )
  local rf = new_roll_for()
      :loot_facade( loot_facade )
      :raid_roster( p1, p2, p3 )
      :chat( chat )
      :soft_res_data( sr( p1.name, 69 ) )
      :config( {
        auto_loot = true,
        auto_loot_messages = true,
        tmog_rolling_enabled = false
      } )
      :build()

  local id = rf.auto_loot.add_category( "global" )
  rf.auto_loot.add( id, item.link )
  lu.assertEquals( rf.auto_loot.is_auto_looted( item ), true )
  lu.assertEquals( rf.auto_loot.is_auto_looted( item2 ), true )

  c( "RollFor: Category global added with ID 1." )
  c( "RollFor: [Bag] added to global." )

  u.mock_table_function( "UnitName", { player = "Psikutas", target = "Princess Kenny" } )
  u.mock_master_loot_candidates( { "Psikutas", "Obszczymucha", "Jimmy" } )
  local master_loot = u.mock_async_master_loot( loot_facade )

  -- When (the two identical items drop and are auto-looted)
  loot_facade.notify( "LootOpened", item, item2 )
  master_loot.flush()

  -- Then
  r( "Princess Kenny dropped 2 items:" )
  r( "1. [Bag] (SR by Psikutas)" )
  r( "2. [Bag]" )
  c( "RollFor: Auto-looting [Bag]." )
  c( "RollFor: Auto-looting [Bag]." )
  rf.loot_frame.should_display()
  rf.rolling_popup.should_be_hidden()

  -- When (we /award one copy to the soft-resser)
  u.slash( "award", p1.name, item.link )

  -- Then
  c( "RollFor: Psikutas was awarded [Bag]." )

  -- When (we /rf [Item] for the remaining copy)
  rf.roll_controller.start( "SoftResRoll", item, 1, 1, 8 )

  -- Then (Psikutas' soft-res was fulfilled by the award, so this is a plain
  -- normal roll - no soft-res announcement)
  rw( "Roll for [Bag]: /roll (MS) or /roll 99 (OS)" )

  -- When (everyone rolls; Psikutas may roll normally now that his SR is fulfilled)
  rf.roll( p1, 95, 1, 100 ) -- Psikutas
  rf.roll( p2, 80, 1, 100 ) -- Obszczymucha
  rf.roll( p3, 70, 1, 100 ) -- Jimmy

  -- Then (Psikutas wins the leftover copy outright with the highest roll)
  c( "RollFor: Psikutas rolled the highest (95) for [Bag]." )
  r( "Psikutas rolled the highest (95) for [Bag]." )
  c( "RollFor: Rolling for [Bag] finished." )

  -- Then (the popup shows a normal roll won by Psikutas)
  rf.rolling_popup.should_display(
    item_link( item, 1 ),
    mainspec_roll( p1, 95, 11 ),
    mainspec_roll( p2, 80 ),
    mainspec_roll( p3, 70 ),
    text( "Psikutas wins the main-spec roll with 95.", 11 ),
    buttons( "RaidRoll", "Close" )
  )
end

function AwardedLootSpec:should_restore_the_soft_res_after_unawarding()
  -- Given
  local loot_facade, chat = mock_loot_facade(), mock_chat()
  local c, rw = chat.console, chat.raid_warning
  local item = i( "Bag", 69 )
  local p1, p2, p3 = p( "Psikutas" ), p( "Obszczymucha" ), p( "Jimmy" )
  local rf = new_roll_for()
      :loot_facade( loot_facade )
      :raid_roster( p1, p2, p3 )
      :chat( chat )
      :soft_res_data( sr( p1.name, 69 ) )
      :config( { tmog_rolling_enabled = false } )
      :build()

  -- When (we /award the item to the soft-resser)
  u.slash( "award", p1.name, item.link )
  c( "RollFor: Psikutas was awarded [Bag]." )

  -- When (we /unaward it again)
  u.slash( "unaward", p1.name, item.link )
  c( "RollFor: Psikutas was unawarded [Bag]." )

  -- When (we /rf [Item]; the soft-res should be restored now)
  rf.roll_controller.start( "SoftResRoll", item, 1, 1, 8 )

  -- Then (the soft-res is restored, so Psikutas wins the copy outright via SR -
  -- no normal roll happens, unlike when the award stands)
  rw( "Psikutas soft-ressed [Bag]." )

  rf.rolling_popup.should_display(
    item_link( item, 1 ),
    text( "Psikutas soft-ressed this item.", 11 ),
    buttons( "RaidRoll", "Close" )
  )
end

os.exit( lu.LuaUnit.run() )
