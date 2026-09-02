RollFor = RollFor or {}
local m = RollFor

if m.AutoRoundRobinDb then return end

local M = {}
local catalogue = m.ItemCatalogue

-- The round-robin catalogue: which items /rf autorobin is allowed to hand out, grouped into
-- categories. Deliberately narrow. Round robin awards loot on its own, so what belongs here is
-- the bulk-consumable end of the drop table that nobody wants to burn a roll on.
--
-- Two levels, Category -> items, where auto-loot's is three (Dungeon -> Boss -> items). Which
-- raid a gem fell out of is not a fact this feature has any use for -- one gem is one gem, and
-- one queue serves all of them -- so the raid level is not modelled at all. That is also why the
-- seeding and query functions below are here rather than shared with AutoLootDb through
-- ItemCatalogue: the two catalogues no longer have the same shape, and only the item link
-- helpers survive as genuinely common ground.
--
-- The categories are the unit of rotation: each one owns an independent queue (see
-- AutoRoundRobin), so adding a category here adds a queue with no other change.
--
-- The ids and icons are the ones already verified in AutoLootDb (Black Temple Trash), not
-- re-derived, so nothing here needs a live GetItemInfo fetch.
--
-- Trash (below) is the one category that names no ids at all -- see the comment on it.
local TRASH = "Trash"

local ids = {
  [ "Gems" ] = {
    order = 1,
    items = {
      [ 32227 ] = { quality = 4, icon = 133238, name = "Crimson Spinel" },
      [ 32228 ] = { quality = 4, icon = 133244, name = "Empyrean Sapphire" },
      [ 32229 ] = { quality = 4, icon = 133248, name = "Lionseye" },
      [ 32230 ] = { quality = 4, icon = 133265, name = "Shadowsong Amethyst" },
      [ 32231 ] = { quality = 4, icon = 133260, name = "Pyrestone" },
      [ 32249 ] = { quality = 4, icon = 133263, name = "Seaspray Emerald" },
    }
  },
  [ "Marks" ] = {
    order = 2,
    items = {
      [ 32897 ] = { quality = 2, icon = 136172, name = "Mark of the Illidari" },
    }
  },
  [ "Hearts" ] = {
    order = 3,
    items = {
      [ 32428 ] = { quality = 3, icon = 136150, name = "Heart of Darkness" },
    }
  },
  -- The fallback. Every other category names item ids; this one names qualities, so it catches
  -- the bulk of a raid's trash drops without anybody maintaining a list for them. It sorts last
  -- (see the order), which is what makes it a fallback rather than a competitor: an item is only
  -- ever trash once every real category has passed on it.
  --
  -- Epic and above are deliberately unreachable here -- an epic is never nobody's business -- so
  -- these two rows are the whole of it.
  --
  -- The other half of the rule is not enforced in this file at all. An item below the master loot
  -- threshold cannot be handed out by GiveMasterLoot in the first place, and the award pass
  -- already rejects those before it ever asks which category serves them (see
  -- AutoRoundRobin.is_awardable). So ticking Uncommon while the threshold is Rare is inert, and
  -- the window is what says so -- re-deriving the threshold here would only give the two places
  -- a chance to disagree.
  [ TRASH ] = {
    order = 99,
    qualities = {
      [ 2 ] = { name = "Uncommon" },
      [ 3 ] = { name = "Rare" },
    }
  },
}

