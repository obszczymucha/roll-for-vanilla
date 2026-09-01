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
}

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

    db.ids[ category_name ] = category
  end
end

-- Which category's queue should serve this item -- the question the award pass asks, and the
-- reason this lookup exists at all. Reads the persisted db, not the static catalogue: an item
-- under a disabled category is not on the list, so it has no queue.
---@param db table the persisted autorobin_db
---@param item_id number
---@return string? -- nil when the item isn't enabled anywhere
function M.find_category( db, item_id )
  if not db or not db.ids then return nil end

  -- Catalogue order, so an item listed under two categories always resolves to the same one
  -- rather than to whatever pairs() happened to yield first.
  for _, category_name in ipairs( M.categories( db ) ) do
    local category = db.ids[ category_name ]

    if category.enabled then
      local item = category.items and category.items[ item_id ]
      if item and item.enabled then return category_name end
    end
  end

  return nil
end

---@param db table the persisted autorobin_db
---@param item_id number
---@return boolean
function M.is_enabled( db, item_id )
  return M.find_category( db, item_id ) and true or false
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

m.AutoRoundRobinDb = M
return M
