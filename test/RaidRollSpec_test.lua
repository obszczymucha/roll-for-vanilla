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

SingleWinnerRaidRollSpec = {}

function SingleWinnerRaidRollSpec:should_auto_raid_roll_if_no_one_rolled()
  -- Given
  local loot_facade, chat = mock_loot_facade(), mock_chat()
  local item, item2, item3, p1, p2 = i( "Hearthstone", 123 ), i( "Bag", 69 ), i( "Sword", 42 ), p( "Psikutas" ), p( "Obszczymucha" )
  local rf = new_roll_for()
      :loot_facade( loot_facade )
      :raid_roster( p1, p2 )
      :chat( chat )
      :config( { auto_raid_roll = true } )
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
    buttons( "Roll", "RaidRoll", "AwardOther", "Close" )
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
  rf.ace_timer.repeating_tick( 8 )

  -- Then
  chat.raid( "Stopping rolls in 3" )
  chat.raid( "2" )
  chat.raid( "1" )
  chat.console( "RollFor: No one rolled for [Bag]." )
  chat.raid( "No one rolled for [Bag]." )
  chat.raid( "Raid rolling [Bag]..." )
  rf.rolling_popup.should_display(
    item_link( item2, 1 ),
    text( "Raid rolling...", 11 ),
    empty_line( 5 )
  )

  -- When
  rf.ace_timer.repeating_tick( 1 )

  -- Then
  chat.raid( "[1]:Obszczymucha, [2]:Psikutas" )

  -- When
  rf.roll( p1, 1, 1, 2 ) -- Not great, but I gotta get things moving, cuz Netherwing 3.0.

  -- Then
  chat.raid( "Obszczymucha wins [Bag] (raid-roll)." )
  rf.rolling_popup.should_display(
    item_link( item2, 1 ),
    text( "Obszczymucha wins the raid-roll.", 11 ),
    buttons( "AwardWinner", "RaidRollAgain", "AwardOther", "Close" )
  )

  -- When
  rf.rolling_popup.click( "Close" )
  loot_facade.notify( "LootClosed" )
  loot_facade.notify( "LootOpened", item3 )

  -- Then
  rf.loot_frame.should_display(
    enabled_item( 1, "Sword" )
  )
  rf.rolling_popup.should_be_hidden()
end

function SingleWinnerRaidRollSpec:should_raid_roll_if_no_one_rolled()
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
    buttons( "Roll", "RaidRoll", "AwardOther", "Close" )
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
  rf.ace_timer.repeating_tick( 8 )

  -- Then
  chat.raid( "Stopping rolls in 3" )
  chat.raid( "2" )
  chat.raid( "1" )
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
  rf.rolling_popup.should_display(
    item_link( item2, 1 ),
    text( "Raid rolling...", 11 ),
    empty_line( 5 )
  )
end

function SingleWinnerRaidRollSpec:should_auto_raid_roll_if_no_one_rolled_and_reproduce_a_bug()
  -- Given
  local loot_facade, chat = mock_loot_facade(), mock_chat()
  local item, item2, p1, p2 = i( "Hearthstone", 123 ), i( "Bag", 69 ), p( "Psikutas" ), p( "Obszczymucha" )
  local rf = new_roll_for()
      :loot_facade( loot_facade )
      :raid_roster( p1, p2 )
      :chat( chat )
      :config( { auto_raid_roll = true } )
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
    buttons( "Roll", "RaidRoll", "AwardOther", "Close" )
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
  rf.ace_timer.repeating_tick( 7 )

  -- Then
  chat.raid( "Stopping rolls in 3" )
  chat.raid( "2" )
  chat.raid( "1" )
  rf.rolling_popup.should_display(
    item_link( item2, 1 ),
    text( "Rolling ends in 1 second.", 11 ),
    buttons( "Cancel" )
  )

  -- When
  loot_facade.notify( "LootClosed" )

  -- Then
  rf.loot_frame.should_be_hidden()

  -- When
  rf.ace_timer.repeating_tick( 1 )

  -- Then
  chat.console( "RollFor: No one rolled for [Bag]." )
  chat.raid( "No one rolled for [Bag]." )
  chat.raid( "Raid rolling [Bag]..." )
  rf.rolling_popup.should_display(
    item_link( item2, 1 ),
    text( "Raid rolling...", 11 ),
    empty_line( 5 )
  )

  -- When
  rf.ace_timer.repeating_tick( 1 )

  -- Then
  chat.raid( "[1]:Obszczymucha, [2]:Psikutas" )

  -- When
  rf.roll( p1, 1, 1, 2 ) -- Not great, but I gotta get things moving, cuz Netherwing 3.0.

  -- Then
  chat.raid( "Obszczymucha wins [Bag] (raid-roll)." )
  rf.rolling_popup.should_display(
    item_link( item2, 1 ),
    text( "Obszczymucha wins the raid-roll.", 11 ),
    buttons( "RaidRollAgain", "Close" )
  )

  -- When
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
end

os.exit( lu.LuaUnit.run() )
