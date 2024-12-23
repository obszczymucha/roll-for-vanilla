RollFor = RollFor or {}
local m = RollFor

if m.RollingPopup then return end

local c = m.colorize_player_by_class
local blue = m.colors.blue

local button_defaults = {
  width = 80,
  height = 24,
  scale = 0.76
}

local M = {}

M.center_point = { point = "CENTER", relative_point = "CENTER", x = 0, y = 150 }

function M.new( custom_popup_builder, db, config )
  local popup
  db.point = db.point or M.center_point

  local function create_popup()
    local function is_out_of_bounds( point, x, y, frame_width, frame_height, screen_width, screen_height )
      local left, right, top, bottom
      local width = frame_width / 2
      local height = frame_height / 2

      if point == "TOPLEFT" then
        left = x - width
        right = x + width
        top = y + height
        bottom = y - height
      elseif point == "TOPRIGHT" then
        left = x - width
        right = x + width
        top = y + height
        bottom = y - height
      elseif point == "BOTTOMLEFT" then
        left = x - width
        right = x + width
        top = y + height
        bottom = y - height
      elseif point == "BOTTOMRIGHT" then
        left = x - width
        right = x + width
        top = y + height
        bottom = y - height
      else
        return false
      end

      return left < 0 or
          right > screen_width or
          top > 0 or
          bottom < -screen_height
    end

    local function on_drag_stop()
      local width, height = popup:GetWidth(), popup:GetHeight()
      local screen_width, screen_height = m.api.GetScreenWidth(), m.api.GetScreenHeight()
      local point, _, _, x, y = popup:get_anchor_point()

      if is_out_of_bounds( point, x, y, width, height, screen_width, screen_height ) then
        db.point = M.center_point
        popup:position( M.center_point )

        return
      end

      local anchor_point, _, anchor_relative_point, anchor_x, anchor_y = popup:get_anchor_point()
      db.point = { point = anchor_point, relative_point = anchor_relative_point, x = anchor_x, y = anchor_y }
    end

    local function get_point()
      if popup then
        local width, height = popup:GetWidth(), popup:GetHeight()
        local screen_width, screen_height = m.api.GetScreenWidth(), m.api.GetScreenHeight()
        local x, y = popup:get_anchor_center()

        if is_out_of_bounds( x, y, width, height, screen_width, screen_height ) then
          return M.center_point
        end
      elseif db.point then
        return db.point
      else
        return M.center_point
      end
    end

    local builder = custom_popup_builder()
        :with_name( "RollForRollingFrame" )
        :with_width( 180 )
        :with_height( 100 )
        :with_point( get_point() )
        :with_bg_file( "Interface/Buttons/WHITE8x8" )
        :with_sound()
        :with_esc()
        :with_backdrop_color( 0, 0, 0, 0.6 )
        :with_gui_elements( m.GuiElements )
        :with_frame_style( "PrincessKenny" )
        :with_on_drag_stop( on_drag_stop )

    popup = builder:build()

    if config.rolling_popup_lock() then
      popup:lock()
    else
      popup:unlock()
    end

    config.subscribe( "rolling_popup_lock", function( enabled )
      if enabled then
        popup:lock()
      else
        popup:unlock()
      end
    end )

    config.subscribe( "reset_rolling_popup", function()
      db.point = nil
      popup:position( M.center_point )
    end )
  end

  local function refresh( _, content )
    if not popup then return end
    popup:clear()

    for _, v in ipairs( content ) do
      popup.add_line( v.type, function( type, frame )
        if type == "item" then
          frame.text:SetText( v.link )
          frame:SetWidth( frame.text:GetWidth() )
          frame.tooltip_link = v.link and m.ItemUtils.get_tooltip_link( v.link )
        elseif type == "text" then
          frame:SetText( v.value )
        elseif type == "icon_text" then
          frame:SetText( v.value )
        elseif type == "roll" then
          frame.roll_type:SetText( m.roll_type_color( v.roll_type, m.roll_type_abbrev( v.roll_type ) ) )
          frame.player_name:SetText( c( v.player_name, v.player_class ) )

          if v.roll then
            frame.roll:SetText( blue( v.roll ) )
            frame.icon:Hide()
          else
            frame.roll:SetText( "" )
            frame.icon:Show()
          end

          -- local player_name = v.player_name

          frame:SetScript( "OnClick", function()
            -- if selected_frame then selected_frame:deselect() end
            -- frame:select()
            -- selected_frame = frame
            -- print( player_name )
          end )
        elseif type == "button" then
          frame:SetWidth( v.width or button_defaults.width )
          frame:SetHeight( v.height or button_defaults.height )
          frame:SetText( v.label or "" )
          frame:SetScale( v.scale or button_defaults.scale )
          frame:SetScript( "OnClick", v.on_click or function() end )
        elseif type == "info" then
          frame.tooltip_info = v.value
          frame:ClearAllPoints()
          frame:SetPoint( "TOPRIGHT", v.anchor, "TOPRIGHT", -5, -5 )
        end
      end, v.padding )
    end
  end

  local function show()
    if not config.rolling_popup() then return end

    if not popup then
      create_popup()
    else
      popup:clear()
    end

    popup:Show()
  end

  local function hide()
    popup:Hide()
  end

  local function border_color( _, r, g, b, a )
    if not popup then
      create_popup()
    end

    popup:border_color( r, g, b, a )
  end

  return {
    show = show,
    refresh = refresh,
    hide = hide,
    border_color = border_color
  }
end

m.RollingPopup = M
return M
