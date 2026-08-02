RollFor = RollFor or {}
local m = RollFor

if m.AutoLootTree then return end

local M = {}
local Tree = m.Tree

-- Builds a Dungeon -> Boss -> Item drops tree (using the generic Tree module for structure) from
-- AutoLootDb's hardcoded data (name/link/icon already resolved there). expanded/checked are
-- UI-only state AutoLootDb doesn't know about, so they get bolted on here as each node's `data`.
-- This whole file is the AutoLoot-domain layer: it's the only thing that knows nodes have a
-- `checked`/`expanded` concept at all -- Tree.lua itself doesn't.
local function sorted_keys( t )
  local keys = {}
  for key in pairs( t ) do table.insert( keys, key ) end
  table.sort( keys )

  return keys
end

-- Same as sorted_keys, but by each entry's own `order` field (e.g. real boss encounter order)
-- rather than alphabetically by name. Entries without an `order` sort after ones that have it.
local function ordered_keys( t )
  local keys = sorted_keys( t )

  table.sort( keys, function( a, b )
    local order_a = t[ a ].order or math.huge
    local order_b = t[ b ].order or math.huge

    if order_a == order_b then return a < b end

    return order_a < order_b
  end )

  return keys
end

-- Presentation for the tree itself: which colors dungeons/bosses/items get. AutoLootDb only ever
-- holds real WoW facts (quality, icon, name) -- how THIS tree chooses to display those facts is
-- this module's decision, not AutoLootDb's.
local DUNGEON_COLOR = { 0.125, 0.624, 0.976 }
local DUNGEON_HOVER_TEXT_COLOR = { 0.5, 0.8, 1 }
local BOSS_HOVER_TEXT_COLOR = { 0.625, 0.624, 0.976 }

local TRASH_COLOR = { 0.45, 0.45, 0.45 }
local TRASH_HOVER_TEXT_COLOR = { 0.65, 0.65, 0.65 }

-- AutoLootDb only owns the verified |cffXXXXXX fact per quality (see quality_color_hex) -- turning
-- that into an { r, g, b, a } highlight is this tree's own display decision, so the parsing lives
-- here.
---@param quality number
---@param a number
---@return number[]
local function quality_color_rgb( quality, a )
  local hex = m.AutoLootDb.quality_color_hex( quality )
  local rr, gg, bb = hex:match( "(%x%x)(%x%x)(%x%x)$" )
  return { tonumber( rr, 16 ) / 255, tonumber( gg, 16 ) / 255, tonumber( bb, 16 ) / 255, a }
end

local ITEM_HOVER_BACKGROUND_ALPHA = 0.25

-- Keeps the item tooltip from covering the row itself. Same kind of display choice as the colors
-- above, just expressed as an anchor + coordinate transform instead of a color -- GuiElements owns
-- reading the cursor and calling SetPoint, this module owns which point and how far to shift it.
local ITEM_TOOLTIP_ANCHOR = "LEFT"
local ITEM_TOOLTIP_OFFSET_X = 100

---@param x number
---@param y number
---@return string, number, number
local function item_tooltip_position( x, y )
  return ITEM_TOOLTIP_ANCHOR, x + ITEM_TOOLTIP_OFFSET_X, y
end

