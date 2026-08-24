RollFor = RollFor or {}
local m = RollFor

if m.ResistanceFrameContentTransformer then return end

local M = {}

-- The only two schools the column can ever report, with the client's own color
-- for each name. What a player is expected to reach is the registry's to say --
-- that's the run's rule, not presentation -- so it's filled in per instance.
local school_labels = {
  [ m.ResistanceRegistry.ResistanceType.Fire ] = m.colorize( "ff8000", "Fire" ),
  [ m.ResistanceRegistry.ResistanceType.Shadow ] = m.colorize( "8080ff", "Shadow" )
}

---@param label string
---@param width number
local function button_definition( label, width )
  return { type = "button", label = label, width = width }
end

M.button_definitions = {
  [ "Check" ] = button_definition( "Check", 70 ),
  [ "Clear" ] = button_definition( "Clear", 70 ),
  [ "Close" ] = button_definition( "Close", 70 )
}

---@alias ResistanceFrameButtonType
---| "Check"
---| "Clear"
---| "Close"

---@class ResistanceFrameButtonWithCallback
---@field type ResistanceFrameButtonType
---@field callback fun()
---@field disabled boolean?

---@class ResistanceFrameRow : ResistanceRow
---@field on_clear fun()

---@class ResistanceFrameData
---@field rows ResistanceFrameRow[]
---@field buttons ResistanceFrameButtonWithCallback[]

---@class ResistanceFrameContentTransformer
---@field transform fun( data: ResistanceFrameData ): table

---@param content table
---@param buttons ResistanceFrameButtonWithCallback[]
local function add_buttons( content, buttons )
  for _, button in ipairs( buttons or {} ) do
    local definition = M.button_definitions[ button.type ]
    if not definition then error( string.format( "Unsupported button type: %s", button.type or "nil" ) ) end

    table.insert( content, {
      type = definition.type,
      label = definition.label,
      width = definition.width,
      disabled = button.disabled and true or false,
      on_click = button.callback
    } )
  end
end

-- Three states share these columns: mid-scan, scanned, and nothing known. A
-- failed inspect is the fourth -- it renders as a dash too, but a red one, so
-- "out of range" doesn't look like "not scanned yet".
---@param row ResistanceFrameRow
---@param value string|number|nil
---@return string
local function cell( row, value )
  if row.scanning then return "..." end
  if value == nil then return row.failed and m.colors.red( "-" ) or "-" end

  return tostring( value )
end

-- What Personal doesn't say on its own. Food is already counted in the number,
-- so the star only says part of it isn't gear; the dash says the resistance neck
-- is missing, whatever the number adds up to. Total gets neither -- both markers
-- are about what the player brought themselves.
---@param row ResistanceFrameRow
---@return string -- empty when there's nothing to point out
local function markers( row )
  local result = ""

  if row.food then result = result .. "*" end
  if row.missing_neck then result = result .. "-" end

  return result
end

-- Both numbers are judged against the school's minimum on their own, so a row
-- can show gear that falls short next to a buffed total that doesn't. Markers
-- ride inside the color, so they read as part of the number.
---@param row ResistanceFrameRow
---@param value number?
---@param school table?
---@param suffix string? -- what markers() had to say about this number
---@return string
local function value_cell( row, value, school, suffix )
  if row.scanning or value == nil then return cell( row, value ) end

  local color = value >= school.minimum and m.colors.green or m.colors.red

  return color( string.format( "%s%s", value, suffix or "" ) )
end

---@param content table
local function add_header( content )
  table.insert( content, {
    type = "resistance_row",
    header = true,
    player = "Player",
    resistance = "Resistance",
    personal = "Personal",
    total = "Total",
    padding = 0
  } )
end

---@param content table
---@param rows ResistanceFrameRow[]
---@param schools table<ResistanceType, table>
local function add_rows( content, rows, schools )
  for i, row in ipairs( rows or {} ) do
    local school = schools[ row.resistance_type ]

    table.insert( content, {
      type = "resistance_row",
      player = m.colorize_player_by_class( row.player_name, row.class ),
      resistance = cell( row, school and school.label ),
      personal = value_cell( row, row.personal, school, markers( row ) ),
      total = value_cell( row, row.total, school ),
      -- Nothing cached means nothing to clear, so the row doesn't offer it.
      clearable = row.personal ~= nil,
      on_clear = row.on_clear,
      padding = i == 1 and 4 or 2
    } )
  end
end

---@param registry ResistanceRegistry
---@return ResistanceFrameContentTransformer
function M.new( registry )
  local schools = {}

  for resistance_type, label in pairs( school_labels ) do
    schools[ resistance_type ] = { label = label, minimum = registry.minimum( resistance_type ) }
  end

  ---@param data ResistanceFrameData
  local function transform( data )
    local content = {}
    add_header( content )
    add_rows( content, data.rows, schools )
    add_buttons( content, data.buttons )

    return content
  end

  ---@type ResistanceFrameContentTransformer
  return {
    transform = transform
  }
end

m.ResistanceFrameContentTransformer = M
return M
