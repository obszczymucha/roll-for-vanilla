-- PINNED CONTRACT — DO NOT EDIT WHEN IMPLEMENTING SR_REDESIGN.md
--
-- These specs were written from SR_REDESIGN.md *before* the implementation existed, and
-- they are the acceptance criteria for it. They deliberately assert literal table
-- structures instead of using test/gui_helpers.lua, so that they cannot be satisfied by
-- changing a helper.
--
-- If a spec here fails, the implementation is wrong. Fixing the implementation is the
-- only permitted response. Do not edit, weaken, skip or delete anything in this file.
--
-- Expected to be RED until SR_REDESIGN.md is implemented.

package.path = "./?.lua;" .. package.path .. ";../?.lua;../RollFor/?.lua"

require( "src/bcc/compat" )
local u = require( "test/utils" )
local lu = u.luaunit()
local eq = lu.assertEquals
local builder = require( "test/IntegrationTestBuilder" )
local mock_loot_facade, mock_chat, new_roll_for = builder.mock_loot_facade, builder.mock_chat, builder.new_roll_for
local i, p = builder.i, builder.p
local sr = u.soft_res_item

-- Literal content builders. These describe the *expected* shapes and must stay
-- independent of src/ and of test/gui_helpers.lua.
local function item_line( item, count )
  return {
    type = "item_link_with_icon",
    link = item.link,
    tooltip_link = item.tooltip_link,
    count = count,
    quantity = 1,
    padding = 5
  }
end

local function cell( roll )
  return { roll_type = "SoftRes", roll = roll }
end

---@param name string
---@param cells table   cast rolls in cast order, then `false` for each pending slot
---@param best_index number?
---@param cell_count number
---@param padding number?
local function row( name, cells, best_index, cell_count, padding )
  local rolls = {}

  for _, v in ipairs( cells ) do
    table.insert( rolls, cell( v ~= false and v or nil ) )
  end

  return {
    type = "roll",
    player_name = name,
    player_class = "Warrior",
    rolls = rolls,
    best_index = best_index,
    cell_count = cell_count,
    padding = padding
  }
end

local function button( label, width )
  return { type = "button", label = label, width = width }
end

SrRowContractSpec = {}

