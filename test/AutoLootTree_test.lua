package.path = "./?.lua;" .. package.path .. ";../?.lua;../RollFor/?.lua;../RollFor/libs/?.lua"

require( "src/compat" )
local u = require( "test/utils" )
local lu, eq = u.luaunit( "assertEquals" )
u.multi_require_src( "DebugBuffer", "Module", "Types" )
require( "src/modules" )
u.mock_wow_api()
require( "src/ItemUtils" )
require( "src/ItemCatalogue" ) -- the catalogue helpers AutoLootDb delegates its seeding and queries to
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

-- build() is what lets a second catalogue (the round-robin one) reuse this tree: it takes the
-- non-boss set from whoever owns the catalogue instead of reaching for AutoLootDb's, and hands
-- back the roots rather than assigning them to the module-level M.dungeons that auto-loot owns.
AutoLootTreeBuildSpec = {}

local function catalogue_db()
  return {
    ids = {
      [ "Black Temple" ] = {
        enabled = true,
        order = 1,
        bosses = {
          [ "Gems" ] = {
            enabled = false,
            order = 1,
            items = { [ 32227 ] = { enabled = false, quality = 4, icon = 1, name = "Crimson Spinel" } }
          },
          [ "Illidan Stormrage" ] = {
            enabled = false,
            order = 2,
            items = { [ 32235 ] = { enabled = true, quality = 4, icon = 2, name = "Cursed Vision of Sargeras" } }
          }
        }
      }
    }
  }
end

---@param roots table
---@param boss_name string
local function boss_node( roots, boss_name )
  for _, boss in ipairs( roots[ 1 ].children ) do
    if boss.data.name == boss_name then return boss end
  end
end

