RollFor = RollFor or {}
local m = RollFor

if m.Chain then return end

local M = {}
local getn = m.getn

-- An ordered chain of decorators, built once at login.
--
-- RollFor's soft-res view is a stack of decorators wrapped around SoftRes, and the order
-- they're stacked in decides who is allowed to roll for what. That order used to be
-- spelled out as a run of local variables in main.lua, which meant an extension could
-- only join it by being edited into that run.
--
-- Here, core declares the backbone links under stable names and extensions anchor to
-- those names. Anchoring to a name that doesn't exist is an error at build time rather
-- than a silent append: a mis-ordered soft-res chain produces wrong loot decisions, and
-- nobody would trace one back to here.
--
-- Anchors are resolved at build time, not as each link arrives, so a link may anchor to
-- one that has not been added yet. It has to work that way: addons load alphabetically,
-- so RollForNetherVortex declares itself before RollForSoftResIt contributes the very
-- links it anchors to, and neither addon can do anything about the other's name.
--
-- An anchor that is still unresolvable once everything has been added takes that one
-- link out of the chain and says so. It does not throw: build() runs in the composition
-- root, outside the pcall that isolates one extension's mistakes from the rest, so
-- throwing would turn a third-party typo into a failed login for the whole addon. Core's
-- own mistakes -- a duplicate name, a factory returning nil, a tap nobody declared --
-- still throw, because those are bugs here rather than out there.

---@class ChainLink
---@field name string
---@field after string? -- a link name, or "base" for the undecorated object
---@field before string?
---@field factory fun( inner: any ): any

---@class ChainTap
---@field name string
---@field after string? -- capture the value just after this link
---@field before string? -- capture the value just before this link

---@class BuiltChain
---@field final any
---@field tap fun( name: string ): any
---@field has_tap fun( name: string ): boolean

---@class Chain
---@field add fun( link: ChainLink )
---@field tap fun( tap: ChainTap )
---@field has fun( name: string ): boolean
---@field names fun(): string[]
---@field build fun( base: any ): BuiltChain

-- The undecorated object the chain is built on. Usable as an anchor so a link can ask to
-- come first without knowing which core link currently holds that position.
local BASE = "base"

