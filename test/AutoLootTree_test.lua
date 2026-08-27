package.path = "./?.lua;" .. package.path .. ";../?.lua;../RollFor/?.lua;../RollFor/libs/?.lua"

require( "src/compat" )
local u = require( "test/utils" )
local lu, eq = u.luaunit( "assertEquals" )
u.multi_require_src( "DebugBuffer", "Module", "Types" )
require( "src/modules" )
u.mock_wow_api()
require( "src/ItemUtils" )
require( "src/AutoLootDb" )
require( "src/Tree" )
local AutoLootTree = require( "src/AutoLootTree" )
local Tree = RollFor.Tree

local function leaf( checked )
  return Tree.new_leaf( { checked = checked, entry = { enabled = checked }, id = 1, item = { name = "Item" } } )
end

local function branch( checked, children )
  return Tree.new_node( { checked = checked, entry = { enabled = checked }, expanded = false, name = "Node" }, children or {} )
end

AutoLootTreeIsLeafEnabledSpec = {}

function AutoLootTreeIsLeafEnabledSpec:should_be_enabled_when_dungeon_boss_and_item_are_all_checked()
  eq( AutoLootTree.is_leaf_enabled( branch( true ), branch( true ), leaf( true ) ), true )
end

function AutoLootTreeIsLeafEnabledSpec:should_be_disabled_when_the_item_itself_is_unchecked()
  eq( AutoLootTree.is_leaf_enabled( branch( true ), branch( true ), leaf( false ) ), false )
end

function AutoLootTreeIsLeafEnabledSpec:should_be_disabled_when_the_boss_is_unchecked()
  eq( AutoLootTree.is_leaf_enabled( branch( true ), branch( false ), leaf( true ) ), false )
end

function AutoLootTreeIsLeafEnabledSpec:should_be_disabled_when_the_dungeon_is_unchecked()
  eq( AutoLootTree.is_leaf_enabled( branch( false ), branch( true ), leaf( true ) ), false )
end

function AutoLootTreeIsLeafEnabledSpec:should_be_disabled_when_everything_is_unchecked()
  eq( AutoLootTree.is_leaf_enabled( branch( false ), branch( false ), leaf( false ) ), false )
end

AutoLootTreeAllCheckedSpec = {}

function AutoLootTreeAllCheckedSpec:should_be_true_when_dungeon_and_every_descendant_are_checked()
  local d = branch( true, { branch( true, { leaf( true ), leaf( true ) } ) } )
  eq( AutoLootTree.all_checked( d ), true )
end

function AutoLootTreeAllCheckedSpec:should_be_false_when_the_dungeon_itself_is_unchecked()
  local d = branch( false, { branch( true, { leaf( true ) } ) } )
  eq( AutoLootTree.all_checked( d ), false )
end

function AutoLootTreeAllCheckedSpec:should_be_false_when_a_boss_is_unchecked_even_if_its_items_are_checked()
  local d = branch( true, { branch( false, { leaf( true ) } ) } )
  eq( AutoLootTree.all_checked( d ), false )
end

function AutoLootTreeAllCheckedSpec:should_be_false_when_a_single_item_is_unchecked()
  local d = branch( true, { branch( true, { leaf( true ), leaf( false ) } ) } )
  eq( AutoLootTree.all_checked( d ), false )
end

AutoLootTreeSetCheckedSpec = {}

function AutoLootTreeSetCheckedSpec:should_toggle_a_leaf_item_on_by_itself()
  local i = leaf( false )

  AutoLootTree.set_checked( i, true )

  eq( i.data.checked, true )
  eq( i.data.entry.enabled, true )
end

function AutoLootTreeSetCheckedSpec:should_toggle_a_leaf_item_off_by_itself()
  local i = leaf( true )

  AutoLootTree.set_checked( i, false )

  eq( i.data.checked, false )
  eq( i.data.entry.enabled, false )
end

function AutoLootTreeSetCheckedSpec:should_cascade_to_all_items_when_boss_and_every_item_share_the_same_state()
  local i1, i2 = leaf( false ), leaf( false )
  local b = branch( false, { i1, i2 } )

  AutoLootTree.set_checked( b, true )

  eq( b.data.checked, true )
  eq( i1.data.checked, true )
  eq( i2.data.checked, true )