function AutoLootTreeBuildSpec:should_build_the_roots_from_the_dbs_own_selection_state()
  local roots = AutoLootTree.build( catalogue_db(), {} )

  eq( #roots, 1 )
  eq( roots[ 1 ].data.name, "Black Temple" )
  eq( roots[ 1 ].data.checked, true )
  eq( boss_node( roots, "Illidan Stormrage" ).children[ 1 ].data.checked, true )
end

function AutoLootTreeBuildSpec:should_grey_out_the_nodes_the_supplied_non_boss_set_names()
  local roots = AutoLootTree.build( catalogue_db(), { [ "Gems" ] = true } )

  local gems = boss_node( roots, "Gems" )
  local illidan = boss_node( roots, "Illidan Stormrage" )

  lu.assertNotEquals( gems.data.color, illidan.data.color )
  lu.assertNotEquals( gems.data.hover_text_color, illidan.data.hover_text_color )
end

-- The same name is only a non-boss for the catalogue that says so: "Gems" is one in the
-- round-robin catalogue and nothing at all in the auto-loot one.
function AutoLootTreeBuildSpec:should_treat_a_node_as_a_boss_when_the_non_boss_set_does_not_name_it()
  local as_boss = boss_node( AutoLootTree.build( catalogue_db(), {} ), "Gems" )
  local as_non_boss = boss_node( AutoLootTree.build( catalogue_db(), { [ "Gems" ] = true } ), "Gems" )

  eq( as_boss.data.color, boss_node( AutoLootTree.build( catalogue_db(), {} ), "Illidan Stormrage" ).data.color )
  lu.assertNotEquals( as_non_boss.data.color, as_boss.data.color )
end

-- build_flat is the round-robin catalogue's shape: Category -> items, two levels rather than
-- three. Everything downstream walks children rather than counting levels, so the only thing
-- worth proving is that the roots come out right.
AutoLootTreeBuildFlatSpec = {}

local function flat_db()
  return {
    ids = {
      [ "Hearts" ] = {
        enabled = false,
        order = 3,
        items = { [ 32428 ] = { enabled = true, quality = 3, icon = 1, name = "Heart of Darkness" } }
      },
      [ "Gems" ] = {
        enabled = true,
        order = 1,
        items = {
          [ 32227 ] = { enabled = true, quality = 4, icon = 2, name = "Crimson Spinel" },
          [ 32228 ] = { enabled = false, quality = 4, icon = 3, name = "Empyrean Sapphire" }
        }
      }
    }
  }
end

function AutoLootTreeBuildFlatSpec:should_put_the_items_directly_under_their_category()
  local roots = AutoLootTree.build_flat( flat_db() )

  eq( #roots, 2 )
  eq( roots[ 1 ].data.name, "Gems" )
  eq( #roots[ 1 ].children, 2 )
  -- Leaves, so no children of their own -- the tree really is two deep.
  eq( roots[ 1 ].children[ 1 ].children, nil )
end

function AutoLootTreeBuildFlatSpec:should_order_categories_by_the_catalogues_own_order()
  local roots = AutoLootTree.build_flat( flat_db() )

  eq( roots[ 1 ].data.name, "Gems" )
  eq( roots[ 2 ].data.name, "Hearts" )
end

function AutoLootTreeBuildFlatSpec:should_take_each_rows_checked_state_from_the_persisted_db()
  local roots = AutoLootTree.build_flat( flat_db() )

  eq( roots[ 1 ].data.checked, true )
  eq( roots[ 2 ].data.checked, false )
  eq( roots[ 1 ].children[ 1 ].data.checked, true )
  eq( roots[ 1 ].children[ 2 ].data.checked, false )
end

-- Categories are the top level, so they take the top-level colour rather than the boss one.
function AutoLootTreeBuildFlatSpec:should_colour_categories_as_top_level_rows()
  local flat = AutoLootTree.build_flat( flat_db() )
  local nested = AutoLootTree.build( catalogue_db(), {} )

  eq( flat[ 1 ].data.color, nested[ 1 ].data.color )
end

-- The two-level tree feeds the same visible_rows / set_checked the three-level one does.
function AutoLootTreeBuildFlatSpec:should_work_with_the_rest_of_the_tree()
  local db = flat_db()
  local roots = AutoLootTree.build_flat( db )

  -- Collapsed, so only the two category rows show.
  eq( #AutoLootTree.visible_rows( roots ), 2 )

  roots[ 1 ].data.expanded = true
  eq( #AutoLootTree.visible_rows( roots ), 4 )

  AutoLootTree.set_checked( roots[ 2 ], true )
  eq( db.ids[ "Hearts" ].enabled, true )
end

-- The round-robin catalogue's Trash category names qualities instead of item ids, so its rows are
-- label leaves: a name and no id/item, which is what makes the window render them as a coloured
-- word with a checkbox rather than as an item link.
AutoLootTreeBuildFlatQualitiesSpec = {}

local function trash_db()
  return {
    ids = {
      [ "Trash" ] = {
        enabled = true,
        order = 99,
        items = {},
        qualities = {
          [ 3 ] = { enabled = true, name = "Rare" },
          [ 2 ] = { enabled = false, name = "Uncommon" }
        }
      }
    }
  }
end

function AutoLootTreeBuildFlatQualitiesSpec:should_build_quality_rows_as_leaves_with_a_name_and_no_item()
  local trash = AutoLootTree.build_flat( trash_db() )[ 1 ]

  eq( #trash.children, 2 )
  eq( trash.children[ 1 ].children, nil )
  eq( trash.children[ 1 ].data.name, "Uncommon" )
  eq( trash.children[ 1 ].data.id, nil )
  eq( trash.children[ 1 ].data.item, nil )
end

-- Ascending, so the window reads Uncommon then Rare rather than in whatever order pairs() yields.
function AutoLootTreeBuildFlatQualitiesSpec:should_order_quality_rows_by_quality()
  local trash = AutoLootTree.build_flat( trash_db() )[ 1 ]

  eq( trash.children[ 1 ].data.quality, 2 )
  eq( trash.children[ 2 ].data.quality, 3 )
end

function AutoLootTreeBuildFlatQualitiesSpec:should_take_each_quality_rows_checked_state_from_the_db()
  local trash = AutoLootTree.build_flat( trash_db() )[ 1 ]

  eq( trash.children[ 1 ].data.checked, false )
  eq( trash.children[ 2 ].data.checked, true )
end

-- Colour by quality, the same fact item rows are tinted by -- a green row for Uncommon, blue for
-- Rare -- so the two rows say which they are without reading them.
function AutoLootTreeBuildFlatQualitiesSpec:should_colour_each_quality_row_by_its_own_quality()
  local trash = AutoLootTree.build_flat( trash_db() )[ 1 ]

  lu.assertNotEquals( trash.children[ 1 ].data.color, trash.children[ 2 ].data.color )
  lu.assertNotEquals( trash.children[ 1 ].data.color, nil )
end

-- Ticking one writes back to the persisted entry exactly as an item row does.
function AutoLootTreeBuildFlatQualitiesSpec:should_write_a_toggle_back_to_the_persisted_quality_entry()
  local db = trash_db()
  local trash = AutoLootTree.build_flat( db )[ 1 ]

  AutoLootTree.set_checked( trash.children[ 1 ], true )

  eq( db.ids[ "Trash" ].qualities[ 2 ].enabled, true )
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
