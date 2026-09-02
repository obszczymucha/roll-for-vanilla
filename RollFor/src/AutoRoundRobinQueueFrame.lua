RollFor = RollFor or {}
local m = RollFor

if m.AutoRoundRobinQueueFrame then return end

local M = {}

-- The round-robin queues, one category at a time. Rendering and wiring only: AutoRoundRobin owns
-- the queues and every rule about them, this file turns its rows into widget calls and hands the
-- clicks back. ListPopup owns the window itself.
--
-- Which category is on screen is this window's own state and nothing else's -- it is where you
-- last left the dropdown, not something the rotation knows or should persist against the queues.
-- It is remembered in the window's db alongside the position, for the same reason the position is.

---@class AutoRoundRobinQueueFrame
---@field show fun()
---@field hide fun()
---@field toggle fun()
---@field on_group_changed fun()
---@field get_frame fun(): Popup?

---@param popup_builder PopupBuilder
---@param content_transformer RoundRobinQueueFrameContentTransformer
---@param round_robin AutoRoundRobin
---@param add_player_frame AutoRoundRobinAddPlayerFrame
---@param config Config
---@param db table
---@return AutoRoundRobinQueueFrame
function M.new( popup_builder, content_transformer, round_robin, add_player_frame, config, db )
  ---@type ListPopup
  local list

  -- Falls back to the first category rather than persisting a name that may have been dropped
  -- from the catalogue since it was written.
  ---@return string
  local function category()
    local categories = round_robin.get_categories()

    for _, name in ipairs( categories ) do
      if name == db.category then return name end
    end

    return categories[ 1 ]
  end

  -- Anybody not in the group is left out (see AutoRoundRobin.get_rows), so a row's place in this
  -- list is not its place in the queue. Every callback acts on the queue, so all of them are
  -- bound to `position` -- the index the queue knows it by -- and never to the drawn order.
  ---@return RoundRobinQueueFrameRow[]
  local function rows()
    local current = category()
    local visible = round_robin.get_rows( current )
    local result = {}

    -- The arrows move a player past the one above or below them *on screen*. Stepping one place
    -- in the queue instead would swap them with a hidden player and redraw identically, which
    -- reads as a dead button.
    ---@param i number
    ---@param offset number
    ---@return fun()
    local function swap_with_neighbour( i, offset )
      return function()
        local from, to = visible[ i ], visible[ i + offset ]
        if not to then return end

        round_robin.move_player( current, from.position, to.position - from.position )
      end
    end

    for i, row in ipairs( visible ) do
      table.insert( result, {
        name = row.name,
        class = row.class,
        core = row.core,
        -- Every one of these refreshes the window, so the next click is against the list it
        -- just produced.
        on_up = swap_with_neighbour( i, -1 ),
        on_down = swap_with_neighbour( i, 1 ),
        on_remove = function() round_robin.remove_player( current, row.position ) end,
        on_toggle_core = function( core ) round_robin.set_core( current, row.position, core ) end
      } )
    end

    return result
  end

  ---@return RoundRobinQueueFrameOption[]
  local function options()
    local result = {}

    for _, name in ipairs( round_robin.get_categories() ) do
      table.insert( result, { value = name, label = m.AutoRoundRobinDb.colorize( name ) } )
    end

    return result
  end

  ---@return RoundRobinQueueFrameData
  local function content()
    local current = category()

    return {
      category = current,
      categories = options(),
      on_category_change = function( selected )
        db.category = selected
        list.refresh_if_visible()
      end,
      rows = rows(),
      -- Closing is the corner X (see close_button below), so it isn't in the row. Resetting is
      -- /rf autorobin reset: it throws away every queue at once, which is not something to leave
      -- one click away from the up arrow.
      buttons = {
        { type = "Add", callback = function() add_player_frame.show( current ) end },
        -- Up moves the list up: the head goes to the back and everybody else climbs a place.
        { type = "CycleUp", callback = function() round_robin.cycle( current, 1 ) end },
        { type = "CycleDown", callback = function() round_robin.cycle( current, -1 ) end }
      }
    }
  end

  list = m.ListPopup.new( {
    name = "RollForAutoRoundRobinQueueFrame",
    slash_command = "rfrobin",
    db = db,
    popup_builder = popup_builder,
    content_transformer = content_transformer,
    content = content,
    row_type = "round_robin_row",
    header_type = "round_robin_count",
    close_button = true,
    esc = true,
    -- A full raid in one window would be forty rows tall, so the list scrolls past whatever the
    -- user has asked to see at once.
    max_rows = config.round_robin_queue_rows,
    -- The same blue AutoLootFrame uses. This window is one click off the round-robin selection
    -- window, so a red border on one of the pair read as a warning rather than as a style. The
    -- other list popups keep the red they shipped with.
    border_color = { 0.351, 0.553, 1.0, 0.3 }
  } )

  -- Every award and every edit moves somebody, and the window may well be open while a loot
  -- window is.
  round_robin.subscribe( list.refresh_if_visible )
  -- The row limit is read on every redraw, so telling the window to redraw is all it takes for a
  -- change to the setting to land.
  config.subscribe( "round_robin_queue_rows", list.refresh_if_visible )

  ---@type AutoRoundRobinQueueFrame
  return {
    show = list.show,
    hide = list.hide,
    toggle = list.toggle,
    -- The queues are read fresh on every refresh, so redrawing is all it takes for someone who
    -- joined to appear.
    on_group_changed = list.refresh_if_visible,
    get_frame = list.get_frame
  }
end

m.AutoRoundRobinQueueFrame = M
return M
