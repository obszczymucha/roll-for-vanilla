RollFor = RollFor or {}
local m = RollFor

if m.SelectionTree then return end

local M = {}
local Tree = m.Tree

---@class SelectionTree
---@field build fun( db: table, non_bosses: table<string, boolean> ): TreeNode[]
---@field build_flat fun( db: table ): TreeNode[]
---@field all_checked fun( node: TreeNode ): boolean
---@field set_checked fun( node: TreeNode, checked: boolean )
---@field visible_rows fun( nodes: TreeNode[] ): SelectionTreeVisibleRow[]

-- A tree of things the player can tick, built out of a persisted selection db (using the generic
-- Tree module for structure). The db holds the facts -- name, icon, quality -- and an `enabled`
-- per node; expanded/checked are UI state the db knows nothing about, so they get bolted on here
-- as each node's `data`.
--
-- This is the selection layer: the only thing that knows nodes have a `checked`/`expanded`
-- concept at all -- Tree.lua itself doesn't. What is in the tree, and what ticking a row means,
-- belongs to whoever owns the catalogue.
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

-- Presentation for the tree itself: which colors the levels get. A selection db only ever holds
-- real WoW facts (quality, icon, name) -- how THIS tree chooses to display those facts is this
-- module's decision, not the db's.
local DUNGEON_COLOR = { 0.125, 0.624, 0.976 }
local DUNGEON_HOVER_TEXT_COLOR = { 0.5, 0.8, 1 }
local BOSS_HOVER_TEXT_COLOR = { 0.625, 0.624, 0.976 }

local BOSS_COLOR = { 1, 1, 1 }
local TRASH_COLOR = { 0.45, 0.45, 0.45 }
local TRASH_HOVER_TEXT_COLOR = { 0.65, 0.65, 0.65 }

-- A catalogue may name a node's colour as RRGGBB; turning that into an { r, g, b, a } highlight
-- is this tree's own display decision, so the parsing lives here.
---@param hex string -- RRGGBB
---@param a number
---@return number[]
local function hex_color_rgb( hex, a )
  local rr, gg, bb = hex:match( "(%x%x)(%x%x)(%x%x)$" )
  return { tonumber( rr, 16 ) / 255, tonumber( gg, 16 ) / 255, tonumber( bb, 16 ) / 255, a }
end

-- The client already keeps a colour per quality, as floats, so there is nothing to look up here
-- and nothing to parse. Unknown qualities fall back to Poor.
---@param quality number?
---@param a number
---@return number[]
local function quality_color_rgb( quality, a )
  local colors = m.api.ITEM_QUALITY_COLORS
  local color = colors[ quality or 0 ] or colors[ 0 ]

  return { color.r, color.g, color.b, a }
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

-- The entries here come from the persisted selection db, already seeded: everything in the
-- catalogue is present and carries its own `enabled`, which is this tree's initial checked state
-- and the write-back target for toggling (see set_checked below). No enabled-based filtering:
-- a seeded entry always exists, it is just off (enabled = false) by default.
-- The leaves are the same in every catalogue: an item is an item.
---@param items table -- persisted item entries, keyed by item id
---@return TreeNode[]
local function build_items( items )
  local result = {}

  for _, item_id in ipairs( sorted_keys( items or {} ) ) do
    local item_entry = items[ item_id ]

    table.insert( result, Tree.new_leaf( {
      id = item_id,
      item = item_entry,
      entry = item_entry,
      hover_background_color = quality_color_rgb( item_entry.quality, ITEM_HOVER_BACKGROUND_ALPHA ),
      tooltip_position = item_tooltip_position,
      checked = item_entry.enabled,
    } ) )
  end

  return result
end

