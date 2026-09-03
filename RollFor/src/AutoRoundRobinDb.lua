RollFor = RollFor or {}
local m = RollFor

if m.AutoRoundRobinDb then return end

local M = {}

-- The round-robin catalogue: which items /rf autorobin is allowed to hand out, grouped into
-- categories. Deliberately narrow. Round robin awards loot on its own, so what belongs here is
-- the bulk-consumable end of the drop table that nobody wants to burn a roll on.
--
-- Two levels, Category -> items, where auto-loot's is three (Dungeon -> Boss -> items). Which
-- raid a gem fell out of is not a fact this feature has any use for -- one gem is one gem, and
-- one queue serves all of them -- so the raid level is not modelled at all. That is also why the
-- seeding and query functions below are here rather than shared with AutoLootDb through
-- AutoLootDb: the two catalogues no longer have the same shape. Building an item link is the
-- only thing they still do the same way, and that is ItemUtils'.
--
-- The categories are the unit of rotation: each one owns an independent queue (see
-- AutoRoundRobin), so adding a category here adds a queue with no other change. Trash Ignored is
-- the one exception, and M.categories leaving it out is the whole of how it has no queue.
--
-- The ids and icons are the ones already verified in AutoLootDb (Black Temple Trash), not
-- re-derived, so nothing here needs a live GetItemInfo fetch.
--
-- Trash and Trash Ignored (below) are the two that aren't ordinary lists of ids to hand out --
-- see the comments on them.
local TRASH = "Trash"
local TRASH_IGNORED = "Trash Ignored"

-- An item quality's colour as plain RRGGBB, off the table the client builds during UIParent load.
---@param quality number
---@return string
local function quality_color( quality )
  return string.sub( m.api.ITEM_QUALITY_COLORS[ quality ].hex, -6 )
end

-- The colour each category is drawn in, as plain RRGGBB -- no escape codes, so it is as usable as
-- an { r, g, b } for the tree as it is as text for the dropdown. A colour rather than a quality,
-- so a category is free to take one no item quality has; the four below borrow quality colours
-- because that is what reads well next to the items in them, not because a category has to.
local ids = {
  [ "Gems" ] = {
    color = quality_color( 4 ), -- epic
    order = 3,
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
    color = quality_color( 2 ), -- uncommon
    order = 1,
    items = {
      [ 32897 ] = { quality = 2, icon = 136172, name = "Mark of the Illidari" },
    }
  },
  [ "Hearts" ] = {
    color = quality_color( 3 ), -- rare
    order = 2,
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
    color = quality_color( 0 ), -- poor
    order = 99,
    qualities = {
      [ 2 ] = { name = "Uncommon" },
      [ 3 ] = { name = "Rare" },
    }
  },
  -- The exceptions to the fallback: the items Trash must not claim. Nothing here is ever handed
  -- out, so this is the one category with no queue -- M.categories leaves it out, and since every
  -- queue there is comes from that list, no queue is ever made for it.
  --
  -- It shadows Trash and nothing else. Unticking Heart of Darkness under Hearts already says
  -- "don't round robin this", so an ignore list that also overrode the id categories would be a
  -- second switch for a question that already has one.
  --
  -- Its rows are item ids like a real category's, because "leave this particular formula alone"
  -- is not something a quality can say. Ticked means ignored: the checkboxes are there so an
  -- entry can be switched off without being taken out of the catalogue.
  [ TRASH_IGNORED ] = {
    color = quality_color( 0 ), -- poor, the same as Trash: this is Trash's own list, not a rival
    order = 100,
    items = {
      -- A row only ever matters while the master loot threshold admits its quality: above it the
      -- award pass drops the item before Trash is asked at all (see AutoRoundRobin.is_awardable),
      -- so ignoring it and not ignoring it come to the same thing.
      [ 22545 ] = { quality = 2, icon = 134327, name = "Formula: Enchant Boots - Surefooted" },
      [ 22559 ] = { quality = 3, icon = 134327, name = "Formula: Enchant Weapon - Mongoose" },
      [ 22560 ] = { quality = 3, icon = 134327, name = "Formula: Enchant Weapon - Sunfire" },
      [ 22561 ] = { quality = 3, icon = 134327, name = "Formula: Enchant Weapon - Soulfrost" },
      -- The same formula under two ids, both of them live. Which one drops is not a question this
      -- list can answer, so it names both rather than ignoring one and quietly missing the other.
      [ 28280 ] = { quality = 3, icon = 134327, name = "Formula: Enchant Boots - Boar's Speed" },
      [ 35297 ] = { quality = 3, icon = 134327, name = "Formula: Enchant Boots - Boar's Speed" },
      [ 23809 ] = { quality = 3, icon = 134941, name = "Schematic: Stabilized Eternium Scope" },
    }
  },
}

