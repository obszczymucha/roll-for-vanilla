RollFor = RollFor or {}
local m = RollFor

if m.BossKilled then return end

local M = m.Module.new( "BossKilled" )

local getn = m.getn

-- Which bosses this character has seen die, inferred from their loot. Nothing
-- here watches combat: an item that only one boss drops is proof that boss is
-- dead, and the loot window is the one moment the addon is guaranteed to be
-- looking. AutoLootDb owns the item-to-boss catalogue.

-- Items that don't identify what dropped them, so nothing can be concluded from
-- seeing one. Karazhan's Opera event picks one of The Big Bad Wolf / The Wizard
-- of Oz / Romulo and Julianne per lockout and all three share these six, so the
-- catalogue lists each of them under all three bosses. Each of those bosses also
-- drops four items of its own, which is what actually names the kill.
--
-- The cost of ignoring them: an Opera kill where none of the four unique items
-- drops goes unrecorded. That's the deliberate trade -- silence beats crediting
-- a boss that didn't die.
local ignored_items = {
  [ 28589 ] = true, -- Beastmaw Pauldrons
  [ 28590 ] = true, -- Ribbon of Sacrifice
  [ 28591 ] = true, -- Earthsoul Leggings
  [ 28592 ] = true, -- Libram of Souls Redeemed
  [ 28593 ] = true, -- Eternium Greathelm
  [ 28594 ] = true  -- Trial-Fire Trousers
}

M.ignored_items = ignored_items

---@class BossKilled
---@field on_item_dropped fun( item_id: number )
---@field is_killed fun( boss_name: string ): boolean
---@field get_killed_bosses fun(): string[]
---@field reset fun()
---@field subscribe fun( listener: fun( boss_name: string ) )

---@param db table -- killed bosses by name, persisted
---@return BossKilled
function M.new( db )
  -- db is a proxy over the saved table (see Db.lua): it forwards reads and
  -- writes but holds no keys of its own, so pairs() over it comes back empty.
  -- The set has to live one level down to be enumerable, and so reset can drop
  -- the whole thing in one write.
  db.bosses = db.bosses or {}

  local m_listeners = {}

  ---@param boss_name string
  local function notify( boss_name )
    for i = 1, getn( m_listeners ) do
      m_listeners[ i ]( boss_name )
    end
  end

  -- Listeners hear about kills only. reset() is a correction to the record, not
  -- a boss dying, so it stays quiet.
  ---@param listener fun( boss_name: string )
  local function subscribe( listener )
    table.insert( m_listeners, listener )
  end

  ---@param boss_name string
  ---@return boolean
  local function is_killed( boss_name )
    return db.bosses[ boss_name ] and true or false
  end

  -- A boss drops several items at once and the loot window can be reopened, so
  -- the same kill arrives many times over. Only the first one is an event.
  ---@param item_id number
  local function on_item_dropped( item_id )
    -- Shared between bosses, so it names none of them (see above). Checked
    -- before the lookup, which would happily hand back one of the candidates.
    if ignored_items[ item_id ] then return end

    -- Trash, quest items, anything outside the catalogue: nothing that names a
    -- boss, so nothing to record.
    local boss_name = m.AutoLootDb.find_boss( item_id )
    if not boss_name then return end

    if db.bosses[ boss_name ] then return end

    db.bosses[ boss_name ] = true
    M.debug.add( string.format( "%s killed (item %s)", boss_name, tostring( item_id ) ) )
    notify( boss_name )
  end

  -- Sorted, because pairs() over the set comes back in whatever order the table
  -- feels like and a list that reorders itself between calls is no use to a
  -- caller displaying it.
  ---@return string[]
  local function get_killed_bosses()
    local result = {}

    for boss_name in pairs( db.bosses ) do
      table.insert( result, boss_name )
    end

    table.sort( result )

    return result
  end

  local function reset()
    db.bosses = {}
    M.debug.add( "reset" )
  end

  ---@type BossKilled
  return {
    on_item_dropped = on_item_dropped,
    is_killed = is_killed,
    get_killed_bosses = get_killed_bosses,
    reset = reset,
    subscribe = subscribe
  }
end

m.BossKilled = M
return M
