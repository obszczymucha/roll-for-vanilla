local M = {}

local transformer = require( "src/RollingPopupContentTransformer" )
local button_definitions = transformer.button_definitions

local options_transformer = require( "src/OptionsFrameContentTransformer" )
local options_button_definitions = options_transformer.button_definitions

local T = require( "src/Types" )
local RT = T.RollType

---@param item DroppedItem
---@param item_count number
---@param padding number?
function M.item_link( item, item_count, padding )
  return { type = "item_link_with_icon", link = item.link, tooltip_link = item.tooltip_link, count = item_count, quantity = item.quantity or 1, padding = padding or 5 }
end

---@param player Player
---@param roll_type RollType
---@param padding number?
function M.roll_placeholder( player, roll_type, padding )
  return { type = "roll", player_name = player.name, player_class = player.class, roll_type = roll_type, padding = padding }
end

-- Soft-res rolls render as one row per player with a cell per roll, so their expected
-- shape is a `rolls` array rather than a single `roll`.
--
-- A cell is a roll value, `false` for a pending soft-res cell, or `{ br = <roll|false> }`
-- for a bonus one -- the bonus roll being an extra cell on the player's own row rather
-- than a row of its own.
---@param player Player
---@param cells table -- cast rolls in cast order; `false` for a pending cell
---@param cell_count number? -- widest grouped row in the popup; defaults to this row's own
---@param padding number?
function M.sr_row( player, cells, cell_count, padding )
  local rolls = {}
  local best_index, best_roll

  for i, cell in ipairs( cells ) do
    local is_bonus = type( cell ) == "table"
    -- Not `is_bonus and cell.br or cell`: a pending bonus cell is `{ br = false }`, and
    -- `false or cell` would hand back the wrapper table as the roll value.
    local roll = cell
    if is_bonus then roll = cell.br end

    table.insert( rolls, { roll_type = is_bonus and RT.BonusRoll or RT.SoftRes, roll = roll ~= false and roll or nil } )

    if roll ~= false and (not best_roll or roll > best_roll) then
      best_roll = roll
      best_index = i
    end
  end

  return {
    type = "roll",
    player_name = player.name,
    player_class = player.class,
    rolls = rolls,
    best_index = best_index,
    cell_count = cell_count or table.getn( cells ),
    padding = padding
  }
end

---@param player Player
---@param padding number?
---@param cell_count number?
function M.sr_roll_placeholder( player, padding, cell_count )
  return M.sr_row( player, { false }, cell_count, padding )
end

-- A player owed one soft-res roll and one bonus roll, neither cast yet. The bonus pip
-- leads, which is how the popup renders it.
---@param player Player
---@param padding number?
---@param cell_count number?
function M.bonus_roll_placeholder( player, padding, cell_count )
  return M.sr_row( player, { { br = false }, false }, cell_count, padding )
end

---@param player Player
---@param padding number?
function M.mainspec_roll( player, roll, padding )
  return { type = "roll", player_name = player.name, player_class = player.class, roll_type = RT.MainSpec, roll = roll, padding = padding }
end

---@param player Player
---@param padding number?
function M.offspec_roll( player, roll, padding )
  return { type = "roll", player_name = player.name, player_class = player.class, roll_type = RT.OffSpec, roll = roll, padding = padding }
end

---@param player Player
---@param roll number
---@param padding number?
---@param cell_count number?
function M.softres_roll( player, roll, padding, cell_count )
  return M.sr_row( player, { roll }, cell_count, padding )
end

---@param message string
---@param padding number?
function M.text( message, padding ) return { type = "text", value = message, padding = padding } end

---@param height number
---@param padding number?
function M.empty_line( height, padding ) return { type = "empty_line", height = height, padding = padding } end

---@param index number
---@param name string
---@param comment string?
---@param comment_tooltip string[]?
---@param bind string?
---@param quantity number?
function M.enabled_item( index, name, comment, comment_tooltip, bind, quantity )
  return { index = index, is_enabled = true, is_selected = false, name = name, comment = comment, comment_tooltip = comment_tooltip, bind = bind, quantity = quantity }
end

---@param index number
---@param name string
---@param comment string?
---@param comment_tooltip string[]?
---@param bind string?
---@param quantity number?
function M.disabled_item( index, name, comment, comment_tooltip, bind, quantity )
  return { index = index, is_enabled = false, is_selected = false, name = name, comment = comment, comment_tooltip = comment_tooltip, bind = bind, quantity = quantity }
end

---@param index number
---@param name string
---@param comment string?
---@param comment_tooltip string[]?
---@param bind string?
---@param quantity number?
function M.selected_item( index, name, comment, comment_tooltip, bind, quantity )
  return { index = index, is_enabled = true, is_selected = true, name = name, comment = comment, comment_tooltip = comment_tooltip, bind = bind, quantity = quantity }
end

---@param ... RollingPopupButtonType
function M.buttons( ... )
  local result = {}

  for _, button_type in ipairs( { ... } ) do
    local button = button_definitions[ button_type ]
    if not button then error( string.format( "%s button definition was not found.", button_type ), 2 ) end

    table.insert( result, button_definitions[ button_type ] )
  end

  return table.unpack( result )
end

M.individual_award_button = { type = "award_button", label = "Award", width = 90, padding = 6 }

---@param ... OptionsFrameButtonType
function M.options_buttons( ... )
  local result = {}

  for _, button_type in ipairs( { ... } ) do
    local button = options_button_definitions[ button_type ]
    if not button then error( string.format( "%s button definition was not found.", button_type ), 2 ) end

    table.insert( result, options_button_definitions[ button_type ] )
  end

  return table.unpack( result )
end

---@param label string
---@param value boolean
---@param padding number?
function M.checkbox( label, value, padding )
  return { type = "checkbox", label = label, value = value, padding = padding }
end

---@param label string
---@param value number
---@param min number
---@param max number
---@param precision number?
---@param padding number?
function M.slider( label, value, min, max, precision, padding )
  return { type = "slider", label = label, value = value, min = min, max = max, precision = precision or 0, padding = padding }
end

---@param label string
---@param value number
---@param precision number?
---@param padding number?
function M.editbox( label, value, precision, padding )
  return { type = "editbox", label = label, value = value, precision = precision or 0, padding = padding }
end

---@param label string
---@param value any
---@param options table
---@param padding number?
function M.dropdown( label, value, options, padding )
  return { type = "dropdown", label = label, value = value, options = options, padding = padding }
end

return M
