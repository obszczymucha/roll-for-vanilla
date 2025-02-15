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

---@alias RollingPopupData RollingPopupPreviewData|RollingPopupRaidRollData|RollingPopupRollData|RollingPopupRollingCanceledData|RollingPopupRaidRollingData|RollingPopupTieData

---@class RollingPopup
---@field show fun()
---@field refresh fun( _, content: RollingPopupData )
---@field hide fun()
---@field border_color fun( _, color: RgbaColor )
---@field backdrop_color fun( _, color: RgbaColor )
---@field get_frame fun(): table
---@field ping fun()

local M = m.Module.new( "RollingPopup" )

M.center_point = { point = "CENTER", relative_point = "CENTER", x = 0, y = 150 }

---@param popup_builder PopupBuilder
---@param content_transformer RollingPopupContentTransformer
---@param db table
---@param config Config
function M.new( popup_builder, content_transformer, db, config )
  ---@type Popup?
  local popup
  db.point = db.point or M.center_point

  local top_padding = 14
  local on_hide ---@type fun()?

  ---@param frame_name string?
  ---@param close_button_callback fun()?
  local function toggle_esc( frame_name, close_button_callback )
    if not frame_name then return end

    ---@diagnostic disable-next-line: undefined-global
    local f = UISpecialFrames

    local function disable_esc()
      ---@diagnostic disable-next-line: undefined-global
      for i, v in ipairs( f ) do
        if v == frame_name then table.remove( f, i ) end
      end
    end

    local function enable_esc()
      disable_esc()
      table.insert( f, frame_name )
    end

    if close_button_callback then
      on_hide = close_button_callback
      enable_esc()
    else
      on_hide = nil
      disable_esc()
    end
  end

  local function create_popup()
    local function is_out_of_bounds( point, x, y, frame_width, frame_height, screen_width, screen_height )
      local abs_x, abs_y

      if point == "CENTER" then
        abs_x = x
        abs_y = y
      elseif point == "TOPLEFT" then
        abs_x = x + frame_width / 2
        abs_y = y - frame_height / 2
      elseif point == "TOP" then
        abs_x = x
        abs_y = y - frame_height / 2
      elseif point == "TOPRIGHT" then
        abs_x = x - frame_width / 2
        abs_y = y - frame_height / 2
      elseif point == "RIGHT" then
        abs_x = x - frame_width / 2
        abs_y = y
      elseif point == "BOTTOMRIGHT" then
        abs_x = x - frame_width / 2
        abs_y = y + frame_height / 2
      elseif point == "BOTTOM" then
        abs_x = x
        abs_y = y + frame_height / 2
      elseif point == "BOTTOMLEFT" then
        abs_x = x + frame_width / 2
        abs_y = y + frame_height / 2
      elseif point == "LEFT" then
        abs_x = x + frame_width / 2
        abs_y = y
      else
        abs_x = x
        abs_y = y
      end

      local left = abs_x - frame_width / 2
      local right = abs_x + frame_width / 2
      local top = abs_y + frame_height / 2
      local bottom = abs_y - frame_height / 2

      local screen_left = 0
      local screen_right = screen_width
      local screen_top = 0
      local screen_bottom = -screen_height

      return left < screen_left or
          right > screen_right or
          top > screen_top or
          bottom < screen_bottom
    end

    local function on_drag_stop()
      if not popup then return end
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

    local builder = popup_builder
        :name( "RollForRollingFrame" )
        :width( 180 )
        :height( 100 )
        :point( get_point() )
        :bg_file( "Interface/Buttons/WHITE8x8" )
        :sound()
        :backdrop_color( 0, 0, 0, 0.6 )
        :gui_elements( m.GuiElements )
        :frame_style( "PrincessKenny" )
        :movable()
        :on_drag_stop( on_drag_stop )
        :on_hide( function()
          if on_hide then
            on_hide()
          end
        end )
        :self_centered_anchor()

    local result = builder:build()

    if config.rolling_popup_lock() then
      result:lock()
    else
      result:unlock()
    end

    config.subscribe( "rolling_popup_lock", function( enabled )
      if enabled then
        result:lock()
      else
        result:unlock()
      end
    end )

    config.subscribe( "reset_rolling_popup", function()
      db.point = nil
      if result then result:position( M.center_point ) end
    end )

    return result
  end

  ---@param buttons RollingPopupButtonWithCallback[]
  ---@return fun()?
  local function find_close_button_callback( buttons )
    for _, button in ipairs( buttons or {} ) do
      if button.type == "Close" then
        return button.callback
      end
    end
  end

  ---@param data RollingPopupData
  local function refresh( _, data )
    M.debug.add( string.format( "refresh( type: %s )", data.type or "nil" ) )
    M.debug.add( string.format( "buttons: %s", data.buttons and m.prettify_table( data.buttons, function( b ) return b.type end ) or "nil" ) )

    if not popup then popup = create_popup() end
    popup:clear()

    local close_button_callback = find_close_button_callback( data.buttons )
    toggle_esc( popup:GetName(), close_button_callback )

    for _, v in ipairs( content_transformer.transform( data ) ) do
      popup.add_line( v.type, function( type, frame, lines )
        if type == "item_link_with_icon" then
          frame:SetItem( v, v.link and m.ItemUtils.get_tooltip_link( v.link ) )
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
          frame:ClearAllPoints() -- This fixes a strange visual bug in BCC. Frame is either without label or misaligned without this.
          frame:SetScale( v.scale or button_defaults.scale )

          local f = v.on_click and close_button_callback and v.on_click == close_button_callback and function()
            on_hide = nil
            close_button_callback()
          end or v.on_click or function() end

          frame:SetScript( "OnClick", f )

          if v.disabled then
            frame:Disable()
          else
            frame:Enable()
          end
        elseif type == "award_button" then
          frame:SetWidth( v.width or button_defaults.width )
          frame:SetHeight( v.height or button_defaults.height )
          frame:SetText( v.label or "" )
          frame:SetScale( v.scale or button_defaults.scale )
          frame:SetScript( "OnClick", v.on_click or function() end )

          if v.disabled then
            frame:Disable()
          else
            frame:Enable()
          end
        elseif type == "info" then
          frame.tooltip_info = v.value
          frame:ClearAllPoints()
          frame:SetPoint( "TOPRIGHT", v.anchor, "TOPRIGHT", -5, -5 )
        elseif type == "empty_line" then
          frame:SetHeight( v.height or 4 )
        end

        if type ~= "button" then
          local count = #lines

          if count == 0 then
            local y = -top_padding - (v.padding or 0)
            frame:ClearAllPoints()
            frame:SetPoint( "TOP", popup, "TOP", 0, y )
          else
            local line_anchor = lines[ count ].frame
            frame:ClearAllPoints()
            frame:SetPoint( "TOP", line_anchor, "BOTTOM", 0, v.padding and -v.padding or 0 )
          end
        end
      end, v.padding )
    end
  end

  local function show()
    M.debug.add( "show" )

    if not popup then
      popup = create_popup()
    else
      popup:clear()
    end

    popup:Show()
  end

  local function hide()
    M.debug.add( "hide" )

    if popup then
      on_hide = nil
      popup:Hide()
    end
  end

  ---@param color RgbaColor
  local function border_color( _, color )
    if not popup then
      popup = create_popup()
    end

    popup:border_color( color.r, color.g, color.b, color.a )
  end

  ---@param color RgbaColor
  local function backdrop_color( _, color )
    if not popup then
      popup = create_popup()
    end

    popup:backdrop_color( color.r, color.g, color.b, color.a )
  end

  -- roll_controller.subscribe( "all_items_awarded", hide )

  local function get_frame()
    if not popup then
      create_popup()
    end

    return popup
  end

  local function ping()
    m.api.PlaySound( m.api.SOUNDKIT.IG_MAINMENU_OPEN )
  end

  ---@type RollingPopup
  return {
    show = show,
    refresh = refresh,
    hide = hide,
    border_color = border_color,
    backdrop_color = backdrop_color,
    get_frame = get_frame,
    ping = ping
  }
end

m.RollingPopup = M
return M
