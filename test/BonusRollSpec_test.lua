package.path = "./?.lua;" .. package.path .. ";../?.lua;../RollFor/?.lua"

require( "src/bcc/compat" )
local u = require( "test/utils" )
local lu, eq = u.luaunit( "assertEquals" )
local builder = require( "test/IntegrationTestBuilder" )
local mock_loot_facade, mock_chat, new_roll_for = builder.mock_loot_facade, builder.mock_chat, builder.new_roll_for
local i, p = builder.i, builder.p
local gui = require( "test/gui_helpers" )
local item_link, text, buttons = gui.item_link, gui.text, gui.buttons
local sr_row, sr_roll_placeholder = gui.sr_row, gui.sr_roll_placeholder
local bonus_roll_placeholder = gui.bonus_roll_placeholder
local sr = u.soft_res_item

local SHAHRAZ = "Mother Shahraz"
local COUNCIL = "The Illidari Council"

-- Real catalogue ids: the bonus allowance is resolved through AutoLootDb, so made-up ids
-- would prove nothing but that unknown items grant nothing.
local PENDANT = 32370 -- Nadina's Pendant of Purity, Mother Shahraz
local CLOAK = 32331   -- Cloak of the Illidari Council

---@param name string
---@param item_id number
local function br( name, item_id ) return { name = name, item_id = item_id } end

BonusRollSpec = {}

-- A bonus roll is an extra cell on the soft-resser's own row, and the gold pip leads so
-- it renders to the left of the white one.
function BonusRollSpec:should_show_a_bonus_placeholder_in_the_preview_for_an_eligible_soft_resser()
  -- Given
  local loot_facade, chat = mock_loot_facade(), mock_chat()
  local item, p1, p2 = i( "Nadina's Pendant of Purity", PENDANT ), p( "Drutree" ), p( "Mendunia" )
  local rf = new_roll_for()
      :loot_facade( loot_facade )
      :raid_roster( p1, p2 )
      :chat( chat )
      :soft_res_data( sr( p1.name, PENDANT ), sr( p2.name, PENDANT ) )
      :bonus_rolls( { Drutree = { SHAHRAZ } } )
      :build()

  -- When
  loot_facade.notify( "LootOpened", item )
  rf.loot_frame.click( 1 )

  -- Then
  rf.rolling_popup.should_display(
    item_link( item, 1 ),
    bonus_roll_placeholder( p1, 11, 2 ),
    sr_roll_placeholder( p2, nil, 2 ),
    buttons( "Roll", "AwardOther", "Close" )
  )
end

-- The bonus roll is mandatory, exactly like an extra soft-res roll: rolling waits past the
-- timer for it rather than closing on the roll the player has already cast.
--
-- Drutree is behind when the timer runs out, which is the case that matters. A player who
-- is already winning can't change the result with the rolls he has left, and the existing
-- finish-early path closes on him -- bonus roll or not.
function BonusRollSpec:should_hold_the_roll_open_until_the_bonus_roll_is_cast()
  -- Given
  local loot_facade, chat = mock_loot_facade(), mock_chat()
  local c, r, rw = chat.console, chat.raid, chat.raid_warning
  local item, p1, p2 = i( "Nadina's Pendant of Purity", PENDANT ), p( "Drutree" ), p( "Mendunia" )
  local rf = new_roll_for()
      :loot_facade( loot_facade )
      :raid_roster( p1, p2 )
      :chat( chat )
      :soft_res_data( sr( p1.name, PENDANT ), sr( p2.name, PENDANT ) )
      :bonus_rolls( { Drutree = { SHAHRAZ } } )
      :build()

  loot_facade.notify( "LootOpened", item )
  rf.loot_frame.click( 1 )
  rf.rolling_popup.click( "Roll" )

  -- When (both cast their soft-res roll, Drutree behind, then the timer runs out)
  rf.roll( p1, 5, 1, 100 )
  rf.roll( p2, 40, 1, 100 )

  for _ = 1, 8 do rf.ace_timer.repeating_tick() end

  -- Then (Drutree still owes his bonus roll, so nobody has won yet)
  r( "Princess Kenny dropped 1 item:" )
  r( "1. [Nadina's Pendant of Purity] (SR by Drutree and Mendunia)" )
  rw( "Roll for [Nadina's Pendant of Purity]. SR by Drutree [1 roll +1 bonus] and Mendunia" )
  r( "Stopping rolls in 3" )
  r( "2" )
  r( "1" )
  r( "SR rolls remaining: Drutree (1 bonus roll)" )
  rf.rolling_popup.should_display(
    item_link( item, 1 ),
    sr_row( p2, { 40 }, 2, 11 ),
    sr_row( p1, { 5, { br = false } }, 2 ),
    text( "Waiting for remaining rolls...", 11 ),
    buttons( "FinishEarly", "Cancel" )
  )

  -- When
  rf.roll( p1, 10, 1, 100 )

  -- Then
  c( "RollFor: Drutree used a Bonus Roll on [Nadina's Pendant of Purity] (10). 0 left." )
  c( "RollFor: Mendunia rolled the highest (40) for [Nadina's Pendant of Purity] (SR)." )
  r( "Mendunia rolled the highest (40) for [Nadina's Pendant of Purity] (SR)." )
  c( "RollFor: Rolling for [Nadina's Pendant of Purity] finished." )
