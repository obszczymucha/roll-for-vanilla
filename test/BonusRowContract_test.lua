-- PINNED CONTRACT — DO NOT EDIT WHEN IMPLEMENTING BONUS_ROLLS.md
--
-- These specs were written from BONUS_ROLLS.md *before* the implementation existed, and
-- they are the acceptance criteria for the popup row a bonus roll produces. They
-- deliberately assert literal table structures instead of using test/gui_helpers.lua, so
-- that they cannot be satisfied by changing a helper.
--
-- If a spec here fails, the implementation is wrong. Fixing the implementation is the
-- only permitted response. Do not edit, weaken, skip or delete anything in this file.
--
-- Expected to be RED until BONUS_ROLLS.md is implemented.

package.path = "./?.lua;" .. package.path .. ";../?.lua;../RollFor/?.lua"

require( "src/compat" )
local u = require( "test/utils" )
local lu = u.luaunit()
local eq = lu.assertEquals
local builder = require( "test/IntegrationTestBuilder" )
local mock_loot_facade, mock_chat, new_roll_for = builder.mock_loot_facade, builder.mock_chat, builder.new_roll_for
local i, p = builder.i, builder.p
local sr = u.soft_res_item

local SHAHRAZ = "Mother Shahraz"
local COUNCIL = "The Illidari Council"

-- Real catalogue ids, because the bonus allowance is resolved through AutoLootDb.
local SHAHRAZ_ITEM = 32370 -- Nadina's Pendant of Purity
local COUNCIL_ITEM = 32331 -- Cloak of the Illidari Council

-- Literal cell builders. These describe the *expected* shapes and must stay independent
-- of src/ and of test/gui_helpers.lua.
local function sr_cell( roll )
  return { roll_type = "SoftRes", roll = roll }
end

local function br_cell( roll )
  return { roll_type = "BonusRoll", roll = roll }
end

---@param name string
---@param cells table[]
---@param best_index number?
---@param cell_count number
---@param padding number?
local function row( name, cells, best_index, cell_count, padding )
  return {
    type = "roll",
    player_name = name,
    player_class = "Warrior",
    rolls = cells,
    best_index = best_index,
    cell_count = cell_count,
    padding = padding
  }
end

---@param rf table
local function rows( rf )
  local result = {}

  for _, v in ipairs( rf.rolling_popup.content() ) do
    if v.type == "roll" then table.insert( result, v ) end
  end

  return result
end

BonusRowContractSpec = {}

-- Rule: a bonus roll is an extra cell on the soft-resser's existing row, not a row of its
-- own, and the pending bonus pip sorts ahead of the pending SR pip so the gold pips render
-- to the left of the white ones.
function BonusRowContractSpec:should_put_the_pending_bonus_cell_before_the_pending_sr_cell()
  -- Given
  local loot_facade, chat = mock_loot_facade(), mock_chat()
  local item, p1, p2 = i( "Nadina's Pendant of Purity", SHAHRAZ_ITEM ), p( "Drutree" ), p( "Mendunia" )
  local rf = new_roll_for()
      :loot_facade( loot_facade )
      :raid_roster( p1, p2 )
      :chat( chat )
      :soft_res_data( sr( p1.name, SHAHRAZ_ITEM ), sr( p2.name, SHAHRAZ_ITEM ) )
      :bonus_rolls( { Drutree = { SHAHRAZ } } )
      :build()

  -- When
  loot_facade.notify( "LootOpened", item )
  rf.loot_frame.click( 1 )

  -- Then
  eq( rows( rf ), {
    row( "Drutree", { br_cell( nil ), sr_cell( nil ) }, nil, 2, 11 ),
    row( "Mendunia", { sr_cell( nil ) }, nil, 2 )
  } )
end

