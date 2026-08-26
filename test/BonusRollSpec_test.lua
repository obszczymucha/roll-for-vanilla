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
local c, r, rw = u.console_message, u.raid_message, u.raid_warning

local SHAHRAZ = "Mother Shahraz"
local COUNCIL = "The Illidari Council"
local ILLIDAN = "Illidan Stormrage"

-- Real catalogue ids: the bonus allowance is resolved through AutoLootDb, so made-up ids
-- would prove nothing but that unknown items grant nothing.
local PENDANT = 32370 -- Nadina's Pendant of Purity, Mother Shahraz
local CLOAK = 32331   -- Cloak of the Illidari Council
local SKULL = 32483   -- The Skull of Gul'dan, Illidan Stormrage

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

-- A tie on 100 is over the moment it happens: 100 is the highest roll there is, so nobody
-- left holding rolls can beat it, and the only player still holding any is already in the
-- tie. Waiting on her asks her to spend three bonus rolls that cannot change the result --
-- and they are deducted the moment she casts them, so the wait costs her the rolls.
--
-- The rolling has to call the tie itself. Leaving it to the master looter to finish early
-- is what the addon is for.
function BonusRollSpec:should_call_the_tie_when_no_remaining_roll_can_change_it()
  -- Given (both hold a Mother, a Council and an Illidan roll, and both soft-ressed the
  -- last Illidan item, so each has one soft-res roll and three bonus rolls)
  local loot_facade, chat = mock_loot_facade(), mock_chat()
  local item, p1, p2 = i( "The Skull of Gul'dan", SKULL ), p( "Ayla" ), p( "Borkul" )
  local grants = { SHAHRAZ, COUNCIL, ILLIDAN }
  local rf = new_roll_for()
      :loot_facade( loot_facade )
      :raid_roster( p1, p2 )
      :chat( chat )
      :soft_res_data( sr( p1.name, SKULL ), sr( p2.name, SKULL ) )
      :bonus_rolls( { Ayla = grants, Borkul = grants } )
      :build()

  loot_facade.notify( "LootOpened", item )
  rf.loot_frame.click( 1 )
  rf.rolling_popup.click( "Roll" )

  -- When (Ayla casts her soft-res roll and cannot improve on it; Borkul works through his
  -- allowance while the clock runs down, then ties her with his last bonus roll)
  rf.roll( p1, 100, 1, 100 )
  rf.ace_timer.repeating_tick( 2 )
  rf.roll( p2, 10, 1, 100 )
  rf.ace_timer.repeating_tick( 2 )
  rf.roll( p2, 11, 1, 100 )
  rf.ace_timer.repeating_tick( 2 )
  rf.roll( p2, 12, 1, 100 )
  rf.ace_timer.repeating_tick( 2 )
  rf.roll( p2, 100, 1, 100 )

  -- Then (the timer running out on Borkul is correct -- he was behind and still owed a
  -- roll that could change the result. His 100 is where it ends: nothing Ayla has left can
  -- beat it, so the tie is called here, with no Finish early clicked)
  chat.assert(
    r( "Princess Kenny dropped 1 item:" ),
    r( "1. [The Skull of Gul'dan] (SR by Ayla and Borkul)" ),
    rw( "Roll for [The Skull of Gul'dan]. SR by Ayla [1 roll +3 bonus] and Borkul [1 roll +3 bonus]" ),
    c( "RollFor: Borkul used a Bonus Roll on [The Skull of Gul'dan] (11). 2 left." ),
    r( "Stopping rolls in 3" ),
    r( "2" ),
    c( "RollFor: Borkul used a Bonus Roll on [The Skull of Gul'dan] (12). 1 left." ),
    r( "1" ),
    r( "SR rolls remaining: Ayla (3 bonus rolls) and Borkul (1 bonus roll)" ),
    c( "RollFor: Borkul used a Bonus Roll on [The Skull of Gul'dan] (100). 0 left." ),
    c( "RollFor: Ayla and Borkul rolled the highest (100) for [The Skull of Gul'dan] (SR)." ),
    r( "Ayla and Borkul rolled the highest (100) for [The Skull of Gul'dan] (SR)." )
  )

  -- And (nothing of hers has been spent to get here: she never needed a bonus roll)
  eq( rf.bonus_roll_registry.count( "Ayla" ), 3 )
  eq( rf.bonus_roll_registry.count( "Borkul" ), 0 )

  -- When (the tie roll starts)
  rf.ace_timer.tick()

  -- Then (a tie roll is a roll like any other, so the same rule applies: one roll each,
  -- plus whatever bonus rolls a player still holds. Borkul spent his three climbing to
  -- 100 and gets one; Ayla never needed hers and brings all three. That leaves them on
  -- five rolls each for the item -- which is what one roll each does not.)
  chat.assert(
    r( "Princess Kenny dropped 1 item:" ),
    r( "1. [The Skull of Gul'dan] (SR by Ayla and Borkul)" ),
    rw( "Roll for [The Skull of Gul'dan]. SR by Ayla [1 roll +3 bonus] and Borkul [1 roll +3 bonus]" ),
    c( "RollFor: Borkul used a Bonus Roll on [The Skull of Gul'dan] (11). 2 left." ),
    r( "Stopping rolls in 3" ),
    r( "2" ),
    c( "RollFor: Borkul used a Bonus Roll on [The Skull of Gul'dan] (12). 1 left." ),
    r( "1" ),
    r( "SR rolls remaining: Ayla (3 bonus rolls) and Borkul (1 bonus roll)" ),
    c( "RollFor: Borkul used a Bonus Roll on [The Skull of Gul'dan] (100). 0 left." ),
    c( "RollFor: Ayla and Borkul rolled the highest (100) for [The Skull of Gul'dan] (SR)." ),
    r( "Ayla and Borkul rolled the highest (100) for [The Skull of Gul'dan] (SR)." ),
    r( "Ayla [1 roll +3 bonus] and Borkul /roll for [The Skull of Gul'dan] now." )
  )

  -- When (she plays her four out and Borkul his one)
  rf.roll( p1, 55, 1, 100 )
  rf.roll( p1, 70, 1, 100 )
  rf.roll( p1, 80, 1, 100 )
  rf.roll( p1, 90, 1, 100 )
  rf.roll( p2, 42, 1, 100 )

  -- Then (each of hers counts and is deducted, and her best one takes the item -- she is
  -- judged on her best roll, not handed a winning slot per roll)
  chat.assert(
    r( "Princess Kenny dropped 1 item:" ),
    r( "1. [The Skull of Gul'dan] (SR by Ayla and Borkul)" ),
    rw( "Roll for [The Skull of Gul'dan]. SR by Ayla [1 roll +3 bonus] and Borkul [1 roll +3 bonus]" ),
    c( "RollFor: Borkul used a Bonus Roll on [The Skull of Gul'dan] (11). 2 left." ),
    r( "Stopping rolls in 3" ),
    r( "2" ),
    c( "RollFor: Borkul used a Bonus Roll on [The Skull of Gul'dan] (12). 1 left." ),
    r( "1" ),
    r( "SR rolls remaining: Ayla (3 bonus rolls) and Borkul (1 bonus roll)" ),
    c( "RollFor: Borkul used a Bonus Roll on [The Skull of Gul'dan] (100). 0 left." ),
    c( "RollFor: Ayla and Borkul rolled the highest (100) for [The Skull of Gul'dan] (SR)." ),
    r( "Ayla and Borkul rolled the highest (100) for [The Skull of Gul'dan] (SR)." ),
    r( "Ayla [1 roll +3 bonus] and Borkul /roll for [The Skull of Gul'dan] now." ),
    c( "RollFor: Ayla used a Bonus Roll on [The Skull of Gul'dan] (70). 2 left." ),
    c( "RollFor: Ayla used a Bonus Roll on [The Skull of Gul'dan] (80). 1 left." ),
    c( "RollFor: Ayla used a Bonus Roll on [The Skull of Gul'dan] (90). 0 left." ),
    c( "RollFor: Ayla re-rolled the highest (90) for [The Skull of Gul'dan] (BR)." ),
    r( "Ayla re-rolled the highest (90) for [The Skull of Gul'dan] (BR)." ),
    c( "RollFor: Rolling for [The Skull of Gul'dan] finished." )
  )

  -- And (five rolls each at the item, and every bonus roll either of them earned has been
  -- cast: nobody is left holding rolls that were never usable)
  eq( rf.bonus_roll_registry.count( "Ayla" ), 0 )
  eq( rf.bonus_roll_registry.count( "Borkul" ), 0 )
