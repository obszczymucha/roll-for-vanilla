RollFor = RollFor or {}
local m = RollFor

if m.ResistanceBonusRollFrameContentTransformer then return end

local M = {}

local getn = m.getn

---@param label string
---@param width number
local function button_definition( label, width )
  return { type = "button", label = label, width = width }
end

M.button_definitions = {
  [ "Close" ] = button_definition( "Close", 70 )
}

---@alias BonusRollFrameButtonType
---| "Close"

---@class BonusRollFrameButtonWithCallback
---@field type BonusRollFrameButtonType
---@field callback fun()

---@class BonusRollFrameData
---@field rows BonusRollRegistryRow[]
---@field buttons BonusRollFrameButtonWithCallback[]

---@class BonusRollFrameContentTransformer
---@field transform fun( data: BonusRollFrameData ): table

---@param content table
---@param buttons BonusRollFrameButtonWithCallback[]
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
  table.insert( content, { type = "text", value = m.colors.blue( "Resistance Bonus Rolls" ), padding = 6 } )
end

---@param content table
local function add_empty_notice( content )
  table.insert( content, { type = "text", value = m.colors.grey( "No bonus rolls granted yet." ), padding = 10 } )
end

---@param content table
local function add_header( content )
  table.insert( content, {
    type = "bonus_roll_row",
    header = true,
    player = "Player",
    rolls = "Rolls",
    padding = 0
  } )
end

-- One line per boss that paid for a roll, in the order they were granted -- which is
-- the order they were killed in. Nothing here dates them; the row itself is the answer
-- to "how many", the tooltip is "which ones" and, for the ones already gone, what they
-- went on.
--
-- The spend record is the whole reason entries are marked rather than deleted: it is what
-- settles an argument about a roll after the item has been handed out. Spent lines are
-- greyed, so the unused ones -- the rolls the player can still actually cast -- are what
-- the eye lands on.
---@param row BonusRollRegistryRow
---@return string[]
local function tooltip_lines( row )
  local result = {}

  for _, entry in ipairs( row.entries ) do
    local used = entry.used_on

    if used then
      table.insert( result, m.colors.grey( string.format( "%s - spent on %s (%s)",
        entry.boss_name, used.item_link, used.roll ) ) )
    else
      table.insert( result, entry.boss_name )
    end
  end

  return result
end

---@param content table
---@param rows BonusRollRegistryRow[]
local function add_rows( content, rows )
  for i, row in ipairs( rows or {} ) do
    table.insert( content, {
      type = "bonus_roll_row",
      player = m.colorize_player_by_class( row.player_name, row.class ),
      rolls = tostring( row.count ),
      tooltip_lines = tooltip_lines( row ),
      padding = i == 1 and 4 or 2
    } )
  end
end

---@param data BonusRollFrameData
local function transform( data )
  local content = {}
  add_title( content )

  if getn( data.rows or {} ) == 0 then
    add_empty_notice( content )
  else
    add_header( content )
    add_rows( content, data.rows )
  end

  add_buttons( content, data.buttons )

  return content
end

---@return BonusRollFrameContentTransformer
function M.new()
  return {
    transform = transform
  }
end

m.ResistanceBonusRollFrameContentTransformer = M
return M
