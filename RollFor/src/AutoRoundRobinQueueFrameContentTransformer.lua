RollFor = RollFor or {}
local m = RollFor

if m.AutoRoundRobinQueueFrameContentTransformer then return end

local M = {}

---@param label string
---@param width number
local function button_definition( label, width )
  return { type = "button", label = label, width = width }
end

M.button_definitions = {
  [ "Add" ] = button_definition( "Add", 60 ),
  [ "CycleUp" ] = button_definition( "Up", 60 ),
  [ "CycleDown" ] = button_definition( "Down", 60 )
}

---@alias RoundRobinQueueFrameButtonType
---| "Add"
---| "CycleUp"
---| "CycleDown"

---@class RoundRobinQueueFrameButtonWithCallback
---@field type RoundRobinQueueFrameButtonType
---@field callback fun()

---@class RoundRobinQueueFrameData
---@field category string -- the category whose queue is shown
---@field categories string[] -- everything the dropdown offers
---@field on_category_change fun( category: string )
---@field rows RoundRobinQueueFrameRow[]
---@field buttons RoundRobinQueueFrameButtonWithCallback[]

---@class RoundRobinQueueFrameRow : AutoRoundRobinRow
---@field on_up fun()
---@field on_down fun()
---@field on_remove fun()

---@class RoundRobinQueueFrameContentTransformer
---@field transform fun( data: RoundRobinQueueFrameData ): table

---@param content table
---@param buttons RoundRobinQueueFrameButtonWithCallback[]
local function add_buttons( content, buttons )
  for _, button in ipairs( buttons or {} ) do
    local definition = M.button_definitions[ button.type ]
    if not definition then error( string.format( "Unsupported button type: %s", button.type or "nil" ) ) end

    table.insert( content, {
      type = definition.type,
      label = definition.label,
      width = definition.width,
      on_click = button.callback
    } )
  end
end

---@param content table
local function add_title( content )
  -- Tighter to the top of the window than the other list popups' titles, which sit at 6: this one
  -- shares its line with the corner X, and a title hanging below the X reads as misaligned.
  table.insert( content, { type = "text", value = m.colors.blue( "Auto Round Robin Queues" ), padding = 1 } )
end

-- Each category owns an independent queue, so the dropdown is not a filter over one list -- it
-- picks which list you are looking at and editing.
--
-- No label: it sits directly under a title that already says these are the round robin queues,
-- and a box reading "Gems" under it is not ambiguous enough to need "Queue" written beside it.
-- Narrower than the default for the same reason -- the widest category name is short.
local category_dropdown_width = 60

-- Between rows, and above the first one. They add up to what the first row used to carry on its
-- own (see add_rows).
local row_gap = 2
local count_gap = 2

---@param content table
---@param data RoundRobinQueueFrameData
local function add_category_picker( content, data )
  local options = {}

  for _, category in ipairs( data.categories or {} ) do
    table.insert( options, { value = category, label = category } )
  end

  table.insert( content, {
    type = "dropdown",
    label = "",
    width = category_dropdown_width,
    value = data.category,
    options = options,
    on_change = data.on_category_change,
    padding = 8
  } )
end

-- A queue nobody is in yet. Only reachable out of a group with nothing added by hand, since
-- joining seeds every queue.
-- How many are in the queue. Above the list rather than in the title because it is a fact about
-- the list, and it changes as you edit it.
---@param content table
---@param rows RoundRobinQueueFrameRow[]
local function add_count( content, rows )
  table.insert( content, {
    type = "round_robin_count",
    count = tostring( m.getn( rows ) ),
    -- The widget itself is a sliver that draws its number in the line above (see
    -- GuiElements.round_robin_count), so this padding is really the gap above the first row. It
    -- lives here rather than on that row because this line is never scrolled away, and a gap that
    -- belongs to a row disappears when that row does.
    padding = count_gap
  } )
end

---@param content table
local function add_empty_notice( content )
  table.insert( content, { type = "text", value = "Nobody in this queue yet.", padding = 10 } )
end

-- The one thing the order alone cannot say. A player who cannot receive right now is greyed
-- rather than labelled -- it is a fact about where they are standing, not about their place in
-- the queue, and it stops being true the moment they walk back in.
--
-- It also quietly answers "why did the second row get it": the drop goes to the first player who
-- can actually receive, so a greyed name at the front was passed over without losing its place.
---@param row RoundRobinQueueFrameRow
---@return string
local function player_cell( row )
  if not row.eligible then return m.colors.grey( row.name ) end

  return m.colorize_player_by_class( row.name, row.class )
end

-- Every row is padded the same. A wider gap on the first one would be a gap that exists only
-- while that row is on screen: padding is decided by a row's place in the whole list, not in the
-- viewport, so scrolling the first row away would take its extra space with it and the rest of
-- the list would ride up. Whatever the top of the list wants is the count line's to give.
---@param content table
---@param rows RoundRobinQueueFrameRow[]
local function add_rows( content, rows )
  local count = m.getn( rows )

  for i, row in ipairs( rows ) do
    table.insert( content, {
      type = "round_robin_row",
      player = player_cell( row ),
      can_move_up = i > 1,
      can_move_down = i < count,
      on_up = row.on_up,
      on_down = row.on_down,
      on_remove = row.on_remove,
      padding = row_gap
    } )
  end
end

---@param data RoundRobinQueueFrameData
local function transform( data )
  local content = {}
  local rows = data.rows or {}

  add_title( content )
  add_category_picker( content, data )

  if m.getn( rows ) == 0 then
    add_empty_notice( content )
  else
    add_count( content, rows )
    add_rows( content, rows )
  end

  add_buttons( content, data.buttons )

  return content
end

---@return RoundRobinQueueFrameContentTransformer
function M.new()
  return {
    transform = transform
  }
end

m.AutoRoundRobinQueueFrameContentTransformer = M
return M
