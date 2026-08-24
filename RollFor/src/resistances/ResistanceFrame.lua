RollFor = RollFor or {}
local m = RollFor

if m.ResistanceFrame then return end

local M = {}
local getn = m.getn

local button_defaults = {
  width = 80,
  height = 24,
  scale = 0.76
}

-- The group's resistance list. Rendering only: ResistanceCheck owns the cache
-- and the scanning, this file turns its rows into widget calls and wires the
-- buttons back to it.

---@class ResistanceFrame
---@field show fun()
---@field hide fun()
---@field toggle fun()
---@field on_group_changed fun()
---@field get_frame fun(): Popup?

M.center_point = { point = "CENTER", relative_point = "CENTER", x = 0, y = 0 }

---@param popup_builder PopupBuilder
---@param content_transformer ResistanceFrameContentTransformer
---@param resistance_check ResistanceCheck
---@param db table
function M.new( popup_builder, content_transformer, resistance_check, db )
  ---@type Popup?
  local popup
  local top_padding = 16

  local function on_drag_stop()
    if not popup then return end

    if m.is_frame_out_of_bounds( popup ) then
      db.point = M.center_point
      popup:position( M.center_point )

      return
    end

    local anchor = popup:get_anchor_point()
    db.point = { point = anchor.point, relative_point = anchor.relative_point, x = anchor.x, y = anchor.y }
  end

  local function get_point()
    if popup and m.is_frame_out_of_bounds( popup ) then
      return M.center_point
    elseif db.point then
      return db.point
    else
      return M.center_point
    end
  end

  local function create_popup()
    local result = popup_builder
        :name( "RollForResistanceFrame" )
        :point( get_point() )
        :gui_elements( m.GuiElements )
        :movable()
        :on_drag_stop( on_drag_stop )
        :strata( "DIALOG" )
        :self_centered_anchor()
        :anchor_point( "TOPLEFT" )
        :hidden()
        :build()

    result:border_color( 0.65, 0.22, 0.22, 0.22 )

    return result
  end

  local refresh

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

  ---@return ResistanceFrameData
  local function content()
    return {
      rows = rows(),
      buttons = {
        -- Clicking Check again mid-scan would queue players who are already in
        -- flight, so it stays disabled until the queue drains.
        { type = "Check", callback = resistance_check.scan, disabled = resistance_check.is_scanning() },
        { type = "Clear", callback = resistance_check.clear_all },
        { type = "Close", callback = function() if popup then popup:Hide() end end }
      }
    }
  end

  refresh = function()
    if not popup then popup = create_popup() end
    popup:clear()

    for _, v in ipairs( content_transformer.transform( content() ) ) do
      popup.add_line( v.type, function( type, frame, lines )
        if type == "button" then
          frame:SetWidth( v.width or button_defaults.width )
          frame:SetHeight( v.height or button_defaults.height )
          frame:SetText( v.label or "" )
          frame:ClearAllPoints() -- This fixes a strange visual bug in BCC. Frame is either without label or misaligned without this.
          frame:SetScale( v.scale or button_defaults.scale )
          frame:SetScript( "OnClick", v.on_click or function() end )

          if v.disabled then frame:Disable() else frame:Enable() end
        elseif type == "resistance_row" then
          frame:SetHeader( v.header and true or false )
          frame:SetRow( v )
          frame.on_clear = v.on_clear or function() end
        elseif type == "text" then
          frame:SetText( v.value )
        end

        -- Every row is the same fixed width, so chaining them centered keeps the
        -- columns aligned with each other and with the header.
        if type ~= "button" then
          local count = getn( lines )

          frame:ClearAllPoints()

          if count == 0 then
            local y = -top_padding - (v.padding or 0)
            frame:SetPoint( "TOP", popup, "TOP", 0, y )
          else
            local line_anchor = lines[ count ].frame
            frame:SetPoint( "TOP", line_anchor, "BOTTOM", 0, v.padding and -v.padding or 0 )
          end
        end
      end, v.padding )
    end
  end

  local function show()
    if not popup then popup = create_popup() end
    refresh()

    popup:Show()
  end

  local function hide()
    if popup then popup:Hide() end
  end

  local function toggle()
    if not popup then popup = create_popup() end

    if popup:IsVisible() then
      popup:Hide()
    else
      show()
    end
  end

  local function refresh_if_visible()
    if popup and popup:IsVisible() then refresh() end
  end

  -- Scan results trickle in one inspect at a time, so the list redraws as they
  -- land. Nothing to redraw while it's hidden.
  resistance_check.subscribe( refresh_if_visible )

  m.slash_cmd( "rfres", toggle )

  ---@type ResistanceFrame
  return {
    show = show,
    hide = hide,
    toggle = toggle,
    -- The roster is read fresh on every refresh, so redrawing is all it takes
    -- for someone who joined to appear and someone who left to drop off.
    on_group_changed = refresh_if_visible,
    get_frame = function() return popup end
  }
end

m.ResistanceFrame = M
return M