end

-- The other side of that rule. A tie below the highest roll is not decided: the bonus roll
-- Drutree still holds can break it, so the rolling has to stay open for it -- and does.
function BonusRollSpec:should_keep_rolling_when_a_tie_below_the_top_roll_can_still_be_broken()
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

  -- When (they tie on 87 and Drutree still has his bonus roll)
  rf.roll( p1, 87, 1, 100 )
  rf.roll( p2, 87, 1, 100 )

  -- Then (no tie is called: his bonus roll can still settle it outright)
  chat.assert(
    r( "Princess Kenny dropped 1 item:" ),
    r( "1. [Nadina's Pendant of Purity] (SR by Drutree and Mendunia)" ),
    rw( "Roll for [Nadina's Pendant of Purity]. SR by Drutree [1 roll +1 bonus] and Mendunia" )
  )

  -- When
  rf.roll( p1, 90, 1, 100 )

  -- Then
  chat.assert(
    r( "Princess Kenny dropped 1 item:" ),
    r( "1. [Nadina's Pendant of Purity] (SR by Drutree and Mendunia)" ),
    rw( "Roll for [Nadina's Pendant of Purity]. SR by Drutree [1 roll +1 bonus] and Mendunia" ),
    c( "RollFor: Drutree used a Bonus Roll on [Nadina's Pendant of Purity] (90). 0 left." ),
    c( "RollFor: Drutree rolled the highest (90) for [Nadina's Pendant of Purity] (BR)." ),
    r( "Drutree rolled the highest (90) for [Nadina's Pendant of Purity] (BR)." ),
    c( "RollFor: Rolling for [Nadina's Pendant of Purity] finished." )
  )
