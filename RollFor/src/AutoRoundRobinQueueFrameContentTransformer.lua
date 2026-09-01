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
  [ "Reset" ] = button_definition( "Reset", 70 ),
  [ "Close" ] = button_definition( "Close", 70 )
}

---@alias RoundRobinQueueFrameButtonType
---| "Reset"
---| "Close"

---@class RoundRobinQueueFrameButtonWithCallback
---@field type RoundRobinQueueFrameButtonType
---@field callback fun()

---@class RoundRobinQueueFrameData
---@field rows AutoRoundRobinRow[]
---@field buttons RoundRobinQueueFrameButtonWithCallback[]

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
  table.insert( content, { type = "text", value = m.colors.blue( "Auto Round Robin Queue" ), padding = 6 } )
end

---@param content table
local function add_header( content )
  table.insert( content, {
    type = "round_robin_row",
    header = true,
    player = "Player",
    status = "Status",
    eligible = "Eligible",
    padding = 0
  } )
end

-- Nobody in the group at all is the only way to get an empty list, and the window is openable out
-- of raid, so it says so rather than showing bare column titles over nothing.
---@param content table
local function add_empty_notice( content )
  table.insert( content, { type = "text", value = "Nobody in the group yet.", padding = 10 } )
end

-- What the player's place in the rotation is, phrased by how far behind the current cycle they
-- are. Someone served this cycle is done and sits back in grey; someone owed more than one cycle
-- has been missing for a while and is called out, because that's the row that explains why they
-- keep winning when they walk back in.
---@param row AutoRoundRobinRow
---@return string
local function status_cell( row )
  if row.behind == 0 then return m.colors.grey( "Received" ) end
  if row.behind == 1 then return "Waiting" end

  return m.colors.hl( string.format( "Owed (%d cycles)", row.behind ) )
end

-- Being in the group and being able to receive are different things (see AutoRoundRobin): a
-- player outside the instance or out of range is still in the rotation, they just can't be paid
-- right now. Dimmed rather than red -- it's a fact about where they're standing, not a problem.
---@param row AutoRoundRobinRow
---@return string
local function eligible_cell( row )
  return row.eligible and "Yes" or m.colors.grey( "No" )
end

---@param content table
---@param rows AutoRoundRobinRow[]
local function add_rows( content, rows )
  for i, row in ipairs( rows ) do
    table.insert( content, {
      type = "round_robin_row",
      player = m.colorize_player_by_class( row.player_name, row.class ),
      status = status_cell( row ),
      eligible = eligible_cell( row ),
      padding = i == 1 and 4 or 2
    } )
  end
end

---@param data RoundRobinQueueFrameData
local function transform( data )
  local content = {}
  local rows = data.rows or {}

  add_title( content )

  if m.getn( rows ) == 0 then
    add_empty_notice( content )
  else
    add_header( content )
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