end

function BonusRollSpec:should_deduct_the_bonus_roll_from_the_registry_with_the_item_and_the_value()
  -- Given
  local loot_facade, chat = mock_loot_facade(), mock_chat()
  local item, p1, p2 = i( "Nadina's Pendant of Purity", PENDANT ), p( "Drutree" ), p( "Mendunia" )
  local rf = new_roll_for()
      :loot_facade( loot_facade )
      :raid_roster( p1, p2 )
      :chat( chat )
      :soft_res_data( sr( p1.name, PENDANT ), sr( p2.name, PENDANT ) )
      :bonus_rolls( { Drutree = { SHAHRAZ } } )
      :build()

  loot_facade.notify( "LootOpened", item )
  rf.loot_frame.click( 1 )
  rf.rolling_popup.click( "Roll" )

  -- When
  rf.roll( p1, 75, 1, 100 )
  rf.roll( p1, 10, 1, 100 )

  -- Then
  local entry = rf.bonus_roll_registry.get( "Drutree" )[ 1 ]
  eq( entry.boss_name, SHAHRAZ )
  eq( entry.used_on.item_id, PENDANT )
  eq( entry.used_on.item_link, item.link )
  eq( entry.used_on.roll, 10 )
  eq( rf.bonus_roll_registry.count( "Drutree" ), 0 )
end

-- The allowance has to be announced split. "Drutree [2 rolls]" would read as two soft-res
-- rolls, which is not what he has.
function BonusRollSpec:should_announce_the_bonus_allowance_separately_from_the_soft_res_rolls()
  -- Given
  local loot_facade, chat = mock_loot_facade(), mock_chat()
  local r, rw = chat.raid, chat.raid_warning
  local item, p1, p2 = i( "Nadina's Pendant of Purity", PENDANT ), p( "Drutree" ), p( "Mendunia" )
  local rf = new_roll_for()
      :loot_facade( loot_facade )
      :raid_roster( p1, p2 )
      :chat( chat )
      :soft_res_data( sr( p1.name, PENDANT ), sr( p2.name, PENDANT ) )
      :bonus_rolls( { Drutree = { SHAHRAZ } } )
      :build()

  loot_facade.notify( "LootOpened", item )
  rf.loot_frame.click( 1 )

  -- When
  rf.rolling_popup.click( "Roll" )

  -- Then
  r( "Princess Kenny dropped 1 item:" )
  r( "1. [Nadina's Pendant of Purity] (SR by Drutree and Mendunia)" )
  rw( "Roll for [Nadina's Pendant of Purity]. SR by Drutree [1 roll +1 bonus] and Mendunia" )
end