end

function AutoLootTreeSetCheckedSpec:should_cascade_off_to_all_items_when_boss_and_every_item_share_the_same_state()
  local i1, i2 = leaf( true ), leaf( true )
  local b = branch( true, { i1, i2 } )

  AutoLootTree.set_checked( b, false )

  eq( b.data.checked, false )
  eq( i1.data.checked, false )
  eq( i2.data.checked, false )
end

function AutoLootTreeSetCheckedSpec:should_write_the_cascaded_state_through_to_each_items_persisted_entry()
  local i1, i2 = leaf( false ), leaf( false )
  local b = branch( false, { i1, i2 } )

  AutoLootTree.set_checked( b, true )

  eq( i1.data.entry.enabled, true )
  eq( i2.data.entry.enabled, true )
end

function AutoLootTreeSetCheckedSpec:should_not_cascade_when_at_least_one_item_already_differs_from_the_boss()
  local matching_item = leaf( false )
  local differing_item = leaf( true )
  local b = branch( false, { matching_item, differing_item } )

  AutoLootTree.set_checked( b, true )

  eq( b.data.checked, true )
  eq( matching_item.data.checked, false )
  eq( differing_item.data.checked, true )
end

function AutoLootTreeSetCheckedSpec:should_toggle_only_the_boss_itself_when_it_has_no_items()
  local b = branch( false, {} )

  AutoLootTree.set_checked( b, true )

  eq( b.data.checked, true )
end

function AutoLootTreeSetCheckedSpec:should_cascade_to_every_boss_and_item_when_the_whole_dungeon_subtree_shares_the_same_state()
  local i1, i2, i3 = leaf( false ), leaf( false ), leaf( false )
  local b1 = branch( false, { i1, i2 } )
  local b2 = branch( false, { i3 } )
  local d = branch( false, { b1, b2 } )

  AutoLootTree.set_checked( d, true )

  eq( d.data.checked, true )
  eq( b1.data.checked, true )
  eq( b2.data.checked, true )
  eq( i1.data.checked, true )
  eq( i2.data.checked, true )
  eq( i3.data.checked, true )
end

function AutoLootTreeSetCheckedSpec:should_not_cascade_to_any_boss_when_one_boss_already_differs_from_the_dungeon()
  local matching_boss = branch( false, { leaf( false ) } )
  local differing_boss = branch( true, { leaf( true ) } )
  local d = branch( false, { matching_boss, differing_boss } )

  AutoLootTree.set_checked( d, true )

  eq( d.data.checked, true )
  eq( matching_boss.data.checked, false )
  eq( differing_boss.data.checked, true )
end

function AutoLootTreeSetCheckedSpec:should_not_cascade_when_a_boss_matches_the_dungeon_but_one_of_its_own_items_does_not()
  local matching_item = leaf( false )
  local differing_item = leaf( true )
  local b = branch( false, { matching_item, differing_item } )
  local d = branch( false, { b } )

  AutoLootTree.set_checked( d, true )

  eq( d.data.checked, true )
  eq( b.data.checked, false )
  eq( matching_item.data.checked, false )
  eq( differing_item.data.checked, true )
end

AutoLootTreeVisibleRowsSpec = {}

