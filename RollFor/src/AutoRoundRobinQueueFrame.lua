RollFor = RollFor or {}
local m = RollFor

if m.AutoRoundRobinQueueFrame then return end

local M = {}

-- Where everyone stands in the rotation. Rendering only: AutoRoundRobin owns the pool, the cycle
-- and the rule, this file turns its rows into widget calls. ListPopup owns the window itself.
--
-- The pool keeps every player this character has ever grouped with, forever -- that's what lets
-- somebody who missed three raids walk back in still owed three cycles. This window is the
-- display, not the record, so AutoRoundRobin.get_rows narrows that to who's in the group now.

---@class AutoRoundRobinQueueFrame
---@field show fun()
---@field hide fun()
---@field toggle fun()
---@field on_group_changed fun()
---@field get_frame fun(): Popup?

---@param popup_builder PopupBuilder
---@param content_transformer RoundRobinQueueFrameContentTransformer
---@param round_robin AutoRoundRobin
---@param on_reset fun() -- asks before throwing the rotation away, then resets
---@param db table
---@return AutoRoundRobinQueueFrame
function M.new( popup_builder, content_transformer, round_robin, on_reset, db )
  ---@type ListPopup
  local list

  ---@return RoundRobinQueueFrameData
  local function content()
    return {
      rows = round_robin.get_rows(),
      buttons = {
        { type = "Reset", callback = on_reset },
        { type = "Close", callback = function() list.hide() end }
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
    row_type = "round_robin_row"
  } )

  -- Every award moves somebody's place, and the window may well be open while a loot window is.
  round_robin.subscribe( list.refresh_if_visible )

  ---@type AutoRoundRobinQueueFrame
  return {
    show = list.show,
    hide = list.hide,
    toggle = list.toggle,
    -- The roster is read fresh on every refresh, so redrawing is all it takes for someone who
    -- joined to appear and someone who left to drop off.
    on_group_changed = list.refresh_if_visible,
    get_frame = list.get_frame
  }
end

m.AutoRoundRobinQueueFrame = M
return M
