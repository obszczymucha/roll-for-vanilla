RollFor = RollFor or {}
local m = RollFor

if m.ResistanceBonusRollEligibilityFrameContentTransformer then return end

local M = {}

-- The two reasons that aren't a judgement about a number. Everything else the
-- module writes names a school and a value, so it's colored by the verdict. Read
-- off the module that writes them rather than retyped, so a rename over there
-- can't quietly turn this whole column green.
local NOT_SCANNED = m.ResistanceBonusRollEligibility.NOT_SCANNED
local MANUAL = m.ResistanceBonusRollEligibility.MANUAL

---@param label string
---@param width number
local function button_definition( label, width )
  return { type = "button", label = label, width = width }
end

M.button_definitions = {
  [ "Infer" ] = button_definition( "Infer", 70 ),
  [ "Reset" ] = button_definition( "Reset", 70 ),
  [ "Close" ] = button_definition( "Close", 70 )
}

---@alias BonusRollEligibilityFrameButtonType
---| "Infer"
---| "Reset"
---| "Close"

---@class BonusRollEligibilityFrameButtonWithCallback
---@field type BonusRollEligibilityFrameButtonType
---@field callback fun()
---@field disabled boolean?

---@class BonusRollEligibilityFrameRow : BonusRollEligibilityRow
---@field on_check fun( checked: boolean )

---@class BonusRollEligibilityFrameData
---@field rows BonusRollEligibilityFrameRow[]
---@field buttons BonusRollEligibilityFrameButtonWithCallback[]

---@class BonusRollEligibilityFrameContentTransformer
---@field transform fun( data: BonusRollEligibilityFrameData ): table

---@param content table
---@param buttons BonusRollEligibilityFrameButtonWithCallback[]
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

---@param content table
local function add_title( content )
  table.insert( content, { type = "text", value = m.colors.blue( "Resistance Bonus Roll Eligibility" ), padding = 6 } )
end

---@param content table
local function add_header( content )
  table.insert( content, {
    type = "eligibility_row",
    header = true,
    player = "Player",
    reason = "Reason",
    padding = 0
  } )
end

-- The reason is colored by what it means, not by the checkbox: green says a
-- scan found the gear, red says a scan found it wanting. The two reasons that
-- aren't a measurement sit back in grey, so a hand-set row doesn't read as
-- evidence of anything.
---@param row BonusRollEligibilityFrameRow
---@return string
local function reason_cell( row )
  local reason = row.reason or NOT_SCANNED

  if reason == NOT_SCANNED or reason == MANUAL then return m.colors.grey( reason ) end

  return row.eligible and m.colors.green( reason ) or m.colors.red( reason )
end

---@param content table
---@param rows BonusRollEligibilityFrameRow[]
local function add_rows( content, rows )
  for i, row in ipairs( rows or {} ) do
    table.insert( content, {
      type = "eligibility_row",
      player = m.colorize_player_by_class( row.player_name, row.class ),
      reason = reason_cell( row ),
      checked = row.eligible and true or false,
      on_check = row.on_check,
      padding = i == 1 and 4 or 2
    } )
  end
end

---@param data BonusRollEligibilityFrameData
local function transform( data )
  local content = {}
  add_title( content )
  add_header( content )
  add_rows( content, data.rows )
  add_buttons( content, data.buttons )

  return content
end

---@return BonusRollEligibilityFrameContentTransformer
function M.new()
  return {
    transform = transform
  }
end

m.ResistanceBonusRollEligibilityFrameContentTransformer = M
return M