end

-- The 100-100 tie, played up to the point where the tie roll is open and the shared part
-- of the transcript is asserted: Ayla holds the three bonus rolls she never needed, Borkul
-- has none. Each test below carries on from there with its own rolls, so what it asserts
-- is only its own.
---@param chat ChatApiMock
local function a_tie_on_the_top_roll( chat )
  local loot_facade = mock_loot_facade()
  local item, p1, p2 = i( "The Skull of Gul'dan", SKULL ), p( "Ayla" ), p( "Borkul" )
  local grants = { SHAHRAZ, COUNCIL, ILLIDAN }
  local rf = new_roll_for()
      :loot_facade( loot_facade )
      :raid_roster( p1, p2 )
      :chat( chat )
      :soft_res_data( sr( p1.name, SKULL ), sr( p2.name, SKULL ) )
      :bonus_rolls( { Ayla = grants, Borkul = grants } )
      :build()

  loot_facade.notify( "LootOpened", item )
  rf.loot_frame.click( 1 )
  rf.rolling_popup.click( "Roll" )

  rf.roll( p1, 100, 1, 100 )
  rf.roll( p2, 10, 1, 100 )
  rf.roll( p2, 11, 1, 100 )
  rf.roll( p2, 12, 1, 100 )
  rf.roll( p2, 100, 1, 100 )
  rf.ace_timer.tick()

  chat.raid( "Princess Kenny dropped 1 item:" )
  chat.raid( "1. [The Skull of Gul'dan] (SR by Ayla and Borkul)" )
  chat.raid_warning( "Roll for [The Skull of Gul'dan]. SR by Ayla [1 roll +3 bonus] and Borkul [1 roll +3 bonus]" )
  chat.console( "RollFor: Borkul used a Bonus Roll on [The Skull of Gul'dan] (11). 2 left." )
  chat.console( "RollFor: Borkul used a Bonus Roll on [The Skull of Gul'dan] (12). 1 left." )
  chat.console( "RollFor: Borkul used a Bonus Roll on [The Skull of Gul'dan] (100). 0 left." )
  chat.console( "RollFor: Ayla and Borkul rolled the highest (100) for [The Skull of Gul'dan] (SR)." )
  chat.raid( "Ayla and Borkul rolled the highest (100) for [The Skull of Gul'dan] (SR)." )
  chat.raid( "Ayla [1 roll +3 bonus] and Borkul /roll for [The Skull of Gul'dan] now." )

  return rf, item, p1, p2
end

-- Borkul rolls first and Ayla's tie roll already beats him. He is out of rolls, so there is
-- nothing left that can change the result -- the same condition that ends the soft-res
-- round. Her three bonus rolls are not needed and stay hers.
function BonusRollSpec:should_end_the_tie_when_the_tie_roll_already_beats_a_player_out_of_rolls()
  -- Given
  local chat = mock_chat()
  local rf, _, p1, p2 = a_tie_on_the_top_roll( chat )

  -- When
  rf.roll( p2, 42, 1, 100 )
  rf.roll( p1, 55, 1, 100 )

  -- Then
  chat.console( "RollFor: Ayla re-rolled the highest (55) for [The Skull of Gul'dan] (SR)." )
  chat.raid( "Ayla re-rolled the highest (55) for [The Skull of Gul'dan] (SR)." )
  chat.console( "RollFor: Rolling for [The Skull of Gul'dan] finished." )
  eq( rf.bonus_roll_registry.count( "Ayla" ), 3 )
end

-- Borkul rolls first and Ayla's tie roll is behind it, so she works through the bonus rolls
-- she brought until one of them takes it. Each is deducted as it is cast, and the item is
-- decided on her best.
function BonusRollSpec:should_let_her_climb_past_him_with_the_bonus_rolls_she_brought_to_the_tie()
  -- Given
  local chat = mock_chat()
  local rf, _, p1, p2 = a_tie_on_the_top_roll( chat )

  -- When
  rf.roll( p2, 42, 1, 100 )
  rf.roll( p1, 30, 1, 100 )
  rf.roll( p1, 35, 1, 100 )
  rf.roll( p1, 40, 1, 100 )
  rf.roll( p1, 90, 1, 100 )

  -- Then
  chat.console( "RollFor: Ayla used a Bonus Roll on [The Skull of Gul'dan] (35). 2 left." )
  chat.console( "RollFor: Ayla used a Bonus Roll on [The Skull of Gul'dan] (40). 1 left." )
  chat.console( "RollFor: Ayla used a Bonus Roll on [The Skull of Gul'dan] (90). 0 left." )
  chat.console( "RollFor: Ayla re-rolled the highest (90) for [The Skull of Gul'dan] (BR)." )
  chat.raid( "Ayla re-rolled the highest (90) for [The Skull of Gul'dan] (BR)." )
  chat.console( "RollFor: Rolling for [The Skull of Gul'dan] finished." )
  eq( rf.bonus_roll_registry.count( "Ayla" ), 0 )
end

os.exit( lu.LuaUnit.run( "-v", "-T", "Spec", "-m", "should", "-o", "text" ) )
