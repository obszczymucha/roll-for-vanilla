RollFor = RollFor or {}
local m = RollFor

if m.Ordering then return end

local M = {}
local getn = m.getn

-- Anchored placement: given a list of named entries, each optionally asking to sit after
-- or before another by name, work out the order.
--
-- Lifted out of Chain, which needed it to stack decorators, because the loot pipeline
-- needs the same thing for an ordered list of callbacks. Those two compose differently --
-- one wraps, one appends -- but they order identically, and an extension anchoring a loot
-- handler should get the same vocabulary, the same failures and the same error messages
-- it already knows from the soft-res chain.
--
-- What is not here: composition, taps, duplicate-name checks, and whether an unplaceable
-- entry is worth complaining about out loud. Those belong to the caller. This answers
-- where things go and, for the ones that cannot go anywhere, why.

---@class OrderingEntry
---@field name string
---@field after string? -- an entry name, or the base name for "first"
---@field before string?

---@class UnplaceableEntry
---@field entry OrderingEntry
---@field reason string -- a full sentence, ready to be printed by whoever asked

---@param entries OrderingEntry[]
---@param name string
---@return number?
local function index_among( entries, name )
  for i, entry in ipairs( entries ) do
    if entry.name == name then return i end
  end
end

-- The base sits at index 0, so `after = base` lands at position 1 and everything else
-- falls out of the same arithmetic.
--
-- Three answers, not two: a position, or `nil` plus a complaint when the entry can never
-- be placed, or `nil` and no complaint when its anchor simply has not been placed *yet*.
-- Only place() knows which of the last two it is, because only place() knows whether
-- there is another pass coming.
---@param placed OrderingEntry[]
---@param entry OrderingEntry
---@param base string
---@param noun string
---@return number?, string?
local function position_for( placed, entry, base, noun )
  local after_index, before_index

  if entry.after then
    if entry.after == base then
      after_index = 0
    else
      after_index = index_among( placed, entry.after )
      if not after_index then return nil end
    end
  end

  if entry.before then
    before_index = index_among( placed, entry.before )
    if not before_index then return nil end
  end

  -- With both anchors given, `after` decides the position and `before` is the constraint
  -- it has to satisfy. Two entries asking for the same slot break the tie by registration
  -- order.
  if after_index then
    local position = after_index + 1

    if before_index and position > before_index then
      return nil, string.format( "%s '%s' cannot be both after '%s' and before '%s'.",
        noun, entry.name, entry.after, entry.before )
    end

    return position
  end

  if before_index then return before_index end

  return getn( placed ) + 1
end

---@param entries OrderingEntry[]
---@param base string
---@return string
local function known( entries, base )
  local names = { base }
  for _, entry in ipairs( entries ) do table.insert( names, entry.name ) end
  return table.concat( names, ", " )
end

---@param entries OrderingEntry[]
---@param entry OrderingEntry
---@param base string
---@param noun string
---@return string
local function why_unplaceable( entries, entry, base, noun )
  local missing = {}

  if entry.after and entry.after ~= base and not index_among( entries, entry.after ) then
    table.insert( missing, string.format( "after '%s'", entry.after ) )
  end

  if entry.before and not index_among( entries, entry.before ) then
    table.insert( missing, string.format( "before '%s'", entry.before ) )
  end

  -- Every name it asked for exists, so the only way it can still be unplaceable is a
  -- cycle: two entries each waiting for the other. Worth saying out loud, because the
  -- obvious reading of the message below -- "which is not in the chain" -- would be a lie
  -- here, and would send whoever reads it looking for a typo that isn't there.
  if getn( missing ) == 0 then
    return string.format(
      "%s '%s' could not be placed: its anchors and something anchored to it are waiting on each other. Known: %s.",
      noun, entry.name, known( entries, base ) )
  end

  return string.format( "%s '%s' is anchored %s, which is not in the chain. Known: %s.",
    noun, entry.name, table.concat( missing, " and " ), known( entries, base ) )
end

-- Repeated passes in registration order rather than a topological sort: a pass that places
-- anything makes the next one possible, and a pass that places nothing means what is left
-- cannot be placed at all. Slower than sorting and small enough not to care -- there are a
-- handful of entries -- and it keeps the arithmetic identical to the order entries used to
-- be inserted in one at a time.
--
-- Unplaceable entries come back in the order they were found to be unplaceable:
-- contradictions as each pass hits them, then whatever is still waiting when the passes
-- run out. That is the order their complaints read in.
---@param entries OrderingEntry[]
---@param options { base: string?, noun: string? }?
---@return OrderingEntry[] -- placed, in order
---@return UnplaceableEntry[]
function M.place( entries, options )
  local base = options and options.base or "base"
  local noun = options and options.noun or "entry"

  ---@type OrderingEntry[]
  local placed = {}
  ---@type UnplaceableEntry[]
  local rejected = {}
  local pending = {}

  for _, entry in ipairs( entries ) do table.insert( pending, entry ) end

  local progress = true

  while progress and getn( pending ) > 0 do
    progress = false
    local remaining = {}

    for _, entry in ipairs( pending ) do
      local position, contradiction = position_for( placed, entry, base, noun )

      if position then
        table.insert( placed, position, entry )
        progress = true
      elseif contradiction then
        -- Not waiting on anything: no later pass can make this true.
        table.insert( rejected, { entry = entry, reason = contradiction } )
        progress = true
      else
        table.insert( remaining, entry )
      end
    end

    pending = remaining
  end

  for _, entry in ipairs( pending ) do
    table.insert( rejected, { entry = entry, reason = why_unplaceable( entries, entry, base, noun ) } )
  end

  return placed, rejected
end

m.Ordering = M
return M
