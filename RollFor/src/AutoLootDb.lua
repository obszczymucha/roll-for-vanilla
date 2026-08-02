RollFor = RollFor or {}
local m = RollFor

if m.AutoLootDb then return end

local M = {}

-- Item ids sourced from AtlasLootClassic_DungeonsAndRaids (data-tbc.lua). AtlasLoot itself
-- doesn't hardcode name/link/icon either -- it resolves those live via GetItemInfo, which the
-- WoW client caches locally after the first server fetch. We do the same here instead of baking
-- in name/link/icon strings that could go stale or be wrong.
local ids = {
  [ "Serpentshrine Cavern" ] = {
    enabled = true,
    order = 1,
    bosses = {
      [ "Hydross the Unstable" ] = {
        enabled = true,
        order = 1,
        items = {
          [ 30056 ] = { enabled = true, quality = 4, icon = 132684, name = "Robe of Hateful Echoes" },
          [ 30664 ] = { enabled = true, quality = 4, icon = 134218, name = "Living Root of the Wildheart" },
          [ 30053 ] = { enabled = true, quality = 4, icon = 135051, name = "Pauldrons of the Wardancer" },
          [ 32516 ] = { enabled = true, quality = 4, icon = 132612, name = "Wraps of Purification" },
          [ 30050 ] = { enabled = true, quality = 4, icon = 132539, name = "Boots of the Shifting Nightmare" },
          [ 33055 ] = { enabled = true, quality = 4, icon = 133413, name = "Band of Vile Aggression" },
          [ 30049 ] = { enabled = true, quality = 4, icon = 134079, name = "Fathomstone" },
          [ 30047 ] = { enabled = true, quality = 4, icon = 132601, name = "Blackfathom Warbands" },
          [ 30051 ] = { enabled = true, quality = 4, icon = 134903, name = "Idol of the Crescent Goddess" },
          [ 30055 ] = { enabled = true, quality = 4, icon = 135054, name = "Shoulderpads of the Stranger" },
          [ 30629 ] = { enabled = true, quality = 4, icon = 135443, name = "Scarab of Displacement" },
          [ 30048 ] = { enabled = true, quality = 4, icon = 133124, name = "Brighthelm of Justice" },
          [ 30052 ] = { enabled = true, quality = 4, icon = 133393, name = "Ring of Lethality" },
          [ 30054 ] = { enabled = true, quality = 4, icon = 132744, name = "Ranger-General's Chestguard" }
        }
      },
      [ "The Lurker Below" ] = {
        enabled = true,
        order = 2,
        items = {
          [ 30064 ] = { enabled = true, quality = 4, icon = 132492, name = "Cord of Screaming Terrors" },
          [ 30067 ] = { enabled = true, quality = 4, icon = 132539, name = "Velvet Boots of the Guardian" },
          [ 30062 ] = { enabled = true, quality = 4, icon = 132601, name = "Grove-Bands of Remulos" },
          [ 30060 ] = { enabled = true, quality = 4, icon = 132587, name = "Boots of Effortless Striking" },
          [ 30066 ] = { enabled = true, quality = 4, icon = 132548, name = "Tempest-Strider Boots" },
          [ 30065 ] = { enabled = true, quality = 4, icon = 132740, name = "Glowing Breastplate of Truth" },
          [ 30057 ] = { enabled = true, quality = 4, icon = 132618, name = "Bracers of Eradication" },
          [ 30059 ] = { enabled = true, quality = 4, icon = 133341, name = "Choker of Animalistic Fury" },
          [ 30061 ] = { enabled = true, quality = 4, icon = 133383, name = "Ancestral Ring of Conquest" },
          [ 33054 ] = { enabled = true, quality = 4, icon = 133381, name = "The Seal of Danzalar" },
          [ 30665 ] = { enabled = true, quality = 4, icon = 133349, name = "Earring of Soulful Meditation" },
          [ 30063 ] = { enabled = true, quality = 4, icon = 134917, name = "Libram of Absolute Truth" },
          [ 30058 ] = { enabled = true, quality = 4, icon = 135677, name = "Mallet of the Tides" },
        }
      },
      [ "Leotheras the Blind" ] = {
        enabled = true,
        order = 3,
        items = {
          [ 30092 ] = { enabled = true, quality = 4, icon = 132573, name = "Orca-Hide Boots" },
          [ 30097 ] = { enabled = true, quality = 4, icon = 135050, name = "Coral-Barbed Shoulderpads" },
          [ 30091 ] = { enabled = true, quality = 4, icon = 132614, name = "True-Aim Stalker Bands" },
          [ 30096 ] = { enabled = true, quality = 4, icon = 132516, name = "Girdle of the Invulnerable" },
          [ 30627 ] = { enabled = true, quality = 4, icon = 136111, name = "Tsunami Talisman" },
          [ 30095 ] = { enabled = true, quality = 4, icon = 135383, name = "Fang of the Leviathan" },
          [ 30239 ] = { enabled = true, quality = 4, icon = 132961, name = "Gloves of the Vanquished Champion" },
          [ 30240 ] = { enabled = true, quality = 4, icon = 132961, name = "Gloves of the Vanquished Defender" },
          [ 30241 ] = { enabled = true, quality = 4, icon = 132961, name = "Gloves of the Vanquished Hero" },
        }
      },
      [ "Fathom-Lord Karathress" ] = {
        enabled = true,
        order = 4,
        items = {
          [ 30100 ] = { enabled = true, quality = 4, icon = 132579, name = "Soul-Strider Boots" },
          [ 30101 ] = { enabled = true, quality = 4, icon = 132743, name = "Bloodsea Brigand's Vest" },
          [ 30099 ] = { enabled = true, quality = 4, icon = 134326, name = "Frayed Tether of the Drowned" },
          [ 30663 ] = { enabled = true, quality = 4, icon = 134398, name = "Fathom-Brooch of the Tidewalker" },
          [ 30626 ] = { enabled = true, quality = 4, icon = 133003, name = "Sextant of Unstable Currents" },
          [ 30090 ] = { enabled = true, quality = 4, icon = 133532, name = "World Breaker" },
          [ 30245 ] = { enabled = true, quality = 4, icon = 134693, name = "Leggings of the Vanquished Champion" },
          [ 30246 ] = { enabled = true, quality = 4, icon = 134693, name = "Leggings of the Vanquished Defender" },
          [ 30247 ] = { enabled = true, quality = 4, icon = 134693, name = "Leggings of the Vanquished Hero" },
        }
      },
      [ "Morogrim Tidewalker" ] = {
        enabled = true,
        order = 5,
        items = {
          [ 30098 ] = { enabled = true, quality = 4, icon = 133772, name = "Razor-Scale Battlecloak" },
          [ 30079 ] = { enabled = true, quality = 4, icon = 135056, name = "Illidari Shoulderpads" },
          [ 30075 ] = { enabled = true, quality = 4, icon = 132725, name = "Gnarled Chestpiece of the Ancients" },
          [ 30085 ] = { enabled = true, quality = 4, icon = 135058, name = "Mantle of the Tireless Tracker" },
          [ 30068 ] = { enabled = true, quality = 4, icon = 132508, name = "Girdle of the Tidal Call" },
          [ 30084 ] = { enabled = true, quality = 4, icon = 135045, name = "Pauldrons of the Argent Sentinel" },
          [ 30081 ] = { enabled = true, quality = 4, icon = 132585, name = "Warboots of Obliteration" },
          [ 30008 ] = { enabled = true, quality = 4, icon = 133299, name = "Pendant of the Lost Ages" },
          [ 30083 ] = { enabled = true, quality = 4, icon = 133373, name = "Ring of Sundered Souls" },
          [ 33058 ] = { enabled = true, quality = 4, icon = 133385, name = "Band of the Vigilant" },
          [ 30720 ] = { enabled = true, quality = 4, icon = 136070, name = "Serpent-Coil Braid" },
          [ 30082 ] = { enabled = true, quality = 4, icon = 135360, name = "Talon of Azshara" },
          [ 30080 ] = { enabled = true, quality = 4, icon = 135476, name = "Luminescent Rod of the Naaru" },
        }
      },
      [ "Lady Vashj" ] = {
        enabled = true,
        order = 6,
        items = {
          [ 30107 ] = { enabled = true, quality = 4, icon = 132658, name = "Vestments of the Sea-Witch" },
          [ 30111 ] = { enabled = true, quality = 4, icon = 135038, name = "Runetotem's Mantle" },
          [ 30106 ] = { enabled = true, quality = 4, icon = 132515, name = "Belt of One-Hundred Deaths" },
          [ 30104 ] = { enabled = true, quality = 4, icon = 132555, name = "Cobra-Lash Boots" },
          [ 30102 ] = { enabled = true, quality = 4, icon = 132746, name = "Krakken-Heart Breastplate" },
          [ 30112 ] = { enabled = true, quality = 4, icon = 132954, name = "Glorious Gauntlets of Crestfall" },
          [ 30109 ] = { enabled = true, quality = 4, icon = 133386, name = "Ring of Endless Coils" },
          [ 30110 ] = { enabled = true, quality = 4, icon = 133377, name = "Coral Band of the Revived" },
          [ 30621 ] = { enabled = true, quality = 4, icon = 134100, name = "Prism of Inner Calm" },
          [ 30103 ] = { enabled = true, quality = 4, icon = 135674, name = "Fang of Vashj" },
          [ 30108 ] = { enabled = true, quality = 4, icon = 135678, name = "Lightfathom Scepter" },
          [ 30105 ] = { enabled = true, quality = 4, icon = 135496, name = "Serpent Spine Longbow" },
          [ 30242 ] = { enabled = true, quality = 4, icon = 133126, name = "Helm of the Vanquished Champion" },
          [ 30243 ] = { enabled = true, quality = 4, icon = 133126, name = "Helm of the Vanquished Defender" },
          [ 30244 ] = { enabled = true, quality = 4, icon = 133126, name = "Helm of the Vanquished Hero" },
        }
      },
      [ "Trash" ] = {
        enabled = true,
        order = 7,
        items = {
          [ 30027 ] = { enabled = true, quality = 4, icon = 132551, name = "Boots of Courage Unending" },
          [ 30022 ] = { enabled = true, quality = 4, icon = 133339, name = "Pendant of the Perilous" },
          [ 30620 ] = { enabled = true, quality = 4, icon = 134441, name = "Spyglass of the Hidden Fleet" },
          [ 30023 ] = { enabled = true, quality = 4, icon = 136022, name = "Totem of the Maelstrom" },
          [ 30021 ] = { enabled = true, quality = 4, icon = 135186, name = "Wildfury Greatstaff" },
          [ 30025 ] = { enabled = true, quality = 4, icon = 135430, name = "Serpentshrine Shuriken" },
          [ 30324 ] = { enabled = true, quality = 4, icon = 134940, name = "Plans: Red Havoc Boots" },
          [ 30322 ] = { enabled = true, quality = 4, icon = 134940, name = "Plans: Red Belt of Battle" },
          [ 30323 ] = { enabled = true, quality = 4, icon = 134940, name = "Plans: Boots of the Protector" },
          [ 30321 ] = { enabled = true, quality = 4, icon = 134940, name = "Plans: Belt of the Guardian" },
          [ 30280 ] = { enabled = true, quality = 4, icon = 134940, name = "Pattern: Belt of Blasting" },
          [ 30282 ] = { enabled = true, quality = 4, icon = 134940, name = "Pattern: Boots of Blasting" },
          [ 30283 ] = { enabled = true, quality = 4, icon = 134940, name = "Pattern: Boots of the Long Road" },
          [ 30281 ] = { enabled = true, quality = 4, icon = 134940, name = "Pattern: Belt of the Long Road" },
          [ 30308 ] = { enabled = true, quality = 4, icon = 134940, name = "Pattern: Hurricane Boots" },
          [ 30304 ] = { enabled = true, quality = 4, icon = 134940, name = "Pattern: Monsoon Belt" },
          [ 30305 ] = { enabled = true, quality = 4, icon = 134940, name = "Pattern: Boots of Natural Grace" },
          [ 30307 ] = { enabled = true, quality = 4, icon = 134940, name = "Pattern: Boots of the Crimson Hawk" },
          [ 30306 ] = { enabled = true, quality = 4, icon = 134940, name = "Pattern: Boots of Utter Darkness" },
          [ 30301 ] = { enabled = true, quality = 4, icon = 134940, name = "Pattern: Belt of Natural Power" },
          [ 30303 ] = { enabled = true, quality = 4, icon = 134940, name = "Pattern: Belt of the Black Eagle" },
          [ 30302 ] = { enabled = true, quality = 4, icon = 134940, name = "Pattern: Belt of Deep Shadow" },
          [ 32897 ] = { enabled = true, quality = 2, icon = 136172, name = "Mark of the Illidari" },
        }
      }
    }
  }
}

