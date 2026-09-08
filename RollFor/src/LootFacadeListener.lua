RollFor = RollFor or {}
local m = RollFor

if m.LootFacadeListener then return end

local IU = m.ItemUtils

local M = {}
local getn = m.getn

-- The loot pipeline, as a named registry.
--
-- These handlers used to be positional arguments called in a fixed run, which meant an
-- extension could only join the pipeline by being edited into that run. The positions
-- were load-bearing and undocumented: auto_loot runs before anything decides an item is
-- still there, and roll_controller sees what the rest left behind. Getting one wrong
-- hands the item to the wrong person rather than throwing.
--
-- So core names its handlers and anchors them to each other, and extensions anchor to
-- those names through ctx.on_loot -- the same vocabulary, failures and error messages as
-- the soft-res chain, because Ordering is what places both.
--
-- Registration happens before the loot facade exists (extensions declare during
-- Extensions.enable, which runs first), so collecting and subscribing are separate:
-- start() resolves the order once and subscribes, exactly like the chain being built.

---@class LootHandler
---@field name string
---@field after string?
---@field before string?
---@field callback fun( ... )

---@class LootFacadeListener
---@field on_loot fun( event: LootEventName, handler: LootHandler )
---@field register_core fun( components: table )
---@field start fun( loot_facade: LootFacade )
---@field order fun( event: LootEventName ): string[]

local EVENTS = {
  LootOpened = true,
  LootClosed = true,
  LootSlotCleared = true,
  ChatMsgLoot = true
}

---@return LootFacadeListener
function M.new()
  local handlers = {}
  local started = false

  local function fail( message )
    error( string.format( "RollFor loot pipeline: %s", message ), 3 )
  end

  ---@param event LootEventName
  ---@param handler LootHandler
  local function on_loot( event, handler )
    if not EVENTS[ event ] then
      fail( string.format( "'%s' is not a loot event. Known: LootOpened, LootClosed, LootSlotCleared, ChatMsgLoot.",
        tostring( event ) ) )
    end

    if type( handler ) ~= "table" then fail( "a handler must be a table." ) end
    if type( handler.name ) ~= "string" or handler.name == "" then
      fail( "a handler must have a non-empty 'name'." )
    end
    if type( handler.callback ) ~= "function" then
      fail( string.format( "handler '%s' must have a 'callback' function.", handler.name ) )
    end

    -- Subscribing has already happened, so anything arriving now would never be called.
    -- Silently doing nothing is the one outcome worth refusing outright.
    if started then
      fail( string.format( "handler '%s' was registered after the pipeline started.", handler.name ) )
    end

    handlers[ event ] = handlers[ event ] or {}

    for _, existing in ipairs( handlers[ event ] ) do
      if existing.name == handler.name then
        fail( string.format( "handler '%s' is already registered for %s.", handler.name, event ) )
      end
    end

    table.insert( handlers[ event ], {
      name = handler.name,
      after = handler.after,
      before = handler.before,
      callback = handler.callback
    } )
  end

  ---@param event LootEventName
  ---@return LootHandler[]
  local function placed_for( event )
    local placed, unplaceable = m.Ordering.place( handlers[ event ] or {},
      { base = "base", noun = "handler" } )

    for _, rejected in ipairs( unplaceable ) do
      m.err( string.format( "RollFor loot pipeline (%s): %s It has been left out.", event, rejected.reason ) )
    end

    return placed
  end

  -- Chain order, for tests and diagnostics. Resolves quietly -- asking is not starting.
  ---@param event LootEventName
  ---@return string[]
  local function order( event )
    local placed = m.Ordering.place( handlers[ event ] or {}, { base = "base", noun = "handler" } )
    local result = {}
    for _, handler in ipairs( placed ) do table.insert( result, handler.name ) end
    return result
  end

  -- Core's own handlers, named and anchored so they reproduce the order they fired in
  -- when they were argument positions. The anchors are what an extension reads to decide
  -- where its own handler belongs.
  ---@param c table -- the components each handler is a method on
  local function register_core( c )
    on_loot( "LootOpened", { name = "dropped_loot", callback = function() c.dropped_loot.on_loot_opened() end } )
    on_loot( "LootOpened", { name = "dropped_loot_announce", after = "dropped_loot",
      callback = function() c.dropped_loot_announce.on_loot_opened() end } )
    on_loot( "LootOpened", { name = "auto_loot", after = "dropped_loot_announce",
      callback = function() c.auto_loot.on_loot_opened() end } )
    on_loot( "LootOpened", { name = "master_loot", after = "auto_loot",
      callback = function() c.master_loot.on_loot_opened() end } )
    on_loot( "LootOpened", { name = "auto_group_loot", after = "master_loot",
      callback = function() c.auto_group_loot.on_loot_opened() end } )
    on_loot( "LootOpened", { name = "roll_controller", after = "auto_group_loot",
      callback = function() c.roll_controller.loot_opened() end } )

    on_loot( "LootSlotCleared", { name = "master_loot",
      callback = function( slot ) c.master_loot.on_loot_slot_cleared( slot ) end } )
    on_loot( "LootSlotCleared", { name = "auto_group_loot", after = "master_loot",
      callback = function() c.auto_group_loot.on_loot_slot_cleared() end } )

    on_loot( "LootClosed", { name = "roll_controller", callback = function() c.roll_controller.loot_closed() end } )

    -- This covers the scenario where the master looter assigns the loot and then moves immediately,
    -- causing the loot frame to close. In normal circumstances, when the last item gets assigned,
    -- the LOOT_SLOT_CLEARED fires and then LOOT_CLOSED event follows. In this case, however,
    -- LOOT_CLOSED fires first, because of the player movement and the LOOT_SLOT_CLEARED doesn't
    -- (because we're not looting anymore).
    on_loot( "ChatMsgLoot", { name = "master_loot", callback = function( message )
      for player_name, link_with_optional_quantity in string.gmatch( message, "(.-) receives loot: (.*)" ) do
        local item_link = IU.parse_link( link_with_optional_quantity )
        local item_id = item_link and IU.get_item_id( item_link )

        if item_id and item_link then
          c.master_loot.on_loot_received( player_name, item_id, item_link )
        end

        return
      end

      for link_with_optional_quantity in string.gmatch( message, "You receive loot: (.*)" ) do
        local item_link = IU.parse_link( link_with_optional_quantity )
        local item_id = item_link and IU.get_item_id( item_link )

        if item_id and item_link then
          c.master_loot.on_loot_received( c.player_info.get_name(), item_id, item_link )
        end

        return
      end
    end } )
  end

  ---@param loot_facade LootFacade
  local function start( loot_facade )
    started = true

    for event in pairs( EVENTS ) do
      local placed = placed_for( event )

      if getn( placed ) > 0 then
        loot_facade.subscribe( event, function( ... )
          for _, handler in ipairs( placed ) do
            handler.callback( ... )
          end
        end )
      end
    end
  end

  ---@type LootFacadeListener
  return {
    on_loot = on_loot,
    register_core = register_core,
    start = start,
    order = order
  }
end

m.LootFacadeListener = M
return M