-- Only ever used to name a quality in a sentence (see the window's inert-row tooltip), never to
-- decide anything.
local quality_names = {
  [ 0 ] = "Poor",
  [ 1 ] = "Common",
  [ 2 ] = "Uncommon",
  [ 3 ] = "Rare",
  [ 4 ] = "Epic",
  [ 5 ] = "Legendary"
}

---@param quality number
---@return string
function M.quality_name( quality )
  return quality_names[ quality ] or tostring( quality )
end

-- Categories in catalogue order, which is the order the tree draws them and the order the
-- Queues dropdown offers them.
---@param db table? -- the persisted autorobin_db; falls back to the static catalogue
---@return string[]
function M.categories( db )
  local source = db and db.ids or ids
  local names = {}

  for name in pairs( source ) do table.insert( names, name ) end

  table.sort( names, function( a, b )
    local order_a = (source[ a ].order or math.huge)
    local order_b = (source[ b ].order or math.huge)

    if order_a == order_b then return a < b end

    return order_a < order_b
  end )

  return names
end

-- Seeds the persisted db from the static catalogue above. Same contract ItemCatalogue.ensure_seeded
-- documents for the nested shape: additions appear disabled, `enabled` on rows that already exist
-- is never touched, and entries no longer in the catalogue are left alone rather than pruned.
---@param db table the persisted autorobin_db
function M.ensure_seeded( db )
  db.ids = db.ids or {}

  for category_name, category_entry in pairs( ids ) do
    local category = db.ids[ category_name ] or { enabled = false }
    category.order = category_entry.order
    category.items = category.items or {}

    for item_id, item_entry in pairs( category_entry.items or {} ) do
      local item = category.items[ item_id ] or { enabled = false }
      item.quality = item_entry.quality
      item.icon = item_entry.icon
      item.name = item_entry.name

      category.items[ item_id ] = item
    end

    -- Same contract as the items above, for the one category whose rows are qualities rather
    -- than ids: a row that isn't there yet appears disabled, one that is keeps its `enabled`.
    if category_entry.qualities then
      category.qualities = category.qualities or {}

      for quality, quality_entry in pairs( category_entry.qualities ) do
        local entry = category.qualities[ quality ] or { enabled = false }
        entry.name = quality_entry.name

        category.qualities[ quality ] = entry
      end
    end

    db.ids[ category_name ] = category
  end
end

-- Whether the catalogue names this item at all, ticked or not. The fallback asks before claiming
-- anything: unticking Hearts means "don't round robin Heart of Darkness", and quietly rerouting
-- it to the Trash queue instead is not what turning it off meant.
--
-- Reads the static catalogue rather than the persisted db, because being a known item is a fact
-- of the catalogue and not of anybody's selection. One consequence worth knowing: an item dropped
-- from the catalogue above stops being known and becomes eligible for Trash, even though
-- ensure_seeded leaves its stale entry in the db.
---@param item_id number
---@return boolean
function M.is_catalogued( item_id )
  for _, category in pairs( ids ) do
    if category.items and category.items[ item_id ] then return true end
  end

  return false
end

-- The fallback, asked only after every real category has passed. Quality alone decides, because
-- that is all this category knows about an item.
---@param db table the persisted autorobin_db
---@param quality number?
---@return string?
local function find_trash_category( db, quality )
  if not quality then return nil end

  local trash = db.ids[ TRASH ]
  if not trash or not trash.enabled then return nil end

  local entry = trash.qualities and trash.qualities[ quality ]

  return entry and entry.enabled and TRASH or nil
end

-- Which category's queue should serve this item -- the question the award pass asks, and the
-- reason this lookup exists at all. Reads the persisted db, not the static catalogue: an item
-- under a disabled category is not on the list, so it has no queue.
---@param db table the persisted autorobin_db
---@param item_id number
---@param quality number? -- without it the Trash fallback can't be reached, only the ids
---@return string? -- nil when the item isn't enabled anywhere
function M.find_category( db, item_id, quality )
  if not db or not db.ids then return nil end

  -- Catalogue order, so an item listed under two categories always resolves to the same one
  -- rather than to whatever pairs() happened to yield first. Trash sorts last but can never match
  -- here -- it holds no ids -- so this loop is exactly "did a real category claim it".
  for _, category_name in ipairs( M.categories( db ) ) do
    local category = db.ids[ category_name ]

    if category.enabled then
      local item = category.items and category.items[ item_id ]
      if item and item.enabled then return category_name end
    end
  end

  -- A catalogued item that no enabled category claimed was switched off on purpose, so it stops
  -- here instead of falling through to Trash.
  if M.is_catalogued( item_id ) then return nil end

  return find_trash_category( db, quality )
end

---@param db table the persisted autorobin_db
---@param item_id number
---@param quality number?
---@return boolean
function M.is_enabled( db, item_id, quality )
  return M.find_category( db, item_id, quality ) and true or false
end

-- Whether the player has anything at all selected. Stops at the first hit instead of counting.
---@param db table the persisted autorobin_db
---@return boolean
function M.has_enabled_items( db )
  if not db or not db.ids then return false end

  for _, category in pairs( db.ids ) do
    if category.enabled then
      for _, item in pairs( category.items or {} ) do
        if item.enabled then return true end
      end

      for _, quality in pairs( category.qualities or {} ) do
        if quality.enabled then return true end
      end
    end
  end

  return false
end

---@param item_id number
---@param quality number
---@param name string
---@return string
function M.make_link( item_id, quality, name )
  return catalogue.make_link( item_id, quality, name )
end

M.ids = ids
M.TRASH = TRASH

m.AutoRoundRobinDb = M
return M
