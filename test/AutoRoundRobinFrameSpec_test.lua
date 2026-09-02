-- The selection window over the round-robin catalogue. Only the part that is this window's own is
-- covered here: the Trash category's quality rows, and what the master loot threshold does to
-- them. The tree itself (ordering, checked write-through, quality rows being leaves) belongs to
-- AutoLootTree_test, and the awarding to AutoRoundRobinSpec_test.
---@diagnostic disable: missing-fields, inject-field
package.path = "./?.lua;" .. package.path .. ";../?.lua;../RollFor/?.lua;../RollFor/libs/?.lua"

require( "src/compat" )
local u = require( "test/utils" )
local lu, eq = u.luaunit( "assertEquals" )
u.multi_require_src( "DebugBuffer", "Module", "Types" )
require( "src/modules" )
local Db = require( "src/Db" )
local popup_builder = require( "mocks/PopupBuilder" )
require( "src/ItemUtils" )
require( "src/ItemCatalogue" )
require( "src/AutoLootDb" )
require( "src/AutoRoundRobinDb" )
require( "src/Tree" )
require( "src/AutoLootTree" )
require( "src/AutoLootFrame" )
local Transformer = require( "src/AutoLootFrameContentTransformer" )
local AutoRoundRobinFrame = require( "src/AutoRoundRobinFrame" )

u.mock_wow_api()

local ItemQuality = RollFor.Types.ItemQuality

---@param threshold number
local function window( threshold )
  u.loot_threshold( threshold )

  local db = Db.new( {} )
  local round_robin_db = db( "autorobin" )

  -- Trash ticked, so the only thing left that can grey a row underneath it is the threshold. A
  -- row under an unchecked category is greyed too (that's the tree's own rule, covered in
  -- AutoLootTree_test), and leaving it off here would make every assertion below say nothing.
  RollFor.AutoRoundRobinDb.ensure_seeded( round_robin_db )
  round_robin_db.ids[ RollFor.AutoRoundRobinDb.TRASH ].enabled = true

  -- The real transformer, spied on: what this window decides about a row only exists in what it
  -- hands over, so the assertions read that rather than a widget.
  local rows
  local real = Transformer.new()

  local spying_transformer = {
    transform = function( data )
      rows = data.rows
      return real.transform( data )
    end
  }

  local changes = 0

  local frame = AutoRoundRobinFrame.new( popup_builder.new(), spying_transformer, round_robin_db,
    db( "frame" ), function() end, function() changes = changes + 1 end )

  frame.change_count = function() return changes end

  -- Collapsed by default, so nothing under Trash is drawn until it's opened. Clicking the row is
  -- how a player would do it, and it redraws on its own.
  frame.expand_trash = function()
    frame.show()

    for _, row in ipairs( rows or {} ) do
      if row.data.name == "Trash" and row.on_click then row.on_click() end
    end
  end

  ---@param label string
  frame.row = function( label )
    for _, row in ipairs( rows or {} ) do
      if row.data.name == label then return row end
    end

    error( string.format( "There is no %s row.", label ), 2 )
  end

  return frame
end

-- Both rows are live at an Uncommon threshold: GiveMasterLoot will take either.
RoundRobinTrashRowsSpec = {}

function RoundRobinTrashRowsSpec:should_offer_an_uncommon_and_a_rare_row_under_trash()
  local frame = window( ItemQuality.Uncommon )

  frame.expand_trash()

  eq( frame.row( "Uncommon" ).data.quality, ItemQuality.Uncommon )
  eq( frame.row( "Rare" ).data.quality, ItemQuality.Rare )
end

function RoundRobinTrashRowsSpec:should_leave_both_rows_alone_when_the_threshold_is_uncommon()
  local frame = window( ItemQuality.Uncommon )

  frame.expand_trash()

  eq( frame.row( "Uncommon" ).desaturated, false )
  eq( frame.row( "Uncommon" ).tooltip_text, nil )
  eq( frame.row( "Rare" ).desaturated, false )
  eq( frame.row( "Rare" ).tooltip_text, nil )