---@class AutoLootDbItem
---@field enabled boolean
---@field name string
---@field icon number
---@field quality number

---@class ResolvedAutoLootDbItem: AutoLootDbItem
---@field link string

-- Quality -> |cffXXXXXX prefix. 1 (Common), 2 (Uncommon), 3 (Rare) and 4 (Epic) were verified live
-- via /rf autolootdb against real items (Refreshing Spring Water, Glyph of Frost Warding, Manual
-- Crowd Pummeler, Hydross' drops). 0 (Poor) and 5 (Legendary) are the standard, unchanged-since-
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
local function quality_color_hex( quality )
  return QUALITY_COLOR_HEX[ quality or 0 ] or QUALITY_COLOR_HEX[ 0 ]
end

-- Every entry uses the same item link shape, so it isn't stored per item -- callers (e.g.
-- SandboxFrame) build it on demand from the id/quality/name they already have.
---@param item_id number
---@param quality number
---@param name string
---@return string
function M.make_link( item_id, quality, name )
  return string.format( "%s|Hitem:%d::::::::70::::::::::|h[%s]|h|r", quality_color_hex( quality ), item_id, name )
end

-- The verified fact itself (see QUALITY_COLOR_HEX above), for callers that need the raw
-- |cffXXXXXX prefix rather than a fully-built item link.
---@param quality number
---@return string
function M.quality_color_hex( quality )
  return quality_color_hex( quality )