-- Rule: the bonus allowance is per item. A Council item is worth both rolls the player is
-- holding; a Mother item is worth only the one that existed when Mother died.
function BonusRowContractSpec:should_offer_two_bonus_cells_on_a_council_item_and_one_on_a_mother_item()
  -- Given
  local loot_facade, chat = mock_loot_facade(), mock_chat()
  local mother_item = i( "Nadina's Pendant of Purity", SHAHRAZ_ITEM )
  local council_item = i( "Cloak of the Illidari Council", COUNCIL_ITEM )
  local p1, p2 = p( "Drutree" ), p( "Mendunia" )
  -- Two soft-ressers on one copy, or the lone soft-resser wins it outright and there is no
  -- roll to put a bonus cell in.
  local rf = new_roll_for()
      :loot_facade( loot_facade )
      :raid_roster( p1, p2 )
      :chat( chat )
      :soft_res_data(
        sr( p1.name, SHAHRAZ_ITEM ), sr( p2.name, SHAHRAZ_ITEM ),
        sr( p1.name, COUNCIL_ITEM ), sr( p2.name, COUNCIL_ITEM ) )
      :bonus_rolls( { Drutree = { SHAHRAZ, COUNCIL } } )
      :build()

  -- When (Council item first, so nothing can be explained by the Mother item having been seen)
  loot_facade.notify( "LootOpened", council_item )
  rf.loot_frame.click( 1 )

  -- Then
  eq( rows( rf ), {
    row( "Drutree", { br_cell( nil ), br_cell( nil ), sr_cell( nil ) }, nil, 3, 11 ),
    row( "Mendunia", { sr_cell( nil ) }, nil, 3 )
  } )

  -- When
  loot_facade.notify( "LootClosed" )
  loot_facade.notify( "LootOpened", mother_item )
  rf.loot_frame.click( 1 )

  -- Then
  eq( rows( rf ), {
    row( "Drutree", { br_cell( nil ), sr_cell( nil ) }, nil, 2, 11 ),
    row( "Mendunia", { sr_cell( nil ) }, nil, 2 )
  } )
end

-- Rule: a player's rolls come out of their SR allowance first, so the first roll they cast
-- is an SR roll and the second is the bonus roll -- and cast cells keep cast order, with
-- the pending cell still leading.
function BonusRowContractSpec:should_spend_the_sr_roll_first_and_the_bonus_roll_second()
  -- Given
  local loot_facade, chat = mock_loot_facade(), mock_chat()
  local item, p1, p2 = i( "Nadina's Pendant of Purity", SHAHRAZ_ITEM ), p( "Drutree" ), p( "Mendunia" )
  local rf = new_roll_for()
      :loot_facade( loot_facade )
      :raid_roster( p1, p2 )
      :chat( chat )
      :soft_res_data( sr( p1.name, SHAHRAZ_ITEM ), sr( p2.name, SHAHRAZ_ITEM ) )
      :bonus_rolls( { Drutree = { SHAHRAZ } } )
      :build()

  loot_facade.notify( "LootOpened", item )
  rf.loot_frame.click( 1 )
  rf.rolling_popup.click( "Roll" )

  -- When (Drutree spends his SR roll)
  rf.roll( p1, 75, 1, 100 )

  -- Then (the cast SR cell, with the still-pending bonus cell trailing it)
  eq( rows( rf )[ 1 ], row( "Drutree", { sr_cell( 75 ), br_cell( nil ) }, 1, 2, 11 ) )

  -- When (and then his bonus roll)
  rf.roll( p1, 40, 1, 100 )

  -- Then (both cast, in cast order; 75 is still his best)
  eq( rows( rf )[ 1 ], row( "Drutree", { sr_cell( 75 ), br_cell( 40 ) }, 1, 2, 11 ) )
end