-- Rule: one row per player, never one row per roll slot. A player's unspent rolls show
-- as pending cells on their own row.
function SrRowContractSpec:should_render_one_row_per_player_with_a_cell_per_roll()
  -- Given (Drutree SR'd twice, Mendunia and Pinp once each)
  local loot_facade, chat = mock_loot_facade(), mock_chat()
  local r = chat.raid
  local item, p1, p2, p3 = i( "Bag", 69 ), p( "Drutree" ), p( "Mendunia" ), p( "Pinp" )
  local rf = new_roll_for()
      :loot_facade( loot_facade )
      :raid_roster( p1, p2, p3 )
      :chat( chat )
      :soft_res_data( sr( p1.name, 69 ), sr( p1.name, 69 ), sr( p2.name, 69 ), sr( p3.name, 69 ) )
      :build()

  -- When
  loot_facade.notify( "LootOpened", item )
  r( "Princess Kenny dropped 1 item:" )
  r( "1. [Bag] (SR by Drutree [2 rolls], Mendunia and Pinp)" )
  rf.loot_frame.click( 1 )

  -- Then (3 rows for 4 roll slots; nobody has rolled, so alphabetical)
  local content = rf.rolling_popup.content()
  local rows = {}
  for _, v in ipairs( content ) do
    if v.type == "roll" then table.insert( rows, v ) end
  end

  eq( rows, {
    row( "Drutree", { false, false }, nil, 2, 11 ),
    row( "Mendunia", { false }, nil, 2 ),
    row( "Pinp", { false }, nil, 2 )
  } )
end

-- Rule: rows order by best roll descending, but cells within a row stay in cast order.
-- This is the case that cannot be faked: Drutree's best (96) is his *second* cast, so a
-- value-sorted row would read "96 69" and a value-sorted row order would put Mendunia
-- first if it looked at the leading cell.
function SrRowContractSpec:should_order_rows_by_best_roll_but_cells_by_cast_order()
  -- Given (both players SR'd twice; 1 item)
  local loot_facade, chat = mock_loot_facade(), mock_chat()
  local item, p1, p2 = i( "Bag", 69 ), p( "Drutree" ), p( "Mendunia" )
  local rf = new_roll_for()
      :loot_facade( loot_facade )
      :raid_roster( p1, p2 )
      :chat( chat )
      :soft_res_data( sr( p1.name, 69 ), sr( p1.name, 69 ), sr( p2.name, 69 ), sr( p2.name, 69 ) )
      :build()

  loot_facade.notify( "LootOpened", item )
  rf.loot_frame.click( 1 )
  rf.rolling_popup.click( "Roll" )

  -- When (Drutree casts 69 then 96; Mendunia casts 87 then 91, interleaved)
  rf.roll( p1, 69, 1, 100 )
  rf.roll( p2, 87, 1, 100 )
  rf.roll( p1, 96, 1, 100 )
  rf.roll( p2, 91, 1, 100 )

  -- Then
  local rows = {}
  for _, v in ipairs( rf.rolling_popup.content() ) do
    if v.type == "roll" then table.insert( rows, v ) end
  end

  eq( rows, {
    row( "Drutree", { 69, 96 }, 2, 2, 11 ), -- first: best roll 96 beats 91
    row( "Mendunia", { 87, 91 }, 2, 2 )     -- cells stay 87, 91 - not 91, 87
  } )
end

-- Rule: a row mixes cast and pending cells, pending trailing. This is the state that is
-- unreadable today (two identical Drutree rows).
function SrRowContractSpec:should_show_cast_and_pending_cells_on_the_same_row()
  -- Given
  local loot_facade, chat = mock_loot_facade(), mock_chat()
  local item, p1, p2 = i( "Bag", 69 ), p( "Drutree" ), p( "Mendunia" )
  local rf = new_roll_for()
      :loot_facade( loot_facade )
      :raid_roster( p1, p2 )
      :chat( chat )
      :soft_res_data( sr( p1.name, 69 ), sr( p1.name, 69 ), sr( p2.name, 69 ) )
      :build()

  loot_facade.notify( "LootOpened", item )
  rf.loot_frame.click( 1 )
  rf.rolling_popup.click( "Roll" )

  -- When (Drutree spends one of his two rolls; Mendunia has not rolled)
  rf.roll( p1, 75, 1, 100 )

  -- Then
  local rows = {}
  for _, v in ipairs( rf.rolling_popup.content() ) do
    if v.type == "roll" then table.insert( rows, v ) end
  end

  eq( rows, {
    row( "Drutree", { 75, false }, 1, 2, 11 ),
    row( "Mendunia", { false }, nil, 2 )
  } )
end

-- Rule: normal (MS/OS) rolls are NOT grouped and keep the pre-redesign line shape. This
-- is the regression canary - if it fails, the groupable-roll-type filter is wrong.
function SrRowContractSpec:should_leave_non_softres_rolls_ungrouped()
  -- Given (no soft-res at all)
  local loot_facade, chat = mock_loot_facade(), mock_chat()
  local item, p1, p2 = i( "Bag", 69 ), p( "Drutree" ), p( "Mendunia" )
  local rf = new_roll_for()
      :loot_facade( loot_facade )
      :raid_roster( p1, p2 )
      :chat( chat )
      :build()

  loot_facade.notify( "LootOpened", item )
  rf.loot_frame.click( 1 )
  rf.rolling_popup.click( "Roll" )

  -- When
  rf.roll( p1, 69, 1, 100 )
  rf.roll( p2, 96, 1, 99 ) -- off-spec

  -- Then (one line per roll, `roll` and `roll_type` on the line itself, no `rolls` array)
  local rows = {}
  for _, v in ipairs( rf.rolling_popup.content() ) do
    if v.type == "roll" then table.insert( rows, v ) end
  end

  eq( rows, {
    { type = "roll", player_name = "Drutree", player_class = "Warrior", roll_type = "MainSpec", roll = 69, padding = 11 },
    { type = "roll", player_name = "Mendunia", player_class = "Warrior", roll_type = "OffSpec", roll = 96 }
  } )
end

-- Invariant: no roll slot may be lost or invented by grouping. Total cells across all
-- rows must equal the number of roll slots, and cell_count must be uniform.
function SrRowContractSpec:should_preserve_every_roll_slot_and_keep_cell_count_uniform()
  -- Given
  local loot_facade, chat = mock_loot_facade(), mock_chat()
  local item, p1, p2, p3 = i( "Bag", 69 ), p( "Drutree" ), p( "Mendunia" ), p( "Pinp" )
  local rf = new_roll_for()
      :loot_facade( loot_facade )
      :raid_roster( p1, p2, p3 )
      :chat( chat )
      :soft_res_data(
        sr( p1.name, 69 ), sr( p1.name, 69 ), sr( p1.name, 69 ),
        sr( p2.name, 69 ), sr( p2.name, 69 ),
        sr( p3.name, 69 ) )
      :build()

  loot_facade.notify( "LootOpened", item )
  rf.loot_frame.click( 1 )
  rf.rolling_popup.click( "Roll" )
  rf.roll( p1, 50, 1, 100 )
  rf.roll( p3, 80, 1, 100 )

  -- Then
  local rows, cells, names = {}, 0, {}
  for _, v in ipairs( rf.rolling_popup.content() ) do
    if v.type == "roll" then
      table.insert( rows, v )
      names[ v.player_name ] = (names[ v.player_name ] or 0) + 1
      for _ = 1, table.getn( v.rolls ) do cells = cells + 1 end
      eq( v.cell_count, 3 ) -- widest player has 3 rolls
    end
  end

  eq( table.getn( rows ), 3, "one row per player" )
  eq( cells, 6, "3 + 2 + 1 roll slots, none lost" )

  for name, count in pairs( names ) do
    eq( count, 1, string.format( "%s must appear on exactly one row", name ) )
  end
end

os.exit( lu.LuaUnit.run( "-v", "-T", "Spec", "-m", "should", "-o", "text" ) )