end

---@param dungeon string
---@param boss string
---@return table<number, AutoLootDbItem> enabled items keyed by item id
function M.get_items( dungeon, boss )
  local dungeon_entry = ids[ dungeon ]
  if not dungeon_entry or not dungeon_entry.enabled then return {} end

  local boss_entry = dungeon_entry.bosses and dungeon_entry.bosses[ boss ]
  if not boss_entry or not boss_entry.enabled then return {} end

  local items = {}

  for item_id, item in pairs( boss_entry.items or {} ) do
    if item.enabled then items[ item_id ] = item end
  end

  return items
end

-- Only used by the fetch tool below (dump_to_db / on_item_info_received) -- its output is meant
-- to be inspected/pasted back, so unlike the permanent `ids` entries it also includes a real,
-- client-generated `link` (the whole point right now: reading the true |cffXXXXXX per quality off
-- of it, to replace the ITEM_QUALITY_COLORS lookup in make_link with verified values).
---@param item_id number
---@return ResolvedAutoLootDbItem?
local function resolve_item( item_id )
  local name, _, quality, _, _, _, _, _, _, texture = m.api.GetItemInfo( item_id )
  if not name then return end

  local link = m.fetch_item_link( item_id, quality )
  if not link then return end

  return { enabled = true, name = name, icon = texture, quality = quality, link = link }