-- A catalogue node may name qualities instead of item ids, in which case its rows have a name
-- and no item. That makes them label leaves -- a checkbox and a coloured word, no icon and no
-- item tooltip -- which is why they carry `name` where an item row would carry `id`/`item`.
--
-- The quality is carried along too, unused here: a window may read it to work out whether the
-- master loot threshold has made the row inert. This tree has no business asking the client
-- anything, so it only passes the fact on.
---@param qualities table -- persisted quality entries, keyed by quality
---@return TreeNode[]
local function build_qualities( qualities )
  local result = {}
  local keys = {}

  for quality in pairs( qualities or {} ) do table.insert( keys, quality ) end
  table.sort( keys )

  for _, quality in ipairs( keys ) do
    local entry = qualities[ quality ]

    table.insert( result, Tree.new_leaf( {
      name = entry.name,
      entry = entry,
      quality = quality,
      color = quality_color_rgb( quality, 1 ),
      hover_background_color = quality_color_rgb( quality, ITEM_HOVER_BACKGROUND_ALPHA ),
      checked = entry.enabled,
    } ) )
  end

  return result
end

---@param name string
---@param entry table -- the persisted node this row writes its `enabled` back to
---@param color number[]
---@param hover_text_color number[]
---@param children TreeNode[]
---@return TreeNode
local function build_group( name, entry, color, hover_text_color, children )
  return Tree.new_node( {
    name = name,
    entry = entry,
    color = color,
    hover_text_color = hover_text_color,
    checked = entry.enabled,
    expanded = false,
  }, children )
end

---@param ids table
---@param non_bosses table<string, boolean> -- which node names under a dungeon aren't encounters
---@return TreeNode[]
local function build_tree( ids, non_bosses )
  local dungeons = {}

  for _, dungeon_name in ipairs( ordered_keys( ids ) ) do
    local dungeon_entry = ids[ dungeon_name ]
    local bosses = {}

    -- A catalogue entry names either encounters or qualities, never both. The second kind draws
    -- quality leaves, the same ones build_flat's categories draw, so those serve here too.
    --
    -- An entry may name the colour it is drawn in, as RRGGBB. Everything that names none is a
    -- raid, and raids are dungeon blue.
    local color = dungeon_entry.color and hex_color_rgb( dungeon_entry.color, 1 ) or DUNGEON_COLOR
    local hover_text_color = dungeon_entry.color and color or DUNGEON_HOVER_TEXT_COLOR

    if dungeon_entry.qualities then
      table.insert( dungeons, build_group( dungeon_name, dungeon_entry,
        color, hover_text_color, build_qualities( dungeon_entry.qualities ) ) )
    end

    for _, boss_name in ipairs( ordered_keys( dungeon_entry.bosses or {} ) ) do
      local boss_entry = dungeon_entry.bosses[ boss_name ]

      -- Trash and Patterns aren't bosses, so they don't get the boss colour. Which names those
      -- are is the catalogue's answer, not this tree's.
      local is_trash = non_bosses[ boss_name ] and true or false

      table.insert( bosses, build_group( boss_name, boss_entry,
        is_trash and TRASH_COLOR or BOSS_COLOR,
        is_trash and TRASH_HOVER_TEXT_COLOR or BOSS_HOVER_TEXT_COLOR,
        build_items( boss_entry.items ) ) )
    end

    if not dungeon_entry.qualities then
      table.insert( dungeons, build_group( dungeon_name, dungeon_entry, color, hover_text_color, bosses ) )
    end
  end

  return dungeons
end

-- Builds a Dungeon -> Boss -> items tree out of an already-seeded selection db. Takes the
-- catalogue's own non-boss set rather than reaching for one, and returns the roots instead of
-- assigning them anywhere: more than one window is built from this module, so a module-level
-- singleton could only belong to one of them.
---@param db table -- a persisted selection db, already seeded
---@param non_bosses table<string, boolean>
---@return TreeNode[]
function M.build( db, non_bosses )
  return build_tree( db.ids, non_bosses )
end