-- Rule: soft-res and bonus rolls are the same contest, so they sort against each other by
-- value. A bonus 99 must put its owner above a soft-resser who rolled 40 -- ranking bonus
-- rolls by type instead would shove the row to one end regardless of the number on it.
function BonusRowContractSpec:should_order_rows_by_value_across_both_roll_types()
  -- Given
  local loot_facade, chat = mock_loot_facade(), mock_chat()
  local item, p1, p2 = i( "Nadina's Pendant of Purity", SHAHRAZ_ITEM ), p( "Drutree" ), p( "Mendunia" )
  local rf = new_roll_for()
      :loot_facade( loot_facade )
      :raid_roster( p1, p2 )
      :chat( chat )
      :soft_res_data( sr( p1.name, SHAHRAZ_ITEM ), sr( p2.name, SHAHRAZ_ITEM ) )
      :bonus_rolls( { Drutree = { SHAHRAZ } } )
      :build()

  loot_facade.notify( "LootOpened", item )
  rf.loot_frame.click( 1 )
  rf.rolling_popup.click( "Roll" )

  -- When (Mendunia's only roll is 40; Drutree's SR roll is 5 and his bonus roll is 99)
  rf.roll( p2, 40, 1, 100 )
  rf.roll( p1, 5, 1, 100 )
  rf.roll( p1, 99, 1, 100 )

  -- Then (Drutree leads on his bonus 99, not on his SR 5)
  eq( rows( rf ), {
    row( "Drutree", { sr_cell( 5 ), br_cell( 99 ) }, 2, 2, 11 ),
    row( "Mendunia", { sr_cell( 40 ) }, 1, 2 )
  } )
end

-- Rule: with the feature off there is no bonus allowance at all, so the row is exactly
-- what it was before bonus rolls existed.
function BonusRowContractSpec:should_render_no_bonus_cell_when_the_feature_is_off()
  -- Given
  local loot_facade, chat = mock_loot_facade(), mock_chat()
  local item, p1, p2 = i( "Nadina's Pendant of Purity", SHAHRAZ_ITEM ), p( "Drutree" ), p( "Mendunia" )
  local rf = new_roll_for()
      :loot_facade( loot_facade )
      :raid_roster( p1, p2 )
      :chat( chat )
      :config( { resistance_bonus_rolls_enabled = false } )
      :soft_res_data( sr( p1.name, SHAHRAZ_ITEM ), sr( p2.name, SHAHRAZ_ITEM ) )
      :bonus_rolls( { Drutree = { SHAHRAZ } } )
      :build()

  -- When
  loot_facade.notify( "LootOpened", item )
  rf.loot_frame.click( 1 )

  -- Then
  eq( rows( rf ), {
    row( "Drutree", { sr_cell( nil ) }, nil, 1, 11 ),
    row( "Mendunia", { sr_cell( nil ) }, nil, 1 )
  } )
end

-- Rule: an item no granting boss drops is worth no bonus rolls, however many the player
-- is holding. This is what confines bonus rolls to Mother/Council/Illidan loot.
function BonusRowContractSpec:should_render_no_bonus_cell_for_an_item_outside_the_granting_bosses()
  -- Given
  local loot_facade, chat = mock_loot_facade(), mock_chat()
  local item, p1, p2 = i( "Bag", 69 ), p( "Drutree" ), p( "Mendunia" )
  local rf = new_roll_for()
      :loot_facade( loot_facade )
      :raid_roster( p1, p2 )
      :chat( chat )
      :soft_res_data( sr( p1.name, 69 ), sr( p2.name, 69 ) )
      :bonus_rolls( { Drutree = { SHAHRAZ, COUNCIL } } )
      :build()

  -- When
  loot_facade.notify( "LootOpened", item )
  rf.loot_frame.click( 1 )

  -- Then
  eq( rows( rf ), {
    row( "Drutree", { sr_cell( nil ) }, nil, 1, 11 ),
    row( "Mendunia", { sr_cell( nil ) }, nil, 1 )
  } )
end

os.exit( lu.LuaUnit.run( "-v", "-T", "Spec", "-m", "should", "-o", "text" ) )