function AutoLootTreeVisibleRowsSpec:should_only_show_the_dungeon_row_when_collapsed()
  local d = branch( true, { branch( true, { leaf( true ) } ) } )

  local rows = AutoLootTree.visible_rows( { d } )

  eq( #rows, 1 )
  eq( rows[ 1 ].depth, 0 )
  eq( rows[ 1 ].node, d )
end

function AutoLootTreeVisibleRowsSpec:should_show_bosses_once_the_dungeon_is_expanded()
  local b = branch( true, { leaf( true ) } )
  local d = branch( true, { b } )
  d.data.expanded = true

  local rows = AutoLootTree.visible_rows( { d } )

  eq( #rows, 2 )
  eq( rows[ 2 ].depth, 1 )
  eq( rows[ 2 ].node, b )
end

function AutoLootTreeVisibleRowsSpec:should_show_items_once_the_boss_is_also_expanded()
  local i = leaf( true )
  local b = branch( true, { i } )
  b.data.expanded = true
  local d = branch( true, { b } )
  d.data.expanded = true

  local rows = AutoLootTree.visible_rows( { d } )

  eq( #rows, 3 )
  eq( rows[ 3 ].depth, 2 )
  eq( rows[ 3 ].node, i )
  eq( rows[ 3 ].data, i.data )
end

function AutoLootTreeVisibleRowsSpec:should_desaturate_boss_and_items_when_the_dungeon_is_unchecked()
  local i = leaf( true )
  local b = branch( true, { i } )
  b.data.expanded = true
  local d = branch( false, { b } )
  d.data.expanded = true

  local rows = AutoLootTree.visible_rows( { d } )

  eq( rows[ 1 ].desaturated, true ) -- dungeon: not all_checked( d ), since d.data.checked is false
  eq( rows[ 2 ].desaturated, true ) -- boss: dungeon is off
  eq( rows[ 3 ].desaturated, true ) -- item: dungeon is off
end

function AutoLootTreeVisibleRowsSpec:should_desaturate_dungeon_and_boss_when_a_single_item_is_unchecked_but_not_the_item_itself()
  local checked_item = leaf( true )
  local unchecked_item = leaf( false )
  local b = branch( true, { checked_item, unchecked_item } )
  b.data.expanded = true
  local d = branch( true, { b } )
  d.data.expanded = true

  local rows = AutoLootTree.visible_rows( { d } )

  eq( rows[ 1 ].desaturated, true ) -- dungeon: not all descendants checked
  eq( rows[ 2 ].desaturated, true ) -- boss: not all its own items checked
  eq( rows[ 3 ].desaturated, false ) -- checked item: dungeon and boss are both on
  eq( rows[ 4 ].desaturated, false ) -- unchecked item: still not desaturated -- ancestors are on,
  -- desaturation only reflects ancestor state, not the item's own checked value
end

function AutoLootTreeVisibleRowsSpec:should_desaturate_the_direct_parent_boss_of_an_unchecked_leaf()
  local checked_item = leaf( true )
  local unchecked_item = leaf( false )
  local b = branch( true, { checked_item, unchecked_item } )
  b.data.expanded = true
  local d = branch( true, { b } )
  d.data.expanded = true

  local rows = AutoLootTree.visible_rows( { d } )

  eq( rows[ 2 ].node, b )
  eq( rows[ 2 ].desaturated, true )
end

function AutoLootTreeVisibleRowsSpec:should_desaturate_the_grandparent_dungeon_of_an_unchecked_leaf()
  local checked_item = leaf( true )
  local unchecked_item = leaf( false )
  local b = branch( true, { checked_item, unchecked_item } )
  b.data.expanded = true
  local d = branch( true, { b } )
  d.data.expanded = true

  local rows = AutoLootTree.visible_rows( { d } )

  eq( rows[ 1 ].node, d )
  eq( rows[ 1 ].desaturated, true )
end

function AutoLootTreeVisibleRowsSpec:should_not_desaturate_a_sibling_boss_unrelated_to_the_unchecked_leaf()
  local unchecked_item = leaf( false )
  local affected_boss = branch( true, { unchecked_item } )
  affected_boss.data.expanded = true

  local unaffected_item = leaf( true )
  local unaffected_boss = branch( true, { unaffected_item } )
  unaffected_boss.data.expanded = true

  local d = branch( true, { affected_boss, unaffected_boss } )
  d.data.expanded = true

  local rows = AutoLootTree.visible_rows( { d } )

  -- [1] dungeon, [2] affected_boss, [3] unchecked_item, [4] unaffected_boss, [5] unaffected_item
  eq( rows[ 1 ].desaturated, true ) -- grandparent: still desaturated, one bad leaf is enough
  eq( rows[ 2 ].desaturated, true ) -- direct parent of the unchecked leaf
  eq( rows[ 4 ].node, unaffected_boss )
  eq( rows[ 4 ].desaturated, false ) -- sibling boss with no unchecked descendants of its own
end

os.exit( lu.LuaUnit.run() )
