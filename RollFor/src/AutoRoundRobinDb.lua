RollFor = RollFor or {}
local m = RollFor

if m.AutoRoundRobinDb then return end

local M = {}
local catalogue = m.ItemCatalogue

-- The round-robin catalogue: which items /rf autorobin is allowed to hand out. Same
-- Dungeon -> Boss -> items shape as AutoLootDb's, so AutoLootTree, AutoLootFrame and the
-- seeding/query helpers in ItemCatalogue all work on it unchanged.
--
-- Deliberately narrow. Round robin awards loot on its own, so what belongs here is the
-- bulk-consumable end of the drop table that nobody wants to burn a roll on -- currently
-- exactly the six Tier 5 epic gems, which drop off Mount Hyjal and Black Temple trash.
--
-- The ids and icons are the ones already verified in AutoLootDb (Black Temple Trash), not
-- re-derived, so nothing here needs a live GetItemInfo fetch. The same six ids appearing
-- under both raids is fine and already normal for this data: is_enabled matches on item id
-- and counts an item as soon as any one occurrence of it is enabled.
local function gems()
  return {
    [ 32227 ] = { quality = 4, icon = 133238, name = "Crimson Spinel" },
    [ 32228 ] = { quality = 4, icon = 133244, name = "Empyrean Sapphire" },
    [ 32229 ] = { quality = 4, icon = 133248, name = "Lionseye" },
    [ 32230 ] = { quality = 4, icon = 133265, name = "Shadowsong Amethyst" },
    [ 32231 ] = { quality = 4, icon = 133260, name = "Pyrestone" },
    [ 32249 ] = { quality = 4, icon = 133263, name = "Seaspray Emerald" },
  }
end

local ids = {
  [ "Mount Hyjal" ] = {
    order = 1,
    bosses = {
      [ "Gems" ] = { order = 1, items = gems() }
    }
  },
  [ "Black Temple" ] = {
    order = 2,
    bosses = {
      [ "Gems" ] = { order = 1, items = gems() }
    }
  },
}

-- "Gems" is not a boss, the same way AutoLootDb's "Trash" and "Patterns" aren't: the tree
-- greys those rows out rather than colouring them like an encounter. Each catalogue carries
-- its own set instead of extending AutoLootDb.non_bosses, which find_boss and BossKilled read
-- and which should keep answering questions about the auto-loot catalogue only.
local NON_BOSSES = {
  [ "Gems" ] = true
}

---@param db table the persisted autorobin_db
function M.ensure_seeded( db )
  catalogue.ensure_seeded( db, ids )
end

---@param db table the persisted autorobin_db
---@param item_id number
---@return boolean
function M.is_enabled( db, item_id )
  return catalogue.is_enabled( db, item_id )
end

---@param db table the persisted autorobin_db
---@return boolean
function M.has_enabled_items( db )
  return catalogue.has_enabled_items( db )
end

---@param item_id number
---@param quality number
---@param name string
---@return string
function M.make_link( item_id, quality, name )
  return catalogue.make_link( item_id, quality, name )
end

M.ids = ids
M.non_bosses = NON_BOSSES

m.AutoRoundRobinDb = M
return M
