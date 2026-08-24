RollFor = RollFor or {}
local m = RollFor

if m.ResistanceBonusRollEligibilityFrame then return end

local M = {}

-- Who may take a bonus roll. Rendering only: ResistanceBonusRollEligibility owns
-- the database and the rule, this file turns its rows into widget calls and
-- wires the checkboxes and buttons back to it. ListPopup owns the window itself.

---@class ResistanceBonusRollEligibilityFrame
---@field show fun()
---@field hide fun()
---@field toggle fun()
---@field on_group_changed fun()
---@field get_frame fun(): Popup?

---@param popup_builder PopupBuilder
---@param content_transformer BonusRollEligibilityFrameContentTransformer
---@param eligibility ResistanceBonusRollEligibility
---@param resistance_check ResistanceCheck
---@param db table
function M.new( popup_builder, content_transformer, eligibility, resistance_check, db )
  ---@type ListPopup
  local list

  ---@return BonusRollEligibilityFrameRow[]
  local function rows()
    local result = {}

    for _, row in ipairs( eligibility.get_rows() ) do
      local player_name = row.player_name

      table.insert( result, {
        player_name = player_name,
        class = row.class,
        eligible = row.eligible,
        reason = row.reason,
        -- No reason passed, so the module stamps this one as hand-set.
        on_check = function( checked ) eligibility.set( player_name, checked ) end
      } )
    end

    return result
  end

  ---@return BonusRollEligibilityFrameData
  local function content()
    return {
      rows = rows(),
      buttons = {
        -- Inferring off a half-filled cache would write "Not scanned" rows that
        -- a second click would immediately correct, so it waits for the scan.
        { type = "Infer", callback = eligibility.infer, disabled = resistance_check.is_scanning() },
        { type = "Reset", callback = eligibility.reset },
        { type = "Close", callback = function() list.hide() end }
      }
    }
  end

  list = m.ListPopup.new( {
    name = "RollForResistanceBonusRollEligibilityFrame",
    slash_command = "rfbonus",
    db = db,
    popup_builder = popup_builder,
    content_transformer = content_transformer,
    content = content,
    row_type = "eligibility_row",
    row_callback = "on_check"
  } )

  eligibility.subscribe( list.refresh_if_visible )
  -- A scan landing changes what Infer would produce, and the frame may well be
  -- open while one runs.
  resistance_check.subscribe( list.refresh_if_visible )

  ---@type ResistanceBonusRollEligibilityFrame
  return {
    show = list.show,
    hide = list.hide,
    toggle = list.toggle,
    -- The roster is read fresh on every refresh, so redrawing is all it takes
    -- for someone who joined to appear and someone who left to drop off.
    on_group_changed = list.refresh_if_visible,
    get_frame = list.get_frame
  }
end

m.ResistanceBonusRollEligibilityFrame = M
return M