function BonusRollSpec:should_let_a_bonus_roll_win_and_report_it_as_br()
  -- Given
  local loot_facade, chat = mock_loot_facade(), mock_chat()
  local c, r, rw = chat.console, chat.raid, chat.raid_warning
  local item, p1, p2 = i( "Nadina's Pendant of Purity", PENDANT ), p( "Drutree" ), p( "Mendunia" )
  local rf = new_roll_for()
      :loot_facade( loot_facade )
      :raid_roster( p1, p2 )
      :chat( chat )
      :soft_res_data( sr( p1.name, PENDANT ), sr( p2.name, PENDANT ) )
      :bonus_rolls( { Drutree = { SHAHRAZ } } )
      :build()

  loot_facade.notify( "LootOpened", item )
  rf.loot_frame.click( 1 )
  rf.rolling_popup.click( "Roll" )

  -- When (Drutree's soft-res roll is worse than Mendunia's; his bonus roll is not)
  rf.roll( p1, 5, 1, 100 )
  rf.roll( p2, 40, 1, 100 )
  rf.roll( p1, 99, 1, 100 )

  -- Then
  r( "Princess Kenny dropped 1 item:" )
  r( "1. [Nadina's Pendant of Purity] (SR by Drutree and Mendunia)" )
  rw( "Roll for [Nadina's Pendant of Purity]. SR by Drutree [1 roll +1 bonus] and Mendunia" )
  c( "RollFor: Drutree used a Bonus Roll on [Nadina's Pendant of Purity] (99). 0 left." )
  c( "RollFor: Drutree rolled the highest (99) for [Nadina's Pendant of Purity] (BR)." )
  r( "Drutree rolled the highest (99) for [Nadina's Pendant of Purity] (BR)." )
  c( "RollFor: Rolling for [Nadina's Pendant of Purity] finished." )
end

-- An 87 is an 87 whichever pool it came out of, so the two tie -- and the re-roll that
-- follows is one roll each, with no bonus rolls in it.
function BonusRollSpec:should_tie_a_bonus_roll_against_an_equal_soft_res_roll()
  -- Given
  local loot_facade, chat = mock_loot_facade(), mock_chat()
  local c, r, rw = chat.console, chat.raid, chat.raid_warning
  local item, p1, p2 = i( "Nadina's Pendant of Purity", PENDANT ), p( "Drutree" ), p( "Mendunia" )
  local rf = new_roll_for()
      :loot_facade( loot_facade )
      :raid_roster( p1, p2 )
      :chat( chat )
      :soft_res_data( sr( p1.name, PENDANT ), sr( p2.name, PENDANT ) )
      :bonus_rolls( { Drutree = { SHAHRAZ } } )
      :build()

  loot_facade.notify( "LootOpened", item )
  rf.loot_frame.click( 1 )
  rf.rolling_popup.click( "Roll" )

  -- When (Drutree's bonus roll matches Mendunia's soft-res roll exactly)
  rf.roll( p1, 5, 1, 100 )
  rf.roll( p2, 87, 1, 100 )
  rf.roll( p1, 87, 1, 100 )

  -- Then (the bonus 87 and the soft-res 87 are one contest, and the tie is labelled SR)
  r( "Princess Kenny dropped 1 item:" )
  r( "1. [Nadina's Pendant of Purity] (SR by Drutree and Mendunia)" )
  rw( "Roll for [Nadina's Pendant of Purity]. SR by Drutree [1 roll +1 bonus] and Mendunia" )
  c( "RollFor: Drutree used a Bonus Roll on [Nadina's Pendant of Purity] (87). 0 left." )
  c( "RollFor: Drutree and Mendunia rolled the highest (87) for [Nadina's Pendant of Purity] (SR)." )
  r( "Drutree and Mendunia rolled the highest (87) for [Nadina's Pendant of Purity] (SR)." )

  -- When
  rf.ace_timer.tick()

  -- Then (one roll each in the re-roll, no bonus pip)
  r( "Drutree and Mendunia /roll for [Nadina's Pendant of Purity] now." )
  rf.rolling_popup.should_display(
    item_link( item, 1 ),
    sr_row( p1, { 5, { br = 87 } }, 2, 11 ),
    sr_row( p2, { 87 }, 2 ),
    text( "There was a tie (87):", 11 ),
    sr_roll_placeholder( p1, 11, 2 ),
    sr_roll_placeholder( p2, nil, 2 ),
    text( "Waiting for remaining rolls...", 11 ),
    buttons( "FinishEarly", "Cancel" )
  )
end