---@return TreeNode[]
local function build_tree()
  local dungeons = {}

  for _, dungeon_name in ipairs( ordered_keys( m.AutoLootDb.ids ) ) do
    local dungeon_entry = m.AutoLootDb.ids[ dungeon_name ]

    if dungeon_entry.enabled then
      local bosses = {}

      for _, boss_name in ipairs( ordered_keys( dungeon_entry.bosses or {} ) ) do
        local boss_entry = dungeon_entry.bosses[ boss_name ]

        if boss_entry.enabled then
          local items = {}

          for _, item_id in ipairs( sorted_keys( boss_entry.items or {} ) ) do
            local item_data = boss_entry.items[ item_id ]
            if item_data.enabled then
              table.insert( items, Tree.new_leaf( {
                id = item_id,
                item = item_data,
                hover_background_color = quality_color_rgb( item_data.quality, ITEM_HOVER_BACKGROUND_ALPHA ),
                tooltip_position = item_tooltip_position,
                checked = true,
              } ) )
            end
          end

          local is_trash = boss_name == "Trash"

          table.insert( bosses, Tree.new_node( {
            name = boss_name,
            color = is_trash and TRASH_COLOR or nil,
            hover_text_color = is_trash and TRASH_HOVER_TEXT_COLOR or BOSS_HOVER_TEXT_COLOR,
            checked = true,
            expanded = false,
          }, items ) )
        end
      end

      table.insert( dungeons, Tree.new_node( {
        name = dungeon_name,
        color = DUNGEON_COLOR,
        hover_text_color = DUNGEON_HOVER_TEXT_COLOR,
        checked = true,
        expanded = false,
      }, bosses ) )
    end
  end

  return dungeons
end

---@type TreeNode[]
M.dungeons = build_tree()

-- Each node's own `data.checked` is independent and never touched by its parent/ancestors --
-- toggling a dungeon or boss only ever sets that node's own flag, nothing cascades down. Children
-- just render desaturated (see visible_rows below) while an ancestor is off, remembering their
-- own state for whenever that ancestor is turned back on.

-- An item only actually counts as enabled (e.g. for auto-loot) if it and every node above it are
-- checked -- a checked item under an unchecked boss/dungeon is not effectively enabled.
---@param dungeon TreeNode
---@param boss TreeNode
---@param item TreeNode
---@return boolean
function M.is_leaf_enabled( dungeon, boss, item )
  return (dungeon.data.checked and boss.data.checked and item.data.checked) and true or false
end

-- True only if this node and every descendant (recursively) are checked. AutoLoot's own selection
-- semantics (checked propagation) -- not a generic tree concept, so it lives here, not in Tree.lua.
-- Built on Tree.walk: stops at the first unchecked node instead of visiting the whole tree.
---@param node TreeNode
---@return boolean
function M.all_checked( node )
  local ok = true

  Tree.walk( { node }, nil, function( n )
    if not n.data.checked then
      ok = false
      return false, nil, true -- stop the whole walk immediately, no point checking the rest
    end
  end )

  return ok
end

---@class AutoLootTreeRow
---@field depth number
---@field node TreeNode the node this row was built from -- callers wire click/check callbacks
--- against it and mutate node.data directly (expanded/checked); this module never does.
---@field expandable boolean
---@field expanded boolean?
---@field checked boolean
---@field desaturated boolean
---@field data table same opaque payload as node.data, copied here for convenience

-- Flattens the tree into exactly the rows that should currently be visible (respecting each
-- node's own `data.expanded`), with checked/desaturated already decided. Pure data in, pure data
-- out -- no widgets, no callbacks, no rendering. The GUI layer's job is just to dumbly render this
-- list. This is AutoLoot-specific (desaturation/visibility are selection-tree concepts), unlike
-- Tree.lua which only knows about children/data. Built on Tree.walk: only descends into expanded
-- non-leaf nodes, threading "are all ancestors checked so far" down as the walk's context.
---@param nodes TreeNode[]
---@return AutoLootTreeRow[]
function M.visible_rows( nodes )
  local rows = {}

  Tree.walk( nodes, true, function( node, depth, ancestors_checked )
    local is_leaf = node.children == nil
    -- A leaf's own checked state never affects its own desaturation, only its ancestors'.
    local desaturated

    if is_leaf then
      desaturated = not ancestors_checked
    else
      desaturated = not ancestors_checked or not M.all_checked( node )
    end

    table.insert( rows, {
      depth = depth,
      node = node,
      expandable = not is_leaf,
      expanded = node.data.expanded,
      checked = node.data.checked,
      desaturated = desaturated,
      data = node.data,
    } )

    local should_descend = not is_leaf and node.data.expanded
    return should_descend, ancestors_checked and node.data.checked
  end )

  return rows
end

m.AutoLootTree = M
return M
