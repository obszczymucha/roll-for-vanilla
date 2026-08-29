RollFor = RollFor or {}
local m = RollFor

if m.ResistanceFrame then return end

local M = {}

-- The group's resistance list. Rendering only: ResistanceCheck owns the cache
-- and the scanning, this file turns its rows into widget calls and wires the
-- buttons back to it. ListPopup owns the window itself.

---@class ResistanceFrame
---@field show fun()
---@field hide fun()
---@field toggle fun()
---@field on_group_changed fun()
---@field get_frame fun(): Popup?

---@param popup_builder PopupBuilder
---@param content_transformer ResistanceFrameContentTransformer
---@param resistance_check ResistanceCheck
---@param announcer ResistanceAnnouncer
---@param db table
function M.new( popup_builder, content_transformer, resistance_check, announcer, db )
  ---@type ListPopup
  local list

  ---@return ResistanceFrameRow[]
  local function rows()
    local result = {}

    for _, row in ipairs( resistance_check.get_rows() ) do
      local player_name = row.player_name

      table.insert( result, {
        player_name = player_name,
        class = row.class,
        resistance_type = row.resistance_type,
        personal = row.personal,
        total = row.total,
        food = row.food,
        missing_neck = row.missing_neck,
        scanning = row.scanning,
        failed = row.failed,
        on_clear = function() resistance_check.clear( player_name ) end
      } )
    end

    return result
  end

  -- Reads out what's already known, then goes looking for the rest. The
  -- announcer stays open over the scan it kicks off, so the players still being
  -- inspected are read out as their results land -- the same trickle that fills
  -- in the list.
  local function on_check()
    announcer.announce()
    resistance_check.scan()
  end

  -- The announcer owns both of these; the frame only draws them and hands the
  -- clicks straight back, so what's on screen is whatever was persisted.
  ---@return ResistanceFrameOption[]
  local function options()
    return {
      { label = "Announce to raid", checked = announcer.is_enabled(), on_click = announcer.set_enabled },
      { label = "Include cached", checked = announcer.is_including_cached(), on_click = announcer.set_including_cached }
    }
  end

  ---@return ResistanceFrameData
  local function content()
    return {
      rows = rows(),
      options = options(),
      buttons = {
        -- Clicking Check again mid-scan would queue players who are already in
        -- flight, so it stays disabled until the queue drains.
        { type = "Check", callback = on_check, disabled = resistance_check.is_scanning() },
        { type = "Clear", callback = resistance_check.clear_all },
        { type = "Close", callback = function() list.hide() end }
      }
    }
  end

  list = m.ListPopup.new( {
    name = "RollForResistanceFrame",
    slash_command = "rfres",
    db = db,
    popup_builder = popup_builder,
    content_transformer = content_transformer,
    content = content,
    row_type = "resistance_row",
    row_callback = "on_clear"
  } )

  -- Scan results trickle in one inspect at a time, so the list redraws as they
  -- land. Nothing to redraw while it's hidden.
  resistance_check.subscribe( list.refresh_if_visible )

  ---@type ResistanceFrame
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

m.ResistanceFrame = M
return M