-- A category's name in its own colour, for the places that draw it as text.
--
-- Reads the static catalogue, not the persisted db: a colour is a fact of the catalogue and not
-- of anybody's selection, and ensure_seeded overwrites the stored one from here anyway. Falls
-- back to the plain name, so a category with no colour is still drawn rather than blanked.
---@param category string
---@return string
function M.colorize( category )
  local entry = ids[ category ]

  if not entry or not entry.color then return category end

  return m.colorize( entry.color, category )
end

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

-- The categories that own a queue, in catalogue order, which is the order the Queues dropdown
-- offers them.
--
-- Every queue there is comes from this list: db.queues is written lazily, keyed by whatever name
-- it is handed (see AutoRoundRobin), and every caller that names a queue takes the name from
-- here. So leaving Trash Ignored out is all it takes for that category never to have one.
--
-- The selection tree does not come through here -- AutoLootTree.build_flat walks db.ids itself --
-- which is why the ignore list still draws in the window that ticks it.
---@param db table? -- the persisted autorobin_db; falls back to the static catalogue
---@return string[]
function M.categories( db )
  local source = db and db.ids or ids
  local names = {}

  for name in pairs( source ) do
    if name ~= TRASH_IGNORED then table.insert( names, name ) end
  end

  table.sort( names, function( a, b )
    local order_a = (source[ a ].order or math.huge)
    local order_b = (source[ b ].order or math.huge)

    if order_a == order_b then return a < b end

    return order_a < order_b
  end )

  return names
end

-- Seeds the persisted db from the static catalogue above. Same contract AutoLootDb.ensure_seeded
-- documents for the nested shape: additions appear disabled, `enabled` on rows that already exist
-- is never touched, and entries no longer in the catalogue are left alone rather than pruned.
---@param db table the persisted autorobin_db
function M.ensure_seeded( db )
  db.ids = db.ids or {}

  for category_name, category_entry in pairs( ids ) do
    local category = db.ids[ category_name ] or { enabled = false }
    category.order = category_entry.order
    category.color = category_entry.color
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
  for name, category in pairs( ids ) do
    -- The ignore list names ids without claiming them: an item on it that isn't ticked has to
    -- fall through to Trash like any other, which counting it as catalogued would prevent.
    if name ~= TRASH_IGNORED and category.items and category.items[ item_id ] then return true end
  end

  return false
end

-- Whether Trash has been told to leave this item alone. Ticked is ignored, and the category's own
-- checkbox switches the whole list off.
---@param db table the persisted autorobin_db
---@param item_id number
---@return boolean
local function is_trash_ignored( db, item_id )
  local ignored = db.ids[ TRASH_IGNORED ]
  if not ignored or not ignored.enabled then return false end

  local item = ignored.items and ignored.items[ item_id ]

  return item and item.enabled and true or false
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

  -- Asked here rather than inside find_trash_category, which is Trash's own rule and knows only
  -- the quality: the ignore list is about the item, and it is only ever consulted on the way into
  -- the fallback -- the categories above have already had their say.
  if is_trash_ignored( db, item_id ) then return nil end

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

  for name, category in pairs( db.ids ) do
    -- Ticking something on the ignore list is not having something selected: nothing under it is
    -- ever handed out.
    if name ~= TRASH_IGNORED and category.enabled then
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

M.ids = ids
M.TRASH = TRASH
M.TRASH_IGNORED = TRASH_IGNORED

m.AutoRoundRobinDb = M
return M