end

-- At a Rare threshold the Uncommon row can't do anything, however it's ticked -- the award pass
-- drops the item before it ever asks which queue serves it. Greying it is the only warning a
-- player gets, so it comes with the reason attached.
function RoundRobinTrashRowsSpec:should_grey_the_uncommon_row_when_the_threshold_is_rare()
  local frame = window( ItemQuality.Rare )

  frame.expand_trash()

  eq( frame.row( "Uncommon" ).desaturated, true )
  eq( frame.row( "Rare" ).desaturated, false )
end

function RoundRobinTrashRowsSpec:should_say_why_a_greyed_row_is_greyed()
  local frame = window( ItemQuality.Rare )

  frame.expand_trash()

  local tooltip = frame.row( "Uncommon" ).tooltip_text

  eq( tooltip[ 1 ], "Uncommon" )
  lu.assertStrContains( tooltip[ 2 ], "Uncommon items can't be master looted" )
  lu.assertStrContains( tooltip[ 2 ], "threshold is Rare" )
end

function RoundRobinTrashRowsSpec:should_grey_both_rows_when_the_threshold_is_epic()
  local frame = window( ItemQuality.Epic )

  frame.expand_trash()

  eq( frame.row( "Uncommon" ).desaturated, true )
  eq( frame.row( "Rare" ).desaturated, true )
  lu.assertStrContains( frame.row( "Rare" ).tooltip_text[ 2 ], "threshold is Epic" )
end

-- The threshold is the raid leader's setting and can change while the window is open. refresh()
-- is what PARTY_LOOT_METHOD_CHANGED reaches (see main.on_party_loot_method_changed) -- going
-- through show() here instead would only prove decorate_row re-reads the threshold, not that
-- anything ever asks it to.
function RoundRobinTrashRowsSpec:should_follow_the_threshold_changing_while_the_window_is_open()
  local frame = window( ItemQuality.Epic )

  frame.expand_trash()
  eq( frame.row( "Uncommon" ).desaturated, true )

  u.loot_threshold( ItemQuality.Uncommon )
  frame.refresh()

  eq( frame.row( "Uncommon" ).desaturated, false )
end

-- A closed window has nothing to correct, and refreshing one would build it just to hide it again.
function RoundRobinTrashRowsSpec:should_not_redraw_a_window_that_is_closed()
  local frame = window( ItemQuality.Epic )

  frame.expand_trash()
  frame.hide()

  u.loot_threshold( ItemQuality.Uncommon )
  frame.refresh()

  -- Still what it was drawn as, because nothing was drawn.
  eq( frame.row( "Uncommon" ).desaturated, true )
end

-- Ticking a row changes whether the category hands anything out, which display addons need to
-- hear about (see main.broadcast_round_robin_selection). Nothing else notices the write: it goes
-- straight onto the persisted entry through AutoLootTree.set_checked, with no db watch behind it.
function RoundRobinTrashRowsSpec:should_report_a_row_being_ticked()
  local frame = window( ItemQuality.Uncommon )

  frame.expand_trash()
  eq( frame.change_count(), 0 )

  frame.row( "Uncommon" ).on_check( true )

  eq( frame.change_count(), 1 )
end

-- Expanding is not a selection change: nothing about what gets handed out is different.
function RoundRobinTrashRowsSpec:should_not_report_merely_expanding_a_category()
  local frame = window( ItemQuality.Uncommon )

  frame.expand_trash()

  eq( frame.change_count(), 0 )
end

-- Item rows have nothing to explain, so they must not pick up a tooltip meant for quality rows.
function RoundRobinTrashRowsSpec:should_leave_item_rows_without_a_label_tooltip()
  local frame = window( ItemQuality.Epic )

  frame.show()

  for _, row in ipairs( { frame.row( "Gems" ), frame.row( "Marks" ), frame.row( "Hearts" ) } ) do
    eq( row.tooltip_text, nil )
  end
end

os.exit( lu.LuaUnit.run() )