end

-- Items that resolved as nil during the last dump: item_id -> { dungeon, boss }. Retried as
-- GET_ITEM_INFO_RECEIVED fires (see on_item_info_received below) instead of requiring the
-- player to rerun the command by hand.
local pending = {}
local pending_db
local on_all_resolved

-- Separate from `pending` above: items queued by on_print_command, which just prints straight to
-- chat instead of writing anywhere -- no SavedVariables round trip needed to read the result.
local print_pending = {}

local function count_pending()
  local n = 0
  for _ in pairs( pending ) do n = n + 1 end
  return n
end

-- Lazily creates (only when there's actually something to write) the dungeon/boss scaffolding in
-- db.items and returns its items table.
local function ensure_boss_items( db, dungeon, boss )
  db.items[ dungeon ] = db.items[ dungeon ] or { enabled = true, bosses = {} }
  db.items[ dungeon ].bosses[ boss ] = db.items[ dungeon ].bosses[ boss ] or { enabled = true, items = {} }

  return db.items[ dungeon ].bosses[ boss ].items
end

-- Only fetches stub items -- ones in `ids` missing a `quality`, meaning they haven't been fully
-- resolved yet (name alone can be hardcoded from a trusted static source like AtlasLoot without
-- needing a live fetch; quality/icon can't). Already-fully-resolved items (e.g. the 14
-- Serpentshrine Cavern ones) are skipped entirely and never written to db.items, so the dump
-- output only ever contains what actually still needs fetching. Writes into db.items in the same
-- shape as `ids` so it can be pasted straight back in. GetItemInfo only returns data once the
-- client has it cached (usually near-instant after the first query); anything not cached yet is
-- tracked in `pending` and retried automatically via on_item_info_received.
---@param db table
---@return number resolved_count, number pending_count
local function dump_to_db( db )
  db.items = db.items or {}
  pending_db = db

  local resolved_count = 0

  for dungeon, dungeon_entry in pairs( ids ) do
    for boss, boss_entry in pairs( dungeon_entry.bosses or {} ) do
      for item_id, item_entry in pairs( boss_entry.items or {} ) do
        if not item_entry.quality then
          local item = resolve_item( item_id )

          if item then
            ensure_boss_items( db, dungeon, boss )[ item_id ] = item
            resolved_count = resolved_count + 1
          else
            pending[ item_id ] = { dungeon = dungeon, boss = boss }
          end
        end
      end
    end
  end

  return resolved_count, count_pending()
end

---@param db table
---@param on_done fun( resolved_count: number )? called once every pending item has resolved
--- (synchronously, with the initial resolved_count, if nothing was pending to begin with). Owns
--- no printing itself -- the caller decides what, if anything, to tell the player.
function M.on_command( db, on_done )
  local resolved_count, pending_count = dump_to_db( db )

  if pending_count > 0 then
    m.print( string.format(
      "AutoLootDb: resolved %d item(s), %d still uncached -- will keep retrying automatically as their info arrives.",
      resolved_count, pending_count
    ) )
    on_all_resolved = on_done
  else
    m.print( string.format( "AutoLootDb: resolved %d item(s), stored in the DB.", resolved_count ) )
    on_all_resolved = nil
    if on_done then on_done( resolved_count ) end
  end
end

-- Same "only stub items" scan as dump_to_db, but prints `id -> quality, icon` straight to chat
-- instead of writing to SavedVariables -- no /reload + file-digging needed to read the result.
-- Stragglers not cached yet get printed as they arrive, same as the db path.
function M.on_print_command()
  local resolved_count = 0

  for _, dungeon_entry in pairs( ids ) do
    for _, boss_entry in pairs( dungeon_entry.bosses or {} ) do
      for item_id, item_entry in pairs( boss_entry.items or {} ) do
        if not item_entry.quality then
          local item = resolve_item( item_id )

          if item then
            m.print( string.format( "%d -> %d, %d", item_id, item.quality, item.icon ) )
            resolved_count = resolved_count + 1
          else
            print_pending[ item_id ] = true
          end
        end
      end
    end
  end

  local pending_count = 0
  for _ in pairs( print_pending ) do pending_count = pending_count + 1 end

  m.print( string.format(
    "AutoLootDb: printed %d item(s), %d still uncached -- will print as they resolve.",
    resolved_count, pending_count
  ) )
end

-- Hooked up to the GET_ITEM_INFO_RECEIVED event (see main.lua's on_item_info_received). Not
-- available on vanilla clients, but this raid is TBC-only so that's a non-issue here.
---@param item_id number
function M.on_item_info_received( item_id )
  if print_pending[ item_id ] then
    local item = resolve_item( item_id )

    if item then
      print_pending[ item_id ] = nil
      m.print( string.format( "%d -> %d, %d", item_id, item.quality, item.icon ) )
    end
  end

  local target = pending[ item_id ]
  if not target or not pending_db then return end

  local item = resolve_item( item_id )
  if not item then return end

  ensure_boss_items( pending_db, target.dungeon, target.boss )[ item_id ] = item
  pending[ item_id ] = nil

  local remaining = count_pending()

  if remaining > 0 then
    m.print( string.format( "AutoLootDb: resolved another item, %d still pending.", remaining ) )
    return
  end

  local callback = on_all_resolved
  on_all_resolved = nil
  if callback then callback() end
end

M.ids = ids

m.AutoLootDb = M
return M