-- A rolling the ML canceled never happened, so what it spent goes back.
function BonusRollSpec:should_refund_a_spent_bonus_roll_when_the_rolling_is_canceled()
  -- Given
  local loot_facade, chat = mock_loot_facade(), mock_chat()
  local item, p1, p2 = i( "Nadina's Pendant of Purity", PENDANT ), p( "Drutree" ), p( "Mendunia" )
  local rf = new_roll_for()
      :loot_facade( loot_facade )
      :raid_roster( p1, p2 )
      :chat( chat )
      :soft_res_data( sr( p1.name, PENDANT ), sr( p2.name, PENDANT ) )
      :bonus_rolls( { Drutree = { SHAHRAZ } } )
      :build()

  loot_facade.notify( "LootOpened", item )
  rf.loot_frame.click( 1 )
  rf.rolling_popup.click( "Roll" )
  rf.roll( p1, 75, 1, 100 )
  rf.roll( p1, 10, 1, 100 )
  eq( rf.bonus_roll_registry.count( "Drutree" ), 0 )

  -- When
  rf.rolling_popup.click( "Cancel" )

  -- Then
  eq( rf.bonus_roll_registry.count( "Drutree" ), 1 )
  eq( rf.bonus_roll_registry.get( "Drutree" )[ 1 ].used_on, nil )
end

function BonusRollSpec:should_offer_and_deduct_nothing_when_the_feature_is_off()
  -- Given
  local loot_facade, chat = mock_loot_facade(), mock_chat()
  local item, p1, p2 = i( "Nadina's Pendant of Purity", PENDANT ), p( "Drutree" ), p( "Mendunia" )
  local rf = new_roll_for()
      :loot_facade( loot_facade )
      :raid_roster( p1, p2 )
      :chat( chat )
      :config( { resistance_bonus_rolls_enabled = false } )
      :soft_res_data( sr( p1.name, PENDANT ), sr( p2.name, PENDANT ) )
      :bonus_rolls( { Drutree = { SHAHRAZ } } )
      :build()

  loot_facade.notify( "LootOpened", item )
  rf.loot_frame.click( 1 )

  -- Then (no bonus pip)
  rf.rolling_popup.should_display(
    item_link( item, 1 ),
    sr_roll_placeholder( p1, 11, 1 ),
    sr_roll_placeholder( p2, nil, 1 ),
    buttons( "Roll", "AwardOther", "Close" )
  )

  -- When
  rf.rolling_popup.click( "Roll" )
  rf.roll( p1, 75, 1, 100 )
  rf.roll( p2, 40, 1, 100 )

  -- Then (nothing was spent)
  eq( rf.bonus_roll_registry.count( "Drutree" ), 1 )
end

-- The rule end to end: at the moment an item's boss died, the bonus rolls the player was
-- already holding are the ones that item is worth.
function BonusRollSpec:should_offer_one_roll_on_a_mother_item_and_two_on_a_council_item()
  -- Given
  local loot_facade, chat = mock_loot_facade(), mock_chat()
  local pendant, cloak = i( "Nadina's Pendant of Purity", PENDANT ), i( "Cloak of the Illidari Council", CLOAK )
  local p1, p2 = p( "Drutree" ), p( "Mendunia" )
  local rf = new_roll_for()
      :loot_facade( loot_facade )
      :raid_roster( p1, p2 )
      :chat( chat )
      :soft_res_data(
        sr( p1.name, PENDANT ), sr( p2.name, PENDANT ),
        sr( p1.name, CLOAK ), sr( p2.name, CLOAK ) )
      :bonus_rolls( { Drutree = { SHAHRAZ, COUNCIL } } )
      :build()

  -- When
  loot_facade.notify( "LootOpened", pendant )
  rf.loot_frame.click( 1 )

  -- Then
  rf.rolling_popup.should_display(
    item_link( pendant, 1 ),
    sr_row( p1, { { br = false }, false }, 2, 11 ),
    sr_roll_placeholder( p2, nil, 2 ),
    buttons( "Roll", "AwardOther", "Close" )
  )

  -- When
  loot_facade.notify( "LootClosed" )
  loot_facade.notify( "LootOpened", cloak )
  rf.loot_frame.click( 1 )

  -- Then
  rf.rolling_popup.should_display(
    item_link( cloak, 1 ),
    sr_row( p1, { { br = false }, { br = false }, false }, 3, 11 ),
    sr_roll_placeholder( p2, nil, 3 ),
    buttons( "Roll", "AwardOther", "Close" )
  )
end

os.exit( lu.LuaUnit.run( "-v", "-T", "Spec", "-m", "should", "-o", "text" ) )