---@param chain_name string
---@return Chain
function M.new( chain_name )
  ---@type ChainLink[]
  local links = {}
  ---@type ChainTap[]
  local taps = {}

  local function fail( message, level )
    error( string.format( "RollFor chain '%s': %s", chain_name, message ), level or 3 )
  end

  ---@param name string
  ---@return number?
  local function index_of( name )
    for i, link in ipairs( links ) do
      if link.name == name then return i end
    end
  end

  ---@param name string
  ---@return boolean
  local function has( name )
    return name == BASE or index_of( name ) ~= nil
  end

  -- Registration order. What "could you have anchored to" means, and callable from
  -- inside resolution -- which the public names() is not, since that resolves first.
  local function all_names()
    local result = {}
    for _, link in ipairs( links ) do table.insert( result, link.name ) end
    return result
  end

  local function known()
    local n = all_names()
    table.insert( n, 1, BASE )
    return table.concat( n, ", " )
  end

  ---@param placed ChainLink[]
  ---@param name string
  ---@return number?
  local function index_among( placed, name )
    for i, link in ipairs( placed ) do
      if link.name == name then return i end
    end
  end

  -- "base" sits at index 0, so `after = "base"` lands at position 1 and everything else
  -- falls out of the same arithmetic.
  --
  -- Three answers, not two: a position, or `nil` plus a complaint when the link can never
  -- be placed, or `nil` and no complaint when its anchor simply has not been placed
  -- *yet*. Only resolve() knows which of the last two it is, because only resolve() knows
  -- whether there is another pass coming.
  ---@param placed ChainLink[]
  ---@param link ChainLink
  ---@return number?, string?
  local function position_for( placed, link )
    local after_index, before_index

    if link.after then
      if link.after == BASE then
        after_index = 0
      else
        after_index = index_among( placed, link.after )
        if not after_index then return nil end
      end
    end

    if link.before then
      before_index = index_among( placed, link.before )
      if not before_index then return nil end
    end

    -- With both anchors given, `after` decides the position and `before` is the
    -- constraint it has to satisfy. Two links asking for the same slot break the tie by
    -- registration order.
    if after_index then
      local position = after_index + 1

      if before_index and position > before_index then
        return nil, string.format( "link '%s' cannot be both after '%s' and before '%s'.",
          link.name, link.after, link.before )
      end

      return position
    end

    if before_index then return before_index end

    return getn( placed ) + 1
  end

  ---@param link ChainLink
  ---@return string
  local function unplaceable( link )
    local missing = {}

    if link.after and link.after ~= BASE and not index_among( links, link.after ) then
      table.insert( missing, string.format( "after '%s'", link.after ) )
    end

    if link.before and not index_among( links, link.before ) then
      table.insert( missing, string.format( "before '%s'", link.before ) )
    end

    -- Every name it asked for exists, so the only way it can still be unplaceable is a
    -- cycle: two links each waiting for the other. Worth saying out loud, because the
    -- obvious reading of the message above -- "which is not in the chain" -- would be a
    -- lie here, and would send whoever reads it looking for a typo that isn't there.
    if getn( missing ) == 0 then
      return string.format(
        "link '%s' could not be placed: its anchors and something anchored to it are waiting on each other. Known: %s.",
        link.name, known() )
    end

    return string.format( "link '%s' is anchored %s, which is not in the chain. Known: %s.",
      link.name, table.concat( missing, " and " ), known() )
  end

  -- Placement, once every link that could be an anchor has arrived. Repeated passes in
  -- registration order rather than a topological sort: a pass that places anything makes
  -- the next one possible, and a pass that places nothing means what is left cannot be
  -- placed at all. Slower than sorting and small enough not to care -- there are a
  -- handful of links -- and it keeps the placement arithmetic identical to the order
  -- links used to be inserted in one at a time.
  ---@param report boolean -- false when only the order is wanted, e.g. from names()
  ---@return ChainLink[]
  local function resolve( report )
    ---@type ChainLink[]
    local placed = {}
    local pending = {}

    for _, link in ipairs( links ) do table.insert( pending, link ) end

    local progress = true

    while progress and getn( pending ) > 0 do
      progress = false
      local remaining = {}

      for _, link in ipairs( pending ) do
        local position, contradiction = position_for( placed, link )

        if position then
          table.insert( placed, position, link )
          progress = true
        elseif contradiction then
          -- Not waiting on anything: no later pass can make this true.
          if report then
            m.err( string.format( "RollFor chain '%s': %s It has been left out.", chain_name, contradiction ) )
          end

          progress = true
        else
          table.insert( remaining, link )
        end
      end

      pending = remaining
    end

    if report then
      for _, link in ipairs( pending ) do
        m.err( string.format( "RollFor chain '%s': %s It has been left out.", chain_name, unplaceable( link ) ) )
      end
    end

    return placed
  end

  ---@param link ChainLink
  local function add( link )
    if type( link ) ~= "table" then fail( "a link must be a table." ) end
    if type( link.name ) ~= "string" or link.name == "" then fail( "a link must have a non-empty 'name'." ) end
    if type( link.factory ) ~= "function" then
      fail( string.format( "link '%s' must have a 'factory' function.", link.name ) )
    end
    if link.name == BASE then fail( string.format( "'%s' is a reserved link name.", BASE ) ) end
    if link.before == BASE then
      fail( string.format( "link '%s' cannot be anchored before '%s'.", link.name, BASE ) )
    end
    if index_of( link.name ) then fail( string.format( "link '%s' is already in the chain.", link.name ) ) end

    -- Registration order, not chain order. Where it actually lands is decided in
    -- resolve(), once every link that could be an anchor has arrived.
    table.insert( links, {
      name = link.name,
      after = link.after,
      before = link.before,
      factory = link.factory
    } )
  end

  -- A named point in the chain whose meaning belongs to core, so that consumers wanting
  -- "the soft-res view before group filtering" can say that, instead of naming whichever
  -- decorator happens to sit there -- a name that goes away when its extension is off.
  ---@param tap ChainTap
  local function add_tap( tap )
    if type( tap ) ~= "table" then fail( "a tap must be a table." ) end
    if type( tap.name ) ~= "string" or tap.name == "" then fail( "a tap must have a non-empty 'name'." ) end

    for _, existing in ipairs( taps ) do
      if existing.name == tap.name then fail( string.format( "tap '%s' is already declared.", tap.name ) ) end
    end

    table.insert( taps, { name = tap.name, after = tap.after, before = tap.before } )
  end

  -- Chain order, not registration order: what this answers is "where did everything end
  -- up", so it resolves first. Quietly -- asking is not building, and a link that cannot
  -- be placed should be complained about once, when the chain is built.
  ---@return string[]
  local function names()
    local result = {}
    for _, link in ipairs( resolve( false ) ) do table.insert( result, link.name ) end
    return result
  end

  ---@param base any
  ---@return BuiltChain
  -- `report` says whether an unplaceable link is worth complaining about. It is, normally:
  -- a link that cannot be placed is a typo in somebody's anchor and the addon quietly does
  -- less than it should. It is not when the caller already knows the anchors are missing
  -- for a reason the user cannot fix -- see main.lua's soft-res chain with no source
  -- installed, where every contributed link is unplaceable and saying so four times over
  -- reads like four bugs.
  ---@param base any
  ---@param options { report: boolean }?
  local function build( base, options )
    if base == nil then fail( "cannot build on a nil base." ) end

    local report = not options or options.report ~= false

    -- The accumulator as it looked on either side of every link, so taps can be resolved
    -- afterwards without running any factory twice.
    local before_link = {}
    local after_link = { [ BASE ] = base }
    local accumulator = base

    for _, link in ipairs( resolve( report ) ) do
      before_link[ link.name ] = accumulator
      accumulator = link.factory( accumulator )

      if accumulator == nil then
        fail( string.format( "the factory for link '%s' returned nil.", link.name ) )
      end

      after_link[ link.name ] = accumulator
    end

    local resolved = {}

    for _, tap in ipairs( taps ) do
      local value

      if tap.before then
        value = before_link[ tap.before ]
        if value == nil then
          fail( string.format( "tap '%s' is anchored before '%s', which is not in the chain. Known: %s.",
            tap.name, tap.before, known() ) )
        end
      elseif tap.after then
        value = after_link[ tap.after ]
        if value == nil then
          fail( string.format( "tap '%s' is anchored after '%s', which is not in the chain. Known: %s.",
            tap.name, tap.after, known() ) )
        end
      else
        value = accumulator
      end

      resolved[ tap.name ] = value
    end

    ---@type BuiltChain
    return {
      final = accumulator,
      tap = function( name )
        local value = resolved[ name ]
        if value == nil then fail( string.format( "there is no tap called '%s'.", name or "nil" ) ) end

        return value
      end,
      -- Asking is not an error, taking a missing one is: whether a tap exists at all
      -- depends on which extensions are installed, so a consumer that can live without
      -- one needs a way to find out that isn't pcall around tap().
      has_tap = function( name )
        return resolved[ name ] ~= nil
      end
    }
  end

  ---@type Chain
  return {
    add = add,
    tap = add_tap,
    has = has,
    names = names,
    build = build
  }
end

M.BASE = BASE

m.Chain = M
return M
