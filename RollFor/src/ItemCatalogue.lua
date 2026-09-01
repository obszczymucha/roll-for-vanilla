RollFor = RollFor or {}
local m = RollFor

if m.ItemCatalogue then return end

local M = {}

-- The half of a Dungeon -> Boss -> items catalogue that doesn't depend on which catalogue it
-- is: seeding the persisted selection db from a static id table, and the two queries the
-- auto-loot and round-robin passes run against the result. AutoLootDb and AutoRoundRobinDb
-- both own a catalogue of exactly that shape and both need all of this, so it lives here
-- rather than in whichever of them happened to be written first. What stays behind in
-- AutoLootDb is what only AutoLootDb has: find_boss and the item-info fetch tooling.

-- The |cffXXXXXX prefix per item quality, read off real client-generated item links (see the
-- fetch tooling in AutoLootDb) rather than from ITEM_QUALITY_COLORS, which is missing on
-- vanilla Blizzard client constants.
local QUALITY_COLOR_HEX = {
  [ 0 ] = "|cff9d9d9d",
  [ 1 ] = "|cffffffff",
  [ 2 ] = "|cff1eff00",
  [ 3 ] = "|cff0070dd",
  [ 4 ] = "|cffa335ee",
  [ 5 ] = "|cffff8000",
}

---@param quality number
---@return string
function M.quality_color_hex( quality )
  return QUALITY_COLOR_HEX[ quality or 0 ] or QUALITY_COLOR_HEX[ 0 ]
end

-- Every entry uses the same item link shape, so it isn't stored per item -- callers (e.g.
-- AutoLootFrame) build it on demand from the id/quality/name they already have.
---@param item_id number
---@param quality number
---@param name string
---@return string
function M.make_link( item_id, quality, name )
  return string.format( "%s|Hitem:%d::::::::70::::::::::|h[%s]|h|r", M.quality_color_hex( quality ), item_id, name )
end

-- Seeds db (the persisted SavedVariables table backing a selection GUI) with a copy of the
-- static `ids` catalogue, with `enabled = false` added to every dungeon/boss/item -- the
-- user's actual selection state, which AutoLootTree reads and writes from here on so it
-- survives a /reload.
--
-- Reconciles instead of bailing out when db.ids already exists: the catalogue grows between
-- releases (Mount Hyjal's "Patterns" node did), and a db seeded once and never revisited would
-- hide every later addition from anyone who has already opened the GUI. Anything missing is
-- added disabled -- new rows are an offer, not a change to what the user picked -- while
-- `enabled` on rows that already exist is never touched. Everything else (order, name, icon,
-- quality) is a fact about the game rather than a choice, so the catalogue overwrites it.
--
-- Entries no longer in the catalogue are left alone rather than pruned: they cost a row in the
-- GUI at worst, and dropping them would throw away a selection over what may well be a typo in
-- an item id.
---@param db table
---@param ids table -- the static catalogue to seed from
function M.ensure_seeded( db, ids )
  db.ids = db.ids or {}

  for dungeon_name, dungeon_entry in pairs( ids ) do
    local dungeon = db.ids[ dungeon_name ] or { enabled = false }
    dungeon.order = dungeon_entry.order
    dungeon.bosses = dungeon.bosses or {}

    for boss_name, boss_entry in pairs( dungeon_entry.bosses or {} ) do
      local boss = dungeon.bosses[ boss_name ] or { enabled = false }
      boss.order = boss_entry.order
      boss.items = boss.items or {}

      for item_id, item_entry in pairs( boss_entry.items or {} ) do
        local item = boss.items[ item_id ] or { enabled = false }
        item.quality = item_entry.quality
        item.icon = item_entry.icon
        item.name = item_entry.name

        boss.items[ item_id ] = item
      end

      dungeon.bosses[ boss_name ] = boss
    end

    db.ids[ dungeon_name ] = dungeon
  end
end

-- The two queries below are what an auto-loot / round-robin pass runs against the player's
-- selection. Both read the persisted db.ids (see ensure_seeded), never the static catalogue --
-- that one carries no selection state at all. An item only counts if it and both nodes above it
-- are enabled, the same rule AutoLootTree.is_leaf_enabled applies to the GUI's own rows.
--
-- Skipping disabled dungeons/bosses wholesale keeps these proportional to what's actually
-- selected rather than to the size of the catalogue, so no lookup index is maintained here.

-- Items that appear under more than one boss (shared trash drops, or the same gem listed under
-- two raids) count as soon as any one of those occurrences is enabled.
---@param db table the persisted selection db
---@param item_id number
---@return boolean
function M.is_enabled( db, item_id )
  if not db or not db.ids then return false end

  for _, dungeon_entry in pairs( db.ids ) do
    if dungeon_entry.enabled then
      for _, boss_entry in pairs( dungeon_entry.bosses or {} ) do
        if boss_entry.enabled then
          local item = boss_entry.items and boss_entry.items[ item_id ]
          if item and item.enabled then return true end
        end
      end
    end
  end

  return false
end

-- Whether the player has anything at all selected -- i.e. whether M.is_enabled could ever return
-- true for this db. Stops at the first hit instead of counting.
---@param db table the persisted selection db
---@return boolean
function M.has_enabled_items( db )
  if not db or not db.ids then return false end

  for _, dungeon_entry in pairs( db.ids ) do
    if dungeon_entry.enabled then
      for _, boss_entry in pairs( dungeon_entry.bosses or {} ) do
        if boss_entry.enabled then
          for _, item in pairs( boss_entry.items or {} ) do
            if item.enabled then return true end
          end
        end
      end
    end
  end

  return false
end

m.ItemCatalogue = M
return M