-- Builds a Category -> items tree: the same thing one level shallower, for a catalogue with no
-- encounter layer. Every layer below the top is the same as build's, and everything downstream --
-- visible_rows, set_checked, the whole frame -- walks children rather than counting levels, so
-- nothing else has to know the tree is two deep instead of three.
--
-- Categories take the top-level colour for the same reason dungeons do: they are the top level.
---@param db table -- a persisted selection db, already seeded
---@return TreeNode[]
function M.build_flat( db )
  local categories = {}

  for _, category_name in ipairs( ordered_keys( db.ids or {} ) ) do
    local entry = db.ids[ category_name ]

    -- A category names either item ids or qualities, never both -- the Trash fallback is the only
    -- one of the second kind, and asking which it is here keeps every layer below this one
    -- ignorant of the difference: both branches return leaves.
    local children = entry.qualities and build_qualities( entry.qualities ) or build_items( entry.items )

    -- A category may name the colour it is drawn in. Falls back to the dungeon blue every
    -- top-level node gets when it names none.
    local color = entry.color and hex_color_rgb( entry.color, 1 ) or DUNGEON_COLOR

    table.insert( categories, build_group( category_name, entry,
      color, entry.color and color or DUNGEON_HOVER_TEXT_COLOR, children ) )
  end

  return categories
end

-- Each node's own `data.checked` is independent and never touched by its parent/ancestors --
-- toggling a dungeon or boss only ever sets that node's own flag, nothing cascades down. Children
-- just render desaturated (see visible_rows below) while an ancestor is off, remembering their
-- own state for whenever that ancestor is turned back on.

-- True only if this node and every descendant (recursively) are checked. Selection semantics
-- (checked propagation) -- not a generic tree concept, so it lives here, not in Tree.lua.
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

---@param node TreeNode
---@param checked boolean
local function apply_checked( node, checked )
  node.data.checked = checked
  node.data.entry.enabled = checked
end

-- Whether every node in node's own subtree (node included) is currently checked == value. Used to
-- decide whether toggling a dungeon/boss is safe to cascade: only when the whole subtree already
-- agreed with the node's own (pre-toggle) state, so a deliberate partial selection underneath
-- never gets silently clobbered.
---@param node TreeNode
---@param value boolean
---@return boolean
local function subtree_matches( node, value )
  local matches = true

  Tree.walk( { node }, nil, function( n )
    if n.data.checked ~= value then
      matches = false
      return false, nil, true -- stop the whole walk immediately, no point checking the rest
    end
  end )

  return matches
end

-- Toggling a row writes through to the persisted entry as well as
-- the node's own in-memory checked state, so the selection survives a /reload instead of resetting
-- to whatever build_tree seeded it with. A dungeon/boss also cascades the new state down to every
-- descendant, but only if the whole subtree currently shares its own (pre-toggle) checked state --
-- if even one descendant already differs, that's a deliberate partial selection, so only the
-- toggled node itself changes.
---@param node TreeNode
---@param checked boolean
function M.set_checked( node, checked )
  if node.children and subtree_matches( node, node.data.checked ) then
    Tree.walk( { node }, nil, function( n ) apply_checked( n, checked ) end )
  else
    apply_checked( node, checked )
  end
end

---@class SelectionTreeVisibleRow
---@field depth number
---@field node TreeNode the node this row was built from -- callers wire click/check callbacks
--- against it, mutating node.data.expanded directly and going through set_checked for checked.
---@field expandable boolean
---@field expanded boolean?
---@field checked boolean
---@field desaturated boolean
---@field data table same opaque payload as node.data, copied here for convenience

-- Flattens the tree into exactly the rows that should currently be visible (respecting each
-- node's own `data.expanded`), with checked/desaturated already decided. Pure data in, pure data
-- out -- no widgets, no callbacks, no rendering. The GUI layer's job is just to dumbly render this
-- list. This is selection-specific (desaturation and visibility are selection concepts), unlike
-- Tree.lua which only knows about children/data. Built on Tree.walk: only descends into expanded
-- non-leaf nodes, threading "are all ancestors checked so far" down as the walk's context.
---@param nodes TreeNode[]
---@return SelectionTreeVisibleRow[]
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

m.SelectionTree = M
return M
